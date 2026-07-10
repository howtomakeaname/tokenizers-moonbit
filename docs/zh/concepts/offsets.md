---
title: Offsets
createTime: 2026/07/10 00:00:00
---

# Offsets

默认 offset 是 MoonBit 字符 offset。另提供 byte-offset 变体，用于兼容
HuggingFace 风格的 UTF-8 字节位置。

| API 族 | Offset 单位 | 说明 |
|---|---|---|
| `encode` | 字符 | 默认的 MoonBit 友好 offset |
| `encode_fast` | 置零 | 仅保留 ids/tokens/masks |
| `encode_with_byte_offsets` | UTF-8 字节 | 匹配 HF Python/Rust 约定 |
| pre-tokenized encode | 合成字符文本 | 规范化后的词用一个 ASCII 空格连接 |

## Mapping Helpers

`Encoding` 暴露 token/word/char 映射辅助方法，适合需要对齐的任务：

```moonbit
enc.token_to_chars(0)
enc.char_to_token(3)
enc.word_to_tokens(1)
enc.token_to_word(2)
enc.sequence_ids()
```

## Post-processing Effects

ByteLevel 和 RoBERTa post-processor 可以裁剪空白 offset。即使
`add_special_tokens=false`，该行为也会发生，因为 HF 将 offset 裁剪视为
非 special 的 post-processing 效果。
