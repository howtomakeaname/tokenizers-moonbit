// Top-level Tokenizer assembly and public API.
//
// P1: parse the full tokenizer.json into typed components. encode/decode are
// added in later phases (P2+); for now they are declared as TODO stubs so the
// public surface is visible.

///|
/// A loaded tokenizer: the full decoded pipeline.
pub struct Tokenizer {
  normalizer : @normalizer.Normalizer?
  pre_tokenizer : @pretokenizer.PreTokenizer?
  model : @model.Model
  post_processor : @processor.PostProcessor?
  decoder : @decoder.Decoder?
  added_vocabulary : AddedVocabulary
  mut truncation : TruncationParams?
  mut padding : PaddingParams?
  // Original tokenizer.json payload. `to_json`/`save` preserve it verbatim so a
  // loaded HF tokenizer can round-trip through MoonBit without losing fields we
  // do not yet model (trainers, metadata, full regex text, etc.).
  mut source_json : String?
}

///|
/// Serializable/interoperable snapshot of a full `Tokenizer`. Python binding
/// layers can pickle this stable JSON state and restore through `__setstate__`
/// without depending on MoonBit-internal component layout.
pub struct TokenizerState {
  json : String
} derive(Debug, Eq)

///|
/// Minimal HF-style normalized string wrapper. It keeps both the original and
/// current normalized text and exposes common mutation helpers used by custom
/// normalizer migrations. Offset tracking is conservative: transforms that
/// change length reset offsets to the normalized string's char positions.
pub struct NormalizedString {
  original : String
  normalized : String
}

///|
pub fn NormalizedString::new(s : String) -> NormalizedString {
  { original: s, normalized: s }
}

///|
pub fn NormalizedString::get_original(self : NormalizedString) -> String {
  self.original
}

///|
pub fn NormalizedString::get(self : NormalizedString) -> String {
  self.normalized
}

///|
pub fn NormalizedString::len(self : NormalizedString) -> Int {
  self.normalized.char_length()
}

///|
pub fn NormalizedString::is_empty(self : NormalizedString) -> Bool {
  self.normalized.is_empty()
}

///|
pub fn NormalizedString::normalize(
  self : NormalizedString,
  normalizer : @normalizer.Normalizer,
) -> NormalizedString {
  { ..self, normalized: normalizer.normalize(self.normalized) }
}

///|
pub fn NormalizedString::replace(
  self : NormalizedString,
  pattern : String,
  content : String,
) -> NormalizedString {
  {
    ..self,
    normalized: @common.replace_literal(self.normalized, pattern, content),
  }
}

///|
pub fn NormalizedString::prepend(
  self : NormalizedString,
  prefix : String,
) -> NormalizedString {
  { ..self, normalized: prefix + self.normalized }
}

///|
pub fn NormalizedString::slice(
  self : NormalizedString,
  start : Int,
  stop : Int,
) -> NormalizedString {
  let chars = self.normalized.to_array()
  let a = clamp_int(start, 0, chars.length())
  let b = clamp_int(stop, a, chars.length())
  let sb = StringBuilder::new()
  for i in a..<b {
    sb.write_char(chars[i])
  }
  { original: self.original, normalized: sb.to_string() }
}

///|
pub fn NormalizedString::filter(
  self : NormalizedString,
  keep : (Char) -> Bool,
) -> NormalizedString {
  let sb = StringBuilder::new()
  for c in self.normalized {
    if keep(c) {
      sb.write_char(c)
    }
  }
  { ..self, normalized: sb.to_string() }
}

///|
pub fn NormalizedString::map(
  self : NormalizedString,
  f : (Char) -> String,
) -> NormalizedString {
  let sb = StringBuilder::new()
  for c in self.normalized {
    sb.write_string(f(c))
  }
  { ..self, normalized: sb.to_string() }
}

///|
pub fn NormalizedString::split(
  self : NormalizedString,
  pattern : String,
) -> Array[NormalizedString] {
  let spans = @common.literal_matches(self.normalized.to_array(), pattern)
  match spans {
    Some(matches) => split_normalized_by_spans(self, matches)
    None => [self]
  }
}

///|
pub fn NormalizedString::split_regex(
  self : NormalizedString,
  regex : @common.Regex,
) -> Array[NormalizedString]? {
  match regex.find_matches(self.normalized) {
    Some(raw_spans) => {
      let spans : Array[@common.Span] = raw_spans.map(p => {
        start: p.0,
        stop: p.1,
      })
      Some(split_normalized_by_spans(self, spans))
    }
    None => None
  }
}

///|
fn split_normalized_by_spans(
  ns : NormalizedString,
  spans : Array[@common.Span],
) -> Array[NormalizedString] {
  let chars = ns.normalized.to_array()
  let out : Array[NormalizedString] = []
  let mut cursor = 0
  for span in spans {
    if span.start > cursor {
      out.push(ns.slice(cursor, span.start))
    }
    cursor = span.stop
  }
  if cursor < chars.length() {
    out.push(ns.slice(cursor, chars.length()))
  }
  out
}

