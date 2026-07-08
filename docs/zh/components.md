# 组件与限制

本页列出已实现的 `tokenizer.json` 组件。未知组件会在加载阶段抛出
`UnsupportedComponent`。

英文版：[`../components.md`](../components.md)

## Models

| `type` | 状态 | 说明 |
|---|---|---|
| `BPE` / byte-level BPE | ✅ | 支持 `byte_fallback`、`fuse_unk`、`ignore_merges` |
| `WordPiece` | ✅ | 贪心最长匹配，支持 `##` 前缀、`end_of_word_suffix` 与 `max_input_chars_per_word` |
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
| `Precompiled` | ✅ 解析 SentencePiece 二进制 double-array `precompiled_charsmap`；空 map 保留 NFKC + 全 Unicode 空白折叠与 ASCII fast path |

## Pre-tokenizers

| `type` | 状态 |
|---|---|
| `ByteLevel` | ✅ |
| `Whitespace`、`WhitespaceSplit`、`BertPreTokenizer`、`Punctuation`、`Metaspace`、`Sequence` | ✅ |
| `Split`：GPT-2 / Qwen-Llama3 / o200k / CLIP / CJK / digit-triplet / 尾部空白正则族 | ✅ |
| `Digits`、`Delimiter`、`FixedLength`、`UnicodeScripts` | ✅ |
| 任意 `Split` 正则 | 🚧 已支持的 deterministic family 正常加载；JSON 中不支持的 regex pattern 在加载期抛 `UnsupportedComponent`（手写构造的运行时 fallback 仍为单段） |

## Post-processors

| `type` | 状态 |
|---|---|
| `TemplateProcessing`、`BertProcessing`、`RobertaProcessing`、`ByteLevel`、`Sequence` | ✅ |

## Decoders

| `type` | 状态 |
|---|---|
| `ByteLevel`、`WordPiece`、`BPEDecoder`、`Metaspace`、`Fuse`、`Replace`、`Strip`、`Sequence` | ✅（`WordPiece` cleanup 已改为单遍 BERT 标点/缩写 fast path） |
| `ByteFallback` | ✅ |
| `CTC` | ✅ |

## 已验证模型

在可选 fixture 存在时，39 个真实模型与 Python `tokenizers` token id 对齐：
gpt2、roberta、llama、bert/bert-cased、distilbert、t5、albert、xlm-roberta、
Qwen2.5、Qwen3、DeepSeek-V2、Phi-3、Mistral、Falcon、StarCoder2、GPT-NeoX、
CLIP、DeBERTa、Llama-3.2、Phi-4-mini、DeepSeek-R1-Distill-Qwen、DeepSeek-V3.2、
GPT-OSS、GLM-4.5、Granite-4、Qwen3-Coder、Qwen3-VL、BGE-M3、multilingual-E5、
ModernBERT、GTE-ModernBERT、MiniLM、BGE-large-en、Jina embeddings、Nomic Embed、
E5-small、MixedBread、SmolLM2。

## 限制

- **通用正则引擎：** 本项目不内置完整 backtracking 或完整通用 Unicode regex
  引擎。当前支持的 `Split` / `Replace` regex family 来自真实 HuggingFace
  tokenizer 配置，并以 deterministic scanner 实现。look-ahead/look-behind、
  backreference、任意 alternation/grouping 语义以及未覆盖的 Unicode property
  组合，在迁移前需要单独验证。
- **Precompiled charsmap：** tokenizer.json 中的 `precompiled_charsmap` 会先做
  base64 解码，再按 SentencePiece double-array trie 应用到 Unicode scalar；空/缺失
  map 继续走常见 SPM NFKC + Unicode 空白折叠路径，并保留 ASCII fast path。
- **任意 Split 正则：** 当前识别主流 tokenizer 的常见正则族，并覆盖 literal / escaped-literal
  alternatives（`foo|bar`、`(foo|bar)`、`(?:foo|bar)`、`foo|a\\.b`，以及
  `^foo$` / `\\bfoo\\b` / `^(?:foo|bar)` / `(?:foo|bar)$` /
  `\\b(?:foo|bar)\\b` 这类 anchored / word-boundary 形式）、`\s+`、
  `\S+`、`\s+$`、`\s{2,}` / `\s{3,}` / `\s{4,}` 以及 `\s{2}` /
  `\s{3}` / `\s{4}` 精确空白 run、`[\r\n]+` 及 `{2,}` / `{3,}` /
  `{4,}`、`{2}` / `{3}` / `{4}` 换行量词、`[^\S\r\n]+` 及水平空白
  `{2..4}` 最小/精确量词、`\d+`、`\D+`、
  `[\d]+` / `[^\d]+` / `\P{N}+` 数字类别名、`\d{2,}` / `[\d]{2,}` 最小数字 run、`\d{2}` / `\d{3}` / `\d{4}` 精确数字 run、
  `\d{1,2}` / `\d{1,3}` / `\d{1,4}` / `\d{2,4}` 及 `\p{N}` 别名、anchored digit/word/letter run、
  `\w{2,}` / `\w{3,}` / `\w{2}` / `{1,2}` / `{1,3}` / `{1,4}` bounded 与 `{2,3}` / `{2,4}` / `{3,4}` ranged word/ASCII/Unicode letter run / `[A-Za-z]{2,}` / `\p{L}{3}` 等 word/letter 量词 run、
  `\p{P}{2,}` / `\p{P}{2}` / `\p{S}{2}` / `{1,n}` bounded 与 `{2,n}` ranged punctuation/symbol/`\p{P}\p{S}` union run / `[\p{P}\p{S}]{2,}` 等 punctuation/symbol 量词 run，
  以及 `\D{3,}` / `\D{4}`、`\S{2,}`、`\W{2}`、`\P{L}{3,}`、`\P{P}{4}`、`\P{S}{2,}`、反向 ASCII class、`[^\p{P}\p{S}]{3,}` 和 `[^\s\p{L}\p{N}]{4}` 等 exact/min/bounded/ranged 反集 run、
  `\w+` / `\W+`、`[A-Za-z0-9]+` / `[A-Za-z]+` 及反集、`\p{L}+` / `\P{L}+`、`\p{P}+` / `\P{P}+`、
  `\p{S}+` / `\P{S}+`、`[\p{P}\p{S}]+`、`[^\s\p{L}\p{N}]+` 等简单 span，以及每个分支都是普通或 escaped literal 的简单 literal / alternation（如 `^foo$` / `\\bfoo\\b` / `foo|bar` / `(?:foo|bar)` / `^(?:foo|bar)` / `(?:foo|bar)$` / `\\b(?:foo|bar)\\b`）；复杂未知 pattern 会在加载时抛出
  `UnsupportedComponent`，避免静默产生不对齐切分。通用 Unicode regex 引擎不在现阶段范围内。
