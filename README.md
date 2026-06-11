# tokenizers-moonbit

A MoonBit port of [HuggingFace `tokenizers`](https://github.com/huggingface/tokenizers).

Load a standard `tokenizer.json` and run encode/decode across **all MoonBit
backends** — `wasm`, `wasm-gc`, `js`, `native` — with no native dependencies.
The project targets LLM, edge and browser use cases where the Rust
`tokenizers` crate is unavailable or heavy to ship.

> Status: actively developed. See [`PROGRESS.md`](./PROGRESS.md) for the full
> capability matrix and roadmap.
>
> 中文文档：[`README.zh.md`](./README.zh.md)

## Why this project

- **Runs everywhere MoonBit runs.** One pure-MoonBit implementation compiles to
  wasm/wasm-gc/js/native. No FFI, no platform-specific binaries.
- **Faithful to HuggingFace.** Output is checked token-for-token against the
  Python `tokenizers` library for real models, including classic encoders,
  modern LLM tokenizers, coder tokenizers, multimodal tokenizers and embedding
  tokenizers.
- **Loads `tokenizer.json` directly.** No conversion step; use the same file as
  your Python or Transformers pipeline.
- **Optional Hub download.** The core loader stays all-backend/offline, while the
  `hub` package can download `tokenizer.json` on native/js and populate the same
  HuggingFace-style cache layout.

## Supported

- **Models:** BPE, byte-level BPE (with `byte_fallback` / `fuse_unk` /
  `ignore_merges`), WordPiece, Unigram, WordLevel.
- **Pipeline:** Normalizer → Pre-tokenizer → Model → Post-processor → Decoder,
  plus AddedVocabulary for special/added tokens such as `<|endoftext|>` and
  `[MASK]`, including `single_word`, `lstrip`, `rstrip` and `normalized` flags.
- **API:** `encode`, `encode_pair`, `encode_batch`, `decode`, truncation and
  padding builders, `token_to_id`, `id_to_token`, `get_vocab_size`.

With optional fixtures present, parity tests compare against Python
`tokenizers` across **40 real models**: gpt2, roberta, llama, bert/bert-cased,
distilbert, t5, albert, xlm-roberta, Qwen/DeepSeek/Phi/Mistral/Falcon/
StarCoder/GPT-NeoX/CLIP/GLM/Granite families, ModernBERT/GTE-ModernBERT,
SmolLM2, and embedding tokenizers such as BGE, E5, MiniLM, Jina, Nomic and
MixedBread.

See [`docs/components.md`](./docs/components.md) for per-component status and
known gaps, and [`PROGRESS.md`](./PROGRESS.md) for the roadmap.

## Documentation

- [Usage guide](./docs/usage.md) — loading, encode/decode, truncation, padding, batches
- [API reference](./docs/api.md)
- [Supported components & limitations](./docs/components.md)
- [Migrating from HuggingFace](./docs/migration-from-hf.md)
- [Benchmarks](./docs/benchmarks/README.md)
- [中文文档](./README.zh.md)

## Quick start

```moonbit
// Load from a tokenizer.json string (backend-agnostic, no file IO):
let tok = @tokenizer.Tokenizer::from_str(json_text)

// Or load from a file (uses moonbitlang/x/fs, available on all backends):
let tok = @tokenizer.from_file("tokenizer.json")

// Native/js only: download from HuggingFace Hub through the optional hub package:
let tok = @hub.from_pretrained("bert-base-uncased")

// Use a HuggingFace-compatible mirror when needed:
let tok = @hub.from_pretrained(
  "bert-base-uncased",
  options=@hub.HubDownloadOptions::new(endpoint="https://hf-mirror.com"),
)

// Encode:
let enc = tok.encode("Hello world")
println(enc.ids)            // [Int]
println(enc.tokens)         // [String]
println(enc.attention_mask) // [Int]

// Encode a pair (adds [CLS]/[SEP] etc. via the post-processor):
let pair = tok.encode_pair("question", "context")

// Decode:
let text = tok.decode(enc.ids, skip_special_tokens=true)
```

`encode(text, add_special_tokens=false)` skips the post-processor template.
Special tokens already present in the text are still recognized.

## Migrating from HuggingFace

If you already use Python `tokenizers` or Transformers, see the
[migration guide](./docs/migration-from-hf.md) for a side-by-side API mapping.

| HuggingFace (Python) | MoonBit |
|---|---|
| `Tokenizer.from_file("tokenizer.json")` | `@tokenizer.from_file("tokenizer.json")` |
| `tok.encode(text)` | `tok.encode(text)` |
| `tok.encode(text, add_special_tokens=False)` | `tok.encode(text, add_special_tokens=false)` |
| `tok.encode(a, b)` | `tok.encode_pair(a, b)` |
| `tok.decode(ids, skip_special_tokens=True)` | `tok.decode(ids, skip_special_tokens=true)` |
| `enc.ids / enc.tokens / enc.attention_mask` | `enc.ids / enc.tokens / enc.attention_mask` |

## Building & testing

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon test                    # default backend (wasm-gc)
moon test --target native    # also: wasm, wasm-gc, js
```

Inline tests run on every backend. Model-parity tests load full
`tokenizer.json` files that are large and git-ignored. To run them locally:

```bash
# download model fixtures (classic + modern matrix; gated/renamed models skip)
python3 scripts/fetch_models.py

# generate expected outputs with Python tokenizers
pip install tokenizers
python3 scripts/gen_parity.py

moon test --target native
```

Parity tests self-skip when fixtures are absent.

## License

Apache-2.0. Inspired by and follows the algorithms and file format of
HuggingFace `tokenizers` (Apache-2.0). See [`LICENSE`](./LICENSE).