///|
/// Minimal HF-style pre-tokenized string wrapper. Splits are ordinary
/// tokenizer `Split` values and can be normalized, pre-tokenized further, or
/// converted into an Encoding with a Model.
pub struct PreTokenizedString {
  original : String
  splits : Array[@types.Split]
}

///|
pub fn PreTokenizedString::new(text : String) -> PreTokenizedString {
  {
    original: text,
    splits: [{ value: text, offsets: (0, text.char_length()) }],
  }
}

///|
pub fn PreTokenizedString::from_splits(
  splits : Array[@types.Split],
) -> PreTokenizedString {
  let sb = StringBuilder::new()
  for i, s in splits {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string(s.value)
  }
  { original: sb.to_string(), splits: splits.copy() }
}

///|
pub fn PreTokenizedString::get_splits(
  self : PreTokenizedString,
) -> Array[@types.Split] {
  self.splits.copy()
}

///|
pub fn PreTokenizedString::normalize(
  self : PreTokenizedString,
  normalizer : @normalizer.Normalizer,
) -> PreTokenizedString {
  let out : Array[@types.Split] = []
  for s in self.splits {
    let value = normalizer.normalize(s.value)
    out.push({
      value,
      offsets: (s.offsets.0, s.offsets.0 + value.char_length()),
    })
  }
  { ..self, splits: out }
}

///|
pub fn PreTokenizedString::split(
  self : PreTokenizedString,
  pre_tokenizer : @pretokenizer.PreTokenizer,
) -> PreTokenizedString {
  let out : Array[@types.Split] = []
  for s in self.splits {
    for p in pre_tokenizer.pre_tokenize(s.value, base_offset=s.offsets.0) {
      out.push(p)
    }
  }
  { ..self, splits: out }
}

///|
pub fn PreTokenizedString::to_encoding(
  self : PreTokenizedString,
  model : @model.Model,
  type_id? : Int = 0,
) -> @types.Encoding {
  let toks : Array[@types.Token] = []
  for s in self.splits {
    for t in model.tokenize(s.value, offset=s.offsets.0) {
      toks.push(t)
    }
  }
  @types.Encoding::from_tokens(toks, type_id~)
}

///|
fn clamp_int(n : Int, lo : Int, hi : Int) -> Int {
  if n < lo {
    lo
  } else if n > hi {
    hi
  } else {
    n
  }
}

// `from_str` is often called repeatedly with the same stable tokenizer.json in
// benchmarks, REPLs and tests. Cache only parsed JSON trees (not Tokenizers), so
// each call still builds fresh mutable model/added-token caches and builder
// state while avoiding the largest repeated parse cost. Keep a few entries so
// alternating model loads (e.g. gpt2 + bert in services/tests) stay hot.

///|
let from_str_parse_cache : Map[String, Json] = {}

///|
let from_str_parse_cache_limit : Int = 4

///|
/// Create a tokenizer from a model and attach pipeline components with builder
/// methods (`with_normalizer`, `with_pre_tokenizer`, `with_post_processor`,
/// `with_decoder`, `with_truncation`, `with_padding`). Mirrors HF's
/// `Tokenizer(model)` construction flow.
pub fn Tokenizer::new(model : @model.Model) -> Tokenizer {
  {
    normalizer: None,
    pre_tokenizer: None,
    model,
    post_processor: None,
    decoder: None,
    added_vocabulary: AddedVocabulary::new([]),
    truncation: None,
    padding: None,
    source_json: None,
  }
}

///|
/// Load a tokenizer from the textual contents of a `tokenizer.json`.
///
/// Backend-agnostic main entry point: takes a `String`, no file IO, so it works
/// on every backend (wasm/wasm-gc/js/native).
pub fn Tokenizer::from_str(
  json : String,
) -> Tokenizer raise @types.TokenizerError {
  let parsed = parse_tokenizer_json(json)
  let root = @types.as_object(parsed, "tokenizer.json root")

  // model is mandatory.
  let model = match root.get("model") {
    Some(m) => @model.Model::from_json(m)
    None => raise @types.ParseError("tokenizer.json missing \"model\"")
  }

  // The rest are optional and may be JSON null.
  let normalizer = decode_opt(root, "normalizer", j => {
    @normalizer.Normalizer::from_json(j)
  })
  let pre_tokenizer = decode_opt(root, "pre_tokenizer", j => {
    @pretokenizer.PreTokenizer::from_json(j)
  })
  let post_processor = decode_opt(root, "post_processor", j => {
    @processor.PostProcessor::from_json(j)
  })
  let decoder = decode_opt(root, "decoder", j => @decoder.Decoder::from_json(j))
  let added_vocabulary = AddedVocabulary::new_with_encode_special_tokens(
    parse_added_tokens(root),
    @types.get_bool(root, "encode_special_tokens", default=false),
  ).with_normalizer(normalizer)
  let truncation = decode_opt(root, "truncation", parse_truncation)
  let padding = decode_opt(root, "padding", parse_padding)
  {
    normalizer,
    pre_tokenizer,
    model,
    post_processor,
    decoder,
    added_vocabulary,
    truncation,
    padding,
    source_json: Some(json),
  }
}

