# 开发进度与任务跟踪（tokenizers-moonbit）

本文件用于跟踪实现进度，便于后续开发者接替。每个阶段标注状态、产出文件、验证方式与已知缺口。

> 状态图例：✅ 已完成 / 🚧 进行中 / ⬜ 未开始 / ⏸ 暂缓（TODO）

## 总览

| 阶段 | 内容 | 状态 |
|---|---|---|
| P0 | 项目骨架 + JSON 解析接通 | ✅ |
| P1 | tokenizer.json 反序列化（vocab/merges/各组件配置） | ✅ |
| P2 | BPE encode（非字节级，rank 合并） | ✅ |
| P3 | 字节级 BPE + ByteLevel pre-tokenizer（GPT-2 对齐） | ✅ |
| P4 | decode | ✅ |
| P5 | WordPiece（BERT 对齐） | ✅ |
| P6 | Unigram（T5 对齐）+ Metaspace | ✅ |
| P7 | 后处理 / 特殊 token / encode_pair | ✅ |
| P8 | 跨后端验证（wasm/wasm-gc/js/native） | ✅ |
| R1 | AddedVocabulary（文本内 special token 预切分） | ✅ |
| R2 | WordLevel + byte_fallback + fuse_unk + ignore_merges + ByteFallback decoder | ✅ |
| R3 | 多模型对拍设施 + CI | ✅ |
| R4 | truncation / padding / encode_batch | ✅ |
| R5 | Unicode 归一化最小集（NFD+Mn / strip_accents） | ✅ |
| R6 | pre_tokenizer/decoder/template DSL 补全 | 🚧（ByteFallback 已在 R2 完成）|
| R7 | benchmark 套件 + 与 HF 跑分 | ✅ |
| R8 | 文档 + 迁移指南 | ✅ |
| R9 | HF 无缝迁移缺口收敛（API / offsets / charsmap / save / pretrained） | 🚧 |
| R10 | 架构治理与模块化（公共库 / 测试与基准分层 / HF 风格组件边界） | 🚧 |

## R10：架构治理与模块化计划

目标：在不破坏现有 HF parity、全后端测试与 benchmark 对比的前提下，逐步把项目整理成更接近 HF tokenizers 的组件化结构：公共工具层 → normalizers / pre_tokenizers / models / processors / decoders → tokenizer façade → tests/bench harness。

迁移原则：每一步都必须是小步可回滚；先抽无状态、无依赖的公共 helper，再移动测试/bench；所有阶段完成后运行 `moon test --target wasm/wasm-gc/js/native`，性能结论仍以 `scripts/bench_compare.py` 的 Moon/HF ratio 为准。

| 阶段 | 内容 | 状态 | 验证 |
|---|---|---|---|
| A0 | 项目名从 `tokenizer-moonbit` 修正为 `tokenizers-moonbit`，同步 module/import/doc/script 引用 | ✅ | wasm/wasm-gc/js/native 测试通过 |
| A1 | 新增 dependency-free `common` 包，先承载跨组件复用的字符谓词与 tiny string helper | ✅ | wasm/wasm-gc/js/native 测试通过；`bench_compare.py --quick --target native` 通过 |
| A2 | 继续抽离通用 Regex 子集/replace-run helper，统一 normalizer/decoder/pretokenizer 的简单正则语义 | ✅ | 已抽 common replace/run helper 与 Split 简单正则 span helper，并新增 wbtest；wasm/wasm-gc/js/native 测试通过，`bench_compare.py --quick --target native` 通过 |
| A3 | 拆分 bench harness：将 tokenizer 包内超大 `bench_test.mbt` 迁移到独立 benchmarks 包/目录，仅通过公开 API 依赖 tokenizer | ✅ | wasm/wasm-gc/js/native 测试通过；`scripts/bench_compare.py --quick --target native` 通过 |
| A4 | 分层整理测试：保留组件 wbtest/核心 API 单测贴近源码，迁移 fixture/parity 集成用例到独立 integration 包，避免 tokenizer 源码目录膨胀 | ✅ | wasm/wasm-gc/js/native 测试通过；fixture 缺失保持自动跳过；`bench_compare.py --quick --target native` 通过 |
| A5 | 梳理 public API façade：tokenizer 包只暴露稳定 API，组件包保持 HF pipeline 边界清晰 | ✅ | 已收窄 padding/truncation 内部执行 helper 可见性；保留 Tokenizer/Params/builder/trainer 公开 API；wasm/wasm-gc/js/native 测试通过，`bench_compare.py --quick --target native` 通过 |

