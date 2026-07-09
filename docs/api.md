# API Reference

All public types live in the `@tokenizer` package, with shared types in
`@types`. Signatures below use MoonBit notation.

Chinese version: [`docs/zh/api.md`](./zh/api.md)

## Loading

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
) -> Tokenizer raise TokenizerError
fn Tokenizer::to_str(self : Tokenizer, pretty? : Bool = false) -> String raise TokenizerError
fn Tokenizer::save(self : Tokenizer, path : String, pretty? : Bool = true) -> Unit raise TokenizerError
fn Tokenizer::save_pretrained(
  self : Tokenizer, dir : String, pretty? : Bool = false,
  save_model? : Bool = false, model_prefix? : String = "",
) -> String raise TokenizerError
```

- `from_str` parses `tokenizer.json` text; it does no file IO and works on all backends.
  A small multi-entry parsed-JSON cache keeps repeated or alternating stable
  tokenizer payloads hot while still returning fresh tokenizer state.
- `from_buffer` parses UTF-8 bytes, and `from_file` reads via `moonbitlang/x/fs`
  before calling `from_str`.
- `from_pretrained` accepts a tokenizer JSON file, a local directory containing
  `tokenizer.json`, or an already-populated HuggingFace Hub cache entry. It does
  not perform network downloads; it resolves `$HUGGINGFACE_HUB_CACHE`,
  `$HF_HUB_CACHE`, `$HF_HOME/hub`, then `$HOME/.cache/huggingface/hub`.
  Stable pretrained sources are kept in a small in-process FIFO cache for repeated loads. Offline
  resolution errors distinguish missing JSON files, local directories without
  `tokenizer.json`, and model ids that are absent from the local Hub cache.
- `from_pretrained_cached` lets callers provide an explicit local Hub cache root
  and revision, matching offline `local_files_only=True` workflows.
- `from_pretrained_downloaded` is the transport bridge used by network-capable
  callers: pass downloaded `tokenizer.json` text and it writes the standard HF
  Hub cache layout before parsing. The optional `@hub` package provides native/js
  async HTTP downloading on top of this API; wasm users can keep host-side fetch
  logic and call this function with the fetched JSON.
- `from_pretrained_aux_file(path, filename)` and
  `from_pretrained_aux_file_path(path, filename)` resolve tokenizer-adjacent
  sidecar files such as `added_tokens.json` without interpreting their content.
  `cache_pretrained_aux_file(model_id, filename, content, ...)` writes raw
  sidecar content into the simplified HF-compatible refs/snapshots cache so the
  same aux readers can resolve it later.
- `to_str(pretty)` defaults to compact/verbatim JSON. `save(path, pretty)`
  follows HF `Tokenizer.save` and defaults to two-space pretty output; pass
  `pretty=false` for exact compact/verbatim bytes. `save_pretrained(dir, pretty)`
  keeps its compact default and can also write model sidecar artifacts next to
  `tokenizer.json` with `save_model=true`.
- Programmatically constructed tokenizers serialize typed normalizer,
  pre-tokenizer, model, post-processor, decoder, truncation, padding and added
  token state when those components expose a typed serializer; loaded HF
  tokenizers still preserve their original JSON verbatim until a builder mutates
  typed state.

### Standalone model artifacts (`@model`)

```moonbit
fn Model::save(self : Model, folder : String, prefix? : String = "") -> Array[String] raise TokenizerError
fn Model::from_bpe_files(
  vocab_path : String, merges_path : String, unk_token? : String? = Some("[UNK]"),
  continuing_subword_prefix? : String? = None, end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false, byte_fallback? : Bool = false,
  ignore_merges? : Bool = false, dropout? : Double? = None,
) -> Model raise TokenizerError
fn Model::from_wordpiece_file(
  vocab_path : String, unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##", end_of_word_suffix? : String? = None,
  max_input_chars_per_word? : Int = 100,
) -> Model raise TokenizerError
fn Model::from_wordlevel_file(
  vocab_path : String, unk_token? : String = "[UNK]",
) -> Model raise TokenizerError
fn Model::from_unigram_file(vocab_path : String) -> Model raise TokenizerError
```

`Model::save` writes HF-style standalone artifacts for BPE (`vocab.json` +
`merges.txt`), WordPiece (`vocab.txt`), WordLevel (`vocab.json`), and a compact
score-preserving Unigram JSON artifact. The standalone loaders read those common
HF artifact formats back into typed models, including saved Unigram JSON
fragments; BPE merge files skip `#version:` comment lines and use the same
legacy merge splitting semantics as tokenizer JSON loading.

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
token discovery via `HF_TOKEN_PATH` / `$HF_HOME/token`, and
`local_files_only=true`. `HF_ENDPOINT` supplies the default endpoint when set,
and truthy `HF_HUB_OFFLINE` values (`1`, `true`, `yes`, `on`) default hub
options to local-only mode unless options override them. For users in regions
where `huggingface.co` is slow, pass a mirror endpoint, for example:

