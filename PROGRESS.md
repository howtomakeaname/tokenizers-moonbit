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
| R6 | pre_tokenizer/decoder/template DSL 补全 | ✅（ByteFallback R2 完成；template DSL 字符串构造已补 `template_from_strings`）|
| R7 | benchmark 套件 + 与 HF 跑分 | ✅ |
| R8 | 文档 + 迁移指南 | ✅ |
| R9 | HF 无缝迁移缺口收敛（API / offsets / charsmap / save / pretrained） | ✅（Hub 下载已由可选 native/js `hub` 包承接）|
| R10 | 架构治理与模块化（公共库 / 测试与基准分层 / HF 风格组件边界） | ✅（A0–A5 全部完成）|
| R11 | HF tokenizers 全量兼容缺口收敛（低频 API / 高级训练 / 正则与并行） | 🚧 排期中（`encode_fast`、迁移序列化 API、缓存控制 API、BPE dropout、模型文件级保存、HF config alias、Tokenizer set_* property alias、EncodeInput、Token/Regex/Encoding/Tokenizer state API、Tokenizer train pipeline MVP、高级 trainer knobs 与 Trainer state、Hub tokenizer.json 下载/metadata/离线校验/诊断 hint/ref/resume 元数据/条件请求计划/响应决策/HEAD 预检/流式落盘、固定 aux 读取与通用 sidecar 请求规划、batch parallel 兼容入口、NormalizedString/PreTokenizedString 低层 API 与 binding alias、async 兼容入口、regex literal 策略、错误分类 helper、Python binding alias 第三十七批、Hub env/local-only 闭环已完成） |

## R11：对齐 HuggingFace tokenizers 的剩余缺口排期（2026-06-12 复评）

目标：在当前 39 个真实 tokenizer.json 逐 id parity 的基础上，继续从「主流推理无缝迁移」推进到「HF tokenizers 公共 API 与低频组件行为尽量完整兼容」。排序原则：先补会影响真实模型加载/推理正确性的 P0/P1，再补迁移便利 API，最后补训练/扩展/并行等高级能力。每项必须包含：HF 行为对拍、MoonBit 全 target 测试、`moon check` 无 warning；涉及热路径的改动必须跑 `scripts/bench_compare.py --quick --target native`，不得让相关项退化到 `Moon/HF > 1.10x`。

本轮复评结论：主流推理链路（load tokenizer.json / added tokens / normalizer / pre-tokenizer / model / post-processor / decoder / truncation / padding / offsets / pair / batch / pretokenized / save / local+online hub）已经基本可迁移；剩余缺口主要集中在训练生态完整 EM/大语料对拍、Hub 文件族/错误映射、以及 Python 绑定长尾别名。Regex 当前采用“HF 常见 deterministic subset + 复杂 pattern 显式 unsupported”的完成策略，不把 full backtracking/通用 Unicode regex 引擎作为跨 target 核心目标。

### 2026-07-11 小闭环：API 文档补齐（缓存控制 / 属性 getter / 词表别名）

- 补齐缓存控制 API 文档：`clear_cache` / `resize_cache` / `cache_size`。
- 补齐属性风格 getter 文档：`normalizer()` / `pre_tokenizer()` / `model()` / `post_processor()` / `decoder()` / `truncation()` / `padding()` / `encode_special_tokens()` / `vocab_size()` / `vocab()` / `added_tokens_decoder()` / `added_tokens()` / `all_special_tokens()` / `all_special_ids()` / `get_trainer()` / `default_trainer()` / `to_json()`。
- 补齐词表别名文档：`convert_token_to_id` / `convert_id_to_token` / `convert_tokens_to_ids` / `convert_ids_to_tokens`。
- 中英文文档同步更新。

### 2026-07-11 小闭环：Trainer setter 别名（Python binding 兼容）

- HF Python `Trainer` 类暴露属性 setter（如 `trainer.vocab_size = 1000`），允许修改训练器属性。
- MoonBit 已补齐 `Trainer::set_*` setter 方法，返回新 Trainer，保持不可变语义。
- 已补 setter（19 个）：
  - `set_unk_token` / `set_min_frequency` / `set_special_tokens` / `set_special_added_tokens` / `set_vocab_size` / `set_show_progress`（所有变体）
  - `set_continuing_subword_prefix` / `set_end_of_word_suffix` / `set_max_input_chars_per_word` / `set_max_token_length` / `set_initial_alphabet` / `set_limit_alphabet`（WordPiece/BPE）
  - `set_fuse_unk`（BPE/Unigram）
  - `set_byte_fallback` / `set_shrinking_factor` / `set_max_piece_length` / `set_n_sub_iterations` / `set_seed_size`（Unigram）
  - `set_progress_format`（BPE）
- 每个 setter 都有 `*_alias` 别名。
- setter 仅修改对应训练器变体的字段，其他变体返回原 Trainer。
- 新增 `trainer_test.mbt` 覆盖所有 setter 的基本功能测试。
- 全后端测试通过：native(384)/js(384)/wasm(361)/wasm-gc(361)。

### 2026-07-11 小闭环：Decoder setter 别名（Python binding 兼容）

- HF Python `Decoder` 类暴露属性 setter（如 `decoder.add_prefix_space = True`），允许修改解码器属性。
- MoonBit 已补齐 `Decoder::set_*` setter 方法，返回新 Decoder，保持不可变语义。
- 已补 setter：
  - `set_add_prefix_space` / `set_trim_offsets` / `set_use_regex`（ByteLevel）
  - `set_prefix` / `set_cleanup`（WordPiece）
  - `set_replacement` / `set_prepend_scheme` / `set_split_enabled`（Metaspace）
  - `set_suffix`（BPEDecoder）
  - `set_content`（Replace/ReplaceString）
  - `set_start` / `set_stop` / `set_left` / `set_right`（Strip）
  - `set_pad_token` / `set_word_delimiter_token` / `set_cleanup`（CTC）
- 每个 setter 都有 `*_alias` 别名。
- setter 仅修改对应解码器变体的字段，其他变体返回原 Decoder。
- 新增 `decoder_wbtest.mbt` 覆盖所有 setter 的基本功能测试。
- 全后端测试通过：native(344)/js(344)/wasm(321)/wasm-gc(321)。

### 2026-07-11 小闭环：PostProcessor setter 别名（Python binding 兼容）

- HF Python `PostProcessor` 类暴露属性 setter（如 `processor.trim_offsets = True`），允许修改后处理器属性。
- MoonBit 已补齐 `PostProcessor::set_*` setter 方法，返回新 PostProcessor，保持不可变语义。
- 已补 setter：
  - `set_trim_offsets` / `set_add_prefix_space` / `set_use_regex`（ByteLevel）
  - `set_trim_offsets` / `set_add_prefix_space`（RobertaProcessing）
  - `set_sep` / `set_cls`（BertProcessing/RobertaProcessing）
- 每个 setter 都有 `*_alias` 别名。
- setter 仅修改对应后处理器变体的字段，其他变体返回原 PostProcessor。
- 新增 `post_processor_wbtest.mbt` 覆盖所有 setter 的基本功能测试。
- 全后端测试通过：native(344)/js(344)/wasm(321)/wasm-gc(321)。

### 2026-07-11 小闭环：Unigram N-best 采样（SentencePiece 兼容）

- HF SentencePiece 的 Unigram 模型支持 `nbest_size` 参数用于 N-best 路径采样。
- MoonBit 已补齐 N-best 采样实现：当 `alpha > 0` 且 `nbest_size > 0` 时，使用 beam search
  枚举最多 `nbest_size` 条完整分词路径，计算得分后使用 `alpha` 作为温度的 softmax 采样。
- 当 `nbest_size` 未设置（或 `<= 0`）时，回退到前向-后向算法对完整分布采样。
- 新增 `sample_nbest` 和 `sample_forward_backward` 函数分离两种采样策略。
- 新增测试覆盖 N-best 采样模式。
- 全后端测试通过：native(345)/js(345)/wasm(322)/wasm-gc(322)。

### 2026-07-11 小闭环：PreTokenizer setter 别名（Python binding 兼容）

- HF Python `PreTokenizer` 类暴露属性 setter（如 `pre_tokenizer.individual_digits = True`），允许修改预分词器属性。
- MoonBit 已补齐 `PreTokenizer::set_*` setter 方法，返回新 PreTokenizer，保持不可变语义。
- 已补 setter：
  - `set_add_prefix_space` / `set_use_regex` / `set_trim_offsets`（ByteLevel）
  - `set_replacement` / `set_prepend_scheme` / `set_split_enabled`（Metaspace）
  - `set_delimiter`（Delimiter）
  - `set_individual_digits`（Digits）
  - `set_length`（FixedLength）
  - `set_behavior`（Split/Punctuation）
  - `set_invert`（Split）
- 每个 setter 都有 `*_alias` 别名。
- setter 仅修改对应预分词器变体的字段，其他变体返回原 PreTokenizer。
- 新增 `pretok_setter_wbtest.mbt` 覆盖所有 setter 的基本功能测试。
- 全后端测试通过：native(300)/js(300)/wasm(277)/wasm-gc(277)。

### 2026-07-11 小闭环：Normalizer setter 别名（Python binding 兼容）

- HF Python `Normalizer` 类暴露属性 setter（如 `normalizer.left = True`），允许修改归一化器属性。
- MoonBit 已补齐 `Normalizer::set_*` setter 方法，返回新 Normalizer，保持不可变语义。
- 已补 setter：
  - `set_left` / `set_right`（Strip）
  - `set_clean_text` / `set_handle_chinese_chars` / `set_strip_accents` / `set_lowercase`（BertNormalizer）
  - `set_prepend`（Prepend）
  - `set_content`（Replace/ReplaceString）
- 每个 setter 都有 `*_alias` 别名。
- setter 仅修改对应归一化器变体的字段，其他变体返回原 Normalizer。
- 新增 `normalizer_setter_wbtest.mbt` 覆盖所有 setter 的基本功能测试。
- 全后端测试通过：native(290)/js(290)/wasm(267)/wasm-gc(267)。

### 2026-07-11 小闭环：Model setter 别名（Python binding 兼容）

- HF Python `Model` 类暴露属性 setter（如 `model.dropout = 0.5`），允许修改模型属性。
- MoonBit 已补齐 `Model::set_*` setter 方法，返回新 Model 而非原地修改，保持不可变语义。
- 已补 setter：
  - `set_unk_token` / `set_dropout` / `set_continuing_subword_prefix` / `set_end_of_word_suffix`
  - `set_byte_fallback` / `set_fuse_unk` / `set_ignore_merges`
  - `set_max_input_chars_per_word`（WordPiece）
  - `set_alpha` / `set_nbest_size`（Unigram）
- 每个 setter 都有 `*_alias` 别名，保持与 Python binding 迁移模式一致。
- setter 仅修改对应模型变体的字段，其他变体返回原 Model（如 `set_dropout` 对 Unigram 无操作）。
- 新增 `model_setter_wbtest.mbt` 覆盖所有 setter 的基本功能测试。
- 全后端测试通过：native(281)/js(281)/wasm(258)/wasm-gc(258)。

### 2026-07-10 小闭环：Unigram lattice 采样实现

- HF Unigram 支持 `alpha`（采样温度）和 `nbest_size`（N-best 路径数）推理参数，用于从 lattice 中采样而非确定性 Viterbi。
- MoonBit 已实现 forward-backward 采样算法：当 `alpha > 0` 时，构建 lattice 并计算前向概率，然后从分布中采样 token 序列。
- 实现要点：
  - `log_sum_exp` - 数值稳定的 log-sum-exp 计算
  - `tokenize_with_sampling` - 前向-后向采样主函数
  - `sample_from_log_probs` - 从 log 概率分布采样
- 当前使用确定性种子（基于 log 概率和）保证可复现性，后续可替换为真随机。
- 全后端测试通过：native(269)。

### 2026-07-10 小闭环：`Tokenizer::get_trainer` 默认训练器

- HF `Model.get_trainer()` 返回模型对应的默认 Trainer。MoonBit 已补齐 `Tokenizer::get_trainer()` / `default_trainer()`，根据模型类型返回对应的默认 Trainer（BPE → BpeTrainer、WordPiece → WordPieceTrainer、Unigram → UnigramTrainer、WordLevel → WordLevelTrainer）。
- 全后端测试通过：native(268)。