///|
/// Load a tokenizer from a UTF-8 `tokenizer.json` byte buffer. This is the
/// byte-oriented counterpart of `from_str`, matching HF's `from_buffer` style
/// migration path while remaining backend-agnostic.
pub fn Tokenizer::from_buffer(
  buffer : Bytes,
) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_str(@utf8.decode_lossy(buffer[:]))
}

///|
/// Load a tokenizer from a UTF-8 `tokenizer.json` byte buffer.
pub fn from_buffer(buffer : Bytes) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_buffer(buffer)
}

///|
fn parse_tokenizer_json(json : String) -> Json raise @types.TokenizerError {
  match from_str_parse_cache.get(json) {
    Some(parsed) => return parsed
    None => ()
  }
  let parsed = @json.parse(json) catch {
    err => raise @types.ParseError("invalid tokenizer.json: \{err}")
  }
  if from_str_parse_cache.length() >= from_str_parse_cache_limit {
    from_str_parse_cache.clear()
  }
  from_str_parse_cache[json] = parsed
  parsed
}

///|
/// Export this tokenizer back to tokenizer.json text. For tokenizers loaded via
/// `from_str` / `from_file`, this preserves the original JSON verbatim so that
/// unsupported-but-parseable HF metadata survives a load/save round-trip.
pub fn Tokenizer::to_json(
  self : Tokenizer,
) -> String raise @types.TokenizerError {
  match self.source_json {
    Some(json) => json
    None =>
      match self.model.to_json() {
        Some(model_json) => {
          let normalizer_json = match self.normalizer {
            Some(nm) =>
              match nm.to_json() {
                Some(json) => json
                None =>
                  raise @types.ParseError("normalizer has no serialized form")
              }
            None => "null"
          }
          let pt_json = match self.pre_tokenizer {
            Some(pt) =>
              match pt.to_json() {
                Some(json) => json
                None =>
                  raise @types.ParseError(
                    "pre_tokenizer has no serialized form",
                  )
              }
            None => "null"
          }
          let pp_json = match self.post_processor {
            Some(pp) =>
              match pp.to_json() {
                Some(json) => json
                None =>
                  raise @types.ParseError(
                    "post_processor has no serialized form",
                  )
              }
            None => "null"
          }
          let decoder_json = match self.decoder {
            Some(dec) =>
              match dec.to_json() {
                Some(json) => json
                None =>
                  raise @types.ParseError("decoder has no serialized form")
              }
            None => "null"
          }
          let json = "{\"version\":\"1.0\",\"added_tokens\":" +
            added_tokens_to_json(self.added_vocabulary.to_infos()) +
            ",\"normalizer\":" +
            normalizer_json +
            ",\"pre_tokenizer\":" +
            pt_json +
            ",\"model\":" +
            model_json +
            ",\"post_processor\":" +
            pp_json +
            ",\"decoder\":" +
            decoder_json +
            ",\"encode_special_tokens\":" +
            bool_json(self.added_vocabulary.get_encode_special_tokens()) +
            ",\"truncation\":" +
            truncation_to_json(self.truncation) +
            ",\"padding\":" +
            padding_to_json(self.padding) +
            "}"
          self.source_json = Some(json)
          json
        }
        None => raise @types.ParseError("tokenizer has no serialized source")
      }
  }
}

///|
/// HF-style alias for exporting tokenizer JSON. `pretty=false` preserves the
/// exact minified/verbatim behavior of `to_json`; `pretty=true` parses the same
/// JSON and re-emits it with two-space indentation for human-readable saves.
pub fn Tokenizer::to_str(
  self : Tokenizer,
  pretty? : Bool = false,
) -> String raise @types.TokenizerError {
  format_tokenizer_json(self.to_json(), pretty~)
}

///|
/// Return a Python-binding-friendly tokenizer state snapshot.
pub fn Tokenizer::get_state(
  self : Tokenizer,
) -> TokenizerState raise @types.TokenizerError {
  { json: self.to_json() }
}

///|
/// Restore a tokenizer from a state snapshot produced by `get_state` or
/// `__getstate__`.
pub fn Tokenizer::from_state(
  state : TokenizerState,
) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_str(state.json)
}

