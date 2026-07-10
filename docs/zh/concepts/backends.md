---
title: Backend Model
createTime: 2026/07/10 00:00:00
---

# Backend Model

核心 tokenizer 运行时是纯 MoonBit 实现。它避免原生 addon，并让同一套
tokenizer 逻辑可用于所有 target。

| 包区域 | Targets | 说明 |
|---|---|---|
| Core tokenizer | wasm / wasm-gc / js / native | 加载、encode、decode、保存、本地缓存读取 |
| Optional Hub | native / js | 通过 `moonbitlang/async/http` 进行 HTTP 下载 |
| Batch compatibility aliases | all | 当前为稳定顺序的串行执行 |
| Benchmarks | native / js / wasm-gc | 在适用场景下与 Python `tokenizers` 对比 |

## Why No Built-in Multi-thread Worker Runtime?

MoonBit 提供 async 和结构化并发原语，但本项目目前不依赖稳定的跨 target
worker runtime 来处理 CPU-bound tokenizer batch。公开 batch API 保持确定性顺序，
并且无需 worker 设置即可在 browser/edge target 上运行。

当宿主 runtime 提供 worker 或线程时，应用代码仍然可以在宿主层拆分 batch 工作。
