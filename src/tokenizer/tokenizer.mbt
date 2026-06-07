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
  source_json : String?
}

///|
/// Load a tokenizer from the textual contents of a `tokenizer.json`.
///
/// Backend-agnostic main entry point: takes a `String`, no file IO, so it works
/// on every backend (wasm/wasm-gc/js/native).
pub fn Tokenizer::from_str(
  json : String,
) -> Tokenizer raise @types.TokenizerError {
  let parsed = @json.parse(json) catch {
    err => raise @types.ParseError("invalid tokenizer.json: \{err}")
  }
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
  let added_vocabulary = AddedVocabulary::new(parse_added_tokens(root))
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
          "{\"version\":\"1.0\",\"pre_tokenizer\":" +
          pt_json +
          ",\"model\":" +
          model_json +
          "}"
        }
        None => raise @types.ParseError("tokenizer has no serialized source")
      }
  }
}

///|
/// Enable/disable truncation (builder; mutates and returns self).
pub fn Tokenizer::with_truncation(
  self : Tokenizer,
  params : TruncationParams?,
) -> Tokenizer {
  self.truncation = params
  self
}

///|
/// Enable/disable padding (builder; mutates and returns self).
pub fn Tokenizer::with_padding(
  self : Tokenizer,
  params : PaddingParams?,
) -> Tokenizer {
  self.padding = params
  self
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