### 2026-07-10 小闭环：BPE `get_word_count` + Decoder Strip `left`/`right` 别名

- **BPE `get_word_count`**：HF `BpeTrainer.get_word_count()` 返回训练后唯一词数。MoonBit 已补齐 `BPEModel.word_count : Int?` 字段，训练时记录唯一词数，JSON/文件加载时为 `None`；新增 `Model::get_word_count()` getter，BPE 返回 `Some(count)`，其它模型返回 `None`。
- **Decoder Strip `left`/`right` 别名**：HF `decoders.Strip` 使用 `left`/`right` 参数，MoonBit 原用 `start`/`stop`。已补齐 `Decoder::left()` / `get_left()` / `right()` / `get_right()` getter alias；`from_json` 同时接受 `left`/`right` 和 `start`/`stop` 键名，HF 配置可直接反序列化。
- 全后端测试通过：native(267)/js(267)/wasm(244)/wasm-gc(244)。

### 2026-07-10 小闭环：Unigram `alpha` / `nbest_size` 推理参数

- 已对拍 HF 0.22.2：Unigram 模型支持 `alpha`（采样温度）和 `nbest_size`（N-best 路径数）推理参数。当 `alpha` 为 `None` 或 `0.0` 时使用确定性 Viterbi 算法（默认行为）；当 `alpha > 0` 时启用采样模式；当 `nbest_size > 0` 且 `alpha > 0` 时从 N-best 路径中采样。
- MoonBit 本轮补齐：`UnigramModel` 新增 `alpha : Double?` 和 `nbest_size : Int?` 字段；`parse_unigram` 从 tokenizer.json 解析这两个字段；`unigram_to_json` 序列化时保留非 `None` 值；新增 `Model::alpha()` / `get_alpha()` / `nbest_size()` / `get_nbest_size()` getter alias；`get_optional_number_strict` helper 已补齐。
- JSON round-trip 已验证：`alpha=0.5` 和 `nbest_size=10` 可正确序列化和反序列化；`alpha=None` 和 `nbest_size=None` 不写入 JSON。
- N-best 采样已实现：当 `alpha > 0` 且 `nbest_size > 0` 时使用 beam search 枚举 N-best 路径采样；当 `nbest_size` 未设置时回退到前向-后向采样。当前使用确定性种子保证可复现性，后续可替换为真随机。
- 全后端测试通过：native/js/wasm/wasm-gc 均 266 测试通过。

### 2026-07-08 小闭环：`add_special_tokens=false` post-process

- 已对拍 HF 0.22.2：`Tokenizer.post_process(..., add_special_tokens=False)` 与 `PostProcessor.process(..., add_special_tokens=False)` 会跳过 BERT/Template/RoBERTa special token 注入，但 ByteLevel/RoBERTa 的 offset trimming 等非 special-token 后处理仍会执行。
- MoonBit 本轮只在 tokenizer-level 显式 `Tokenizer::post_process(..., add_special_tokens=false)` 补齐上述 HF 语义：复用现有 post-processor 产物后移除无 sequence 的 injected special tokens，因此 Template type_id、ByteLevel/RoBERTa offset trimming 与 Sequence 组合的非 special-token 效果仍保留；未改 `processor` 包 internals，也未触碰 normalizer/pretokenizer/processor sequence alias。
- Python binding 可把带 `add_special_tokens` 参数的 post-process 入口映射到 `Tokenizer::post_process`，低层 `PostProcessor::process` 也已补同名 flag 并复用同一“先执行非 special 后处理，再移除注入 special token”的语义。

| 优先级 | 缺口 | 当前状态 | 验收标准 | 建议排期 |
|---|---|---|---|---|
| P0 | `NormalizedString` / `PreTokenizedString` 低层 API 暴露 | ✅ 已完成 | 已提供 HF 同名概念的最小公共类型：原文/归一化文本、`len`/`__len__`/`is_empty`、`get`/`normalized`/`to_string`、`get_original`/`original`、state/tuple 往返、normalize、replace、prepend/append、clear、lowercase/uppercase、lstrip/rstrip/strip、nfc/nfd/nfkc/nfkd、slice、map/filter、literal/Regex split、`get_splits`/`splits`、pre-tokenizer 二次 split 与 `to_encoding`/`into_encoding`；覆盖自定义 normalizer/pre-tokenizer 与 Python binding 低层迁移场景，完整可变 offset hook 后续按需扩展 | 1 周 |
| P0 | Regex 兼容策略 | ✅ 已完成 | 现有 deterministic regex family 保持 fast path；已补 regex=true 的 literal/escaped-literal 安全策略，并进一步覆盖 `^foo$`、`\\bfoo\\b`、`foo|bar`、`(foo)` / `(?:foo)`、`(foo|bar)` / `(?:foo|bar)`、`foo|a\\.b`、`^(?:foo|bar)` / `(?:foo|bar)$` 以及 `\\b(?:foo|bar)\\b` / `^\\b(?:foo|bar)\\b$` 这类每个分支都是普通或 escaped literal 的简单 literal/alternation，并把 HF SentencePiece 常用 ` {2,}` 纳入共享 scanner；`Regex::is_supported/find_matches/replace_all` 对复杂 pattern 显式返回 `None`，未知复杂 Split regex 在 tokenizer.json 加载期抛 `UnsupportedComponent`，避免静默错配；full backtracking/通用 Unicode regex 引擎不属于当前跨 target 核心目标 | 1–2 周 |
| P0 | BPE `dropout` encode 语义 | ✅ 已完成 | 已解析/序列化 `model.dropout`；`None/0` 继续走确定性 fast path 与 word cache，`>0` 禁用 word cache 并按 dropout 概率跳过可用 merge，`1.0` 覆盖全跳过边界；新增单测覆盖序列化、缓存禁用与确定性路径不退化 | 0.5–1 周 |
| P1 | 训练 API 完整化：`Tokenizer.train` / `train_from_iterator` / 文件训练 | ✅ pipeline MVP 已完成 | 已新增 `Trainer::{wordlevel,wordpiece,bpe,unigram}` 配置与 `Tokenizer::train` / `train_from_iterator` / `train_from_files`；训练前应用 added-vocab extraction、normalizer、pre-tokenizer，训练完成后写回 model 并将已有 special added tokens 重新映射到新 model ids；已补 iterator 与文件训练单测。后续高级 trainer knobs 继续归入下一项 | 1–2 周 |
| P1 | 高级 trainer 参数补齐 | 🚧 第十四批完成 | 已补 `show_progress` 兼容参数（当前保持 no-op 以跨 target 稳定）、`special_added_tokens` AddedToken 元数据保真、BPE continuing/end suffix 训练入口覆盖、WordPiece model/trainer `end_of_word_suffix`（加载、encode、训练、序列化往返）与 `max_token_length`（限制训练阶段产生过长整词 token）、Unigram `unk_piece` alias、`max_piece_length` 子词候选限制；`shrinking_factor` / `n_sub_iterations` 已从 tokenizer trainer 透传到 model trainer，并新增 deterministic Unigram candidate ranking + shrinking prune 近似：先按 EM-like score/frequency/长度/字典序合并排序 whole-word 与 subpiece 候选，再按 shrinking 轮次裁剪后应用 vocab cap，避免高频整词被低分子串挤出；第四批补充 Trainer 配置 getter/property-style alias（通用字段与 WordPiece/BPE/Unigram 特有 knobs 均返回副本或 Option），便于 Python binding 暴露 trainer 属性；第五批补充 `TrainerState` 与 `get_state` / `from_state` / `__getstate__` / `__setstate__`、`__str__` / `__repr__`，保留 typed trainer 配置和 `AddedToken` 元数据，未知 trainer kind 显式报 unsupported；第六批补充 Unigram `initial_alphabet` 参数，从 tokenizer trainer 透传到 model trainer，按 HF 语义对多字符条目只取首字符，并在 vocab cap 下作为 required alphabet 先于语料候选加入；第七批修正 BPE `continuing_subword_prefix` merge surface，训练和 encode 阶段合并右侧 subword 时都会先去掉 continuation prefix，避免生成 `a@@b` 这类非 HF token；第八批修正 BPE/WordPiece `initial_alphabet` 与 `limit_alphabet` 交互，initial alphabet 进入同一 alphabet 候选池并优先保留，但总 alphabet 数仍受 limit 约束；第九批对齐 Unigram `unk_token` 插入位置：当 unk 未显式列入 special_tokens 时先插入 unk，当 special_tokens 中已包含 unk 时保留列表顺序；第十批补充 BPE `progress_format` 配置/state 兼容，保存 `"indicatif"` / `"json"` / `"silent"`，未知值按 HF Python setter 语义回落 `"indicatif"`，真实 progress 输出仍保持跨 target no-op；第十一批补充 Unigram `seed_size` 配置/state 与 tokenizer/model 透传，将其作为当前 deterministic Unigram MVP 的 ranked candidate cap，默认 `1000000`，小值可限制 whole/subpiece 候选；第十二批修正 `Tokenizer::train_from_iterator` 在原模型为 BPE 时保留 `dropout` / `byte_fallback` / `ignore_merges` / cache capacity 等训练外选项，同时保留 trainer 显式 prefix/suffix 覆盖；第十三批补充 Trainer 通用 `get_*` getter alias；第十四批补齐 WordPiece/BPE/Unigram model-specific `get_*` getter alias；已补 tokenizer/model trainer 单测。后续继续做大语料与 HF trainer 对拍，收敛完整 EM loss 细节 | 2 周 |
| P1 | 模型文件级保存/加载 API | ✅ 已完成 | 已新增 `Model::save(folder, prefix)` 与 `Tokenizer::save_model(folder, prefix)`；BPE 写 `vocab.json`+`merges.txt`，WordPiece 写 `vocab.txt`，WordLevel 写 `vocab.json`，Unigram 写 score-preserving `unigram.json`；`save_pretrained(..., save_model=true, model_prefix=...)` 可同步辅助 artifacts；并已补 `Model::from_bpe_files` / `from_wordpiece_file` / `from_wordlevel_file` / `from_unigram_file` standalone artifact loader，覆盖保存后重载 | 0.5–1 周 |
| P1 | HF mutating/config API 别名 | ✅ 已完成 | 已在现有 `with_truncation` / `with_padding` 基础上补 `enable_truncation` / `no_truncation` / `enable_padding` / `no_padding`，并补 `enable_encode_special_tokens` / `disable_encode_special_tokens` alias；`set_normalizer` / `set_pre_tokenizer` / `set_model` / `set_post_processor` / `set_decoder` / `set_truncation` / `set_padding` 作为 writable-property 风格 alias 委托现有 `with_*` builder；语义保持 builder/mutating 链式风格；已补迁移 API 单测 | 0.5 周 |
| P1 | `encode_fast` / `encode_batch_fast` 无 offsets 快路径 | ✅ 已完成 | 已新增 single/pair/batch/pretokenized 全 fast API 族；ids/tokens/masks/type_ids/sequence_ids/word_ids 与普通 encode 一致，offsets 统一置零；已加入单测与 benchmark 对比 | 0.5 周 |
| P1 | BPE / Unigram cache 控制 API | ✅ 已完成 | 已暴露 `Tokenizer::clear_cache` / `resize_cache` / `cache_size`，覆盖 BPE / WordPiece / Unigram 内部 word cache；验证 from_str 后缓存隔离、`capacity=0` 禁用缓存、默认性能路径保持不变 | 0.5 周 |
| P1 | `Tokenizer.from_buffer` / `to_str(pretty)` / `save(pretty)` 迁移 API | ✅ 已完成 | 已支持 UTF-8 `Bytes` buffer 加载；`to_str(pretty)` 支持 minified/verbatim 与两空格 pretty 输出；`save(path)` 默认对齐 HF 写两空格 pretty JSON，显式 `pretty=false` 保留旧 compact/verbatim 字节；`save_pretrained(pretty)` 仍支持两种输出；已加载 JSON round-trip 仍保真 | 0.5 周 |
| P2 | `Token` / `Regex` / component trait 扩展点 | ✅ 已完成 | 已提供低层 `Token::new` / `from_tuple` / `as_tuple` / getters / `__str__` / `__repr__`，并为 `Split` 补齐同类显示 alias；新增 `EncodingState` / `Encoding::get_state` / `__getstate__` / `__setstate__`，方便 Python binding/pickle/state 互操作；新增 `Regex::new` / `pattern` / `is_supported` / `find_matches` / `replace_all`，显式暴露 deterministic regex subset 能力边界，未知复杂 pattern 返回 `None`；新增 `TokenizerComponentHooks` 与 `encode_with_hooks` / `encode_with_hooks_fast` / `decode_with_hooks`，允许 Python/FFI 层按调用注入自定义 normalize / pre_tokenize / decode 回调；新增 `Tokenizer::with_component_hooks` / `clear_component_hooks` / `get_component_hooks` / `component_hooks`，让 runtime hook 可作为 tokenizer 级轻量组件参与普通 `encode` / `encode_fast` / `decode` 路径，per-call hooks 会覆盖持久 hook；callback 不写入 tokenizer JSON/state 是有意设计，用来保持 HF JSON/state round-trip 稳定，序列化组件仍应使用 typed normalizer/pre-tokenizer/decoder | 1 周 |
| P2 | async encode/decode batch API | ✅ 兼容入口已完成 | 已提供 `async_encode` / `async_encode_fast` / `async_encode_batch` / `async_encode_batch_fast` / `async_decode` / `async_decode_batch` 兼容入口，语义与同步 API 一致；已补 async encode/fast/batch smoke 测试，确认 fast offsets 置零且 ids/metadata 与同步路径一致；实现保持同步以覆盖 native/js/wasm/wasm-gc，后续若 MoonBit async runtime 稳定再替换内部调度 | 0.5–1 周 |
| P2 | batch 并行 | ✅ 兼容入口已完成；真实并行暂缓 | MoonBit 当前缺少稳定跨 target worker runtime，已新增 `encode_batch_parallel(_fast)` / pair / pretokenized / pretokenized-pair parallel 兼容入口，委托现有串行批处理 + 批内缓存，保证顺序稳定与全后端一致；若后续运行时支持再替换内部实现 | 1–2 周（取决于运行时） |
| P2 | EncodeInput / TextInputSequence 统一输入类型 | ✅ 已完成 | 已新增 `TextInputSequence::{text,pretokenized}`、`EncodeInput::{single,single_pretokenized,pair,pair_pretokenized,mixed_pair}` 与 `encode_input` / `encode_input_fast` / `encode_input_batch` / `encode_input_batch_fast`；覆盖 raw、pretokenized、mixed pair、batch duplicate cache 与 fast offsets 置零；现有显式 API 保持兼容 | 0.5–1 周 |
| P3 | 完整 Hub 生态 | 🚧 tokenizer.json 下载 + metadata/离线校验/诊断/ref/resume/条件请求与响应决策已接入下载路径，固定 aux 读取、通用 sidecar 请求规划、2xx-only sidecar GET 与 raw sidecar cache bridge 已完成，HEAD 预检与真实流式落盘已完成 | 已补 `PretrainedAuxFiles` 与 `from_pretrained_aux_files`，可按本地目录/文件/Hub cache snapshot 读取固定的 `tokenizer_config.json` / `special_tokens_map.json`；`from_pretrained_aux_file(_path)` 可按同一解析规则读取 tokenizer 邻近的通用 basename sidecar 原文（如 `added_tokens.json`），但不解释内容；`cache_pretrained_aux_file` / `apply_hub_file_download_result` 可把宿主或 Hub 层拿到的完整 sidecar body 作为 raw 文件写入简化的 refs/snapshots cache，并由同一套 aux reader 读回；`download_hub_file` 可对 tokenizer 邻近 sidecar 执行简单 2xx-only GET 并跟随 redirect，但不套 tokenizer.json 的 ETag/Range/resume 决策；`from_pretrained_downloaded` 可同步写入两个固定 sidecar 与 `tokenizer.json.etag`，新增 `PretrainedCacheMetadata` / `from_pretrained_cache_metadata` 返回 tokenizer/sidecar 路径、revision、resolved revision、etag，并提供 `cache_exists` / `etag_matches` / `is_fresh` 与 tokenizer 级 helper 做离线 freshness 校验；新增 `PretrainedResolutionHint` / `from_pretrained_resolution_hint`，缺失 cache/snapshot/tokenizer.json 时输出含 private/gated repo 指引的可诊断消息；新增 `PretrainedCachePaths`、ref 读取/写入 helper、`PretrainedDownloadResumeMetadata` 读写/清理 helper，并在 hub 下载结果中透传 ETag；新增 `HubRequestPlan` / `HubResponseMetadata`，可生成 `If-None-Match` / `Range` / `If-Range` 请求计划并解析 HEAD/GET 响应元数据；新增 `HubTransferAction` / `HubResponseDecision`、`decide_tokenizer_json_response` 与 `apply_tokenizer_json_response`，覆盖 304 复用缓存、200 覆盖缓存、206 匹配 resume 后拼接 `.incomplete` 并清理 sidecar、416/不匹配 Range 触发无 Range 重试建议；新增 `apply_tokenizer_json_download_result` 并将 `download_tokenizer_json` 的真实 GET 路径接入 304/206 决策，Range 不匹配/416 会自动去掉 Range/If-Range 重试一次；新增 `head_tokenizer_json_request` / `decide_tokenizer_json_head_response` / `head_tokenizer_json` / `HubHeadResult`，真实 HEAD 路径跟随重定向且不读取 body，`from_pretrained` 在缓存命中时用 HEAD 校验 304 或 revision/ETag 一致后复用缓存，HEAD 不可用时保留离线缓存兼容；新增 `apply_tokenizer_json_download_chunks`（宿主 text chunk）与 `apply_tokenizer_json_download_bytes`（真实 HTTP byte chunk），按 chunk 写入 `tokenizer.json.incomplete` 并持续刷新 byte-accurate resume sidecar，支持 200 全量与 206 续传完成后清理临时文件；真实 `download_tokenizer_json` 已从一次性 `http.get(...).read_all()` 切换为 `http.get_stream` + `read_some(max_len=stream_chunk_size)`，网络层以 byte chunks 交给同一决策 helper，避免 UTF-8 多字节字符跨 chunk 时被 `decode_lossy` 破坏，并新增非 ASCII split chunk 测试；新增 `HubDownloadOptions::stream_chunk_size` / `with_stream_chunk_size` 控制刷新粒度；新增 `hub_file_url` / `plan_hub_file_request` 规划非 tokenizer sidecar 的 URL/header，但 `from_pretrained` 仍不自动下载 sidecar，sidecar ETag/Range/resume 决策与内容解析仍未接入；本地 correctness pack 补齐 HTTP header 大小写无关解析、`Content-Range` 起点校验防止 206 错位 append、slash revision/ref 嵌套目录写入，以及 HF 风格 model id/revision 字符与路径段校验，且不误伤本地文件/目录 `from_pretrained`；新增 401/403/404/429/5xx 本地 HTTP status 诊断 helper并接入 GET/HEAD reject message。后续继续补更完整的 Hub 文件族自动下载、sidecar 内容解析和错误映射；保持请求 header 与 HF 兼容，不引入非 HF 标识 | 1–2 周 |
| P3 | Python binding 兼容层 / 命名别名 | 🚧 state/命名别名/错误分类第三十七批已完成 | 已覆盖 tokenizer/model/component/encoding/trainer 的 state、tuple/buffer、属性 getter、显示 alias、构造器 alias、sequence/item 访问、参数字符串 helper 等 Python binding 迁移入口；详细分批记录见下方第三十批及之后段落，后续继续补低频属性与方法 alias，MoonBit 原生 API 保持 typed/显式风格 | 独立里程碑 |

