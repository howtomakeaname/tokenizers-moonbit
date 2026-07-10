---
title: Hub
createTime: 2026/07/10 00:00:00
---

# Hub

The optional `@hub` package handles online HuggingFace Hub access on native and
js targets. It downloads `tokenizer.json`, writes cache metadata and delegates
parsing to the core tokenizer package.

## Common APIs

```moonbit
@hub.from_pretrained(model_id)
@hub.download_tokenizer_json(model_id, options=opts)
@hub.HubDownloadOptions::new(...)
```

## Options

| Option | Purpose |
|---|---|
| `revision` | Branch, tag or commit |
| `cache_dir` | HF-style cache root |
| `endpoint` | Mirror or alternate Hub endpoint |
| `token` | Bearer token for private/gated repositories |
| `local_files_only` | Refuse network operations |
| `stream_chunk_size` | Streamed write granularity |

The core package remains useful without `@hub`: pass fetched JSON into
`Tokenizer::from_str` or use local cache paths.
