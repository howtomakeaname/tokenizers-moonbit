# API 参考

公开 tokenizer API 位于 `@tokenizer` 包，共享类型位于 `@types`。

英文版：[`../api.md`](../api.md)

## 加载

```moonbit
fn Tokenizer::from_str(json : String) -> Tokenizer raise TokenizerError
fn Tokenizer::from_buffer(buffer : Bytes) -> Tokenizer raise TokenizerError
fn from_file(path : String) -> Tokenizer raise TokenizerError
fn from_pretrained(path_or_model_id : String) -> Tokenizer raise TokenizerError
fn from_pretrained_cached(
  model_id : String, revision? : String = "main", cache_dir? : String? = None,
) -> Tokenizer raise TokenizerError
fn from_pretrained_downloaded(
  model_id : String, tokenizer_json : String, revision? : String = "main",
  resolved_revision? : String? = None, cache_dir? : String? = None,
  tokenizer_config_json? : String? = None, special_tokens_map_json? : String? = None,
  etag? : String? = None,
) -> Tokenizer raise TokenizerError
fn Tokenizer::to_str(self : Tokenizer, pretty? : Bool = false) -> String raise TokenizerError
fn Tokenizer::save(self : Tokenizer, path : String, pretty? : Bool = true) -> Unit raise TokenizerError
fn Tokenizer::save_pretrained(
  self : Tokenizer, dir : String, pretty? : Bool = false,
  save_model? : Bool = false, model_prefix? : String = "",
) -> String raise TokenizerError
```

- `from_buffer` 解析 UTF-8 bytes；`from_file` 使用 `moonbitlang/x/fs` 读取文件后调用
  `from_str`。
- `from_pretrained` 支持 tokenizer JSON 文件、本地含 `tokenizer.json` 的目录，
  以及已存在的 HuggingFace Hub 本地 cache（按 `$HUGGINGFACE_HUB_CACHE`、
  `$HF_HUB_CACHE`、`$HF_HOME/hub`、`$HOME/.cache/huggingface/hub` 顺序解析）。
  核心库不做网络下载；稳定 pretrained source 会进入小型进程内 FIFO cache，优化重复加载。离线解析失败时会区分
  JSON 文件缺失、本地目录缺少 `tokenizer.json`、以及 model id 未命中本地 Hub cache。
- `from_str` 使用小型多项 parsed-JSON cache，重复或交替加载稳定
  tokenizer payload 时避免重复 JSON 解析，同时每次仍返回全新的 tokenizer 状态。
  WordLevel/WordPiece JSON 必须包含 `model.unk_token`；BPE JSON 必须包含
  `model.merges`；WordPiece JSON 还必须包含 `model.continuing_subword_prefix`
  与 `model.max_input_chars_per_word`。缺失或类型错误的必填字段会抛
  `TokenizerError`；BPE/Unigram 的布尔 knobs 与 BPE `dropout` 若类型错误也会
  被拒绝，而不是静默回落到默认值。BPE 可选字符串字段（`unk_token`、
  `continuing_subword_prefix`、`end_of_word_suffix`）以及 WordPiece
  `end_of_word_suffix` 允许缺失/null，但会拒绝错误 JSON 类型。Unigram
  `unk_id` 允许缺失/null，但会拒绝非 number 值。
  `added_tokens` 条目遵循 HF 严格 schema：`id`、`content`、`single_word`、
  `lstrip`、`rstrip`、`normalized`、`special` 必须存在且类型正确。
  root `truncation` / `padding` 对象也按 HF tokenizer JSON schema 解析：
  必填 number/string enum 字段缺失、类型错误或使用 Python-style lowercase alias
  时会被拒绝；`truncation.direction` 仍可省略并默认 `Right`。
- `from_pretrained_cached` 可显式传入本地 Hub cache 根目录和 revision，对齐
  HF `local_files_only=True` 的离线使用方式。
- `from_pretrained_downloaded` 用于网络调用方桥接：传入已下载的 `tokenizer.json`
  文本后写入标准 HF Hub cache 布局并立即解析。可选 `@hub` 包基于它在 native/js
  后端提供异步 HTTP 下载；wasm 场景可由宿主 fetch 后调用该函数。
- `from_pretrained_aux_file(path, filename)` 与
  `from_pretrained_aux_file_path(path, filename)` 可解析 tokenizer 邻近 sidecar 文件，
  例如 `added_tokens.json`，但不解释文件内容。
  `cache_pretrained_aux_file(model_id, filename, content, ...)` 可把 raw sidecar
  内容写入简化的 HF-compatible refs/snapshots cache，之后仍由同一套 aux reader 读回。
- `to_str(pretty)` 默认保持 compact/verbatim JSON。`save(path, pretty)` 对齐 HF
  `Tokenizer.save`，默认写出两空格 pretty JSON；传 `pretty=false` 可保留精确
  compact/verbatim bytes。`save_pretrained(dir, pretty)` 仍保持 compact 默认；
  `save_pretrained(save_model=true)` 还能在 `tokenizer.json` 旁写出模型 sidecar artifacts。
- 程序化构造的 tokenizer 会序列化已支持 typed serializer 的 normalizer、
  pre-tokenizer、model、post-processor、decoder、truncation、padding 与 added token
  状态；从 HF JSON 加载的 tokenizer 在 builder 修改 typed state 前仍保持原始 JSON
  原样往返。

### 独立模型文件（`@model`）

```moonbit
fn Model::wordlevel(
  vocab : Map[String, Int], unk_token? : String = "<unk>",
) -> Model
fn Model::wordpiece(
  vocab : Map[String, Int], unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##", end_of_word_suffix? : String? = None,
  max_input_chars_per_word? : Int = 100,
) -> Model
fn Model::save(self : Model, folder : String, prefix? : String = "") -> Array[String] raise TokenizerError
fn Model::from_bpe_files(
  vocab_path : String, merges_path : String, unk_token? : String? = Some("[UNK]"),
  continuing_subword_prefix? : String? = None, end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false, byte_fallback? : Bool = false,
  ignore_merges? : Bool = false, dropout? : Double? = None,
) -> Model raise TokenizerError
fn Model::bpe_read_file(...) -> Model raise TokenizerError
fn Model::bpe_from_file(...) -> Model raise TokenizerError
fn Model::from_wordpiece_file(
  vocab_path : String, unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##", end_of_word_suffix? : String? = None,
  max_input_chars_per_word? : Int = 100,
) -> Model raise TokenizerError
fn Model::wordpiece_read_file(...) -> Model raise TokenizerError
fn Model::wordpiece_from_file(...) -> Model raise TokenizerError
fn Model::from_wordlevel_file(
  vocab_path : String, unk_token? : String = "[UNK]",
) -> Model raise TokenizerError
fn Model::wordlevel_read_file(...) -> Model raise TokenizerError
fn Model::wordlevel_from_file(...) -> Model raise TokenizerError
fn Model::from_unigram_file(vocab_path : String) -> Model raise TokenizerError
```

`Model::save` 会写出 HF 风格独立模型文件：BPE 为 `vocab.json` + `merges.txt`，
WordPiece 为 `vocab.txt`，WordLevel 为 `vocab.json`，Unigram 为紧凑且保留 score
的 JSON 文件。对应 standalone loader 可把这些常见 HF artifact 重新读回 typed
model，包括保存出来的 Unigram JSON 片段；BPE merges 会跳过 `#version:` 注释行，
并沿用 tokenizer JSON 加载路径的 legacy merge 拆分语义。
`Model::wordlevel` 与 `Model::wordpiece` 提供内存词表构造入口，便于迁移 HF
`models.WordLevel(vocab=...)` 与 `models.WordPiece(vocab=...)`；构造时会复制输入
vocab，再建立 dense id lookup 表。
`*_read_file` 与 `*_from_file` 模型 helper 是同一套 BPE/WordPiece/WordLevel
artifact loader 的命名 alias，用于对齐 HF model class methods；Unigram 仍只暴露
JSON artifact loader，因为 HF 没有对应的 file-class helper。

