---
title: Pipeline
createTime: 2026/07/10 00:00:00
---

# Pipeline

运行时遵循 HuggingFace tokenizer pipeline，同时在 MoonBit 中显式保留每个阶段。

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

| 阶段 | 职责 | 示例 |
|---|---|---|
| Normalizer | 规范化文本 | Lowercase, NFKC, BertNormalizer |
| AddedVocabulary | 提取 added/special token | `[MASK]`, `<|endoftext|>` |
| Pre-tokenizer | 拆分规范化后的文本 | ByteLevel, Whitespace, Split, Metaspace |
| Model | 将片段映射为 id | BPE, WordPiece, Unigram, WordLevel |
| Post-processor | 添加模板和元数据 | BERT, RoBERTa, TemplateProcessing |
| Truncation | 限制最大长度 | LongestFirst, OnlyFirst, OnlySecond |
| Padding | 生成矩形输入 | Fixed, BatchLongest |
| Decoder | 将 id 转回文本 | ByteLevel, WordPiece, Metaspace, CTC |

`add_special_tokens` 标志由 post-processor 解释：它控制注入的 special token，
而不是关闭整个 post-processing 阶段。即使该标志为 false，非 special
元数据和 offset 变换仍会执行。
