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
| `Precompiled` (SentencePiece charsmap) | 🚧 common whitespace folding; full charsmap TODO |
| `Nmt`, byte-level normalizer | ⬜ not yet |

## Pre-tokenizers

| `type` | Status |
|---|---|
| `ByteLevel` (GPT-2 scanner) | ✅ |
| `Whitespace`, `WhitespaceSplit`, `BertPreTokenizer`, `Punctuation`, `Metaspace`, `Sequence` | ✅ |
| `Split` with GPT-2 / Qwen-Llama3 / o200k / CLIP / CJK / digit-triplet regex families | ✅ |
| `Digits`, `Delimiter`, `FixedLength` | ✅ |
| `Split` with arbitrary regex, `UnicodeScripts` | 🚧 unrecognized patterns fall back to one piece |

## Post-processors

| `type` | Status |
|---|---|
| `TemplateProcessing`, `BertProcessing`, `RobertaProcessing`, `ByteLevel`, `Sequence` | ✅ |

## Decoders

| `type` | Status |
|---|---|
| `ByteLevel`, `WordPiece`, `BPEDecoder`, `Metaspace`, `Fuse`, `Replace`, `Strip`, `Sequence` | ✅ |
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

- **Precompiled charsmap:** common SentencePiece whitespace folding is covered;
  full binary charsmap decoding is still TODO.
- **Arbitrary `Split` regex:** well-known GPT-2 / Qwen-Llama3 / o200k / CLIP /
  CJK / digit-triplet patterns are recognized. Other regexes are not executed
  and pass through as one piece. MoonBit's core regex lacks `\p{L}`/`\p{N}`
  support, so a general Unicode regex engine is future work.
- **Offsets:** char-based, relative to the original text. HuggingFace's default
  `encode` returns byte offsets; byte-offset mode is future work.
- **Batching:** single-threaded by design for wasm/js targets.
- **Performance:** BPE merging uses a priority-queue heap with lazy stale
  removal. A word-to-token cache and faster multi-MB vocab loading remain useful
  optimizations.
- **Training:** out of scope. The library loads and runs existing tokenizers.