///|
/// Python pickle compatibility alias for `get_state`.
pub fn Tokenizer::__getstate__(
  self : Tokenizer,
) -> TokenizerState raise @types.TokenizerError {
  self.get_state()
}

///|
/// Python pickle compatibility alias for restoring tokenizer state.
pub fn Tokenizer::__setstate__(
  state : TokenizerState,
) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_state(state)
}

///|
fn format_tokenizer_json(
  json : String,
  pretty~ : Bool,
) -> String raise @types.TokenizerError {
  if !pretty {
    return json
  }
  let parsed = @json.parse(json) catch {
    err => raise @types.ParseError("cannot pretty-print tokenizer.json: \{err}")
  }
  parsed.stringify(indent=2)
}

///|
/// Attach/clear a normalizer (builder; returns a fresh tokenizer value).
pub fn Tokenizer::with_normalizer(
  self : Tokenizer,
  normalizer : @normalizer.Normalizer?,
) -> Tokenizer {
  {
    ..self,
    normalizer,
    added_vocabulary: self.added_vocabulary.with_normalizer(normalizer),
    source_json: None,
  }
}

///|
/// Attach/clear a pre-tokenizer (builder; returns a fresh tokenizer value).
pub fn Tokenizer::with_pre_tokenizer(
  self : Tokenizer,
  pre_tokenizer : @pretokenizer.PreTokenizer?,
) -> Tokenizer {
  { ..self, pre_tokenizer, source_json: None }
}

///|
/// Replace the model (builder; returns a fresh tokenizer value).
pub fn Tokenizer::with_model(
  self : Tokenizer,
  model : @model.Model,
) -> Tokenizer {
  { ..self, model, source_json: None }
}

///|
/// Attach/clear a post-processor (builder; returns a fresh tokenizer value).
pub fn Tokenizer::with_post_processor(
  self : Tokenizer,
  post_processor : @processor.PostProcessor?,
) -> Tokenizer {
  { ..self, post_processor, source_json: None }
}

///|
/// Attach/clear a decoder (builder; returns a fresh tokenizer value).
pub fn Tokenizer::with_decoder(
  self : Tokenizer,
  decoder : @decoder.Decoder?,
) -> Tokenizer {
  { ..self, decoder, source_json: None }
}

///|
/// Enable/disable truncation (builder; mutates and returns self).
pub fn Tokenizer::with_truncation(
  self : Tokenizer,
  params : TruncationParams?,
) -> Tokenizer {
  self.truncation = params
  self.source_json = None
  self
}

///|
/// HF-style mutating alias for truncation configuration. Keeps the current
/// builder ergonomics by mutating and returning `self`, while accepting the
/// common `enable_truncation(max_length, stride=..., strategy=..., direction=...)`
/// shape used by HuggingFace tokenizers users.
pub fn Tokenizer::enable_truncation(
  self : Tokenizer,
  max_length : Int,
  stride? : Int = 0,
  strategy? : TruncationStrategy = LongestFirst,
  direction? : TruncationDirection = Right,
) -> Tokenizer {
  self.with_truncation(
    Some(
      TruncationParams::new(max_length)
      .with_stride(stride)
      .with_strategy(strategy)
      .with_direction(direction),
    ),
  )
}

///|
/// HF-style mutating alias for clearing truncation configuration.
pub fn Tokenizer::no_truncation(self : Tokenizer) -> Tokenizer {
  self.with_truncation(None)
}

///|
/// Enable/disable padding (builder; mutates and returns self).
pub fn Tokenizer::with_padding(
  self : Tokenizer,
  params : PaddingParams?,
) -> Tokenizer {
  self.padding = params
  self.source_json = None
  self
}

///|
/// HF-style mutating alias for padding configuration. `length=None` selects
/// batch-longest padding; `Some(length)` selects fixed-length padding.
pub fn Tokenizer::enable_padding(
  self : Tokenizer,
  length? : Int? = None,
  direction? : PaddingDirection = Right,
  pad_id? : Int = 0,
  pad_type_id? : Int = 0,
  pad_token? : String = "[PAD]",
  pad_to_multiple_of? : Int? = None,
) -> Tokenizer {
  let strategy = match length {
    Some(n) => Fixed(n)
    None => BatchLongest
  }
  self.with_padding(
    Some(
      PaddingParams::new(strategy, pad_id~, pad_token~)
      .with_direction(direction)
      .with_pad_type_id(pad_type_id)
      .with_pad_to_multiple_of(pad_to_multiple_of),
    ),
  )
}

///|
/// HF-style mutating alias for clearing padding configuration.
pub fn Tokenizer::no_padding(self : Tokenizer) -> Tokenizer {
  self.with_padding(None)
}

///|
/// Return the current normalizer component, if any.
pub fn Tokenizer::get_normalizer(self : Tokenizer) -> @normalizer.Normalizer? {
  self.normalizer
}