#### Model getter 别名与状态 API

```moonbit
fn Model::kind(self : Model) -> String
fn Model::unk_token(self : Model) -> String?
fn Model::get_unk_token(self : Model) -> String?
fn Model::unk_id(self : Model) -> Int?
fn Model::get_unk_id(self : Model) -> Int?
fn Model::continuing_subword_prefix(self : Model) -> String?
fn Model::get_continuing_subword_prefix(self : Model) -> String?
fn Model::end_of_word_suffix(self : Model) -> String?
fn Model::get_end_of_word_suffix(self : Model) -> String?
fn Model::max_input_chars_per_word(self : Model) -> Int?
fn Model::get_max_input_chars_per_word(self : Model) -> Int?
fn Model::byte_fallback(self : Model) -> Bool?
fn Model::get_byte_fallback(self : Model) -> Bool?
fn Model::fuse_unk(self : Model) -> Bool?
fn Model::get_fuse_unk(self : Model) -> Bool?
fn Model::ignore_merges(self : Model) -> Bool?
fn Model::get_ignore_merges(self : Model) -> Bool?
fn Model::dropout(self : Model) -> Double?
fn Model::get_dropout(self : Model) -> Double?
fn Model::alpha(self : Model) -> Double?
fn Model::get_alpha(self : Model) -> Double?
fn Model::nbest_size(self : Model) -> Int?
fn Model::get_nbest_size(self : Model) -> Int?
fn Model::vocab_size(self : Model) -> Int
fn Model::get_vocab_size(self : Model) -> Int
fn Model::vocab(self : Model) -> Map[String, Int]
fn Model::get_vocab(self : Model) -> Map[String, Int]
fn Model::token_to_id(self : Model, token : String) -> Int?
fn Model::id_to_token(self : Model, id : Int) -> String?
fn Model::to_json(self : Model) -> String?
fn Model::get_state(self : Model) -> ModelState
fn Model::from_state(state : ModelState) -> Model raise TokenizerError
fn Model::clear_cache(self : Model) -> Unit
fn Model::resize_cache(self : Model, capacity : Int) -> Unit
fn Model::cache_size(self : Model) -> Int
```

属性风格 getter 返回模型配置。`kind()` 返回模型类型字符串
（`"BPE"`、`"WordPiece"`、`"Unigram"`、`"WordLevel"`）。
`vocab_size()` 和 `vocab()` 访问词表。`token_to_id()` 和 `id_to_token()` 查询 token。
`to_json()` 序列化模型。`get_state()` / `from_state()` 提供状态往返。
缓存控制方法管理内部 word-to-tokens 缓存。

#### Model setter 别名（Python binding 兼容）

```moonbit
fn Model::set_unk_token(self : Model, token : String) -> Model
fn Model::set_dropout(self : Model, dropout : Double?) -> Model
fn Model::set_continuing_subword_prefix(self : Model, prefix : String?) -> Model
fn Model::set_end_of_word_suffix(self : Model, suffix : String?) -> Model
fn Model::set_byte_fallback(self : Model, val : Bool) -> Model
fn Model::set_fuse_unk(self : Model, val : Bool) -> Model
fn Model::set_ignore_merges(self : Model, val : Bool) -> Model
fn Model::set_max_input_chars_per_word(self : Model, val : Int) -> Model
fn Model::set_alpha(self : Model, alpha : Double?) -> Model
fn Model::set_nbest_size(self : Model, nbest_size : Int?) -> Model
```

对应 HF Python `Model` 属性 setter（如 `model.dropout = 0.5`），MoonBit 提供 `set_*`
方法返回新 Model，保持不可变语义。每个 setter 仅修改对应模型变体的字段，其他变体返回
原 Model（如 `set_dropout` 对 Unigram 无操作）。每个 setter 都有 `*_alias` 别名保持
与 Python binding 迁移模式一致。

当 Unigram 模型设置 `alpha > 0` 且 `nbest_size > 0` 时，分词器使用 N-best 路径采样
（SentencePiece 模式）：通过 beam search 枚举最多 `nbest_size` 条完整分词路径，
计算得分后使用 `alpha` 作为温度的 softmax 采样。当 `nbest_size` 未设置（或 `<= 0`）时，
回退到前向-后向算法对完整分布采样。

#### Normalizer setter 别名（Python binding 兼容）

```moonbit
fn Normalizer::set_left(self : Normalizer, val : Bool) -> Normalizer
fn Normalizer::set_right(self : Normalizer, val : Bool) -> Normalizer
fn Normalizer::set_clean_text(self : Normalizer, val : Bool) -> Normalizer
fn Normalizer::set_handle_chinese_chars(self : Normalizer, val : Bool) -> Normalizer
fn Normalizer::set_strip_accents(self : Normalizer, val : Bool?) -> Normalizer
fn Normalizer::set_lowercase(self : Normalizer, val : Bool) -> Normalizer
fn Normalizer::set_prepend(self : Normalizer, val : String) -> Normalizer
fn Normalizer::set_content(self : Normalizer, val : String) -> Normalizer
```

对应 HF Python `Normalizer` 属性 setter，MoonBit 提供 `set_*` 方法返回新 Normalizer。
每个 setter 仅修改对应归一化器变体的字段，其他变体返回原 Normalizer。

#### Normalizer getter 别名

```moonbit
fn Normalizer::kind(self : Normalizer) -> String
fn Normalizer::left(self : Normalizer) -> Bool?
fn Normalizer::get_strip_left(self : Normalizer) -> Bool?
fn Normalizer::right(self : Normalizer) -> Bool?
fn Normalizer::get_strip_right(self : Normalizer) -> Bool?
fn Normalizer::pattern(self : Normalizer) -> String?
fn Normalizer::content(self : Normalizer) -> String?
fn Normalizer::prepend(self : Normalizer) -> String?
fn Normalizer::clean_text(self : Normalizer) -> Bool?
fn Normalizer::get_clean_text(self : Normalizer) -> Bool?
fn Normalizer::handle_chinese_chars(self : Normalizer) -> Bool?
fn Normalizer::get_handle_chinese_chars(self : Normalizer) -> Bool?
fn Normalizer::strip_accents(self : Normalizer) -> Bool?
fn Normalizer::get_strip_accents(self : Normalizer) -> Bool?
fn Normalizer::lowercase(self : Normalizer) -> Bool?
fn Normalizer::get_lowercase(self : Normalizer) -> Bool?
fn Normalizer::normalizers(self : Normalizer) -> Array[Normalizer]
fn Normalizer::get_normalizers(self : Normalizer) -> Array[Normalizer]
fn Normalizer::get_state(self : Normalizer) -> NormalizerState
fn Normalizer::from_state(state : NormalizerState) -> Normalizer raise TokenizerError
fn Normalizer::to_json(self : Normalizer) -> String?
fn Normalizer::from_json(j : Json) -> Normalizer raise TokenizerError
fn Normalizer::normalize_str(self : Normalizer, input : String) -> String raise TokenizerError
```

属性风格 getter 返回归一化器配置。`kind()` 返回类型字符串。
`left()` / `right()` 是 HF `Strip.left` / `Strip.right` 别名。
`normalizers()` 返回 Sequence 归一化器的子项。
`normalize_str()` 是 `normalize()` 的 HF 风格别名。
`get_state()` / `from_state()` 提供状态往返。

#### PreTokenizer setter 别名（Python binding 兼容）

