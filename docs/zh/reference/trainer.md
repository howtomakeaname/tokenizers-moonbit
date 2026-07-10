---
title: Trainer
createTime: 2026/07/10 00:00:00
---

# Trainer

训练 API 为常见的 WordLevel、WordPiece、BPE 和 Unigram 流程提供确定性的 MoonBit 实现。

## Entry Points

```moonbit
Tokenizer::train(...)
Tokenizer::train_from_iterator(...)
Tokenizer::train_from_files(...)
Trainer::wordlevel_trainer(...)
Trainer::wordpiece_trainer(...)
Trainer::bpe_trainer(...)
Trainer::unigram_trainer(...)
```

## Common Knobs

| Knob | Applies to | Notes |
|---|---|---|
| `vocab_size` | all | 输出词表上限 |
| `min_frequency` | WordLevel / WordPiece / BPE | 频次阈值 |
| `special_tokens` | all | 字符串特殊 token |
| `special_added_tokens` | all | 保留 AddedToken 元数据的特殊 token |
| `initial_alphabet` | WordPiece / BPE / Unigram | 必需的初始 alphabet |
| `limit_alphabet` | WordPiece / BPE | alphabet 上限 |
| `byte_fallback` | BPE / Unigram | 现代 LLM tokenizer 支持 |

为兼容 Python 绑定，训练器状态和 getter 别名也会暴露。
