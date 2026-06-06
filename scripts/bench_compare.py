#!/usr/bin/env python3
"""Compare tokenizer-moonbit with HuggingFace tokenizers on the same host.

This script intentionally reports **ratios** instead of only standalone timings:
`moonbit_us / hf_us`, where lower is better for tokenizer-moonbit. It runs
`moon bench --target <target>`, parses MoonBit's benchmark table, then measures
HF `tokenizers` on the same tokenizer.json fixtures and corpora.

Default scope is a practical mixed-corpus matrix for the model families we care
about most. Use `--all` to include every model fixture known to bench_python.py.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass

from bench_python import CORPORA, DATA, MODELS

try:
    from tokenizers import Tokenizer
except Exception as exc:  # pragma: no cover - environment diagnostic
    print("ERROR: Python package 'tokenizers' is required: pip install tokenizers", file=sys.stderr)
    raise SystemExit(2) from exc


DEFAULT_MODELS = ["gpt2", "bert", "llama", "Qwen2.5", "phi4_mini", "qwen3_coder"]
TIME_RE = re.compile(r"^(?P<name>\S+)\s+(?P<value>[0-9.]+)\s+(?P<unit>ns|µs|us|ms|s)\b")


@dataclass
class Row:
    name: str
    moon_us: float
    hf_us: float

    @property
    def ratio(self) -> float:
        return self.moon_us / self.hf_us if self.hf_us > 0 else float("inf")

    @property
    def verdict(self) -> str:
        if self.ratio <= 0.90:
            return "faster"
        if self.ratio <= 1.10:
            return "same-range"
        return "slower"


def to_us(value: float, unit: str) -> float:
    if unit == "ns":
        return value / 1000.0
    if unit in ("µs", "us"):
        return value
    if unit == "ms":
        return value * 1000.0
    if unit == "s":
        return value * 1_000_000.0
    raise ValueError(unit)


def run_moon_bench(target: str) -> dict[str, float]:
    env = os.environ.copy()
    env["PATH"] = os.path.expanduser("~/.moon/bin") + os.pathsep + env.get("PATH", "")
    cmd = ["moon", "bench", "--target", target]
    proc = subprocess.run(cmd, text=True, capture_output=True, check=False, env=env)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode)
    results: dict[str, float] = {}
    for line in proc.stdout.splitlines():
        m = TIME_RE.match(line.strip())
        if not m:
            continue
        name = m.group("name")
        if name == "name":
            continue
        results[name] = to_us(float(m.group("value")), m.group("unit"))
    return results


def load_tokenizer(name: str) -> tuple[Tokenizer | None, str]:
    path = os.path.join(DATA, f"{name}.full.json")
    if not os.path.exists(path):
        return None, path
    return Tokenizer.from_file(path), path


def iterations_for(text: str) -> int:
    if len(text) > 10_000:
        return 120
    if len(text) > 2_000:
        return 400
    return 1_000


def timed_us(fn, iters: int) -> float:
    for _ in range(min(50, iters)):
        fn()
    t0 = time.perf_counter()
    for _ in range(iters):
        fn()
    return (time.perf_counter() - t0) / iters * 1_000_000.0


def hf_encode_us(tok: Tokenizer, text: str) -> float:
    iters = iterations_for(text)
    return timed_us(lambda: tok.encode(text, add_special_tokens=False), iters)


def hf_decode_us(tok: Tokenizer, text: str) -> float:
    ids = tok.encode(text, add_special_tokens=False).ids
    iters = iterations_for(text)
    return timed_us(lambda: tok.decode(ids, skip_special_tokens=False), iters)


def hf_load_us(path: str) -> float:
    return timed_us(lambda: Tokenizer.from_file(path), 30)


def compare(models: list[str], corpus: str, target: str) -> list[Row]:
    text = CORPORA[corpus]
    moon = run_moon_bench(target)
    rows: list[Row] = []
    for model in models:
        tok, path = load_tokenizer(model)
        if tok is None:
            print(f"[skip] missing fixture: {path}")
            continue
        encode_key = f"{model}-encode-{corpus}"
        decode_key = f"{model}-decode-{corpus}"
        load_key = f"{model}-from_str"
        if encode_key in moon:
            rows.append(Row(encode_key, moon[encode_key], hf_encode_us(tok, text)))
        if decode_key in moon:
            rows.append(Row(decode_key, moon[decode_key], hf_decode_us(tok, text)))
        if load_key in moon:
            rows.append(Row(load_key, moon[load_key], hf_load_us(path)))
    return rows


def print_rows(rows: list[Row]) -> None:
    print("| case | MoonBit µs/op | HF tokenizers µs/op | Moon/HF | verdict |")
    print("|---|---:|---:|---:|---|")
    for r in rows:
        print(f"| {r.name} | {r.moon_us:.2f} | {r.hf_us:.2f} | {r.ratio:.2f}x | {r.verdict} |")
    slower = sorted([r for r in rows if r.ratio > 1.10], key=lambda r: r.ratio, reverse=True)
    if slower:
        print("\nOptimization focus:")
        for r in slower[:8]:
            print(f"- {r.name}: {r.ratio:.2f}x slower than HF")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", default="native", choices=["native", "js", "wasm", "wasm-gc"])
    parser.add_argument("--corpus", default="mixed", choices=sorted(CORPORA.keys()))
    parser.add_argument("--models", default=",".join(DEFAULT_MODELS), help="comma-separated model names")
    parser.add_argument("--all", action="store_true", help="compare every model known to bench_python.py")
    args = parser.parse_args()
    models = MODELS if args.all else [m for m in args.models.split(",") if m]
    print(f"Comparing target={args.target}, corpus={args.corpus}, models={','.join(models)}")
    print_rows(compare(models, args.corpus, args.target))


if __name__ == "__main__":
    main()