```moonbit
fn PreTokenizer::set_add_prefix_space(self : PreTokenizer, val : Bool) -> PreTokenizer
fn PreTokenizer::set_use_regex(self : PreTokenizer, val : Bool) -> PreTokenizer
fn PreTokenizer::set_trim_offsets(self : PreTokenizer, val : Bool) -> PreTokenizer
fn PreTokenizer::set_replacement(self : PreTokenizer, val : Char) -> PreTokenizer
fn PreTokenizer::set_prepend_scheme(self : PreTokenizer, val : String) -> PreTokenizer
fn PreTokenizer::set_split_enabled(self : PreTokenizer, val : Bool) -> PreTokenizer
fn PreTokenizer::set_delimiter(self : PreTokenizer, val : Char) -> PreTokenizer
fn PreTokenizer::set_individual_digits(self : PreTokenizer, val : Bool) -> PreTokenizer
fn PreTokenizer::set_length(self : PreTokenizer, val : Int) -> PreTokenizer
fn PreTokenizer::set_behavior(self : PreTokenizer, val : SplitBehavior) -> PreTokenizer
fn PreTokenizer::set_invert(self : PreTokenizer, val : Bool) -> PreTokenizer
```

对应 HF Python `PreTokenizer` 属性 setter，MoonBit 提供 `set_*` 方法返回新 PreTokenizer。
每个 setter 仅修改对应预分词器变体的字段，其他变体返回原 PreTokenizer。


### 可选 Hub 下载器（`@hub`，native/js）

```moonbit
fn HubDownloadOptions::new(
  endpoint? : String = "https://huggingface.co",
  revision? : String = "main",
  cache_dir? : String? = None,
  token? : String? = None,
  local_files_only? : Bool = false,
  max_redirects? : Int = 5,
  user_agent? : String? = Some("unknown/None; hf_hub/...; python/...; tokenizers/..."),
  stream_chunk_size? : Int = 65536,
) -> HubDownloadOptions

async fn @hub.from_pretrained(
  model_id : String, options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> Tokenizer raise TokenizerError
```

`@hub.from_pretrained` 会先尝试本地文件/cache，未命中时通过
`moonbitlang/async/http` 下载 `/<model>/resolve/<revision>/tokenizer.json`，跟随
redirect，写入 HF 风格 cache 后复用核心 loader。支持自定义 endpoint/mirror、显式
cache 根目录、`HF_TOKEN` 或显式 bearer token、通过 `HF_TOKEN_PATH` / `$HF_HOME/token`
发现 token、HF 风格请求 headers，以及
`local_files_only=true`。`HF_ENDPOINT` 可作为默认 endpoint；`HF_HUB_OFFLINE`
为真值（`1`、`true`、`yes`、`on`）时会让默认 hub options 进入 local-only 模式，
除非调用方显式覆盖。中国大陆用户可显式配置镜像：

`hub_file_url` 与 `plan_hub_file_request` 为 `tokenizer_config.json`、
`special_tokens_map.json`、`added_tokens.json` 等 tokenizer 邻近 sidecar 文件暴露同一套
URL revision 编码与请求 headers；sidecar request plan 不附带 tokenizer cache/range
metadata。`apply_hub_file_download_result` 可把完整 sidecar response body 作为 raw
snapshot 内容写入 cache，`download_hub_file` 可对 tokenizer 邻近 sidecar 做简单
2xx-only GET。`from_pretrained` 自动下载 sidecar、ETag/Range/resume 决策和内容解析
仍不属于这些 helper 的范围。

```moonbit
let tok = @hub.from_pretrained(
  "bert-base-uncased",
  options=@hub.HubDownloadOptions::new(endpoint="https://hf-mirror.com"),
)
```

## 编码与解码

```moonbit
fn Tokenizer::encode(
  self : Tokenizer, text : String, add_special_tokens~ : Bool = true,
) -> Encoding raise TokenizerError

fn Tokenizer::encode_pair(
  self : Tokenizer, text_a : String, text_b : String,
  add_special_tokens~ : Bool = true,
) -> Encoding raise TokenizerError

fn Tokenizer::encode_batch(
  self : Tokenizer, texts : Array[String], add_special_tokens~ : Bool = true,
) -> Array[Encoding] raise TokenizerError

fn Tokenizer::encode_pair_batch(
  self : Tokenizer, pairs : Array[(String, String)], add_special_tokens~ : Bool = true,
) -> Array[Encoding] raise TokenizerError

fn Tokenizer::encode_pretokenized(
  self : Tokenizer, words : Array[String], add_special_tokens~ : Bool = true,
) -> Encoding raise TokenizerError

fn Tokenizer::encode_pretokenized_pair(
  self : Tokenizer, words_a : Array[String], words_b : Array[String],
  add_special_tokens~ : Bool = true,
) -> Encoding raise TokenizerError

fn Tokenizer::encode_pretokenized_batch(
  self : Tokenizer, batch : Array[Array[String]], add_special_tokens~ : Bool = true,
) -> Array[Encoding] raise TokenizerError

fn Tokenizer::encode_pretokenized_pair_batch(
  self : Tokenizer, batch : Array[(Array[String], Array[String])],
  add_special_tokens~ : Bool = true,
) -> Array[Encoding] raise TokenizerError

fn Tokenizer::decode(
  self : Tokenizer, ids : Array[Int], skip_special_tokens~ : Bool = true,
) -> String

fn Tokenizer::decode_batch(
  self : Tokenizer, batch : Array[Array[Int]], skip_special_tokens? : Bool = true,
) -> Array[String]

fn Tokenizer::decode_stream(
  self : Tokenizer, skip_special_tokens? : Bool = true,
) -> DecodeStream

fn DecodeStream::step(self : DecodeStream, id : Int) -> (DecodeStream, String?)
```

Fast encode 变体（`encode_fast`、`encode_batch_fast`、
`encode_sequence_input_fast`、`encode_input_fast`、`encode_input_batch_fast`、
`batch_encode_plus_fast`）保持 ids/tokens/masks/sequence metadata 与普通 encode
路径一致，同时把 offsets 置零。encode API 可能因模型级 tokenization 失败抛
`TokenizerError`，例如 WordLevel/WordPiece/BPE/Unigram 的 unknown-token fallback
配置缺失。Async 兼容 alias（`async_encode`、
`async_encode_fast`、`async_encode_batch`、`async_encode_batch_fast`、
`async_decode`、`async_decode_batch`）在所有 target 上委托同一套确定性同步实现。

高层 encode API 的 `add_special_tokens=false` 遵循 HF 语义：跳过由
post-processor 注入的 special token，但 post-processor 仍会执行非 special-token
效果，例如 Template/BERT `type_ids`、句对 `sequence_ids` 与 ByteLevel/RoBERTa
offset trimming。

所有 `encode_*_with_byte_offsets` 变体返回 HF 风格 UTF-8 byte offsets。
pre-tokenized 输入会跳过 tokenizer 的 pre-tokenizer 阶段，但 normalizer、model、
post-processor、truncation 与 padding 仍会执行；offsets 按“归一化后的词用单个 ASCII
空格连接”得到的合成文本计算。传入词内部的 added/special token 仍会按 tokenizer 的
`single_word`、`lstrip`、`rstrip` 与 `normalized` 规则先切出，再把普通片段交给 model。

`decode_stream` 对齐 HF 的增量解码器，用于 token-by-token streaming。每次 `step`
返回新的 stream 和可选输出：当缓冲 ids 已经能解出有效文本增量时返回 `Some(chunk)`，
遇到未完成的 byte-fallback / decoder 上下文时返回 `None`。

## 属性风格 getter

