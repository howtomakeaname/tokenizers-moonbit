---
title: 编码与解码
createTime: 2026/07/10 00:00:00
---

# 编码与解码

公开 encode API 会生成 `Encoding`，其中包含 ids、tokens、offsets、type ids、
attention masks、special-token masks、sequence ids 和 word ids。

## 单句、句对与批量

```moonbit
let one = tok.encode("Hello world")
let pair = tok.encode_pair("question", "context")
let batch = tok.encode_batch(["first text", "second text"])
let pair_batch = tok.encode_pair_batch([("question", "context")])
```

| API | 输入 | 输出 | 说明 |
|---|---|---|---|
| `encode` | 一个字符串 | `Encoding` | 完整 pipeline |
| `encode_pair` | 两个字符串 | `Encoding` | 句对 post-processing 与 type ids |
| `encode_batch` | 字符串数组 | `Array[Encoding]` | 共享批量 padding 行为 |
| `encode_pair_batch` | tuple 数组 | `Array[Encoding]` | 适合 BERT/reranker 负载 |

## `add_special_tokens=false`

MoonBit 遵循 HF 语义：`add_special_tokens=false` 只省略已配置 post-processor
注入的 special tokens。post-processor 仍会执行非 special 的效果。

| Processor | 省略 specials | 保留非 special 效果 |
|---|---:|---|
| `TemplateProcessing` | 是 | `type_ids`, `sequence_ids` |
| `BertProcessing` | 是 | 句对 `type_ids = 0/1`、句对 sequence ids |
| `RobertaProcessing` | 是 | ByteLevel 风格 offset trimming，所有 `type_ids = 0` |
| `ByteLevel` | N/A | offset trimming |

```moonbit
let enc = tok.encode_pair("hello", "world", add_special_tokens=false)
// no [CLS]/[SEP], but pair metadata still comes from the post-processor
```

## 预分词输入

```moonbit
let pre = tok.encode_pretokenized(["Hello", "world"])
let pair = tok.encode_pretokenized_pair(["question"], ["context"])
```

预分词 API 会跳过 tokenizer 配置的 pre-tokenizer，但仍会执行 normalization、
added-token extraction、model tokenization、post-processing、truncation 和
padding。Offsets 基于一个合成文本计算，该文本由归一化后的词用一个 ASCII 空格连接而成。

## Fast 与字节偏移变体

`encode_fast` 及批量 fast 变体会保持 ids、tokens、masks 和 sequence metadata
与普通 encode 路径一致，同时将 offsets 置零。无需 offsets 时可使用它们。

`encode_with_byte_offsets` 以及句对/预分词的字节偏移变体，会把字符 offset 转换为
HF 风格的 UTF-8 字节 offset。

## Decode

```moonbit
let text = tok.decode(enc.ids)
let raw = tok.decode(enc.ids, skip_special_tokens=false)
let texts = tok.decode_batch([enc.ids])
```

流式解码可通过 `DecodeStream::step` 使用，适合逐 token 生成循环。
