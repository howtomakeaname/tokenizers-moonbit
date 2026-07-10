---
title: Added Tokens
createTime: 2026/07/10 00:00:00
---

# Added Tokens

Added tokens 是 tokenizer 级词表项，可在普通 model tokenization 之前被识别。
它们常用于 `[MASK]`、`<s>`、`</s>` 等 special marker，以及应用自定义 sentinel。

## 普通 Added Token 与 Special Added Token

```moonbit
let mask = @tokenizer.AddedToken::special("[MASK]")
let tag = @tokenizer.AddedToken::new("<tag>", single_word=true)

let tok = tok
  .add_special_tokens([mask])
  .add_tokens([tag])
```

| Flag | 效果 |
|---|---|
| `single_word` | 仅在被词边界包围时匹配 |
| `lstrip` | 在 token span 中包含左侧空白 |
| `rstrip` | 在 token span 中包含右侧空白 |
| `normalized` | 在 normalizer 输出上匹配，而不是在原始文本上匹配 |
| `special` | 注册为 special added token |

`lstrip` 和 `rstrip` 使用 Unicode 空白行为，以对齐主流 HF 语义，包括不换行空格。

## 内联 Specials 与 `encode_special_tokens`

输入文本中已经出现的 special token 会被识别为单个 token。
`encode_special_tokens` 开关控制文本中内嵌的 special tokens 是作为 special
added tokens 提取，还是留在普通 model 路径上。

```moonbit
let tok = tok.set_encode_special_tokens(true)
```

## 自省

```moonbit
tok.get_added_tokens_decoder()
tok.get_all_special_tokens()
tok.get_all_special_ids()
tok.is_special_token("[MASK]")
```

这些 helper 对齐常见 Python binding 形状；当加载的 `tokenizer.json` 包含大量附带
added tokens 时，它们能让迁移调试更直接。
