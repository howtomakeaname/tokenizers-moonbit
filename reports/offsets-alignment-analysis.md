# Offset-Alignment Design Analysis: HF tokenizers vs. MoonBit port

Purpose: explain precisely how HuggingFace `tokenizers` keeps token offsets anchored to the
**original** input through arbitrary normalization and pre-tokenization rewrites, inventory where
the MoonBit port loses that anchor, and recommend a minimal-risk fix that preserves the current
public API (char offsets into the ORIGINAL text).

HF sources read: local checkout `hf-tokenizers` at 0.23.2-dev (alignment design unchanged since
~0.9; Python sweep target 0.22.2 has identical semantics).
MoonBit sources read: `tokenizer-moonbit/src`.

---

## 1. HF alignment semantics (with source references)

All paths below are relative to `hf-tokenizers/tokenizers/src/`.

### 1.1 The core data structure

`NormalizedString` (`tokenizer/normalizer.rs:105-117`) carries four fields:

```rust
original: String,                      // untouched input
normalized: String,                    // current state after edits
alignments: Vec<(usize, usize)>,       // PER NORMALIZED BYTE: (start,end) byte range in `original`
original_shift: usize,                 // if this is a slice, where its `original` starts in the parent's original
```

Identity construction (`From<String>`, normalizer.rs:998-1014): every byte `b` of each char
(range `b..b+len_utf8()`) gets alignment `(b, b+len)`. So before any edit, normalized byte `i`
maps to original byte `i` — the identity case.

`alignments` is the single source of truth for offset conversion, in both directions
(`convert_offsets`, normalizer.rs:156-215):

- **Normalized → Original**: take `alignments[a..b]` and *expand* (`expand_alignments`,
  normalizer.rs:905-913): result is `(alignments[a].0, alignments[b-1].1)` — the union span.
- **Original → Normalized**: scan alignments for entries whose original span overlaps the target
  (normalizer.rs:185-211).

### 1.2 The single edit primitive: `transform` / `transform_range`

Every normalizer ultimately funnels into
`transform_range(range, dest, initial_offset)` (normalizer.rs:317-428; whole-string wrapper
`transform` at 441-446). `dest` yields `(char, change)` pairs — the **change-encoding contract**
(documented at normalizer.rs:306-316 and reified by the helper in `normalizers/precompiled.rs:6-31`):

| `change` | meaning | new char's alignment |
|---|---|---|
| `0` | replaces the current normalized char (1:1) | keeps `alignments[idx]` of the char it replaces |
| `+1` (positive) | newly inserted char | **copies `alignments[idx - 1]`** — attaches to the *previous* normalized byte (normalizer.rs:364-372); if at position 0, `(0,0)` |
| `-N` (negative) | replaces the current char AND removes the next N normalized chars | keeps `alignments[idx]`; the removed chars' original bytes simply become uncovered (deleted from `alignments`) |

`initial_offset` = number of *leading* normalized chars being deleted (used by `filter` and
`lrstrip` so the stream can start mid-string, normalizer.rs:339-344).

This one primitive covers every case in the sweep:

- **Identity / per-char change** (`Lowercase` ASCII, `map`, whitespace→space): all changes 0.
  Alignments unchanged. (`map`, normalizer.rs:529-537; `lowercase`, 546-555 — note `lowercase`
  marks expansion chars like `ß → SS` with +1.)
- **1→many expansion (NFD/NFKD)**: `n.nfd()` etc. (normalizer.rs:449-470) feed the
  `unicode-normalization-alignments` crate stream directly into `transform`; a decomposed
  combining mark is an inserted char (+1) that attaches to the base char's alignment. Verified by
  `nfd_adds_new_chars` (normalizer.rs:1043-1076): `"é"` → `"e\u{301}"`, all 3 normalized bytes map
  to original `(0,2)` — one original char, two normalized chars, same span. **This is why HF
  "counts the combining mark": the 7-char normalized `éclair` still maps to the 6-char original
  word.**
