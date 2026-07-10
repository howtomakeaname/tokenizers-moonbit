---
title: Benchmarks
createTime: 2026/07/10 00:00:00
---

# Benchmarks

Benchmarks compare MoonBit encode/decode/load performance against Python
`tokenizers` on the same corpora.

## Summary

<BenchmarkSnapshot locale="en" />

## Charts

### Moon/HF Ratio by Case

Top 15 cases sorted by Moon/HF ratio. Lower is better; values below 1.0 (green)
indicate MoonBit is faster than HF.

::: echarts Moon/HF Ratio
:charts{path="ratio-bar.json"}
:::

### Moon µs vs HF µs Scatter

Each point represents one benchmark case. Points below the diagonal line mean
MoonBit is faster than HF for that case.

::: echarts Moon vs HF Performance
:charts{path="scatter.json"}
:::

### Performance Distribution

Distribution of benchmark results by verdict category.

::: echarts Performance Summary
:charts{path="summary.json"}
:::

### Average Ratio by Model

Average Moon/HF ratio across all benchmark cases for each model.

::: echarts Model Average Ratio
:charts{path="model-bar.json"}
:::

## Pipeline

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

# Generate ECharts from benchmark report
node scripts/gen-bench-charts.mjs reports/bench-native-mixed.json
```

## Reading Results

| Moon/HF ratio | Interpretation |
|---:|---|
| `< 0.90x` | MoonBit is faster on this case |
| `0.90x .. 1.10x` | Same range |
| `> 1.10x` | Optimization candidate or regression |

Published performance claims should quote the comparison ratio, not standalone
`moon bench` output.

The page reads `/benchmarks/latest.json` at runtime. CI writes the raw
`reports/bench-native-mixed.json` artifact from `bench_compare.py --json-out`,
then the docs build converts that report into the static JSON consumed here.
ECharts are generated from the same report via `gen-bench-charts.mjs`.
