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

- `from_str` parses `tokenizer.json` text; it does no file IO and works on all backends.
  WordLevel and WordPiece JSON must include `model.unk_token`; BPE JSON must
  include `model.merges`; WordPiece JSON must include
  `model.continuing_subword_prefix` and `model.max_input_chars_per_word`.
  Missing or wrong-typed required fields raise `TokenizerError`; wrong-typed
  BPE/Unigram boolean knobs and BPE `dropout` are rejected instead of silently
  falling back to defaults. BPE optional string fields (`unk_token`,
  `continuing_subword_prefix`, `end_of_word_suffix`) and WordPiece
  `end_of_word_suffix` accept missing/null values but reject wrong JSON types.
  Unigram `unk_id` accepts missing/null values but rejects non-number values.
  `added_tokens` entries follow HF's strict schema: `id`, `content`,
  `single_word`, `lstrip`, `rstrip`, `normalized`, and `special` must be present
  with the expected JSON types.
  Root `truncation` and `padding` objects also follow HF tokenizer JSON schema:
  required numeric/string enum fields are rejected when missing, wrong-typed, or
  using Python-style lowercase aliases; `truncation.direction` remains optional
  and defaults to `Right`.
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

`Model::save` writes HF-style standalone artifacts for BPE (`vocab.json` +
`merges.txt`), WordPiece (`vocab.txt`), WordLevel (`vocab.json`), and a compact
score-preserving Unigram JSON artifact. The standalone loaders read those common
HF artifact formats back into typed models, including saved Unigram JSON
fragments; BPE merge files skip `#version:` comment lines and use the same
legacy merge splitting semantics as tokenizer JSON loading.
`Model::wordlevel` and `Model::wordpiece` provide in-memory constructors for
the common HF `models.WordLevel(vocab=...)` and `models.WordPiece(vocab=...)`
migration path; constructor inputs are copied before building dense id lookup
tables.
The `*_read_file` and `*_from_file` model helpers are naming aliases for the
same BPE/WordPiece/WordLevel artifact loaders, matching HF model class methods;
Unigram intentionally only exposes the JSON artifact loader because HF has no
matching file-class helper.

#### Model getter aliases and state API

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

Property-style getters return the model's configuration. `kind()` returns the
model type string (`"BPE"`, `"WordPiece"`, `"Unigram"`, `"WordLevel"`).
`vocab_size()` and `vocab()` access the vocabulary. `token_to_id()` and
`id_to_token()` look up tokens. `to_json()` serializes the model.
`get_state()` / `from_state()` provide state round-trip. Cache control methods
manage the internal word-to-tokens cache.

#### Model low-level methods

```moonbit
fn Model::tokenize(self : Model, word : String, offset? : Int = 0) -> Array[Token] raise TokenizerError
fn Model::get_word_count(self : Model) -> Int?
fn Model::_clear_cache(self : Model) -> Unit  // alias for clear_cache
fn Model::_resize_cache(self : Model, capacity : Int) -> Unit  // alias for resize_cache
```

`tokenize()` is a low-level method that tokenizes a single pre-tokenized word
into tokens. `offset` is the character offset of the word within the original
text. `get_word_count()` returns the BPE word count (None for other models).
`_clear_cache()` and `_resize_cache()` are Python binding aliases for the
cache control methods.

#### Model setter aliases (Python binding compatibility)

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

Corresponding to HF Python `Model` property setters (e.g. `model.dropout = 0.5`),
MoonBit provides `set_*` methods that return a new Model, preserving immutability.
Each setter only modifies the relevant model variant's field; other variants return
the original Model unchanged (e.g. `set_dropout` is a no-op on Unigram). Each
setter has a `*_alias` companion for Python binding migration consistency.

When `alpha > 0` and `nbest_size > 0` are set on an Unigram model, the tokenizer
uses N-best path sampling (SentencePiece mode): it enumerates up to `nbest_size`
complete tokenization paths via beam search over the lattice, scores them, and
samples using softmax with `alpha` as temperature. When `nbest_size` is not set
(or `<= 0`), it falls back to forward-backward sampling over the full
distribution.

#### Normalizer setter aliases (Python binding compatibility)

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

Corresponding to HF Python `Normalizer` property setters, MoonBit provides `set_*`
methods that return a new Normalizer, preserving immutability. Each setter only
modifies the relevant normalizer variant's field; other variants return the
original Normalizer unchanged.

#### Normalizer additional getters

```moonbit
fn Normalizer::pattern_kind(self : Normalizer) -> PatternKind?
fn Normalizer::get_pattern_kind(self : PatternKind) -> PatternKind?
fn Normalizer::get_pattern(self : Normalizer) -> String?
fn Normalizer::get_content(self : Normalizer) -> String?
fn Normalizer::get_prepend(self : Normalizer) -> String?
fn Normalizer::get_item(self : Normalizer, index : Int) -> Normalizer?
```

Additional getter aliases for Normalizer. `pattern_kind()` returns the pattern
kind for Replace normalizers. `get_item()` returns the child normalizer at the
given index for Sequence normalizers.

#### Normalizer builder methods

```moonbit
fn Normalizer::nfc() -> Normalizer
fn Normalizer::nfd() -> Normalizer
fn Normalizer::nfkc() -> Normalizer
fn Normalizer::nfkd() -> Normalizer
fn Normalizer::byte_level() -> Normalizer
fn Normalizer::lowercase_normalizer() -> Normalizer
fn Normalizer::strip(left : Bool, right : Bool) -> Normalizer
fn Normalizer::strip_left() -> Normalizer  // strip(left=true, right=false)
fn Normalizer::strip_right() -> Normalizer  // strip(left=false, right=true)
fn Normalizer::strip_accents_normalizer() -> Normalizer
fn Normalizer::prepend_normalizer(content : String) -> Normalizer
fn Normalizer::nmt() -> Normalizer
fn Normalizer::precompiled(charsmap : String) -> Normalizer
fn Normalizer::replace(pattern : String, content : String) -> Normalizer
fn Normalizer::replace_regex(pattern : String, content : String) -> Normalizer
fn Normalizer::bert_normalizer(
  clean_text? : Bool = true, handle_chinese_chars? : Bool = true,
  strip_accents? : Bool? = None, lowercase? : Bool = true,
) -> Normalizer
fn Normalizer::sequence(normalizers : Array[Normalizer]) -> Normalizer
```

Builder methods create Normalizer instances. `nfc()` / `nfd()` / `nfkc()` / `nfkd()`
create Unicode normalization forms. `strip()` creates a Strip normalizer.
`bert_normalizer()` creates a BertNormalizer with configurable flags.
`sequence()` chains multiple normalizers.

#### Normalizer getter aliases

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

Property-style getters return the normalizer's configuration. `kind()` returns
the normalizer type string. `left()` / `right()` are HF `Strip.left` / `Strip.right`
aliases. `normalizers()` returns children for Sequence normalizers.
`normalize_str()` is an HF-style alias for `normalize()`.
`get_state()` / `from_state()` provide state round-trip.

#### PreTokenizer setter aliases (Python binding compatibility)

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

Corresponding to HF Python `PreTokenizer` property setters, MoonBit provides `set_*`
methods that return a new PreTokenizer, preserving immutability. Each setter only
modifies the relevant pre-tokenizer variant's field; other variants return the
original PreTokenizer unchanged.


### Hub cache types (`@tokenizer`)

```moonbit
pub struct PretrainedCacheMetadata {
  tokenizer_json_path : String
  tokenizer_config_path : String?
  special_tokens_map_path : String?
  revision : String
  resolved_revision : String
  etag : String?
}

fn PretrainedCacheMetadata::cache_exists(self : PretrainedCacheMetadata) -> Bool
fn PretrainedCacheMetadata::etag_matches(self : PretrainedCacheMetadata, expected_etag : String?) -> Bool
fn PretrainedCacheMetadata::is_fresh(
  self : PretrainedCacheMetadata, resolved_revision? : String? = None,
  etag? : String? = None, require_tokenizer_config? : Bool = false,
  require_special_tokens_map? : Bool = false,
) -> Bool

pub struct PretrainedCachePaths {
  repo_cache_dir : String
  refs_dir : String
  ref_path : String
  snapshot_dir : String
  tokenizer_json_path : String
  tokenizer_config_path : String
  special_tokens_map_path : String
  etag_path : String
  resume_path : String
}

pub struct PretrainedDownloadResumeMetadata {
  resume_path : String
  incomplete_path : String
  etag : String?
  expected_size : Int?
  downloaded_size : Int
}

pub struct PretrainedResolutionHint {
  model_id : String
  revision : String
  cache_dir : String?
  repo_cache_dir : String?
  ref_path : String?
  resolved_revision : String?
  snapshot_dir : String?
  tokenizer_json_path : String?
  cache_exists : Bool
  message : String
}

fn Tokenizer::from_pretrained_cache_metadata(
  self : Tokenizer, model_id : String, ...,
) -> PretrainedCacheMetadata?
fn Tokenizer::from_pretrained_cache_paths(
  self : Tokenizer, model_id : String, ...,
) -> PretrainedCachePaths
fn Tokenizer::from_pretrained_resolution_hint(
  self : Tokenizer, path : String, ...,
) -> PretrainedResolutionHint
fn Tokenizer::from_pretrained_download_resume_metadata(
  self : Tokenizer, model_id : String, ...,
) -> PretrainedDownloadResumeMetadata?
```

