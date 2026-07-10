---
title: 截断与 Padding
createTime: 2026/07/10 00:00:00
---

# 截断与 Padding

截断和 padding 都是 tokenizer 级配置步骤。它们可以从 `tokenizer.json` 加载，
也可以通过代码配置。

## 截断

```moonbit
let tok = tok.enable_truncation(
  128,
  stride=16,
  strategy=LongestFirst,
  direction=Right,
)
```

面向绑定层的 HF 风格字符串 helper 也可使用：

```moonbit
let tok = tok.enable_truncation_hf(
  128,
  strategy="longest_first",
  direction="right",
)
```

| Strategy | 使用场景 | 说明 |
|---|---|---|
| `LongestFirst` | 通用单句/句对输入 | 从较长一侧移除 |
| `OnlyFirst` | Query 截断 | 当第一段无法承载移除量时抛错 |
| `OnlySecond` | Context 截断 | 常用于 question/context 任务 |

当 `stride > 0` 时，被截断出的窗口会出现在 `enc.overflowing`。

## Padding

```moonbit
let fixed = tok.enable_padding(length=Some(64), pad_token="[PAD]")
let batch = tok.enable_padding() // BatchLongest
```

| Strategy | 行为 | 适合 |
|---|---|---|
| `Fixed(n)` | 每个 encoding 都 pad 到 `n` | 模型输入张量 |
| `BatchLongest` | 每个批次 pad 到批内最长成员 | 动态批处理 |

Padding 位置使用 `attention_mask = 0` 和 `special_tokens_mask = 1`。

## tokenizer.json 严格性

根级 `truncation` 和 `padding` 对象遵循 HF tokenizer JSON schema。缺少必需字段
或 enum 大小写错误时，会抛出 `ParseError`，不会静默回退。

| 根对象 | 必需字段 |
|---|---|
| `truncation` | `max_length`, `stride`, `strategy`; 省略 `direction` 时默认为 `Right` |
| `padding` | `strategy`, `direction`, `pad_id`, `pad_type_id`, `pad_token` |

根 JSON 中的固定 padding 必须把 `strategy` 编码为 `{"Fixed": n}`。
