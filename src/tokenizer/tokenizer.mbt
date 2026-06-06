// Top-level Tokenizer assembly and public API.
//
// P1: parse the full tokenizer.json into typed components. encode/decode are
// added in later phases (P2+); for now they are declared as TODO stubs so the
// public surface is visible.

/// An added/special token entry from the top-level "added_tokens" array.
pub struct AddedToken {
  id : Int
  content : String
  special : Bool
} derive(Show, Eq)

/// A loaded tokenizer: the full decoded pipeline.
pub struct Tokenizer {
  normalizer : @normalizer.Normalizer?
  pre_tokenizer : @pretokenizer.PreTokenizer?
  model : @model.Model
  post_processor : @processor.PostProcessor?
  decoder : @decoder.Decoder?
  added_tokens : Array[AddedToken]
}

/// Load a tokenizer from the textual contents of a `tokenizer.json`.
///
/// Backend-agnostic main entry point: takes a `String`, no file IO, so it works
/// on every backend (wasm/wasm-gc/js/native).
pub fn Tokenizer::from_str(
  json : String,
) -> Tokenizer raise @types.TokenizerError {
  let parsed = try @json.parse(json) catch {
    err => raise @types.ParseError("invalid tokenizer.json: \{err}")
  }
  let root = @types.as_object(parsed, "tokenizer.json root")

  // model is mandatory.
  let model = match root.get("model") {
    Some(m) => @model.Model::from_json(m)
    None => raise @types.ParseError("tokenizer.json missing \"model\"")
  }

  // The rest are optional and may be JSON null.
  let normalizer = decode_opt(root, "normalizer", j => @normalizer.Normalizer::from_json(
    j,
  ))
  let pre_tokenizer = decode_opt(root, "pre_tokenizer", j => @pretokenizer.PreTokenizer::from_json(
    j,
  ))
  let post_processor = decode_opt(root, "post_processor", j => @processor.PostProcessor::from_json(
    j,
  ))
  let decoder = decode_opt(root, "decoder", j => @decoder.Decoder::from_json(j))
  let added_tokens = parse_added_tokens(root)
  { normalizer, pre_tokenizer, model, post_processor, decoder, added_tokens }
}

// Decode an optional component: absent key or JSON null -> None.
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

fn parse_added_tokens(
  root : Map[String, Json],
) -> Array[AddedToken] raise @types.TokenizerError {
  let out : Array[AddedToken] = []
  let arr = match root.get("added_tokens") {
    Some(Array(a)) => a
    _ => return out
  }
  for entry in arr {
    let obj = @types.as_object(entry, "added_token")
    out.push({
      id: @types.get_int(obj, "id", default=-1),
      content: @types.get_str(obj, "content", default=""),
      special: @types.get_bool(obj, "special", default=false),
    })
  }
  out
}

/// Vocabulary size of the underlying model.
pub fn Tokenizer::get_vocab_size(self : Tokenizer) -> Int {
  self.model.vocab_size()
}

/// Look up a token id by surface string.
pub fn Tokenizer::token_to_id(self : Tokenizer, token : String) -> Int? {
  self.model.token_to_id(token)
}

/// Look up a token surface by id.
pub fn Tokenizer::id_to_token(self : Tokenizer, id : Int) -> String? {
  self.model.id_to_token(id)
}