`PretrainedCacheMetadata` holds resolved cache paths, revision and ETag for
offline freshness checks. `cache_exists` checks if the tokenizer JSON file
exists on disk. `etag_matches` compares cached ETag against an expected value.
`is_fresh` validates cache freshness using available offline signals.

`PretrainedCachePaths` exposes concrete paths for the HF Hub cache layout,
useful for HEAD checks, ref updates, or resumable downloads.

`PretrainedDownloadResumeMetadata` tracks interrupted downloads for Range/ETag
resume coordination. `PretrainedResolutionHint` provides diagnostic information
for offline resolution failures, including private/gated repo guidance.

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
  stream_chunk_size? : Int = 65536,
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
### Hub protocol types (`@hub`)

```moonbit
pub enum HubTransferAction {
  UseCachedTokenizer       // 304: cache is fresh
  ReplaceCachedTokenizer   // 200: download full body
  AppendRangeToCachedTokenizer  // 206: resume partial download
  RetryWithoutRange        // 416/mismatch: retry without Range
  RejectResponse           // non-success status
}

pub struct HubRequestPlan {
  url : String
  headers : Map[String, String]
  cache_paths : PretrainedCachePaths?
  cache_metadata : PretrainedCacheMetadata?
  resume_metadata : PretrainedDownloadResumeMetadata?
  range_start : Int?
  conditional_etag : String?
}

pub struct HubResponseMetadata {
  status : Int
  resolved_revision : String?
  etag : String?
  content_length : Int?
  content_range_start : Int?
  content_range_end : Int?
  content_range_total : Int?
  accept_ranges : Bool
}

pub struct HubResponseDecision {
  action : HubTransferAction
  resolved_revision : String?
  etag : String?
  expected_size : Int?
  range_start : Int?
  message : String
}

pub struct HubHeadResult {
  metadata : HubResponseMetadata
  decision : HubResponseDecision
  final_url : String
}

fn HubResponseMetadata::new(status : Int, ...) -> HubResponseMetadata
fn HubResponseMetadata::from_headers(headers : Map[String, String], ...) -> HubResponseMetadata
fn HubResponseDecision::can_use_cache(self : HubResponseDecision) -> Bool
fn HubResponseDecision::should_write_full_body(self : HubResponseDecision) -> Bool
fn HubResponseDecision::should_append_range(self : HubResponseDecision) -> Bool
fn HubResponseDecision::should_retry_without_range(self : HubResponseDecision) -> Bool

fn hub_http_status_diagnostic(status : Int) -> String
fn tokenizer_json_url(model_id : String, revision? : String = "main") -> String
fn hub_file_url(model_id : String, filename : String, revision? : String = "main") -> String
fn plan_tokenizer_json_request(model_id : String, ...) -> HubRequestPlan
fn plan_hub_file_request(model_id : String, filename : String, ...) -> HubRequestPlan
fn head_tokenizer_json_request(model_id : String, ...) -> HubRequestPlan
fn decide_tokenizer_json_response(plan : HubRequestPlan, metadata : HubResponseMetadata) -> HubResponseDecision
fn decide_tokenizer_json_head_response(plan : HubRequestPlan, metadata : HubResponseMetadata) -> HubResponseDecision
```

`HubTransferAction` enumerates the possible cache update decisions:
`UseCachedTokenizer` (304 or HEAD match), `ReplaceCachedTokenizer` (full download),
`AppendRangeToCachedTokenizer` (206 resume), `RetryWithoutRange` (416/mismatch),
and `RejectResponse` (non-success).

`HubRequestPlan` combines URL, auth headers, cache metadata, and resume state
for deterministic request planning without performing IO.

`HubResponseMetadata` extracts status, revision, ETag, content length, and
Range headers from HEAD/GET responses.

`HubResponseDecision` pairs the action with diagnostic message, resolved
revision, ETag, and size information.

`hub_http_status_diagnostic` returns human-readable diagnostics for 401/403/404/429/5xx.

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

fn Tokenizer::encode_plus(
  self : Tokenizer, text : String, pair? : String? = None,
  add_special_tokens? : Bool = true,
) -> Encoding raise TokenizerError

fn Tokenizer::batch_encode_plus(
  self : Tokenizer, inputs : Array[EncodeInput], add_special_tokens? : Bool = true,
) -> Array[Encoding] raise TokenizerError

fn Tokenizer::decode_ids(
  self : Tokenizer, ids : Array[Int], skip_special_tokens? : Bool = true,
) -> String

fn Tokenizer::batch_decode(
  self : Tokenizer, batch : Array[Array[Int]], skip_special_tokens? : Bool = true,
) -> Array[String]

fn Tokenizer::async_encode(
  self : Tokenizer, input : EncodeInput, add_special_tokens? : Bool = true,
) -> Encoding raise TokenizerError

fn Tokenizer::async_encode_batch(
  self : Tokenizer, inputs : Array[EncodeInput], add_special_tokens? : Bool = true,
) -> Array[Encoding] raise TokenizerError

fn Tokenizer::async_decode(
  self : Tokenizer, ids : Array[Int], skip_special_tokens? : Bool = true,
) -> String