```moonbit
fn Tokenizer::normalizer(self : Tokenizer) -> Normalizer?
fn Tokenizer::pre_tokenizer(self : Tokenizer) -> PreTokenizer?
fn Tokenizer::model(self : Tokenizer) -> Model
fn Tokenizer::post_processor(self : Tokenizer) -> PostProcessor?
fn Tokenizer::decoder(self : Tokenizer) -> Decoder?
fn Tokenizer::truncation(self : Tokenizer) -> TruncationParams?
fn Tokenizer::padding(self : Tokenizer) -> PaddingParams?
fn Tokenizer::encode_special_tokens(self : Tokenizer) -> Bool
fn Tokenizer::vocab_size(self : Tokenizer) -> Int
fn Tokenizer::vocab(self : Tokenizer) -> Map[String, Int]
fn Tokenizer::added_tokens_decoder(self : Tokenizer) -> Map[Int, AddedToken]
fn Tokenizer::added_tokens(self : Tokenizer) -> Array[AddedToken]
fn Tokenizer::added_tokens_count(self : Tokenizer) -> Int
fn Tokenizer::all_special_tokens(self : Tokenizer) -> Array[String]
fn Tokenizer::all_special_ids(self : Tokenizer) -> Array[Int]
fn Tokenizer::get_trainer(self : Tokenizer) -> Trainer
fn Tokenizer::default_trainer(self : Tokenizer) -> Trainer
fn Tokenizer::to_json(self : Tokenizer) -> String raise TokenizerError
```

## 状态 API 与组件钩子

```moonbit
fn Tokenizer::get_state(self : Tokenizer) -> TokenizerState raise TokenizerError
fn Tokenizer::from_state(state : TokenizerState) -> Tokenizer raise TokenizerError
fn Tokenizer::with_component_hooks(self : Tokenizer, hooks : TokenizerComponentHooks) -> Tokenizer
fn Tokenizer::get_component_hooks(self : Tokenizer) -> TokenizerComponentHooks
fn Tokenizer::component_hooks(self : Tokenizer) -> TokenizerComponentHooks
fn Tokenizer::clear_component_hooks(self : Tokenizer) -> Tokenizer
fn Tokenizer::get_added_tokens(self : Tokenizer) -> Array[AddedToken]
fn Tokenizer::added_tokens(self : Tokenizer) -> Array[AddedToken]
fn Tokenizer::get_added_tokens_count(self : Tokenizer, special_only? : Bool = false) -> Int
fn Tokenizer::added_tokens_count(self : Tokenizer, special_only? : Bool = false) -> Int
```

`get_state` / `from_state` 提供 JSON 状态往返，用于 Python binding/pickle 互操作。
`with_component_hooks` 附加自定义 normalize/pre-tokenize/decode 回调；
`clear_component_hooks` 移除钩子。`get_added_tokens` 返回按 id 排序的所有 added tokens；
`get_added_tokens_count` 返回数量，支持 `special_only` 过滤。
`added_tokens` 和 `added_tokens_count` 是属性风格别名。

属性风格 getter 是对应 `get_*` 方法的便捷别名，返回相同值。
`normalizer()`、`pre_tokenizer()`、`model()`、`post_processor()`、`decoder()`
访问分词器组件。`truncation()` 和 `padding()` 返回当前配置。
`encode_special_tokens()` 报告 special token 编码开关。
`vocab_size()` 和 `vocab()` 是 `get_vocab_size()` 和 `get_vocab()` 的别名。
`added_tokens_decoder()` 返回 `id -> AddedToken` 映射。
`get_trainer()` 和 `default_trainer()` 返回使用当前分词器配置的 trainer。
`to_json()` 将分词器序列化为 JSON 字符串（`to_str()` 的别名）。

## 配置

```moonbit
fn Tokenizer::new(model : @model.Model) -> Tokenizer
fn Tokenizer::with_normalizer(self : Tokenizer, normalizer : @normalizer.Normalizer?) -> Tokenizer
fn Tokenizer::with_pre_tokenizer(self : Tokenizer, pre_tokenizer : @pretokenizer.PreTokenizer?) -> Tokenizer
fn Tokenizer::with_model(self : Tokenizer, model : @model.Model) -> Tokenizer
fn Tokenizer::with_post_processor(self : Tokenizer, post_processor : @processor.PostProcessor?) -> Tokenizer
fn Tokenizer::with_decoder(self : Tokenizer, decoder : @decoder.Decoder?) -> Tokenizer
fn Tokenizer::with_truncation(self : Tokenizer, params : TruncationParams?) -> Tokenizer
fn Tokenizer::with_padding(self : Tokenizer, params : PaddingParams?) -> Tokenizer
fn Tokenizer::set_normalizer(self : Tokenizer, normalizer : @normalizer.Normalizer?) -> Tokenizer
fn Tokenizer::set_pre_tokenizer(self : Tokenizer, pre_tokenizer : @pretokenizer.PreTokenizer?) -> Tokenizer
fn Tokenizer::set_model(self : Tokenizer, model : @model.Model) -> Tokenizer
fn Tokenizer::set_post_processor(self : Tokenizer, post_processor : @processor.PostProcessor?) -> Tokenizer
fn Tokenizer::set_decoder(self : Tokenizer, decoder : @decoder.Decoder?) -> Tokenizer
fn Tokenizer::set_truncation(self : Tokenizer, params : TruncationParams?) -> Tokenizer
fn Tokenizer::set_padding(self : Tokenizer, params : PaddingParams?) -> Tokenizer
fn Tokenizer::enable_truncation(
  self : Tokenizer, max_length : Int, stride? : Int = 0,
  strategy? : TruncationStrategy = LongestFirst,
  direction? : TruncationDirection = Right,
) -> Tokenizer
fn Tokenizer::enable_truncation_hf(
  self : Tokenizer, max_length : Int, stride? : Int = 0,
  strategy? : String = "longest_first", direction? : String = "right",
) -> Tokenizer raise TokenizerError
fn Tokenizer::no_truncation(self : Tokenizer) -> Tokenizer
fn Tokenizer::enable_padding(
  self : Tokenizer, length? : Int? = None, direction? : PaddingDirection = Right,
  pad_id? : Int = 0, pad_type_id? : Int = 0, pad_token? : String = "[PAD]",
  pad_to_multiple_of? : Int? = None,
) -> Tokenizer
fn Tokenizer::enable_padding_hf(
  self : Tokenizer, length? : Int? = None, direction? : String = "right",
  pad_id? : Int = 0, pad_type_id? : Int = 0, pad_token? : String = "[PAD]",
  pad_to_multiple_of? : Int? = None,
) -> Tokenizer raise TokenizerError
fn Tokenizer::no_padding(self : Tokenizer) -> Tokenizer

fn Tokenizer::get_normalizer(self : Tokenizer) -> @normalizer.Normalizer?
fn Tokenizer::get_pre_tokenizer(self : Tokenizer) -> @pretokenizer.PreTokenizer?
fn Tokenizer::get_model(self : Tokenizer) -> @model.Model
fn Tokenizer::get_post_processor(self : Tokenizer) -> @processor.PostProcessor?
fn Tokenizer::get_decoder(self : Tokenizer) -> @decoder.Decoder?
fn Tokenizer::get_truncation(self : Tokenizer) -> TruncationParams?
fn Tokenizer::get_padding(self : Tokenizer) -> PaddingParams?

fn Tokenizer::set_encode_special_tokens(self : Tokenizer, value : Bool) -> Tokenizer
fn Tokenizer::enable_encode_special_tokens(self : Tokenizer) -> Tokenizer
fn Tokenizer::disable_encode_special_tokens(self : Tokenizer) -> Tokenizer
fn Tokenizer::get_encode_special_tokens(self : Tokenizer) -> Bool
fn Tokenizer::num_special_tokens_to_add(self : Tokenizer, is_pair? : Bool = false) -> Int
fn Tokenizer::post_process(
  self : Tokenizer,
  encoding : Encoding,
  pair? : Encoding? = None,
  add_special_tokens? : Bool = true,
) -> Encoding
```

