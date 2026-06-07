#!/usr/bin/env python3
"""Compare tokenizer-moonbit with HuggingFace tokenizers on the same host.

This script intentionally reports **ratios** instead of only standalone timings:
`moonbit_us / hf_us`, where lower is better for tokenizer-moonbit. It runs
`moon bench --target <target>`, parses MoonBit's benchmark table, then measures
HF `tokenizers` on the same tokenizer.json fixtures and corpora.

Default scope covers every model fixture known to bench_python.py on the mixed
corpus. Use `--corpus all` for the full model × corpus encode matrix.
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
    from tokenizers import Regex
    from tokenizers import decoders as hf_decoders
    from tokenizers import models as hf_models
    from tokenizers import pre_tokenizers as hf_pre_tokenizers
    from tokenizers import trainers as hf_trainers
except Exception as exc:  # pragma: no cover - environment diagnostic
    print("ERROR: Python package 'tokenizers' is required: pip install tokenizers", file=sys.stderr)
    raise SystemExit(2) from exc


QUICK_MODELS = ["gpt2", "bert", "llama", "Qwen2.5", "phi4_mini", "qwen3_coder"]
DEFAULT_MODELS = MODELS
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


def hf_encode_batch_us(tok: Tokenizer, text: str) -> float:
    batch = [text] * 8
    iters = iterations_for(text)
    return timed_us(lambda: tok.encode_batch(batch, add_special_tokens=False), iters)


def hf_decode_us(tok: Tokenizer, text: str) -> float:
    ids = tok.encode(text, add_special_tokens=False).ids
    iters = iterations_for(text)
    return timed_us(lambda: tok.decode(ids, skip_special_tokens=False), iters)


def hf_decode_batch_us(tok: Tokenizer, text: str) -> float:
    ids = tok.encode(text, add_special_tokens=False).ids
    batch = [ids] * 8
    iters = iterations_for(text)
    return timed_us(lambda: tok.decode_batch(batch, skip_special_tokens=False), iters)


def hf_load_us(path: str) -> float:
    return timed_us(lambda: Tokenizer.from_file(path), 30)


def hf_to_json_us(tok: Tokenizer) -> float:
    return timed_us(lambda: tok.to_str(pretty=False), 30)


def hf_train_wordlevel_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.WordLevel(unk_token="[UNK]"))
        tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
        trainer = hf_trainers.WordLevelTrainer(
            min_frequency=1,
            special_tokens=["[PAD]", "[UNK]"],
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 60)


def hf_decoder_replace_regex_us() -> float:
    decoder = hf_decoders.Replace(Regex(r"\s+"), " ")
    tokens = [
        "The\tquick",
        "\u00a0brown\nfox",
        "\u3000jumps",
        " over\tthe lazy dog.",
        " MoonBit\nwasm\u3000tokenizers.",
    ]
    return timed_us(lambda: decoder.decode(tokens), 2_000)


def hf_split_trailing_ws_regex_us() -> float:
    pt = hf_pre_tokenizers.Split(Regex(r"\s+$"), "removed", invert=False)
    text = CORPORA["mixed"] + "\t \n"
    return timed_us(lambda: pt.pre_tokenize_str(text), 2_000)


def hf_split_nonspace_regex_us() -> float:
    pt = hf_pre_tokenizers.Split(Regex(r"\S+"), "removed", invert=False)
    text = CORPORA["mixed"]
    return timed_us(lambda: pt.pre_tokenize_str(text), 2_000)


def compare(models: list[str], corpora: list[str], target: str) -> list[Row]:
    moon = run_moon_bench(target)
    rows: list[Row] = []
    train_key = "wordlevel-train-mixedx4"
    if train_key in moon:
        rows.append(Row(train_key, moon[train_key], hf_train_wordlevel_us(CORPORA["mixed"])))
    decoder_replace_key = "decoder-replace-regex-mixed"
    if decoder_replace_key in moon:
        rows.append(Row(decoder_replace_key, moon[decoder_replace_key], hf_decoder_replace_regex_us()))
    split_trailing_ws_key = "pretokenizer-split-trailing-ws-regex-mixed"
    if split_trailing_ws_key in moon:
        rows.append(Row(split_trailing_ws_key, moon[split_trailing_ws_key], hf_split_trailing_ws_regex_us()))
    split_nonspace_key = "pretokenizer-split-nonspace-regex-mixed"
    if split_nonspace_key in moon:
        rows.append(Row(split_nonspace_key, moon[split_nonspace_key], hf_split_nonspace_regex_us()))
    for model in models:
        tok, path = load_tokenizer(model)
        if tok is None:
            print(f"[skip] missing fixture: {path}")
            continue
        for corpus in corpora:
            text = CORPORA[corpus]
            encode_key = f"{model}-encode-{corpus}"
            encode_byte_offsets_key = f"{model}-encode-byte-offsets-{corpus}"
            if encode_key in moon:
                rows.append(Row(encode_key, moon[encode_key], hf_encode_us(tok, text)))
            if encode_byte_offsets_key in moon:
                # HF encodings carry byte offsets by default, so plain encode is
                # the closest same-work baseline for MoonBit's explicit byte
                # offset conversion API.
                rows.append(Row(encode_byte_offsets_key, moon[encode_byte_offsets_key], hf_encode_us(tok, text)))
        # Decode benches are currently standardized on the mixed corpus in
        # src/tokenizer/bench_test.mbt; include them once per model.
        decode_key = f"{model}-decode-mixed"
        decode_batch_key = f"{model}-decode-batch-mixedx8"
        encode_batch_key = f"{model}-encode-batch-mixedx8"
        load_key = f"{model}-from_str"
        pretrained_key = f"{model}-from_pretrained-file"
        to_json_key = f"{model}-to_json"
        if decode_key in moon:
            rows.append(Row(decode_key, moon[decode_key], hf_decode_us(tok, CORPORA["mixed"])))
        if decode_batch_key in moon:
            rows.append(Row(decode_batch_key, moon[decode_batch_key], hf_decode_batch_us(tok, CORPORA["mixed"])))
        if encode_batch_key in moon:
            rows.append(Row(encode_batch_key, moon[encode_batch_key], hf_encode_batch_us(tok, CORPORA["mixed"])))
        if load_key in moon:
            rows.append(Row(load_key, moon[load_key], hf_load_us(path)))
        if pretrained_key in moon:
            # Local file from_pretrained is intentionally equivalent to HF's
            # from_file baseline; Hub/network fetching is outside this script.
            rows.append(Row(pretrained_key, moon[pretrained_key], hf_load_us(path)))
        if to_json_key in moon:
            rows.append(Row(to_json_key, moon[to_json_key], hf_to_json_us(tok)))
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
    parser.add_argument("--corpus", default="mixed", choices=sorted(CORPORA.keys()) + ["all"])
    parser.add_argument("--models", default=",".join(DEFAULT_MODELS), help="comma-separated model names")
    parser.add_argument("--quick", action="store_true", help="compare representative core models only")
    args = parser.parse_args()
    models = QUICK_MODELS if args.quick else [m for m in args.models.split(",") if m]
    corpora = list(CORPORA.keys()) if args.corpus == "all" else [args.corpus]
    print(f"Comparing target={args.target}, corpus={','.join(corpora)}, models={','.join(models)}")
    print_rows(compare(models, corpora, args.target))


if __name__ == "__main__":
    main()
