---
title: Tokenizer
createTime: 2026/07/10 00:00:00
---

# Tokenizer

`Tokenizer` is the high-level facade for loading, encoding, decoding,
configuration, save/load, added tokens and training.

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

Fast variants zero offsets but keep ids/tokens/masks/sequence metadata aligned.

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

`set_*` aliases mirror writable-property binding style while preserving
return-new-tokenizer semantics.

## Save and Pretrained Artifacts

```moonbit
tok.to_json()
tok.save(path, pretty=true)
tok.save_pretrained(dir)
```

The full API page contains the exhaustive signature list:
[API Reference](/tokenizers-moonbit/api/).
