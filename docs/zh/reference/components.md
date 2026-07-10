---
title: Components
createTime: 2026/07/10 00:00:00
---

# Components

组件既可以从 `tokenizer.json` 加载，也可以为合成流水线和测试直接构造。

| Component | Examples |
|---|---|
| Model | `Model::bpe`, `Model::wordpiece`, `Model::unigram`, `Model::wordlevel` |
| Normalizer | `Lowercase`, `BertNormalizer`, Unicode forms, `Sequence` |
| Pre-tokenizer | `ByteLevel`, `WhitespaceSplit`, `Split`, `Metaspace`, `Digits` |
| Post-processor | `TemplateProcessing`, `BertProcessing`, `RobertaProcessing`, `ByteLevel` |
| Decoder | `ByteLevel`, `WordPiece`, `Metaspace`, `ByteFallback`, `CTC` |

完整支持矩阵见
[Component Matrix](/tokenizers-moonbit/zh/compatibility/components/)。
