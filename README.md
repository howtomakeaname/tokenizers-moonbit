# tokenizer-moonbit

A MoonBit port of [HuggingFace `tokenizers`](https://github.com/huggingface/tokenizers).

Load a standard `tokenizer.json` and run encode/decode across **all MoonBit
backends** — `wasm`, `wasm-gc`, `js`, `native` — with no native dependencies.
Targeted at LLM / edge / browser use cases where the Rust `tokenizers` crate is
unavailable or heavyweight to ship.

> Status: actively developed. See [`PROGRESS.md`](./PROGRESS.md) for the full
> capability matrix and roadmap.

## Why this project

- **Runs everywhere MoonBit runs.** One pure-MoonBit implementation compiles to
  wasm/wasm-gc/js/native. No FFI, no platform-specific binaries.
- **Faithful to HuggingFace.** Output is checked token-for-token against the
  Python `tokenizers` library for real models (GPT-2, BERT, T5, Llama).
- **Loads `tokenizer.json` directly.** No conversion step; drop in the same file
  your Python pipeline uses.

## Supported

- **Models:** BPE, byte-level BPE (with `byte_fallback` / `fuse_unk` /
  `ignore_merges`), WordPiece, Unigram, WordLevel.
- **Pipeline:** Normalizer → Pre-tokenizer → Model → Post-processor → Decoder,
  plus an AddedVocabulary stage that splits special/added tokens (e.g.
  `<|endoftext|>`, `[MASK]`) out of text — including mid-text — with
  `single_word` / `lstrip` / `rstrip` / `normalized` semantics.
- **API:** `encode`, `encode_pair`, `decode`, `token_to_id`, `id_to_token`,
  `get_vocab_size`.

See [`PROGRESS.md`](./PROGRESS.md) for the exact per-component status and known
gaps (Unicode normalization, truncation/padding, batching are on the roadmap).

## Quick start

```moonbit
// Load from a tokenizer.json string (backend-agnostic, no file IO):
let tok = @tokenizer.Tokenizer::from_str(json_text)

// Or load from a file (uses moonbitlang/x/fs, available on all backends):
let tok = @tokenizer.from_file("tokenizer.json")

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

`encode(text, add_special_tokens=false)` skips the post-processor template
(special tokens already present in the text are still recognized).

## Migrating from HuggingFace

If you already use the Python `tokenizers` / `transformers`, see the
[migration guide](./docs/migration-from-hf.md) for a side-by-side API mapping.

Quick taste:

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

Inline tests run on every backend. The model-parity tests load full
`tokenizer.json` files that are **not committed** (large, git-ignored). To run
them locally:

```bash
# download model fixtures
curl -L -o tests/data/gpt2.full.json  https://huggingface.co/gpt2/resolve/main/tokenizer.json
curl -L -o tests/data/bert.full.json  https://huggingface.co/bert-base-uncased/resolve/main/tokenizer.json
curl -L -o tests/data/t5.full.json    https://huggingface.co/t5-small/resolve/main/tokenizer.json
curl -L -o tests/data/llama.full.json https://huggingface.co/hf-internal-testing/llama-tokenizer/resolve/main/tokenizer.json

# generate expected outputs with the Python `tokenizers` library
pip install tokenizers
python3 scripts/gen_expected.py      tests/data/gpt2.full.json  tests/data/gpt2_expected.json
python3 scripts/gen_expected_bert.py tests/data/bert.full.json  tests/data/bert_expected.json
python3 scripts/gen_expected_bert.py tests/data/t5.full.json    tests/data/t5_expected.json

moon test --target native
```

Parity tests self-skip gracefully when fixtures are absent.

## License

Apache-2.0. Inspired by and follows the algorithms / file format of
HuggingFace `tokenizers` (Apache-2.0). See [`LICENSE`](./LICENSE).
