---
title: Types and Errors
createTime: 2026/07/10 00:00:00
---

# Types and Errors

`@types` 包包含共享运行时值，例如 `Encoding`、`Token`、`Split`、`NormalizedString`、`PreTokenizedString` 和 `TokenizerError`。

## Encoding Fields

| Field | Meaning |
|---|---|
| `ids` | token id |
| `tokens` | token 的表面字符串 |
| `type_ids` | segment/template id |
| `offsets` | 字符或字节跨度，取决于所用 API |
| `special_tokens_mask` | 特殊 token/pad token 为 1 |
| `attention_mask` | padding 为 0 |
| `sequence_ids` | 单输入/文本对中的序列归属 |
| `word_ids` | 预分词输入中的词归属 |

## Error Variants

| Error | Typical source |
|---|---|
| `ParseError` | tokenizer JSON 格式错误或字段类型不对 |
| `UnsupportedComponent` | 不支持的 tokenizer 组件或正则表达式 |
| `VocabError` | 缺少未知 token 回退、vocab 引用错误 |
| `IoError` | 文件/缓存操作 |
