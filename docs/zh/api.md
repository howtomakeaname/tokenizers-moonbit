# API 参考

公开 tokenizer API 位于 `@tokenizer` 包，共享类型位于 `@types`。

英文版：[`../api.md`](../api.md)

## 加载

```moonbit
fn Tokenizer::from_str(json : String) -> Tokenizer raise TokenizerError
fn from_file(path : String) -> Tokenizer raise TokenizerError
fn from_pretrained(path_or_model_id : String) -> Tokenizer raise TokenizerError
fn from_pretrained_cached(
  model_id : String, revision? : String = "main", cache_dir? : String? = None,
) -> Tokenizer raise TokenizerError
fn from_pretrained_downloaded(
  model_id : String, tokenizer_json : String, revision? : String = "main",
  resolved_revision? : String? = None, cache_dir? : String? = None,
) -> Tokenizer raise TokenizerError
fn Tokenizer::save_pretrained(self : Tokenizer, dir : String) -> String raise TokenizerError
```

- `from_pretrained` 支持 tokenizer JSON 文件、本地含 `tokenizer.json` 的目录，
  以及已存在的 HuggingFace Hub 本地 cache（按 `$HUGGINGFACE_HUB_CACHE`、
  `$HF_HOME/hub`、`$HOME/.cache/huggingface/hub` 顺序解析）。核心库不做网络下载；
  稳定 pretrained source 会进入小型进程内 FIFO cache，优化重复加载。离线解析失败时会区分
  JSON 文件缺失、本地目录缺少 `tokenizer.json`、以及 model id 未命中本地 Hub cache。
- `from_str` 使用小型多项 parsed-JSON cache，重复或交替加载稳定
  tokenizer payload 时避免重复 JSON 解析，同时每次仍返回全新的 tokenizer 状态。
- `from_pretrained_cached` 可显式传入本地 Hub cache 根目录和 revision，对齐
  HF `local_files_only=True` 的离线使用方式。
- `from_pretrained_downloaded` 用于网络调用方桥接：传入已下载的 `tokenizer.json`
  文本后写入标准 HF Hub cache 布局并立即解析。可选 `@hub` 包基于它在 native/js
  后端提供异步 HTTP 下载；wasm 场景可由宿主 fetch 后调用该函数。
- `save_pretrained(dir)` 创建/复用 HF 风格目录并写出 `dir/tokenizer.json`，返回
  具体 JSON 路径，便于日志记录或后续 `from_file` 加载。
- 程序化构造的 tokenizer 会序列化已支持 typed serializer 的 normalizer、
  pre-tokenizer、model、post-processor、decoder、truncation、padding 与 added token
  状态；从 HF JSON 加载的 tokenizer 在 builder 修改 typed state 前仍保持原始 JSON
  原样往返。

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
) -> HubDownloadOptions