- **Regex Replace：** `Replace` normalizer/decoder 已支持 `\s+`、`^\s+`、`\s+$`、
  `\s{2,}` / `\s{3,}` / `\s{4,}` 与 `\s{2}` / `\s{3}` / `\s{4}`、
  `[\r\n]+` 及 `{2..4}` 最小/精确换行量词、`[^\S\r\n]+` / `[ \t]+` 水平空白 `{2..4}` 最小/精确量词、` {2,}`、anchored positive/inverse class run（如 `^\s+` / `\s+$` / `^\S+` / `\D+$` / `^\P{Letter}+` / `\P{Punctuation}+$` / `^[^\p{P}\p{S}]+` / `[^\s\p{L}\p{N}]+$`），
  以及 `\d+` / `[\d]+` / `\D+` / `\P{N}+`、`\d{2,}` / `[\d]{2,}`、`\d{2}` / `\d{3}` / `\d{4}` / `\d{2,4}`、`\w{2,}` / `\w{3,}` / `\w{2}` / `{1,2}` / `{1,3}` / `{1,4}` bounded 与 `{2,3}` / `{2,4}` / `{3,4}` ranged word/ASCII/Unicode letter run / `[A-Za-z]{2,}` / `\p{L}{3}`、`\p{P}{2,}` / `\p{P}{2}` / `\p{S}{2}` / `{1,n}` bounded 与 `{2,n}` ranged punctuation/symbol/`\p{P}\p{S}` union run / `[\p{P}\p{S}]{2,}`、`\D{3,}` / `\D{4}` / `\W{2}` / `\P{L}{3,}` / `\P{P}{4}` / `\P{S}{2,}` / `[^\s\p{L}\p{N}]{4}` 等 exact/min/bounded/ranged 反集 run、`\w+` / `\W+`、`[A-Za-z0-9]+` / `[A-Za-z]+` 及反集、`\p{L}+` / `\P{L}+`、
  `\p{P}+` / `\P{P}+`、`\p{S}+` / `\P{S}+`、`[\p{P}\p{S}]+`、
  `[^\s\p{L}\p{N}]+` 和简单 literal alternation 替换；Normalizer 与 Decoder `Replace` 会先分发
  bounded/ranged 量词热路径，再进入通用 span fallback，使对应 micro benchmark
  保持快于 HF；更复杂正则替换待补。
- **Offsets：** 默认返回字符偏移；可通过 byte-offset encode API 对齐 HF byte offsets。
- **Batch：** `encode_batch` 为串行实现，适配 wasm/js 目标。
- **性能：** BPE 合并使用优先队列与惰性失效，BPE / WordPiece / Unigram 均带
  repeated-word cache；加载时直接填充 dense 反向词表。重复或交替 `from_str`
  加载会复用小型 parsed-JSON cache，但每次仍构建全新的 tokenizer 状态。
- **训练：** 已支持确定性 WordLevel 训练，可使用默认 `WhitespaceSplit`、调用方传入的
  pre-tokenizer 或已预切分 token 流，并支持 `min_frequency`、`special_tokens`、
  `vocab_size` 以及 HF 风格的频次/词典序词表排序；也已提供确定性 WordPiece、
  BPE 与 Unigram trainer MVP，支持相同输入模式以及 continuation prefix、
  end-of-word suffix、`max_input_chars_per_word`、`byte_fallback` 等常见参数；
  WordPiece 与 BPE training 还支持 HF 风格 `initial_alphabet` / `limit_alphabet`，
  WordPiece 已支持 `end_of_word_suffix` 的 encode 与 JSON 往返，WordPiece/BPE 均支持
  `max_token_length`，并提供 `byte_level_alphabet()` 暴露 256 个 ByteLevel symbols，便于 GPT-2/RoBERTa 风格训练。
- **构造型 tokenizer 序列化：** 训练得到的 WordLevel / WordPiece / BPE / Unigram tokenizer 可序列化常见
  pre-tokenizer，如 ByteLevel、Metaspace、Punctuation、Split、Digits、Delimiter、
  FixedLength、UnicodeScripts 和 Sequence。
