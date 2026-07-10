---
title: API Mapping
createTime: 2026/07/10 00:00:00
---

# API Mapping

This page groups common Python `tokenizers` calls and their MoonBit
equivalents.

## Loading

| Python | MoonBit | Notes |
|---|---|---|
| `Tokenizer.from_str(json)` | `Tokenizer::from_str(json)` | Backend-agnostic |
| `Tokenizer.from_file(path)` | `@tokenizer.from_file(path)` | Local file |
| `Tokenizer.from_pretrained(id)` | `@tokenizer.from_pretrained(id)` | Offline/local cache in core package |
| `Tokenizer.from_pretrained(id)` with network | `@hub.from_pretrained(id)` | Optional native/js package |

## Encoding

| Python | MoonBit | Notes |
|---|---|---|
| `tok.encode(text)` | `tok.encode(text)` | Single input |
| `tok.encode(text, pair)` | `tok.encode_pair(text, pair)` | Pair input |
| `tok.encode_batch(texts)` | `tok.encode_batch(texts)` | Batch input |
| `tok.encode(words, is_pretokenized=True)` | `tok.encode_pretokenized(words)` | Pre-tokenized words |
| `tok.encode_batch([(a, b), ...])` | `tok.encode_pair_batch([(a, b), ...])` | Pair batches |
| `tok.encode(text, add_special_tokens=False)` | `tok.encode(text, add_special_tokens=false)` | Non-special post-processing still runs |

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
