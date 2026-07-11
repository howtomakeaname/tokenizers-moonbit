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
  component_hooks : TokenizerComponentHooks
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
pub fn TokenizerState::new(json : String) -> TokenizerState {
  { json, }
}

///|
/// Lightweight custom component hooks for migration layers that cannot yet map a
/// dynamic HF Python component to a typed MoonBit Normalizer/PreTokenizer/Decoder.
/// Hooks can be supplied per call through explicit `*_with_hooks` APIs or
/// attached to a tokenizer with `with_component_hooks` for migration layers that
/// need component-like runtime callbacks. Callback hooks are intentionally not
/// serialized into tokenizer JSON/state.
pub struct TokenizerComponentHooks {
  normalize : ((String) -> String)?
  pre_tokenize : ((String, Int) -> Array[@types.Split])?
  decode : ((Array[String]) -> String)?
}

///|
pub fn TokenizerComponentHooks::new(
  normalize? : ((String) -> String)? = None,
  pre_tokenize? : ((String, Int) -> Array[@types.Split])? = None,
  decode? : ((Array[String]) -> String)? = None,
) -> TokenizerComponentHooks {
  { normalize, pre_tokenize, decode }
}

///|
pub fn TokenizerComponentHooks::empty() -> TokenizerComponentHooks {
  TokenizerComponentHooks::new()
}

///|
pub fn TokenizerComponentHooks::with_normalize(
  self : TokenizerComponentHooks,
  normalize : ((String) -> String)?,
) -> TokenizerComponentHooks {
  { ..self, normalize, }
}

///|
pub fn TokenizerComponentHooks::with_pre_tokenize(
  self : TokenizerComponentHooks,
  pre_tokenize : ((String, Int) -> Array[@types.Split])?,
) -> TokenizerComponentHooks {
  { ..self, pre_tokenize, }
}

///|
pub fn TokenizerComponentHooks::with_decode(
  self : TokenizerComponentHooks,
  decode : ((Array[String]) -> String)?,
) -> TokenizerComponentHooks {
  { ..self, decode, }
}

///|
/// Merge two hook sets. Hooks present in `overrides` take precedence while
/// missing hooks fall back to `self`.
fn TokenizerComponentHooks::overlay(
  self : TokenizerComponentHooks,
  overrides : TokenizerComponentHooks,
) -> TokenizerComponentHooks {
  {
    normalize: match overrides.normalize {
      Some(f) => Some(f)
      None => self.normalize
    },
    pre_tokenize: match overrides.pre_tokenize {
      Some(f) => Some(f)
      None => self.pre_tokenize
    },
    decode: match overrides.decode {
      Some(f) => Some(f)
      None => self.decode
    },
  }
}

///|
/// Minimal HF-style normalized string wrapper. It keeps both the original and
/// current normalized text and exposes common mutation helpers used by custom
/// normalizer migrations. Offset tracking is conservative: transforms that
/// change length reset offsets to the normalized string's char positions.

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
    component_hooks: TokenizerComponentHooks::empty(),
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
    component_hooks: TokenizerComponentHooks::empty(),
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
/// Python binding alias for `str(tokenizer)`.
pub fn Tokenizer::__str__(
  self : Tokenizer,
) -> String raise @types.TokenizerError {
  self.to_str()
}

///|
/// Python binding alias for `repr(tokenizer)`.
pub fn Tokenizer::__repr__(
  self : Tokenizer,
) -> String raise @types.TokenizerError {
  self.to_str()
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
/// HF/Python writable-property style alias for `with_normalizer`.
pub fn Tokenizer::set_normalizer(
  self : Tokenizer,
  normalizer : @normalizer.Normalizer?,
) -> Tokenizer {
  self.with_normalizer(normalizer)
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
/// HF/Python writable-property style alias for `with_pre_tokenizer`.
pub fn Tokenizer::set_pre_tokenizer(
  self : Tokenizer,
  pre_tokenizer : @pretokenizer.PreTokenizer?,
) -> Tokenizer {
  self.with_pre_tokenizer(pre_tokenizer)
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
/// HF/Python writable-property style alias for `with_model`.
pub fn Tokenizer::set_model(
  self : Tokenizer,
  model : @model.Model,
) -> Tokenizer {
  self.with_model(model)
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
/// HF/Python writable-property style alias for `with_post_processor`.
pub fn Tokenizer::set_post_processor(
  self : Tokenizer,
  post_processor : @processor.PostProcessor?,
) -> Tokenizer {
  self.with_post_processor(post_processor)
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
/// HF/Python writable-property style alias for `with_decoder`.
pub fn Tokenizer::set_decoder(
  self : Tokenizer,
  decoder : @decoder.Decoder?,
) -> Tokenizer {
  self.with_decoder(decoder)
}

///|
/// Attach runtime component hooks to the tokenizer. These hooks are applied by
/// normal `encode`/`encode_fast`/`decode` paths as if they were lightweight
/// components, but remain intentionally outside tokenizer JSON/state because
/// callbacks are host-language values.
pub fn Tokenizer::with_component_hooks(
  self : Tokenizer,
  hooks : TokenizerComponentHooks,
) -> Tokenizer {
  { ..self, component_hooks: hooks }
}

///|
/// Remove all persisted runtime component hooks.
pub fn Tokenizer::clear_component_hooks(self : Tokenizer) -> Tokenizer {
  self.with_component_hooks(TokenizerComponentHooks::empty())
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
/// HF/Python writable-property style alias for `with_truncation`.
pub fn Tokenizer::set_truncation(
  self : Tokenizer,
  params : TruncationParams?,
) -> Tokenizer {
  self.with_truncation(params)
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
/// HF Python-style truncation wrapper using string strategy/direction values.
pub fn Tokenizer::enable_truncation_hf(
  self : Tokenizer,
  max_length : Int,
  stride? : Int = 0,
  strategy? : String = "longest_first",
  direction? : String = "right",
) -> Tokenizer raise @types.TokenizerError {
  self.enable_truncation(
    max_length,
    stride~,
    strategy=parse_truncation_strategy_hf(strategy),
    direction=parse_truncation_direction_hf(direction),
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
/// HF/Python writable-property style alias for `with_padding`.
pub fn Tokenizer::set_padding(
  self : Tokenizer,
  params : PaddingParams?,
) -> Tokenizer {
  self.with_padding(params)
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
/// HF Python-style padding wrapper using string direction values.
pub fn Tokenizer::enable_padding_hf(
  self : Tokenizer,
  length? : Int? = None,
  direction? : String = "right",
  pad_id? : Int = 0,
  pad_type_id? : Int = 0,
  pad_token? : String = "[PAD]",
  pad_to_multiple_of? : Int? = None,
) -> Tokenizer raise @types.TokenizerError {
  self.enable_padding(
    length~,
    direction=parse_padding_direction_hf(direction),
    pad_id~,
    pad_type_id~,
    pad_token~,
    pad_to_multiple_of~,
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
/// Return the runtime component hooks currently attached to this tokenizer.
pub fn Tokenizer::get_component_hooks(
  self : Tokenizer,
) -> TokenizerComponentHooks {
  self.component_hooks
}

///|
/// Python/property-style alias for `get_component_hooks`.
pub fn Tokenizer::component_hooks(self : Tokenizer) -> TokenizerComponentHooks {
  self.get_component_hooks()
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
