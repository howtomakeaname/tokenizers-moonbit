#!/usr/bin/env python3
"""Generate expected encode/decode outputs for cross-checking against the
MoonBit tokenizer. Uses the HuggingFace `tokenizers` library (Rust-backed).

Usage:  python3 scripts/gen_expected.py <tokenizer.json> <out.json>

Writes a JSON array of {text, ids, tokens, decoded} cases.
"""
import json
import sys
from tokenizers import Tokenizer

CASES = [
    "Hello world",
    "Hello, world!",
    "I'm fine, thanks.",
    "The quick brown fox jumps over the lazy dog.",
    " leading space",
    "multiple   spaces",
    "tab\tand\nnewline",
    "naïve café",
    "日本語のテキスト",
    "emoji 😀 test",
    "ABC123xyz",
    "don't  can't  won't",
    "  ",
    "MoonBit is great",
]


def main():
    tok_path, out_path = sys.argv[1], sys.argv[2]
    tok = Tokenizer.from_file(tok_path)
    out = []
    for text in CASES:
        enc = tok.encode(text, add_special_tokens=False)
        decoded = tok.decode(enc.ids, skip_special_tokens=False)
        out.append(
            {
                "text": text,
                "ids": enc.ids,
                "tokens": enc.tokens,
                "decoded": decoded,
            }
        )
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"wrote {len(out)} cases to {out_path}")


if __name__ == "__main__":
    main()
