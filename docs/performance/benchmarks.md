---
title: Benchmarks
createTime: 2026/07/10 00:00:00
---

# Benchmarks

Benchmarks compare MoonBit encode/decode/load performance against Python
`tokenizers` on the same corpora.

```mermaid
flowchart LR
  A[fetch_models.py] --> B[gen_parity.py]
  B --> C[moon bench]
  C --> D[bench_python.py]
  D --> E[bench_compare.py]
  E --> F[Moon/HF ratio]
  F --> G{> 1.10x?}
  G -->|yes| H[Optimization backlog]
  G -->|no| I[Publish result]
```

## Commands

```bash
python3 scripts/fetch_models.py
pip install tokenizers numpy
python3 scripts/gen_parity.py

moon bench --target native
python3 scripts/bench_compare.py --target native --corpus mixed
python3 scripts/bench_compare.py --target native --corpus all --fail-above 1.10
```

## Reading Results

| Moon/HF ratio | Interpretation |
|---:|---|
| `< 0.90x` | MoonBit is faster on this case |
| `0.90x .. 1.10x` | Same range |
| `> 1.10x` | Optimization candidate or regression |

Published performance claims should quote the comparison ratio, not standalone
`moon bench` output.
