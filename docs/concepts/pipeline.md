---
title: Pipeline
createTime: 2026/07/10 00:00:00
---

# Pipeline

The runtime follows the HuggingFace tokenizer pipeline while keeping each stage
explicit in MoonBit.

```mermaid
flowchart LR
  A[Load tokenizer.json] --> B[Normalizer]
  B --> C[AddedVocabulary stage 1]
  C --> D[Pre-tokenizer]
  D --> E[AddedVocabulary stage 2]
  E --> F[Model]
  F --> G[Post-processor]
  G --> H[Truncation]
  H --> I[Padding]
  I --> J[Encoding]
  J --> K[Decoder]
```

| Stage | Responsibility | Examples |
|---|---|---|
| Normalizer | Canonicalize text | Lowercase, NFKC, BertNormalizer |
| AddedVocabulary | Extract added/special tokens | `[MASK]`, `<|endoftext|>` |
| Pre-tokenizer | Split normalized text | ByteLevel, Whitespace, Split, Metaspace |
| Model | Map pieces to ids | BPE, WordPiece, Unigram, WordLevel |
| Post-processor | Add templates and metadata | BERT, RoBERTa, TemplateProcessing |
| Truncation | Enforce max length | LongestFirst, OnlyFirst, OnlySecond |
| Padding | Produce rectangular inputs | Fixed, BatchLongest |
| Decoder | Convert ids back to text | ByteLevel, WordPiece, Metaspace, CTC |

The `add_special_tokens` flag is post-processor specific: it controls injected
special tokens, not the entire post-processing stage. Non-special metadata and
offset transformations still run when the flag is false.