第三十批补充 `Normalizer` / `PreTokenizer` / `Decoder` 的 lower-snake typed builder alias：覆盖常见 HF 构造器迁移入口（如 `bert_normalizer`、`metaspace`、`char_delimiter_split`、`bpe_decoder`、`fuse`、`sequence`），实现均为现有 typed enum variant 的薄封装，不改变 normalize / pre-tokenize / decode 行为。

第三十一批继续收敛 Python binding 长尾：补充 `Encoding` 的 HF 形态 helper（`*_by_sequence_index`、`token_to_char_offsets`、`token_to_word_index`、`truncate_hf`、`pad_hf`），保留现有 MoonBit typed/富返回值 API；同时锁定 Hub request header 合约（`Accept`、空 token 不生成 `Authorization`、JS/native `User-Agent` 差异）、GET/HEAD 的 slash revision URL segment 编码、HEAD plan 去除 Range/If-Range，以及 direct `local_files_only` 网络入口拒绝语义。

第三十二批继续补齐 Python binding 构造器长尾：`Decoder::metaspace(replacement='▁', prepend_scheme="always")` 作为 HF `decoders.Metaspace(...)` lower-snake factory alias，复用现有 `Metaspace` typed variant，不改变 decode 语义。

第三十三批继续补齐低层 pre-tokenizer binding 长尾：`PreTokenizedString::get_item(index)` / `__getitem__(index)` 返回当前 split，负 index 或越界返回 `None`；与 `NormalizedString`、`Normalizer`/`PreTokenizer`/`PostProcessor` sequence 组件的单 index 访问形态保持一致，便于 Python binding 映射 `pretokenized[index]`。

第三十四批补齐 Decoder sequence binding 长尾：`Decoder::get_item(index)` / `__getitem__(index)` 对 `Sequence` 返回子 decoder，非 sequence、负 index 或越界返回 `None`；与 `Normalizer` / `PreTokenizer` / `PostProcessor` 的 sequence 组件索引 alias 保持一致，不改变 decode 行为或 JSON/state。

第三十四批追加补齐 Sequence component 长度 alias：`PreTokenizer::__len__()` / `PostProcessor::__len__()` / `Decoder::__len__()` 对 `Sequence` 返回子组件数、非 sequence 返回 `0`，与 `Normalizer::__len__()` 保持一致，便于 Python binding 映射 `len(component)`。

Sequence component 子列表 getter 小闭环：`Normalizer::get_normalizers` / `PreTokenizer::get_pre_tokenizers` / `Decoder::get_decoders` / `PostProcessor::get_processors` 已补齐，作为现有 `normalizers` / `pre_tokenizers` / `decoders` / `processors` 的 HF-style getter alias；返回数组副本，修改返回值不影响原组件。

Normalizer 配置 getter alias 小闭环：`get_strip_left` / `get_strip_right` / `get_pattern` / `get_content` / `get_prepend` / `get_clean_text` / `get_handle_chinese_chars` / `get_strip_accents` / `get_lowercase` 已补齐，均委托现有 property-style getter，便于 Python binding 统一暴露 `get_*` 配置属性。

Normalizer Strip 精确属性名小闭环：`Normalizer::left()` / `right()` 已作为 HF `normalizers.Strip.left/right` 精确名称 alias 补齐，非 Strip normalizer 返回 `None`，不改变 normalize / state / JSON 行为。

Normalizer Bert strip_accents 三态保真：`BertNormalizer.strip_accents` 已从 Bool 折叠修正为 `Bool?` 三态，`None` 在 JSON/state 中序列化为 `null`，归一化行为按 HF 0.22.2 对拍随 `lowercase` 决定是否去音调；显式 `true/false` 保持原语义。

PreTokenizer 配置 getter alias 小闭环：`get_add_prefix_space` / `get_use_regex` / `get_trim_offsets` / `get_replacement` / `get_prepend_scheme` / `get_split` / `get_behavior` / `get_pattern` / `get_invert` / `get_regex` / `get_individual_digits` / `get_delimiter` / `get_length` 已补齐，均委托现有 property-style getter，便于 Python binding 统一暴露 `get_*` 配置属性。

PreTokenizer ByteLevel alphabet 精确方法名小闭环：`PreTokenizer::alphabet()` 已作为 HF `ByteLevel.alphabet()` 精确名称 alias 补齐，返回和 `byte_level_alphabet()` 相同的 256 项副本。

Decoder 配置 getter alias 小闭环：`get_add_prefix_space` / `get_trim_offsets` / `get_use_regex` / `get_prefix` / `get_cleanup` / `get_replacement` / `get_prepend_scheme` / `get_suffix` / `get_content` / `get_start` / `get_stop` / `get_left` / `get_right` / `get_pattern` / `get_pad_token` / `get_word_delimiter_token` 已补齐，均委托现有 property-style getter，便于 Python binding 统一暴露 `get_*` 配置属性；`left`/`right` 作为 HF `Strip` 参数名别名，`from_json` 同时接受两种键名。

