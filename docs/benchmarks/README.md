# Benchmarks

These benchmarks measure encode/decode throughput and load time, and pair the
MoonBit results with the Python `tokenizers` (Rust) baseline on the **same
corpora**.

Chinese version: [`docs/zh/benchmarks.md`](../zh/benchmarks.md)

## How to reproduce

```bash
# 1) fetch model fixtures (see ../../README.md)
python3 scripts/fetch_models.py

# 2) Direct MoonBit benchmark, per backend
moon bench --target native
moon bench --target js
moon bench --target wasm-gc

# 3) Python baseline (HuggingFace tokenizers, Rust-backed)
pip install tokenizers
python3 scripts/bench_python.py

# 4) One-command comparison: MoonBit vs HF tokenizers on the same host
python3 scripts/bench_compare.py --target native --corpus mixed
# quick representative subset while iterating
python3 scripts/bench_compare.py --target native --corpus mixed --quick
# full model × corpus encode matrix
python3 scripts/bench_compare.py --target native --corpus all
```

Corpora:

- `short`: chat-style short input; measures interactive overhead.
- `mixed`: English + CJK + punctuation paragraph repeated to roughly 1.5 KB.
- `code`: MoonBit-like code, identifiers and comments; targets coder models.
- `long`: repeated mixed + code text; stresses BPE merge loops and vocab lookup.

The MoonBit corpora live in `src/tokenizer/bench_test.mbt`. The Python baseline
uses the same corpus names in `scripts/bench_python.py`.

## Required comparison workflow

For performance work, do not quote standalone `moon bench` numbers. Always run
the comparison script and use its `Moon/HF` ratio:

```bash
python3 scripts/bench_compare.py --target native --corpus mixed
python3 scripts/bench_compare.py --target native --corpus code
python3 scripts/bench_compare.py --target native --corpus all
```

Interpretation:

- `< 0.90x`: MoonBit is faster than HF on this case.
- `0.90x .. 1.10x`: same range; optimize only if this is a hot path.
- `> 1.10x`: regression/optimization candidate; add it to `PROGRESS.md` before
  claiming benchmark parity.

The script also prints an `Optimization focus` list sorted by the largest gap.
By default the model list is the full fixture matrix from `scripts/bench_python.py`
(currently GPT-2/RoBERTa byte-level BPE, BERT WordPiece, T5/embedding
SentencePiece-style models, Llama/Qwen/Phi/Mistral/StarCoder/CLIP and related
modern tokenizers). Use `--quick` only for local smoke checks, not for published
performance claims.

## Results (historical mixed corpus)

> Indicative numbers from a developer laptop; absolute values vary by machine.
> The point is the ratio and deployment story, not the exact microseconds.

| model | MoonBit native | Python `tokenizers` (Rust, native) | Moon/HF |
|---|---|---|---|
| gpt2 (byte-level BPE) | ~144 µs | ~331 µs | ~0.44x |
| bert (WordPiece) | ~212 µs | ~439 µs | ~0.48x |
| llama (byte_fallback BPE) | ~62 µs | ~225 µs | ~0.28x |
| t5 (Unigram/SentencePiece) | ~144 µs | ~373 µs | ~0.39x |
| bge_m3 (embedding Unigram) | ~120 µs | ~285 µs | ~0.42x |
| e5_multilingual (embedding Unigram) | ~121 µs | ~285 µs | ~0.43x |

decode (gpt2): native ~20 µs, js ~129 µs.
load `from_str` (gpt2, ~1.3 MB json): native ~30 ms, js ~72 ms.

The BPE merge loop uses a priority-queue heap with lazy stale removal plus a
word-level cache. Unigram/SentencePiece uses the same cache idea after Viterbi.
On repeated mixed-corpus workloads this makes GPT-2, Llama, T5 and embedding
tokenizers faster than the HF native baseline on the sampled machine. Re-run
`scripts/bench_compare.py` on your target hardware before quoting numbers.

## How to read the results

**Correctness first.** With optional fixtures present, parity tests cover 31 real
models and compare token ids against Python `tokenizers`. A faster tokenizer
that disagrees with the reference is not useful.

**Portability is the main differentiator.** Rust `tokenizers` is fast on a
server. In browsers, edge runtimes and pure JS environments, you typically need
an additional WASM artifact, glue code or a native addon. `tokenizers-moonbit`
compiles the same source to `js`, `wasm`, `wasm-gc` and `native`.

**Throughput is in the same range.** Native byte-level BPE and Split models are
within the same order of magnitude as the Rust baseline, and WordPiece can be
faster for the measured corpus. The JS backend remains practical for browser
inference workloads.

**Optimization is ratio-driven.** Any benchmark-related PR should include the
MoonBit/HF comparison table, not only raw MoonBit timings. If a case is slower
than HF by more than 10%, treat it as a concrete optimization backlog item.

## Notes

- `encode_batch` is single-threaded by design; the Rust crate uses rayon for
  batch parallelism.
- Re-run the benchmark matrix before quoting numbers. Hardware, backend and
  corpus mix matter.
- The current matrix reports encode/decode/load across short, mixed, code and
  long-document workloads.
