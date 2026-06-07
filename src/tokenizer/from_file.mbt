// from_file: load a tokenizer.json from disk.
//
// Backed by moonbitlang/x/fs, which provides read_file_to_string on all
// backends (js / native / wasm / wasm-gc).

// `from_pretrained` models are typically stable artifacts resolved by path. Keep
// a tiny one-entry source cache so repeated loads (common in tests, CLIs and
// server warmups) avoid paying filesystem + UTF-8 conversion repeatedly. Plain
// `from_file` intentionally stays uncached for direct file round-trips.

///|
let pretrained_source_cache : Map[String, String] = {}

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
  pretrained_source_cache.clear()
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
  let resolved = if path.has_suffix(".json") {
    path
  } else {
    join_tokenizer_json(path)
  }
  Tokenizer::from_str(read_pretrained_source(resolved))
}

///|
fn read_pretrained_source(path : String) -> String raise @types.TokenizerError {
  match pretrained_source_cache.get(path) {
    Some(content) => content
    None => {
      let content = @fs.read_file_to_string(path) catch {
        _ => raise @types.ParseError("cannot read file: \{path}")
      }
      pretrained_source_cache.clear()
      pretrained_source_cache[path] = content
      content
    }
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