builder 返回 tokenizer，可链式调用，例如
`Tokenizer::new(model).with_pre_tokenizer(..).with_decoder(..)`；修改组件后会
使缓存的原始 JSON 失效，后续序列化尽量从已建模的 typed state 生成。
`set_*` 组件/配置方法是对应 `with_*` builder 的 writable-property 风格 alias，
保留同样“返回新 tokenizer”的语义，便于薄 binding 层映射 setter。
`enable_truncation_hf` 与 `enable_padding_hf` 接受 HF 风格字符串
`strategy` / `direction`，非法字符串会抛错；原 typed `enable_*` API 保持不变。

```moonbit
fn TruncationParams::new(max_length : Int) -> TruncationParams
fn TruncationParams::with_stride(self : TruncationParams, stride : Int) -> TruncationParams
fn TruncationParams::with_direction(self : TruncationParams, direction : TruncationDirection) -> TruncationParams
fn TruncationParams::with_direction_hf(self : TruncationParams, direction : String) -> TruncationParams raise TokenizerError
fn TruncationParams::with_strategy(self : TruncationParams, strategy : TruncationStrategy) -> TruncationParams
fn TruncationParams::with_strategy_hf(self : TruncationParams, strategy : String) -> TruncationParams raise TokenizerError
fn TruncationParams::direction_string(self : TruncationParams) -> String
fn TruncationParams::get_direction_string(self : TruncationParams) -> String
fn TruncationParams::strategy_string(self : TruncationParams) -> String
fn TruncationParams::get_strategy_string(self : TruncationParams) -> String

fn PaddingParams::new(
  strategy : PaddingStrategy, pad_id~ : Int = 0, pad_token~ : String = "[PAD]",
) -> PaddingParams
fn PaddingParams::fixed(length : Int, pad_id~ : Int = 0, pad_token~ : String = "[PAD]") -> PaddingParams
fn PaddingParams::batch_longest(pad_id~ : Int = 0, pad_token~ : String = "[PAD]") -> PaddingParams
fn PaddingParams::with_direction(self : PaddingParams, direction : PaddingDirection) -> PaddingParams
fn PaddingParams::with_direction_hf(self : PaddingParams, direction : String) -> PaddingParams raise TokenizerError
fn PaddingParams::with_pad_type_id(self : PaddingParams, pad_type_id : Int) -> PaddingParams
fn PaddingParams::with_pad_to_multiple_of(self : PaddingParams, pad_to_multiple_of : Int?) -> PaddingParams
fn PaddingParams::direction_string(self : PaddingParams) -> String
fn PaddingParams::get_direction_string(self : PaddingParams) -> String

fn Decoder::wordpiece(prefix? : String = "##", cleanup? : Bool = true) -> Decoder
fn Decoder::byte_fallback() -> Decoder
fn Decoder::ctc(
  pad_token? : String = "<pad>", word_delimiter_token? : String = "|", cleanup? : Bool = true,
) -> Decoder
#### Decoder setter 别名（Python binding 兼容）

```moonbit
fn Decoder::set_add_prefix_space(self : Decoder, val : Bool) -> Decoder
fn Decoder::set_trim_offsets(self : Decoder, val : Bool) -> Decoder
fn Decoder::set_use_regex(self : Decoder, val : Bool) -> Decoder
fn Decoder::set_prefix(self : Decoder, val : String) -> Decoder
fn Decoder::set_cleanup(self : Decoder, val : Bool) -> Decoder
fn Decoder::set_replacement(self : Decoder, val : Char) -> Decoder
fn Decoder::set_prepend_scheme(self : Decoder, val : String) -> Decoder
fn Decoder::set_split_enabled(self : Decoder, val : Bool) -> Decoder
fn Decoder::set_suffix(self : Decoder, val : String) -> Decoder
fn Decoder::set_content(self : Decoder, val : String) -> Decoder
fn Decoder::set_start(self : Decoder, val : Int) -> Decoder
fn Decoder::set_stop(self : Decoder, val : Int) -> Decoder
fn Decoder::set_left(self : Decoder, val : Int) -> Decoder
fn Decoder::set_right(self : Decoder, val : Int) -> Decoder
fn Decoder::set_pad_token(self : Decoder, val : String) -> Decoder
fn Decoder::set_word_delimiter_token(self : Decoder, val : String) -> Decoder
```

对应 HF Python `Decoder` 属性 setter，MoonBit 提供 `set_*` 方法返回新 Decoder，
保持不可变语义。每个 setter 仅修改对应解码器变体的字段，其他变体返回原 Decoder。
适用于多个变体的 setter（如 `set_cleanup` 同时支持 WordPiece 和 CTC，
`set_content` 同时支持 Replace 和 ReplaceString）会处理所有匹配变体。


fn PostProcessor::bert(sep : (String, Int), cls : (String, Int)) -> PostProcessor
fn PostProcessor::bert_processing(sep : (String, Int), cls : (String, Int)) -> PostProcessor
fn PostProcessor::roberta(
  sep : (String, Int), cls : (String, Int),
  trim_offsets? : Bool = true, add_prefix_space? : Bool = true,
) -> PostProcessor
fn PostProcessor::roberta_processing(
  sep : (String, Int), cls : (String, Int),
  trim_offsets? : Bool = true, add_prefix_space? : Bool = true,
) -> PostProcessor
fn PostProcessor::byte_level(
  add_prefix_space? : Bool = true, trim_offsets? : Bool = true, use_regex? : Bool = true,
) -> PostProcessor
fn SpecialToken::new(id : String, ids : Array[Int], tokens : Array[String]) -> SpecialToken
fn PostProcessor::template(
  single : Array[Piece], pair : Array[Piece], special_tokens : Map[String, SpecialToken],
) -> PostProcessor
fn PostProcessor::template_processing(
  single : Array[Piece], pair : Array[Piece], special_tokens : Map[String, SpecialToken],
) -> PostProcessor
fn PostProcessor::template_from_strings(
  single : String, pair : String, special_tokens : Map[String, SpecialToken],
) -> PostProcessor raise TokenizerError
fn PostProcessor::sequence(steps : Array[PostProcessor]) -> PostProcessor
#### Trainer setter 别名（Python binding 兼容）

```moonbit
fn Trainer::set_unk_token(self : Trainer, val : String?) -> Trainer
fn Trainer::set_min_frequency(self : Trainer, val : Int) -> Trainer
fn Trainer::set_special_tokens(self : Trainer, val : Array[String]) -> Trainer
fn Trainer::set_special_added_tokens(self : Trainer, val : Array[AddedToken]) -> Trainer
fn Trainer::set_vocab_size(self : Trainer, val : Int?) -> Trainer
fn Trainer::set_show_progress(self : Trainer, val : Bool) -> Trainer
fn Trainer::set_continuing_subword_prefix(self : Trainer, val : String?) -> Trainer
fn Trainer::set_end_of_word_suffix(self : Trainer, val : String?) -> Trainer
fn Trainer::set_max_input_chars_per_word(self : Trainer, val : Int) -> Trainer
fn Trainer::set_max_token_length(self : Trainer, val : Int?) -> Trainer
fn Trainer::set_initial_alphabet(self : Trainer, val : Array[String]) -> Trainer
fn Trainer::set_limit_alphabet(self : Trainer, val : Int?) -> Trainer
fn Trainer::set_fuse_unk(self : Trainer, val : Bool) -> Trainer
fn Trainer::set_byte_fallback(self : Trainer, val : Bool) -> Trainer
fn Trainer::set_shrinking_factor(self : Trainer, val : Double) -> Trainer
fn Trainer::set_max_piece_length(self : Trainer, val : Int?) -> Trainer
fn Trainer::set_n_sub_iterations(self : Trainer, val : Int) -> Trainer
fn Trainer::set_seed_size(self : Trainer, val : Int) -> Trainer
fn Trainer::set_progress_format(self : Trainer, val : String) -> Trainer
```

对应 HF Python `Trainer` 属性 setter，MoonBit 提供 `set_*` 方法返回新 Trainer，
保持不可变语义。每个 setter 仅修改对应训练器变体的字段，其他变体返回原 Trainer。
适用于多个变体的 setter（如 `set_unk_token` 支持所有四种训练器类型）会处理所有匹配变体。
每个 setter 都有 `*_alias` 别名，保持与 Python binding 迁移模式一致。

#### PostProcessor setter 别名（Python binding 兼容）

```moonbit
fn PostProcessor::set_trim_offsets(self : PostProcessor, val : Bool) -> PostProcessor
fn PostProcessor::set_add_prefix_space(self : PostProcessor, val : Bool) -> PostProcessor
fn PostProcessor::set_use_regex(self : PostProcessor, val : Bool) -> PostProcessor
fn PostProcessor::set_sep(self : PostProcessor, val : (String, Int)) -> PostProcessor
fn PostProcessor::set_cls(self : PostProcessor, val : (String, Int)) -> PostProcessor
```

对应 HF Python `PostProcessor` 属性 setter，MoonBit 提供 `set_*` 方法返回新
PostProcessor，保持不可变语义。每个 setter 仅修改对应后处理器变体的字段，其他变体
返回原 PostProcessor。适用于多个变体的 setter（如 `set_sep` 同时支持 BertProcessing
和 RobertaProcessing）会处理所有匹配变体。

```

