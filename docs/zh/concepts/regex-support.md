---
title: Regex Strategy
createTime: 2026/07/10 00:00:00
---

# Regex Strategy

`tokenizers-moonbit` 不内嵌完整的回溯式或通用 Unicode regex 引擎。它改为针对常见
HuggingFace tokenizer regex 族实现确定性 scanner，并对不支持的模式显式失败。

## Policy

| 模式类别 | 行为 |
|---|---|
| GPT-2 / Qwen / o200k / CLIP split patterns | 已实现 |
| 常见空白、数字、标点和 CJK span | 已实现 |
| 简单 literal alternatives | 已实现 |
| Look-around、backreferences、复杂 grouping | 不支持 |
| 未知 tokenizer.json regex | 抛出 `UnsupportedComponent` |

该策略避免 wasm/js target 上出现静默 tokenizer 漂移，同时覆盖主流 tokenizer
配置使用的模式。

## Migration Advice

如果自定义 tokenizer 依赖复杂 regex：

1. 先用 `Tokenizer::from_str` 加载。
2. 如果加载时抛出 `UnsupportedComponent`，将模式缩减为受支持的确定性族，或在宿主代码中预分词。
3. 添加 fixture 测试，将 token id 与 Python `tokenizers` 对比。

组件参考页维护完整模式列表：
[组件矩阵](/tokenizers-moonbit/zh/compatibility/components/)。