Decoder Metaspace split state 小闭环：`Decoder::Metaspace` 与 `Decoder::metaspace` 已保留 HF `split` 配置字段，`from_json` / `to_json` / state round-trip 会保真 `split:false`，并新增 `split_enabled` / `get_split` 配置 getter；HF 0.22.2 对拍显示该字段影响 state 形状但不改变当前 decode 输出，因此 decode 语义保持不变。

PostProcessor 配置 getter alias 小闭环：`get_sep` / `get_cls` / `get_trim_offsets` / `get_add_prefix_space` / `get_use_regex` / `get_single_pieces` / `get_single` / `get_pair_pieces` / `get_pair` / `get_special_tokens` 已补齐，均委托现有 property-style getter，便于 Python binding 统一暴露 `get_*` 配置属性。

PostProcessor Sequence pair 小闭环：`Sequence([ByteLevel, BertProcessing/Template/...])` 在 pair 输入下会先分别处理 A/B 的 ByteLevel offsets，再把原始 pair 交给后续组装型 processor，避免旧实现把 B 合并进 A 后又把原 B 再传入导致 pair 序列重复；已按 HF `Sequence([ByteLevel, BertProcessing])` 对拍补 `encode_pair` 回归测试。

PostProcessor process flag 小闭环：低层 `PostProcessor::process(a, b, add_special_tokens=false)` 已对齐 HF 公开参数，跳过 special token 注入但保留 Template type_id、ByteLevel/RoBERTa offset trimming 等非 special-token 后处理效果；Tokenizer-level `post_process` 改为委托该低层实现。

TemplateProcessing typed alias 小闭环：`PostProcessor::single()` / `pair()` 分别作为 `single_pieces()` / `pair_pieces()` 的 HF-style typed alias；返回数组副本，非 Template processor 返回空数组，并覆盖 parsed pieces 与 `template_from_strings` 两种构造路径。

TemplateProcessing 叶子对象互操作：`SpecialToken::{get_id,id,get_ids,ids,get_tokens,tokens,as_tuple,from_tuple}` 已补齐，数组 getter 返回副本，方便 Python binding 映射 TemplateProcessing special token 元数据。

TemplateProcessing Piece 互操作：`Piece::{kind,get_kind,id,get_id,type_id,get_type_id,as_tuple,from_tuple}` 已补齐，覆盖 `SequenceRef` / `SpecialTokenRef` 两类模板叶子，未知 kind 显式报 parse error。

TemplateProcessing 叶子对象显示 alias：`Piece::__str__/__repr__` 与 `SpecialToken::__str__/__repr__` 已补齐，repr 对字符串字段做转义，便于 Python binding 日志和调试输出。

PostProcessor constructor alias 小闭环：`PostProcessor::bert_processing` / `roberta_processing` / `template_processing` 已补齐，作为 HF 类名风格构造入口，均委托现有 typed builder，不改变 process 或 JSON 行为。

Normalizer constructor alias 小闭环：`Normalizer::lowercase_normalizer` / `strip_accents_normalizer` / `nmt` / `precompiled` 已补齐，和已有 lower-snake builder 风格保持一致。

PreTokenizer ByteLevel 默认值对齐：HF 0.22.2 `ByteLevel()` 默认 `add_prefix_space=true`，`PreTokenizer::byte_level()` 已同步该默认值；显式 `add_prefix_space=false` 保留旧行为。

PreTokenizer Split constructor 默认参数对齐：`PreTokenizer::split(pattern, behavior)` 现在默认 `invert=false`、`regex=false`，对齐 HF literal-string `Split(pattern, behavior)` 常用入口；显式参数仍保留。

PreTokenizer FixedLength JSON 边界对齐：`tokenizer.json` / state 中 `FixedLength.length <= 0` 现在显式 `ParseError`，避免旧实现静默按 step=1 切分；手写 enum 仍保持无 `raise` 的内部逃生路径。

Model vocab getter 小闭环：`Model::get_vocab_size()` 作为 `vocab_size()` 的 HF-style alias 已补齐，和 Tokenizer 的命名保持一致。

Model vocab property alias 小闭环：`Model::vocab()` 已补齐，作为 `get_vocab()` 的属性式 alias，并保持返回词表副本，避免调用方修改内部 vocab。

Model 配置 getter alias 小闭环：`get_unk_token` / `get_unk_id` / `get_continuing_subword_prefix` / `get_end_of_word_suffix` / `get_max_input_chars_per_word` / `get_byte_fallback` / `get_fuse_unk` / `get_ignore_merges` / `get_dropout` / `get_alpha` / `get_nbest_size` 已补齐，全部委托现有 property-style getter，便于 Python binding 统一暴露 `get_*` 配置属性。

Model 直接构造器小闭环：`Model::wordlevel(vocab, unk_token="<unk>")` 与 `Model::wordpiece(vocab, unk_token="[UNK]", continuing_subword_prefix="##", end_of_word_suffix=None, max_input_chars_per_word=100)` 已补齐，覆盖 HF `models.WordLevel(vocab=...)` / `models.WordPiece(vocab=...)` 的内存词表迁移入口；构造时复制 vocab 并建立 dense reverse lookup，测试覆盖稀疏 id、默认参数、tokenize、state 往返与输入 Map 修改隔离。

Model artifact 命名 alias 小闭环：`bpe_read_file` / `bpe_from_file`、`wordpiece_read_file` / `wordpiece_from_file`、`wordlevel_read_file` / `wordlevel_from_file` 已补齐，委托现有 standalone artifact loader，对齐 HF `models.*.read_file/from_file` 命名；Unigram 不补对应 alias，因为 HF Python API 未提供同名入口。

Encoding 显示 alias 小闭环：`Encoding::__str__()` 已补齐，返回与 `__repr__()` 相同的 HF-style 诊断摘要，覆盖 Python binding 的 `str(encoding)` 映射。

AddedToken constructor 小闭环：`AddedToken::new` 已支持 `single_word` / `lstrip` / `rstrip` / `normalized` / `special` HF-style keyword 参数；`special=true` 且未显式指定 `normalized` 时默认 `false`，保留普通 token 默认 `normalized=true`。

AddedToken 注册计数小闭环：`add_tokens_with_count` / `add_special_tokens_with_count` 已按 HF 语义返回“新增 added-vocab 注册数”，已存在于 model vocab 的 token 首次注册为 added/special token 时也计数但保留原 id，重复注册返回 0；新增 `add_token_strings_with_count` / `add_special_token_strings_with_count` 字符串入口，和 AddedToken 数组入口共享同一计数语义。

AddedToken Unicode whitespace 小闭环：`lstrip` / `rstrip` 在 added-token 抽取阶段已从 ASCII whitespace 扩展到 HF/Rust regex 同类 Unicode whitespace（含 NBSP），只影响 added token 周边空白吸收，不改变 `Normalizer::Strip` 的 ASCII helper 语义。

AddedToken state/property 覆盖近期增量：`AddedToken::get_state()` 已和 `__getstate__()` 等价覆盖，`with_special(false)` 显式切回非 special 且不隐式改写 normalized 配置的行为已补回归测试。

Encoding truncate_hf 边界对齐：`Encoding::truncate_hf(max_len, stride)` 在 `stride >= max_len` 时显式报错，匹配 HF 公开 wrapper；typed `truncate` 保持原有宽松不可变 API。

Encoding HF direction 边界对齐：`truncate_hf` / `pad_hf` 对非 `left`/`right` 的 direction 字符串显式 `ParseError`，不再静默回落为 right。

Tokenizer HF 字符串配置 wrapper 小闭环：`enable_truncation_hf(max_length, strategy="longest_first", direction="right")` 与 `enable_padding_hf(direction="right", ...)` 已补齐，接受 HF 风格字符串 strategy/direction 并对非法值抛 `ParseError`，同时保留现有 typed `enable_truncation` / `enable_padding` API。

Truncation/Padding 参数字符串 helper 小闭环：`TruncationParams::with_direction_hf` / `with_strategy_hf`、`direction_string` / `get_direction_string`、`strategy_string` / `get_strategy_string` 与 `PaddingParams::with_direction_hf`、`direction_string` / `get_direction_string` 已补齐，让参数对象本身也可按 HF 字符串 direction/strategy 做 binding 映射，并复用非法字符串 `ParseError` 边界。

PostProcessor Sequence pair 小闭环：`Sequence` 中只做 ByteLevel offset trimming 等不消费 pair 的步骤时，最终不再丢失第二段；`Sequence([ByteLevel, BertProcessing])` 继续把 pair 交给第一个真正消费 pair 的 processor，避免旧路径把第二段重复拼接；已补 ByteLevel-only pair 与 ByteLevel+BertProcessing pair 回归。

Unknown-token fallback parity 小闭环：Unigram 在缺少 `unk_id` 且实际遇到 unknown 时改为抛 `VocabError("Encountered an unknown token but `unk_id` is missing")`，不再返回 `-1`；WordLevel/WordPiece 在 fallback token 未出现在 vocab 时按 HF 抛 `VocabError`；BPE 在 `unk_token=None` 时跳过未知 symbol，配置了 `unk_token` 但 vocab 缺失时抛错。`Model::tokenize`、`PreTokenizedString::to_encoding` 与 tokenizer encode/fast/batch/pair/pretokenized/async 兼容入口均已显式传播 `TokenizerError`，benchmark 通过 non-raising `must_encode*` wrapper 保持 `b.bench` callback 合约。

Tokenizer JSON strictness 小闭环：HF `Tokenizer.from_str` 要求 WordLevel / WordPiece `model.unk_token`、BPE `model.merges`、WordPiece `model.continuing_subword_prefix` 与 `model.max_input_chars_per_word` 字段显式存在；MoonBit 已改为加载缺字段或错误类型时抛 `ParseError` / `VocabError`，直接内存构造器 `Model::wordlevel` / `Model::wordpiece` 仍保留 HF Python constructor 默认值，兼顾 JSON parity 与 programmatic API 便利性。

Tokenizer JSON typed-field strictness 小闭环：BPE `ignore_merges` / `fuse_unk` / `byte_fallback`、Unigram `byte_fallback` / `fuse_unk` 必须是 bool，BPE `dropout` 必须是 number；错误类型现在按 HF 解析语义抛 `ParseError`，不再静默回落默认值。

Tokenizer JSON optional string strictness 小闭环：BPE `unk_token` / `continuing_subword_prefix` / `end_of_word_suffix` 与 WordPiece `end_of_word_suffix` 继续允许缺失或 `null` 表示 `None`，但若字段存在且类型不是 string/null 会按 HF 解析语义抛 `ParseError`，不再静默当作缺省值。

Tokenizer JSON optional int strictness 小闭环：Unigram `unk_id` 继续允许缺失或 `null` 表示 `None`，但若字段存在且类型不是 number 会按 HF 解析语义抛 `ParseError`，不再静默当作缺省值。

Tokenizer JSON optional number strictness 小闭环：Unigram `alpha` / `nbest_size` 继续允许缺失或 `null` 表示 `None`，但若字段存在且类型不是 number 会按 HF 解析语义抛 `ParseError`，不再静默当作缺省值。

AddedToken JSON strictness 小闭环：`added_tokens` 条目已按 HF schema 严格要求 `id` / `content` / `single_word` / `lstrip` / `rstrip` / `normalized` / `special` 字段存在且类型正确；缺字段或错类型会抛 `ParseError`，现有手写 fixture 已补齐完整字段。

Root truncation/padding JSON strictness 小闭环：root `truncation` / `padding` 已按 HF tokenizer JSON schema 收紧必填字段和 enum 大小写，`max_length` / `stride`、`strategy`、padding `direction` / `pad_id` / `pad_type_id` / `pad_token` 等缺失或错类型会抛 `ParseError`；`padding.strategy` 固定长度只接受 `{"Fixed": n}`，顶层 `length` 继续按 HF 行为忽略；`truncation.direction` 可省略并默认 `Right`。

