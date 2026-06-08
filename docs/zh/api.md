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
```

- `from_pretrained` 支持 tokenizer JSON 文件、本地含 `tokenizer.json` 的目录，
  以及已存在的 HuggingFace Hub 本地 cache（按 `$HUGGINGFACE_HUB_CACHE`、
  `$HF_HOME/hub`、`$HOME/.cache/huggingface/hub` 顺序解析）。核心库不做网络下载；
  稳定 pretrained source 会进入小型进程内 cache，优化重复加载。
- `from_pretrained_cached` 可显式传入本地 Hub cache 根目录和 revision，对齐
  HF `local_files_only=True` 的离线使用方式。

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

fn Tokenizer::decode(
  self : Tokenizer, ids : Array[Int], skip_special_tokens~ : Bool = true,
) -> String
```

## 配置

```moonbit
fn Tokenizer::with_truncation(self : Tokenizer, params : TruncationParams?) -> Tokenizer
fn Tokenizer::with_padding(self : Tokenizer, params : PaddingParams?) -> Tokenizer
```

builder 返回 `self`，可链式调用。

## 词表

```moonbit
fn Tokenizer::token_to_id(self : Tokenizer, token : String) -> Int?
fn Tokenizer::id_to_token(self : Tokenizer, id : Int) -> String?
fn Tokenizer::get_vocab_size(self : Tokenizer) -> Int
```

查询顺序：added/special vocabulary 优先，其次模型词表。

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
```

## TokenizerError

```moonbit
pub(all) suberror TokenizerError {
  ParseError(String)
  UnsupportedComponent(String)
  VocabError(String)
}
```