## 已对齐验证的真实模型（与 Python `tokenizers` 逐 token id 一致）

通过表驱动的 `parity_test.mbt`（`scripts/fetch_models.py` + `scripts/gen_parity.py` 生成期望），覆盖 31 个真实/公开 tokenizer.json 模型（fixture 缺失时自动跳过）：

| 模型 | 类型 | 状态 |
|---|---|---|
| gpt2 | 字节级 BPE | ✅（+ `<|endoftext|>` 内联特殊 token / decode 往返）|
| roberta-base | 字节级 BPE | ✅ |
| llama (hf-internal-testing) | BPE + byte_fallback + Metaspace | ✅（emoji 字节回退 + decode 往返）|
| bert-base-uncased | WordPiece | ✅（+ 特殊 token / type_ids / mask / encode_pair）|
| bert-base-cased | WordPiece | ✅ |
| distilbert-base-uncased | WordPiece | ✅ |
| t5-small | Unigram + Metaspace | ✅ |
| albert-base-v2 | Unigram | ✅ |
| xlm-roberta-base | Unigram + NFKC | ✅ |
| Qwen2.5-0.5B | BPE + NFC + Split(Qwen 正则) + ByteLevel | ✅ |
| Qwen3-0.6B | BPE + NFC + Split(Qwen 正则) + ByteLevel | ✅ |
| DeepSeek-V2-Lite | BPE + 多步 Split + Digits + ByteLevel | ✅ |
| Phi-3-mini | BPE + byte_fallback + Prepend | ✅ |
| Mistral-7B-Instruct-v0.3 | BPE + Metaspace | ✅ |
| Falcon-7B | BPE | ✅ |
| StarCoder2-3B | BPE | ✅ |
| GPT-NeoX-20B | BPE | ✅ |
| CLIP ViT-B/32 | BPE + CLIP Split + ByteLevel | ✅ |
| tiny-random-DeBERTaV2 | Unigram + Metaspace + Precompiled whitespace | ✅ |
| Llama-3.2-1B-Instruct | BPE + Llama-3/Qwen Split + ByteLevel | ✅ |
| Phi-4-mini-instruct | BPE + o200k Split + ByteLevel | ✅ |
| DeepSeek-R1-Distill-Qwen | BPE + Qwen Split | ✅ |
| DeepSeek-V3.2 | BPE + Qwen/Llama3 Split | ✅ |
| GPT-OSS | BPE + o200k Split | ✅ |
| GLM-4.5-Air | BPE + digit triplet / modern Split | ✅ |
| Granite-4 | BPE / modern LLM tokenizer | ✅ |
| Qwen3-Coder | BPE + Qwen Split + code workloads | ✅ |
| Qwen3-VL | BPE + Qwen Split + multimodal tokenizer | ✅ |
| BAAI/bge-m3 | embedding tokenizer | ✅ |
| multilingual-e5-large | multilingual embedding tokenizer | ✅ |

## 组件实现矩阵

### Models
| 组件 | 状态 | 备注 |
|---|---|---|
| BPE / 字节级 BPE | ✅ | 优先队列(pairing heap)合并 + 惰性失效 + word cache；decode 反查使用 dense id array 并在加载时直接填充；native mixed 抽样 gpt2/llama encode 快于 HF |
| byte_fallback / fuse_unk / ignore_merges | ✅ | |
| WordPiece | ✅ | 贪心最长前缀 |
| Unigram | ✅ | Viterbi DP + word cache；`byte_fallback` / `fuse_unk` supported；native mixed 抽样 t5/bge/e5 encode 快于 HF |
| WordLevel | ✅ | |
| dropout / word cache | ⏸ | 进一步优化（merge 已用优先队列堆）|