High-level encode post-processing parity 小闭环：`Tokenizer::encode` / pair / batch / fast / pre-tokenized / mixed `EncodeInput` 在 `add_special_tokens=false` 时不再绕过 configured post-processor，而是按 HF 语义仅移除由 post-processor 注入的 special tokens，同时保留 Template/BERT `type_ids`、句对 `sequence_ids` 与 ByteLevel/RoBERTa offset trimming；显式 `post_process(false)` 与高层 encode 路径已补一致性测试。

main/docs 文档站小闭环：VuePress 2 + `vuepress-theme-plume` 文档站源码已落到主分支现有 `docs/` 目录，不再依赖单独 `docs-site` 或 `gh-pages` 源码分支；新增分层指南、概念、兼容矩阵、迁移、参考、性能与开发页面，包含 Mermaid pipeline/迁移/benchmark/docs workflow 图和多张支持表；Pages 已切到 GitHub Actions workflow，`pnpm@11.10.0` + `pnpm-lock.yaml` / `pnpm-workspace.yaml` 管理依赖，workflow 使用 Node `24.11.0` 并将 `docs/` 构建到 `gh-pages-deploy/` artifact。

Benchmark fixture strictness 小闭环：`src/benchmarks/bench_test.mbt` 中 synthetic `added_tokens` fixtures 已补齐 `single_word` / `lstrip` / `rstrip` / `normalized` / `special` 完整 HF schema，避免 benchmark smoke 在严格 tokenizer.json parser 下抛 `ParseError`；本地 `python3 scripts/bench_compare.py --target native --quick --corpus mixed` 已通过并覆盖 pre-tokenized / offset lookup benchmark cases。

Plume 文档站 locales / Mermaid / home hero / 双语同构小闭环：文档站已按 Plume locales 规范把 `/` 与 `/zh/` 的 navbar/sidebar 拆到 theme locale 配置，root locale 显式声明 `selectLanguageName: English`，中文导航与侧栏补齐指南、概念、兼容性、迁移、参考、性能、开发七个栏目并与英文路径同构，不再在英文导航里手写“中文”入口；Mermaid 已在 `plumeTheme({ markdown: { mermaid: true } })` 开启，并通过 `@vuepress/plugin-markdown-chart/client` 的 `defineMermaidConfig` 配置非紫色主题变量，`.mermaid-wrapper` / `.mermaid-content` CSS 兜底保持 pipeline / migration / benchmark / docs workflow 图在 light/dark 模式下统一使用绿色、青色与中性色系；英文与中文首页同步使用 Plume `tint-plate` hero effect 和简洁技术文档入口文案，避免默认紫色 hero 渐变；`docs/development/docs-workflow.md` 与 `docs/zh/development/docs-workflow.md` 已写入后续用户可见行为/API/兼容性/迁移/性能/导航变更必须同步更新中英文文档的维护规则。

Performance 文档数据图小闭环：`scripts/bench_compare.py --json-out` 产出的 MoonBit/HF 对比报告可通过 `scripts/update-docs-benchmarks.mjs` 转换为 `docs/.vuepress/public/benchmarks/latest.json`，`BenchmarkSnapshot` VuePress 组件会在英文/中文 performance 页面读取该 JSON 并展示 target/corpus/model 摘要、verdict 计数、Moon/HF ratio 条形图与表格；CI bench-smoke 会上传 `reports/bench-native-mixed.json` artifact，Pages workflow 在构建前尽力生成最新 docs snapshot，失败时保留 checked-in fallback 数据，避免阻塞文档发布。

Trainer 通用 getter alias 小闭环：`get_unk_token` / `get_min_frequency` / `get_special_tokens` / `get_special_added_tokens` / `get_vocab_size` / `get_show_progress` / `get_word_count` 已补齐，均委托现有 property-style getter 并保持数组/AddedToken 返回副本，便于 Python binding 统一暴露 `get_*` 配置属性；`get_word_count` 对 BPE 返回训练后唯一词数，其它模型返回 `None`。

Trainer model-specific getter alias 小闭环：WordPiece/BPE/Unigram 特有 knobs 已补对应 `get_*` alias，覆盖 `get_continuing_subword_prefix` / `get_end_of_word_suffix` / `get_initial_alphabet` / `get_limit_alphabet` / `get_max_token_length` / `get_max_input_chars_per_word` / `get_fuse_unk` / `get_byte_fallback` / `get_shrinking_factor` / `get_max_piece_length` / `get_n_sub_iterations` / `get_seed_size` / `get_progress_format`，数组返回继续保持 copy-return 语义。

Encoding merge defaults 小闭环：`Encoding::merge` / `merge_with` 已暴露，默认 `growing_offsets=true`，显式 `false` 时保留各段原 offsets；已补默认 growing 与显式 false 两种行为测试。

Encoding merge pad/special offset 回归覆盖：HF 对拍确认前段末尾为 special/pad `(0,0)` 时，`growing_offsets=true` 不会按前一个非零 span 偏移后段；已补 padding 后 merge 的回归测试锁住该边界。

Encoding validation 小闭环：`Encoding::new` / `from_state` / `from_buffers` / `from_tuple` 以及 `__setstate__` 已校验公开 parallel arrays 长度一致性；省略 `sequence_ids` / `word_ids` 仍保留 HF-style 默认值，传入非空且长度不匹配会抛 `ParseError`。`with_type_ids` / `with_special_tokens_mask` / `with_attention_mask` / `with_word_ids` 也会校验 replacement array 长度，`set_sequence_id` / `with_sequence_id` 拒绝负数 sequence id。

Replace pattern kind 保真小闭环：Normalizer / Decoder `Replace` 已保留 HF `pattern` 的 `{String: ...}` / `{Regex: ...}` tag，JSON/state 中 String 形态按字面量 substring 替换，Regex 形态走现有 deterministic regex 子集；`replace(...)` factory 创建 String 形态，`replace_regex(...)` 创建 Regex 形态，直接 enum `Replace(...)` 保持既有 regex-backed 测试语义以兼容内部 typed 使用。

Tokenizer state constructor 小闭环：`TokenizerState::new(json)` 已补齐，和 `ModelState` / `NormalizerState` / `PreTokenizerState` / `PostProcessorState` / `DecoderState` 的 JSON-backed state wrapper 构造方式保持一致，便于 binding/pickle shim 直接构造 tokenizer state。

Trainer iterator length 兼容：`Tokenizer::train_from_iterator(..., length=Some(n))` 已接受 HF progress hint 参数并作为 no-op，训练结果与不传 `length` 一致。

第三十五批补齐低层 value display alias：`Token::__str__()` / `Split::__str__()` 返回 surface value，`Token::__repr__()` / `Split::__repr__()` 返回带转义的紧凑诊断摘要，覆盖 Python binding 对底层 token/split 对象的显示迁移。

第三十六批补齐 Trainer constructor alias 长尾：`Trainer::wordlevel_trainer` / `wordpiece_trainer` / `bpe_trainer` / `unigram_trainer` 作为 HF/Python lower-snake constructor 入口，全部委托现有 typed builder，保持默认值、state 与训练行为一致。

Hub env/local-only 小闭环：新增 `@hub.from_pretrained(..., local_files_only=true)` cache hit/miss 覆盖，验证缓存命中直接返回本地 tokenizer 且不触网，缓存缺失抛出 `from_pretrained local cache miss and local_files_only=true`；核心 `from_pretrained` 默认 cache root 识别 `$HF_HUB_CACHE`（在 legacy `$HUGGINGFACE_HUB_CACHE` 之后、`$HF_HOME/hub` 之前），并补齐 `$HF_HOME/hub` 与 `$HOME/.cache/huggingface/hub` fallback 测试；`PretrainedCacheMetadata::etag_matches(None)` / tokenizer-level cache etag helper 明确表示“无 expected ETag 时只要求 cache 存在”；`HubDownloadOptions::new()` 读取 `$HF_ENDPOINT` 作为默认 endpoint，并在 `$HF_HUB_OFFLINE` 为真值时默认进入 local-only 模式；Hub request auth 也按显式 token → `$HF_TOKEN` → `$HF_TOKEN_PATH` → `$HF_HOME/token` 顺序发现 bearer token，显式 options 仍可覆盖。

Hub env/header 边界覆盖近期增量：补齐 `HF_HUB_OFFLINE` 真值大小写（`TRUE` / `Yes` / `ON`）、负数 `stream_chunk_size` 回落默认值，以及显式空 token 在 `HF_TOKEN` 存在时仍不生成 Authorization header 的测试。

Hub/Core aux 与 sidecar 文件小闭环：`PretrainedAuxFiles` 固定覆盖 `tokenizer_config.json` / `special_tokens_map.json`；`from_pretrained_aux_file(_path)` 可按本地目录/文件/Hub cache snapshot 解析 tokenizer 邻近的通用 basename sidecar（如 `added_tokens.json`），返回原始文本或路径，不解释内容并拒绝路径穿越文件名；`cache_pretrained_aux_file` 可把 raw sidecar 写入 refs/snapshots cache，且 sidecar-only snapshot 也可由 aux reader 读回。

Hub sidecar request/download/cache 小闭环：新增 `hub_file_url` / `plan_hub_file_request`，复用 tokenizer.json 的 endpoint/revision 编码与 HF-style headers，支持 tokenizer 邻近 basename sidecar 的本地纯规划；`download_hub_file` 可做简单 2xx-only sidecar GET 并跟随 redirect，`apply_hub_file_download_result` 可把完整 sidecar response body 写为 raw snapshot 文件；非 tokenizer.json 文件仍不附带 tokenizer cache/range metadata，也不做 `from_pretrained` 自动下载、ETag/Range/resume 或内容解析。

Hub 高层本地路径语义小闭环：`@hub.from_pretrained` 对已存在的本地 `tokenizer.json` 文件或含 `tokenizer.json` 的目录直接委托 core loader 返回，不做 HEAD/GET；已补 native async 测试覆盖本地单文件、本地目录、本地目录缺 `tokenizer.json` 错误优先，以及 `local_files_only=true` cache miss 仍报本地 cache miss。

Hub metadata/HEAD correctness 覆盖近期增量：`HubResponseMetadata::from_headers` 已补空/非法 `Content-Length`、非 `bytes` `Accept-Ranges`、`Content-Range: bytes */total`、非法单位与反向 range 解析边界；HEAD `200` 在远端 revision/ETag 为空时不会误判缓存命中，而是要求重新下载。

Tokenizer public API 文档同步闭环：英文/中文 API 文档补齐已实现但此前未列全的 `from_buffer`、`to_str(pretty)`、`save(path, pretty)`、`save_pretrained(pretty/save_model/model_prefix)`、`enable_truncation` / `no_truncation`、`enable_padding` / `no_padding`、`enable_encode_special_tokens` / `disable_encode_special_tokens`、Tokenizer component/config setter alias（`set_normalizer` / `set_pre_tokenizer` / `set_model` / `set_post_processor` / `set_decoder` / `set_truncation` / `set_padding`）以及 Truncation/Padding 参数字符串 helper，减少 HF 迁移时对源码的依赖。

Hub/Pretrained API 文档同步近期增量：英文/中文 API 签名补齐 `from_pretrained_downloaded(..., tokenizer_config_json, special_tokens_map_json, etag)` 与 `HubDownloadOptions::new(..., stream_chunk_size)`，和当前 core/hub 公开接口保持一致。

训练/模型文件近期增量：`Trainer::{wordlevel,wordpiece,bpe,unigram}`、对应 lower-snake alias、`Model::train_*` 以及 `Tokenizer::train_wordlevel*` / `train_wordpiece*` / `train_bpe*` / `train_unigram*` convenience helper 的默认 `vocab_size` 已统一对齐 HF cap（WordLevel/WordPiece/BPE 为 `Some(30000)`，Unigram 为 `Some(8000)`；显式 `None` 表示不设 cap），Unigram trainer 默认 `max_piece_length=Some(16)` 且显式 `None` 保留旧 escape hatch；tokenizer/model-level trainer 入口补充 `show_progress` no-op，model-level Unigram 补充 `unk_piece` alias。`Model::save` 之外已补 `Model::from_bpe_files` / `from_wordpiece_file` / `from_wordlevel_file` / `from_unigram_file` standalone artifact loader，覆盖 BPE `vocab.json`+`merges.txt`、WordPiece `vocab.txt`、WordLevel `vocab.json`、Unigram JSON 的保存后重载。