`hub_file_url` and `plan_hub_file_request` expose the same URL revision encoding
and request headers for tokenizer-adjacent sidecar files such as
`tokenizer_config.json`, `special_tokens_map.json`, or `added_tokens.json`;
sidecar plans intentionally do not attach tokenizer cache/range metadata.
`apply_hub_file_download_result` can cache a complete sidecar response body as
raw snapshot content, and `download_hub_file` can perform a simple 2xx-only GET
for a tokenizer-adjacent sidecar. Sidecar auto-download from
`from_pretrained`, ETag/Range/resume decisions, and sidecar content parsing
remain intentionally out of scope for these helpers.

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

Fast encode variants (`encode_fast`, `encode_batch_fast`,
`encode_sequence_input_fast`, `encode_input_fast`, `encode_input_batch_fast`,
and `batch_encode_plus_fast`) keep ids/tokens/masks/sequence metadata aligned
with regular encode paths while zeroing offsets. Async-compatible aliases
(`async_encode`, `async_encode_fast`, `async_encode_batch`,
`async_encode_batch_fast`, `async_decode`, `async_decode_batch`) delegate to the
same deterministic synchronous implementation on every target.

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
fn Tokenizer::enable_truncation(
  self : Tokenizer, max_length : Int, stride? : Int = 0,
  strategy? : TruncationStrategy = LongestFirst,
  direction? : TruncationDirection = Right,
) -> Tokenizer
fn Tokenizer::no_truncation(self : Tokenizer) -> Tokenizer
fn Tokenizer::enable_padding(
  self : Tokenizer, length? : Int? = None, direction? : PaddingDirection = Right,
  pad_id? : Int = 0, pad_type_id? : Int = 0, pad_token? : String = "[PAD]",
  pad_to_multiple_of? : Int? = None,
) -> Tokenizer
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
post-processor for already-built encodings. With `add_special_tokens=false`, it
matches HF by skipping special-token insertion while still applying non-special
post-processing effects such as ByteLevel/RoBERTa offset trimming. Use this
tokenizer-level entry for Python binding parity; the low-level
`PostProcessor::process` method keeps its compact native signature. The
`num_special_tokens_to_add` helper reports how many special tokens would be
injected for single or pair inputs.
The same count is also available on `PostProcessor` as
`num_special_tokens_to_add(is_pair)` for HF Python binding parity.

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
`AddedToken::new` accepts HF-style keyword defaults; when `special=true` and
`normalized` is omitted it defaults to `false`, matching HF's constructor.
`AddedToken::__str__()` returns the token content and `__repr__()` returns a
stable HF-style configuration summary.
Low-level `Token` and `Split` values also expose `__str__()` as their surface
value and `__repr__()` as a compact escaped diagnostic summary.

