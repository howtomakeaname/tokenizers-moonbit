# API Reference

All public types live in the `@tokenizer` package, with shared types in
`@types`. Signatures below use MoonBit notation.

Chinese version: [`docs/zh/api.md`](./zh/api.md)

## Loading

```moonbit
fn Tokenizer::from_str(json : String) -> Tokenizer raise TokenizerError
fn from_file(path : String) -> Tokenizer raise TokenizerError
fn from_pretrained(path_or_model_id : String) -> Tokenizer raise TokenizerError
fn from_pretrained_cached(
  model_id : String, revision? : String = "main", cache_dir? : String? = None,
) -> Tokenizer raise TokenizerError
fn Tokenizer::save_pretrained(self : Tokenizer, dir : String) -> String raise TokenizerError
```

- `from_str` parses `tokenizer.json` text; it does no file IO and works on all backends.
  A small multi-entry parsed-JSON cache keeps repeated or alternating stable
  tokenizer payloads hot while still returning fresh tokenizer state.
- `from_file` reads via `moonbitlang/x/fs` and then calls `from_str`.
- `from_pretrained` accepts a tokenizer JSON file, a local directory containing
  `tokenizer.json`, or an already-populated HuggingFace Hub cache entry. It does
  not perform network downloads; it resolves `$HUGGINGFACE_HUB_CACHE`,
  `$HF_HOME/hub`, then `$HOME/.cache/huggingface/hub`. Stable pretrained sources
  are kept in a small in-process FIFO cache for repeated loads. Offline
  resolution errors distinguish missing JSON files, local directories without
  `tokenizer.json`, and model ids that are absent from the local Hub cache.
- `from_pretrained_cached` lets callers provide an explicit local Hub cache root
  and revision, matching offline `local_files_only=True` workflows.
- `save_pretrained(dir)` creates/uses an HF-style directory and writes
  `dir/tokenizer.json`, returning the concrete JSON path for logging or later
  `from_file` calls.

## Encoding / decoding

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

All `encode_*_with_byte_offsets` variants return HF-style UTF-8 byte offsets.
For pre-tokenized inputs, offsets are measured against a synthetic normalized
text formed by joining normalized words with one ASCII space; the tokenizer's
pre-tokenizer stage is skipped, while normalizer, model, post-processor,
truncation and padding still run. Added/special tokens embedded in a provided
word are still extracted with the tokenizer's `single_word`, `lstrip`, `rstrip`
and `normalized` rules before ordinary spans go to the model.

## Configuration builders

```moonbit
fn Tokenizer::with_truncation(self : Tokenizer, params : TruncationParams?) -> Tokenizer
fn Tokenizer::with_padding(self : Tokenizer, params : PaddingParams?) -> Tokenizer
```

Builders mutate and return `self`, so they can be chained:
`from_str(j).with_padding(..)`.

## Vocabulary

```moonbit
fn Tokenizer::token_to_id(self : Tokenizer, token : String) -> Int?
fn Tokenizer::id_to_token(self : Tokenizer, id : Int) -> String?
fn Tokenizer::get_vocab_size(self : Tokenizer) -> Int
```

Lookups consult the added/special vocabulary first, then the model vocabulary.

## Component compatibility notes

- `Normalizer::Replace`, `Decoder::Replace`, and regex `PreTokenizer::Split`
  share the same deterministic scanner for common HF regex families instead of
  relying on a backend-specific regex engine. Covered fast paths include
  whitespace/newline/horizontal whitespace, digit and inverse digit runs, word
  and inverse word runs, ASCII alnum/letter classes, Unicode
  `\p{L}`/`\p{N}`/`\p{P}`/`\p{S}` classes, punctuation-or-symbol unions,
  anchored `^...+` / `...+$`, exact `{2..4}` and minimum `{2,}`/`{3,}`/`{4,}`
  quantifiers across those class families, plus bounded `{1,2}`/`{1,3}`/`{1,4}`
  forms and ranged `{2,3}`/`{2,4}`/`{3,4}` runs.
- Unknown complex Split regexes are rejected during loading; unknown Replace
  patterns keep the existing lightweight fallback and are treated as literal
  substring replacements.

## Types

### Encoding (`@types`)

```moonbit
pub(all) struct Encoding {
  ids : Array[Int]
  type_ids : Array[Int]
  tokens : Array[String]
  offsets : Array[(Int, Int)]          // char offsets
  special_tokens_mask : Array[Int]
  attention_mask : Array[Int]
  overflowing : Array[Encoding]        // truncation stride windows
}
```

### TruncationParams (`@tokenizer`)

```moonbit
pub(all) enum TruncationDirection { Left; Right }
pub(all) enum TruncationStrategy { LongestFirst; OnlyFirst; OnlySecond }
pub(all) struct TruncationParams {
  max_length : Int
  stride : Int
  direction : TruncationDirection
  strategy : TruncationStrategy
}
fn TruncationParams::new(max_length : Int) -> TruncationParams  // stride 0, Right
fn TruncationParams::with_stride(self : TruncationParams, stride : Int) -> TruncationParams
fn TruncationParams::with_direction(self : TruncationParams, direction : TruncationDirection) -> TruncationParams
fn TruncationParams::with_strategy(self : TruncationParams, strategy : TruncationStrategy) -> TruncationParams
```

### PaddingParams (`@tokenizer`)

```moonbit
pub(all) enum PaddingStrategy { BatchLongest; Fixed(Int) }
pub(all) enum PaddingDirection { Left; Right }
pub(all) struct PaddingParams {
  strategy : PaddingStrategy
  direction : PaddingDirection
  pad_id : Int
  pad_type_id : Int
  pad_token : String
  pad_to_multiple_of : Int?
}
fn PaddingParams::new(
  strategy : PaddingStrategy, pad_id~ : Int = 0, pad_token~ : String = "[PAD]",
) -> PaddingParams
fn PaddingParams::fixed(length : Int, pad_id~ : Int = 0, pad_token~ : String = "[PAD]") -> PaddingParams
fn PaddingParams::batch_longest(pad_id~ : Int = 0, pad_token~ : String = "[PAD]") -> PaddingParams
fn PaddingParams::with_direction(self : PaddingParams, direction : PaddingDirection) -> PaddingParams
fn PaddingParams::with_pad_type_id(self : PaddingParams, pad_type_id : Int) -> PaddingParams
fn PaddingParams::with_pad_to_multiple_of(self : PaddingParams, pad_to_multiple_of : Int?) -> PaddingParams
```

### TokenizerError (`@types`)

```moonbit
pub(all) suberror TokenizerError {
  ParseError(String)            // malformed / unexpected tokenizer.json
  UnsupportedComponent(String)  // component type not yet implemented
  VocabError(String)            // malformed vocab / merges
}
```