训练文件/metadata correctness 覆盖近期增量：`train_from_iterator(length=...)` 已补 `0` / 大值 hint 不影响训练结果的回归测试；`train_from_files` 已覆盖多文件中后续文件缺失时的精确错误消息、无尾换行的末行保留、空文件与空 iterator 等价；`special_tokens` 与 `special_added_tokens` 同 content 时已覆盖去重并保留 `AddedToken` metadata。

训练默认值近期对齐：HF 0.22.x 的 WordLevel/WordPiece/BPE `min_frequency` 默认是 `0`，MoonBit 已完成三者默认值对齐，并保留显式旧阈值测试；BPE trainer 默认 `unk_token=None` 已对齐 HF，显式 `Some("[UNK]")` 保留旧行为；Unigram trainer/tokenizer/model 默认 `unk_token=None` 已对齐 HF，显式 `unk_token=Some("<unk>")` / `unk_piece=Some(...)` 保留旧行为；隐式 unk 关闭后的 unknown encode 边界已按 HF 改为跳过或抛错。后续训练风险主要转为完整 Unigram EM/大语料 golden 对拍。

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

通过表驱动的 `parity_test.mbt`（`scripts/fetch_models.py` + `scripts/gen_parity.py` 生成期望），覆盖 39 个真实/公开 tokenizer.json 模型（fixture 缺失时自动跳过）：

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
| ModernBERT-base | BPE + normalizer/pre-tokenizer modern encoder pipeline | ✅ |
| GTE-ModernBERT-base | BPE + ModernBERT embedding tokenizer | ✅ |
| all-MiniLM-L6-v2 | WordPiece / sentence-transformers embedding tokenizer | ✅ |
| bge-large-en-v1.5 | WordPiece embedding tokenizer | ✅ |
| jina-embeddings-v3 | XLM-R/Unigram-style multilingual embedding tokenizer | ✅ |
| nomic-embed-text-v1.5 | WordPiece embedding tokenizer | ✅ |
| multilingual-e5-small | multilingual embedding tokenizer | ✅ |
| mxbai-embed-large-v1 | WordPiece embedding tokenizer | ✅ |
| SmolLM2-135M-Instruct | compact LLM BPE tokenizer | ✅ |

## 组件实现矩阵

### Models
| 组件 | 状态 | 备注 |
|---|---|---|
| BPE / 字节级 BPE | ✅ | 优先队列(pairing heap)合并 + 惰性失效 + word cache；decode 反查使用 dense id array 并在加载时直接填充；`unk_token=None` 时 unknown symbol 按 HF 跳过，配置 unk 但 vocab 缺失时抛错；native mixed 抽样 gpt2/llama encode 快于 HF |
| byte_fallback / fuse_unk / ignore_merges | ✅ | |
| WordPiece | ✅ | 贪心最长前缀；支持 `continuing_subword_prefix` 与 HF `end_of_word_suffix`；fallback `[UNK]` 缺失时抛错 |
| Unigram | ✅ | Viterbi DP + word cache + forward-backward sampling；`byte_fallback` / `fuse_unk` / `alpha` / `nbest_size` supported；`alpha > 0` 时启用采样模式；缺少 `unk_id` 且遇到 unknown 时抛错；native mixed 抽样 t5/bge/e5 encode 快于 HF |
| WordLevel | ✅ | fallback unk token 缺失时抛错 |
| dropout / word cache | ✅ | BPE `dropout` 已解析/序列化并在 `>0` 时禁用 word cache；BPE/WordPiece/Unigram word cache 已完成，后续仅保留更细粒度容量/性能优化 |

### Normalizers
| 组件 | 状态 |
|---|---|
| Lowercase / Strip / Replace / Prepend / Sequence | ✅ |
| BertNormalizer（clean_text/handle_chinese_chars/strip_accents/lowercase）| ✅ |
| StripAccents（NFD+Mn 最小表，1006 条，lazy 加载）| ✅ |
| NFC/NFD/NFKC/NFKD | ✅ | 生成表 + UAX #15 分解/排序/重组 |
| Precompiled（SentencePiece charsmap）| ✅ | 已支持 tokenizer.json 中的二进制 double-array `precompiled_charsmap` 解码；空/缺失 map 保留主流 SPM NFKC + 全 Unicode 空白映射，并为 ASCII 输入提供 fast path |
| Nmt | ✅ | 控制/格式字符清理 + Unicode 空白归一 |
| ByteLevel-normalizer | ✅ | UTF-8 bytes → GPT-2 byte alphabet |

### Pre-tokenizers
| 组件 | 状态 |
|---|---|
| ByteLevel（手写 GPT-2 扫描）| ✅ |
| Whitespace / WhitespaceSplit / BertPreTokenizer / Punctuation / Metaspace / Sequence | ✅ |
| Punctuation / Split SplitBehavior | ✅ | Removed / Isolated / MergedWithPrevious / MergedWithNext / Contiguous；Split 的 Contiguous 会合并相邻 delimiter spans |
| Split（GPT-2 / Qwen-Llama3 / o200k / CLIP / CJK / digit-triplet 家族正则）| ✅ 现代 LLM/CLIP 主线；o200k case-aware letter scanner 已覆盖希腊字母 |
| Digits / Delimiter / FixedLength / UnicodeScripts | ✅ | 已补直接 runtime offsets 单测 |
| Split（Regex 策略）| ✅ 已覆盖主流 GPT/Qwen/o200k/CLIP/CJK/digit regex + 简单 literal / escaped-literal alternation（含单 literal group、`^...` / `...$` 锚定与 `\\b...\\b` / `^\\b...\\b$` word-boundary 形式）/ ` {2,}` / `\\s+` / `\\S+` / `\\s+$` / `[\\r\\n]`；复杂未知 pattern 加载期显式 Unsupported |

### Decoders
| 组件 | 状态 |
|---|---|
| ByteLevel / WordPiece / BPEDecoder / Metaspace / Fuse / Replace / Strip / Sequence | ✅ | WordPiece cleanup 已改为单遍 BERT 标点/缩写 fast path，并公开 `Decoder::wordpiece` builder |
| ByteFallback | ✅（R2）| 覆盖连续 / 中断 / 非法 UTF-8 byte runs |
| CTC | ✅ | 覆盖 duplicate collapse、pad drop、word delimiter 与 cleanup |

### Post-processors
| 组件 | 状态 |
|---|---|
| TemplateProcessing（预解析 pieces）/ Bert / Roberta / ByteLevel / Sequence | ✅ |
| RobertaProcessing pair type_ids | ✅ | 与 HF 一致，pair 两段均为 type_id 0 |
| TemplateProcessing 字符串模板 DSL（$A/$B/$0:1）| ✅ | `$A`/`$B` 与 `$0`/`$1` aliases 均有直接覆盖 |

### Tokenizer 核心
| 能力 | 状态 |
|---|---|
| from_str / from_file（x/fs 全后端）| ✅ | `from_str` 使用小型多项 parsed-JSON cache，交替加载多个稳定 tokenizer.json 时避免重复解析 |
| encode / encode_pair / decode | ✅ |
| AddedVocabulary（single_word/lstrip/rstrip/normalized）| ✅ |
| token_to_id / id_to_token / get_vocab / get_vocab_size | ✅ | `get_vocab(with_added_tokens=true)` 默认包含 added tokens |
| truncation / padding / encode_batch | ✅ | `with_truncation` / `with_padding` builder 与 `set_truncation` / `set_padding`、`enable_truncation` / `no_truncation`、`enable_padding` / `no_padding` alias；Truncation/Padding 参数对象支持 HF string helper；BatchLongest/Fixed；batch 串行；encode_pair 已接入 finalize |
| decode_batch / decode_stream | ✅ | `decode_batch` 串行实现并带重复 id 序列缓存；`decode_stream` 对齐 HF token-by-token 增量解码，显式返回更新后的 stream，覆盖 special skip 与 incomplete ByteFallback buffering |
| tokenizer.json root truncation/padding 自动加载 | ✅ | 已解析 root-level `truncation` / `padding`，覆盖 Fixed/BatchLongest 与方向/倍数/pad 字段 |
| offsets | ✅ | 默认保留 char offsets；新增 `encode_with_byte_offsets` / `encode_pair_with_byte_offsets` 对齐 HF byte offsets；ByteLevel post-processor `trim_offsets` 已按 HF 空白裁剪语义对齐 |
| sequence_ids | ✅ | `Encoding::sequence_ids()`；special/padding 为 None，pair 序列为 Some(0)/Some(1) |
| token-char 映射 | ✅ | `token_to_sequence` / `token_to_chars` / `char_to_token`，半开区间语义对齐 HF |
| Encoding HF-style getters | ✅ | `get_ids` / `get_type_ids` / `get_tokens` / `get_offsets` / `get_special_tokens_mask` / `get_attention_mask` / `get_overflowing` 返回副本，便于从 HF Encoding 迁移 |
| Encoding / Tokenizer metadata getters | ✅ | `Encoding::len` / `is_empty` / `n_sequences` / `get_sequence_ids` / `get_word_ids`，以及 Tokenizer component getters（model/normalizer/pre_tokenizer/post_processor/decoder/truncation/padding）|
| 程序化构造 / AddedToken API | ✅ | `Tokenizer::new`、组件/配置 `with_*` builder 与对应 `set_*` alias（normalizer/pre_tokenizer/model/post_processor/decoder/truncation/padding）、`AddedToken` builder、`add_tokens(_with_count)` / `add_special_tokens(_with_count)`；普通 added token mask=0，special token mask=1，支持 `encode_special_tokens`、added-token introspection（含 `get_added_tokens_decoder`、`get_all_special_tokens` / `get_all_special_ids`）、`num_special_tokens_to_add` 与显式 `post_process`；typed normalizer/post_processor/decoder/truncation/padding 可序列化往返 |

## R9：HF 迁移缺口排期

目标：把「能跑主流 tokenizer.json 推理」推进到「大多数 HF tokenizers 推理用户低成本迁移」。训练器与 Hub 能力体量较大，单独排期；每项必须配套测试和 benchmark（涉及性能/API 的项）。

