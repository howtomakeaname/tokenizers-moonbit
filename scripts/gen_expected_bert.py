#!/usr/bin/env python3
"""Generate expected outputs for a WordPiece (BERT) tokenizer.
add_special_tokens=False isolates normalizer+pretokenizer+model (no [CLS]/[SEP]).

Usage:  python3 scripts/gen_expected_bert.py <tokenizer.json> <out.json>
"""
import json
import sys
from tokenizers import Tokenizer

# ASCII-focused cases; accent stripping (NFD-based) is a known P5 gap, so we
# avoid accented inputs here and revisit in a later phase.
CASES = [
    "Hello world",
    "The quick brown fox.",
    "unaffable",
    "tokenization is fun",
    "Don't panic!",
    "HELLO World",
    "running runner runs",
    "a b c 1 2 3",
    "supercalifragilistic",
    "New York City",
]


def main():
    tok = Tokenizer.from_file(sys.argv[1])
    out = []
    for text in CASES:
        enc = tok.encode(text, add_special_tokens=False)
        out.append({"text": text, "ids": enc.ids, "tokens": enc.tokens})
    json.dump(out, open(sys.argv[2], "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    print(f"wrote {len(out)} cases")


if __name__ == "__main__":
    main()
