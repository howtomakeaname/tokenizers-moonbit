# Supported Components & Limitations

This page lists implemented `tokenizer.json` components. Unknown component
types raise `UnsupportedComponent` at load time.

Chinese version: [`docs/zh/components.md`](./zh/components.md)

## Models

| `type` | Status | Notes |
|---|---|---|
| `BPE` / byte-level BPE | ✅ | `byte_fallback`, `fuse_unk`, `ignore_merges` supported |
| `WordPiece` | ✅ | greedy longest-match, `##` prefix, `max_input_chars_per_word` |
| `Unigram` | ✅ | Viterbi; `byte_fallback` and `fuse_unk` supported |
| `WordLevel` | ✅ | whole-token lookup + unk |

## Normalizers

| `type` | Status |
|---|---|
| `Lowercase`, `Strip`, `Replace`, `Prepend`, `Sequence` | ✅ |
| `StripAccents` | ✅ (NFD-minus-Mn table) |
| `BertNormalizer` (clean_text / handle_chinese_chars / strip_accents / lowercase) | ✅ |
| `NFC` / `NFD` / `NFKC` / `NFKD` | ✅ Unicode table + decomposition/recomposition |
| `Nmt` | ✅ Moses/NMT cleanup for SentencePiece-era tokenizers |
| `ByteLevel` normalizer | ✅ UTF-8 bytes mapped to the GPT-2 byte alphabet |
| `Precompiled` (SentencePiece charsmap) | ✅ Parses SentencePiece binary double-array `precompiled_charsmap`; empty maps keep NFKC + full Unicode whitespace folding with ASCII fast path |

## Pre-tokenizers

| `type` | Status |
|---|---|
| `ByteLevel` (GPT-2 scanner) | ✅ |
| `Whitespace`, `WhitespaceSplit`, `BertPreTokenizer`, `Punctuation`, `Metaspace`, `Sequence` | ✅ |
| `Split` with GPT-2 / Qwen-Llama3 / o200k / CLIP / CJK / digit-triplet / trailing-whitespace regex families | ✅ |
| `Digits`, `Delimiter`, `FixedLength`, `UnicodeScripts` | ✅ |
| `Split` with arbitrary regex | 🚧 supported deterministic families load normally; unsupported JSON regex patterns raise `UnsupportedComponent` at load time (manually constructed runtime fallback remains one piece) |

## Post-processors

| `type` | Status |
|---|---|
| `TemplateProcessing`, `BertProcessing`, `RobertaProcessing`, `ByteLevel`, `Sequence` | ✅ |

## Decoders

| `type` | Status |
|---|---|
| `ByteLevel`, `WordPiece`, `BPEDecoder`, `Metaspace`, `Fuse`, `Replace`, `Strip`, `Sequence` | ✅ (`WordPiece` cleanup uses a single-pass BERT punctuation/contraction fast path) |
| `ByteFallback` | ✅ |
| `CTC` | ✅ |

## Verified models

With optional fixtures present, encode matches Python `tokenizers` token-for-token
for **31 real models**: gpt2, roberta, llama, bert/bert-cased, distilbert, t5,
albert, xlm-roberta, Qwen2.5, Qwen3, DeepSeek-V2, Phi-3, Mistral, Falcon,
StarCoder2, GPT-NeoX, CLIP, DeBERTa, Llama-3.2, Phi-4-mini,
DeepSeek-R1-Distill-Qwen, DeepSeek-V3.2, GPT-OSS, GLM-4.5, Granite-4,
Qwen3-Coder, Qwen3-VL, BGE-M3 and multilingual-E5.

## Limitations

- **Precompiled charsmap:** tokenizer.json `precompiled_charsmap` payloads are
  base64-decoded into the SentencePiece double-array trie and applied per Unicode
  scalar; empty/null maps retain the common SPM NFKC + Unicode whitespace folding
  path with an ASCII fast path.
- **Arbitrary `Split` regex:** well-known GPT-2 / Qwen-Llama3 / o200k / CLIP /
  CJK / digit-triplet patterns plus common simple spans such as `\s+`, `\S+`,
  `^\s+`, `\s+$`, `\s{2,}` / `\s{3,}` / `\s{4,}` and exact
  `\s{2}` / `\s{3}` / `\s{4}`, `[\r\n]+` with `{2,}` / `{3,}` /
  `{4,}` and exact `{2}` / `{3}` / `{4}` forms, `[^\S\r\n]+`-style
  horizontal whitespace (`[^\S\r\n]+` plus `{2,}` / `{3,}` / `{4,}` and
  exact `{2}` / `{3}` / `{4}` aliases), `\d+`, `\D+`,
  bracketed digit aliases (`[\d]+`, `[^\d]+`, `\P{N}+`), min digit runs
  (`\d{2,}` / `[\d]{2,}`), exact digit runs (`\d{2}` / `\d{3}` / `\d{4}`),
  bounded/ranged digit runs (`\d{1,2}` / `\d{1,3}` /
  `\d{1,4}` / `\d{2,4}` and `\p{N}` aliases),
  anchored digit/word/letter runs, word/letter quantifier runs (`\w{2,}` /
  `\w{2}` / `{1,2}` / `{1,3}` / `{1,4}` bounded plus `{2,3}` / `{2,4}` / `{3,4}` ranged word, ASCII letter/alnum and
  Unicode letter forms / `[A-Za-z]{2,}` / `\p{L}{3}`), punctuation/symbol quantifier runs
  (`\p{P}{2,}` / `\p{P}{2}` / `\p{S}{2}` / `{1,n}` bounded and `{2,n}` ranged punctuation,
  symbol and `\p{P}\p{S}` union forms / `[\p{P}\p{S}]{2,}`), inverse
  exact/min/bounded/ranged runs (`\D{3,}`, `\D{4}`, `\S{2,}`,
  `\W{2}`, `\P{L}{3,}`, `\P{P}{4}`, `\P{S}{2,}`, inverse ASCII classes,
  `[^\p{P}\p{S}]{3,}` and `[^\s\p{L}\p{N}]{4}`), `\w+`, `\W+`,
  ASCII alnum/letter classes (`[A-Za-z0-9]+`, `[A-Za-z]+` and inverse forms),
  `\p{L}+`, `\P{L}+`, punctuation
  classes (`\p{P}+` / `\P{P}+`) and symbol classes (`\p{S}+` / `\P{S}+`)
  are recognized, including common union/inverse classes such as
  `[\p{P}\p{S}]+` and `[^\s\p{L}\p{N}]+`.
  Unsupported regexes raise `UnsupportedComponent` at load time instead of
  silently producing mismatched splits. A full Unicode regex engine remains
  future work.
