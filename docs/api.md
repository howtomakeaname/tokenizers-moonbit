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
fn from_pretrained_downloaded(
  model_id : String, tokenizer_json : String, revision? : String = "main",
  resolved_revision? : String? = None, cache_dir? : String? = None,
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
- `from_pretrained_downloaded` is the transport bridge used by network-capable
  callers: pass downloaded `tokenizer.json` text and it writes the standard HF
  Hub cache layout before parsing. The optional `@hub` package provides native/js
  async HTTP downloading on top of this API; wasm users can keep host-side fetch
  logic and call this function with the fetched JSON.
- `save_pretrained(dir)` creates/uses an HF-style directory and writes
  `dir/tokenizer.json`, returning the concrete JSON path for logging or later
  `from_file` calls.
- Programmatically constructed tokenizers serialize typed normalizer,
  pre-tokenizer, model, post-processor, decoder, truncation, padding and added
  token state when those components expose a typed serializer; loaded HF
  tokenizers still preserve their original JSON verbatim until a builder mutates
  typed state.

### Optional Hub downloader (`@hub`, native/js)

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

async fn @hub.download_tokenizer_json(
  model_id : String, options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubDownloadResult raise TokenizerError
```

`@hub.from_pretrained` first tries the local file/cache path through the core
loader, then downloads `/<model>/resolve/<revision>/tokenizer.json` via
`moonbitlang/async/http`, follows redirects, stores the result in the HF-style
cache, and parses it. It supports custom endpoints/mirrors, explicit cache roots,
`HF_TOKEN` or an explicit bearer token, HF-style request headers, and
`local_files_only=true`. For users in regions where `huggingface.co` is slow,
pass a mirror endpoint, for example:

```moonbit
let tok = @hub.from_pretrained(
  "bert-base-uncased",
  options=@hub.HubDownloadOptions::new(endpoint="https://hf-mirror.com"),
)
```

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

fn Tokenizer::decode_batch(
  self : Tokenizer, batch : Array[Array[Int]], skip_special_tokens? : Bool = true,
) -> Array[String]

fn Tokenizer::decode_stream(
  self : Tokenizer, skip_special_tokens? : Bool = true,
) -> DecodeStream

fn DecodeStream::step(self : DecodeStream, id : Int) -> (DecodeStream, String?)
```

All `encode_*_with_byte_offsets` variants return HF-style UTF-8 byte offsets.
For pre-tokenized inputs, offsets are measured against a synthetic normalized
text formed by joining normalized words with one ASCII space; the tokenizer's
pre-tokenizer stage is skipped, while normalizer, model, post-processor,
truncation and padding still run. Added/special tokens embedded in a provided
word are still extracted with the tokenizer's `single_word`, `lstrip`, `rstrip`
and `normalized` rules before ordinary spans go to the model.

`decode_stream` mirrors HF's incremental decoder for token-by-token streaming.
Each `step` returns a new stream plus `Some(chunk)` when the buffered ids decode
to a valid text extension, or `None` for incomplete byte-fallback / decoder
context.

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
fn SpecialToken::new(id : String, ids : Array[Int], tokens : Array[String]) -> SpecialToken
fn PostProcessor::template_from_strings(
  single : String, pair : String, special_tokens : Map[String, SpecialToken],
) -> PostProcessor raise TokenizerError
```

Builders return a tokenizer and can be chained:
`Tokenizer::new(model).with_pre_tokenizer(..).with_decoder(..)`. They invalidate
the cached source JSON so constructed tokenizers serialize from typed state where
supported. Decoder and post-processor builders mirror common HF component
construction in tests or synthetic pipelines.
`template_from_strings` accepts the same `$A` / `$B` / `$0:1` HF template DSL
used in tokenizer.json files, and `SpecialToken::new` supports multi-id special
tokens.

`set_encode_special_tokens(true)` mirrors HF's `encode_special_tokens` switch:
special tokens that appear in input text stay on the ordinary model path instead
of being extracted as special added tokens. `post_process` exposes the configured
post-processor for already-built encodings, and `num_special_tokens_to_add`
reports how many special tokens would be injected for single or pair inputs.

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

`add_tokens_with_count` / `add_special_tokens_with_count` return the number of
new ids allocated, matching HF's duplicate-aware count semantics. Existing model
tokens can still be registered as added/special tokens for extraction without
increasing the vocabulary size. Ordinary added tokens now keep
`special_tokens_mask=0`; only `special=true` entries set mask `1` unless
`encode_special_tokens` is enabled, in which case special token strings found in
input text are encoded as ordinary model tokens. `get_added_tokens_decoder`
returns HF-style `id -> AddedToken` metadata for migration and introspection.

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
  quantifiers across those class families, grouped literals and simple literal
  alternatives such as `(?:foo)` / `foo|bar` / `(?:foo|bar)`, the
  SentencePiece-style ASCII space run ` {2,}`, plus anchored/word-boundary
  forms like
  `^foo$` / `\\bfoo\\b` / `^(?:foo|bar)` / `(?:foo|bar)$` /
  `\\b(?:foo|bar)\\b` / `^\\b(?:foo|bar)\\b$`, bounded
  `{1,2}`/`{1,3}`/`{1,4}` forms and ranged `{2,3}`/`{2,4}`/`{3,4}`
  runs. Normalizer and Decoder
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
fn Encoding::get_sequence_ids(self : Encoding) -> Array[Int?]
fn Encoding::get_word_ids(self : Encoding) -> Array[Int?]
fn Encoding::sequence_ids(self : Encoding) -> Array[Int?]
fn Encoding::word_ids(self : Encoding) -> Array[Int?]
fn Encoding::len(self : Encoding) -> Int
fn Encoding::is_empty(self : Encoding) -> Bool
fn Encoding::n_sequences(self : Encoding) -> Int

pub(all) enum EncodingDirection { Left; Right }
fn Encoding::new(
  ids : Array[Int], type_ids : Array[Int], tokens : Array[String],
  offsets : Array[(Int, Int)], special_tokens_mask : Array[Int], attention_mask : Array[Int],
  sequence_ids? : Array[Int?] = [], word_ids? : Array[Int?] = [], overflowing? : Array[Encoding] = [],
) -> Encoding
fn Encoding::from_tokens(tokens : Array[Token], type_id? : Int = 0) -> Encoding
fn Encoding::with_type_ids(self : Encoding, type_ids : Array[Int]) -> Encoding
fn Encoding::with_special_tokens_mask(self : Encoding, special_tokens_mask : Array[Int]) -> Encoding
fn Encoding::with_attention_mask(self : Encoding, attention_mask : Array[Int]) -> Encoding
fn Encoding::with_word_ids(self : Encoding, word_ids : Array[Int?]) -> Encoding
fn Encoding::with_sequence_id(self : Encoding, sequence_id : Int) -> Encoding
fn Encoding::with_overflowing(self : Encoding, overflowing : Array[Encoding]) -> Encoding
fn Encoding::take_overflowing(self : Encoding) -> (Encoding, Array[Encoding])
fn Encoding::truncate(self : Encoding, max_len : Int, stride? : Int = 0, direction? : EncodingDirection = Right) -> Encoding
fn Encoding::pad(
  self : Encoding, target_length : Int, pad_id? : Int = 0, pad_type_id? : Int = 0,
  pad_token? : String = "[PAD]", direction? : EncodingDirection = Right,
) -> Encoding
fn Encoding::merge(encodings : Array[Encoding], growing_offsets? : Bool = false) -> Encoding
fn Encoding::merge_with(self : Encoding, pair : Encoding, growing_offsets? : Bool = false) -> Encoding
```

The `get_*` accessors return copied arrays, mirroring HF `Encoding` accessors
while keeping the encoded result immutable from caller code. `len`, `is_empty`
and `n_sequences` cover HF's lightweight encoding metadata helpers. Public
manipulation helpers mirror HF's `Encoding` API but return updated values instead
of mutating in place.

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