fn Tokenizer::async_decode_batch(
  self : Tokenizer, batch : Array[Array[Int]], skip_special_tokens? : Bool = true,
) -> Array[String]
```

Fast encode variants (`encode_fast`, `encode_batch_fast`,
`encode_sequence_input_fast`, `encode_input_fast`, `encode_input_batch_fast`,
and `batch_encode_plus_fast`) keep ids/tokens/masks/sequence metadata aligned
with regular encode paths while zeroing offsets. Encode APIs can raise
`TokenizerError` for model-level tokenization failures, for example missing
WordLevel/WordPiece/BPE/Unigram unknown-token fallback configuration. Async-compatible aliases
(`async_encode`, `async_encode_fast`, `async_encode_batch`,
`async_encode_batch_fast`, `async_decode`, `async_decode_batch`) delegate to the
same deterministic synchronous implementation on every target.

For high-level encode APIs, `add_special_tokens=false` follows HF semantics: it
omits special tokens injected by the configured post-processor, but the
post-processor still applies non-special effects such as Template/BERT
`type_ids`, pair `sequence_ids`, and ByteLevel/RoBERTa offset trimming.

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

## Property-style getters

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

## State API and component hooks

```moonbit
fn Tokenizer::get_state(self : Tokenizer) -> TokenizerState raise TokenizerError
fn Tokenizer::from_state(state : TokenizerState) -> Tokenizer raise TokenizerError
fn Tokenizer::__getstate__(self : Tokenizer) -> TokenizerState raise TokenizerError
fn Tokenizer::__setstate__(state : TokenizerState) -> Tokenizer raise TokenizerError
fn Tokenizer::with_component_hooks(self : Tokenizer, hooks : TokenizerComponentHooks) -> Tokenizer
fn Tokenizer::get_component_hooks(self : Tokenizer) -> TokenizerComponentHooks
fn Tokenizer::component_hooks(self : Tokenizer) -> TokenizerComponentHooks
fn Tokenizer::clear_component_hooks(self : Tokenizer) -> Tokenizer
fn Tokenizer::get_added_tokens(self : Tokenizer) -> Array[AddedToken]
fn Tokenizer::added_tokens(self : Tokenizer) -> Array[AddedToken]
fn Tokenizer::get_added_tokens_count(self : Tokenizer, special_only? : Bool = false) -> Int
fn Tokenizer::added_tokens_count(self : Tokenizer, special_only? : Bool = false) -> Int
```

`get_state` / `from_state` provide JSON-backed state round-trip for Python
binding/pickle interop. `__getstate__` and `__setstate__` are Python pickle
compatibility aliases that delegate to `get_state` and `from_state`. `with_component_hooks` attaches per-encode callbacks
for custom normalize/pre-tokenize/decode; `clear_component_hooks` removes
them. `get_added_tokens` returns all added tokens sorted by id;
`get_added_tokens_count` returns the count, with optional `special_only`
filter. `added_tokens` and `added_tokens_count` are property-style aliases.

Property-style getters are convenience aliases for the corresponding `get_*`
methods, returning the same values. `normalizer()`, `pre_tokenizer()`,
`model()`, `post_processor()`, `decoder()` access tokenizer components.
`truncation()` and `padding()` return current configuration.
`encode_special_tokens()` reports the special-token encoding switch.
`vocab_size()` and `vocab()` are aliases for `get_vocab_size()` and `get_vocab()`.
`added_tokens_decoder()` returns the `id -> AddedToken` map.
`get_trainer()` and `default_trainer()` return a trainer configured with the
tokenizer's current settings. `to_json()` serializes the tokenizer to JSON
string (alias for `to_str()`).

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

fn Decoder::wordpiece(prefix? : String = "##", cleanup? : Bool = true) -> Decoder
fn Decoder::byte_fallback() -> Decoder
fn Decoder::ctc(
  pad_token? : String = "<pad>", word_delimiter_token? : String = "|", cleanup? : Bool = true,
) -> Decoder
#### PreTokenizer additional getters

```moonbit
fn PreTokenizer::regex(self : PreTokenizer) -> String?
fn PreTokenizer::get_regex(self : PreTokenizer) -> String?
fn PreTokenizer::get_item(self : PreTokenizer, index : Int) -> PreTokenizer?
```

Additional getter aliases for PreTokenizer. `regex()` returns the regex pattern
for Split pre-tokenizers. `get_item()` returns the child pre-tokenizer at the
given index for Sequence pre-tokenizers.

#### PreTokenizer builder methods

```moonbit
fn PreTokenizer::whitespace() -> PreTokenizer
fn PreTokenizer::whitespace_split() -> PreTokenizer
fn PreTokenizer::bert_pre_tokenizer() -> PreTokenizer
fn PreTokenizer::byte_level(add_prefix_space? : Bool = true) -> PreTokenizer
fn PreTokenizer::metaspace(replacement? : Char = '▁', prepend_scheme? : String = "always") -> PreTokenizer
fn PreTokenizer::punctuation(behavior? : SplitBehavior = Isolated) -> PreTokenizer
fn PreTokenizer::digits(individual_digits? : Bool = false) -> PreTokenizer
fn PreTokenizer::delimiter(delimiter : Char) -> PreTokenizer
fn PreTokenizer::fixed_length(length : Int) -> PreTokenizer
fn PreTokenizer::unicode_scripts() -> PreTokenizer
fn PreTokenizer::char_delimiter_split(delimiter : Char) -> PreTokenizer
fn PreTokenizer::split(pattern : String, behavior? : SplitBehavior = Removed, invert? : Bool = false, regex? : Bool = false) -> PreTokenizer
fn PreTokenizer::sequence(pre_tokenizers : Array[PreTokenizer]) -> PreTokenizer
```

Builder methods create PreTokenizer instances. `whitespace()` splits on
whitespace. `byte_level()` creates GPT-2 style byte-level pre-tokenizer.
`metaspace()` creates SentencePiece-style metaspace pre-tokenizer.
`split()` creates a Split pre-tokenizer with configurable behavior.
`sequence()` chains multiple pre-tokenizers.

#### PreTokenizer getter aliases

```moonbit
fn PreTokenizer::kind(self : PreTokenizer) -> String
fn PreTokenizer::add_prefix_space(self : PreTokenizer) -> Bool?
fn PreTokenizer::get_add_prefix_space(self : PreTokenizer) -> Bool?
fn PreTokenizer::use_regex(self : PreTokenizer) -> Bool?
fn PreTokenizer::get_use_regex(self : PreTokenizer) -> Bool?
fn PreTokenizer::trim_offsets(self : PreTokenizer) -> Bool?
fn PreTokenizer::get_trim_offsets(self : PreTokenizer) -> Bool?
fn PreTokenizer::replacement(self : PreTokenizer) -> Char?
fn PreTokenizer::get_replacement(self : PreTokenizer) -> Char?
fn PreTokenizer::prepend_scheme(self : PreTokenizer) -> String?
fn PreTokenizer::get_prepend_scheme(self : PreTokenizer) -> String?
fn PreTokenizer::split_enabled(self : PreTokenizer) -> Bool?
fn PreTokenizer::get_split(self : PreTokenizer) -> Bool?
fn PreTokenizer::delimiter(self : PreTokenizer) -> Char?
fn PreTokenizer::get_delimiter(self : PreTokenizer) -> Char?
fn PreTokenizer::individual_digits(self : PreTokenizer) -> Bool?
fn PreTokenizer::get_individual_digits(self : PreTokenizer) -> Bool?
fn PreTokenizer::length(self : PreTokenizer) -> Int?
fn PreTokenizer::get_length(self : PreTokenizer) -> Int?
fn PreTokenizer::behavior(self : PreTokenizer) -> SplitBehavior?
fn PreTokenizer::get_behavior(self : PreTokenizer) -> SplitBehavior?
fn PreTokenizer::invert(self : PreTokenizer) -> Bool?
fn PreTokenizer::get_invert(self : PreTokenizer) -> Bool?
fn PreTokenizer::pattern(self : PreTokenizer) -> String?
fn PreTokenizer::get_pattern(self : PreTokenizer) -> String?
fn PreTokenizer::pre_tokenizers(self : PreTokenizer) -> Array[PreTokenizer]
fn PreTokenizer::get_pre_tokenizers(self : PreTokenizer) -> Array[PreTokenizer]
fn PreTokenizer::alphabet(self : PreTokenizer) -> Array[Char]
fn PreTokenizer::byte_level_alphabet(self : PreTokenizer) -> Array[Char]
fn PreTokenizer::pre_tokenize_str(self : PreTokenizer, text : String) -> Array[(String, (Int, Int))]
fn PreTokenizer::get_state(self : PreTokenizer) -> PreTokenizerState
fn PreTokenizer::from_state(state : PreTokenizerState) -> PreTokenizer raise TokenizerError
fn PreTokenizer::to_json(self : PreTokenizer) -> String?
fn PreTokenizer::from_json(j : Json) -> PreTokenizer raise TokenizerError
```

Property-style getters return the pre-tokenizer's configuration. `kind()` returns
the type string. `alphabet()` returns the character set. `pre_tokenize_str()`
returns HF-style `(value, offsets)` tuples. `pre_tokenizers()` returns children
for Sequence pre-tokenizers. `get_state()` / `from_state()` provide state
round-trip.

#### Decoder setter aliases (Python binding compatibility)

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

Corresponding to HF Python `Decoder` property setters, MoonBit provides `set_*`
methods that return a new Decoder, preserving immutability. Each setter only
modifies the relevant decoder variant's field; other variants return the
original Decoder unchanged. Setters that apply to multiple variants (e.g.
`set_cleanup` for WordPiece and CTC, `set_content` for Replace and
ReplaceString) handle all matching variants.


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
#### PostProcessor additional getters

```moonbit
fn PostProcessor::get_single(self : PostProcessor) -> Array[Piece]
fn PostProcessor::get_single_pieces(self : PostProcessor) -> Array[Piece]
fn PostProcessor::get_pair(self : PostProcessor) -> Array[Piece]
fn PostProcessor::get_pair_pieces(self : PostProcessor) -> Array[Piece]
fn PostProcessor::get_special_tokens(self : PostProcessor) -> Map[String, SpecialToken]
fn PostProcessor::added_tokens(self : PostProcessor) -> Map[String, SpecialToken]
fn PostProcessor::get_item(self : PostProcessor, index : Int) -> PostProcessor?
```

Additional getter aliases for PostProcessor. `get_single()` / `get_pair()`
return template pieces. `get_special_tokens()` returns the special tokens map.
`added_tokens()` is an alias for `get_special_tokens()`.
`get_item()` returns the child post-processor at the given index for Sequence
post-processors.

#### PostProcessor getter aliases

```moonbit
fn PostProcessor::kind(self : PostProcessor) -> String
fn PostProcessor::sep(self : PostProcessor) -> (String, Int)?
fn PostProcessor::get_sep(self : PostProcessor) -> (String, Int)?
fn PostProcessor::cls(self : PostProcessor) -> (String, Int)?
fn PostProcessor::get_cls(self : PostProcessor) -> (String, Int)?
fn PostProcessor::trim_offsets(self : PostProcessor) -> Bool?
fn PostProcessor::get_trim_offsets(self : PostProcessor) -> Bool?
fn PostProcessor::add_prefix_space(self : PostProcessor) -> Bool?
fn PostProcessor::get_add_prefix_space(self : PostProcessor) -> Bool?
fn PostProcessor::use_regex(self : PostProcessor) -> Bool?
fn PostProcessor::get_use_regex(self : PostProcessor) -> Bool?
fn PostProcessor::single_pieces(self : PostProcessor) -> Array[Piece]
fn PostProcessor::single(self : PostProcessor) -> Array[Piece]
fn PostProcessor::pair_pieces(self : PostProcessor) -> Array[Piece]
fn PostProcessor::pair(self : PostProcessor) -> Array[Piece]
fn PostProcessor::special_tokens(self : PostProcessor) -> Map[String, SpecialToken]
fn PostProcessor::processors(self : PostProcessor) -> Array[PostProcessor]
fn PostProcessor::get_processors(self : PostProcessor) -> Array[PostProcessor]
fn PostProcessor::num_special_tokens_to_add(self : PostProcessor, is_pair : Bool) -> Int
fn PostProcessor::get_state(self : PostProcessor) -> PostProcessorState
fn PostProcessor::from_state(state : PostProcessorState) -> PostProcessor raise TokenizerError
fn PostProcessor::to_json(self : PostProcessor) -> String?
fn PostProcessor::from_json(j : Json) -> PostProcessor raise TokenizerError
```

Property-style getters return the post-processor's configuration. `kind()` returns
the type string. `single()` / `pair()` return template pieces. `processors()`
returns children for Sequence post-processors. `num_special_tokens_to_add()`
reports how many special tokens would be injected. `get_state()` / `from_state()`
provide state round-trip.

#### Trainer builder methods

```moonbit
fn Trainer::wordlevel(
  unk_token? : String = "<unk>", min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = None,
) -> Trainer
fn Trainer::wordpiece(
  unk_token? : String = "[UNK]", continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None, min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
) -> Trainer
fn Trainer::bpe(
  unk_token? : String? = None, min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = None,
  continuing_subword_prefix? : String? = None, end_of_word_suffix? : String? = None,
) -> Trainer
fn Trainer::unigram(
  unk_token? : String? = None, min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = None,
) -> Trainer
fn Trainer::wordlevel_trainer(...) -> Trainer  // alias for wordlevel
fn Trainer::wordpiece_trainer(...) -> Trainer  // alias for wordpiece
fn Trainer::bpe_trainer(...) -> Trainer  // alias for bpe
fn Trainer::unigram_trainer(...) -> Trainer  // alias for unigram
```

Builder methods create Trainer instances for each model type. `wordlevel()`
creates a WordLevel trainer. `wordpiece()` creates a WordPiece trainer with
continuation prefix and end-of-word suffix. `bpe()` creates a BPE trainer.
`unigram()` creates a Unigram trainer. Each has a `*_trainer` alias for
HF Python naming consistency.

#### Trainer getter aliases

```moonbit
fn Trainer::kind(self : Trainer) -> String
fn Trainer::unk_token(self : Trainer) -> String?
fn Trainer::get_unk_token(self : Trainer) -> String?
fn Trainer::min_frequency(self : Trainer) -> Int
fn Trainer::get_min_frequency(self : Trainer) -> Int
fn Trainer::special_tokens(self : Trainer) -> Array[String]
fn Trainer::get_special_tokens(self : Trainer) -> Array[String]
fn Trainer::special_added_tokens(self : Trainer) -> Array[AddedToken]
fn Trainer::get_special_added_tokens(self : Trainer) -> Array[AddedToken]
fn Trainer::vocab_size(self : Trainer) -> Int?
fn Trainer::get_vocab_size(self : Trainer) -> Int?
fn Trainer::show_progress(self : Trainer) -> Bool
fn Trainer::get_show_progress(self : Trainer) -> Bool
fn Trainer::continuing_subword_prefix(self : Trainer) -> String?
fn Trainer::get_continuing_subword_prefix(self : Trainer) -> String?
fn Trainer::end_of_word_suffix(self : Trainer) -> String?
fn Trainer::get_end_of_word_suffix(self : Trainer) -> String?
fn Trainer::max_input_chars_per_word(self : Trainer) -> Int?
fn Trainer::get_max_input_chars_per_word(self : Trainer) -> Int?
fn Trainer::max_token_length(self : Trainer) -> Int?
fn Trainer::get_max_token_length(self : Trainer) -> Int?
fn Trainer::initial_alphabet(self : Trainer) -> Array[String]
fn Trainer::get_initial_alphabet(self : Trainer) -> Array[String]
fn Trainer::limit_alphabet(self : Trainer) -> Int?
fn Trainer::get_limit_alphabet(self : Trainer) -> Int?
fn Trainer::fuse_unk(self : Trainer) -> Bool?
fn Trainer::get_fuse_unk(self : Trainer) -> Bool?
fn Trainer::byte_fallback(self : Trainer) -> Bool?
fn Trainer::get_byte_fallback(self : Trainer) -> Bool?
fn Trainer::shrinking_factor(self : Trainer) -> Double?
fn Trainer::get_shrinking_factor(self : Trainer) -> Double?
fn Trainer::max_piece_length(self : Trainer) -> Int?
fn Trainer::get_max_piece_length(self : Trainer) -> Int?
fn Trainer::n_sub_iterations(self : Trainer) -> Int?
fn Trainer::get_n_sub_iterations(self : Trainer) -> Int?
fn Trainer::seed_size(self : Trainer) -> Int?
fn Trainer::get_seed_size(self : Trainer) -> Int?
fn Trainer::progress_format(self : Trainer) -> String?
fn Trainer::get_progress_format(self : Trainer) -> String?
fn Trainer::get_state(self : Trainer) -> TrainerState
fn Trainer::from_state(state : TrainerState) -> Trainer raise TokenizerError
```

Property-style getters return the trainer's configuration. `kind()` returns
the trainer type string (`"WordLevel"`, `"WordPiece"`, `"BPE"`, `"Unigram"`).
`get_state()` / `from_state()` provide state round-trip for Python binding/pickle
interop.

#### Trainer setter aliases (Python binding compatibility)

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

Corresponding to HF Python `Trainer` property setters, MoonBit provides `set_*`
methods that return a new Trainer, preserving immutability. Each setter only
modifies the relevant trainer variant's field; other variants return the
original Trainer unchanged. Setters that apply to multiple variants (e.g.
`set_unk_token` for all four trainer types) handle all matching variants.
Each setter has a `*_alias` companion for Python binding migration consistency.

#### Decoder additional getters

```moonbit
fn Decoder::pattern_kind(self : Decoder) -> PatternKind?
fn Decoder::get_pattern_kind(self : Decoder) -> PatternKind?
fn Decoder::pattern(self : Decoder) -> String?
fn Decoder::get_pattern(self : Decoder) -> String?
fn Decoder::get_item(self : Decoder, index : Int) -> Decoder?
```

Additional getter aliases for Decoder. `pattern_kind()` returns the pattern
kind for Replace decoders. `pattern()` returns the regex pattern.
`get_item()` returns the child decoder at the given index for Sequence decoders.

#### Decoder builder methods

```moonbit
fn Decoder::byte_level(add_prefix_space? : Bool = true, trim_offsets? : Bool = true, use_regex? : Bool = true) -> Decoder
fn Decoder::wordpiece(prefix? : String = "##", cleanup? : Bool = true) -> Decoder
fn Decoder::metaspace(replacement? : Char = '▁', prepend_scheme? : String = "always", split? : Bool = true) -> Decoder
fn Decoder::bpe_decoder(suffix? : String = "</w>") -> Decoder
fn Decoder::strip(content : Char, start : Int, stop : Int) -> Decoder
fn Decoder::fuse() -> Decoder
fn Decoder::replace(pattern : String, content : String) -> Decoder
fn Decoder::replace_regex(pattern : String, content : String) -> Decoder
fn Decoder::byte_fallback() -> Decoder
fn Decoder::ctc(pad_token? : String = "<pad>", word_delimiter_token? : String = "|", cleanup? : Bool = true) -> Decoder
fn Decoder::sequence(decoders : Array[Decoder]) -> Decoder
```

Builder methods create Decoder instances. `byte_level()` creates GPT-2 style
byte-level decoder. `wordpiece()` creates WordPiece decoder. `metaspace()`
creates SentencePiece-style metaspace decoder. `ctc()` creates CTC decoder
for speech models. `sequence()` chains multiple decoders.

#### Decoder getter aliases

```moonbit
fn Decoder::kind(self : Decoder) -> String
fn Decoder::add_prefix_space(self : Decoder) -> Bool?
fn Decoder::get_add_prefix_space(self : Decoder) -> Bool?
fn Decoder::trim_offsets(self : Decoder) -> Bool?
fn Decoder::get_trim_offsets(self : Decoder) -> Bool?
fn Decoder::use_regex(self : Decoder) -> Bool?
fn Decoder::get_use_regex(self : Decoder) -> Bool?
fn Decoder::prefix(self : Decoder) -> String?
fn Decoder::get_prefix(self : Decoder) -> String?
fn Decoder::cleanup(self : Decoder) -> Bool?
fn Decoder::get_cleanup(self : Decoder) -> Bool?
fn Decoder::replacement(self : Decoder) -> Char?
fn Decoder::get_replacement(self : Decoder) -> Char?
fn Decoder::prepend_scheme(self : Decoder) -> String?
fn Decoder::get_prepend_scheme(self : Decoder) -> String?
fn Decoder::split_enabled(self : Decoder) -> Bool?
fn Decoder::get_split(self : Decoder) -> Bool?
fn Decoder::suffix(self : Decoder) -> String?
fn Decoder::get_suffix(self : Decoder) -> String?
fn Decoder::content(self : Decoder) -> String?
fn Decoder::get_content(self : Decoder) -> String?
fn Decoder::start(self : Decoder) -> Int?
fn Decoder::get_start(self : Decoder) -> Int?
fn Decoder::stop(self : Decoder) -> Int?
fn Decoder::get_stop(self : Decoder) -> Int?
fn Decoder::left(self : Decoder) -> Int?
fn Decoder::get_left(self : Decoder) -> Int?
fn Decoder::right(self : Decoder) -> Int?
fn Decoder::get_right(self : Decoder) -> Int?
fn Decoder::pad_token(self : Decoder) -> String?
fn Decoder::get_pad_token(self : Decoder) -> String?
fn Decoder::word_delimiter_token(self : Decoder) -> String?
fn Decoder::get_word_delimiter_token(self : Decoder) -> String?
fn Decoder::decoders(self : Decoder) -> Array[Decoder]
fn Decoder::get_decoders(self : Decoder) -> Array[Decoder]
fn Decoder::get_state(self : Decoder) -> DecoderState
fn Decoder::from_state(state : DecoderState) -> Decoder raise TokenizerError
fn Decoder::to_json(self : Decoder) -> String?
fn Decoder::from_json(j : Json) -> Decoder raise TokenizerError
```

Property-style getters return the decoder's configuration. `kind()` returns
the type string. `decoders()` returns children for Sequence decoders.
`get_state()` / `from_state()` provide state round-trip.

#### PostProcessor setter aliases (Python binding compatibility)

```moonbit
fn PostProcessor::set_trim_offsets(self : PostProcessor, val : Bool) -> PostProcessor
fn PostProcessor::set_add_prefix_space(self : PostProcessor, val : Bool) -> PostProcessor
fn PostProcessor::set_use_regex(self : PostProcessor, val : Bool) -> PostProcessor
fn PostProcessor::set_sep(self : PostProcessor, val : (String, Int)) -> PostProcessor
fn PostProcessor::set_cls(self : PostProcessor, val : (String, Int)) -> PostProcessor
```

Corresponding to HF Python `PostProcessor` property setters, MoonBit provides
`set_*` methods that return a new PostProcessor, preserving immutability. Each
setter only modifies the relevant post-processor variant's field; other variants
return the original PostProcessor unchanged. Setters that apply to multiple
variants (e.g. `set_sep` for BertProcessing and RobertaProcessing) handle all
matching variants.

```

