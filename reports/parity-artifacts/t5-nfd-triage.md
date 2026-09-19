# T5 tokenizer divergence triage: `[11949, 11949, ...]` vs `[11949, 6913, 2, ...]`

Tokenizer: `/Users/bytedance/Documents/projects/moonbit-exp-projects/consumer-eval/models/tokenizer_t5.json`
Python `tokenizers` 0.22.2 (wraps Rust tokenizers v0.21.1). All findings below verified by running the
real library and by decoding the real precompiled-charsmap trie.

## 0. Input mixup in the task premise (important)

The quoted input `"Ｌｕｎｉｃｏｄé ｈｅｌｌｏ"` and the quoted id sequences do **not** belong to the same battery
case. In `tokenizer-moonbit/scripts/parity_cases.py`, `INPUTS` is:

| index | input | codepoints |
|---|---|---|
| 4 | `café café Nomade NOMADE` | `café` #1 is **NFC** (U+00E9); `café` #2 is **NFD** (`c a f e U+0301`) |
| 5 | `Ｌｕｎｉｃｏｄé ｈｅｌｌｏ` | fullwidth `Ｌｕｎｉｃｏｄ` + NFC `é` + space + fullwidth `ｈｅｌｌｏ` |

The id sequences in the task (`[11949, 11949, 465, 4725, 56, ...]` golden, `[11949, 6913, 2, 465, 4725, 5...]`
port) are for **INPUTS[4]** (`café café Nomade NOMADE`), *not* for the fullwidth string.
Note `56...` / `5...` are elisions of **5693** (`▁NO`), not id 56 (`▁will`) or id 5 (`.`).
The fullwidth input (INPUTS[5]) does **not** diverge at the normalizer for fullwidth→ASCII
(single-char trie keys) — its golden is below too.

## 1. Golden outputs (Python tokenizers 0.22.2, `Tokenizer.from_file(...)`, default `add_special_tokens=True`)

### INPUTS[4] = `"café café Nomade NOMADE"` (word 2 in NFD)

```
ids:    [11949, 11949, 465, 4725, 5693, 329, 20458, 1]
tokens: ['▁café', '▁café', '▁No', 'made', '▁NO', 'M', 'ADE', '</s>']
offsets:[(0,4), (5,9), (11,13), (13,17), (18,20), (20,21), (21,24), (0,0)]
```

### INPUTS[5] = `"Ｌｕｎｉｃｏｄé ｈｅｌｌｏ"`

```
ids:    [2318, 2532, 32, 3764, 21820, 1]
tokens: ['▁Lu', 'nic', 'o', 'dé', '▁hello', '</s>']
offsets:[(0,2), (2,5), (5,6), (6,8), (9,14), (0,0)]
```

Key ids: 11949=`▁café`, 6913=`▁cafe`, 2=`<unk>`, 465=`▁No`, 4725=`made`, 5693=`▁NO`, 329=`M`,
20458=`ADE`, 1=`</s>`, 3=`▁`, 56=`▁will`, 5=`.`.

`tok.normalizer` repr: `Precompiled(precompiled_charsmap=<base64>)`.
`tok.pre_tokenizer` repr: `Sequence(pretokenizers=[WhitespaceSplit(), Metaspace(replacement="▁", prepend_scheme=always, split=True)])`.
Model: `Unigram(unk_id=2, ...)`. Post-processor appends `</s>` (TemplateProcessing).

## 2. Why 11949 appears TWICE

The input literally contains the word *café* twice — once NFC, once NFD. The precompiled charsmap
contains the multi-codepoint key `e`+`U+0301` → `é`, so **both spellings normalize to the same
`café`**, and each whitespace-split word gets `▁` prepended by Metaspace and tokenizes to the single
vocab entry `▁café` = 11949. Nothing to do with `▁`-prepending quirks, `<unk>`, or apostrophes
(the input contains no apostrophe; the "fullwidth ＇" hypothesis is moot).

## 3. The exact HF 0.22.2 normalization chain for INPUTS[4]

1. **Precompiled charsmap** (t5's `nmt_nfkc`): the crucial, counter-intuitive algorithm
   (Rust `tokenizers` v0.21.1 `normalizers/precompiled.rs`, verbatim; the same code lives in
   `spm_precompiled::normalize_string`):

   ```rust
   normalized.get().graphemes(true).for_each(|grapheme| {
       if grapheme.len() < 6 {
           if let Some(norm) = self.transform(grapheme) {
               replace(&mut transformations, grapheme, norm);
               return;
           }
       }
       for (char_index, c) in grapheme.char_indices() {
           let part = &grapheme[char_index..char_index + c.len_utf8()];
           if let Some(norm) = self.transform(part) { ... } else { transformations.push((c, 0)); }
       }
   });
   ```

   i.e. **UAX#29 grapheme clusters** are tried against the trie **as a whole** (only if the grapheme
   is `< 6` UTF-8 **bytes**); only if that misses does it fall back to **per-character** lookups.
   `transform()` itself = darts `common_prefix_search` → takes `results[0]` = the **first (shortest)
   prefix match** and its value (spm_precompiled 0.1.x, verbatim: `let index = results[0] as usize;`).

   For our input: `cafe` + `U+0301` forms ONE grapheme (`e`+combining acute, 3 bytes < 6);
   the trie has the 2-char key `e`+`U+0301` → `é`, so the whole grapheme is replaced by `é`.
   Result: `"café café Nomade NOMADE"` (verified: `tok.normalizer.normalize_str(input)` returns
   exactly this). NFC word 1 passes through unchanged (`é` has no single-char key — pass-through).

