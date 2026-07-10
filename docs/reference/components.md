---
title: Components
createTime: 2026/07/10 00:00:00
---

# Components

Components can be loaded from `tokenizer.json` or constructed directly for
synthetic pipelines and tests.

| Component | Examples |
|---|---|
| Model | `Model::bpe`, `Model::wordpiece`, `Model::unigram`, `Model::wordlevel` |
| Normalizer | `Lowercase`, `BertNormalizer`, Unicode forms, `Sequence` |
| Pre-tokenizer | `ByteLevel`, `WhitespaceSplit`, `Split`, `Metaspace`, `Digits` |
| Post-processor | `TemplateProcessing`, `BertProcessing`, `RobertaProcessing`, `ByteLevel` |
| Decoder | `ByteLevel`, `WordPiece`, `Metaspace`, `ByteFallback`, `CTC` |

The full support matrix lives in
[Component Matrix](/tokenizers-moonbit/compatibility/components/).
