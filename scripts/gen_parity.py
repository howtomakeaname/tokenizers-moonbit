#!/usr/bin/env python3
"""Generate the parity expectation files consumed by the MoonBit parity tests.

For each available tests/data/<name>.full.json, writes
tests/data/parity/<name>.json with, per case:
  - text
  - ids            (add_special_tokens=False)
  - tokens         (add_special_tokens=False)
  - ids_special    (add_special_tokens=True)

Usage:
    python3 scripts/gen_parity.py            # all available models
    python3 scripts/gen_parity.py gpt2 bert  # subset
"""
import json
import os
import sys

from tokenizers import Tokenizer

CASES = [
    "Hello world",
    "Hello, world!",
    "I'm fine, thanks.",
    "The quick brown fox jumps over the lazy dog.",
    " leading space",
    "multiple   spaces",
    "ABC123xyz",
    "don't can't won't",
    "MoonBit is great",
    "tokenization",
    "日本語のテキスト",
    "emoji test",
    "New York City",
    "unaffable",
]

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "tests", "data")
OUT_DIR = os.path.join(DATA_DIR, "parity")


def gen_one(name: str) -> bool:
    src = os.path.join(DATA_DIR, f"{name}.full.json")
    if not os.path.exists(src):
        print(f"[skip] {name}: {name}.full.json not found")
        return False
    tok = Tokenizer.from_file(src)
    cases = []
    for text in CASES:
        enc = tok.encode(text, add_special_tokens=False)
        enc_s = tok.encode(text, add_special_tokens=True)
        cases.append(
            {
                "text": text,
                "ids": enc.ids,
                "tokens": enc.tokens,
                "ids_special": enc_s.ids,
            }
        )
    os.makedirs(OUT_DIR, exist_ok=True)
    dst = os.path.join(OUT_DIR, f"{name}.json")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump({"model": name, "cases": cases}, f, ensure_ascii=False, indent=2)
    print(f"[ok]   {name}: {len(cases)} cases -> {dst}")
    return True


def main() -> None:
    names = sys.argv[1:]
    if not names:
        # discover from *.full.json present
        names = [
            f[: -len(".full.json")]
            for f in os.listdir(DATA_DIR)
            if f.endswith(".full.json")
        ]
    for name in sorted(names):
        gen_one(name)


if __name__ == "__main__":
    main()
