---
title: Limitations
createTime: 2026/07/10 00:00:00
---

# Limitations

The project is intentionally conservative: unsupported behavior should be
visible, not silently approximated.

| Area | Current boundary | Workaround |
|---|---|---|
| General regex | Full backtracking / arbitrary Unicode regex is not embedded | Use supported patterns or host-side pre-tokenization |
| CPU-bound batch parallelism | Compatibility APIs are stable-order serial | Shard at host/runtime layer if workers are available |
| Training parity | Deterministic MVPs cover common knobs, full HF trainer internals still evolving | Use saved `tokenizer.json` from HF for production parity |
| Hub sidecars | Raw sidecar cache bridge exists; automatic full sidecar ecosystem is still expanding | Load tokenizer JSON first and pass needed sidecars explicitly |
| Offset remapping | Ongoing parity work around length-changing normalizers | Prefer byte-offset APIs and add fixture tests for alignment-sensitive use |

See [PROGRESS.md](https://github.com/howtomakeaname/tokenizers-moonbit/blob/main/PROGRESS.md)
for the full current backlog.