Decoder / PostProcessor builder 用于在测试或合成 pipeline 中直接构造常见 HF 配置。
`set_encode_special_tokens(true)` 对齐 HF 的 `encode_special_tokens` 开关：输入文本中出现的
special token 不再被提前抽取为 special added token，而是留在普通 model 路径上。
`post_process` 可对已构造的 encoding 显式应用当前 post-processor；
当 `add_special_tokens=false` 时会按 HF 语义跳过 special token 注入，但仍保留
ByteLevel/RoBERTa offset trimming 等非 special-token 后处理效果。Python binding
应优先映射这个 tokenizer-level 入口；低层 `PostProcessor::process` 也接受同名
`add_special_tokens` 标志。`num_special_tokens_to_add` 返回单句或句对会额外插入的 special token 数量。
同名计数也在 `PostProcessor::num_special_tokens_to_add(is_pair)` 上提供，
用于对齐 HF Python binding。

## Added tokens

```moonbit
fn AddedToken::new(
  content : String, single_word? : Bool = false, lstrip? : Bool = false,
  rstrip? : Bool = false, normalized? : Bool? = None, special? : Bool = false,
) -> AddedToken
fn AddedToken::special(content : String) -> AddedToken
fn AddedToken::with_single_word(self : AddedToken, single_word : Bool) -> AddedToken
fn AddedToken::with_lstrip(self : AddedToken, lstrip : Bool) -> AddedToken
fn AddedToken::with_rstrip(self : AddedToken, rstrip : Bool) -> AddedToken
fn AddedToken::with_normalized(self : AddedToken, normalized : Bool) -> AddedToken
fn AddedToken::with_special(self : AddedToken, special : Bool) -> AddedToken

fn Tokenizer::add_tokens(self : Tokenizer, tokens : Array[AddedToken]) -> Tokenizer
fn Tokenizer::add_tokens_with_count(self : Tokenizer, tokens : Array[AddedToken]) -> (Tokenizer, Int)
fn Tokenizer::add_token_strings(self : Tokenizer, tokens : Array[String]) -> Tokenizer
fn Tokenizer::add_token_strings_with_count(self : Tokenizer, tokens : Array[String]) -> (Tokenizer, Int)
fn Tokenizer::add_special_tokens(self : Tokenizer, tokens : Array[AddedToken]) -> Tokenizer
fn Tokenizer::add_special_tokens_with_count(self : Tokenizer, tokens : Array[AddedToken]) -> (Tokenizer, Int)
fn Tokenizer::add_special_token_strings(self : Tokenizer, tokens : Array[String]) -> Tokenizer
fn Tokenizer::add_special_token_strings_with_count(self : Tokenizer, tokens : Array[String]) -> (Tokenizer, Int)
fn Tokenizer::get_added_tokens_decoder(self : Tokenizer) -> Map[Int, AddedToken]
fn Tokenizer::get_all_special_tokens(self : Tokenizer) -> Array[String]
fn Tokenizer::get_all_special_ids(self : Tokenizer) -> Array[Int]
fn Tokenizer::is_special_token(self : Tokenizer, token : String) -> Bool
```

`*_with_count` 返回新注册 token 的数量，对齐 HF 对重复 token 的计数语义；已存在于
model 词表的 token 首次注册为 added/special token 时也会计数，但保留原 model id，
不会增加词表大小。字符串入口也提供同语义的 `_with_count` 变体。
普通 added token 的 `special_tokens_mask=0`，只有 `special=true` 的条目会标为 `1`；若启用
`encode_special_tokens`，输入文本中的 special token 字符串会作为普通 model token 编码。
`get_added_tokens_decoder` 返回 HF 风格的 `id -> AddedToken` 元数据，便于迁移和调试；
`get_all_special_tokens` / `get_all_special_ids` 是有序 special token 列表的 getter alias。
`AddedToken::new` 接受 HF 风格 keyword 默认值；`special=true` 且省略 `normalized`
时默认 `false`，对齐 HF constructor。
`AddedToken::__str__()` 返回 token content，`__repr__()` 返回稳定的 HF 风格配置摘要。
低层 `Token` 与 `Split` 也提供 `__str__()` 返回 surface value，`__repr__()`
返回带转义的紧凑诊断摘要。

## 缓存控制

```moonbit
fn Tokenizer::clear_cache(self : Tokenizer) -> Tokenizer
fn Tokenizer::resize_cache(self : Tokenizer, capacity : Int) -> Tokenizer
fn Tokenizer::cache_size(self : Tokenizer) -> Int
```

BPE、WordPiece 和 Unigram 模型维护内部 word-to-tokens 缓存，加速重复编码相同字符串。
`clear_cache` 清空缓存并返回新 Tokenizer；`resize_cache` 设置最大容量（超出时淘汰最旧条目）；
`cache_size` 报告当前缓存条目数。设置容量为 `0` 禁用缓存；`None`（默认）保持无界缓存。

## 词表

```moonbit
fn Tokenizer::token_to_id(self : Tokenizer, token : String) -> Int?
fn Tokenizer::id_to_token(self : Tokenizer, id : Int) -> String?
fn Tokenizer::get_vocab_size(self : Tokenizer) -> Int
fn Tokenizer::vocab_size(self : Tokenizer) -> Int
fn Tokenizer::get_vocab(self : Tokenizer) -> Map[String, Int]
fn Tokenizer::vocab(self : Tokenizer) -> Map[String, Int]
fn Tokenizer::convert_token_to_id(self : Tokenizer, token : String) -> Int?
fn Tokenizer::convert_id_to_token(self : Tokenizer, id : Int) -> String?
fn Tokenizer::convert_tokens_to_ids(self : Tokenizer, tokens : Array[String]) -> Array[Int?]
fn Tokenizer::convert_ids_to_tokens(self : Tokenizer, ids : Array[Int]) -> Array[String?]
```

查询顺序：added/special vocabulary 优先，其次模型词表。
`vocab_size` 和 `vocab` 是 `get_vocab_size` 和 `get_vocab` 的属性风格别名。
`convert_token_to_id` / `convert_id_to_token` 是 `token_to_id` / `id_to_token` 的
HF 风格别名。`convert_tokens_to_ids` 和 `convert_ids_to_tokens` 是批量变体，
映射 token/id 数组。

## 低层迁移 API

`NormalizedString` 暴露一组便于薄 binding 层映射 HF API 的 helper：
`get` / `normalized` / `to_string`、`get_original` / `original`、`len` /
`__len__`、`is_empty`、state/tuple 往返、`normalize`、`replace`、`prepend`、
`append`、`clear`、`lowercase`、`uppercase`、`lstrip`、`rstrip`、`strip`、
`nfc`、`nfd`、`nfkc`、`nfkd`、`slice`、`map`、`filter`、literal `split`
以及受支持 deterministic 子集的 `split_regex`、单 index `get_item` /
`__getitem__`，并提供 `__str__` / `__repr__` 显示 alias。

