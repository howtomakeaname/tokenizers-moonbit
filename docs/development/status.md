---
title: Status
createTime: 2026/07/10 00:00:00
---

# Status

The project is actively converging on practical HF `tokenizers` parity.

| Milestone | Status | Notes |
|---|---:|---|
| Main encode/decode pipeline | Stable | Real model parity fixtures cover common families |
| tokenizer.json parser strictness | Active / mostly aligned | Required field/type checks follow HF in many areas |
| Added tokens | Stable | Metadata, Unicode whitespace strip behavior and introspection covered |
| Hub cache/download | Active | tokenizer.json path is robust; broader sidecar ecosystem expanding |
| Trainers | Active | Deterministic MVPs with common knobs |
| Python binding aliases | Active | State, getters, constructor and display aliases continue expanding |

## Recent Correctness Closures

- Unknown-token fallback errors now propagate through public encode APIs.
- tokenizer.json strictness has been tightened for model fields, optional
  strings, `added_tokens`, Unigram `unk_id`, and root truncation/padding.
- High-level `encode(add_special_tokens=false)` preserves non-special
  post-processing effects while omitting injected specials.

The complete ledger stays in the repository root:
[PROGRESS.md](https://github.com/howtomakeaname/tokenizers-moonbit/blob/main/PROGRESS.md).
