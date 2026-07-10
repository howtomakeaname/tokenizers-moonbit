---
title: Differences
createTime: 2026/07/10 00:00:00
---

# Differences

MoonBit 保持运行时显式且类型化，同时在加载 tokenizer 文件时保留关键的 HF tokenizer 语义。

| Topic | Python tokenizers | MoonBit |
|---|---|---|
| Optional values | `None` | `Option` / `None` |
| Enums | 通常是字符串 | 带类型的枚举；必要处提供 HF 字符串辅助函数 |
| Mutating APIs | 原地赋值风格 | 返回新 tokenizer 的构建器 API，并提供 `set_*` 别名 |
| Offsets | UTF-8 字节 offset | 默认字符 offset；也提供字节 offset API |
| Online Hub | Python 生态内置 | native/js 可选 `@hub` 包 |
| Regex | Rust regex 引擎 | 确定性支持的模式族；不支持的模式会显式报错 |
| Batch parallelism | Rust 端可能使用 rayon | 跨目标保持稳定顺序的串行核心 |

## Return-new Builder Style

```moonbit
let tok = Tokenizer::new(model)
  .with_pre_tokenizer(Some(@pretokenizer.PreTokenizer::whitespace_split()))
  .with_padding(Some(@tokenizer.PaddingParams::fixed(128)))
```

`set_*` 别名保留同样的“返回新 tokenizer”语义，同时让 Python 绑定层更容易映射。

## Errors

解析和分词 API 可能抛出 `TokenizerError` 变体，例如 `ParseError`、`UnsupportedComponent`、`VocabError` 和 `IoError`。