### Normalizers
| 组件 | 状态 |
|---|---|
| Lowercase / Strip / Replace / Prepend / Sequence | ✅ |
| BertNormalizer（clean_text/handle_chinese_chars/strip_accents/lowercase）| ✅ |
| StripAccents（NFD+Mn 最小表，1006 条，lazy 加载）| ✅ |
| NFC/NFD/NFKC/NFKD | ✅ | 生成表 + UAX #15 分解/排序/重组 |
| Precompiled（SentencePiece charsmap）| 🚧 | 已覆盖主流 SPM NFKC charsmap + Unicode 空白映射；完整二进制 trie 解码 TODO |
| Nmt | ✅ | 控制/格式字符清理 + Unicode 空白归一 |
| ByteLevel-normalizer | ✅ | UTF-8 bytes → GPT-2 byte alphabet |

### Pre-tokenizers
| 组件 | 状态 |
|---|---|
| ByteLevel（手写 GPT-2 扫描）| ✅ |
| Whitespace / WhitespaceSplit / BertPreTokenizer / Punctuation / Metaspace / Sequence | ✅ |
| Punctuation SplitBehavior | ✅ | Removed / Isolated / MergedWithPrevious / MergedWithNext / Contiguous |
| Split（GPT-2 / Qwen-Llama3 / o200k / CLIP / CJK / digit-triplet 家族正则）| ✅ 现代 LLM/CLIP 主线 |
| Digits / Delimiter / FixedLength / UnicodeScripts | ✅ |
| Split（任意正则）| 🚧 已覆盖主流 GPT/Qwen/o200k/CLIP/CJK/digit regex + 简单 literal / `\\s+` / `\\S+` / `\\s+$` / `[\\r\\n]`；复杂未知 pattern 加载期显式 Unsupported |

### Decoders
| 组件 | 状态 |
|---|---|
| ByteLevel / WordPiece / BPEDecoder / Metaspace / Fuse / Replace / Strip / Sequence | ✅ |
| ByteFallback | ✅（R2）|
| CTC | ✅ |

### Post-processors
| 组件 | 状态 |
|---|---|
| TemplateProcessing（预解析 pieces）/ Bert / Roberta / ByteLevel / Sequence | ✅ |
| RobertaProcessing pair type_ids | ✅ | 与 HF 一致，pair 两段均为 type_id 0 |
| TemplateProcessing 字符串模板 DSL（$A/$B/$0:1）| ✅ |

### Tokenizer 核心
| 能力 | 状态 |
|---|---|
| from_str / from_file（x/fs 全后端）| ✅ |
| encode / encode_pair / decode | ✅ |
| AddedVocabulary（single_word/lstrip/rstrip/normalized）| ✅ |
| token_to_id / id_to_token / get_vocab / get_vocab_size | ✅ | `get_vocab(with_added_tokens=true)` 默认包含 added tokens |
| truncation / padding / encode_batch | ✅ | with_truncation/with_padding builder；BatchLongest/Fixed；batch 串行；encode_pair 已接入 finalize |
| decode_batch | ✅ | 串行实现，保证 wasm/js/native 行为一致 |
| tokenizer.json root truncation/padding 自动加载 | ✅ | 已解析 root-level `truncation` / `padding`，覆盖 Fixed/BatchLongest 与方向/倍数/pad 字段 |
| offsets | ✅ | 默认保留 char offsets；新增 `encode_with_byte_offsets` / `encode_pair_with_byte_offsets` 对齐 HF byte offsets；ByteLevel post-processor `trim_offsets` 已按 HF 空白裁剪语义对齐 |
| sequence_ids | ✅ | `Encoding::sequence_ids()`；special/padding 为 None，pair 序列为 Some(0)/Some(1) |
| token-char 映射 | ✅ | `token_to_sequence` / `token_to_chars` / `char_to_token`，半开区间语义对齐 HF |

## R9：HF 迁移缺口排期

目标：把「能跑主流 tokenizer.json 推理」推进到「大多数 HF tokenizers 推理用户低成本迁移」。训练器与 Hub 能力体量较大，单独排期；每项必须配套测试和 benchmark（涉及性能/API 的项）。

