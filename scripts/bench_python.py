#!/usr/bin/env python3
"""Python baseline for the encode benchmark, to pair with `moon bench`.

Measures HuggingFace `tokenizers` encode throughput on the same corpus the
MoonBit bench uses, so docs/benchmarks can present a like-for-like comparison.

Usage:  python3 scripts/bench_python.py
"""
import os
import time

from tokenizers import Tokenizer

DATA = os.path.join(os.path.dirname(__file__), "..", "tests", "data")

UNIT = (
    "The quick brown fox jumps over the lazy dog. Tokenization 1234 is fun!\n"
    "MoonBit runs on wasm, js and native. 日本語のテキストも処理できます。\n"
    "Special tokens like <s> and punctuation: e.g., (a+b)*c == 42? Yes!\n"
)
CORPUS = UNIT * 8

MODELS = ["gpt2", "bert", "llama", "Qwen2.5"]


def bench(name: str) -> None:
    path = os.path.join(DATA, f"{name}.full.json")
    if not os.path.exists(path):
        print(f"[skip] {name}")
        return
    tok = Tokenizer.from_file(path)
    # warmup
    for _ in range(50):
        tok.encode(CORPUS, add_special_tokens=False)
    iters = 2000
    t0 = time.perf_counter()
    for _ in range(iters):
        tok.encode(CORPUS, add_special_tokens=False)
    dt = time.perf_counter() - t0
    per = dt / iters * 1e6  # µs per encode
    print(f"{name}-encode  {per:8.2f} µs/encode   ({iters} iters)")


def main() -> None:
    print(f"corpus: {len(CORPUS)} chars")
    for m in MODELS:
        bench(m)


if __name__ == "__main__":
    main()
