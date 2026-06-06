# 开发进度与任务跟踪（tokenizer-moonbit）

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
| R7 | benchmark 套件 + 与 HF 跑分 | ⬜ |
| R8 | 文档 + 迁移指南 | 🚧（本文件 + README + 迁移指南进行中）|

## 已对齐验证的真实模型（与 Python `tokenizers` 逐 token id 一致）

通过表驱动的 `parity_test.mbt`（`scripts/fetch_models.py` + `scripts/gen_parity.py` 生成期望），覆盖 9 个真实模型：

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

## 组件实现矩阵

### Models
| 组件 | 状态 | 备注 |
|---|---|---|
| BPE / 字节级 BPE | ✅ | rank 线性合并（O(n²)，性能优化见 R7 TODO）|
| byte_fallback / fuse_unk / ignore_merges | ✅ | |
| WordPiece | ✅ | 贪心最长前缀 |
| Unigram | ✅ | Viterbi DP；byte_fallback/fuse_unk 字段已留，编码暂未接入 ⏸ |
| WordLevel | ✅ | |
| dropout / cache（thread-local + 四叉堆） | ⏸ | 性能优化，R7 |

### Normalizers
| 组件 | 状态 |
|---|---|
| Lowercase / Strip / Replace / Prepend / Sequence | ✅ |
| BertNormalizer（clean_text/handle_chinese_chars/strip_accents/lowercase）| ✅ |
| StripAccents（NFD+Mn 最小表，1006 条，lazy 加载）| ✅ |
| NFC/NFD/NFKC/NFKD | ⏸ identity（NFKC 视需要补；当前 9 模型对拍不依赖）|
| Precompiled（SentencePiece charsmap）| ⏸ identity |
| Nmt / ByteLevel-normalizer | ⬜ |

### Pre-tokenizers
| 组件 | 状态 |
|---|---|
| ByteLevel（手写 GPT-2 扫描）| ✅ |
| Whitespace / WhitespaceSplit / BertPreTokenizer / Punctuation / Metaspace / Sequence | ✅ |
| Split（GPT-2 / Qwen-Llama3 家族正则）| ✅ 现代 LLM 主线 |
| Split（任意正则）/ Digits / Delimiter / FixedLength / UnicodeScripts | 🚧 未识别 pattern 退化为单段 |

### Decoders
| 组件 | 状态 |
|---|---|
| ByteLevel / WordPiece / BPEDecoder / Metaspace / Fuse / Replace / Strip / Sequence | ✅ |
| ByteFallback | ✅（R2）|
| CTC | ⬜ R6 |

### Post-processors
| 组件 | 状态 |
|---|---|
| TemplateProcessing（预解析 pieces）/ Bert / Roberta / ByteLevel / Sequence | ✅ |
| TemplateProcessing 字符串模板 DSL（$A/$B/$0:1）| ⬜ R6 |

### Tokenizer 核心
| 能力 | 状态 |
|---|---|
| from_str / from_file（x/fs 全后端）| ✅ |
| encode / encode_pair / decode | ✅ |
| AddedVocabulary（single_word/lstrip/rstrip/normalized）| ✅ |
| token_to_id / id_to_token / get_vocab_size | ✅ |
| truncation / padding / encode_batch | ✅ | with_truncation/with_padding builder；BatchLongest/Fixed；batch 串行 |
| offsets（当前 char 偏移；HF 默认 byte）| 🚧 R4 评估 |

## 已知缺口与取舍（TODO）

1. **Unicode 归一化**：NFC/NFKC 无数据表，当前 identity。R5 做 NFD+Mn 最小集支持 strip_accents（覆盖 bert-cased/xlm-roberta）。NFKC 视对拍失败再补。
2. **正则**：core 正则不支持 `\p{L}`；GPT-2 已手写扫描器。通用 Split 复杂 pattern 暂抛 `UnsupportedComponent`。
3. **性能**：BPE 用 rank 线性扫描、无 cache；R7 暴露瓶颈后引入优先队列 + word cache。
4. **batch 并行**：MoonBit 单线程，encode_batch 串行（场景定位 wasm/js 边缘端）。
5. **Unigram byte_fallback**：字段已留，编码路径未接入。

## 测试与验证

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon test                       # 默认 wasm-gc
moon test --target wasm         # 也支持 wasm-gc / js / native
```

- 内联小样本测试在所有后端运行。
- 大模型对拍测试（gpt2/bert/t5/llama）需先下载 `tests/data/*.full.json`（见 README），缺失时测试自动跳过。
- 期望输出由 `scripts/gen_expected*.py`（Python `tokenizers`）生成。

## 代码结构

```
src/
  types/         Encoding/Token/Split/TokenizerError + JSON 辅助
  normalizer/    enum Normalizer + normalize
  pretokenizer/  enum PreTokenizer + pre_tokenize；byte_level/gpt2_regex
  model/         enum Model{BPE,WordPiece,Unigram,WordLevel} + 各 tokenize
  processor/     enum PostProcessor + process
  decoder/       enum Decoder + decode_chain
  tokenizer/     Tokenizer 组装；added_vocabulary；encode/decode/from_file
scripts/         gen_expected*.py（对拍期望生成）
tests/data/      *.full.json（gitignore）+ *_expected.json（gitignore）
```

## 接替开发建议

- 新增组件变体：在对应包的 enum 加变体 → from_json 加 "type" 分派 → 实现行为 → 加对拍测试。
- 新增模型对拍：下载 tokenizer.json 到 `tests/data/<name>.full.json`，用 `scripts/gen_expected*.py` 生成期望，仿照 `llama_test.mbt` 写测试。
- 每完成一个可验证单元就 commit（conventional commits，scope 用包名）。
