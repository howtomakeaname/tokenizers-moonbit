---
title: API Mapping
createTime: 2026/07/10 00:00:00
---

# API Mapping

本页按场景汇总 Python `tokenizers` 的常用调用及其 MoonBit 对应写法。

## Loading

| Python | MoonBit | Notes |
|---|---|---|
| `Tokenizer.from_str(json)` | `Tokenizer::from_str(json)` | 后端无关 |
| `Tokenizer.from_file(path)` | `@tokenizer.from_file(path)` | 本地文件 |
| `Tokenizer.from_pretrained(id)` | `@tokenizer.from_pretrained(id)` | 核心包中的离线/本地缓存 |
| 带网络的 `Tokenizer.from_pretrained(id)` | `@hub.from_pretrained(id)` | 可选 native/js 包 |

## Encoding

| Python | MoonBit | Notes |
|---|---|---|
| `tok.encode(text)` | `tok.encode(text)` | 单输入 |
| `tok.encode(text, pair)` | `tok.encode_pair(text, pair)` | 文本对输入 |
| `tok.encode_batch(texts)` | `tok.encode_batch(texts)` | 批量输入 |
| `tok.encode(words, is_pretokenized=True)` | `tok.encode_pretokenized(words)` | 已预分词的词序列 |
| `tok.encode_batch([(a, b), ...])` | `tok.encode_pair_batch([(a, b), ...])` | 文本对批量输入 |
| `tok.encode(text, add_special_tokens=False)` | `tok.encode(text, add_special_tokens=false)` | 非特殊 token 的后处理仍会执行 |

## Decoding

| Python | MoonBit |
|---|---|
| `tok.decode(ids)` | `tok.decode(ids)` |
| `tok.decode(ids, skip_special_tokens=False)` | `tok.decode(ids, skip_special_tokens=false)` |
| `tok.decode_batch(batch)` | `tok.decode_batch(batch)` |

## Vocabulary and Metadata

| Python | MoonBit |
|---|---|
| `tok.token_to_id(token)` | `tok.token_to_id(token)` |
| `tok.id_to_token(id)` | `tok.id_to_token(id)` |
| `tok.get_vocab_size()` | `tok.get_vocab_size()` |
| `tok.get_vocab(with_added_tokens=True)` | `tok.get_vocab(with_added_tokens=true)` |
| `encoding.ids` | `enc.ids` |
| `encoding.tokens` | `enc.tokens` |
| `encoding.type_ids` | `enc.type_ids` |
| `encoding.attention_mask` | `enc.attention_mask` |
