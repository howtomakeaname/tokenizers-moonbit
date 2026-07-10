---
title: Loading Tokenizers
createTime: 2026/07/10 00:00:00
---

# Loading Tokenizers

Loading is split between the all-target core package and the optional online
Hub package.

## Core Loaders

```moonbit
let tok1 = @tokenizer.Tokenizer::from_str(json_text)
let tok2 = @tokenizer.Tokenizer::from_buffer(bytes)
let tok3 = @tokenizer.from_file("tokenizer.json")
let tok4 = @tokenizer.from_pretrained("bert-base-uncased")
```

`from_pretrained` in the core package resolves local files, local directories
and already-populated HuggingFace cache snapshots. It does not perform network
IO, so it remains portable across wasm, wasm-gc, js and native.

## Online Hub Download

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

| Loader | Network | Cache writes | Targets | Typical use |
|---|---:|---:|---|---|
| `Tokenizer::from_str` | No | No | all | Host fetched JSON or embedded assets |
| `Tokenizer::from_buffer` | No | No | all | Binary resources in edge/browser runtimes |
| `from_file` | No | No | all | Local `tokenizer.json` |
| `@tokenizer.from_pretrained` | No | No | all | Offline HF cache or local export |
| `@hub.from_pretrained` | Yes | Yes | native/js | App-managed online download |

## Error Handling

All loaders can raise `@types.TokenizerError` on malformed JSON, missing
required tokenizer fields or unsupported components.

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
