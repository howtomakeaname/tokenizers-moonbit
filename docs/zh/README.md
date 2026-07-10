---
title: 首页
createTime: 2026/07/10 00:00:00
home: true
config:
  - type: hero
    index: 0
    effect: tint-plate
    effectConfig:
      light:
        r: { value: 228, offset: 18 }
        g: { value: 238, offset: 16 }
        b: { value: 232, offset: 20 }
      dark:
        r: { value: 20, offset: 18 }
        g: { value: 42, offset: 18 }
        b: { value: 38, offset: 20 }
    hero:
      name: tokenizers-moonbit
      tagline: 面向 MoonBit 的 HuggingFace tokenizer 兼容实现。
      text: 用纯 MoonBit 运行时加载 tokenizer.json，并在 wasm、wasm-gc、js 与 native target 上完成 encode/decode。
      actions:
        - text: 使用指南
          link: /zh/usage.html
          theme: brand
        - text: API 参考
          link: /zh/api.html
          theme: alt
  - type: features
    index: 1
    title: 为跨 target tokenizer 兼容而构建
    features:
      - title: 纯 MoonBit 运行时
        details: 同一套实现覆盖 wasm、wasm-gc、js 与 native，无需原生 addon。
      - title: 标准 tokenizer.json
        details: 直接加载 HuggingFace tokenizer.json，并保持 familiar pipeline 语义。
      - title: 真实模型对齐
        details: 可选 fixture 测试持续对拍 Python tokenizers，覆盖经典与现代模型族。
---

`tokenizers-moonbit` 是 HuggingFace `tokenizers` 的 MoonBit 实现，目标是在
`wasm`、`wasm-gc`、`js`、`native` 等 MoonBit target 上直接加载标准
`tokenizer.json` 并执行 encode/decode。

## 快速入口

| 主题 | 链接 | 内容 |
|---|---|---|
| 快速开始 | [快速开始](/tokenizers-moonbit/zh/guide/getting-started.html) | 安装、加载方式和 pipeline |
| 编码与解码 | [编码与解码](/tokenizers-moonbit/zh/guide/encoding-decoding.html) | 单句、句对、批量与 decode |
| 兼容性 | [组件矩阵](/tokenizers-moonbit/zh/compatibility/components.html) | 支持矩阵和已知边界 |
| API 参考 | [参考](/tokenizers-moonbit/zh/reference/) | Tokenizer、组件、错误和 Hub |
| 迁移指南 | [从 HuggingFace 迁移](/tokenizers-moonbit/zh/migration/from-huggingface.html) | API 映射和语义差异 |

## 核心能力

- 纯 MoonBit 实现，无原生 addon。
- 支持 BPE、WordPiece、Unigram、WordLevel。
- 支持常见 normalizer、pre-tokenizer、post-processor、decoder。
- 可选 `@hub` 包支持 native/js 在线下载，核心包保持离线和全 target 可用。
- 文档源码直接维护在 main 分支 `docs/` 目录，GitHub Actions 构建到 `gh-pages-deploy/` 并发布。

```mermaid
flowchart LR
  A[main docs/] --> B[VuePress / Plume]
  B --> C[gh-pages-deploy]
  C --> D[GitHub Pages]
```