Builders return a tokenizer and can be chained:
`Tokenizer::new(model).with_pre_tokenizer(..).with_decoder(..)`. They invalidate
the cached source JSON so constructed tokenizers serialize from typed state where
supported. Decoder and post-processor builders mirror common HF component
construction in tests or synthetic pipelines.
The `set_*` component/config methods are writable-property style aliases for the
corresponding `with_*` builders, preserving the same return-a-new-tokenizer
semantics for thin binding layers.
`enable_truncation_hf` and `enable_padding_hf` accept HF-style string
`strategy` / `direction` values and raise on invalid strings, while preserving
the existing typed `enable_*` APIs.
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
`PostProcessor::process` method accepts the same `add_special_tokens` flag. The
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
fn AddedToken::set_single_word(self : AddedToken, single_word : Bool) -> AddedToken
fn AddedToken::set_single_word_alias(self : AddedToken, single_word : Bool) -> AddedToken
fn AddedToken::with_lstrip(self : AddedToken, lstrip : Bool) -> AddedToken
fn AddedToken::set_lstrip(self : AddedToken, lstrip : Bool) -> AddedToken
fn AddedToken::set_lstrip_alias(self : AddedToken, lstrip : Bool) -> AddedToken
fn AddedToken::with_rstrip(self : AddedToken, rstrip : Bool) -> AddedToken
fn AddedToken::set_rstrip(self : AddedToken, rstrip : Bool) -> AddedToken
fn AddedToken::set_rstrip_alias(self : AddedToken, rstrip : Bool) -> AddedToken
fn AddedToken::with_normalized(self : AddedToken, normalized : Bool) -> AddedToken
fn AddedToken::set_normalized(self : AddedToken, normalized : Bool) -> AddedToken
fn AddedToken::set_normalized_alias(self : AddedToken, normalized : Bool) -> AddedToken
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

