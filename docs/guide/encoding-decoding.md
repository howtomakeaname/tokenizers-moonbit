---
title: Encoding and Decoding
createTime: 2026/07/10 00:00:00
---

# Encoding and Decoding

The public encode APIs produce `Encoding` values with ids, tokens, offsets,
type ids, attention masks, special-token masks, sequence ids and word ids.

## Single, Pair and Batch

```moonbit
let one = tok.encode("Hello world")
let pair = tok.encode_pair("question", "context")
let batch = tok.encode_batch(["first text", "second text"])
let pair_batch = tok.encode_pair_batch([("question", "context")])
```

| API | Input | Output | Notes |
|---|---|---|---|
| `encode` | one string | `Encoding` | Full pipeline |
| `encode_pair` | two strings | `Encoding` | Pair post-processing and type ids |
| `encode_batch` | string array | `Array[Encoding]` | Shares batch padding behavior |
| `encode_pair_batch` | tuple array | `Array[Encoding]` | Useful for BERT/reranker workloads |

## `add_special_tokens=false`

MoonBit follows HF semantics: `add_special_tokens=false` omits only the special
tokens injected by the configured post-processor. The post-processor still runs
for non-special effects.

| Processor | Specials omitted | Non-special effects preserved |
|---|---:|---|
| `TemplateProcessing` | Yes | `type_ids`, `sequence_ids` |
| `BertProcessing` | Yes | pair `type_ids = 0/1`, pair sequence ids |
| `RobertaProcessing` | Yes | ByteLevel-style offset trimming, all `type_ids = 0` |
| `ByteLevel` | N/A | offset trimming |

```moonbit
let enc = tok.encode_pair("hello", "world", add_special_tokens=false)
// no [CLS]/[SEP], but pair metadata still comes from the post-processor
```

## Pre-tokenized Inputs

```moonbit
let pre = tok.encode_pretokenized(["Hello", "world"])
let pair = tok.encode_pretokenized_pair(["question"], ["context"])
```

Pre-tokenized APIs skip the tokenizer's configured pre-tokenizer, but still run
normalization, added-token extraction, model tokenization, post-processing,
truncation and padding. Offsets are measured against a synthetic text formed by
joining normalized words with one ASCII space.

## Fast and Byte-offset Variants

`encode_fast` and batch fast variants keep ids, tokens, masks and sequence
metadata aligned with normal encode paths while zeroing offsets. Use them when
offsets are not needed.

`encode_with_byte_offsets` and pair/pre-tokenized byte-offset variants convert
char offsets to HF-style UTF-8 byte offsets.

## Decode

```moonbit
let text = tok.decode(enc.ids)
let raw = tok.decode(enc.ids, skip_special_tokens=false)
let texts = tok.decode_batch([enc.ids])
```

Streaming decode is available through `DecodeStream::step` for token-by-token
generation loops.