- **many→1 collapse (NFC/NFKC)**: the composed char carries `-N` so the absorbed chars' coverage
  disappears; the composed char keeps only the alignment of the first char it replaces. (Same
  convention as `Precompiled`'s `replace` helper, precompiled.rs:14-30: last kept char gets
  `change += diff`.)
- **Insertion (`Prepend`, BertNormalizer Chinese pads, Metaspace ▁)**:
  `prepend` (normalizer.rs:503-514) emits prepend-chars where the *first* has change 0 (it takes
  over the old first char's alignment) and re-emits the old first char with +1 (attaches to the
  prepend char). Net: prepended `▁` and `H` both map to original `[0,1)` — see the test in
  `normalizers/prepend.rs:30-61` (`"Hello"`→`"▁Hello"`, alignments `[(0,1)×4, (1,2), …]`).
  BertNormalizer `handle_chinese_chars` (`normalizers/bert.rs:98-108`) emits `(' ',0),(c,1),(' ',1)`
  per CJK char: both pad spaces attach to the CJK char's original span.
- **Deletion (`Strip`, `StripAccents`, Nmt control chars, Removed punctuation)**:
  - `filter` (normalizer.rs:473-500): a run of removed chars is encoded as `-removed` on the
    previous kept char; leading removals become `initial_offset`/`removed_start`. Original bytes of
    removed chars end up covered by nobody (zero-width in `alignments_original`,
    normalizer.rs:854-901 — e.g. the "Eaten n" test, normalizer.rs:1106-1138).
  - `lstrip/rstrip/strip` (`lrstrip`, normalizer.rs:786-835): leading whitespace count becomes
    `initial_offset`; trailing whitespace becomes `-trailing` on the last kept char.
    **This is why HF's first token of `"  leading…"` starts at original offset 2, not 0.**
- **`Replace` (pattern → content)**: bulk rebuild (normalizer.rs:570-674). All content chars are
  marked +1, so each replacement char attaches to the alignment of the byte *before* the running
  cursor — concretely the first content char attaches to the last byte of the matched text, and
  subsequent content chars chain onto it. Shorter content ⇒ leftover matched original bytes are
  dropped from coverage; longer content ⇒ extra chars share the tail span; equal length ⇒ 1:1.

### 1.3 Slicing keeps alignment alive across splits

`slice(range)` (normalizer.rs:272-304) produces a child `NormalizedString`: `original` becomes the
slice of the parent original, `alignments` entries are re-based by `n_shift = original_range.start`,
and `original_shift` accumulates. This is how per-piece offsets stay globally correct after
splitting: each child still knows where it lives in the *root* original string.

### 1.4 PreTokenizedString and final offsets

`PreTokenizedString` (`tokenizer/pre_tokenizer.rs:54-58`) = `original: String` + `Vec<Split>`,
where each `Split` (pre_tokenizer.rs:15-46) wraps a full `NormalizedString` (with its alignments
and shift). Its `split()` contract (pre_tokenizer.rs:68-103) requires that pieces recombine to the
same original — pre-tokenizers may freely *rewrite the normalized view* (Metaspace does) because
rewrites go through the same `NormalizedString` methods.

- **`get_splits(OffsetReferential::Original, OffsetType::Char)`** (pre_tokenizer.rs:268-300):
  per split, take `normalized.offsets_original()` = `(original_shift, original_shift +
  len_original())` — byte offsets into the **root original** — then run `BytesToCharOffsetConverter`
  (pre_tokenizer.rs:329-364, a byte→char map built once over `self.original`) to emit **char
  offsets into the original string**. With `OffsetType::Byte` the byte values pass through.
- **`into_encoding(word_idx, type_id, offset_type)`** (pre_tokenizer.rs:198-263): the final token
  offsets. For each split and each model `Token` (whose offsets are relative to the split's
  *normalized* text):
  1. `normalized.convert_offsets(Range::Normalized(token.offsets))` → original-referential range
     **within the split's own original slice** (the alignment expansion of §1.1);
  2. shift by the split's base: `offsets.0 + range.start` where `offsets = normalized.offsets_original()`;
  3. if `offset_type == Char`, convert byte→char against the root original string
     (`converter.convert(offsets)`, falling back to the byte value if not on a boundary).