| 优先级 | 项目 | 状态 | 验收标准 |
|---|---|---|---|
| P0 | `get_vocab(with_added_tokens=true)` | ✅ | 导出模型词表 + added_tokens；新增单测覆盖 with/without added tokens |
| P0 | `decode_batch` | ✅ | API 行为与 `decode` 一致；新增单测与 batch decode bench；对重复 id 序列做单批缓存 |
| P0 | `decode_stream` | ✅ | 增量 decode API 行为与 HF `DecodeStream` 对齐；新增 full-decode 拼接、special skip、ByteFallback incomplete UTF-8 单测与 HF benchmark 对比 |
| P0 | root-level `truncation` / `padding` 自动加载 | ✅ | `Tokenizer::from_str` 直接应用 tokenizer.json 配置；新增单测覆盖 Fixed padding + truncation |
| P0 | CI / pre-commit 编译测试门禁 | ✅ | 本地 pre-commit 运行 `moon check` + wasm/wasm-gc/js/native 全后端测试；GitHub Actions 覆盖格式/多 target 测试、Python 脚本编译、parity smoke 与 quick HF benchmark smoke |
| P1 | byte offsets 模式 | ✅ | 可选择输出 HF Rust 风格 byte offsets；新增中英/emoji offset 对拍与 bench |
| P1 | `sequence_ids` | ✅ | Encoding 增加字段和访问 API；覆盖 pair/special tokens |
| P1 | token-char 映射 | ✅ | 已补 `token_to_sequence` / `token_to_chars` / `char_to_token`；覆盖 pair/special/byte offsets，并新增 lookup bench |
| P1 | pre-tokenized encode API | ✅ | 已补 `encode_pretokenized` / pair / batch / pair_batch 及 byte-offset variants；跳过 pre-tokenizer 但保留 added-token extraction、normalizer/model/post-processor/truncation/padding，输入词内部 special/added token 按 `single_word`/`lstrip`/`rstrip`/`normalized` 规则切出，offsets 基于 normalized words 单空格连接；新增单测与 HF benchmark 对比 |
| P1 | `word_ids` / word-char 映射 | ✅ | 已补 `word_ids`、`token_to_word`、`word_to_tokens`、`word_to_chars`、`char_to_word` 与 HF-style `Encoding::get_*` accessors；覆盖 pair/special/byte offsets，并纳入 lookup/accessor bench |
| P1 | Encoding / Tokenizer getter 迁移 API | ✅ | 补齐 HF 常用 `Encoding.len/is_empty/n_sequences/get_word_ids/get_sequence_ids` 与 tokenizer component getters；更新 accessor bench 与 HF baseline |
| P1 | Truncation strategy 完整化 | ✅ | 支持 LongestFirst/OnlyFirst/OnlySecond；pair encode 按 HF 顺序：预留 special slots 后先截断 raw pair，再 post-process/pad；公开 `TruncationParams::with_*` builder 覆盖 stride/direction/strategy |
| P1 | ByteLevel post-processor `trim_offsets` 细节 | ✅ | 空白修剪与 HF offsets 对齐；已补 ByteLevel / RoBERTa offset 用例与 micro bench |
| P1 | 程序化 Tokenizer 构造与 AddedToken API | ✅ | 对齐 HF `Tokenizer(model)`、组件赋值与 `add_tokens` / `add_special_tokens` 主流程；新增 builder、`set_*` property-style alias、count 返回、重复 token 不增词表、已存在 model token 可注册为 added/special 以参与预切分；补 typed normalizer/post_processor/decoder/truncation/padding 序列化、`encode_special_tokens` 开关、`get_added_tokens_decoder` / `is_special_token` introspection、`num_special_tokens_to_add` 与显式 `post_process`；round-trip 单测、API/迁移文档与 HF builder/add-token/to_json/post_process benchmark 行已覆盖 |
| P2 | Precompiled SentencePiece charsmap 完整解码 | ✅ | 已支持 base64 `precompiled_charsmap` → SentencePiece double-array trie → normalized blob 规则；保留空/缺失 map 的 NFKC+空白 fast path，并新增二进制 charsmap 单测与 bench |
| P2 | 通用 Split/Replace 正则覆盖策略 | ✅ | Normalizer/Decoder Replace 已统一走 Split 的 deterministic simple-regex span scanner，覆盖 `\\s` / `\\S` / `\\d` / `\\D` / `\\w` / `\\W`、ASCII alnum/letter、Unicode `\\p{L}` / `\\p{N}` / `\\p{P}` / `\\p{S}`、punctuation-or-symbol union、anchored positive/inverse class runs、覆盖同一批正向/反向 class families 的 exact `{2}`/`{3}`/`{4}`、min `{2,}`/`{3,}`/`{4,}`、bounded `{1,n}` 与 ranged `{2,3}`/`{2,4}`/`{3,4}` families；Decoder Replace 对这些 simple regex 直接绕过 decode_chain，Split/Normalizer/Decoder 三套语义由 `common` 同一分发表驱动，并已补 exact/min inverse regex bench 与 HF baseline；复杂未知 Split pattern 加载期显式 Unsupported，未知 Replace pattern 保持字面量 fallback；full regex engine 不作为该阶段验收目标 |
| P2 | save / to_json / from_file 对称性 | ✅ | `to_json` 保留原始 tokenizer.json；`Tokenizer::from_file` / `save` 可往返；新增 HF 风格 `save_pretrained(dir)` 写出 `dir/tokenizer.json` 并可由 `from_pretrained(dir)` 重新加载；补 serialization 测试与 to_json/save_pretrained bench |
| P3 | `from_pretrained` / Hub 集成 | ✅ | 核心 `@tokenizer.from_pretrained` 保持全后端离线加载：本地 HF 目录（`tokenizer.json`）、tokenizer 文件路径、`save_pretrained` 目录、已有 HuggingFace Hub cache snapshot（`$HUGGINGFACE_HUB_CACHE` / `$HF_HUB_CACHE` / `$HF_HOME/hub` / `$HOME/.cache/huggingface/hub`，含 refs/main → snapshots/<rev> 与显式 revision 解析），并对稳定 pretrained 路径做小型 FIFO source cache；新增 `from_pretrained_downloaded` 作为宿主/下载器桥接 API，可写入标准 HF cache；新增可选 native/js `hub` 包，基于 `moonbitlang/async/http` 在线下载 `/<model>/resolve/<revision>/tokenizer.json`，支持 redirect、自定义 endpoint/mirror/cache、HF/tokenizers 风格请求 headers、显式 token / `$HF_TOKEN` / `$HF_TOKEN_PATH` / `$HF_HOME/token`、`HF_ENDPOINT`、`HF_HUB_OFFLINE` 与 `local_files_only`；离线解析错误会区分文件缺失、目录缺 tokenizer 与 Hub cache 未命中，并补 negative tests / cache eviction bench |
| P3 | batch 并行 / word cache | ✅ | BPE/WordPiece/Unigram word cache 已完成；encode_batch / encode_pair_batch / pre-tokenized batch / pre-tokenized pair batch 对重复输入做单批缓存并补 bench，pair batch 支持 BatchLongest padding 与 byte offsets；公开 `PaddingParams::fixed` / `batch_longest` / `with_*` builder 覆盖 left/right、pad_type_id、pad_to_multiple_of；已提供 raw/pair/pre-tokenized/pre-tokenized-pair 的 `*_parallel(_fast)` 兼容入口并补等价测试。MoonBit 有 async/structured concurrency，但当前不提供适合 CPU-bound tokenizer 批处理的稳定跨 target 多核 worker 调度；真实多线程并行不作为当前 wasm/js 边缘端核心验收目标 |
| P4 | trainer / training API | ✅ | 已提供确定性 WordLevel trainer（WhitespaceSplit / 自定义 pre-tokenizer / 预切分 token 流 + min_frequency + special tokens + vocab_size + HF 风格频次/词典序排序）；新增确定性 WordPiece / BPE / Unigram trainer MVP（同输入模式 + continuation prefix / end_of_word_suffix / max_input_chars_per_word / byte_fallback + vocab_size），其中 WordPiece/BPE trainer 已支持 HF 风格 `initial_alphabet` / `limit_alphabet`，WordPiece 训练和 encode 均支持 `end_of_word_suffix`，WordPiece/BPE 均支持 `max_token_length`，并通过 `byte_level_alphabet()` 覆盖 ByteLevel 256-byte alphabet；训练结果可 `to_json`/`save` 往返，常见 pre-tokenizer 可序列化，并加入 HF trainer bench；高级训练算法与采样参数后续按需增强 |

### Benchmark 对比要求

性能结论必须基于 `scripts/bench_compare.py` 的同机对比结果，而不是单独的
`moon bench` 输出。脚本会对 encode / explicit byte offsets / decode /
encode_batch / encode_pair_batch / pre-tokenized encode+batch（含 added-token 抽取合成用例）/ tokenizer builder+add_tokens / typed tokenizer to_json / explicit post_process / decode_batch / decode_stream / from_str / local from_pretrained / to_json / save_pretrained / common Split-Replace regex fast paths（含 ranged `{2,4}` 量词）输出
MoonBit µs/op、HF `tokenizers` µs/op、Moon/HF 比值。`Moon/HF > 1.10x` 的项目
应进入优化排期；`< 0.90x` 才能明确宣称本项目在该用例快于 HF。

默认 benchmark 对比覆盖 `scripts/bench_python.py` 中的完整模型 fixture 矩阵；
`--quick` 仅用于本地冒烟，正式性能结论必须跑 `--corpus all` 或至少全模型
`mixed` 矩阵。`bench_compare.py` 已提供 `--fail-above <ratio>` 用于 CI/nightly 性能
门禁（超过阈值时非 0 退出），并提供 `--json-out <path>` 输出 rows、skipped HF baselines、optimization focus 与 failures 的结构化报告，便于 artifact / 趋势看板收集。若 Python `tokenizers` wheel 对 pre-tokenized 输入需要 NumPy 而本机未安装，
`bench_compare.py` 会把对应 HF baseline 记入 `Skipped HF baselines` 并继续输出其它比值，避免整轮对比中断。最近一次全模型抽样（native / mixed，BPE word cache 后）：BPE/
WordPiece/CLIP 主线大多快于 HF（gpt2 0.43x、llama 0.28x、Qwen2.5 0.58x、
bert 0.53x、clip 0.48x）；decode 多数约 0.5x 或同水平；加载大模型基本同
水平。WordPiece decoder cleanup 单遍化后，quick native 抽样 bert decode 从慢于 HF 转为约 0.13x，
`decoder-wordpiece-cleanup` micro bench 约 0.10x；Decoder Replace 对 punctuation/symbol
bounded/ranged 量词先走直接分发后，`decoder-replace-ranged-quantifier-regex` micro bench
由慢于 HF（约 4.5x）转为快于 HF（约 0.5x），并把 bounded punctuation/symbol 量词纳入 HF 对比行。
Normalizer Replace 也补上共享 ranged run direct helper，`normalizer-replace-ranged-regex`
由同档（约 1.0x）改善到约 0.6x。
Unigram word cache 后，t5 encode 0.39x、bge_m3 0.42x、e5_multilingual
0.43x，已由主要性能短板转为快于 HF。Dense vocab reverse map 后，加载
抽样改善明显（bert/Qwen2.5/phi4/qwen3_coder from_str 已达到同档或快于 HF，
llama from_str 仍约 1.14x）。Legacy BPE merges 解析改为 code-unit 扫描、
vocab reverse array 预分配后，大 BPE tokenizer 加载路径减少 StringBuilder 与
Array 增长分配；`from_pretrained` 增加单项 source cache 后，完整 native
`--corpus all` 复测已无 `>1.10x` 慢项：主流 encode 在 short/mixed/code/long
均快于 HF（约 0.25x–0.68x）；decode 同档或快于 HF，decode_batch 增加重复 id
序列单批缓存后 quick native 抽样进一步改善；SentencePiece decoder sequence 增加融合快路径后
llama decode quick native 约 0.17x；from_str
增加多项 parsed-JSON cache 后，quick native 抽样加载路径已明显快于 HF（gpt2
0.45x、bert 0.30x、llama 0.61x、Qwen2.5 0.39x、phi4-mini 0.31x、qwen3-coder
0.37x；local from_pretrained-file 约 0.28x–0.63x）。`post_process` 显式 API 加入
HF 对比后 quick native 约 0.09x；`decode_stream` 增量解码 quick native 约
0.44x–0.76x。下一轮性能优化优先级：大词表 JSON 冷加载解析与更长期的 nightly 趋势落盘。

## 已知缺口与取舍（TODO）

1. **正则**：core 正则不提供完整通用 Unicode regex 引擎；GPT/Qwen/o200k 主线已手写扫描器。通用 Split 已补 literal、escaped-literal alternation（`^foo$`、`\\bfoo\\b`、`foo|bar`、`(foo)` / `(?:foo)`、`(?:foo|bar)`、`^(?:foo|bar)`、`(?:foo|bar)$`、`\\b(?:foo|bar)\\b`、`^\\b(?:foo|bar)\\b$` 等）、` {2,}`、`^\\s+`、`\\s+`、`\\S+`、`\\s+$`、whitespace/newline/horizontal whitespace 的 `{2,}` / `{3,}` / `{4}` 与 `{2}` / `{3}` / `{4}`、digit/word/ASCII/Unicode letter/punctuation/symbol/union positive 与 inverse runs、anchored `^...+` / `...+$`、`{1,2}` / `{1,3}` / `{1,4}` bounded families、`{2,3}` / `{2,4}` / `{3,4}` ranged families、`[^\\s\\p{L}\\p{N}]+` 与 bounded/ranged 反集 runs；复杂未知 pattern 加载期显式 Unsupported，避免静默不对齐。Replace normalizer/decoder 现在复用同一个 `common.simple_split_regex_matches` span scanner，因此上述简单 regex family 在 Split/Normalizer/Decoder 间保持同步；Decoder Replace 对这些 simple regex 走直接 decode fast path，不再落到通用 decode_chain。更复杂 Replace pattern 仍按字面量处理。
2. **训练 / Hub 集成**：当前定位 inference-first；`to_json`/`save` 已支持原始 JSON 往返，`from_pretrained` 已支持本地目录/文件、已有 HF Hub cache snapshot 与稳定路径小型多项 source cache，并通过可选 native/js `hub` 包支持在线下载 `tokenizer.json` 后写入标准 cache；WordLevel trainer 产物已支持序列化保存，并支持自定义 pre-tokenizer / 预切分 token 流 / vocab_size / HF 风格频次与词典序排序；WordPiece / BPE / Unigram trainer MVP 已支持相同输入模式、continuation prefix / end-of-word suffix、`max_input_chars_per_word`、`byte_fallback` 与 `vocab_size`，常见 pre-tokenizer 可序列化。高级训练算法与采样参数后续按需增强。
3. **性能**：BPE merge 已用优先队列(pairing heap)+惰性失效，llama 提速约 7x、与 Rust 同量级；BPE/WordPiece/Unigram word cache 与 tokenizer source cache 已完成，后续重点转向 cache 容量/淘汰策略、冷启动大词表解析与长期 benchmark 趋势落盘。
4. **batch 并行策略**：MoonBit 当前已有 async/structured concurrency，但官方 `moonbitlang/async` 文档说明其任务模型是 single-threaded cooperative multitasking，用户代码只能使用一个硬件处理器；因此它不能直接给 CPU-bound tokenizer encode_batch 提供跨 target 多核并行。项目已提供保持顺序稳定的 `*_parallel(_fast)` 兼容入口，内部委托串行批处理 + 批内重复输入缓存，BPE/WordPiece/Unigram 均带 word cache（场景定位 wasm/js 边缘端）。未来 target runtime 提供稳定 worker 调度时可替换内部实现，不改变公开 API。
5. **Unigram 采样**：HF Unigram 支持 `alpha`（采样温度）和 `nbest_size`（N-best 路径数）推理参数，用于从 lattice 中采样而非确定性 Viterbi。MoonBit 已补齐 JSON 解析/序列化、getter/setter alias 和两种采样算法：`alpha > 0` 且 `nbest_size > 0` 时使用 beam search 枚举 N-best 路径采样（SentencePiece 模式）；`nbest_size` 未设置时使用前向-后向算法对完整分布采样。当前使用确定性种子保证可复现性，后续可替换为真随机。

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

