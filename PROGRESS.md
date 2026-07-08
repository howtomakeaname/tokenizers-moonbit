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
| R11 | HF tokenizers 全量兼容缺口收敛（低频 API / 高级训练 / 正则与并行） | 🚧 排期中（`encode_fast`、迁移序列化 API、缓存控制 API、BPE dropout、模型文件级保存、HF config alias、EncodeInput、Token/Regex/Encoding/Tokenizer state API、Tokenizer train pipeline MVP、高级 trainer knobs 与 Trainer state、Hub sidecar/metadata/离线校验/诊断 hint/ref/resume 元数据/条件请求计划/响应决策/HEAD 预检/流式落盘、batch parallel 兼容入口、NormalizedString/PreTokenizedString 低层 API 与 binding alias、async 兼容入口、regex literal 策略、错误分类 helper、Python binding alias 第二十五批已完成） |

## R11：对齐 HuggingFace tokenizers 的剩余缺口排期（2026-06-12 复评）

目标：在当前 39 个真实 tokenizer.json 逐 id parity 的基础上，继续从「主流推理无缝迁移」推进到「HF tokenizers 公共 API 与低频组件行为尽量完整兼容」。排序原则：先补会影响真实模型加载/推理正确性的 P0/P1，再补迁移便利 API，最后补训练/扩展/并行等高级能力。每项必须包含：HF 行为对拍、MoonBit 全 target 测试、`moon check` 无 warning；涉及热路径的改动必须跑 `scripts/bench_compare.py --quick --target native`，不得让相关项退化到 `Moon/HF > 1.10x`。

本轮复评结论：主流推理链路（load tokenizer.json / added tokens / normalizer / pre-tokenizer / model / post-processor / decoder / truncation / padding / offsets / pair / batch / pretokenized / save / local+online hub）已经基本可迁移；剩余缺口主要集中在训练生态完整 EM/大语料对拍、Hub 文件族/错误映射、以及 Python 绑定长尾别名。Regex 当前采用“HF 常见 deterministic subset + 复杂 pattern 显式 unsupported”的完成策略，不把 full backtracking/通用 Unicode regex 引擎作为跨 target 核心目标。

