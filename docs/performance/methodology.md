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

## Trend tracking

A full run is a point-in-time snapshot, so `scripts/bench_trend.py` keeps a
local history and diffs two runs to catch real regressions:

```bash
# archive a full run (writes reports/trend/<timestamp>_<target>_v<ver>.json)
python3 scripts/bench_trend.py save reports/bench-native-all.json --note "manual"
python3 scripts/bench_trend.py list

# diff against a baseline; exits non-zero on a confirmed regression
python3 scripts/bench_trend.py compare previous.json reports/bench-native-all.json
```

A row counts as a regression only when both the Moon/HF ratio worsens by at
least `--threshold` (default 1.20x) AND the absolute Moon time grows by at
least `--abs-threshold` (default 1.15x). The second condition prevents
HF-side timing jitter on an unchanged Moon row from raising a false alarm;
ratio-only fluctuations are listed separately. The trend directory is
git-ignored because timings are machine- and load-specific.

The `Benchmark nightly` workflow runs the full matrix daily at 02:17 UTC (and
on demand via `workflow_dispatch`), archives the JSON as a 90-day artifact,
and fails when the comparison against the previous successful run reports a
regression.