`add_tokens_with_count` / `add_special_tokens_with_count` return the number of
new token registrations, matching HF's duplicate-aware count semantics. Existing
model tokens count the first time they are registered as added/special tokens,
but keep their original ids and do not increase the vocabulary size. String
entry points also expose `_with_count` variants with the same semantics.
Ordinary added tokens now keep
`special_tokens_mask=0`; only `special=true` entries set mask `1` unless
`encode_special_tokens` is enabled, in which case special token strings found in
input text are encoded as ordinary model tokens. `get_added_tokens_decoder`
returns HF-style `id -> AddedToken` metadata for migration and introspection;
`get_all_special_tokens` / `get_all_special_ids` are getter aliases for the
ordered special-token lists.
`AddedToken::new` accepts HF-style keyword defaults; when `special=true` and
`normalized` is omitted it defaults to `false`, matching HF's constructor.
`AddedToken::__str__()` returns the token content and `__repr__()` returns a
stable HF-style configuration summary.
Low-level `Token` and `Split` values also expose `__str__()` as their surface
value and `__repr__()` as a compact escaped diagnostic summary.

## Cache control

```moonbit
fn Tokenizer::clear_cache(self : Tokenizer) -> Tokenizer
fn Tokenizer::resize_cache(self : Tokenizer, capacity : Int) -> Tokenizer
fn Tokenizer::cache_size(self : Tokenizer) -> Int
```

BPE, WordPiece, and Unigram models maintain an internal word-to-tokens cache
that speeds up repeated encoding of the same strings. `clear_cache` empties the
cache and returns a new Tokenizer; `resize_cache` sets a maximum capacity
(evicting oldest entries when exceeded); `cache_size` reports the current number
of cached entries. Setting capacity to `0` disables caching; `None` (the
default) keeps an unbounded cache.

## Vocabulary

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

Lookups consult the added/special vocabulary first, then the model vocabulary.
`vocab_size` and `vocab` are property-style aliases for `get_vocab_size` and
`get_vocab`. `convert_token_to_id` / `convert_id_to_token` are HF-style
aliases for `token_to_id` / `id_to_token`. `convert_tokens_to_ids` and
`convert_ids_to_tokens` are batch variants that map arrays of tokens/ids.


## Training

```moonbit
fn Tokenizer::train(
  self : Tokenizer, texts : Array[String], trainer : Trainer,
) -> Tokenizer
fn Tokenizer::train_from_iterator(
  self : Tokenizer, texts : Array[String], trainer : Trainer, length? : Int? = None,
) -> Tokenizer
fn Tokenizer::train_from_files(
  self : Tokenizer, files : Array[String], trainer : Trainer,
) -> Tokenizer raise TokenizerError
```