| 优先级 | 缺口 | 当前状态 | 验收标准 | 建议排期 |
|---|---|---|---|---|
| P0 | `NormalizedString` / `PreTokenizedString` 低层 API 暴露 | ✅ 已完成 | 已提供 HF 同名概念的最小公共类型：原文/归一化文本、`len`/`__len__`/`is_empty`、`get`/`normalized`/`to_string`、`get_original`/`original`、state/tuple 往返、normalize、replace、prepend/append、clear、lowercase/uppercase、lstrip/rstrip/strip、nfc/nfd/nfkc/nfkd、slice、map/filter、literal/Regex split、`get_splits`/`splits`、pre-tokenizer 二次 split 与 `to_encoding`/`into_encoding`；覆盖自定义 normalizer/pre-tokenizer 与 Python binding 低层迁移场景，完整可变 offset hook 后续按需扩展 | 1 周 |
| P0 | Regex 兼容策略 | ✅ 已完成 | 现有 deterministic regex family 保持 fast path；已补 regex=true 的 literal/escaped-literal 安全策略，并进一步覆盖 `^foo$`、`\\bfoo\\b`、`foo|bar`、`(foo)` / `(?:foo)`、`(foo|bar)` / `(?:foo|bar)`、`foo|a\\.b`、`^(?:foo|bar)` / `(?:foo|bar)$` 以及 `\\b(?:foo|bar)\\b` / `^\\b(?:foo|bar)\\b$` 这类每个分支都是普通或 escaped literal 的简单 literal/alternation，并把 HF SentencePiece 常用 ` {2,}` 纳入共享 scanner；`Regex::is_supported/find_matches/replace_all` 对复杂 pattern 显式返回 `None`，未知复杂 Split regex 在 tokenizer.json 加载期抛 `UnsupportedComponent`，避免静默错配；full backtracking/通用 Unicode regex 引擎不属于当前跨 target 核心目标 | 1–2 周 |
| P0 | BPE `dropout` encode 语义 | ✅ 已完成 | 已解析/序列化 `model.dropout`；`None/0` 继续走确定性 fast path 与 word cache，`>0` 禁用 word cache 并按 dropout 概率跳过可用 merge，`1.0` 覆盖全跳过边界；新增单测覆盖序列化、缓存禁用与确定性路径不退化 | 0.5–1 周 |
| P1 | 训练 API 完整化：`Tokenizer.train` / `train_from_iterator` / 文件训练 | ✅ pipeline MVP 已完成 | 已新增 `Trainer::{wordlevel,wordpiece,bpe,unigram}` 配置与 `Tokenizer::train` / `train_from_iterator` / `train_from_files`；训练前应用 added-vocab extraction、normalizer、pre-tokenizer，训练完成后写回 model 并将已有 special added tokens 重新映射到新 model ids；已补 iterator 与文件训练单测。后续高级 trainer knobs 继续归入下一项 | 1–2 周 |
| P1 | 高级 trainer 参数补齐 | 🚧 第十批完成 | 已补 `show_progress` 兼容参数（当前保持 no-op 以跨 target 稳定）、`special_added_tokens` AddedToken 元数据保真、BPE continuing/end suffix 训练入口覆盖、WordPiece model/trainer `end_of_word_suffix`（加载、encode、训练、序列化往返）与 `max_token_length`（限制训练阶段产生过长整词 token）、Unigram `unk_piece` alias、`max_piece_length` 子词候选限制；`shrinking_factor` / `n_sub_iterations` 已从 tokenizer trainer 透传到 model trainer，并新增 deterministic Unigram candidate ranking + shrinking prune 近似：先按 EM-like score/frequency/长度/字典序合并排序 whole-word 与 subpiece 候选，再按 shrinking 轮次裁剪后应用 vocab cap，避免高频整词被低分子串挤出；第四批补充 Trainer 配置 getter/property-style alias（通用字段与 WordPiece/BPE/Unigram 特有 knobs 均返回副本或 Option），便于 Python binding 暴露 trainer 属性；第五批补充 `TrainerState` 与 `get_state` / `from_state` / `__getstate__` / `__setstate__`、`__str__` / `__repr__`，保留 typed trainer 配置和 `AddedToken` 元数据，未知 trainer kind 显式报 unsupported；第六批补充 Unigram `initial_alphabet` 参数，从 tokenizer trainer 透传到 model trainer，按 HF 语义对多字符条目只取首字符，并在 vocab cap 下作为 required alphabet 先于语料候选加入；第七批修正 BPE `continuing_subword_prefix` merge surface，训练和 encode 阶段合并右侧 subword 时都会先去掉 continuation prefix，避免生成 `a@@b` 这类非 HF token；第八批修正 BPE/WordPiece `initial_alphabet` 与 `limit_alphabet` 交互，initial alphabet 进入同一 alphabet 候选池并优先保留，但总 alphabet 数仍受 limit 约束；第九批对齐 Unigram `unk_token` 插入位置：当 unk 未显式列入 special_tokens 时先插入 unk，当 special_tokens 中已包含 unk 时保留列表顺序；第十批补充 BPE `progress_format` 配置/state 兼容，保存 `"indicatif"` / `"json"` / `"silent"`，未知值按 HF Python setter 语义回落 `"indicatif"`，真实 progress 输出仍保持跨 target no-op；已补 tokenizer/model trainer 单测。后续继续做大语料与 HF trainer 对拍，收敛完整 EM loss 细节 | 2 周 |
| P1 | 模型文件级保存 API | ✅ 已完成 | 已新增 `Model::save(folder, prefix)` 与 `Tokenizer::save_model(folder, prefix)`；BPE 写 `vocab.json`+`merges.txt`，WordPiece 写 `vocab.txt`，WordLevel 写 `vocab.json`，Unigram 写 score-preserving `unigram.json`；`save_pretrained(..., save_model=true, model_prefix=...)` 可同步辅助 artifacts；已补文件内容单测 | 0.5–1 周 |
| P1 | HF mutating/config API 别名 | ✅ 已完成 | 已在现有 `with_truncation` / `with_padding` 基础上补 `enable_truncation` / `no_truncation` / `enable_padding` / `no_padding`，并补 `enable_encode_special_tokens` / `disable_encode_special_tokens` alias；语义保持 builder/mutating 链式风格；已补迁移 API 单测 | 0.5 周 |
| P1 | `encode_fast` / `encode_batch_fast` 无 offsets 快路径 | ✅ 已完成 | 已新增 single/pair/batch/pretokenized 全 fast API 族；ids/tokens/masks/type_ids/sequence_ids/word_ids 与普通 encode 一致，offsets 统一置零；已加入单测与 benchmark 对比 | 0.5 周 |
| P1 | BPE / Unigram cache 控制 API | ✅ 已完成 | 已暴露 `Tokenizer::clear_cache` / `resize_cache` / `cache_size`，覆盖 BPE / WordPiece / Unigram 内部 word cache；验证 from_str 后缓存隔离、`capacity=0` 禁用缓存、默认性能路径保持不变 | 0.5 周 |
| P1 | `Tokenizer.from_buffer` / `to_str(pretty)` / `save(pretty)` 迁移 API | ✅ 已完成 | 已支持 UTF-8 `Bytes` buffer 加载；`to_str(pretty)` / `save(pretty)` / `save_pretrained(pretty)` 支持 minified/verbatim 与两空格 pretty 输出；已加载 JSON 默认 round-trip 仍保真 | 0.5 周 |
| P2 | `Token` / `Regex` / component trait 扩展点 | ✅ 已完成 | 已提供低层 `Token::new` / `from_tuple` / `as_tuple` / getters；新增 `EncodingState` / `Encoding::get_state` / `__getstate__` / `__setstate__`，方便 Python binding/pickle/state 互操作；新增 `Regex::new` / `pattern` / `is_supported` / `find_matches` / `replace_all`，显式暴露 deterministic regex subset 能力边界，未知复杂 pattern 返回 `None`；新增 `TokenizerComponentHooks` 与 `encode_with_hooks` / `encode_with_hooks_fast` / `decode_with_hooks`，允许 Python/FFI 层按调用注入自定义 normalize / pre_tokenize / decode 回调；新增 `Tokenizer::with_component_hooks` / `clear_component_hooks` / `get_component_hooks` / `component_hooks`，让 runtime hook 可作为 tokenizer 级轻量组件参与普通 `encode` / `encode_fast` / `decode` 路径，per-call hooks 会覆盖持久 hook；callback 不写入 tokenizer JSON/state 是有意设计，用来保持 HF JSON/state round-trip 稳定，序列化组件仍应使用 typed normalizer/pre-tokenizer/decoder | 1 周 |
| P2 | async encode/decode batch API | ✅ 兼容入口已完成 | 已提供 `async_encode` / `async_encode_fast` / `async_encode_batch` / `async_encode_batch_fast` / `async_decode` / `async_decode_batch` 兼容入口，语义与同步 API 一致；实现保持同步以覆盖 native/js/wasm/wasm-gc，后续若 MoonBit async runtime 稳定再替换内部调度 | 0.5–1 周 |
| P2 | batch 并行 | ✅ 兼容入口已完成；真实并行暂缓 | MoonBit 当前缺少稳定跨 target worker runtime，已新增 `encode_batch_parallel(_fast)` / pair / pretokenized / pretokenized-pair parallel 兼容入口，委托现有串行批处理 + 批内缓存，保证顺序稳定与全后端一致；若后续运行时支持再替换内部实现 | 1–2 周（取决于运行时） |
| P2 | EncodeInput / TextInputSequence 统一输入类型 | ✅ 已完成 | 已新增 `TextInputSequence::{text,pretokenized}`、`EncodeInput::{single,single_pretokenized,pair,pair_pretokenized,mixed_pair}` 与 `encode_input` / `encode_input_fast` / `encode_input_batch` / `encode_input_batch_fast`；覆盖 raw、pretokenized、mixed pair、batch duplicate cache 与 fast offsets 置零；现有显式 API 保持兼容 | 0.5–1 周 |
| P3 | 完整 Hub 生态 | 🚧 tokenizer.json 下载 + sidecar/metadata/离线校验/诊断/ref/resume/条件请求与响应决策已接入下载路径，HEAD 预检与真实流式落盘已完成 | 已补 `PretrainedAuxFiles` 与 `from_pretrained_aux_files`，可按本地目录/文件/Hub cache snapshot 读取 `tokenizer_config.json` / `special_tokens_map.json`；`from_pretrained_downloaded` 可同步写入两个 sidecar 与 `tokenizer.json.etag`，新增 `PretrainedCacheMetadata` / `from_pretrained_cache_metadata` 返回 tokenizer/sidecar 路径、revision、resolved revision、etag，并提供 `cache_exists` / `etag_matches` / `is_fresh` 与 tokenizer 级 helper 做离线 freshness 校验；新增 `PretrainedResolutionHint` / `from_pretrained_resolution_hint`，缺失 cache/snapshot/tokenizer.json 时输出含 private/gated repo 指引的可诊断消息；新增 `PretrainedCachePaths`、ref 读取/写入 helper、`PretrainedDownloadResumeMetadata` 读写/清理 helper，并在 hub 下载结果中透传 ETag；新增 `HubRequestPlan` / `HubResponseMetadata`，可生成 `If-None-Match` / `Range` / `If-Range` 请求计划并解析 HEAD/GET 响应元数据；新增 `HubTransferAction` / `HubResponseDecision`、`decide_tokenizer_json_response` 与 `apply_tokenizer_json_response`，覆盖 304 复用缓存、200 覆盖缓存、206 匹配 resume 后拼接 `.incomplete` 并清理 sidecar、416/不匹配 Range 触发无 Range 重试建议；新增 `apply_tokenizer_json_download_result` 并将 `download_tokenizer_json` 的真实 GET 路径接入 304/206 决策，Range 不匹配/416 会自动去掉 Range/If-Range 重试一次；新增 `head_tokenizer_json_request` / `decide_tokenizer_json_head_response` / `head_tokenizer_json` / `HubHeadResult`，真实 HEAD 路径跟随重定向且不读取 body，`from_pretrained` 在缓存命中时用 HEAD 校验 304 或 revision/ETag 一致后复用缓存，HEAD 不可用时保留离线缓存兼容；新增 `apply_tokenizer_json_download_chunks`（宿主 text chunk）与 `apply_tokenizer_json_download_bytes`（真实 HTTP byte chunk），按 chunk 写入 `tokenizer.json.incomplete` 并持续刷新 byte-accurate resume sidecar，支持 200 全量与 206 续传完成后清理临时文件；真实 `download_tokenizer_json` 已从一次性 `http.get(...).read_all()` 切换为 `http.get_stream` + `read_some(max_len=stream_chunk_size)`，网络层以 byte chunks 交给同一决策 helper，避免 UTF-8 多字节字符跨 chunk 时被 `decode_lossy` 破坏，并新增非 ASCII split chunk 测试；新增 `HubDownloadOptions::stream_chunk_size` / `with_stream_chunk_size` 控制刷新粒度；本地 correctness pack 补齐 HTTP header 大小写无关解析、`Content-Range` 起点校验防止 206 错位 append、slash revision/ref 嵌套目录写入，以及 HF 风格 model id/revision 字符与路径段校验，且不误伤本地文件/目录 `from_pretrained`；新增 401/403/404/429/5xx 本地 HTTP status 诊断 helper 并接入 GET/HEAD reject message。后续继续补更完整的 Hub 文件族和错误映射；保持请求 header 与 HF 兼容，不引入非 HF 标识 | 1–2 周 |
| P3 | Python binding 兼容层 / 命名别名 | 🚧 state/命名别名/错误分类第二十七批已完成 | 已提供 `Tokenizer::to_str(pretty)` / `save(pretty)` 命名 alias、`Encoding::__getstate__` / `__setstate__`、`TokenizerState` / `Tokenizer::get_state` / `from_state` / `__getstate__` / `__setstate__`，覆盖 Python pickle/state 与 JSON 状态迁移；新增 `EncodingBuffers` / `Encoding::from_buffers` / `get_buffers` / `as_buffers` / `__len__` / `get_n_sequences`、`TokenState` / `Token::__getstate__` / `__setstate__`、`TokenizerErrorKind` / `TokenizerError::kind` / `message`，方便 Python binding 做 buffer/tuple/state 与异常类型映射；新增 `Tokenizer::vocab_size` / `vocab` 属性式别名，以及 `encode_text(_fast)` / `encode_text_batch(_fast)` / `encode_plus(_fast)` / `decode_ids` / `batch_decode` / `decode_ids_batch` 兼容别名；新增 `Tokenizer::normalizer` / `pre_tokenizer` / `model` / `post_processor` / `decoder` / `truncation` / `padding` / `encode_special_tokens` / `added_tokens_decoder` 属性式访问 alias，并为 `TruncationParams` / `PaddingParams` 补齐字段 getter 与同名 property-style alias；第五批补充 `get_added_tokens` / `added_tokens` / `get_added_tokens_count` / `added_tokens_count`、`all_special_tokens` / `all_special_ids`、`convert_token_to_id` / `convert_id_to_token` / `convert_tokens_to_ids` / `convert_ids_to_tokens`；第六批补充 typed `encode_sequence_input(_fast)` 与 `batch_encode_plus(_fast)`，以 `TextInputSequence`/`EncodeInput` 覆盖 Python `sequence` + optional `pair` 与 batch encode plus 形态；第七批补充 `AddedToken` 的 `get_content` / `content`、`get_single_word` / `single_word`、`get_lstrip` / `lstrip`、`get_rstrip` / `rstrip`、`get_normalized` / `normalized`、`get_special` / `is_special`，以及 `Token::id` / `value` / `offsets` 属性式别名；第八批补充 `Encoding::ids` / `type_ids` / `tokens` / `offsets` / `special_tokens_mask` / `attention_mask` / `overflowing` 属性式数组访问 alias；第九批补充 `Encoding::set_sequence_id` 迁移 alias；第十批补充 `AddedTokenState` / `AddedToken::get_state` / `from_state` / `__getstate__` / `__setstate__` / `as_tuple` / `from_tuple`，覆盖 added token pickle/state/tuple 互操作；第十一批补充 `TruncationParamsState` / `PaddingParamsState` 及两类 params 的 `get_state` / `from_state` / `__getstate__` / `__setstate__` / `as_tuple` / `from_tuple`，覆盖配置对象 pickle/state/tuple 互操作；第十二批补充 `Encoding::as_tuple` / `from_tuple` 全量 positional buffer 互操作，以及 `get_token_sequence` / `get_token_chars` / `token_to_offsets` / `get_token_word` / `get_word_tokens` / `get_word_chars` / `word_to_offsets` / `get_char_token` / `get_char_word` 映射别名，覆盖 Python binding 对 token/word/char offset mapping 的命名迁移；第十三批补充 `NormalizedStringState` / `PreTokenizedStringState` / `SplitState` 与对应 `get_state` / `from_state` / `__getstate__` / `__setstate__` / `as_tuple` / `from_tuple`，并为 `NormalizedString::get_normalized`、`Split::{new,get_value,value,get_offsets,offsets}` 补齐低层 normalizer/pre-tokenizer binding 互操作；第十四批补充 `NormalizedString::{append,clear,lowercase,uppercase,lstrip,rstrip,strip,nfc,nfd,nfkc,nfkd}`，覆盖 HF 低层 normalized string mutating helper 的不可变链式迁移形态；第十五批补充 deprecated `Encoding::words()` 属性别名，映射到 `word_ids()`；第十六批补充 `Tokenizer::__str__()` / `__repr__()`，映射紧凑 `to_str()` JSON；第十七批补充 `Model::{kind,unk_token,unk_id,continuing_subword_prefix,end_of_word_suffix,max_input_chars_per_word,dropout,byte_fallback,fuse_unk,ignore_merges}` 只读配置 getter，覆盖 HF model 属性映射；第十八批补充 `PreTokenizer::pre_tokenize_str`，返回 HF 风格 `(value, offsets)` tuple；第十九批补充 `PreTokenizer::byte_level_alphabet()`，对齐 HF ByteLevel.alphabet 静态入口；第二十批补充 `Normalizer::normalize_str`，对齐 HF normalizer 字符串便捷入口；第二十一批补充 `Normalizer` 只读配置 getter（kind、Strip/Replace/Prepend/Bert/Sequence 配置），覆盖 HF normalizer 属性映射；第二十二批补充 `PreTokenizer` 只读配置 getter（ByteLevel/Metaspace/Punctuation/Split/Digits/Delimiter/FixedLength/Sequence 配置），覆盖 HF pre-tokenizer 属性映射；第二十三批补充 `Decoder` 只读配置 getter（ByteLevel/WordPiece/Metaspace/BPEDecoder/Strip/Replace/CTC/Sequence 配置），覆盖 HF decoder 属性映射；第二十四批补充 `PostProcessor` 只读配置 getter（Bert/Roberta special token pair、ByteLevel/Roberta flags、TemplateProcessing typed pieces/special tokens、Sequence processors），覆盖 HF processor 属性映射；第二十五批补充 `Normalizer` / `PreTokenizer` / `Decoder` / `PostProcessor` JSON state 与 `__str__` / `__repr__` alias，`get_state` / `from_state` / `__getstate__` / `__setstate__` 只对有稳定 JSON 的组件往返，不可序列化组件显式报 unsupported；第二十六批补充 `ModelState` 与 `Model::{get_state,from_state,__getstate__,__setstate__,__str__,__repr__}`，覆盖四类模型的 JSON state/显示 alias；第二十七批补充 `AddedToken::__str__/__repr__`、`Encoding::__repr__`、`NormalizedString::__str__/__repr__` 显示 alias；所有数组 accessor 继续返回 copy，便于 Python binding 在不暴露 MoonBit 内部字段布局的情况下映射属性与批量转换方法。后续继续补更多方法/属性 alias；MoonBit 原生 API 不因此变复杂 | 独立里程碑 |

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
| BPE / 字节级 BPE | ✅ | 优先队列(pairing heap)合并 + 惰性失效 + word cache；decode 反查使用 dense id array 并在加载时直接填充；native mixed 抽样 gpt2/llama encode 快于 HF |
| byte_fallback / fuse_unk / ignore_merges | ✅ | |
| WordPiece | ✅ | 贪心最长前缀；支持 `continuing_subword_prefix` 与 HF `end_of_word_suffix` |
| Unigram | ✅ | Viterbi DP + word cache；`byte_fallback` / `fuse_unk` supported；native mixed 抽样 t5/bge/e5 encode 快于 HF |
| WordLevel | ✅ | |
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
| truncation / padding / encode_batch | ✅ | with_truncation/with_padding builder；BatchLongest/Fixed；batch 串行；encode_pair 已接入 finalize |
| decode_batch / decode_stream | ✅ | `decode_batch` 串行实现并带重复 id 序列缓存；`decode_stream` 对齐 HF token-by-token 增量解码，显式返回更新后的 stream，覆盖 special skip 与 incomplete ByteFallback buffering |
| tokenizer.json root truncation/padding 自动加载 | ✅ | 已解析 root-level `truncation` / `padding`，覆盖 Fixed/BatchLongest 与方向/倍数/pad 字段 |
| offsets | ✅ | 默认保留 char offsets；新增 `encode_with_byte_offsets` / `encode_pair_with_byte_offsets` 对齐 HF byte offsets；ByteLevel post-processor `trim_offsets` 已按 HF 空白裁剪语义对齐 |
| sequence_ids | ✅ | `Encoding::sequence_ids()`；special/padding 为 None，pair 序列为 Some(0)/Some(1) |
| token-char 映射 | ✅ | `token_to_sequence` / `token_to_chars` / `char_to_token`，半开区间语义对齐 HF |
| Encoding HF-style getters | ✅ | `get_ids` / `get_type_ids` / `get_tokens` / `get_offsets` / `get_special_tokens_mask` / `get_attention_mask` / `get_overflowing` 返回副本，便于从 HF Encoding 迁移 |
| Encoding / Tokenizer metadata getters | ✅ | `Encoding::len` / `is_empty` / `n_sequences` / `get_sequence_ids` / `get_word_ids`，以及 Tokenizer component getters（model/normalizer/pre_tokenizer/post_processor/decoder/truncation/padding）|
| 程序化构造 / AddedToken API | ✅ | `Tokenizer::new`、`with_normalizer` / `with_pre_tokenizer` / `with_model` / `with_post_processor` / `with_decoder`、`AddedToken` builder、`add_tokens(_with_count)` / `add_special_tokens(_with_count)`；普通 added token mask=0，special token mask=1，支持 `encode_special_tokens`、added-token introspection、`num_special_tokens_to_add` 与显式 `post_process`；typed normalizer/post_processor/decoder/truncation/padding 可序列化往返 |

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
| P1 | 程序化 Tokenizer 构造与 AddedToken API | ✅ | 对齐 HF `Tokenizer(model)`、组件赋值与 `add_tokens` / `add_special_tokens` 主流程；新增 builder、count 返回、重复 token 不增词表、已存在 model token 可注册为 added/special 以参与预切分；补 typed normalizer/post_processor/decoder/truncation/padding 序列化、`encode_special_tokens` 开关、`get_added_tokens_decoder` / `is_special_token` introspection、`num_special_tokens_to_add` 与显式 `post_process`；round-trip 单测、API/迁移文档与 HF builder/add-token/to_json/post_process benchmark 行已覆盖 |
| P2 | Precompiled SentencePiece charsmap 完整解码 | ✅ | 已支持 base64 `precompiled_charsmap` → SentencePiece double-array trie → normalized blob 规则；保留空/缺失 map 的 NFKC+空白 fast path，并新增二进制 charsmap 单测与 bench |
| P2 | 通用 Split/Replace 正则覆盖策略 | ✅ | Normalizer/Decoder Replace 已统一走 Split 的 deterministic simple-regex span scanner，覆盖 `\\s` / `\\S` / `\\d` / `\\D` / `\\w` / `\\W`、ASCII alnum/letter、Unicode `\\p{L}` / `\\p{N}` / `\\p{P}` / `\\p{S}`、punctuation-or-symbol union、anchored positive/inverse class runs、覆盖同一批正向/反向 class families 的 exact `{2}`/`{3}`/`{4}`、min `{2,}`/`{3,}`/`{4,}`、bounded `{1,n}` 与 ranged `{2,3}`/`{2,4}`/`{3,4}` families；Decoder Replace 对这些 simple regex 直接绕过 decode_chain，Split/Normalizer/Decoder 三套语义由 `common` 同一分发表驱动，并已补 exact/min inverse regex bench 与 HF baseline；复杂未知 Split pattern 加载期显式 Unsupported，未知 Replace pattern 保持字面量 fallback；full regex engine 不作为该阶段验收目标 |
| P2 | save / to_json / from_file 对称性 | ✅ | `to_json` 保留原始 tokenizer.json；`Tokenizer::from_file` / `save` 可往返；新增 HF 风格 `save_pretrained(dir)` 写出 `dir/tokenizer.json` 并可由 `from_pretrained(dir)` 重新加载；补 serialization 测试与 to_json/save_pretrained bench |
| P3 | `from_pretrained` / Hub 集成 | ✅ | 核心 `@tokenizer.from_pretrained` 保持全后端离线加载：本地 HF 目录（`tokenizer.json`）、tokenizer 文件路径、`save_pretrained` 目录、已有 HuggingFace Hub cache snapshot（`$HUGGINGFACE_HUB_CACHE` / `$HF_HOME/hub` / `$HOME/.cache/huggingface/hub`，含 refs/main → snapshots/<rev> 与显式 revision 解析），并对稳定 pretrained 路径做小型 FIFO source cache；新增 `from_pretrained_downloaded` 作为宿主/下载器桥接 API，可写入标准 HF cache；新增可选 native/js `hub` 包，基于 `moonbitlang/async/http` 在线下载 `/<model>/resolve/<revision>/tokenizer.json`，支持 redirect、自定义 endpoint/mirror/cache、HF/tokenizers 风格请求 headers、`HF_TOKEN`/显式 token 与 `local_files_only`；离线解析错误会区分文件缺失、目录缺 tokenizer 与 Hub cache 未命中，并补 negative tests / cache eviction bench |
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
3. **性能**：BPE merge 已用优先队列(pairing heap)+惰性失效，llama 提速约 7x、与 Rust 同量级；进一步可加 word→tokens 缓存与多 MB 词表加载优化。
4. **batch 并行策略**：MoonBit 当前已有 async/structured concurrency，但官方 `moonbitlang/async` 文档说明其任务模型是 single-threaded cooperative multitasking，用户代码只能使用一个硬件处理器；因此它不能直接给 CPU-bound tokenizer encode_batch 提供跨 target 多核并行。项目已提供保持顺序稳定的 `*_parallel(_fast)` 兼容入口，内部委托串行批处理 + 批内重复输入缓存，BPE/WordPiece/Unigram 均带 word cache（场景定位 wasm/js 边缘端）。未来 target runtime 提供稳定 worker 调度时可替换内部实现，不改变公开 API。

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
