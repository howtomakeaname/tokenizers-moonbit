---
title: Methodology
createTime: 2026/07/10 00:00:00
---

# Methodology

Benchmark work follows three rules:

1. Compare MoonBit and Python `tokenizers` on the same model and corpus.
2. Keep correctness fixtures passing before interpreting speed.
3. Treat `Moon/HF > 1.10x` as a concrete optimization backlog item.

## Corpora

| Corpus | Purpose |
|---|---|
| `short` | Interactive overhead and chat-style snippets |
| `mixed` | English, CJK and punctuation paragraph |
| `code` | MoonBit-like code and identifiers |
| `long` | Long-document BPE/Unigram stress |

## Outputs

`bench_compare.py` can write JSON artifacts for CI or dashboards:

```bash
python3 scripts/bench_compare.py --target native --corpus all \
  --fail-above 1.10 --json-out reports/bench-native-all.json
```

For the documentation site, convert a raw benchmark report into the static
snapshot consumed by the performance page:

```bash
node scripts/update-docs-benchmarks.mjs reports/bench-native-all.json
```

CI keeps the raw `reports/bench-native-mixed.json` as an artifact, while Pages
uses `docs/.vuepress/public/benchmarks/latest.json` for the rendered chart and
table.