2. **Pre-tokenizer**: `WhitespaceSplit` → `["café", "café", "Nomade", "NOMADE"]`, then
   `Metaspace(replacement="▁", prepend_scheme=always)` (JSON says legacy `add_prefix_space: true`)
   → `["▁café", "▁café", "▁Nomade", "▁NOMADE"]`.

3. **Unigram**: `▁café`→11949 (×2), `▁Nomade`→`▁No`,`made`, `▁NOMADE`→`▁NO`,`M`,`ADE`.

4. **Post-processor**: append `</s>` (1).

For INPUTS[5] the chain is: per-char fullwidth mappings `Ｌ→L,ｕ→u,...` (single-char trie keys) →
`"Lunicodé hello"` → `["▁Lunicodé","▁hello"]` → `['▁Lu','nic','o','dé'] + ['▁hello']` → `+ </s>`.
There is **no accent stripping** anywhere in t5's normalizer (contrary to the task's premise —
`é` survives into `dé`/`▁café`).

## 4. Trie facts (decoded from the actual base64 charsmap)

Header is **little-endian** u32 trie-byte-size (0x0002B400 = 177152 bytes = 44288 darts units),
then the trie, then the NUL-separated values blob. Enumerating all keys:

- total keys: **224,711**
- **multi-codepoint keys: 219,874** (97.8%) — mostly NFD combining sequences → composed forms
- `e`+`U+0301` → `é` exists (value blob offset 2564); `u`+`U+0308`→`ü`, `A`+`U+0302`→`Â`, `ﬁ`→`fi`,
  `Ｌ`→`L`, `Ⅸ`→`IX`, `\t`→` ` all exist; plain `e`, `é`, `U+0301` alone have **no** key (pass-through).
- `A`+`U+0302`+`U+0301` → `Ấ` exists too, but `transform` takes the *first* match, so HF yields `Â`
  and the leftover mark is swallowed with the grapheme — a known quirk of this normalizer.

## 5. Where the MoonBit port diverges

`tokenizer-moonbit/src/normalizer/normalize_precompiled.mbt`, `precompiled_map_normalize`
(the variant constructed from a non-empty `precompiled_charsmap`, see `normalizer_json.mbt`):

```moonbit
while i < chars.length() {
  match precompiled_transform(data, char_to_string(chars[i])) {  // <-- ONE codepoint at a time
    Some(repl) => sb.write_string(repl)
    None => sb.write_char(chars[i])
  }
  i = i + 1
}
```

The trie key is always a **single codepoint** (`char_to_string(chars[i])`), so the 219,874
multi-codepoint keys can never match. Consequences for INPUTS[4], word 2 (`c a f e U+0301`):

- `c`,`a`,`f`,`e` → no single-char keys → pass through; `U+0301` → no single-char key → **survives**.
- Normalized string stays `"cafe"+U+0301` (no composition).
- Unigram then segments `▁cafe` → id **6913** (`▁cafe`) and the orphaned `U+0301` → id **2** (`<unk>`).

Exact reproduction: encoding INPUTS[4] in Python with the normalizer stripped
(`json["normalizer"]=None`) yields **precisely** the port's output:

```
ids:    [11949, 6913, 2, 465, 4725, 5693, 329, 20458, 1]
tokens: ['▁café', '▁cafe', '<unk>', '▁No', 'made', '▁NO', 'M', 'ADE', '</s>']
```

matching the reported port prefix `[11949, 6913, 2, 465, 4725, 5...]` (with `5...` = 5693...).
So the port's bug is exactly "charsmap applied per-codepoint instead of per-grapheme".

What the port already gets right: darts walk (`precompiled_common_prefix_search`) and taking
`results[0]` (first match) match `spm_precompiled::transform` semantics byte-for-byte; the LE
header parse is correct; fullwidth single-char mappings work (hence INPUTS[5] mostly survives).

## 6. Expected fix (behavior to replicate)

In `precompiled_map_normalize` (or wherever Precompiled normalization is dispatched):

1. Segment the string into UAX#29 grapheme clusters (need `Extend`/combining marks to join the
   preceding base char; ZWJ etc. per UAX#29 — port `unicode-segmentation`'s `graphemes(true)`).
2. If the grapheme's UTF-8 length is **< 6 bytes**, run the existing longest-prefix trie search on
   the whole grapheme string; if it matches, emit the value and **consume the whole grapheme**
   (leftover marks are discarded — HF does this via `replace()`).
3. Otherwise fall back to the current per-character lookup for each char in the grapheme.
4. Preserve offset alignment for 2→1 char merges (`e`+`U+0301` → `é`): HF records char-count diffs
   (`replace()` in precompiled.rs) so token offsets point into the *original* string; the golden
   offset for the second `▁café` is `(5,9)` — note the trailing combining mark at index 9 is *not*
   part of any token span.

Verification case after the fix: `café`(NFC) and `cafe\u0301`(NFD) must produce identical ids
(11949); `Ｌｕｎｉｃｏｄé ｈｅｌｌｏ` must stay `[2318, 2532, 32, 3764, 21820, 1]`; Hangul jamo pairs
(U+1100 U+1161 = 6-byte grapheme) must stay **uncomposed** (the `< 6` guard skips them, and there
are no single-char jamo keys) — full NFKC would compose them and would be *wrong* here.
