---
title: Differences
createTime: 2026/07/10 00:00:00
---

# Differences

MoonBit keeps the runtime explicit and typed while preserving HF tokenizer
semantics where it matters for loaded tokenizer files.

| Topic | Python tokenizers | MoonBit |
|---|---|---|
| Optional values | `None` | `Option` / `None` |
| Enums | Often strings | Typed enums with HF string helpers where useful |
| Mutating APIs | In-place assignment style | Builder-style return-new-tokenizer APIs plus `set_*` aliases |
| Offsets | UTF-8 byte offsets | Character offsets by default; byte-offset APIs available |
| Online Hub | Built into Python ecosystem | Optional `@hub` package for native/js |
| Regex | Rust regex engine | Deterministic supported families; unsupported patterns explicit |
| Batch parallelism | Rust may use rayon | Stable-order serial core across targets |

## Return-new Builder Style

```moonbit
let tok = Tokenizer::new(model)
  .with_pre_tokenizer(Some(@pretokenizer.PreTokenizer::whitespace_split()))
  .with_padding(Some(@tokenizer.PaddingParams::fixed(128)))
```

The `set_*` aliases preserve the same return-new-tokenizer semantics while
making Python binding layers easier to map.

## Errors

Parsing and tokenization APIs can raise `TokenizerError` variants such as
`ParseError`, `UnsupportedComponent`, `VocabError` and `IoError`.