### 1.5 The pipeline (referentials at each stage)

`Tokenizer::encode_single_sequence` (`tokenizer/mod.rs:732-775`):

```
input str
 └─ AddedVocabulary::extract_and_normalize (added_vocabulary.rs:523-564)
     1. split on NON-normalized added tokens (against the raw string),
        slicing the NormalizedString per match (split_with_indices, added_vocabulary.rs:495-515)
     2. run the normalizer on each remaining slice (still a NormalizedString — alignments intact)
     3. split on normalized added tokens (slices again)
 └─ do_pre_tokenize (mod.rs:1218-1229)     — rewrites/splits via NormalizedString methods
 └─ do_tokenize (mod.rs:1148-1171)         — model.tokenize(normalized.get()) per split;
                                             token offsets are normalized-relative
 └─ PreTokenizedString::into_encoding      — converts everything to ORIGINAL-referential
```

`Tokenizer::encode` uses `OffsetType::Byte` (mod.rs:852) — **the Rust core's `Encoding.offsets`
are byte offsets into the original input**; `encode_char_offsets` uses `OffsetType::Char`
(mod.rs:884-902); `encode_fast` uses `OffsetType::None` (zeroed, mod.rs:810).

Downstream note: post-processors adjust these final original-referential offsets (e.g. RoBERTa
`trim_offsets`, `processors/roberta.rs:71`; special tokens get offsets spanning the template
insertion point), and `Encoding::merge` (encoding.rs:391-463) shifts the second pair member's
offsets by `growing_offsets` (used for pre-tokenized input).

### 1.6 Python bindings nuance (confirmed)

- `bindings/python/src/tokenizer.rs:1210`: Python `encode` calls `encode_char_offsets` → core
  runs with `OffsetType::Char`.
- `bindings/python/src/encoding.rs:217-226`: `Encoding.offsets` returns those values verbatim.

**Therefore Python `enc.offsets` are char offsets into the ORIGINAL unicode string.** (The Rust
core keeps byte offsets internally; pyo3 never sees them.) The MoonBit port's public convention —
char offsets into the original text, with `encode_*_with_byte_offsets` variants — matches Python
semantics exactly; only the internals need fixing.

---

## 2. MoonBit gap inventory (where original-referential mapping is lost)

The port's pipeline is a flat `String → String → pieces` flow with a single scalar `base_offset`
threaded through. Offsets are computed as `base + index-in-current-string`, i.e. they are
**normalized-referential with an original-text base**. That is only correct when normalization is
the identity; any insert/delete/expand/collapse makes every downstream offset wrong.