### 2026-07-11 小闭环：API 文档补齐（训练 API / Python pickle 别名）

- 补齐训练 API 文档：
  - Tokenizer 级别：`train` / `train_from_iterator` / `train_from_files`。
  - 便捷训练辅助：`train_wordlevel` / `train_wordpiece` / `train_bpe` / `train_unigram`（含 `*_with_pretokenizer` 和 `*_from_tokens` 变体）。
  - 独立模型训练：`Model::train_wordlevel` / `Model::train_wordpiece` / `Model::train_bpe` / `Model::train_unigram`（含 `*_from_tokens` 变体）。
- 补齐 Python pickle 兼容别名文档：`Tokenizer::__getstate__` / `__setstate__`。
- 中英文文档同步更新。

### 2026-07-11 小闭环：Encoding Python binding setter 别名

- 补齐 Encoding 类型的 Python binding 兼容 setter 别名：
  - `set_type_ids` → 委托给 `with_type_ids`
  - `set_special_tokens_mask` → 委托给 `with_special_tokens_mask`
  - `set_attention_mask` → 委托给 `with_attention_mask`
  - `set_word_ids` → 委托给 `with_word_ids`
  - `set_overflowing` → 委托给 `with_overflowing`
- 添加对应测试（385 个测试，从 384 增加到 385）。
- 中英文文档同步更新。

### 2026-07-11 小闭环：AddedToken Python binding setter 别名

- 补齐 AddedToken 类型的 Python binding 兼容 setter 别名：
  - `set_single_word` / `set_single_word_alias` → 委托给 `with_single_word`
  - `set_lstrip` / `set_lstrip_alias` → 委托给 `with_lstrip`
  - `set_rstrip` / `set_rstrip_alias` → 委托给 `with_rstrip`
  - `set_normalized` / `set_normalized_alias` → 委托给 `with_normalized`
- 添加对应测试（386 个测试，从 385 增加到 386）。
- 中英文文档同步更新。

### 2026-07-11 小闭环：Unicode 字母脚本覆盖扩展

- 扩展 `is_unicode_letter` 函数，新增 15 个 Unicode 字母范围：
  - Ethiopic（阿姆哈拉语/提格里尼亚语）+ Supplement
  - Cherokee（切罗基语）
  - Canadian Aboriginal Syllabics（加拿大原住民音节文字）
  - Ogham（古爱尔兰语）和 Runic（古北欧语/日耳曼语）
  - Latin Extended Additional（越南语等）
  - Greek Extended
  - CJK Extension B、Extension C/D、CJK Compatibility Ideographs
  - Hangul Jamo（韩文辅音/元音）+ Extended-A/B
- 全后端测试通过：native(386)/js(386)。
- 中英文文档同步更新 Unicode 脚本覆盖列表。

### 2026-07-11 小闭环：Encoding 编程构造 API 与编码/解码别名文档

- 补齐 Encoding 类型的编程构造 API：
  - `with_ids` / `set_ids` → 更新 token ids（带长度校验）
  - `with_tokens` / `set_tokens` → 更新 token 字符串（带长度校验）
  - `with_offsets` / `set_offsets` → 更新 offsets（带长度校验）
- 补齐编码/解码 API 文档：
  - `encode_plus` / `batch_encode_plus` → HF 风格统一编码 API
  - `decode_ids` / `batch_decode` → 解码 API 别名
  - `async_encode` / `async_encode_batch` / `async_decode` / `async_decode_batch` → async 兼容别名
- 添加对应测试（387 个测试，从 386 增加到 387）。
- 中英文文档同步更新。

### 2026-07-11 小闭环：EncodeInput 类型文档补齐

- 补齐 `EncodeInput` 和 `TextInputSequence` 类型文档：
  - `EncodeInput` 枚举（`SingleInput` / `PairInput`）及其构造别名
  - `TextInputSequence` 枚举（`Text` / `PreTokenized`）及其辅助方法
  - 说明统一编码输入类型用于 `encode_input`、`encode_plus`、`batch_encode_plus` 等
- 中英文文档同步更新。

### 2026-07-11 小闭环：NormalizedString / PreTokenizedString API 签名文档

- 补齐 `NormalizedString` 完整 API 签名文档（31 个方法）：
  - 构造：`new` / `from_state` / `from_tuple` / `as_tuple`
  - 字符串访问：`get` / `normalized` / `original` / `to_string` / `len` / `is_empty`
  - 归一化：`normalize`
  - 变换：`clear` / `lowercase` / `uppercase` / `lstrip` / `rstrip` / `strip`
  - Unicode 归一化：`nfc` / `nfd` / `nfkc` / `nfkd`
  - 操作：`replace` / `prepend` / `append` / `slice` / `filter` / `map` / `for_each`
  - 分词：`split` / `split_regex`
- 补齐 `PreTokenizedString` 完整 API 签名文档（16 个方法）：
  - 构造：`new` / `from_splits` / `from_state` / `from_tuple` / `as_tuple`
  - 访问：`original` / `len` / `is_empty` / `splits` / `get_item`
  - 操作：`normalize` / `split`
  - 编码转换：`to_encoding` / `into_encoding`
- 中英文文档同步更新。

### 2026-07-11 小闭环：模块化重构 + 版本升级 0.2.0

**模块化拆分**（无功能变更，全后端验证通过）：

- `trainer.mbt`（3177 行）拆分为：
  - `trainer.mbt`（614 行）- enum + state + builders + getters
  - `trainer_setters.mbt`（1522 行）- setter methods + aliases
  - `trainer_state.mbt`（116 行）- state serialization
  - `trainer_training.mbt`（923 行）- tokenizer training methods
- `tokenizer.mbt`（2241 行）拆分为：
  - `tokenizer.mbt`（1659 行）- Tokenizer struct + methods
  - `normalized_string.mbt`（363 行）- NormalizedString type
  - `pretokenized_string.mbt`（219 行）- PreTokenizedString type
- `types.mbt`（1552 行）拆分为：
  - `encoding.mbt`（1199 行）- Encoding struct + methods
  - `token_split.mbt`（217 行）- Token + Split types
  - `errors.mbt`（136 行）- TokenizerError type

**版本升级**：0.1.0 → 0.2.0

**测试验证**：387/387 native, 387/387 js, 364/364 wasm, 364/364 wasm-gc

### 2026-07-11 小闭环：moon publish 0.2.0

- `moon publish` 成功发布 `howtomakeaname/tokenizers-moonbit@0.2.0`
- Server status: 200 OK
- 版本包含：模块化重构 + API 文档完善 + Unicode 扩展 + Python binding 别名

### 2026-07-12 小闭环：Hub 缓存类型文档补齐

- 补齐 Hub 缓存类型文档：
  - `PretrainedCacheMetadata`：缓存路径、revision、ETag + `cache_exists` / `etag_matches` / `is_fresh` 方法
  - `PretrainedCachePaths`：HF Hub 缓存布局具体路径
  - `PretrainedDownloadResumeMetadata`：中断下载跟踪
  - `PretrainedResolutionHint`：离线解析失败诊断信息
  - `from_pretrained_cache_metadata` / `from_pretrained_cache_paths` / `from_pretrained_resolution_hint` 函数
- 中英文文档同步更新。

### 2026-07-12 小闭环：Hub 协议类型文档补齐

- 补齐 Hub 协议类型文档：
  - `HubTransferAction` 枚举（UseCached/Replace/AppendRange/Retry/Reject）
  - `HubRequestPlan` 结构体（确定性请求规划）
  - `HubResponseMetadata` 结构体（HEAD/GET 响应解析）
  - `HubResponseDecision` 结构体（action + 诊断信息）
  - `HubHeadResult` 结构体（HEAD 预检结果）
  - `hub_http_status_diagnostic` / `tokenizer_json_url` / `hub_file_url` 函数
  - `plan_tokenizer_json_request` / `plan_hub_file_request` / `head_tokenizer_json_request` 函数
  - `decide_tokenizer_json_response` / `decide_tokenizer_json_head_response` 函数
- 中英文文档同步更新。

### 2026-07-12 小闭环：byte-offset 编码变体文档补齐

- 补齐 byte-offset 编码变体文档（8 个函数）：
  - `encode_with_byte_offsets` / `encode_pair_with_byte_offsets`
  - `encode_batch_with_byte_offsets` / `encode_pair_batch_with_byte_offsets`
  - `encode_pretokenized_with_byte_offsets` / `encode_pretokenized_pair_with_byte_offsets`
  - `encode_pretokenized_batch_with_byte_offsets` / `encode_pretokenized_pair_batch_with_byte_offsets`
- 说明 UTF-8 byte offset 语义和预分词输入行为。
- 中英文文档同步更新。

### 2026-07-12 小闭环：Token 与 Split 类型文档补齐

- 补齐 Token 类型文档：
  - 结构体定义（id / value / offsets）
  - 构造方法：`new` / `from_tuple` / `from_state`
  - 访问器：`id` / `value` / `offsets`（属性风格别名）
  - 互操作：`as_tuple` / `get_state` / `__getstate__` / `__setstate__`
  - 显示：`__str__` / `__repr__`
- 补齐 Split 类型文档：
  - 结构体定义（value / offsets）
  - 构造方法：`new` / `from_tuple` / `from_state`
  - 访问器：`value` / `offsets`（属性风格别名）
  - 互操作：`as_tuple` / `get_state` / `__getstate__` / `__setstate__`
  - 显示：`__str__` / `__repr__`
- 中英文文档同步更新。

### 2026-07-12 小闭环：AddedToken/TruncationParams/PaddingParams 访问器文档补齐

- 补齐 AddedToken 访问器文档：
  - 属性风格 getter：`content` / `single_word` / `lstrip` / `rstrip` / `normalized` / `is_special`
  - 互操作：`from_tuple` / `as_tuple` / `from_state` / `get_state` / `__getstate__` / `__setstate__`
  - 显示：`__str__` / `__repr__`
  - setter 别名：`set_special` / `set_special_alias`
- 补齐 TruncationParams 访问器文档：
  - 互操作：`from_state` / `from_tuple` / `as_tuple` / `get_state` / `__getstate__` / `__setstate__`
  - getter：`max_length` / `stride` / `direction` / `strategy` + `get_*` 别名
- 补齐 PaddingParams 访问器文档：
  - 互操作：`from_state` / `from_tuple` / `as_tuple` / `get_state` / `__getstate__` / `__setstate__`
  - getter：`strategy` / `direction` / `pad_id` / `pad_type_id` / `pad_token` / `pad_to_multiple_of` + `get_*` 别名
- 中英文文档同步更新。
