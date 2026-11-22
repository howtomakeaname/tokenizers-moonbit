---
title: Status
createTime: 2026/07/10 00:00:00
---

# Status

The project is actively converging on practical HF `tokenizers` parity.

| Milestone | Status | Notes |
|---|---:|---|
| Main encode/decode pipeline | Stable | 39 real-model fixture families, all four backends green |
| tokenizer.json parser strictness | Stable | Required field/type checks follow HF; unsupported components fail loudly |
| Added tokens | Stable | Metadata, Unicode whitespace strip behavior and introspection covered |
| Hub cache/download | Stable | tokenizer.json path robust; sidecar outcomes distinguish 404 from real failures |
| Trainers | Stable | Real Unigram EM trainer (HF 0.22.2 do_train port); BPE/WordPiece/WordLevel complete |
| Python binding aliases | Stable | 263 HF surface methods audited and covered |

## Recent Correctness Closures

- Unknown-token fallback errors now propagate through public encode APIs.
- tokenizer.json strictness has been tightened for model fields, optional
  strings, `added_tokens`, Unigram `unk_id`, and root truncation/padding.
- High-level `encode(add_special_tokens=false)` preserves non-special
  post-processing effects while omitting injected specials.

The complete ledger stays in the repository root:
[PROGRESS.md](https://github.com/howtomakeaname/tokenizers-moonbit/blob/main/PROGRESS.md).