| # | Location | Problem |
|---|---|---|
| G1 | `src/tokenizer/normalized_string.mbt:2-5` | `NormalizedString` holds only `(original, normalized)`. No `alignments`, no `original_shift`. Comment at :141-143 admits "does not track per-char original offsets yet". `normalize()` (:161-166) and all mutating helpers (:169-339) rebuild `normalized` with plain string ops. |
| G2 | `src/normalizer/normalize.mbt:8-60` | `Normalizer::normalize : String -> String`. The entire normalizer layer cannot express alignment. All helpers (`normalize_utils.mbt:2-137` strip/accents/bert-clean/lowercase; `unicode_norm.mbt` NFC/NFD) are `String -> String`. |
| G3 | `src/tokenizer/encode_helpers.mbt:171` | `let normalized = self.normalize_with_hook(raw, hooks)` — **the single line where the mapping dies**. Everything downstream (stage-2 added-token offsets, piece offsets, token offsets) is anchored to the normalized string. |
| G4 | `src/tokenizer/encode_helpers.mbt:174-177` + `src/tokenizer/added_vocabulary_impl.mbt:147-224, 257-267` | `extract_stage2(normalized, base_offset)` scans the **normalized** text but emits `Normal(text=…, base_offset=base + normalized_index)` and `Special(offsets=(base + lo, base + hi))` (:167, :215). Assumes normalized index == original index − base. HF instead *slices the NormalizedString*, keeping alignments per piece. |
| G5 | `src/tokenizer/encode_helpers.mbt:182-195` | `pre_tokenize_with_hook(ntext, base2)` hands the pre-tokenizer a bare string + scalar. `model_offset = piece.offsets.0` then feeds `model.tokenize(piece.value, offset=model_offset)`. |
| G6 | `src/pretokenizer/pre_tokenize.mbt:9-34` (API), `:146-153` (`emit_span`: `base + start`), `:294-306` (`pieces_to_splits`: running cursor), `pre_tokenize_patterns.mbt:35-58, 100-517` (all variants) | Every pre-tokenizer computes piece offsets arithmetically over the normalized string. No per-char origin, no attach semantics. |
| G7 | `src/pretokenizer/pre_tokenize.mbt:363-404` (`byte_level_pre_tokenize`) | Prepended space handled by a `−1` shift + clamp hack (:384-399) — a local approximation of "inserted char attaches to following original char", brittle for boundary tokens. |
| G8 | `src/pretokenizer/pre_tokenize_patterns.mbt:461-517` (`metaspace_pre_tokenize`) | Closest to correct: keeps a local `origin : Array[Int]` (:476-489) so *piece-level* offsets survive. But (a) a prepended ▁ maps to `origin 0` rather than sharing the first real char's span, and (b) the `origin` array is discarded after piece emission — token offsets *inside* a piece are recomputed by the model's scalar arithmetic, so a token spanning `[▁, H]` gets width 2 instead of HF's width 1 (HF: both chars map to original `[0,1)`). |
| G9 | `src/model/bpe.mbt:248-256` (`shift_tokens`), `:267-360` (`offset + char_pos`); same pattern in `unigram.mbt:39-151`, `wordpiece.mbt:13-78` | Model token offsets are piece-relative + scalar. In HF these are *legitimately* normalized-relative — but HF converts them through alignments afterwards; the port never does. |
| G10 | `src/tokenizer/encode_helpers.mbt:2-54` (`encoding_with_byte_offsets`, `convert_offsets`) | Builds the char→byte table over the **original** text — correct *intent* (public offsets must be original-referential) but currently receives normalized-referential char offsets from G3-G9, so the byte-offset variants are equally wrong after any normalizer change. |
| G11 | `src/tokenizer/encode_helpers.mbt:275-357` (`encode_pretokenized_raw_impl`, base arithmetic :341-344) | Pre-tokenized path anchors offsets to a synthetic space-joined **normalized** string (documented at `encode.mbt:564-567`). HF encodes each word as its own NormalizedString and merges with `growing_offsets=true` (encoding.rs:449-459). Deviation is documented but is part of the same referential confusion. |
| G12 | `src/normalizer/normalize_utils.mbt:117-137` (`strip`) | Side finding: strips ASCII whitespace only; HF `lrstrip` uses `char::is_whitespace()` (Unicode). Offsets *and* stripped-content parity both diverge for Unicode spaces. |

Why each sweep failure happens, mapped to gaps:

- **Strip `"  leading and trailing   "` → ours `[0,7]…` vs HF `[2,9]…`**: leading spaces are deleted
  (G2/G3); our offsets count from the normalized start; HF's alignments keep each surviving char
  pointing at its original position (HF `lrstrip`, normalizer.rs:786-835).
- **NFD `"éclair séance"` → ours 6 vs HF 7 units for `éclair`** (char-vs-char): decomposed marks
  are extra normalized chars in ours (index arithmetic overcounts); in HF the mark attaches to the
  base char, so the whole `e◌́clair` span maps back to the 6-char original word (expand semantics,
  §1.2).
- **Metaspace `▁`/`Ġ` tokens with "too wide" offsets**: inserted ▁ must share the neighboring
  original char's span (attach semantics); ours counts it as its own unit (G8/G9).

---

## 3. Recommended fix architecture (minimal risk, public API preserved)

### 3.1 Design principle

Do NOT port HF's byte-level `alignments` machinery wholesale. The port is char-indexed
throughout, the public API is already char-offset-into-original (Python-compatible), and
`encode_fast` bypasses offsets entirely. A **char-granular alignment table threaded as data**
gets full parity with far less churn.

### 3.2 Data structure

