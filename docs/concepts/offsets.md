---
title: Offsets
createTime: 2026/07/10 00:00:00
---

# Offsets

Default offsets are MoonBit character offsets. Byte-offset variants are provided
for HF-style UTF-8 byte positions.

| API family | Offset unit | Notes |
|---|---|---|
| `encode` | character | Default MoonBit-friendly offsets |
| `encode_fast` | zeroed | Keeps ids/tokens/masks only |
| `encode_with_byte_offsets` | UTF-8 byte | Matches HF Python/Rust convention |
| pre-tokenized encode | synthetic character text | Normalized words joined by one ASCII space |

## Mapping Helpers

`Encoding` exposes token/word/char mapping helpers for alignment-heavy tasks:

```moonbit
enc.token_to_chars(0)
enc.char_to_token(3)
enc.word_to_tokens(1)
enc.token_to_word(2)
enc.sequence_ids()
```

## Post-processing Effects

ByteLevel and RoBERTa post-processors can trim whitespace offsets. This happens
even when `add_special_tokens=false`, because HF treats offset trimming as a
non-special post-processing effect.
