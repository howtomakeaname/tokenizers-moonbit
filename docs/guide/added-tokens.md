---
title: Added Tokens
createTime: 2026/07/10 00:00:00
---

# Added Tokens

Added tokens are tokenizer-level vocabulary entries that can be recognized
before ordinary model tokenization. They are used for special markers such as
`[MASK]`, `<s>`, `</s>` and application-specific sentinels.

## Regular and Special Added Tokens

```moonbit
let mask = @tokenizer.AddedToken::special("[MASK]")
let tag = @tokenizer.AddedToken::new("<tag>", single_word=true)

let tok = tok
  .add_special_tokens([mask])
  .add_tokens([tag])
```

| Flag | Effect |
|---|---|
| `single_word` | Match only when surrounded by word boundaries |
| `lstrip` | Include whitespace on the left in the token span |
| `rstrip` | Include whitespace on the right in the token span |
| `normalized` | Match after normalizer output instead of raw text |
| `special` | Register as a special added token |

`lstrip` and `rstrip` use Unicode whitespace behavior for mainstream HF parity,
including non-breaking spaces.

## Inline Specials and `encode_special_tokens`

Special tokens already present in input text are recognized as single tokens.
The `encode_special_tokens` switch changes whether special tokens embedded in
text are extracted as special added tokens or left on the ordinary model path.

```moonbit
let tok = tok.set_encode_special_tokens(true)
```

## Introspection

```moonbit
tok.get_added_tokens_decoder()
tok.get_all_special_tokens()
tok.get_all_special_ids()
tok.is_special_token("[MASK]")
```

These helpers mirror common Python binding shapes and make migration debugging
easier when a loaded `tokenizer.json` contains many sidecar-added tokens.
