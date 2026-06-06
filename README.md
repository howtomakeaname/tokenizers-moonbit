# tokenizer-moonbit

A MoonBit port of [HuggingFace `tokenizers`](https://github.com/huggingface/tokenizers).

It loads a standard `tokenizer.json` and runs tokenization across **all MoonBit
backends** (wasm / wasm-gc / js / native), targeting LLM / edge use cases.

> Status: **work in progress.** See `STATUS` below for which phases are done.

## Goals

- Load HuggingFace `tokenizer.json` directly.
- Support the three core model types:
  - **BPE / byte-level BPE** (GPT-2, RoBERTa, Llama, ...)
  - **WordPiece** (BERT, ...)
  - **Unigram** (SentencePiece: T5, ALBERT, ...)
- Full pipeline: Normalizer → Pre-tokenizer → Model → Post-processor → Decoder.
- `encode` / `decode` verified token-for-token against Python `transformers`.

## Quick start

```moonbit
let tok = @tokenizer.Tokenizer::from_str(json_text)
let enc = tok.encode("Hello world")
println(enc.ids)
```

`from_str(json : String)` is backend-agnostic (no file IO). `from_file(path)`
(backed by `moonbitlang/x/fs`) is available on all backends for convenience.

## Status

- [x] P0 — Project scaffold + JSON parsing wired up.
- [ ] P1 — tokenizer.json deserialization (vocab / merges / component configs).
- [ ] P2 — BPE encode (non byte-level).
- [ ] P3 — Byte-level BPE + ByteLevel pre-tokenizer (GPT-2 parity).
- [ ] P4 — decode.
- [ ] P5 — WordPiece (BERT parity).
- [ ] P6 — Unigram (T5 / ALBERT parity).
- [ ] P7 — Normalizers / post-processors / special tokens.
- [ ] P8 — Cross-backend verification.

## License

Apache-2.0. Inspired by and follows the algorithms / file format of
HuggingFace `tokenizers` (Apache-2.0). See `LICENSE`.
