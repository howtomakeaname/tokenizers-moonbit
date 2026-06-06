# Benchmarks

These benchmarks measure encode/decode throughput and load time, and pair the
MoonBit results with the Python `tokenizers` (Rust) baseline on the **same
corpora**.

Chinese version: [`docs/zh/benchmarks.md`](../zh/benchmarks.md)

## How to reproduce

```bash
# 1) fetch model fixtures (see ../../README.md)
python3 scripts/fetch_models.py

# 2) MoonBit, per backend
moon bench --target native
moon bench --target js
moon bench --target wasm-gc

# 3) Python baseline (HuggingFace tokenizers, Rust-backed)
pip install tokenizers
python3 scripts/bench_python.py
```

Corpora:

- `short`: chat-style short input; measures interactive overhead.
- `mixed`: English + CJK + punctuation paragraph repeated to roughly 1.5 KB.
- `code`: MoonBit-like code, identifiers and comments; targets coder models.
- `long`: repeated mixed + code text; stresses BPE merge loops and vocab lookup.

The MoonBit corpora live in `src/tokenizer/bench_test.mbt`. The Python baseline
uses the same corpus names in `scripts/bench_python.py`.

## Results (historical mixed corpus)

> Indicative numbers from a developer laptop; absolute values vary by machine.
> The point is the ratio and deployment story, not the exact microseconds.

| model | MoonBit native | MoonBit js | Python `tokenizers` (Rust, native) |
|---|---|---|---|
| gpt2 (byte-level BPE) | ~476 µs | ~833 µs | ~325 µs |
| bert (WordPiece) | ~222 µs | ~404 µs | ~392 µs |
| Qwen2.5 (BPE + Split) | ~530 µs | ~812 µs | ~351 µs |
| llama (byte_fallback BPE) | ~405 µs | ~3.0 ms* | ~212 µs |

decode (gpt2): native ~20 µs, js ~129 µs.
load `from_str` (gpt2, ~1.3 MB json): native ~30 ms, js ~72 ms.

\* The BPE merge loop uses a priority-queue heap with lazy stale removal. This
took `llama` encode from ~2.97 ms down to ~405 µs on native.

## How to read the results

**Correctness first.** With optional fixtures present, parity tests cover 31 real
models and compare token ids against Python `tokenizers`. A faster tokenizer
that disagrees with the reference is not useful.

**Portability is the main differentiator.** Rust `tokenizers` is fast on a
server. In browsers, edge runtimes and pure JS environments, you typically need
an additional WASM artifact, glue code or a native addon. `tokenizer-moonbit`
compiles the same source to `js`, `wasm`, `wasm-gc` and `native`.

**Throughput is in the same range.** Native byte-level BPE and Split models are
within the same order of magnitude as the Rust baseline, and WordPiece can be
faster for the measured corpus. The JS backend remains practical for browser
inference workloads.

## Notes

- `encode_batch` is single-threaded by design; the Rust crate uses rayon for
  batch parallelism.
- Re-run the benchmark matrix before quoting numbers. Hardware, backend and
  corpus mix matter.
- The current matrix reports encode/decode/load across short, mixed, code and
  long-document workloads.