///|
/// Python/property-style alias for `get_normalizer`.
pub fn Tokenizer::normalizer(self : Tokenizer) -> @normalizer.Normalizer? {
  self.get_normalizer()
}

///|
/// Return the current pre-tokenizer component, if any.
pub fn Tokenizer::get_pre_tokenizer(
  self : Tokenizer,
) -> @pretokenizer.PreTokenizer? {
  self.pre_tokenizer
}

///|
/// Python/property-style alias for `get_pre_tokenizer`.
pub fn Tokenizer::pre_tokenizer(
  self : Tokenizer,
) -> @pretokenizer.PreTokenizer? {
  self.get_pre_tokenizer()
}

///|
/// Return the current model component.
pub fn Tokenizer::get_model(self : Tokenizer) -> @model.Model {
  self.model
}

///|
/// Python/property-style alias for `get_model`.
pub fn Tokenizer::model(self : Tokenizer) -> @model.Model {
  self.get_model()
}

///|
/// Clear model-level tokenization caches while keeping tokenizer configuration
/// unchanged. Returns `self` for builder-style chaining, matching HF-style cache
/// maintenance ergonomics.
pub fn Tokenizer::clear_cache(self : Tokenizer) -> Tokenizer {
  self.model.clear_cache()
  self
}

///|
/// Resize model-level tokenization caches. `capacity=0` disables future model
/// cache inserts; negative values are clamped to zero. Returns `self` for
/// chaining and leaves tokenization semantics unchanged.
pub fn Tokenizer::resize_cache(self : Tokenizer, capacity : Int) -> Tokenizer {
  self.model.resize_cache(capacity)
  self
}

///|
/// Return the number of currently cached model word tokenizations.
pub fn Tokenizer::cache_size(self : Tokenizer) -> Int {
  self.model.cache_size()
}

///|
/// Return the current post-processor component, if any.
pub fn Tokenizer::get_post_processor(
  self : Tokenizer,
) -> @processor.PostProcessor? {
  self.post_processor
}

///|
/// Python/property-style alias for `get_post_processor`.
pub fn Tokenizer::post_processor(self : Tokenizer) -> @processor.PostProcessor? {
  self.get_post_processor()
}

///|
/// Return the current decoder component, if any.
pub fn Tokenizer::get_decoder(self : Tokenizer) -> @decoder.Decoder? {
  self.decoder
}

///|
/// Python/property-style alias for `get_decoder`.
pub fn Tokenizer::decoder(self : Tokenizer) -> @decoder.Decoder? {
  self.get_decoder()
}

///|
/// Return the current truncation configuration, if any.
pub fn Tokenizer::get_truncation(self : Tokenizer) -> TruncationParams? {
  self.truncation
}

///|
/// Python/property-style alias for `get_truncation`.
pub fn Tokenizer::truncation(self : Tokenizer) -> TruncationParams? {
  self.get_truncation()
}

///|
/// Return the current padding configuration, if any.
pub fn Tokenizer::get_padding(self : Tokenizer) -> PaddingParams? {
  self.padding
}

///|
/// Python/property-style alias for `get_padding`.
pub fn Tokenizer::padding(self : Tokenizer) -> PaddingParams? {
  self.get_padding()
}

///|
/// HF-style switch: when true, special tokens appearing in input text are kept
/// on the ordinary model path instead of being extracted as special added
/// tokens. Defaults to false, matching HF tokenizers.
pub fn Tokenizer::set_encode_special_tokens(
  self : Tokenizer,
  value : Bool,
) -> Tokenizer {
  {
    ..self,
    added_vocabulary: self.added_vocabulary.with_encode_special_tokens(value),
    source_json: None,
  }
}

///|
/// HF-style convenience alias for enabling literal special-token encoding.
pub fn Tokenizer::enable_encode_special_tokens(self : Tokenizer) -> Tokenizer {
  self.set_encode_special_tokens(true)
}

///|
/// HF-style convenience alias for restoring special-token extraction.
pub fn Tokenizer::disable_encode_special_tokens(self : Tokenizer) -> Tokenizer {
  self.set_encode_special_tokens(false)
}

///|
pub fn Tokenizer::get_encode_special_tokens(self : Tokenizer) -> Bool {
  self.added_vocabulary.get_encode_special_tokens()
}

///|
/// Python/property-style alias for `get_encode_special_tokens`.
pub fn Tokenizer::encode_special_tokens(self : Tokenizer) -> Bool {
  self.get_encode_special_tokens()
}

///|
/// Return `id -> AddedToken` for all added/special tokens.
pub fn Tokenizer::get_added_tokens_decoder(
  self : Tokenizer,
) -> Map[Int, AddedToken] {
  self.added_vocabulary.get_added_tokens_decoder()
}