| 优先级 | 项目 | 状态 | 验收标准 |
|---|---|---|---|
| P0 | `get_vocab(with_added_tokens=true)` | ✅ | 导出模型词表 + added_tokens；新增单测覆盖 with/without added tokens |
| P0 | `decode_batch` | ✅ | API 行为与 `decode` 一致；新增单测与 batch decode bench；对重复 id 序列做单批缓存 |
| P0 | root-level `truncation` / `padding` 自动加载 | ✅ | `Tokenizer::from_str` 直接应用 tokenizer.json 配置；新增单测覆盖 Fixed padding + truncation |
| P0 | CI / pre-commit 编译测试门禁 | ✅ | 本地 pre-commit 运行 `moon check` + wasm/wasm-gc/js/native 全后端测试；GitHub Actions 覆盖格式/多 target 测试、Python 脚本编译、parity smoke 与 quick HF benchmark smoke |
| P1 | byte offsets 模式 | ✅ | 可选择输出 HF Rust 风格 byte offsets；新增中英/emoji offset 对拍与 bench |
| P1 | `sequence_ids` | ✅ | Encoding 增加字段和访问 API；覆盖 pair/special tokens |
| P1 | token-char 映射 | ✅ | 已补 `token_to_sequence` / `token_to_chars` / `char_to_token`；覆盖 pair/special/byte offsets，并新增 lookup bench |
| P1 | `word_ids` / word-char 映射 | ✅ | 已补 `word_ids`、`token_to_word`、`word_to_tokens`、`word_to_chars`、`char_to_word`；覆盖 pair/special/byte offsets，并纳入 lookup bench |
| P1 | Truncation strategy 完整化 | ✅ | 支持 LongestFirst/OnlyFirst/OnlySecond；pair encode 按 HF 顺序：预留 special slots 后先截断 raw pair，再 post-process/pad |
| P1 | ByteLevel post-processor `trim_offsets` 细节 | ✅ | 空白修剪与 HF offsets 对齐；已补 ByteLevel / RoBERTa offset 用例与 micro bench |
| P2 | Precompiled SentencePiece charsmap 完整解码 | 🚧 | 已支持主流 SPM NFKC charsmap行为并补兼容字符/空白用例；完整二进制 trie 解码仍待做 |
| P2 | 通用 Split/Replace 正则覆盖 | 🚧 | Normalizer/Decoder Replace 已支持 `^\\s+` / `\\s+` / `\\s+$` / `[\\r\\n]+` / `[^\\S\\r\\n]+` / ` {2,}` / anchored digit/word/letter/punctuation/symbol runs / `\\d+` / `\\D+` / `\\d{1,n}` 常见 bounded digit / `\\w+` / `\\W+` / `\\p{L}+` / `\\P{L}+` / `\\p{P}+` / `\\P{P}+` / `\\p{S}+` / `\\P{S}+` / `[\\p{P}\\p{S}]+` / `[^\\s\\p{L}\\p{N}]+` 与常见 ASCII/Unicode word/letter/number/punctuation/symbol class；Split 已补 literal / `^\\s+` / `\\s+` / `\\S+` / `\\s+$` / `[\\r\\n]` / anchored digit/word/letter/punctuation/symbol runs / `\\d{1,3}` / `\\p{N}{1,3}` / `\\w+` / `\\W+` / `\\p{L}+` / `\\P{L}+` / `\\p{P}+` / `\\P{P}+` / `\\p{S}+` / `\\P{S}+` / `[\\p{P}\\p{S}]+` / `[^\\s\\p{L}\\p{N}]+` 的行为与 offset 测试；复杂未知 pattern 加载期显式 Unsupported |
| P2 | save / to_json / from_file 对称性 | ✅ | `to_json` 保留原始 tokenizer.json；`Tokenizer::from_file` / `save` 可往返；补 serialization 测试与 to_json bench |
| P3 | `from_pretrained` / Hub 集成 | 🚧 | 已支持本地 HF 目录（`tokenizer.json`）、tokenizer 文件路径、已有 HuggingFace Hub cache snapshot（`$HUGGINGFACE_HUB_CACHE` / `$HF_HOME/hub` / `$HOME/.cache/huggingface/hub`，含 refs/main → snapshots/<rev> 解析），并对稳定 pretrained 路径做小型多项 source cache；Hub 网络下载仍需外部脚本/应用层集成 |
| P3 | batch 并行 / word cache | 🚧 | BPE/WordPiece/Unigram word cache 已完成；encode_batch 对重复输入做单批缓存并补 bench；并行仍待运行时能力评估 |
| P4 | trainer / training API | ✅ | 已提供确定性 WordLevel trainer（WhitespaceSplit / 自定义 pre-tokenizer / 预切分 token 流 + min_frequency + special tokens + vocab_size + HF 风格频次/词典序排序）；新增确定性 WordPiece / BPE / Unigram trainer MVP（同输入模式 + continuation prefix / end_of_word_suffix / max_input_chars_per_word / byte_fallback + vocab_size），训练结果可 `to_json`/`save` 往返，常见 pre-tokenizer 可序列化，并加入 HF trainer bench；高级训练算法与采样参数后续按需增强 |

