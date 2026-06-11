# 使用指南

`tokenizers-moonbit` 直接加载 HuggingFace `tokenizer.json`，在 MoonBit 各后端执行
encode/decode。

英文版：[`../usage.md`](../usage.md)

## 加载

```moonbit
let tok = @tokenizer.Tokenizer::from_str(json_text)
let tok = @tokenizer.from_file("tokenizer.json")
```

JSON 非法或组件暂不支持时会抛出 `@types.TokenizerError`。

### HuggingFace Hub

核心 `@tokenizer.from_pretrained` 保持同步、全后端可用：它只解析本地文件/目录或
已有 HuggingFace Hub cache。native/js 应用如果需要在线下载，可使用可选 `@hub` 包：

```moonbit
let tok = @hub.from_pretrained("bert-base-uncased")

let opts = @hub.HubDownloadOptions::new(
  revision="main",
  cache_dir=Some(".hf-cache"),
  endpoint="https://hf-mirror.com", // 可选镜像 URL
)
let tok2 = @hub.from_pretrained("org/model", options=opts)
```

`@hub` 会下载 `tokenizer.json`、写入 HF 风格 cache，然后复用核心 loader。native 请求会使用
接近 HuggingFace/tokenizers 客户端的 User-Agent 与标准 `Accept`/`Authorization` headers；
JS/browser 因 fetch 禁止手动设置 User-Agent，会使用运行时提供的 UA。wasm/
wasm-gc 场景可由宿主环境 fetch JSON 后调用
`@tokenizer.from_pretrained_downloaded(model_id, json_text, cache_dir=...)`。

## 编码

```moonbit
let enc = tok.encode("Hello world")
// enc.ids                 : Array[Int]
// enc.tokens              : Array[String]
// enc.type_ids            : Array[Int]
// enc.attention_mask      : Array[Int]
// enc.special_tokens_mask : Array[Int]
// enc.offsets             : Array[(Int, Int)]   // 字符偏移
```

`add_special_tokens` 默认值为 `true`，控制是否执行 post-processor 模板。文本中
直接出现的 special token 会照常识别。

```moonbit
let enc = tok.encode("text", add_special_tokens=false)
```

## 句对与批量

```moonbit
let pair = tok.encode_pair("question", "context")
let batch = tok.encode_batch(["first text", "second"])
```

`encode_batch` 为串行实现。需要矩阵形输出时，配合 padding 使用。

## 解码

```moonbit
let text = tok.decode(enc.ids)
let raw = tok.decode(enc.ids, skip_special_tokens=false)
```

## 截断

```moonbit
let tok = @tokenizer.Tokenizer::from_str(json)
  .with_truncation(Some(@tokenizer.TruncationParams::new(128)))
let enc = tok.encode(long_text)
```

`TruncationParams` 包含 `max_length`、`stride`、`direction`。`stride > 0` 时，
溢出窗口写入 `enc.overflowing`。

## Padding

```moonbit
let tok = @tokenizer.Tokenizer::from_str(json)
  .with_padding(Some(@tokenizer.PaddingParams::new(Fixed(64))))

let tok = @tokenizer.Tokenizer::from_str(json)
  .with_padding(Some(@tokenizer.PaddingParams::new(BatchLongest)))
let batch = tok.encode_batch(texts)
```

padding 位置的 `attention_mask = 0`，`special_tokens_mask = 1`。

## 词表查询

```moonbit
tok.token_to_id("[CLS]")
tok.id_to_token(101)
tok.get_vocab_size()
```