///|
/// Python/property-style alias for `get_added_tokens_decoder`.
pub fn Tokenizer::added_tokens_decoder(
  self : Tokenizer,
) -> Map[Int, AddedToken] {
  self.get_added_tokens_decoder()
}

///|
/// Check whether a token string is registered as a special added token.
pub fn Tokenizer::is_special_token(self : Tokenizer, token : String) -> Bool {
  self.added_vocabulary.is_special_token(token)
}

///|
/// Number of special tokens the post-processor would add for a single or pair
/// input. Mirrors HF's `num_special_tokens_to_add` helper.
pub fn Tokenizer::num_special_tokens_to_add(
  self : Tokenizer,
  is_pair? : Bool = false,
) -> Int {
  match self.post_processor {
    Some(pp) => pp.added_tokens(pair=is_pair)
    None => 0
  }
}

///|
/// Apply this tokenizer's post-processor to already-built encodings. This is the
/// explicit counterpart of `encode(..., add_special_tokens=true)`.
pub fn Tokenizer::post_process(
  self : Tokenizer,
  encoding : @types.Encoding,
  pair? : @types.Encoding? = None,
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  let is_pair = pair is Some(_)
  let (encoding, pair) = match
    self.truncation_for_raw(pair=is_pair, add_special_tokens~) {
    Some(tp) => truncate_pair_raw(encoding, pair, tp)
    None => (encoding, pair)
  }
  let processed = if add_special_tokens {
    match self.post_processor {
      Some(pp) => pp.process(encoding, pair)
      None => default_post_process(encoding, pair)
    }
  } else {
    default_post_process(encoding, pair)
  }
  self.finalize_padding(processed)
}

///|
fn default_post_process(
  encoding : @types.Encoding,
  pair : @types.Encoding?,
) -> @types.Encoding {
  match pair {
    Some(b) => concat_encodings(encoding, b)
    None => encoding
  }
}

///|
/// Add ordinary tokens to the tokenizer's added vocabulary. Existing model or
/// added-vocabulary tokens are not assigned new ids; new ids are allocated after
/// the current maximum vocabulary id. Returns the updated tokenizer.
pub fn Tokenizer::add_tokens(
  self : Tokenizer,
  tokens : Array[AddedToken],
) -> Tokenizer {
  self.add_tokens_with_count(tokens).0
}

///|
/// Add ordinary tokens and return `(tokenizer, number_of_new_ids)`, matching
/// HF's `Tokenizer.add_tokens` count semantics while keeping MoonBit's builder
/// style convenient.
pub fn Tokenizer::add_tokens_with_count(
  self : Tokenizer,
  tokens : Array[AddedToken],
) -> (Tokenizer, Int) {
  self.add_tokens_impl(tokens, force_special=false)
}

///|
/// Convenience overload for adding plain string tokens.
pub fn Tokenizer::add_token_strings(
  self : Tokenizer,
  tokens : Array[String],
) -> Tokenizer {
  self.add_tokens(tokens.map(AddedToken::new))
}

///|
/// Add special tokens. They are inserted into the non-normalized trie so they
/// are recognized before normalization/pre-tokenization, like HF special added
/// tokens. Returns the updated tokenizer.
pub fn Tokenizer::add_special_tokens(
  self : Tokenizer,
  tokens : Array[AddedToken],
) -> Tokenizer {
  self.add_special_tokens_with_count(tokens).0
}

///|
/// Add special tokens and return `(tokenizer, number_of_new_ids)`.
pub fn Tokenizer::add_special_tokens_with_count(
  self : Tokenizer,
  tokens : Array[AddedToken],
) -> (Tokenizer, Int) {
  self.add_tokens_impl(tokens, force_special=true)
}

///|
/// Convenience overload for adding plain string special tokens.
pub fn Tokenizer::add_special_token_strings(
  self : Tokenizer,
  tokens : Array[String],
) -> Tokenizer {
  self.add_special_tokens(tokens.map(AddedToken::special))
}

///|
fn Tokenizer::add_tokens_impl(
  self : Tokenizer,
  tokens : Array[AddedToken],
  force_special~ : Bool,
) -> (Tokenizer, Int) {
  if tokens.length() == 0 {
    return (self, 0)
  }
  let infos = self.added_vocabulary.to_infos()
  let existing = self.get_vocab(with_added_tokens=true)
  let seen : Map[String, Bool] = {}
  for kv in self.added_vocabulary.get_vocab().to_array() {
    seen[kv.0] = true
  }
  let mut next_id = max_vocab_id(existing) + 1
  let mut new_count = 0
  for tok in tokens {
    if tok.content.is_empty() {
      continue
    }
    match seen.get(tok.content) {
      Some(true) => continue
      _ => ()
    }
    let id = match self.model.token_to_id(tok.content) {
      Some(id) => id
      None => {
        let id = next_id
        next_id = next_id + 1
        new_count = new_count + 1
        id
      }
    }
    infos.push({
      id,
      content: tok.content,
      single_word: tok.single_word,
      lstrip: tok.lstrip,
      rstrip: tok.rstrip,
      normalized: if force_special {
        false
      } else {
        tok.normalized
      },
      special: tok.special || force_special,
    })
    seen[tok.content] = true
  }
  (
    {
      ..self,
      added_vocabulary: AddedVocabulary::new_with_encode_special_tokens(
        infos,
        self.added_vocabulary.get_encode_special_tokens(),
      ).with_normalizer(self.normalizer),
      source_json: None,
    },
    new_count,
  )
}

