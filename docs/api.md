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
- Programmatically constructed tokenizers serialize typed normalizer,
  pre-tokenizer, model, post-processor, decoder, truncation, padding and added
  token state when those components expose a typed serializer; loaded HF
  tokenizers still preserve their original JSON verbatim until a builder mutates
  typed state.

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
fn Tokenizer::new(model : @model.Model) -> Tokenizer
fn Tokenizer::with_normalizer(self : Tokenizer, normalizer : @normalizer.Normalizer?) -> Tokenizer
fn Tokenizer::with_pre_tokenizer(self : Tokenizer, pre_tokenizer : @pretokenizer.PreTokenizer?) -> Tokenizer
fn Tokenizer::with_model(self : Tokenizer, model : @model.Model) -> Tokenizer
fn Tokenizer::with_post_processor(self : Tokenizer, post_processor : @processor.PostProcessor?) -> Tokenizer
fn Tokenizer::with_decoder(self : Tokenizer, decoder : @decoder.Decoder?) -> Tokenizer
fn Tokenizer::with_truncation(self : Tokenizer, params : TruncationParams?) -> Tokenizer
fn Tokenizer::with_padding(self : Tokenizer, params : PaddingParams?) -> Tokenizer

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

Builders return a tokenizer and can be chained:
`Tokenizer::new(model).with_pre_tokenizer(..).with_decoder(..)`. They invalidate
the cached source JSON so constructed tokenizers serialize from typed state where
supported. Decoder and post-processor builders mirror common HF component
construction in tests or synthetic pipelines.

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
```

`add_tokens_with_count` / `add_special_tokens_with_count` return the number of
new ids allocated, matching HF's duplicate-aware count semantics. Existing model
tokens can still be registered as added/special tokens for extraction without
increasing the vocabulary size. Ordinary added tokens now keep
`special_tokens_mask=0`; only `special=true` entries set mask `1`.

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
  forms and ranged `{2,3}`/`{2,4}`/`{3,4}` runs. Normalizer and Decoder
  `Replace` keep hot bounded/ranged quantifier forms on direct dispatch paths
  so synthetic cleanup benchmarks stay faster than HF.
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

The `get_*` accessors return copied arrays, mirroring HF `Encoding` accessors
while keeping the encoded result immutable from caller code.

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