## Vocabulary

```moonbit
fn Tokenizer::token_to_id(self : Tokenizer, token : String) -> Int?
fn Tokenizer::id_to_token(self : Tokenizer, id : Int) -> String?
fn Tokenizer::get_vocab_size(self : Tokenizer) -> Int
```

Lookups consult the added/special vocabulary first, then the model vocabulary.

## Low-level migration API

`NormalizedString` exposes HF-style helpers for thin binding layers:
`get` / `normalized` / `to_string`, `get_original` / `original`, `len` /
`__len__`, `is_empty`, state/tuple round-trips, `normalize`, `replace`,
`prepend`, `append`, `clear`, `lowercase`, `uppercase`, `lstrip`, `rstrip`,
`strip`, `nfc`, `nfd`, `nfkc`, `nfkd`, `slice`, `map`, `filter`, literal
`split`, supported deterministic `split_regex`, single-index `get_item` /
`__getitem__`, and `__str__` / `__repr__` display aliases.

`PreTokenizedString` provides `get_splits` / `splits`, single-index
`get_item` / `__getitem__`, `normalize`, pre-tokenizer `split`, state/tuple
helpers, and `to_encoding` / `into_encoding`.

`PreTokenizer::pre_tokenize_str(text)` returns HF-style `(value, offsets)` tuples
for quick component-level checks and binding shims.
`PreTokenizer::byte_level_alphabet()` mirrors HF ByteLevel.alphabet and returns
the same 256-symbol table as `@pretokenizer.byte_level_alphabet()`.
`PreTokenizer` also exposes read-only configuration getters for binding layers,
including ByteLevel flags, Metaspace settings, Split/Punctuation behavior,
Digits/Delimiter/FixedLength settings, and Sequence children.
Sequence pre-tokenizers support `__len__`, `get_item`, and `__getitem__`.
It also provides lower-snake builder aliases for common HF constructors such as
`whitespace`, `metaspace`, `punctuation`, `digits`,
`byte_level` (default `add_prefix_space=true`), `char_delimiter_split`,
`split` (`invert=false`, `regex=false` by default), `fixed_length`,
`unicode_scripts`, and `sequence`.
`Normalizer::normalize_str(input)` is available as an HF-style alias for
`normalize(input)`.
`Normalizer` also exposes read-only configuration getters for binding layers,
including `kind`, Strip left/right flags, Replace pattern/content, Prepend
content, BertNormalizer flags, and Sequence child normalizers.
It also provides lower-snake builder aliases for common typed constructors such
as `nfc`, `nfd`, `nfkc`, `nfkd`, `byte_level`, `strip`, `replace`,
`prepend_normalizer`, `bert_normalizer`, `lowercase_normalizer`,
`strip_accents_normalizer`, `nmt`, `precompiled`, and `sequence`.
`Decoder` exposes read-only configuration getters for binding layers, including
ByteLevel flags, WordPiece prefix/cleanup, Metaspace settings, BPEDecoder
suffix, Strip/Replace settings, CTC settings, Sequence children, and
Sequence access via `__len__` / `get_item` / `__getitem__`.
It also provides lower-snake builder aliases for common HF constructors such as
`byte_level`, `bpe_decoder`, `strip`, `fuse`, and `sequence`.
`PostProcessor` exposes read-only configuration getters for binding layers,
including Bert/Roberta special token pairs, ByteLevel/Roberta flags,
TemplateProcessing typed pieces and special tokens, and Sequence processors.
HF class-name style constructor aliases are also available:
`bert_processing`, `roberta_processing`, and `template_processing`.
TemplateProcessing exposes typed `single()` and `pair()` aliases for its
templates.
`Piece` exposes `kind` / `get_kind`, `id` / `get_id`, `type_id` /
`get_type_id`, and tuple interop for SequenceRef /
SpecialTokenRef template leaves, plus `__str__` / `__repr__` display aliases.
`SpecialToken` exposes tuple interop plus copy-returning `id` / `ids` / `tokens`
getters and `__str__` / `__repr__`.
Sequence post-processors support `__len__`, `get_item`, and `__getitem__`.
`Normalizer`, `PreTokenizer`, `Decoder`, and `PostProcessor` also expose
JSON-backed `get_state` / `from_state` / `__getstate__` / `__setstate__` plus
`__str__` / `__repr__` aliases. Components without a serialized JSON form report
an unsupported-component error instead of returning lossy state.

