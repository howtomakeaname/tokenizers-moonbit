# 组件与限制

本页列出已实现的 `tokenizer.json` 组件。未知组件会在加载阶段抛出
`UnsupportedComponent`。

英文版：[`../components.md`](../components.md)

## Models

| `type` | 状态 | 说明 |
|---|---|---|
| `BPE` / byte-level BPE | ✅ | 支持 `byte_fallback`、`fuse_unk`、`ignore_merges` |
| `WordPiece` | ✅ | 贪心最长匹配，支持 `##` 前缀 |
| `Unigram` | ✅ | Viterbi；支持 `byte_fallback`、`fuse_unk` |
| `WordLevel` | ✅ | 整词查表，支持 unk |

## Normalizers

| `type` | 状态 |
|---|---|
| `Lowercase`、`Strip`、`Replace`、`Prepend`、`Sequence` | ✅ |
| `StripAccents` | ✅ |
| `BertNormalizer` | ✅ |
| `NFC` / `NFD` / `NFKC` / `NFKD` | ✅ |
| `Nmt` | ✅ |
| `ByteLevel` normalizer | ✅ |
| `Precompiled` | 🚧 已覆盖常见空白折叠，完整 charsmap 待补 |

## Pre-tokenizers

| `type` | 状态 |
|---|---|
| `ByteLevel` | ✅ |
| `Whitespace`、`WhitespaceSplit`、`BertPreTokenizer`、`Punctuation`、`Metaspace`、`Sequence` | ✅ |
| `Split`：GPT-2 / Qwen-Llama3 / o200k / CLIP / CJK / digit-triplet / 尾部空白正则族 | ✅ |
| `Digits`、`Delimiter`、`FixedLength`、`UnicodeScripts` | ✅ |
| 任意 `Split` 正则 | 🚧 未识别 pattern 退化为单段 |

## Post-processors

| `type` | 状态 |
|---|---|
| `TemplateProcessing`、`BertProcessing`、`RobertaProcessing`、`ByteLevel`、`Sequence` | ✅ |

## Decoders

| `type` | 状态 |
|---|---|
| `ByteLevel`、`WordPiece`、`BPEDecoder`、`Metaspace`、`Fuse`、`Replace`、`Strip`、`Sequence` | ✅ |
| `ByteFallback` | ✅ |
| `CTC` | ✅ |

## 已验证模型

在可选 fixture 存在时，31 个真实模型与 Python `tokenizers` token id 对齐：
gpt2、roberta、llama、bert/bert-cased、distilbert、t5、albert、xlm-roberta、
Qwen2.5、Qwen3、DeepSeek-V2、Phi-3、Mistral、Falcon、StarCoder2、GPT-NeoX、
CLIP、DeBERTa、Llama-3.2、Phi-4-mini、DeepSeek-R1-Distill-Qwen、DeepSeek-V3.2、
GPT-OSS、GLM-4.5、Granite-4、Qwen3-Coder、Qwen3-VL、BGE-M3、multilingual-E5。

## 限制

- **Precompiled charsmap：** 仅覆盖常见 SentencePiece 空白折叠；完整二进制
  charsmap 解码仍待实现。
