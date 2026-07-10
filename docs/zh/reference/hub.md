---
title: Hub
createTime: 2026/07/10 00:00:00
---

# Hub

可选的 `@hub` 包在 native 和 js 目标上处理在线 HuggingFace Hub 访问。它会下载 `tokenizer.json`、写入缓存元数据，并把解析交给核心 tokenizer 包。

## Common APIs

```moonbit
@hub.from_pretrained(model_id)
@hub.download_tokenizer_json(model_id, options=opts)
@hub.HubDownloadOptions::new(...)
```

## Options

| Option | Purpose |
|---|---|
| `revision` | 分支、标签或提交 |
| `cache_dir` | HF 风格的缓存根目录 |
| `endpoint` | 镜像或替代 Hub 端点 |
| `token` | 私有/受限仓库的 Bearer token |
| `local_files_only` | 拒绝网络操作 |
| `stream_chunk_size` | 流式写入粒度 |

不使用 `@hub` 时核心包仍然可用：把已获取的 JSON 传给 `Tokenizer::from_str`，或使用本地缓存路径。
