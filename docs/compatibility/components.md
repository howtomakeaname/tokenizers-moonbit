---
title: Component Matrix
createTime: 2026/07/10 00:00:00
---

# Component Matrix

## Models

| Model | Status | Notes |
|---|---:|---|
| BPE | Supported | byte fallback, fuse unk, dropout parsing, ignore merges |
| WordPiece | Supported | greedy longest match, prefix/suffix knobs |
| Unigram | Supported | Viterbi, strict missing `unk_id` error on unknown fallback |
| WordLevel | Supported | whole-token lookup with strict unk fallback |

## Pipeline Components

| Family | Supported examples | Notes |
|---|---|---|
| Normalizers | Lowercase, Strip, Replace, BertNormalizer, Unicode forms, NMT, Precompiled | Unicode tables and SentencePiece charsmap support |
| Pre-tokenizers | ByteLevel, Whitespace, BertPreTokenizer, Split, Metaspace, Digits, UnicodeScripts | Regex subset is deterministic and explicit |
| Post-processors | TemplateProcessing, BertProcessing, RobertaProcessing, ByteLevel, Sequence | `add_special_tokens=false` preserves non-special effects |
| Decoders | ByteLevel, WordPiece, BPE, Metaspace, Fuse, Replace, Strip, ByteFallback, CTC | Sequence composition supported |
| Trainers | WordLevel, WordPiece, BPE, Unigram MVPs | Deterministic trainer behavior with common HF knobs |

## Parser Strictness Highlights

| Area | Behavior |
|---|---|
| Model required fields | Missing `unk_token`, `merges`, WordPiece prefix/max fields rejected where HF requires them |
| Optional strings | Wrong typed optional strings rejected instead of treated as absent |
| Unigram `unk_id` | Missing/null allowed; wrong types/out-of-vocab rejected |
| `added_tokens` | Full HF schema required for present entries |
| Root truncation/padding | Required fields and enum casing match HF tokenizer JSON |

For exhaustive details, see the full component page:
[Supported Components & Limitations](/tokenizers-moonbit/components/).