`Encoding::words()` is available as a deprecated HF Python alias for
`word_ids()`. `Encoding::__str__()` / `__repr__()` return the HF-style compact diagnostic
summary with token count and exposed attribute names.

`Trainer` exposes copy-returning configuration getters such as `kind`,
`unk_token`, `min_frequency`, `special_tokens`, `special_added_tokens`,
`vocab_size`, `show_progress`, and model-specific knobs for WordPiece, BPE and
Unigram trainers. Binding layers can also use lower-snake constructor aliases:
`wordlevel_trainer`, `wordpiece_trainer`, `bpe_trainer`, and
`unigram_trainer`. The default `vocab_size` caps match HF across typed
constructors, lower-snake aliases, model-level training helpers, and tokenizer
training convenience helpers: WordLevel, WordPiece, and BPE default to
`Some(30000)`, while Unigram defaults to `Some(8000)`. Passing
`vocab_size=None` keeps training uncapped. BPE trainers also preserve
`progress_format` as configuration
state (`"indicatif"`, `"json"`, or `"silent"`) while progress output remains a
cross-target no-op. Unigram training also accepts `initial_alphabet`, matching
HF's first-character retention rule for multi-character entries, and preserves
`seed_size` as the deterministic MVP's ranked candidate cap. These helpers are
intended for binding/property mapping and do not change training behavior.
`TrainerState` plus `get_state` / `from_state` / `__getstate__` /
`__setstate__` preserve the same typed configuration, including `AddedToken`
metadata, and `__str__` / `__repr__` return a compact JSON view for binding logs
and diagnostics.
`Tokenizer::train_from_iterator(texts, trainer, length=None)` accepts the HF
`length` progress hint as a no-op so bindings can pass it through without
changing training results.

`Model` exposes read-only configuration getters for binding layers, including
`kind`, `unk_token`, `unk_id`, WordPiece/BPE prefix/suffix knobs, BPE dropout and
merge flags, and BPE/Unigram byte-fallback/fuse-unk flags. It also supports
JSON-backed `get_state` / `from_state` / `__getstate__` / `__setstate__`, plus
`__str__` / `__repr__` aliases for compact model JSON. `get_vocab_size()` is
available as an HF-style alias for `vocab_size()`, and `vocab()` is a
property-style alias for `get_vocab()`.

`Tokenizer::__str__()` and `Tokenizer::__repr__()` are thin Python binding
aliases for the compact `to_str()` JSON form.

`TokenizerComponentHooks` provides runtime-only normalize, pre-tokenize, and
decode callbacks for binding layers that cannot map a dynamic Python component
to a typed MoonBit component yet. Hooks can be passed per call or attached to a
tokenizer. They are intentionally excluded from tokenizer JSON/state; use typed
components for serialized round-trips.

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
fn Encoding::char_to_token_by_sequence_index(self : Encoding, pos : Int, sequence_index? : Int = 0) -> Int?
fn Encoding::char_to_word_by_sequence_index(self : Encoding, pos : Int, sequence_index? : Int = 0) -> Int?
fn Encoding::token_to_char_offsets(self : Encoding, token : Int) -> (Int, Int)?
fn Encoding::token_to_word_index(self : Encoding, token : Int) -> Int?
fn Encoding::word_to_tokens_by_sequence_index(self : Encoding, word : Int, sequence_index? : Int = 0) -> (Int, Int)?
fn Encoding::word_to_chars_by_sequence_index(self : Encoding, word : Int, sequence_index? : Int = 0) -> (Int, Int)?
fn Encoding::len(self : Encoding) -> Int
fn Encoding::is_empty(self : Encoding) -> Bool
fn Encoding::n_sequences(self : Encoding) -> Int