`PreTokenizedString` 提供 `get_splits` / `splits`、单 index `get_item` /
`__getitem__`、`normalize`、pre-tokenizer `split`、state/tuple helper，以及
`to_encoding` / `into_encoding`。

`PreTokenizer::pre_tokenize_str(text)` 返回 HF 风格 `(value, offsets)` tuple，
便于组件级检查和 binding shim。
`PreTokenizer::byte_level_alphabet()` 对齐 HF ByteLevel.alphabet，返回与
`@pretokenizer.byte_level_alphabet()` 相同的 256 个符号表；`PreTokenizer::alphabet()`
是同一 helper 的精确方法名 alias。
`PreTokenizer` 也提供只读配置 getter，覆盖 ByteLevel 标记、Metaspace 设置、
Split/Punctuation behavior、Digits/Delimiter/FixedLength 设置与 Sequence 子项。
这些字段同时提供 `get_*` alias，例如 `get_add_prefix_space`、`get_pattern`、
`get_individual_digits`，便于 Python binding 做属性访问。
Sequence pre-tokenizer 支持 `pre_tokenizers` / `get_pre_tokenizers`、`__len__`、
`get_item`、`__getitem__`。
同时提供常见 HF 构造器的 lower-snake builder alias，例如 `whitespace`、
`metaspace`、`punctuation`、`digits`、`byte_level`（默认
`add_prefix_space=true`）、`char_delimiter_split`、`split`（默认 `invert=false`、
`regex=false`）、`fixed_length`、`unicode_scripts` 和 `sequence`。
`Normalizer::normalize_str(input)` 作为 HF 风格别名，等价于 `normalize(input)`。
`Normalizer` 也提供只读配置 getter，覆盖 `kind`、Strip 左右裁剪标记、
Replace pattern/content、Prepend 内容、BertNormalizer 标记与 Sequence 子 normalizer。
这些字段同时提供 `get_*` alias，例如 `get_strip_left`、`get_pattern`、
`get_clean_text`，便于 Python binding 做属性访问；`left()` / `right()` 是 HF
`Strip.left` / `Strip.right` 的精确名称 alias。Sequence normalizer 同时提供返回副本的
`normalizers` / `get_normalizers` getter。
对 `BertNormalizer`，`strip_accents()` / `get_strip_accents()` 会保留 HF 三态配置：
`None` 序列化为 JSON `null`，归一化时按 `lowercase` 决定是否去音调。
同时提供常见 typed 构造器的 lower-snake builder alias，例如 `nfc`、`nfd`、
`nfkc`、`nfkd`、`byte_level`、`strip`、`replace`、`prepend_normalizer`、
`bert_normalizer`、`lowercase_normalizer`、`strip_accents_normalizer`、`nmt`、
`precompiled` 和 `sequence`。
`Decoder` 提供只读配置 getter，覆盖 ByteLevel 标记、WordPiece prefix/cleanup、
Metaspace replacement/prepend/split 设置、BPEDecoder suffix、Strip/Replace/CTC 设置、Sequence 子项，以及
通过 `decoders` / `get_decoders`、`__len__` / `get_item` / `__getitem__` 进行的
Sequence 访问。这些字段同时提供 `get_*` alias，例如 `get_prefix`、
`get_cleanup`、`get_split`、`get_word_delimiter_token`，便于 Python binding 做属性访问。
同时提供常见 HF 构造器的 lower-snake builder alias，例如 `byte_level`、
`bpe_decoder`、`strip`、`fuse` 和 `sequence`。
`PostProcessor` 提供只读配置 getter，覆盖 Bert/Roberta special token pair、
ByteLevel/Roberta 标记、TemplateProcessing typed pieces 与 special tokens、
以及 Sequence processors。
这些字段同时提供 `get_*` alias，例如 `get_sep`、`get_trim_offsets`、
`get_single_pieces`、`get_special_tokens`，便于 Python binding 做属性访问。
同时提供 HF 类名风格 constructor alias：`bert_processing`、`roberta_processing`、
`template_processing`。
TemplateProcessing 提供 typed `single()` 与 `pair()` alias 访问模板。
`Piece` 提供 `kind` / `get_kind`、`id` / `get_id`、`type_id` / `get_type_id`
以及 SequenceRef / SpecialTokenRef 模板叶子的 tuple 互操作，并提供 `__str__` /
`__repr__` 显示 alias。
`SpecialToken` 提供 tuple 互操作、返回副本的 `id` / `ids` / `tokens` getter，以及
`__str__` / `__repr__`。
Sequence post-processor 支持 `processors` / `get_processors`、`__len__`、
`get_item`、`__getitem__`。
`Normalizer`、`PreTokenizer`、`Decoder` 与 `PostProcessor` 也提供基于 JSON 的
`get_state` / `from_state` / `__getstate__` / `__setstate__`，以及
`__str__` / `__repr__` alias。没有稳定 JSON 序列化形态的组件会显式返回
unsupported-component 错误，不返回有损 state。

`Encoding::words()` 作为 HF Python 已废弃但仍存在的 `word_ids()` 属性别名提供。
`Encoding::__str__()` / `__repr__()` 返回 HF 风格的紧凑诊断摘要，包含 token 数和暴露的属性名。

`Trainer` 暴露返回副本的配置 getter，例如 `kind`、`unk_token`、
`min_frequency`、`special_tokens`、`special_added_tokens`、`vocab_size`、
`show_progress`，以及 WordPiece、BPE、Unigram trainer 的模型特有 knobs。
通用字段也提供 HF 风格 `get_*` alias：`get_unk_token`、`get_min_frequency`、
`get_special_tokens`、`get_special_added_tokens`、`get_vocab_size` 与
`get_show_progress`；模型特有 knobs 也提供对应 `get_*` alias，覆盖 prefix/suffix、
alphabet、max length、byte-fallback/fuse-unk、shrinking、seed 与 progress-format 字段。
binding 层也可以使用 lower-snake constructor alias：`wordlevel_trainer`、
`wordpiece_trainer`、`bpe_trainer`、`unigram_trainer`。默认 `vocab_size` cap
已在 typed constructor、lower-snake alias、model-level 训练 helper 与 tokenizer
convenience 训练入口之间对齐 HF：WordLevel、WordPiece、BPE 默认
`Some(30000)`，Unigram 默认 `Some(8000)`；显式传 `vocab_size=None` 表示不设 cap。
BPE trainer 也会把
`progress_format` 作为配置 state 保留（`"indicatif"`、`"json"`、`"silent"`），但真实
progress 输出仍保持跨 target no-op。Unigram 训练也接受 `initial_alphabet`，
并对多字符条目沿用 HF 的“只保留第一个字符”规则；同时保留 `seed_size` 作为
deterministic MVP 的 ranked candidate cap。这些 helper 用于
binding/property 映射，不改变训练行为。`TrainerState` 以及 `get_state` /
`from_state` / `__getstate__` / `__setstate__` 会保留同一份 typed 配置，包括
`AddedToken` 元数据；`__str__` / `__repr__` 返回紧凑 JSON 视图，便于 binding 日志和诊断。
`Tokenizer::train_from_iterator(texts, trainer, length=None)` 接受 HF 的 `length`
progress hint，并作为 no-op 透传，不改变训练结果。

