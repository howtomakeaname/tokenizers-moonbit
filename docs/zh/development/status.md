---
title: Status
createTime: 2026/07/10 00:00:00
---

# Status

项目正在积极收敛到实用的 HF `tokenizers` 对齐状态。

| Milestone | Status | Notes |
|---|---:|---|
| Main encode/decode pipeline | 稳定 | 真实模型 parity fixture 覆盖常见家族 |
| tokenizer.json parser strictness | 进行中 / 基本对齐 | 许多必填字段和类型检查已跟随 HF |
| Added tokens | 稳定 | 已覆盖元数据、Unicode 空白裁剪行为和自省 |
| Hub cache/download | 进行中 | tokenizer.json 路径稳定；更广的 sidecar 生态仍在扩展 |
| Trainers | 进行中 | 带常见参数的确定性 MVP |
| Python binding aliases | 进行中 | 状态、getter、构造器和 display 别名持续扩展 |

## Recent Correctness Closures

- 未知 token 回退错误现在会通过公开 encode API 传播。
- tokenizer.json 严格性已在模型字段、可选字符串、`added_tokens`、Unigram `unk_id` 和根级截断/填充上收紧。
- 高层 `encode(add_special_tokens=false)` 会跳过注入的特殊 token，同时保留非特殊 token 的后处理效果。

完整流水账保留在仓库根目录：
[PROGRESS.md](https://github.com/howtomakeaname/tokenizers-moonbit/blob/main/PROGRESS.md)。