pub(all) enum EncodingDirection { Left; Right }
fn Encoding::new(
  ids : Array[Int], type_ids : Array[Int], tokens : Array[String],
  offsets : Array[(Int, Int)], special_tokens_mask : Array[Int], attention_mask : Array[Int],
  sequence_ids? : Array[Int?] = [], word_ids? : Array[Int?] = [], overflowing? : Array[Encoding] = [],
) -> Encoding raise TokenizerError
fn Encoding::from_tokens(tokens : Array[Token], type_id? : Int = 0) -> Encoding
fn Encoding::with_type_ids(self : Encoding, type_ids : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_special_tokens_mask(self : Encoding, special_tokens_mask : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_attention_mask(self : Encoding, attention_mask : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_word_ids(self : Encoding, word_ids : Array[Int?]) -> Encoding raise TokenizerError
fn Encoding::with_sequence_id(self : Encoding, sequence_id : Int) -> Encoding raise TokenizerError
fn Encoding::with_overflowing(self : Encoding, overflowing : Array[Encoding]) -> Encoding
fn Encoding::take_overflowing(self : Encoding) -> (Encoding, Array[Encoding])
fn Encoding::truncate(self : Encoding, max_len : Int, stride? : Int = 0, direction? : EncodingDirection = Right) -> Encoding
fn Encoding::truncate_hf(self : Encoding, max_len : Int, stride? : Int = 0, direction? : String = "right") -> Encoding raise TokenizerError
fn Encoding::pad(
  self : Encoding, target_length : Int, pad_id? : Int = 0, pad_type_id? : Int = 0,
  pad_token? : String = "[PAD]", direction? : EncodingDirection = Right,
) -> Encoding
fn Encoding::pad_hf(
  self : Encoding, length : Int, direction? : String = "right",
  pad_id? : Int = 0, pad_type_id? : Int = 0, pad_token? : String = "[PAD]",
) -> Encoding raise TokenizerError
fn Encoding::merge(encodings : Array[Encoding], growing_offsets? : Bool = true) -> Encoding
fn Encoding::merge_with(self : Encoding, pair : Encoding, growing_offsets? : Bool = true) -> Encoding
```

The `get_*` accessors return copied arrays, mirroring HF `Encoding` accessors
while keeping the encoded result immutable from caller code. `len`, `is_empty`
and `n_sequences` cover HF's lightweight encoding metadata helpers. Public
manipulation helpers mirror HF's `Encoding` API but return updated values instead
of mutating in place. `Encoding::merge` and `merge_with` default to HF-style
growing offsets; pass `growing_offsets=false` to keep input offsets unchanged.
Interop constructors and replacement-array setters validate that all public
parallel arrays match `ids.length()`; omitted `sequence_ids` / `word_ids`
continue to use HF-style defaults, while mismatched non-empty arrays raise
`ParseError`. `set_sequence_id` / `with_sequence_id` reject negative sequence
ids.
The `*_by_sequence_index` helpers are naming aliases for binding layers that
map HF's `sequence_index` keyword while preserving the existing MoonBit
`sequence_id` APIs. `token_to_char_offsets` and `token_to_word_index` expose the
HF Python return shapes while keeping the richer MoonBit `token_to_chars` /
`token_to_word` methods intact. `truncate_hf` and `pad_hf` accept HF-style
string directions and keyword order while delegating to the typed MoonBit
helpers. They raise on invalid direction strings; `truncate_hf` also raises
when `stride >= max_len`, matching HF's public wrapper boundary.

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
