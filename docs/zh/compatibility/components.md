---
title: Component Matrix
createTime: 2026/07/10 00:00:00
---

# Component Matrix

## Models

| Model | 状态 | 说明 |
|---|---:|---|
| BPE | 支持 | byte fallback、fuse unk、dropout 解析、ignore merges |
| WordPiece | 支持 | 贪心最长匹配、prefix/suffix 选项 |
| Unigram | 支持 | Viterbi，unknown fallback 时严格检查缺失的 `unk_id` |
| WordLevel | 支持 | whole-token lookup，并严格执行 unk fallback |

## Pipeline Components

| Family | 支持示例 | 说明 |
|---|---|---|
| Normalizers | Lowercase, Strip, Replace, BertNormalizer, Unicode forms, NMT, Precompiled | 支持 Unicode tables 和 SentencePiece charsmap |
| Pre-tokenizers | ByteLevel, Whitespace, BertPreTokenizer, Split, Metaspace, Digits, UnicodeScripts | Regex 子集是确定性的，并会显式报错 |
| Post-processors | TemplateProcessing, BertProcessing, RobertaProcessing, ByteLevel, Sequence | `add_special_tokens=false` 仍保留非 special 效果 |
| Decoders | ByteLevel, WordPiece, BPE, Metaspace, Fuse, Replace, Strip, ByteFallback, CTC | 支持 Sequence 组合 |
| Trainers | WordLevel, WordPiece, BPE, Unigram MVPs | 以确定性 trainer 行为覆盖常见 HF 选项 |

## Parser Strictness Highlights

| 范围 | 行为 |
|---|---|
| Model 必需字段 | 在 HF 要求处拒绝缺失的 `unk_token`、`merges`、WordPiece prefix/max 字段 |
| Optional strings | 错误类型的 optional string 会被拒绝，而不是当作缺失处理 |
| Unigram `unk_id` | 允许缺失/null；错误类型或越界值会被拒绝 |
| `added_tokens` | 对存在的条目要求完整 HF schema |
| Root truncation/padding | 必需字段和 enum 大小写匹配 HF tokenizer JSON |

完整细节见组件页：
[组件矩阵](/tokenizers-moonbit/zh/compatibility/components/)。