///|
fn max_vocab_id(vocab : Map[String, Int]) -> Int {
  let mut out = -1
  for kv in vocab.to_array() {
    if kv.1 > out {
      out = kv.1
    }
  }
  out
}

///|
fn added_tokens_to_json(tokens : Array[AddedTokenInfo]) -> String {
  let sb = StringBuilder::new()
  sb.write_char('[')
  for i in 0..<tokens.length() {
    if i > 0 {
      sb.write_char(',')
    }
    let t = tokens[i]
    sb.write_string("{\"id\":")
    sb.write_string(t.id.to_string())
    sb.write_string(",\"content\":")
    write_json_string(sb, t.content)
    sb.write_string(",\"single_word\":")
    sb.write_string(if t.single_word { "true" } else { "false" })
    sb.write_string(",\"lstrip\":")
    sb.write_string(if t.lstrip { "true" } else { "false" })
    sb.write_string(",\"rstrip\":")
    sb.write_string(if t.rstrip { "true" } else { "false" })
    sb.write_string(",\"normalized\":")
    sb.write_string(if t.normalized { "true" } else { "false" })
    sb.write_string(",\"special\":")
    sb.write_string(if t.special { "true" } else { "false" })
    sb.write_char('}')
  }
  sb.write_char(']')
  sb.to_string()
}

