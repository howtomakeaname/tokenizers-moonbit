// Top-level Tokenizer assembly and public API.
//
// P0 scaffold: only wires up JSON parsing so we can confirm the toolchain and
// package layout work across backends. Real component fields land in P1+.

/// A loaded tokenizer. Fields are filled in over the P1+ phases.
pub struct Tokenizer {
  // Parsed tokenizer.json kept around until component decoding lands in P1.
  config : Json
}

/// Load a tokenizer from the textual contents of a `tokenizer.json`.
///
/// This is the backend-agnostic main entry point: it takes a `String` and does
/// no file IO, so it works on every backend (wasm/wasm-gc/js/native).
pub fn Tokenizer::from_str(
  json : String,
) -> Tokenizer raise @types.TokenizerError {
  let parsed = try @json.parse(json) catch {
    err => raise @types.ParseError("invalid tokenizer.json: \{err}")
  }
  guard parsed is Object(_) else {
    raise @types.ParseError("tokenizer.json root must be a JSON object")
  }
  { config: parsed }
}

