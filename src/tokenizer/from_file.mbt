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
/// directly from a tokenizer JSON file path, or from an existing HuggingFace Hub
/// cache snapshot when `path` is a model id such as `bert-base-uncased` or
/// `org/model`. Network/Hub fetching is kept outside the core library so all
/// MoonBit backends stay deterministic.
pub fn from_pretrained(path : String) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_pretrained(path)
}

///|
/// Load a tokenizer from a local HF-style directory containing `tokenizer.json`,
/// directly from a tokenizer JSON file path, or an already-populated HF Hub
/// cache (`$HUGGINGFACE_HUB_CACHE`, `$HF_HOME/hub`, or
/// `$HOME/.cache/huggingface/hub`).
pub fn Tokenizer::from_pretrained(
  path : String,
) -> Tokenizer raise @types.TokenizerError {
  let resolved = resolve_pretrained_path(path, revision="main", cache_dir=None)
  Tokenizer::from_str(read_pretrained_source(resolved))
}

///|
/// Load from a specific local HF Hub cache directory and revision. This mirrors
/// the common offline `AutoTokenizer.from_pretrained(model_id, local_files_only=True)`
/// workflow without adding network IO to the core library.
pub fn Tokenizer::from_pretrained_cached(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> Tokenizer raise @types.TokenizerError {
  let resolved = resolve_pretrained_path(model_id, revision~, cache_dir~)
  Tokenizer::from_str(read_pretrained_source(resolved))
}

///|
pub fn from_pretrained_cached(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_pretrained_cached(model_id, revision~, cache_dir~)
}

///|
fn resolve_pretrained_path(
  path : String,
  revision~ : String,
  cache_dir~ : String?,
) -> String {
  if path.has_suffix(".json") {
    return path
  }
  let local_path = join_tokenizer_json(path)
  if @fs.path_exists(local_path) {
    return local_path
  }
  match resolve_hub_cache_path(path, revision~, cache_dir~) {
    Some(p) => p
    None => local_path
  }
}

///|
fn resolve_hub_cache_path(
  model_id : String,
  revision~ : String,
  cache_dir~ : String?,
) -> String? {
  let root = match cache_dir {
    Some(c) => c
    None =>
      match default_hub_cache_dir() {
        Some(c) => c
        None => return None
      }
  }
  let repo = root + "/" + hub_model_dir(model_id)
  let rev = read_revision_ref(repo, revision).unwrap_or(revision)
  let tok = repo + "/snapshots/" + rev + "/tokenizer.json"
  if @fs.path_exists(tok) {
    Some(tok)
  } else {
    None
  }
}

///|
fn default_hub_cache_dir() -> String? {
  match @sys.get_env_var("HUGGINGFACE_HUB_CACHE") {
    Some(v) => if !v.is_empty() { return Some(v) }
    None => ()
  }
  match @sys.get_env_var("HF_HOME") {
    Some(v) => if !v.is_empty() { return Some(v + "/hub") }
    None => ()
  }
  match @sys.get_env_var("HOME") {
    Some(v) =>
      if !v.is_empty() {
        Some(v + "/.cache/huggingface/hub")
      } else {
        None
      }
    None => None
  }
}

///|
fn read_revision_ref(repo : String, revision : String) -> String? {
  let path = repo + "/refs/" + revision
  let content = @fs.read_file_to_string(path) catch { _ => return None }
  Some(trim_ascii_ws(content))
}

///|
fn hub_model_dir(model_id : String) -> String {
  "models--" + replace_char(model_id, '/', "--")
}

///|
fn replace_char(s : String, needle : Char, repl : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    if c == needle {
      sb.write_string(repl)
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn trim_ascii_ws(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut stop = chars.length()
  while start < stop && is_ascii_ws(chars[start]) {
    start = start + 1
  }
  while stop > start && is_ascii_ws(chars[stop - 1]) {
    stop = stop - 1
  }
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn is_ascii_ws(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
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