`Model` 暴露只读配置 getter，便于 binding 层映射属性，包括 `kind`、`unk_token`、
`unk_id`、WordPiece/BPE 的 prefix/suffix knobs、BPE dropout 与 merge flags，以及
BPE/Unigram 的 byte-fallback/fuse-unk flags。它也支持基于 JSON 的 `get_state` /
`from_state` / `__getstate__` / `__setstate__`，以及返回紧凑 model JSON 的
`__str__` / `__repr__` alias。`get_vocab_size()` 作为 `vocab_size()` 的 HF 风格别名提供，
`vocab()` 作为 `get_vocab()` 的属性式 alias。
非 vocab 的 model 配置字段也提供 `get_*` alias，例如 `get_unk_token`、
`get_continuing_subword_prefix`、`get_byte_fallback`、`get_dropout`，便于 binding
属性访问。

`Tokenizer::__str__()` 与 `Tokenizer::__repr__()` 是面向 Python binding 的薄别名，
返回紧凑 `to_str()` JSON 形式。`TokenizerState::new(json)` 与其他 JSON-backed
state wrapper 保持一致，便于 binding/pickle shim 构造状态。

`TokenizerComponentHooks` 提供仅运行时生效的 normalize、pre-tokenize、decode
回调，供 binding 层临时承接还无法映射成 typed MoonBit 组件的动态 Python 组件。
这些 hook 可按单次调用传入，也可挂到 tokenizer 上；它们有意不写入 tokenizer
JSON/state，序列化往返仍应使用 typed 组件。

## 组件兼容性说明

- `Normalizer::Replace`、`Decoder::Replace` 与正则 `PreTokenizer::Split`
  共享同一套确定性的简单正则扫描器，避免不同后端依赖不同正则实现。已覆盖
  whitespace/newline/水平空白、digit 与反集、word 与反集、ASCII alnum/letter、
  Unicode `\p{L}`/`\p{N}`/`\p{P}`/`\p{S}`、punctuation-or-symbol union、
  anchored `^...+` / `...+$`、覆盖上述 class family 的精确 `{2..4}` 与最小
  `{2,}`/`{3,}`/`{4,}`、`^foo$` / `\\bfoo\\b` / `foo|bar` /
  `(foo)` / `(?:foo)` / `(?:foo|bar)` / ` {2,}` / `^(?:foo|bar)` /
  `(?:foo|bar)$` / `\\b(?:foo|bar)\\b` / `^\\b(?:foo|bar)\\b$`
  这类简单 literal / alternation，以及 bounded `{1,2}`/`{1,3}`/`{1,4}` 与 ranged
  `{2,3}`/`{2,4}`/`{3,4}` 等 HF 常见 tokenizer regex。Normalizer 与 Decoder
  `Replace` 对 bounded/ranged 量词保持直接分发路径，使合成 cleanup benchmark
  继续快于 HF。
- 加载的 `Replace` 组件会保留 HF tagged pattern 形态：`{String: ...}` 按字面量
  substring 替换，`{Regex: ...}` 才使用上面的 deterministic regex 子集。
  binding-friendly 的 `replace(...)` factory 创建字面量 string 形态；
  `replace_regex(...)` 创建 regex 形态。
- 未知复杂 Split regex 会在加载期显式报 Unsupported；未知 Replace pattern 保持
  轻量 fallback，按字面量子串替换处理。

## Encoding

```moonbit
pub(all) struct Encoding {
  ids : Array[Int]
  type_ids : Array[Int]
  tokens : Array[String]
  offsets : Array[(Int, Int)]
  special_tokens_mask : Array[Int]
  attention_mask : Array[Int]
  overflowing : Array[Encoding]
}

fn Encoding::get_ids(self : Encoding) -> Array[Int]
fn Encoding::get_type_ids(self : Encoding) -> Array[Int]
fn Encoding::get_tokens(self : Encoding) -> Array[String]
fn Encoding::get_offsets(self : Encoding) -> Array[(Int, Int)]
fn Encoding::get_special_tokens_mask(self : Encoding) -> Array[Int]
fn Encoding::get_attention_mask(self : Encoding) -> Array[Int]
fn Encoding::get_overflowing(self : Encoding) -> Array[Encoding]
fn Encoding::get_sequence_ids(self : Encoding) -> Array[Int?]
fn Encoding::get_word_ids(self : Encoding) -> Array[Int?]
fn Encoding::sequence_ids(self : Encoding) -> Array[Int?]
fn Encoding::word_ids(self : Encoding) -> Array[Int?]
fn Encoding::char_to_token_by_sequence_index(self : Encoding, pos : Int, sequence_index? : Int = 0) -> Int?
fn Encoding::char_to_word_by_sequence_index(self : Encoding, pos : Int, sequence_index? : Int = 0) -> Int?
fn Encoding::token_to_char_offsets(self : Encoding, token : Int) -> (Int, Int)?
fn Encoding::token_to_word_index(self : Encoding, token : Int) -> Int?
fn Encoding::word_to_tokens_by_sequence_index(self : Encoding, word : Int, sequence_index? : Int = 0) -> (Int, Int)?
fn Encoding::word_to_chars_by_sequence_index(self : Encoding, word : Int, sequence_index? : Int = 0) -> (Int, Int)?
fn Encoding::len(self : Encoding) -> Int
fn Encoding::is_empty(self : Encoding) -> Bool
fn Encoding::n_sequences(self : Encoding) -> Int
fn Encoding::new(
  ids : Array[Int], type_ids : Array[Int], tokens : Array[String],
  offsets : Array[(Int, Int)], special_tokens_mask : Array[Int], attention_mask : Array[Int],
  sequence_ids? : Array[Int?] = [], word_ids? : Array[Int?] = [], overflowing? : Array[Encoding] = [],
) -> Encoding raise TokenizerError
fn Encoding::with_type_ids(self : Encoding, type_ids : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_special_tokens_mask(self : Encoding, special_tokens_mask : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_attention_mask(self : Encoding, attention_mask : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_word_ids(self : Encoding, word_ids : Array[Int?]) -> Encoding raise TokenizerError
fn Encoding::with_sequence_id(self : Encoding, sequence_id : Int) -> Encoding raise TokenizerError
fn Encoding::truncate_hf(self : Encoding, max_len : Int, stride? : Int = 0, direction? : String = "right") -> Encoding raise TokenizerError
fn Encoding::pad_hf(
  self : Encoding, length : Int, direction? : String = "right",
  pad_id? : Int = 0, pad_type_id? : Int = 0, pad_token? : String = "[PAD]",
) -> Encoding raise TokenizerError
```

`get_*` 访问器返回数组副本，便于从 HF `Encoding` 迁移；`len`、`is_empty` 与
`n_sequences` 对齐 HF 的轻量元数据 helper。

`get_*` accessor 会返回数组副本，便于 HF `Encoding` 迁移，同时避免调用方修改
encoding 内部结果。`Encoding::merge` / `merge_with` 默认采用 HF 风格的
growing offsets；显式传 `growing_offsets=false` 可保留输入 offsets 不变。
interop constructor 和 replacement-array setter 会校验公开 parallel arrays
均与 `ids.length()` 一致；省略 `sequence_ids` / `word_ids` 时仍使用 HF 风格默认值，
但传入非空且长度不一致的数组会抛 `ParseError`。`set_sequence_id` /
`with_sequence_id` 会拒绝负数 sequence id。
`*_by_sequence_index` helper 是面向 binding 层的命名 alias，用来映射 HF 的
`sequence_index` 关键字，同时保留现有 MoonBit `sequence_id` API。
`token_to_char_offsets` 与 `token_to_word_index` 暴露 HF Python 的返回形态，
同时保留 MoonBit 现有信息更完整的 `token_to_chars` / `token_to_word` 方法。
`truncate_hf` / `pad_hf` 接受 HF 风格字符串方向和参数顺序，并委托已有 typed
MoonBit helper。非法 direction 字符串会抛错；`truncate_hf` 在 `stride >= max_len`
时也会抛错，对齐 HF 公开 wrapper 边界。

## TokenizerError

```moonbit
pub(all) suberror TokenizerError {
  ParseError(String)
  UnsupportedComponent(String)
  VocabError(String)
}
```