- **任意 Split 正则：** 当前识别主流 tokenizer 的常见正则族，并覆盖 `\s+`、
  `\S+`、`\s+$`、`\s{2,}` / `\s{3,}` / `\s{4,}` 以及 `\s{2}` /
  `\s{3}` / `\s{4}` 精确空白 run、`[\r\n]+` 及 `{2,}` / `{3,}` /
  `{4,}`、`{2}` / `{3}` / `{4}` 换行量词、`[^\S\r\n]+` 及水平空白
  `{2..4}` 最小/精确量词、`\d+`、`\D+`、
  `[\d]+` / `[^\d]+` / `\P{N}+` 数字类别名、`\d{2,}` / `[\d]{2,}` 最小数字 run、`\d{2}` / `\d{3}` / `\d{4}` 精确数字 run、
  `\d{1,2}` / `\d{1,3}` / `\d{1,4}` 及 `\p{N}` 别名、anchored digit/word/letter run、
  `\w{2,}` / `\w{2}` / `{1,2}` / `{1,3}` / `{1,4}` bounded word/ASCII/Unicode letter run / `[A-Za-z]{2,}` / `\p{L}{3}` 等 word/letter 量词 run、
  `\p{P}{2,}` / `\p{P}{2}` / `\p{S}{2}` / `{1,n}` bounded punctuation/symbol/`\p{P}\p{S}` union run / `[\p{P}\p{S}]{2,}` 等 punctuation/symbol 量词 run、
  `\w+` / `\W+`、`[A-Za-z0-9]+` / `[A-Za-z]+` 及反集、`\p{L}+` / `\P{L}+`、`\p{P}+` / `\P{P}+`、
  `\p{S}+` / `\P{S}+`、`[\p{P}\p{S}]+`、`[^\s\p{L}\p{N}]+` 等简单 span；复杂未知 pattern 会在加载时抛出
  `UnsupportedComponent`，避免静默产生不对齐切分。通用 Unicode regex 引擎不在现阶段范围内。
- **Regex Replace：** `Replace` normalizer/decoder 已支持 `\s+`、`^\s+`、`\s+$`、
  `\s{2,}` / `\s{3,}` / `\s{4,}` 与 `\s{2}` / `\s{3}` / `\s{4}`、
  `[\r\n]+` 及 `{2..4}` 最小/精确换行量词、`[^\S\r\n]+` / `[ \t]+` 水平空白 `{2..4}` 最小/精确量词、` {2,}`、anchored digit/word/letter/punctuation/symbol run，
  以及 `\d+` / `[\d]+` / `\D+` / `\P{N}+`、`\d{2,}` / `[\d]{2,}`、`\d{2}` / `\d{3}` / `\d{4}`、`\w{2,}` / `\w{2}` / `{1,2}` / `{1,3}` / `{1,4}` bounded word/ASCII/Unicode letter run / `[A-Za-z]{2,}` / `\p{L}{3}`、`\p{P}{2,}` / `\p{P}{2}` / `\p{S}{2}` / `{1,n}` bounded punctuation/symbol/`\p{P}\p{S}` union run / `[\p{P}\p{S}]{2,}`、`\w+` / `\W+`、`[A-Za-z0-9]+` / `[A-Za-z]+` 及反集、`\p{L}+` / `\P{L}+`、
  `\p{P}+` / `\P{P}+`、`\p{S}+` / `\P{S}+`、`[\p{P}\p{S}]+`、
  `[^\s\p{L}\p{N}]+` 替换；更复杂正则替换待补。
- **Offsets：** 默认返回字符偏移；可通过 byte-offset encode API 对齐 HF byte offsets。
- **Batch：** `encode_batch` 为串行实现，适配 wasm/js 目标。
- **性能：** BPE 合并使用优先队列与惰性失效，BPE / WordPiece / Unigram 均带
  repeated-word cache；加载时直接填充 dense 反向词表。
- **训练：** 已支持确定性 WordLevel 训练，可使用默认 `WhitespaceSplit`、调用方传入的
  pre-tokenizer 或已预切分 token 流，并支持 `min_frequency`、`special_tokens`、
  `vocab_size` 以及 HF 风格的频次/词典序词表排序；也已提供确定性 WordPiece、
  BPE 与 Unigram trainer MVP，支持相同输入模式以及 continuation prefix、
  end-of-word suffix、`max_input_chars_per_word`、`byte_fallback` 等常见参数。
- **构造型 tokenizer 序列化：** 训练得到的 WordLevel / WordPiece / BPE / Unigram tokenizer 可序列化常见
  pre-tokenizer，如 ByteLevel、Metaspace、Punctuation、Split、Digits、Delimiter、
  FixedLength、UnicodeScripts 和 Sequence。