### Benchmark 对比要求

性能结论必须基于 `scripts/bench_compare.py` 的同机对比结果，而不是单独的
`moon bench` 输出。脚本会对 encode / explicit byte offsets / decode /
encode_batch / decode_batch / from_str / local from_pretrained / to_json 输出
MoonBit µs/op、HF `tokenizers` µs/op、Moon/HF 比值。`Moon/HF > 1.10x` 的项目
应进入优化排期；`< 0.90x` 才能明确宣称本项目在该用例快于 HF。

默认 benchmark 对比覆盖 `scripts/bench_python.py` 中的完整模型 fixture 矩阵；
`--quick` 仅用于本地冒烟，正式性能结论必须跑 `--corpus all` 或至少全模型
`mixed` 矩阵。最近一次全模型抽样（native / mixed，BPE word cache 后）：BPE/
WordPiece/CLIP 主线大多快于 HF（gpt2 0.43x、llama 0.28x、Qwen2.5 0.58x、
bert 0.53x、clip 0.48x）；decode 多数约 0.5x 或同水平；加载大模型基本同
水平。Unigram word cache 后，t5 encode 0.39x、bge_m3 0.42x、e5_multilingual
0.43x，已由主要性能短板转为快于 HF。Dense vocab reverse map 后，加载
抽样改善明显（bert/Qwen2.5/phi4/qwen3_coder from_str 已达到同档或快于 HF，
llama from_str 仍约 1.14x）。Legacy BPE merges 解析改为 code-unit 扫描、
vocab reverse array 预分配后，大 BPE tokenizer 加载路径减少 StringBuilder 与
Array 增长分配；`from_pretrained` 增加单项 source cache 后，完整 native
`--corpus all` 复测已无 `>1.10x` 慢项：主流 encode 在 short/mixed/code/long
均快于 HF（约 0.25x–0.68x）；decode 同档或快于 HF，decode_batch 增加重复 id
序列单批缓存后 quick native 抽样进一步改善；SentencePiece decoder sequence 增加融合快路径后
llama decode quick native 约 0.17x；from_str
增加单项 parsed-JSON cache 后，quick native 抽样加载路径已明显快于 HF（gpt2
0.45x、bert 0.30x、llama 0.61x、Qwen2.5 0.39x、phi4-mini 0.31x、qwen3-coder
0.37x；local from_pretrained-file 约 0.28x–0.63x）。下一轮性能优化优先级：完整
`--corpus all` 回归门禁/夜间化 > 大词表 JSON 冷加载解析。

## 已知缺口与取舍（TODO）