Extend the pipeline value with an alignment column (new file, e.g. `src/tokenizer/align.mbt`):

```moonbit
/// Per-normalized-CHAR span into the ORIGINAL text (char indices), plus the
/// original slice's start in the root original (HF `original_shift`).
pub(all) struct AlignedText {
  text   : String                  // current (normalized) text, char-indexed
  align  : Array[(Int, Int)]       // align[i] = original char span of text[i]; identity = [(i, i+1)]
  base   : Int                     // original-range start of this AlignedText in the root input
                                   // (span values are relative to this; add `base` at the boundary)
}
```

Semantics copied from HF (§1.1-1.2):

- `expand(at, a, b) -> (Int, Int)` = `(at.align[a].0, at.align[b-1].1) + base` — the ONLY query
  the pipeline needs (mirrors `expand_alignments`, normalizer.rs:905-913, plus the shift of
  `offsets_original()`).
- `slice(at, a, b) -> AlignedText` — sub-text with `align` sliced and `base += align[a].0`
  (mirrors `NormalizedString::slice`, normalizer.rs:272-304).
- One generic editor mirroring the change contract, `apply_changes(at, ops : Array[(Char, Int)])`
  where the `Int` is HF's change code (0 / +1 / −N), reproducing normalizer.rs:347-414 in char
  units: replaced char keeps its align; inserted char copies the previous char's align
  (`(0,0)`/following-char rule for position 0, per `prepend`); removed chars drop coverage.

### 3.3 Where to hook it

1. **Normalizer boundary — `normalize_with_hook`** (`encode_helpers.mbt:216-229`): change the hook
   type / internal call to `AlignedText -> AlignedText`. Internally, `Normalizer::normalize` grows
   a sibling `normalize_aligned(input : AlignedText) -> AlignedText` (keep the old `String -> String`
   for the public API and `precompiled_map` fast paths). Each variant is a small op-list over
   `apply_changes` (case table in §3.4). The default implementation for variants that are strictly
   char-wise 1:1 can be `identity-align + copy` — zero behavioral risk where today's arithmetic is
   already exact.
2. **Added-vocabulary stage 2** (`added_vocabulary_impl.mbt:257-267`, used at
   `encode_helpers.mbt:174-177`): scan the normalized `text` as today, but emit `Special(offsets =
   expand(at, lo, hi))` and `Normal` segments as `slice(at, lo, hi)` (carry the `AlignedText`
   instead of `(String, base_offset)`). Stage 1 (raw text) already has identity alignment — wrap
   the raw segment in an identity `AlignedText` so both stages share code.
3. **Pre-tokenizer boundary — `pre_tokenize_with_hook`** (`encode_helpers.mbt:232-252`) and
   `PreTokenizer::pre_tokenize` (`pre_tokenize.mbt:9-34`): accept `AlignedText`, return splits that
   each carry their `align` slice (`@types.Split` gains one optional field, e.g.
   `align? : Array[(Int, Int)]` with absolute original spans, or keep `AlignedText` per split).
   Concretely per variant:
   - `emit_span`/`pieces_to_splits` (`pre_tokenize.mbt:146-153, 294-306`): keep the span math (it
     indexes the normalized string, which is correct for locating chars) but emit
     `offsets = expand(at, span.start, span.stop)` instead of `base + span`, plus the align slice.
   - Metaspace (`pre_tokenize_patterns.mbt:461-517`): replace the local `origin` with the shared
     mechanism — ▁ replaces the space 1:1 (keep align); a *prepended* ▁ is an insert attaching to
     the first char (fixes the `[▁,H]`-width bug).
   - ByteLevel `add_prefix_space` (`pre_tokenize.mbt:363-404`): delete the `−1`/clamp hack; the
     inserted space is an attach-insert.
   - Behavior `Removed` etc.: dropped delimiter chars simply appear in no split's align slice —
     nothing else needed.
4. **Model / emit site** (`encode_helpers.mbt:187-193`): keep `model.tokenize(value, offset=…)`
   exactly as is (model offsets stay piece-relative — same as HF), but at `emit`, map the token's
   piece-relative span through the split's align slice: `offs = expand(split_align, t.offsets.0 - piece_start, t.offsets.1 - piece_start)`.
   This is the port's equivalent of `into_encoding` step (1)+(2) (pre_tokenizer.rs:236-241).
   No model file needs to change (G9 stays, harmlessly).
