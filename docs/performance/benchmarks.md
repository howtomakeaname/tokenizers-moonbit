---
title: Benchmarks
createTime: 2026/07/10 00:00:00
---

# Benchmarks

Benchmarks compare MoonBit encode/decode/load performance against Python
`tokenizers` on the same corpora.

## Charts

::: echarts
```json
{
  "tooltip": { "trigger": "axis", "axisPointer": { "type": "shadow" }, "formatter": "{b}: {c}x" },
  "grid": { "left": "3%", "right": "10%", "bottom": "3%", "containLabel": true },
  "xAxis": { "type": "value", "name": "Moon/HF Ratio", "min": 0, "max": 1.0, "splitLine": { "lineStyle": { "type": "dashed" } }, "axisLabel": { "formatter": "{value}x" } },
  "yAxis": { "type": "category", "data": ["bert-decode", "llama-decode", "llama-encode", "bge-encode", "t5-encode", "gpt2-encode", "gpt2-decode", "bert-encode", "Qwen2.5-encode"], "axisLabel": { "fontSize": 11 } },
  "series": [{
    "type": "bar",
    "data": [
      { "value": 0.13, "itemStyle": { "color": "#22c55e" } },
      { "value": 0.17, "itemStyle": { "color": "#22c55e" } },
      { "value": 0.28, "itemStyle": { "color": "#22c55e" } },
      { "value": 0.42, "itemStyle": { "color": "#22c55e" } },
      { "value": 0.39, "itemStyle": { "color": "#22c55e" } },
      { "value": 0.43, "itemStyle": { "color": "#22c55e" } },
      { "value": 0.50, "itemStyle": { "color": "#22c55e" } },
      { "value": 0.53, "itemStyle": { "color": "#22c55e" } },
      { "value": 0.58, "itemStyle": { "color": "#22c55e" } }
    ],
    "label": { "show": true, "position": "right", "formatter": "{c}x", "fontSize": 11, "fontWeight": "bold" },
    "markLine": { "silent": true, "data": [{ "xAxis": 1, "lineStyle": { "color": "#ef4444", "type": "dashed", "width": 2 } }], "label": { "formatter": "1.0x (HF)", "position": "end" } }
  }]
}
```
:::

### Performance Summary

::: echarts
```json
{
  "tooltip": { "trigger": "item", "formatter": "{b}: {c} cases ({d}%)" },
  "legend": { "bottom": "5%", "left": "center" },
  "series": [{
    "type": "pie",
    "radius": ["40%", "70%"],
    "avoidLabelOverlap": true,
    "itemStyle": { "borderRadius": 6, "borderColor": "#fff", "borderWidth": 2 },
    "label": { "show": true, "formatter": "{b}\n{c} cases", "fontSize": 12 },
    "data": [
      { "value": 39, "name": "Faster (< 0.9x)", "itemStyle": { "color": "#22c55e" } },
      { "value": 0, "name": "Same Range (0.9-1.1x)", "itemStyle": { "color": "#f59e0b" } },
      { "value": 0, "name": "Slower (> 1.1x)", "itemStyle": { "color": "#ef4444" } }
    ]
  }]
}
```
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