///|
fn write_json_string(sb : StringBuilder, s : String) -> Unit {
  sb.write_char('"')
  for c in s {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.write_char('"')
}

///|
fn bool_json(v : Bool) -> String {
  if v {
    "true"
  } else {
    "false"
  }
}

///|
fn truncation_to_json(params : TruncationParams?) -> String {
  match params {
    None => "null"
    Some(tp) => {
      let sb = StringBuilder::new()
      sb.write_string("{\"max_length\":")
      sb.write_string(tp.max_length.to_string())
      sb.write_string(",\"stride\":")
      sb.write_string(tp.stride.to_string())
      sb.write_string(",\"strategy\":")
      write_json_string(sb, truncation_strategy_json(tp.strategy))
      sb.write_string(",\"direction\":")
      write_json_string(sb, truncation_direction_json(tp.direction))
      sb.write_char('}')
      sb.to_string()
    }
  }
}

///|
fn truncation_strategy_json(strategy : TruncationStrategy) -> String {
  match strategy {
    LongestFirst => "LongestFirst"
    OnlyFirst => "OnlyFirst"
    OnlySecond => "OnlySecond"
  }
}

///|
fn truncation_direction_json(direction : TruncationDirection) -> String {
  match direction {
    Left => "Left"
    Right => "Right"
  }
}

///|
fn padding_to_json(params : PaddingParams?) -> String {
  match params {
    None => "null"
    Some(pp) => {
      let sb = StringBuilder::new()
      sb.write_string("{\"strategy\":")
      match pp.strategy {
        BatchLongest => write_json_string(sb, "BatchLongest")
        Fixed(n) => {
          sb.write_string("{\"Fixed\":")
          sb.write_string(n.to_string())
          sb.write_char('}')
        }
      }
      sb.write_string(",\"direction\":")
      write_json_string(sb, padding_direction_json(pp.direction))
      sb.write_string(",\"pad_id\":")
      sb.write_string(pp.pad_id.to_string())
      sb.write_string(",\"pad_type_id\":")
      sb.write_string(pp.pad_type_id.to_string())
      sb.write_string(",\"pad_token\":")
      write_json_string(sb, pp.pad_token)
      match pp.pad_to_multiple_of {
        Some(n) => {
          sb.write_string(",\"pad_to_multiple_of\":")
          sb.write_string(n.to_string())
        }
        None => ()
      }
      sb.write_char('}')
      sb.to_string()
    }
  }
}

///|
fn padding_direction_json(direction : PaddingDirection) -> String {
  match direction {
    Left => "Left"
    Right => "Right"
  }
}

// Decode an optional component: absent key or JSON null -> None.

///|
fn[T] decode_opt(
  root : Map[String, Json],
  key : String,
  decode : (Json) -> T raise @types.TokenizerError,
) -> T? raise @types.TokenizerError {
  match root.get(key) {
    None | Some(Null) => None
    Some(j) => Some(decode(j))
  }
}

///|
fn parse_added_tokens(
  root : Map[String, Json],
) -> Array[AddedTokenInfo] raise @types.TokenizerError {
  let out : Array[AddedTokenInfo] = []
  let arr = match root.get("added_tokens") {
    Some(Array(a)) => a
    _ => return out
  }
  for entry in arr {
    let obj = @types.as_object(entry, "added_token")
    out.push({
      id: @types.get_int(obj, "id", default=-1),
      content: @types.get_str(obj, "content", default=""),
      single_word: @types.get_bool(obj, "single_word", default=false),
      lstrip: @types.get_bool(obj, "lstrip", default=false),
      rstrip: @types.get_bool(obj, "rstrip", default=false),
      // special tokens default to non-normalized; others default normalized.
      normalized: @types.get_bool(
        obj,
        "normalized",
        default=!@types.get_bool(obj, "special", default=false),
      ),
      special: @types.get_bool(obj, "special", default=false),
    })
  }
  out
}

///|
fn parse_truncation(j : Json) -> TruncationParams raise @types.TokenizerError {
  let obj = @types.as_object(j, "truncation")
  let direction = match @types.get_str(obj, "direction", default="Right") {
    "Left" | "left" => TruncationDirection::Left
    _ => TruncationDirection::Right
  }
  let strategy = match @types.get_str(obj, "strategy", default="LongestFirst") {
    "OnlyFirst" | "only_first" => TruncationStrategy::OnlyFirst
    "OnlySecond" | "only_second" => TruncationStrategy::OnlySecond
    _ => TruncationStrategy::LongestFirst
  }
  {
    max_length: @types.get_int(obj, "max_length", default=0),
    stride: @types.get_int(obj, "stride", default=0),
    direction,
    strategy,
  }
}

///|
fn parse_padding_strategy(obj : Map[String, Json]) -> PaddingStrategy {
  match obj.get("strategy") {
    Some(String("Fixed")) => Fixed(@types.get_int(obj, "length", default=0))
    Some(Object(o)) =>
      match o.get("Fixed") {
        Some(Number(n, ..)) => Fixed(n.to_int())
        _ => BatchLongest
      }
    _ => BatchLongest
  }
}

///|
fn parse_padding(j : Json) -> PaddingParams raise @types.TokenizerError {
  let obj = @types.as_object(j, "padding")
  let direction = match @types.get_str(obj, "direction", default="Right") {
    "Left" | "left" => PaddingDirection::Left
    _ => PaddingDirection::Right
  }
  {
    strategy: parse_padding_strategy(obj),
    direction,
    pad_id: @types.get_int(obj, "pad_id", default=0),
    pad_type_id: @types.get_int(obj, "pad_type_id", default=0),
    pad_token: @types.get_str(obj, "pad_token", default="[PAD]"),
    pad_to_multiple_of: @types.get_int_opt(obj, "pad_to_multiple_of"),
  }
}

///|
/// Vocabulary size of the underlying model.
pub fn Tokenizer::get_vocab_size(
  self : Tokenizer,
  with_added_tokens? : Bool = true,
) -> Int {
  self.get_vocab(with_added_tokens~).length()
}

///|
/// Python/property-style alias for `get_vocab_size`.
pub fn Tokenizer::vocab_size(
  self : Tokenizer,
  with_added_tokens? : Bool = true,
) -> Int {
  self.get_vocab_size(with_added_tokens~)
}

///|
/// Export vocabulary as `token -> id`; includes added tokens by default.
pub fn Tokenizer::get_vocab(
  self : Tokenizer,
  with_added_tokens? : Bool = true,
) -> Map[String, Int] {
  let vocab = self.model.get_vocab()
  if with_added_tokens {
    for kv in self.added_vocabulary.get_vocab().to_array() {
      vocab[kv.0] = kv.1
    }
  }
  vocab
}

///|
/// Python/property-style alias for `get_vocab`.
pub fn Tokenizer::vocab(
  self : Tokenizer,
  with_added_tokens? : Bool = true,
) -> Map[String, Int] {
  self.get_vocab(with_added_tokens~)
}

///|
/// Look up a token id by surface string (added vocabulary first, then model).
pub fn Tokenizer::token_to_id(self : Tokenizer, token : String) -> Int? {
  match self.added_vocabulary.token_to_id(token) {
    Some(id) => Some(id)
    None => self.model.token_to_id(token)
  }
}

///|
/// Look up a token surface by id (added vocabulary first, then model).
pub fn Tokenizer::id_to_token(self : Tokenizer, id : Int) -> String? {
  match self.added_vocabulary.id_to_token(id) {
    Some(t) => Some(t)
    None => self.model.id_to_token(id)
  }
}