5. **Byte-offset variants** (`encode_helpers.mbt:2-54`): unchanged code becomes correct once
   upstream offsets are original-referential (the table is already built over the original text).
6. **Skip path**: `track_offsets=false` (`encode_fast`) never builds `AlignedText` (wrap the text
   lazily / keep the string-only fast path). Zero cost for the fast API, mirroring HF's
   `OffsetType::None`.

### 3.4 Which normalizer needs which alignment case

| Normalizer (MoonBit variant, `normalizer/normalize.mbt`) | cases | Notes |
|---|---|---|
| `Lowercase` | 1:1 (+ insert for Unicode expansions `ß→SS`, `İ→i·̇`) | current ASCII impl is pure 1:1 |
| `Strip` | delete (leading via base advance, trailing absorbed into last char) | also switch to Unicode whitespace (G12) |
| `StripAccents` | 1:1 (`é→e` keeps span) + delete (combining marks) | matches HF `filter` |
| `Prepend` | insert (attach to first char) | prepend.rs:30-61 test is the oracle |
| `NFD` / `NFKD` | expand (marks attach to base) | normalizer.rs:1043-1076 test is the oracle |
| `NFC` / `NFKC` | 1:1 + collapse (`-N` on composed char) | precompiled.rs:6-31 convention |
| `Replace` / `ReplaceString` | 1:1 / expand / delete — content chars attach to the END of the matched original span | normalizer.rs:570-674 |
| `BertNormalizer.clean_text` | delete (controls, `\x00`, U+FFFD) + 1:1 (ws→space) | bert.rs:92-96 |
| `BertNormalizer.handle_chinese_chars` | insert ×2 (both spaces attach to the CJK char) | bert.rs:98-108 |
| `BertNormalizer.strip_accents` | NFD expand + mark delete | |
| `Nmt` | delete + 1:1 | |
| `ByteLevel` (normalizer) | expand (each extra mapped char attaches to the char's span) | byte_level.rs:34-52 |
| `Precompiled` / `PrecompiledMap` | 1:1 / expand / collapse per grapheme transform | precompiled.rs |
| Pre-tokenizer `Metaspace` | 1:1 replace + insert prepend | §3.3.3 |
| Pre-tokenizer `ByteLevel.add_prefix_space` | insert | §3.3.3 |

### 3.5 Risk containment

- Public API untouched: `Encoding.offsets` stays `Array[(Int, Int)]` char-into-original;
  `encode_with_byte_offsets` behavior unchanged in signature, becomes *correct*.
- `Normalizer::normalize(String)->String` stays; `normalize_aligned` is additive.
- Where the normalizer is identity/1:1, alignment is exact by construction, so currently-passing
  models (GPT-2, Llama-BPE token ids) see identical offsets — the change only alters the
  previously-broken cases.
- Rollout order: G1/G2 infra → G3/G4 (stage-2 rebase) → G5/G6 (pre-tokenizer) → emit-site mapping.
  Each step is testable against §4 fixtures before the next.

---

## 4. Test cases derived from the sweep failures

All assertions are against Python `tokenizers==0.22.2` behavior (char offsets into the original
string; byte-offset variant asserts the byte equivalents of the same spans).

1. **Strip (delete-left)**: tokenizer `normalizer: Strip(left,right)` + `Whitespace` pre-tokenizer
   on `"  leading and trailing   "` → tokens `leading` `(2,9)`, `and` `(10,13)`, `trailing`
   `(14,22)`. (Today: `(0,7)`, `(8,11)`, `(12,20)` — normalized-referential.)
2. **Strip right**: trailing spaces must not extend the last token's end beyond `22`.
3. **NFD (expand)**: `NFD` + whitespace pretok on `"éclair séance"` (precomposed é) → whole-word
   token `éclair` (normalized `e◌́clair`) has offsets `(0,6)`; a sub-token `e◌́c` has `(0,3)`;
   `séance` starts at `7` (chars), not `8`. Byte variant: `(0,7)` bytes.
4. **NFC (collapse)**: input with decomposed `"e\u{301}clair"` + `NFC` → token `éclair` offsets
   `(0,6)` (composed char absorbs the mark).
5. **NFD + StripAccents (delete after expand)**: `"éclair"` → `éclair`→`eclair`, token `eclair`
   offsets `(0,6)` (mark deleted, base keeps span) — mirrors normalizer.rs:1078-1103.
6. **Prepend (insert)**: `Prepend("▁")` + whitespace on `"Hello world"` → first token spans
   `(0,5)`; a token covering only `▁H` must be `(0,1)`, not `(0,2)` — prepend.rs:30-61 oracle.
7. **Metaspace (replace 1:1 + insert + split MergedWithNext)**: `Metaspace(▁, always, split=true)`
   on `"Hey friend!"` → pieces `"▁Hey"` `(0,3)`, `"▁friend!"` `(3,11)`; token `"▁H"` `(0,1)`;
   `"▁f"` `(4,5)` — metaspace.rs:211-232 oracle.
8. **Metaspace multiple spaces**: `"Hey   friend!"` → `"▁Hey"(0,3)`, `"▁"(3,4)`, `"▁"(4,5)`,
   `"▁friend!"(5,13)` — metaspace.rs:234-265 oracle. Each ▁ owns exactly its original space.
9. **Metaspace prepend_scheme=first**: ▁ only on the split whose `offsets_original().0 == 0`
   (added-token splits suppress it) — metaspace.rs:267-355.
10. **Replace shorter (delete)**: `Replace(Regex "\\s+", " ")` on `"This     is   a         test"`
    → `This(0,4)`, `is(9,11)`, `a(13,14)`, `test(23,27)` (original positions; collapsed spaces
    attach to the last space of each run).
11. **Replace longer (expand)**: `Replace("''", "\"\"\"")` style 1→3: all three inserted chars map
    inside the original `''` span.
12. **BertNormalizer handle_chinese_chars (insert)**: `"你好"` → normalized `" 你 好 "`; token for
    `你` has offsets `(0,1)`, `好` `(1,2)`; the pad spaces share those spans (never `(0,1)`+`(2,3)`).
13. **BertNormalizer clean_text (delete + 1:1)**: `"\x00abc\tdef"` → `abc(1,4)`, `def(5,8)` with
    the tab→space keeping its original slot.
14. **BertNormalizer lowercase+strip_accents (full BERT stack)** on `"Me llamó"` → `me(0,2)`,
    `llamo(3,8)` (ó→o keeps its original char slot).
15. **ByteLevel pre-tokenizer add_prefix_space (insert)**: `"Hello"` → piece `ĠHello` offsets
    `(0,5)`; token `ĠH` `(0,1)` — replaces the clamp hack (G7).
16. **Byte-level + NFD double distortion**: `"é x"` with NFD then ByteLevel: token containing the
    mark maps inside `(0,1)`.
17. **Added-token stage-2 rebase**: normalized added token (e.g. lowercase-model `<mask>`) found
    inside `"  Hello <mask>"` after Strip — its offsets must be original-referential `(8,14)`.
18. **Special tokens around normalization** (`lstrip`/`rstrip` variants): whitespace absorbed into
    the Special span must be original-referential.
19. **Byte-offset variants**: repeat 1, 3, 7, 12 through `encode_with_byte_offsets` with expected
    UTF-8 byte spans (e.g. NFD `éclair` → `(0,7)` bytes).
20. **Regression guard**: identity-normalizer models (GPT-2 regex path, Llama BPE) — offsets
    byte-identical before/after the change.

---

## 5. Summary of the root cause in one sentence

HF anchors every offset by carrying a per-character `alignments` column through
normalize → split → pre-tokenize → tokenize and converting to the original referential only at
`into_encoding`; the MoonBit port replaced that column with a scalar `base_offset` plus
index arithmetic, which is exact only when the normalizer/pre-tokenizer never inserts, deletes,
expands, or collapses characters — exactly the cases in the sweep.
