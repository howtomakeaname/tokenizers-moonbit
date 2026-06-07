// from_file: load a tokenizer.json from disk.
//
// Backed by moonbitlang/x/fs, which provides read_file_to_string on all
// backends (js / native / wasm / wasm-gc).

///|
/// Load a tokenizer from a `tokenizer.json` file path.
pub fn from_file(path : String) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_file(path)
}

///|
/// Load a tokenizer from a `tokenizer.json` file path.
pub fn Tokenizer::from_file(
  path : String,
) -> Tokenizer raise @types.TokenizerError {
  let content = @fs.read_file_to_string(path) catch {
    _ => raise @types.ParseError("cannot read file: \{path}")
  }
  Tokenizer::from_str(content)
}

///|
/// Save this tokenizer to a `tokenizer.json` file path.
pub fn Tokenizer::save(
  self : Tokenizer,
  path : String,
) -> Unit raise @types.TokenizerError {
  let content = self.to_json()
  @fs.write_string_to_file(path, content) catch {
    _ => raise @types.ParseError("cannot write file: \{path}")
  }
}

///|
/// Load a tokenizer from a local HF-style directory containing `tokenizer.json`,
/// or directly from a tokenizer JSON file path. Network/Hub fetching is kept
/// outside the core library so all MoonBit backends stay deterministic.
pub fn from_pretrained(path : String) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_pretrained(path)
}

///|
/// Load a tokenizer from a local HF-style directory containing `tokenizer.json`,
/// or directly from a tokenizer JSON file path.
pub fn Tokenizer::from_pretrained(
  path : String,
) -> Tokenizer raise @types.TokenizerError {
  if path.has_suffix(".json") {
    Tokenizer::from_file(path)
  } else {
    Tokenizer::from_file(join_tokenizer_json(path))
  }
}

///|
fn join_tokenizer_json(path : String) -> String {
  if path.has_suffix("/") {
    path + "tokenizer.json"
  } else {
    path + "/tokenizer.json"
  }
}
