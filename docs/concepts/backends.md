---
title: Backend Model
createTime: 2026/07/10 00:00:00
---

# Backend Model

The core tokenizer runtime is pure MoonBit. It avoids native addons and keeps
the same tokenizer logic available on every target.

| Package area | Targets | Notes |
|---|---|---|
| Core tokenizer | wasm / wasm-gc / js / native | Loading, encode, decode, save, local cache readers |
| Optional Hub | native / js | HTTP download through `moonbitlang/async/http` |
| Batch compatibility aliases | all | Stable-order serial execution today |
| Benchmarks | native / js / wasm-gc | Compare against Python `tokenizers` where applicable |

## Why No Built-in Multi-thread Worker Runtime?

MoonBit has async and structured concurrency primitives, but this project does
not currently depend on a stable cross-target worker runtime for CPU-bound
tokenizer batches. The public batch APIs preserve deterministic ordering and
work on browser/edge targets without requiring worker setup.

Application code can still shard batch work at the host layer when the runtime
provides workers or threads.
