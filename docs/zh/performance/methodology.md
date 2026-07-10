---
title: 方法论
createTime: 2026/07/10 00:00:00
---

# 方法论

基准测试工作遵循三条规则：

1. 在相同模型和语料上比较 MoonBit 与 Python `tokenizers`。
2. 先保持正确性 fixture 通过，再解读速度结果。
3. 将 `Moon/HF > 1.10x` 视为明确的优化 backlog 项。

## 语料

| Corpus | 目的 |
|---|---|
| `short` | 交互开销和聊天式短片段 |
| `mixed` | 英文、CJK 和标点段落 |
| `code` | 类 MoonBit 代码和标识符 |
| `long` | 长文档 BPE/Unigram 压力测试 |

## 输出

`bench_compare.py` 可以为 CI 或仪表盘写出 JSON artifact：

```bash
python3 scripts/bench_compare.py --target native --corpus all \
  --fail-above 1.10 --json-out reports/bench-native-all.json
```

文档站会把原始 benchmark report 转换成 performance 页面消费的静态快照：

```bash
node scripts/update-docs-benchmarks.mjs reports/bench-native-all.json
```

CI 会保留原始 `reports/bench-native-mixed.json` artifact，Pages 则使用
`docs/.vuepress/public/benchmarks/latest.json` 渲染图表和表格。