`train` is a convenience alias for `train_from_iterator`. `train_from_iterator`
accepts text arrays as the deterministic iterator representation across MoonBit
backends; the HF `length` progress hint is accepted as a no-op. `train_from_files`
reads lines from local files before delegating to `train_from_iterator`. All
three return a new `Tokenizer` with the trained model, merged special tokens and
updated vocabulary.

### Convenience training helpers

```moonbit
fn Tokenizer::train_wordlevel(
  texts : Array[String],
  unk_token? : String = "[UNK]", min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = Some(30000),
  show_progress? : Bool = true,
) -> Tokenizer
fn Tokenizer::train_wordpiece(
  texts : Array[String],
  unk_token? : String = "[UNK]", continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None, min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = Some(30000),
  max_input_chars_per_word? : Int = 100, max_token_length? : Int? = None,
  initial_alphabet? : Array[String] = [], limit_alphabet? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer
fn Tokenizer::train_bpe(
  texts : Array[String],
  unk_token? : String? = None, min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = Some(30000),
  continuing_subword_prefix? : String? = None, end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false, initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None, max_token_length? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer
fn Tokenizer::train_unigram(
  texts : Array[String],
  unk_token? : String? = None, min_frequency? : Int = 1,
  special_tokens? : Array[String] = [], vocab_size? : Int? = Some(8000),
  byte_fallback? : Bool = false, fuse_unk? : Bool = true,
  max_piece_length? : Int? = None, initial_alphabet? : Array[String] = [],
  shrinking_factor? : Double = 0.75, n_sub_iterations? : Int = 2,
  show_progress? : Bool = true, seed_size? : Int = 1000000,
) -> Tokenizer
```

Convenience training methods that create a trainer internally and run the
full tokenizer-level training pipeline. `train_wordlevel` creates a WordLevel
tokenizer. `train_wordpiece` creates a WordPiece tokenizer. `train_bpe` creates
a BPE tokenizer. `train_unigram` creates a Unigram tokenizer with N-best
sampling via `seed_size`. All use whitespace pre-tokenization by default.

Each also has a `*_with_pretokenizer` variant accepting a custom `PreTokenizer`
and a `*_from_tokens` variant accepting pre-tokenized `Array[Array[String]]`.

### Standalone model training

```moonbit
fn Model::train_wordlevel(
  texts : Array[String],
  unk_token? : String = "[UNK]", min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = Some(30000),
  show_progress? : Bool = true,
) -> Model
fn Model::train_wordpiece(
  texts : Array[String],
  unk_token? : String = "[UNK]", continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None, min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = Some(30000),
  max_input_chars_per_word? : Int = 100, max_token_length? : Int? = None,
  initial_alphabet? : Array[String] = [], limit_alphabet? : Int? = None,
  show_progress? : Bool = true,
) -> Model
fn Model::train_bpe(
  texts : Array[String],
  unk_token? : String? = None, min_frequency? : Int = 0,
  special_tokens? : Array[String] = [], vocab_size? : Int? = Some(30000),
  continuing_subword_prefix? : String? = None, end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false, initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None, max_token_length? : Int? = None,
  byte_fallback? : Bool = false, ignore_merges? : Bool = false,
  dropout? : Double? = None, cache_capacity? : Int? = None,
  show_progress? : Bool = true,
) -> Model
fn Model::train_unigram(
  texts : Array[String],
  unk_token? : String? = None, min_frequency? : Int = 1,
  special_tokens? : Array[String] = [], vocab_size? : Int? = Some(8000),
  byte_fallback? : Bool = false, fuse_unk? : Bool = true,
  max_piece_length? : Int? = None, initial_alphabet? : Array[String] = [],
  shrinking_factor? : Double = 0.75, n_sub_iterations? : Int = 2,
  show_progress? : Bool = true, seed_size? : Int = 1000000,
) -> Model
```

Model-level training helpers that return a standalone `Model` without a full
tokenizer pipeline. Each has a `*_from_tokens` variant for pre-tokenized input.
These are useful when building only the model component.

## Low-level migration API

### NormalizedString

```moonbit
fn NormalizedString::new(s : String) -> NormalizedString
fn NormalizedString::from_state(state : NormalizedStringState) -> NormalizedString
fn NormalizedString::from_tuple(t : (String, String)) -> NormalizedString
fn NormalizedString::as_tuple(self : NormalizedString) -> (String, String)
fn NormalizedString::get_original(self : NormalizedString) -> String
fn NormalizedString::original(self : NormalizedString) -> String
fn NormalizedString::get(self : NormalizedString) -> String
fn NormalizedString::normalized(self : NormalizedString) -> String
fn NormalizedString::to_string(self : NormalizedString) -> String
fn NormalizedString::len(self : NormalizedString) -> Int
fn NormalizedString::is_empty(self : NormalizedString) -> Bool
fn NormalizedString::normalize(self : NormalizedString, normalizer : Normalizer) -> NormalizedString
fn NormalizedString::append(self : NormalizedString, other : NormalizedString) -> NormalizedString
fn NormalizedString::clear(self : NormalizedString) -> NormalizedString
fn NormalizedString::lowercase(self : NormalizedString) -> NormalizedString
fn NormalizedString::uppercase(self : NormalizedString) -> NormalizedString
fn NormalizedString::lstrip(self : NormalizedString) -> NormalizedString
fn NormalizedString::rstrip(self : NormalizedString) -> NormalizedString
fn NormalizedString::strip(self : NormalizedString) -> NormalizedString
fn NormalizedString::nfc(self : NormalizedString) -> NormalizedString
fn NormalizedString::nfd(self : NormalizedString) -> NormalizedString
fn NormalizedString::nfkc(self : NormalizedString) -> NormalizedString
fn NormalizedString::nfkd(self : NormalizedString) -> NormalizedString
fn NormalizedString::replace(self : NormalizedString, pattern : String, content : String) -> NormalizedString
fn NormalizedString::prepend(self : NormalizedString, s : String) -> NormalizedString
fn NormalizedString::slice(self : NormalizedString, start : Int, stop : Int?) -> NormalizedString?
fn NormalizedString::filter(self : NormalizedString, pred : (Char) -> Bool) -> NormalizedString
fn NormalizedString::map(self : NormalizedString, f : (Char) -> Char) -> NormalizedString
fn NormalizedString::for_each(self : NormalizedString, f : (Char) -> Unit) -> Unit
fn NormalizedString::split(self : NormalizedString, pattern : String) -> Array[NormalizedString]
fn NormalizedString::split_regex(self : NormalizedString, pattern : String) -> Array[NormalizedString]
```

`NormalizedString` exposes HF-style helpers for thin binding layers:
`get` / `normalized` / `to_string`, `get_original` / `original`, `len` /
`__len__`, `is_empty`, state/tuple round-trips, `normalize`, `replace`,
`prepend`, `append`, `clear`, `lowercase`, `uppercase`, `lstrip`, `rstrip`,
`strip`, `nfc`, `nfd`, `nfkc`, `nfkd`, `slice`, `map`, `filter`, literal
`split`, supported deterministic `split_regex`, single-index `get_item` /
`__getitem__`, and `__str__` / `__repr__` display aliases.

### PreTokenizedString

```moonbit
fn PreTokenizedString::new(text : String) -> PreTokenizedString
fn PreTokenizedString::from_splits(splits : Array[Split]) -> PreTokenizedString
fn PreTokenizedString::from_state(state : PreTokenizedStringState) -> PreTokenizedString
fn PreTokenizedString::from_tuple(t : (String, Array[Split])) -> PreTokenizedString
fn PreTokenizedString::as_tuple(self : PreTokenizedString) -> (String, Array[Split])
fn PreTokenizedString::get_original(self : PreTokenizedString) -> String
fn PreTokenizedString::original(self : PreTokenizedString) -> String
fn PreTokenizedString::len(self : PreTokenizedString) -> Int
fn PreTokenizedString::is_empty(self : PreTokenizedString) -> Bool
fn PreTokenizedString::get_splits(self : PreTokenizedString) -> Array[Split]
fn PreTokenizedString::splits(self : PreTokenizedString) -> Array[Split]
fn PreTokenizedString::get_item(self : PreTokenizedString, index : Int) -> Split?
fn PreTokenizedString::normalize(self : PreTokenizedString, normalizer : Normalizer) -> PreTokenizedString
fn PreTokenizedString::split(self : PreTokenizedString, pre_tokenizer : PreTokenizer) -> PreTokenizedString
fn PreTokenizedString::to_encoding(
  self : PreTokenizedString, type_id? : Int = 0,
) -> Encoding raise TokenizerError
fn PreTokenizedString::into_encoding(
  self : PreTokenizedString, type_id? : Int = 0,
) -> Encoding raise TokenizerError
```