- **Regex `Replace`:** `Replace` normalizer/decoder supports common whitespace
  regex replacements such as `\s+`, anchored positive/inverse class runs such as
  `^\s+`, `\s+$`, `^\S+`, `\D+$`, `^\P{Letter}+`, `\P{Punctuation}+$`,
  `^[^\p{P}\p{S}]+` and `[^\s\p{L}\p{N}]+$`, `\s{2,}` / `\s{3,}` /
  `\s{4,}` and exact `\s{2}` / `\s{3}` / `\s{4}`, `[\r\n]+` with min/exact
  `{2..4}` quantifiers, `[^\S\r\n]+` and `[ \t]+` horizontal whitespace
  min/exact `{2..4}` forms, ` {2,}`, digit runs
  `\d+` / `[\d]+` / `\D+` / `\P{N}+`, min digit runs such as `\d{2,}` /
  `[\d]{2,}`, exact digit runs (`\d{2}` / `\d{3}` / `\d{4}`), word/letter
  quantifier runs (`\w{2,}` / `\w{3,}` / `\w{2}` / `{1,2}` / `{1,3}` / `{1,4}` bounded / `{2,3}` / `{2,4}` / `{3,4}` ranged
  word, ASCII letter/alnum and Unicode letter forms / `[A-Za-z]{2,}` / `\p{L}{3}`),
  punctuation/symbol quantifier runs (`\p{P}{2,}` / `\p{P}{2}` / `\p{S}{2}` /
  `{1,n}` bounded and `{2,n}` ranged punctuation, symbol and `\p{P}\p{S}` union forms /
  `[\p{P}\p{S}]{2,}`), common exact/min/bounded positive and inverse runs such as
  `\d{1,3}`, `\D{1,3}`, `\D{3,}`, `\D{4}`, `\W{1,2}`, `\W{2}`,
  `\P{L}{1,4}`, `\P{L}{3,}` and `[^\s\p{L}\p{N}]{1,3}` / `{4}`, anchored digit/word/letter/punctuation/symbol
  runs, word runs `\w+` / `\W+`,
  ASCII alnum/letter runs `[A-Za-z0-9]+` / `[A-Za-z]+` and inverse forms, and
  letter/punctuation/symbol runs (`\p{L}+`, `\p{P}+`, `\p{S}+` and inverse
  forms), plus common union/inverse classes like `[\p{P}\p{S}]+` and
  `[^\s\p{L}\p{N}]+`. Normalizer and Decoder `Replace` dispatch quantified
  bounded/ranged forms before the generic span-building fallback, keeping those
  micro paths direct and faster than HF; more complex regex replacement remains
  future work.
- **Offsets:** char-based by default, relative to the original text. Optional
  byte-offset encode APIs are available for HuggingFace-style byte offsets.
- **Batching:** single-threaded by design for wasm/js targets.
- **Performance:** BPE merging uses a priority-queue heap with lazy stale
  removal plus word caching; WordPiece and Unigram also cache repeated words;
  BPE loading fills dense reverse vocab tables directly; repeated/alternating
  `from_str` loads reuse a small parsed-JSON cache while constructing fresh
  tokenizer state each time.
- **Training:** deterministic WordLevel training is supported with default
  `WhitespaceSplit`, caller-provided pre-tokenizers, or pre-tokenized token
  streams, including `min_frequency`, `special_tokens`, `vocab_size`, and
  HF-style frequency/lexical vocab ordering. Deterministic WordPiece, BPE, and
  Unigram trainer MVPs are also available with the same input modes and common
  knobs such as continuation-prefix / end-of-word suffix /
  `max_input_chars_per_word` / `byte_fallback`; WordPiece and BPE training
  additionally support HF-style `initial_alphabet` / `limit_alphabet`, BPE also
  supports `max_token_length`, and `byte_level_alphabet()` exposes the 256
  ByteLevel symbols for GPT-2/RoBERTa style training.
- **Constructed tokenizer serialization:** trained WordLevel, WordPiece, BPE, and Unigram tokenizers serialize
  common pre-tokenizers such as ByteLevel, Metaspace, Punctuation, Split, Digits,
  Delimiter, FixedLength, UnicodeScripts, and Sequence.
