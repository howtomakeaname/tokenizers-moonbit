# tokenizers-moonbit

MoonBit 版 HuggingFace `tokenizers`。直接加载标准 `tokenizer.json`，在
`wasm`、`wasm-gc`、`js`、`native` 后端运行同一套 encode/decode 实现，无 native
依赖。

项目定位：面向 LLM、边缘端和浏览器场景，在 Rust `tokenizers` 不便直接分发或
集成成本较高时，提供纯 MoonBit 的 tokenizer 运行时。

英文主页：[`README.md`](./README.md)

## 目标

- **跨后端一致。** 同一份 MoonBit 源码编译到 wasm/wasm-gc/js/native，不依赖 FFI
  或平台二进制。
- **对齐 HuggingFace。** 使用 Python `tokenizers` 生成期望结果，对真实模型做
  token id 级对拍。
- **直接复用 `tokenizer.json`。** 不需要转换格式，可复用 Python/Transformers
  流水线中的 tokenizer 文件。
- **可选 Hub 下载。** 核心 loader 保持全后端/离线可用；`hub` 包可在 native/js
  后端在线下载 `tokenizer.json`，并写入 HuggingFace 风格 cache。

## 支持范围

- **模型：** BPE、byte-level BPE（含 `byte_fallback` / `fuse_unk` /
  `ignore_merges`）、WordPiece、Unigram、WordLevel。
- **流水线：** Normalizer → Pre-tokenizer → Model → Post-processor → Decoder；
  另支持 AddedVocabulary，用于识别文本中的 special/added token。
- **API：** `encode`、`encode_pair`、`encode_batch`、`decode`、truncation、
  padding、`token_to_id`、`id_to_token`、`get_vocab_size`。

在可选 fixture 存在时，对拍覆盖 40 个真实模型：gpt2、roberta、llama、
bert/bert-cased、distilbert、t5、albert、xlm-roberta、Qwen/DeepSeek/Phi/Mistral/
Falcon/StarCoder/GPT-NeoX/CLIP/GLM/Granite 家族、ModernBERT/GTE-ModernBERT、
SmolLM2，以及 BGE、E5、MiniLM、Jina、Nomic、MixedBread 等 embedding tokenizer。

组件状态见 [`docs/zh/components.md`](./docs/zh/components.md)，路线图见
[`PROGRESS.md`](./PROGRESS.md)。

## 文档

- [使用指南](./docs/zh/usage.md)
- [API 参考](./docs/zh/api.md)
- [组件与限制](./docs/zh/components.md)
- [从 HuggingFace 迁移](./docs/zh/migration-from-hf.md)
- [Benchmark](./docs/zh/benchmarks.md)

## 快速开始

```moonbit
let tok = @tokenizer.Tokenizer::from_str(json_text)
// 或：let tok = @tokenizer.from_file("tokenizer.json")
// native/js 可选：let tok = @hub.from_pretrained("bert-base-uncased")
// 镜像：let tok = @hub.from_pretrained("bert-base-uncased", options=@hub.HubDownloadOptions::new(endpoint="https://hf-mirror.com"))

let enc = tok.encode("Hello world")
println(enc.ids)
println(enc.tokens)

let pair = tok.encode_pair("question", "context")
let text = tok.decode(enc.ids, skip_special_tokens=true)
```

`encode(text, add_special_tokens=false)` 会跳过 post-processor 模板；文本中已有的
special token 仍会被识别。

## 测试

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon test
moon test --target native
```

完整模型对拍需要下载大文件 fixture：

```bash
python3 scripts/fetch_models.py
pip install tokenizers
python3 scripts/gen_parity.py
moon test --target native
```

fixture 缺失时，对拍测试自动跳过。

## License

Apache-2.0。实现参考 HuggingFace `tokenizers` 的算法与文件格式。
