---
title: Truncation and Padding
createTime: 2026/07/10 00:00:00
---

# Truncation and Padding

Truncation and padding are tokenizer-level configuration steps. They can be
loaded from `tokenizer.json` or configured programmatically.

## Truncation

```moonbit
let tok = tok.enable_truncation(
  128,
  stride=16,
  strategy=LongestFirst,
  direction=Right,
)
```

HF-style string helpers are available for binding layers:

```moonbit
let tok = tok.enable_truncation_hf(
  128,
  strategy="longest_first",
  direction="right",
)
```

| Strategy | Use case | Notes |
|---|---|---|
| `LongestFirst` | General single/pair inputs | Removes from the longest side |
| `OnlyFirst` | Query truncation | Raises when the first sequence cannot absorb the removal |
| `OnlySecond` | Context truncation | Common for question/context tasks |

With `stride > 0`, truncated windows appear in `enc.overflowing`.

## Padding

```moonbit
let fixed = tok.enable_padding(length=Some(64), pad_token="[PAD]")
let batch = tok.enable_padding() // BatchLongest
```

| Strategy | Behavior | Best for |
|---|---|---|
| `Fixed(n)` | Every encoding padded to `n` | Model input tensors |
| `BatchLongest` | Each batch padded to longest member | Dynamic batching |

Padded positions use `attention_mask = 0` and `special_tokens_mask = 1`.

## tokenizer.json Strictness

Root-level `truncation` and `padding` objects follow HF tokenizer JSON schema.
Missing required fields or wrong enum casing raises `ParseError` instead of
falling back silently.

| Root object | Required fields |
|---|---|
| `truncation` | `max_length`, `stride`, `strategy`; `direction` defaults to `Right` when omitted |
| `padding` | `strategy`, `direction`, `pad_id`, `pad_type_id`, `pad_token` |

For fixed padding in root JSON, `strategy` must be encoded as `{"Fixed": n}`.
