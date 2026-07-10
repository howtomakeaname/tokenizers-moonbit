---
title: 加载 Tokenizer
createTime: 2026/07/10 00:00:00
---

# 加载 Tokenizer

加载能力分为全 target 可用的核心包，以及可选的在线 Hub 包。

## 核心加载器

```moonbit
let tok1 = @tokenizer.Tokenizer::from_str(json_text)
let tok2 = @tokenizer.Tokenizer::from_buffer(bytes)
let tok3 = @tokenizer.from_file("tokenizer.json")
let tok4 = @tokenizer.from_pretrained("bert-base-uncased")
```

核心包中的 `from_pretrained` 会解析本地文件、本地目录，以及已经填充好的
HuggingFace cache snapshot。它不执行网络 IO，因此可在 wasm、wasm-gc、js
和 native 间保持可移植。

## 在线 Hub 下载

```moonbit
let tok = @hub.from_pretrained("bert-base-uncased")

let opts = @hub.HubDownloadOptions::new(
  revision="main",
  cache_dir=Some(".hf-cache"),
  endpoint="https://hf-mirror.com",
  token=None,
)
let mirrored = @hub.from_pretrained("org/model", options=opts)
```

| 加载器 | 网络 | 写入 cache | Targets | 典型用途 |
|---|---:|---:|---|---|
| `Tokenizer::from_str` | 否 | 否 | all | 宿主已获取的 JSON 或内嵌资源 |
| `Tokenizer::from_buffer` | 否 | 否 | all | Edge/browser 运行时中的二进制资源 |
| `from_file` | 否 | 否 | all | 本地 `tokenizer.json` |
| `@tokenizer.from_pretrained` | 否 | 否 | all | 离线 HF cache 或本地导出 |
| `@hub.from_pretrained` | 是 | 是 | native/js | 应用管理的在线下载 |

## 错误处理

当 JSON 格式错误、缺少 tokenizer 必需字段，或包含暂不支持的组件时，所有加载器都可能抛出
`@types.TokenizerError`。

```moonbit
try {
  let tok = @tokenizer.Tokenizer::from_str(json_text)
  ...
} catch {
  @types.ParseError(msg) => println("bad tokenizer.json: \{msg}")
  @types.UnsupportedComponent(name) => println("unsupported: \{name}")
  err => println("tokenizer error")
}
```
