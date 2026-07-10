---
title: Limitations
createTime: 2026/07/10 00:00:00
---

# Limitations

项目有意保持保守：不支持的行为应该可见，而不是被静默近似。

| 范围 | 当前边界 | 规避方式 |
|---|---|---|
| 通用 regex | 不内嵌完整回溯式或任意 Unicode regex | 使用受支持模式，或在宿主侧预分词 |
| CPU-bound batch parallelism | 兼容 API 是稳定顺序的串行执行 | 如 runtime 提供 worker，可在宿主/runtime 层分片 |
| Training parity | 确定性 MVP 覆盖常见选项，完整 HF trainer 内部行为仍在演进 | 生产对齐优先使用 HF 保存的 `tokenizer.json` |
| Hub sidecars | 已有 raw sidecar cache bridge；自动化完整 sidecar 生态仍在扩展 | 先加载 tokenizer JSON，并显式传入所需 sidecar |
| Offset remapping | 对长度变化 normalizer 的 parity 工作仍在进行 | 优先使用 byte-offset API，并为对齐敏感用途添加 fixture 测试 |

完整当前 backlog 见
[PROGRESS.md](https://github.com/howtomakeaname/tokenizers-moonbit/blob/main/PROGRESS.md)。