async fn @hub.from_pretrained(
  model_id : String, options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> Tokenizer raise TokenizerError
```

`@hub.from_pretrained` 会先尝试本地文件/cache，未命中时通过
`moonbitlang/async/http` 下载 `/<model>/resolve/<revision>/tokenizer.json`，跟随
redirect，写入 HF 风格 cache 后复用核心 loader。支持自定义 endpoint/mirror、显式
cache 根目录、`HF_TOKEN` 或显式 bearer token、HF 风格请求 headers，以及
`local_files_only=true`。中国大陆用户可显式配置镜像：

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
) -> Encoding

fn Tokenizer::encode_pair(
  self : Tokenizer, text_a : String, text_b : String,
  add_special_tokens~ : Bool = true,
) -> Encoding

fn Tokenizer::encode_batch(
  self : Tokenizer, texts : Array[String], add_special_tokens~ : Bool = true,
) -> Array[Encoding]

fn Tokenizer::encode_pair_batch(
  self : Tokenizer, pairs : Array[(String, String)], add_special_tokens~ : Bool = true,
) -> Array[Encoding]

fn Tokenizer::encode_pretokenized(
  self : Tokenizer, words : Array[String], add_special_tokens~ : Bool = true,
) -> Encoding

fn Tokenizer::encode_pretokenized_pair(
  self : Tokenizer, words_a : Array[String], words_b : Array[String],
  add_special_tokens~ : Bool = true,
) -> Encoding

fn Tokenizer::encode_pretokenized_batch(
  self : Tokenizer, batch : Array[Array[String]], add_special_tokens~ : Bool = true,
) -> Array[Encoding]

fn Tokenizer::encode_pretokenized_pair_batch(
  self : Tokenizer, batch : Array[(Array[String], Array[String])],
  add_special_tokens~ : Bool = true,
) -> Array[Encoding]

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

所有 `encode_*_with_byte_offsets` 变体返回 HF 风格 UTF-8 byte offsets。
pre-tokenized 输入会跳过 tokenizer 的 pre-tokenizer 阶段，但 normalizer、model、
post-processor、truncation 与 padding 仍会执行；offsets 按“归一化后的词用单个 ASCII
空格连接”得到的合成文本计算。传入词内部的 added/special token 仍会按 tokenizer 的
`single_word`、`lstrip`、`rstrip` 与 `normalized` 规则先切出，再把普通片段交给 model。

`decode_stream` 对齐 HF 的增量解码器，用于 token-by-token streaming。每次 `step`
返回新的 stream 和可选输出：当缓冲 ids 已经能解出有效文本增量时返回 `Some(chunk)`，
遇到未完成的 byte-fallback / decoder 上下文时返回 `None`。

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

fn Tokenizer::get_normalizer(self : Tokenizer) -> @normalizer.Normalizer?
fn Tokenizer::get_pre_tokenizer(self : Tokenizer) -> @pretokenizer.PreTokenizer?
fn Tokenizer::get_model(self : Tokenizer) -> @model.Model
fn Tokenizer::get_post_processor(self : Tokenizer) -> @processor.PostProcessor?
fn Tokenizer::get_decoder(self : Tokenizer) -> @decoder.Decoder?
fn Tokenizer::get_truncation(self : Tokenizer) -> TruncationParams?
fn Tokenizer::get_padding(self : Tokenizer) -> PaddingParams?

fn Tokenizer::set_encode_special_tokens(self : Tokenizer, value : Bool) -> Tokenizer
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

```moonbit
fn TruncationParams::new(max_length : Int) -> TruncationParams
fn TruncationParams::with_stride(self : TruncationParams, stride : Int) -> TruncationParams
fn TruncationParams::with_direction(self : TruncationParams, direction : TruncationDirection) -> TruncationParams
fn TruncationParams::with_strategy(self : TruncationParams, strategy : TruncationStrategy) -> TruncationParams

fn PaddingParams::new(
  strategy : PaddingStrategy, pad_id~ : Int = 0, pad_token~ : String = "[PAD]",
) -> PaddingParams
fn PaddingParams::fixed(length : Int, pad_id~ : Int = 0, pad_token~ : String = "[PAD]") -> PaddingParams
fn PaddingParams::batch_longest(pad_id~ : Int = 0, pad_token~ : String = "[PAD]") -> PaddingParams
fn PaddingParams::with_direction(self : PaddingParams, direction : PaddingDirection) -> PaddingParams
fn PaddingParams::with_pad_type_id(self : PaddingParams, pad_type_id : Int) -> PaddingParams
fn PaddingParams::with_pad_to_multiple_of(self : PaddingParams, pad_to_multiple_of : Int?) -> PaddingParams

fn Decoder::wordpiece(prefix? : String = "##", cleanup? : Bool = true) -> Decoder
fn Decoder::byte_fallback() -> Decoder
fn Decoder::ctc(
  pad_token? : String = "<pad>", word_delimiter_token? : String = "|", cleanup? : Bool = true,
) -> Decoder

fn PostProcessor::bert(sep : (String, Int), cls : (String, Int)) -> PostProcessor
fn PostProcessor::roberta(
  sep : (String, Int), cls : (String, Int),
  trim_offsets? : Bool = true, add_prefix_space? : Bool = true,
) -> PostProcessor
```

Decoder / PostProcessor builder 用于在测试或合成 pipeline 中直接构造常见 HF 配置。
`set_encode_special_tokens(true)` 对齐 HF 的 `encode_special_tokens` 开关：输入文本中出现的
special token 不再被提前抽取为 special added token，而是留在普通 model 路径上。
`post_process` 可对已构造的 encoding 显式应用当前 post-processor；
`num_special_tokens_to_add` 返回单句或句对会额外插入的 special token 数量。

## Added tokens

```moonbit
fn AddedToken::new(content : String) -> AddedToken
fn AddedToken::special(content : String) -> AddedToken
fn AddedToken::with_single_word(self : AddedToken, single_word : Bool) -> AddedToken
fn AddedToken::with_lstrip(self : AddedToken, lstrip : Bool) -> AddedToken
fn AddedToken::with_rstrip(self : AddedToken, rstrip : Bool) -> AddedToken
fn AddedToken::with_normalized(self : AddedToken, normalized : Bool) -> AddedToken
fn AddedToken::with_special(self : AddedToken, special : Bool) -> AddedToken

fn Tokenizer::add_tokens(self : Tokenizer, tokens : Array[AddedToken]) -> Tokenizer
fn Tokenizer::add_tokens_with_count(self : Tokenizer, tokens : Array[AddedToken]) -> (Tokenizer, Int)
fn Tokenizer::add_token_strings(self : Tokenizer, tokens : Array[String]) -> Tokenizer
fn Tokenizer::add_special_tokens(self : Tokenizer, tokens : Array[AddedToken]) -> Tokenizer
fn Tokenizer::add_special_tokens_with_count(self : Tokenizer, tokens : Array[AddedToken]) -> (Tokenizer, Int)
fn Tokenizer::add_special_token_strings(self : Tokenizer, tokens : Array[String]) -> Tokenizer
fn Tokenizer::get_added_tokens_decoder(self : Tokenizer) -> Map[Int, AddedToken]
fn Tokenizer::is_special_token(self : Tokenizer, token : String) -> Bool
```

`*_with_count` 返回新分配 id 的数量，对齐 HF 对重复 token 的计数语义；已存在于
model 词表的 token 也可以注册为 added/special token 用于预切分，但不会增加词表大小。
普通 added token 的 `special_tokens_mask=0`，只有 `special=true` 的条目会标为 `1`；若启用
`encode_special_tokens`，输入文本中的 special token 字符串会作为普通 model token 编码。
`get_added_tokens_decoder` 返回 HF 风格的 `id -> AddedToken` 元数据，便于迁移和调试。

## 词表

```moonbit
fn Tokenizer::token_to_id(self : Tokenizer, token : String) -> Int?
fn Tokenizer::id_to_token(self : Tokenizer, id : Int) -> String?
fn Tokenizer::get_vocab_size(self : Tokenizer) -> Int
```

查询顺序：added/special vocabulary 优先，其次模型词表。

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
fn Encoding::len(self : Encoding) -> Int
fn Encoding::is_empty(self : Encoding) -> Bool
fn Encoding::n_sequences(self : Encoding) -> Int
```

`get_*` 访问器返回数组副本，便于从 HF `Encoding` 迁移；`len`、`is_empty` 与
`n_sequences` 对齐 HF 的轻量元数据 helper。

`get_*` accessor 会返回数组副本，便于 HF `Encoding` 迁移，同时避免调用方修改
encoding 内部结果。

## TokenizerError

```moonbit
pub(all) suberror TokenizerError {
  ParseError(String)
  UnsupportedComponent(String)
  VocabError(String)
}
```
