#!/usr/bin/env python3
"""Python baseline for the benchmark matrix, to pair with `moon bench`.

Measures HuggingFace `tokenizers` encode/decode/load throughput on the same
corpora the MoonBit bench uses, so docs/benchmarks can present a like-for-like
comparison across model families and workloads.

Usage:  python3 scripts/bench_python.py
"""
import os
import time

from tokenizers import Tokenizer

DATA = os.path.join(os.path.dirname(__file__), "..", "tests", "data")

SHORT_CHAT = "I'm fine, thanks. 请用 MoonBit 写一个 tokenizer 示例。"

MIXED_UNIT = (
    "The quick brown fox jumps over the lazy dog. Tokenization 1234 is fun!\n"
    "MoonBit runs on wasm, js and native. 日本語のテキストも処理できます。\n"
    "Special tokens like <s> and punctuation: e.g., (a+b)*c == 42? Yes!\n"
)
MIXED = MIXED_UNIT * 8

CODE_UNIT = (
    "pub fn encode_batch(tok : Tokenizer, xs : Array[String]) -> Array[Encoding] {\n"
    "  xs.map(fn(x) { tok.encode(x, add_special_tokens=false) })\n"
    "}\n"
    "// UTF-8, byte_fallback, snake_case, camelCase, HTTP/2, JSON.parse\n"
)
CODE = CODE_UNIT * 12
LONG_DOC = (MIXED + CODE) * 8

CORPORA = {
    "short": SHORT_CHAT,
    "mixed": MIXED,
    "code": CODE,
    "long": LONG_DOC,
}

MODELS = [
    "gpt2",
    "bert",
    "roberta",
    "t5",
    "llama",
    "Qwen2.5",
    "qwen3",
    "phi3",
    "mistral",
    "starcoder2",
    "clip",
    "llama3_2",
    "phi4_mini",
    "gpt_oss",
    "qwen3_coder",
    "bge_m3",
    "e5_multilingual",
]


def load_tokenizer(name: str):
    path = os.path.join(DATA, f"{name}.full.json")
    if not os.path.exists(path):
        print(f"[skip] {name}")
        return None, path
    return Tokenizer.from_file(path), path


def iterations_for(text: str) -> int:
    if len(text) > 10_000:
        return 200
    if len(text) > 2_000:
        return 800
    return 2_000


def bench_encode(name: str, tok: Tokenizer, corpus_name: str, text: str) -> None:
    # warmup
    for _ in range(50):
        tok.encode(text, add_special_tokens=False)
    iters = iterations_for(text)
    t0 = time.perf_counter()
    for _ in range(iters):
        tok.encode(text, add_special_tokens=False)
    dt = time.perf_counter() - t0
    per = dt / iters * 1e6  # µs per encode
    tokens = len(tok.encode(text, add_special_tokens=False).ids)
    tok_s = tokens * iters / dt
    print(f"{name}-encode-{corpus_name:5s} {per:9.2f} µs/op  {tok_s:10.0f} tok/s  ({iters} iters)")


def bench_decode(name: str, tok: Tokenizer, corpus_name: str, text: str) -> None:
    ids = tok.encode(text, add_special_tokens=False).ids
    for _ in range(50):
        tok.decode(ids, skip_special_tokens=False)
    iters = iterations_for(text)
    t0 = time.perf_counter()
    for _ in range(iters):
        tok.decode(ids, skip_special_tokens=False)
    dt = time.perf_counter() - t0
    per = dt / iters * 1e6
    tok_s = len(ids) * iters / dt
    print(f"{name}-decode-{corpus_name:5s} {per:9.2f} µs/op  {tok_s:10.0f} tok/s  ({iters} iters)")


def bench_load(name: str, path: str) -> None:
    iters = 50
    t0 = time.perf_counter()
    for _ in range(iters):
        Tokenizer.from_file(path)
    dt = time.perf_counter() - t0
    per = dt / iters * 1e3
    size_mb = os.path.getsize(path) / 1024 / 1024
    print(f"{name}-from_file      {per:9.2f} ms/op  fixture={size_mb:6.2f} MiB  ({iters} iters)")


def main() -> None:
    print("corpora:", ", ".join(f"{k}={len(v)} chars" for k, v in CORPORA.items()))
    for m in MODELS:
        tok, path = load_tokenizer(m)
        if tok is None:
            continue
        bench_load(m, path)
        for cname, text in CORPORA.items():
            bench_encode(m, tok, cname, text)
        bench_decode(m, tok, "mixed", MIXED)


if __name__ == "__main__":
    main()
