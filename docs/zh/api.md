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
- `save_pretrained(dir)` 创建/复用 HF 风格目录并写出 `dir/tokenizer.json`，返回
  具体 JSON 路径，便于日志记录或后续 `from_file` 加载。

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
```

所有 `encode_*_with_byte_offsets` 变体返回 HF 风格 UTF-8 byte offsets。
pre-tokenized 输入会跳过 tokenizer 的 pre-tokenizer 阶段，但 normalizer、model、
post-processor、truncation 与 padding 仍会执行；offsets 按“归一化后的词用单个 ASCII
空格连接”得到的合成文本计算。传入词内部的 added/special token 仍会按 tokenizer 的
`single_word`、`lstrip`、`rstrip` 与 `normalized` 规则先切出，再把普通片段交给 model。

## 配置

```moonbit
fn Tokenizer::with_truncation(self : Tokenizer, params : TruncationParams?) -> Tokenizer
fn Tokenizer::with_padding(self : Tokenizer, params : PaddingParams?) -> Tokenizer
```

builder 返回 `self`，可链式调用。

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

fn Decoder::wordpiece(prefix~ : String = "##", cleanup~ : Bool = true) -> Decoder
fn Decoder::byte_fallback() -> Decoder
fn Decoder::ctc(
  pad_token~ : String = "<pad>", word_delimiter_token~ : String = "|", cleanup~ : Bool = true,
) -> Decoder
```

Decoder builder 用于在测试或合成 pipeline 中直接构造常见 HF decoder 配置。

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
  `{2,}`/`{3,}`/`{4,}`，以及 bounded `{1,2}`/`{1,3}`/`{1,4}` 与 ranged
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
fn Encoding::sequence_ids(self : Encoding) -> Array[Int?]
fn Encoding::word_ids(self : Encoding) -> Array[Int?]
```

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