1. **Precompiled charsmap**：当前覆盖主流 SentencePiece NFKC charsmap 与 Unicode 空白映射；完整二进制 trie 解码仍是 TODO。
2. **正则**：core 正则不提供完整通用 Unicode regex 引擎；GPT/Qwen/o200k 主线已手写扫描器。通用 Split 已补 literal、`^\\s+`、`\\s+`、`\\S+`、`\\s+$`、`[\\r\\n]`、`\\d+`、`\\D+`、`\\d{1,3}`、`\\p{N}{1,3}`、anchored digit/word/letter/punctuation/symbol runs、`\\w+`、`\\W+`、`\\p{L}+`、`\\P{L}+`、`\\p{P}+`、`\\P{P}+`、`\\p{S}+`、`\\P{S}+`、`[\\p{P}\\p{S}]+`、`[^\\s\\p{L}\\p{N}]+`、常见 ASCII/Unicode word/letter/number/punctuation/symbol class；复杂未知 pattern 加载期显式 Unsupported，避免静默不对齐。Replace normalizer/decoder 已补 `^\\s+` / `\\s+` / `\\s+$` / `[\\r\\n]+` / `[^\\S\\r\\n]+` / ` {2,}` / anchored digit/word/letter/punctuation/symbol runs / `\\d+` / `\\D+` / 常见 bounded digit / `\\w+` / `\\W+` / `\\p{L}+` / `\\P{L}+` / `\\p{P}+` / `\\P{P}+` / `\\p{S}+` / `\\P{S}+` / `[\\p{P}\\p{S}]+` / `[^\\s\\p{L}\\p{N}]+`；更复杂 Replace pattern 仍按字面量处理。
3. **训练 / Hub 集成**：当前定位 inference-first；`to_json`/`save` 已支持原始 JSON 往返，`from_pretrained` 已支持本地目录/文件、已有 HF Hub cache snapshot 与稳定路径小型多项 source cache；WordLevel trainer 产物已支持序列化保存，并支持自定义 pre-tokenizer / 预切分 token 流 / vocab_size / HF 风格频次与词典序排序；WordPiece / BPE / Unigram trainer MVP 已支持相同输入模式、continuation prefix / end-of-word suffix、`max_input_chars_per_word`、`byte_fallback` 与 `vocab_size`，常见 pre-tokenizer 可序列化。Hub 网络下载 API 暂未实现，高级训练算法与采样参数后续按需增强。
4. **性能**：BPE merge 已用优先队列(pairing heap)+惰性失效，llama 提速约 7x、与 Rust 同量级；进一步可加 word→tokens 缓存与多 MB 词表加载优化。
5. **batch 并行**：MoonBit 单线程，encode_batch 串行；已对重复输入做批内缓存，BPE/WordPiece/Unigram 均带 word cache（场景定位 wasm/js 边缘端）。

## 测试与验证

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon test                       # 默认 wasm-gc
moon test --target wasm         # 也支持 wasm-gc / js / native
```

- 内联小样本测试在所有后端运行。
- 大模型对拍测试需先下载 `tests/data/*.full.json`（见 README 的 `scripts/fetch_models.py`），缺失时测试自动跳过。
- 期望输出由 `scripts/gen_parity.py`（Python `tokenizers`）生成。

## 代码结构

```
src/
  types/         Encoding/Token/Split/TokenizerError + JSON 辅助
  normalizer/    enum Normalizer + normalize
  pretokenizer/  enum PreTokenizer + pre_tokenize；byte_level/gpt2_regex
  model/         enum Model{BPE,WordPiece,Unigram,WordLevel} + 各 tokenize
  processor/     enum PostProcessor + process
  decoder/       enum Decoder + decode_chain
  tokenizer/     Tokenizer 组装；added_vocabulary；encode/decode/from_file；bench_test
scripts/         fetch_models.py / gen_parity.py / bench_python.py
tests/data/      *.full.json（gitignore）+ *_expected.json（gitignore）
```

## 接替开发建议

- 新增组件变体：在对应包的 enum 加变体 → from_json 加 "type" 分派 → 实现行为 → 加对拍测试。
- 新增模型对拍：在 `scripts/fetch_models.py` 加模型 URL，下载 tokenizer.json 到 `tests/data/<name>.full.json`，用 `scripts/gen_parity.py` 生成期望，并把模型名加入 `src/tokenizer/parity_test.mbt`。
- 每完成一个可验证单元就 commit（conventional commits，scope 用包名）。
