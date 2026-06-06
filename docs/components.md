# Supported Components & Limitations

This page lists which `tokenizer.json` components are implemented. Unknown
component types raise `UnsupportedComponent` at load time (fail fast).

## Models

| `type` | Status | Notes |
|---|---|---|
| `BPE` / byte-level BPE | ✅ | `byte_fallback`, `fuse_unk`, `ignore_merges` supported |
| `WordPiece` | ✅ | greedy longest-match, `##` prefix, `max_input_chars_per_word` |
| `Unigram` | ✅ | Viterbi; `fuse_unk` (default true); `byte_fallback` field parsed |
| `WordLevel` | ✅ | whole-token lookup + unk |

## Normalizers

| `type` | Status |
|---|---|
| `Lowercase`, `Strip`, `Replace`, `Prepend`, `Sequence` | ✅ |
| `StripAccents` | ✅ (NFD-minus-Mn table) |
| `BertNormalizer` (clean_text / handle_chinese_chars / strip_accents / lowercase) | ✅ |
| `NFC` / `NFD` / `NFKC` / `NFKD` | ⏸ identity (see limitations) |
| `Precompiled` (SentencePiece charsmap) | ⏸ identity |
| `Nmt`, byte-level normalizer | ⬜ not yet |

## Pre-tokenizers

| `type` | Status |
|---|---|
| `ByteLevel` (GPT-2 scanner) | ✅ |
| `Whitespace`, `WhitespaceSplit`, `BertPreTokenizer`, `Punctuation`, `Metaspace`, `Sequence` | ✅ |
| `Split` with the GPT-2 / Qwen-Llama3 family regex | ✅ (covers modern LLMs) |
| `Split` with an arbitrary regex, `Digits`, `Delimiter`, `FixedLength`, `UnicodeScripts` | 🚧 unrecognized patterns fall back to a single piece |

## Post-processors

| `type` | Status |
|---|---|
| `TemplateProcessing`, `BertProcessing`, `RobertaProcessing`, `ByteLevel`, `Sequence` | ✅ |

## Decoders

| `type` | Status |
|---|---|
| `ByteLevel`, `WordPiece`, `BPEDecoder`, `Metaspace`, `Fuse`, `Replace`, `Strip`, `Sequence` | ✅ |
| `ByteFallback` | ✅ |
| `CTC` | ⬜ not yet |

## Verified models

Encode matches Python `tokenizers` token-for-token for: **gpt2, roberta,
bert, bert-cased, distilbert, t5, albert, xlm-roberta, llama, Qwen2.5, Qwen3,
DeepSeek-V2, Phi-3**.

## Limitations

- **Unicode normalization (NFC/NFKC):** currently identity. The verified models
  above do not depend on it for their tested inputs; pure-accent handling is
  covered by the `StripAccents` table. Full NFC/NFKC needs a larger Unicode
  table and is deferred.
- **Arbitrary `Split` regex:** only the well-known GPT-2 / Qwen-Llama3 family
  patterns are recognized (they are used verbatim by most models). Other
  regexes are not executed (the text passes through as one piece). MoonBit's
  core regex lacks `\p{L}`/`\p{N}` support, so a general engine is future work.
- **Offsets:** char-based, relative to the original text. HuggingFace's default
  `encode` returns byte offsets; byte-offset mode is future work.
- **Batching:** single-threaded by design (target is wasm/js).
- **Performance:** byte_fallback BPE (e.g. llama) uses a naive O(n²) merge
  without a priority-queue heap or word cache — correct but slow; optimization
  is tracked in `PROGRESS.md`.
- **Training:** out of scope. This library loads and runs existing tokenizers.
