---
title: Tokenizer
createTime: 2026/07/10 00:00:00
---

# Tokenizer

`Tokenizer` 是加载、编码、解码、配置、保存/读取、added tokens 和训练的高层门面。

## Loading

```moonbit
Tokenizer::from_str(json)
Tokenizer::from_buffer(bytes)
@tokenizer.from_file("tokenizer.json")
@tokenizer.from_pretrained("bert-base-uncased")
```

## Encode

```moonbit
tok.encode(text)
tok.encode_pair(a, b)
tok.encode_batch(texts)
tok.encode_pretokenized(words)
tok.encode_input(input)
```

快速变体会清零 offset，但保持 id、token、mask 和序列元数据对齐。

## Configuration

```moonbit
tok.with_normalizer(...)
tok.with_pre_tokenizer(...)
tok.with_model(...)
tok.with_post_processor(...)
tok.with_decoder(...)
tok.with_truncation(...)
tok.with_padding(...)
```

`set_*` 别名模拟可写属性的绑定风格，同时保留返回新 tokenizer 的语义。

## Save and Pretrained Artifacts

```moonbit
tok.to_json()
tok.save(path, pretty=true)
tok.save_pretrained(dir)
```

完整 API 页面包含详尽的签名列表：
[API Reference](/tokenizers-moonbit/zh/api/)。
