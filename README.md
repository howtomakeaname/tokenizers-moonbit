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
- [x] P1 — tokenizer.json deserialization (vocab / merges / component configs).
- [x] P2 — BPE encode (non byte-level).
- [x] P3 — Byte-level BPE + ByteLevel pre-tokenizer (GPT-2 parity).
- [x] P4 — decode.
- [x] P5 — WordPiece (BERT parity).
- [x] P6 — Unigram (T5 parity).
- [x] P7 — Post-processing / special tokens / `encode_pair`.
- [x] P8 — Cross-backend verification (wasm / wasm-gc / js / native).

Verified token-for-token against Python `tokenizers` for **GPT-2**, **BERT**
(`bert-base-uncased`) and **T5** (`t5-small`).

### Known gaps (TODO)

- Unicode normalization (NFC/NFKC) and `strip_accents` need data tables; they
  currently act as identity. The `Precompiled` (SentencePiece) normalizer is
  also identity.
- `\p{...}` Unicode classes in the GPT-2 pre-tokenizer use coarse range tables
  (common scripts only).
- `byte_fallback`, exact byte-level offset trimming, and training are not
  implemented.

## Tests

Most tests embed tiny inline fixtures and run on every backend. The parity
tests for GPT-2 / BERT / T5 load full `tokenizer.json` files that are **not**
committed (they are large and git-ignored). To run them locally:

```bash
# download model fixtures
curl -L -o tests/data/gpt2.full.json https://huggingface.co/gpt2/resolve/main/tokenizer.json
curl -L -o tests/data/bert.full.json https://huggingface.co/bert-base-uncased/resolve/main/tokenizer.json
curl -L -o tests/data/t5.full.json   https://huggingface.co/t5-small/resolve/main/tokenizer.json
# (re)generate expected outputs with the Python `tokenizers` library
python3 scripts/gen_expected.py      tests/data/gpt2.full.json tests/data/gpt2_expected.json
python3 scripts/gen_expected_bert.py tests/data/bert.full.json tests/data/bert_expected.json
python3 scripts/gen_expected_bert.py tests/data/t5.full.json   tests/data/t5_expected.json

moon test --target native   # also: wasm, wasm-gc, js
```

The disk-backed tests self-skip gracefully when fixtures are absent.

## License

Apache-2.0. Inspired by and follows the algorithms / file format of
HuggingFace `tokenizers` (Apache-2.0). See `LICENSE`.
