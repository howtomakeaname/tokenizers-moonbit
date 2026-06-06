# Benchmarks

These benchmarks measure encode/decode throughput and load time, and pair the
MoonBit results with the Python `tokenizers` (Rust) baseline on the **same
corpus** to show a like-for-like comparison.

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

Corpus: a mixed English / CJK / punctuation paragraph repeated to ~1.5 KB
(`bench_corpus()` in `src/tokenizer/bench_test.mbt`).

## Results (encode, µs per encode of the corpus)

> Indicative numbers from a developer laptop; absolute values vary by machine.
> The point is the **ratio** and the **portability story**, not the exact µs.

| model | MoonBit native | MoonBit js | Python `tokenizers` (Rust, native) |
|---|---|---|---|
| gpt2 (byte-level BPE) | ~505 µs | ~833 µs | ~325 µs |
| bert (WordPiece) | ~232 µs | ~404 µs | ~392 µs |
| Qwen2.5 (BPE + Split) | ~569 µs | ~812 µs | ~351 µs |
| llama (byte_fallback BPE) | ~2.97 ms | ~3.16 ms | ~212 µs |

decode (gpt2): native ~20 µs, js ~129 µs.
load `from_str` (gpt2, ~1.3 MB json): native ~30 ms, js ~72 ms.

## How to read this — the scenario-differentiated story

**1. Correctness is the headline, and it is exact.** Across **13 real models**
(gpt2, roberta, bert±cased, distilbert, t5, albert, xlm-roberta, llama,
Qwen2.5, Qwen3, DeepSeek-V2, Phi-3) every encode matches Python `tokenizers`
**token-for-token**. A faster tokenizer that disagrees with the reference is
useless; this one agrees.

**2. Where it wins: portability.** The Rust `tokenizers` crate is fast on a
server, but to run it in a **browser / edge / JS runtime** you must compile it
to WASM (a multi-MB artifact + glue) or call a native addon. `tokenizer-moonbit`
compiles **the same source** to `js`, `wasm`, `wasm-gc` and `native` with no
FFI and no separate toolchain — you get a working tokenizer directly in the
target the model runs in.

**3. Throughput is in the same ballpark — sometimes faster.** On native,
WordPiece (bert) is already **faster than** the Rust baseline here, and
byte-level BPE / Split models are within ~1.5–1.6×. The JS backend (the one
that matters for in-browser inference) runs the same corpus in well under a
millisecond for most models.

**4. Honest gaps.** `llama` (byte_fallback BPE with a multi-step pre-tokenizer)
is currently ~14× slower than Rust — its merge loop is the naive O(n²) scan
without a priority-queue heap or word cache. That is the next performance
target (see `PROGRESS.md`); it does not affect correctness.

## Notes

- `encode_batch` is single-threaded by design (the target is wasm/js, which are
  single-threaded); the Rust crate uses rayon for batch parallelism.
- Numbers above are encode-only of one fixed corpus; real workloads vary.