`PreTokenizedString` provides `get_splits` / `splits`, single-index
`get_item` / `__getitem__`, `normalize`, pre-tokenizer `split`, state/tuple
helpers, and `to_encoding` / `into_encoding`.

`PreTokenizer::pre_tokenize_str(text)` returns HF-style `(value, offsets)` tuples
for quick component-level checks and binding shims.
`PreTokenizer::byte_level_alphabet()` mirrors HF ByteLevel.alphabet and returns
the same 256-symbol table as `@pretokenizer.byte_level_alphabet()`;
`PreTokenizer::alphabet()` is the exact-name alias for the same helper.
`PreTokenizer` also exposes read-only configuration getters for binding layers,
including ByteLevel flags, Metaspace settings, Split/Punctuation behavior,
Digits/Delimiter/FixedLength settings, and Sequence children. These fields also
have `get_*` aliases such as `get_add_prefix_space`, `get_pattern`, and
`get_individual_digits` for Python binding property access.
Sequence pre-tokenizers support `pre_tokenizers` / `get_pre_tokenizers`,
`__len__`, `get_item`, and `__getitem__`.
It also provides lower-snake builder aliases for common HF constructors such as
`whitespace`, `metaspace`, `punctuation`, `digits`,
`byte_level` (default `add_prefix_space=true`), `char_delimiter_split`,
`split` (`invert=false`, `regex=false` by default), `fixed_length`,
`unicode_scripts`, and `sequence`.
`Normalizer::normalize_str(input)` is available as an HF-style alias for
`normalize(input)`.
`Normalizer` also exposes read-only configuration getters for binding layers,
including `kind`, Strip left/right flags, Replace pattern/content, Prepend
content, BertNormalizer flags, and Sequence child normalizers. These fields also
have `get_*` aliases such as `get_strip_left`, `get_pattern`, and
`get_clean_text` for Python binding property access; `left()` and `right()` are
exact-name aliases for HF `Strip.left` / `Strip.right`. Sequence normalizers expose
both `normalizers` and `get_normalizers` copy-returning getters.
For `BertNormalizer`, `strip_accents()` / `get_strip_accents()` preserve HF's
three-state setting: `None` serializes as JSON `null` and behaves like
`lowercase` during normalization.
It also provides lower-snake builder aliases for common typed constructors such
as `nfc`, `nfd`, `nfkc`, `nfkd`, `byte_level`, `strip`, `replace`,
`prepend_normalizer`, `bert_normalizer`, `lowercase_normalizer`,
`strip_accents_normalizer`, `nmt`, `precompiled`, and `sequence`.
`Decoder` exposes read-only configuration getters for binding layers, including
ByteLevel flags, WordPiece prefix/cleanup, Metaspace replacement/prepend/split
settings, BPEDecoder suffix, Strip/Replace settings, CTC settings, Sequence children, and
Sequence access via `decoders` / `get_decoders` plus `__len__` / `get_item` /
`__getitem__`. These fields also have `get_*` aliases such as
`get_prefix`, `get_cleanup`, `get_split`, and `get_word_delimiter_token` for
Python binding property access.
It also provides lower-snake builder aliases for common HF constructors such as
`byte_level`, `bpe_decoder`, `strip`, `fuse`, and `sequence`.
`PostProcessor` exposes read-only configuration getters for binding layers,
including Bert/Roberta special token pairs, ByteLevel/Roberta flags,
TemplateProcessing typed pieces and special tokens, and Sequence processors.
These fields also have `get_*` aliases such as `get_sep`,
`get_trim_offsets`, `get_single_pieces`, and `get_special_tokens` for Python
binding property access.
HF class-name style constructor aliases are also available:
`bert_processing`, `roberta_processing`, and `template_processing`.
TemplateProcessing exposes typed `single()` and `pair()` aliases for its
templates.
`Piece` exposes `kind` / `get_kind`, `id` / `get_id`, `type_id` /
`get_type_id`, and tuple interop for SequenceRef /
SpecialTokenRef template leaves, plus `__str__` / `__repr__` display aliases.
`SpecialToken` exposes tuple interop plus copy-returning `id` / `ids` / `tokens`
getters and `__str__` / `__repr__`.
Sequence post-processors support `processors` / `get_processors`, `__len__`,
`get_item`, and `__getitem__`.
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
Unigram trainers. Common fields also expose HF-style `get_*` aliases:
`get_unk_token`, `get_min_frequency`, `get_special_tokens`,
`get_special_added_tokens`, `get_vocab_size`, and `get_show_progress`; the
model-specific knobs expose matching `get_*` aliases as well, including prefix,
suffix, alphabet, max-length, byte-fallback/fuse-unk, shrinking, seed, and
progress-format fields.
Binding layers can also use lower-snake constructor aliases:
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
Non-vocab model configuration fields also provide `get_*` aliases such as
`get_unk_token`, `get_continuing_subword_prefix`, `get_byte_fallback`, and
`get_dropout` for binding property access.

`Tokenizer::__str__()` and `Tokenizer::__repr__()` are thin Python binding
aliases for the compact `to_str()` JSON form. `TokenizerState::new(json)`
matches the other JSON-backed state wrappers for binding/pickle shims.

`TokenizerComponentHooks` provides runtime-only normalize, pre-tokenize, and
decode callbacks for binding layers that cannot map a dynamic Python component
to a typed MoonBit component yet. Hooks can be passed per call or attached to a
tokenizer. They are intentionally excluded from tokenizer JSON/state; use typed
components for serialized round-trips.

## Unicode script coverage

The deterministic regex subset covers the following Unicode letter scripts
(matching HF Rust regex engine coverage): Latin, Latin Extended Additional,
Greek, Greek Extended, Cyrillic, Armenian, Hebrew, Arabic, Devanagari, Bengali,
Gurmukhi, Gujarati, Oriya, Tamil, Telugu, Kannada, Malayalam, Sinhala, Thai,
Lao, Tibetan, Myanmar, Georgian, Khmer, Ethiopic, Cherokee, Canadian Aboriginal
Syllabics, Ogham, Runic, Hiragana, Katakana, CJK Unified Ideographs (including
Extension A, Extension B, Extension C/D), CJK Compatibility Ideographs,
Hangul Syllables, and Hangul Jamo (including Extended-A/B).
The `\p{S}` symbol class covers currency, math, technical, dingbat, emoji, and
miscellaneous mathematical symbol blocks (including 0x27C0-0x27EF and 0x2980-0x29FF).
The `\p{N}` / `\d` digit class covers 18 Unicode digit ranges: ASCII,
Arabic-Indic, Extended Arabic-Indic, Devanagari, Bengali, Gurmukhi,
Gujarati, Oriya, Tamil, Telugu, Kannada, Malayalam, Thai, Lao, Tibetan,
Myanmar, Khmer, and Fullwidth. Complex unknown patterns are explicitly
rejected at load time as `Unsupported`.

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
- Loaded `Replace` components preserve HF's tagged pattern shape: `{String: ...}`
  uses literal substring replacement, while `{Regex: ...}` uses the deterministic
  regex subset above. The binding-friendly `replace(...)` factories create the
  literal-string form; `replace_regex(...)` creates the regex form.
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

#### Encoding getter aliases

```moonbit
fn Encoding::get_n_sequences(self : Encoding) -> Int
fn Encoding::get_char_token(self : Encoding, pos : Int, sequence_id? : Int) -> Int?
fn Encoding::get_char_word(self : Encoding, pos : Int, sequence_id? : Int) -> Int?
fn Encoding::get_token_chars(self : Encoding, token : Int) -> (Int, (Int, Int))?
fn Encoding::get_token_sequence(self : Encoding, token : Int) -> Int?
fn Encoding::get_token_word(self : Encoding, token : Int) -> (Int, Int)?
fn Encoding::get_word_chars(self : Encoding, word : Int, sequence_id? : Int) -> (Int, Int)?
fn Encoding::get_word_tokens(self : Encoding, word : Int, sequence_id? : Int) -> (Int, Int)?
```

`get_*` aliases for HF Python binding compatibility. These return the same
values as their non-`get_` counterparts.

### Encoding methods

