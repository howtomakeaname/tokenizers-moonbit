---
title: Testing
createTime: 2026/07/10 00:00:00
---

# Testing

## Core Matrix

```bash
moon fmt --check
moon check --deny-warn
moon test --target native --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
```

## Optional Parity Fixtures

```bash
python3 scripts/fetch_models.py
pip install tokenizers
python3 scripts/gen_parity.py
moon test --target native
```

## What to Test for Behavior Changes

| Change area | Required coverage |
|---|---|
| tokenizer.json parsing | 正向 fixture，加上字段类型错误/缺失字段的负向测试 |
| encode pipeline | 若触及共享 helper，覆盖单输入、文本对、批量、fast 和预分词场景 |
| offsets | 对齐敏感修复需覆盖字符 offset 和字节 offset 变体 |
| Hub logic | 本地缓存 helper 测试，以及 HTTP 状态/元数据决策 |
| Trainers | 确定性输入语料；配置变化时覆盖状态 round-trip |

## Review Discipline

先跑聚焦测试以快速发现局部失败；在提交用户可见的行为变化前，再运行完整目标矩阵。