```moonbit
fn Encoding::ids(self : Encoding) -> Array[Int]
fn Encoding::type_ids(self : Encoding) -> Array[Int]
fn Encoding::tokens(self : Encoding) -> Array[String]
fn Encoding::offsets(self : Encoding) -> Array[(Int, Int)]
fn Encoding::special_tokens_mask(self : Encoding) -> Array[Int]
fn Encoding::attention_mask(self : Encoding) -> Array[Int]
fn Encoding::sequence_ids(self : Encoding) -> Array[Int?]
fn Encoding::word_ids(self : Encoding) -> Array[Int?]
fn Encoding::words(self : Encoding) -> Array[Int?]  // deprecated alias for word_ids
fn Encoding::overflowing(self : Encoding) -> Array[Encoding]
fn Encoding::n_sequences(self : Encoding) -> Int
fn Encoding::len(self : Encoding) -> Int
fn Encoding::is_empty(self : Encoding) -> Bool
fn Encoding::empty() -> Encoding

fn Encoding::char_to_token(self : Encoding, pos : Int, sequence_id? : Int) -> Int?
fn Encoding::char_to_token_by_sequence_index(self : Encoding, pos : Int, sequence_index? : Int = 0) -> Int?
fn Encoding::char_to_word(self : Encoding, pos : Int, sequence_id? : Int) -> Int?
fn Encoding::char_to_word_by_sequence_index(self : Encoding, pos : Int, sequence_index? : Int = 0) -> Int?
fn Encoding::token_to_chars(self : Encoding, token : Int) -> (Int, (Int, Int))?
fn Encoding::token_to_char_offsets(self : Encoding, token : Int) -> (Int, Int)?
fn Encoding::token_to_word(self : Encoding, token : Int) -> (Int, Int)?
fn Encoding::token_to_word_index(self : Encoding, token : Int) -> Int?
fn Encoding::token_to_sequence(self : Encoding, token : Int) -> Int?
fn Encoding::token_to_offsets(self : Encoding, token : Int) -> (Int, Int)?
fn Encoding::word_to_tokens(self : Encoding, word : Int, sequence_id? : Int) -> (Int, Int)?
fn Encoding::word_to_tokens_by_sequence_index(self : Encoding, word : Int, sequence_index? : Int = 0) -> (Int, Int)?
fn Encoding::word_to_chars(self : Encoding, word : Int, sequence_id? : Int) -> (Int, Int)?
fn Encoding::word_to_chars_by_sequence_index(self : Encoding, word : Int, sequence_index? : Int = 0) -> (Int, Int)?
fn Encoding::word_to_offsets(self : Encoding, word : Int, sequence_id? : Int) -> (Int, Int)?

fn Encoding::from_state(state : EncodingState) -> Encoding raise TokenizerError
fn Encoding::get_state(self : Encoding) -> EncodingState
fn Encoding::from_tuple(tuple : ...) -> Encoding raise TokenizerError
fn Encoding::as_tuple(self : Encoding) -> (...)
fn Encoding::from_buffers(buffers : EncodingBuffers, ...) -> Encoding raise TokenizerError
fn Encoding::as_buffers(self : Encoding) -> EncodingBuffers
fn Encoding::get_buffers(self : Encoding) -> EncodingBuffers

fn Encoding::with_type_ids(self : Encoding, type_ids : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::set_type_ids(self : Encoding, type_ids : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_special_tokens_mask(self : Encoding, mask : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::set_special_tokens_mask(self : Encoding, mask : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_attention_mask(self : Encoding, mask : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::set_attention_mask(self : Encoding, mask : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_word_ids(self : Encoding, word_ids : Array[Int?]) -> Encoding raise TokenizerError
fn Encoding::set_word_ids(self : Encoding, word_ids : Array[Int?]) -> Encoding raise TokenizerError
fn Encoding::with_sequence_id(self : Encoding, sequence_id : Int) -> Encoding raise TokenizerError
fn Encoding::set_sequence_id(self : Encoding, sequence_id : Int) -> Encoding raise TokenizerError
fn Encoding::with_ids(self : Encoding, ids : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::set_ids(self : Encoding, ids : Array[Int]) -> Encoding raise TokenizerError
fn Encoding::with_tokens(self : Encoding, tokens : Array[String]) -> Encoding raise TokenizerError
fn Encoding::set_tokens(self : Encoding, tokens : Array[String]) -> Encoding raise TokenizerError
fn Encoding::with_offsets(self : Encoding, offsets : Array[(Int, Int)]) -> Encoding raise TokenizerError
fn Encoding::set_offsets(self : Encoding, offsets : Array[(Int, Int)]) -> Encoding raise TokenizerError
fn Encoding::with_overflowing(self : Encoding, overflowing : Array[Encoding]) -> Encoding raise TokenizerError
fn Encoding::set_overflowing(self : Encoding, overflowing : Array[Encoding]) -> Encoding raise TokenizerError

fn Encoding::truncate(self : Encoding, max_len : Int, stride? : Int = 0, direction? : TruncationDirection = Right) -> Encoding raise TokenizerError
fn Encoding::truncate_hf(self : Encoding, max_len : Int, stride? : Int = 0, direction? : String = "right") -> Encoding raise TokenizerError
fn Encoding::pad(self : Encoding, length : Int, ...) -> Encoding raise TokenizerError
fn Encoding::pad_hf(self : Encoding, length : Int, direction? : String = "right", ...) -> Encoding raise TokenizerError
fn Encoding::merge(encodings : Array[Encoding], growing_offsets? : Bool = true) -> Encoding
fn Encoding::merge_with(self : Encoding, other : Encoding, growing_offsets? : Bool = true) -> Encoding

fn Encoding::from_tokens(tokens : Array[Token], type_id? : Int) -> Encoding
```

Property-style accessors return arrays (copies) for HF compatibility.
`char_to_token` / `char_to_word` / `token_to_chars` / `word_to_tokens` etc.
provide bidirectional index mapping. `truncate_hf` / `pad_hf` accept HF-style
string direction. `merge` / `merge_with` combine encodings.

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
fn TruncationParams::with_direction_hf(self : TruncationParams, direction : String) -> TruncationParams raise TokenizerError
fn TruncationParams::with_strategy(self : TruncationParams, strategy : TruncationStrategy) -> TruncationParams
fn TruncationParams::with_strategy_hf(self : TruncationParams, strategy : String) -> TruncationParams raise TokenizerError
fn TruncationParams::direction_string(self : TruncationParams) -> String
fn TruncationParams::get_direction_string(self : TruncationParams) -> String
fn TruncationParams::strategy_string(self : TruncationParams) -> String
fn TruncationParams::get_strategy_string(self : TruncationParams) -> String
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
fn PaddingParams::with_direction_hf(self : PaddingParams, direction : String) -> PaddingParams raise TokenizerError
fn PaddingParams::with_pad_type_id(self : PaddingParams, pad_type_id : Int) -> PaddingParams
fn PaddingParams::with_pad_to_multiple_of(self : PaddingParams, pad_to_multiple_of : Int?) -> PaddingParams
fn PaddingParams::direction_string(self : PaddingParams) -> String
fn PaddingParams::get_direction_string(self : PaddingParams) -> String
```

### EncodeInput (`@tokenizer`)

```moonbit
pub enum TextInputSequence {
  Text(String)
  PreTokenized(Array[String])
}

pub enum EncodeInput {
  SingleInput(TextInputSequence)
  PairInput(TextInputSequence, TextInputSequence)
}

fn TextInputSequence::text(text : String) -> TextInputSequence
fn TextInputSequence::pretokenized(words : Array[String]) -> TextInputSequence

fn EncodeInput::single(text : String) -> EncodeInput
fn EncodeInput::single_pretokenized(words : Array[String]) -> EncodeInput
fn EncodeInput::pair(text_a : String, text_b : String) -> EncodeInput
fn EncodeInput::pair_pretokenized(words_a : Array[String], words_b : Array[String]) -> EncodeInput
fn EncodeInput::mixed_pair(a : TextInputSequence, b : TextInputSequence) -> EncodeInput
```

Unified encode input type used by `encode_input`, `encode_plus`,
`batch_encode_plus` and their async/fast variants. `TextInputSequence`
distinguishes raw text from pre-tokenized word arrays. `EncodeInput` wraps
single or pair inputs, letting callers mix raw text and pre-tokenized
sequences in pair encoding.

### TokenizerError (`@types`)

```moonbit
pub(all) suberror TokenizerError {
  ParseError(String)            // malformed / unexpected tokenizer.json
  UnsupportedComponent(String)  // component type not yet implemented
  VocabError(String)            // malformed vocab / merges
}
```
