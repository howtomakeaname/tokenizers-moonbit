///|
/// Whether `value` is a valid Hub repo id under huggingface_hub's
/// client-side rules (probed against the installed Python pair):
/// at most one '/'-separated namespace, each part nonempty starting
/// and ending with a word character, inner chars word/'-'/'.', the
/// name part at most 96 chars, no "--"/".." anywhere, no ".git" tail.
pub fn is_valid_hub_identifier(value : String) -> Bool {
  hub_repo_id_error(value) is None
}

///|
/// Exact huggingface_hub `HFValidationError` message for an invalid
/// repo id, in the library's checked order; None when the id is valid.
fn hub_repo_id_error(value : String) -> String? {
  if slash_count(value) > 1 {
    return Some(
      "Repo id must be in the form 'repo_name' or 'namespace/repo_name': '\{value}'. Use `repo_type` argument if needed.",
    )
  }
  if !repo_id_parts_shape_ok(value) {
    return Some(
      "Repo id must use alphanumeric chars, '-', '_' or '.'. The name cannot start or end with '-' or '.' and the maximum length is 96: '\{value}'.",
    )
  }
  if value.contains("--") || value.contains("..") {
    return Some("Cannot have -- or .. in repo_id: '\{value}'.")
  }
  if value.has_suffix(".git") {
    return Some("Repo_id cannot end by '.git': '\{value}'.")
  }
  None
}

///|
fn slash_count(value : String) -> Int {
  let mut n = 0
  for c in value {
    if c == '/' {
      n += 1
    }
  }
  n
}

///|
/// huggingface_hub's REPO_ID_REGEX: optional namespace part + a name
/// part of 1..96 chars, each part beginning and ending on a word
/// boundary (i.e. a word char) with word/'-'/'.' inside.
fn repo_id_parts_shape_ok(value : String) -> Bool {
  let chars = value.to_array()
  let n = chars.length()
  let mut start = 0
  let mut i = 0
  while i < n {
    if chars[i] == '/' {
      // namespace part: [start, i)
      if !repo_id_part_ok(chars, start, i, -1) {
        return false
      }
      start = i + 1
    }
    i += 1
  }
  // name part: [start, n), length 1..=96
  if n - start < 1 || n - start > 96 {
    return false
  }
  repo_id_part_ok(chars, start, n, -1)
}

///|
fn repo_id_part_ok(
  chars : Array[Char],
  start : Int,
  end : Int,
  _max : Int,
) -> Bool {
  if end <= start {
    return false
  }
  if !is_hub_word_char(chars[start]) || !is_hub_word_char(chars[end - 1]) {
    return false
  }
  let mut i = start + 1
  while i < end - 1 {
    if !is_hub_word_char(chars[i]) && chars[i] != '-' && chars[i] != '.' {
      return false
    }
    i += 1
  }
  true
}

///|
/// Python regex \w semantics (General Category L ∪ N plus '_', from
/// the generated empirical table in @common). Deliberately NOT the
/// onig \w table — Python rejects combining marks, connector
/// punctuation, and symbols that onig accepts, and accepts all
/// letters (incl. µ/پ/Ａ) and No numerals.
fn is_hub_word_char(c : Char) -> Bool {
  @common.is_python_word_char(c)
}

///|
pub fn Tokenizer::is_valid_hub_identifier(value : String) -> Bool {
  is_valid_hub_identifier(value)
}

///|
pub fn validate_hub_model_id(
  model_id : String,
) -> Unit raise @types.TokenizerError {
  validate_hub_identifier(model_id, "Model")
}

///|
pub fn Tokenizer::validate_hub_model_id(
  model_id : String,
) -> Unit raise @types.TokenizerError {
  validate_hub_model_id(model_id)
}

///|
/// huggingface_hub performs no client-side revision charset validation
/// (probed: 'rev!!bad' and '../main' are URL-encoded and rejected by
/// the server), so arbitrary characters pass. Structural safety is
/// still enforced because this library writes revisions into local
/// cache paths (refs/<revision>, snapshots/<revision>).
pub fn validate_hub_revision(
  revision : String,
) -> Unit raise @types.TokenizerError {
  if !is_safe_hub_revision_path(revision) {
    raise @types.ParseError(
      "Revision \"\{revision}\" is not a safe cache path (empty, '.', or '..' segments)",
    )
  }
}

///|
pub fn Tokenizer::validate_hub_revision(
  revision : String,
) -> Unit raise @types.TokenizerError {
  validate_hub_revision(revision)
}

///|
fn validate_hub_identifier(
  value : String,
  label : String,
) -> Unit raise @types.TokenizerError {
  match hub_repo_id_error(value) {
    Some(msg) => raise @types.ParseError(msg)
    None => ()
  }
  ignore(label)
}

///|
/// Structural path safety for revisions used inside the local cache
/// tree (huggingface_hub writes refs/<revision> and
/// snapshots/<revision> literally, including nested 'refs/pr/7'):
/// nonempty, no leading/trailing '/', no empty/'.'/'..' segments.
/// This is NOT repo-id validation.
fn valid_optional_hub_revision(value : String?) -> Bool {
  match value {
    Some(v) => v.is_empty() || is_safe_hub_revision_path(v)
    None => true
  }
}

///|
pub fn is_safe_hub_revision_path(value : String) -> Bool {
  if value.is_empty() || value.has_prefix("/") || value.has_suffix("/") {
    return false
  }
  let mut segment = StringBuilder()
  for c in value {
    if c == '/' {
      if !valid_hub_path_segment(segment.to_string()) {
        return false
      }
      segment = StringBuilder()
    } else {
      segment.write_char(c)
    }
  }
  valid_hub_path_segment(segment.to_string())
}

///|
fn valid_hub_path_segment(segment : String) -> Bool {
  !segment.is_empty() && segment != "." && segment != ".."
}

///|
fn hub_model_dir(model_id : String) -> String {
  "models--" + replace_char(model_id, '/', "--")
}

///|
fn build_pretrained_cache_paths(
  root : String,
  model_id : String,
  revision : String,
  resolved_revision? : String? = None,
) -> PretrainedCachePaths {
  let repo = root + "/" + hub_model_dir(model_id)
  let snapshot = match resolved_revision {
    Some(r) => if r.is_empty() { revision } else { r }
    None => read_revision_ref(repo, revision).unwrap_or(revision)
  }
  let refs_dir = repo + "/refs"
  let ref_path = refs_dir + "/" + revision
  let snapshot_dir = repo + "/snapshots/" + snapshot
  let tokenizer_json_path = snapshot_dir + "/tokenizer.json"
  {
    repo_cache_dir: repo,
    refs_dir,
    ref_path,
    snapshot_dir,
    tokenizer_json_path,
    tokenizer_config_path: snapshot_dir + "/tokenizer_config.json",
    special_tokens_map_path: snapshot_dir + "/special_tokens_map.json",
    etag_path: snapshot_dir + "/tokenizer.json.etag",
    resume_path: snapshot_dir + "/tokenizer.json.resume",
  }
}

///|
fn incomplete_tokenizer_path(tokenizer_json_path : String) -> String {
  tokenizer_json_path + ".incomplete"
}

///|
fn resume_metadata_to_string(
  etag~ : String?,
  expected_size~ : Int?,
  downloaded_size~ : Int,
) -> String {
  let sb = StringBuilder()
  match etag {
    Some(v) => sb.write_string("etag=" + escape_resume_value(v) + "\n")
    None => ()
  }
  match expected_size {
    Some(n) =>
      if n >= 0 {
        sb.write_string("expected_size=" + n.to_string() + "\n")
      }
    None => ()
  }
  sb.write_string("downloaded_size=" + downloaded_size.to_string() + "\n")
  sb.to_string()
}

///|
fn parse_resume_metadata(
  content : String,
  resume_path : String,
  incomplete_path : String,
) -> PretrainedDownloadResumeMetadata? {
  let mut etag : String? = None
  let mut expected_size : Int? = None
  let mut downloaded_size = 0
  for line in split_lines(content) {
    let trimmed = trim_ascii_ws(line)
    if trimmed.is_empty() {
      continue
    }
    match split_once(trimmed, '=') {
      Some((key, value)) => {
        let key = trim_ascii_ws(key)
        let value = trim_ascii_ws(value)
        if key == "etag" {
          etag = Some(unescape_resume_value(value))
        } else if key == "expected_size" {
          expected_size = parse_non_negative_int(value)
        } else if key == "downloaded_size" {
          downloaded_size = parse_non_negative_int(value).unwrap_or(0)
        }
      }
      None => ()
    }
  }
  Some({ resume_path, incomplete_path, etag, expected_size, downloaded_size, })
}

///|
fn split_lines(s : String) -> Array[String] {
  let out : Array[String] = []
  let chars = s.to_array()
  let mut start = 0
  for i, c in chars {
    if c == '\n' {
      out.push(string_slice(chars, start, i))
      start = i + 1
    }
  }
  if start <= chars.length() {
    out.push(string_slice(chars, start, chars.length()))
  }
  out
}

///|
fn split_once(s : String, sep : Char) -> (String, String)? {
  let chars = s.to_array()
  for i, c in chars {
    if c == sep {
      return Some(
        (string_slice(chars, 0, i), string_slice(chars, i + 1, chars.length())),
      )
    }
  }
  None
}

///|
fn parse_non_negative_int(s : String) -> Int? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut out = 0
  for c in chars {
    let u = c.to_int()
    if u < '0'.to_int() || u > '9'.to_int() {
      return None
    }
    out = out * 10 + (u - '0'.to_int())
  }
  Some(out)
}

///|
fn escape_resume_value(s : String) -> String {
  replace_char(replace_char(s, '\n', "\\n"), '\r', "\\r")
}

///|
fn unescape_resume_value(s : String) -> String {
  let sb = StringBuilder()
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      if chars[i + 1] == 'n' {
        sb.write_char('\n')
        i = i + 2
        continue
      } else if chars[i + 1] == 'r' {
        sb.write_char('\r')
        i = i + 2
        continue
      }
    }
    sb.write_char(chars[i])
    i = i + 1
  }
  sb.to_string()
}

///|
fn string_slice(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn replace_char(s : String, needle : Char, repl : String) -> String {
  let sb = StringBuilder()
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
  let sb = StringBuilder()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn ensure_dir(path : String) -> Unit raise @types.TokenizerError {
  if path.is_empty() || @fs.path_exists(path) {
    return
  }
  ensure_parent_dir(path)
  @fs.create_dir(path) catch {
    _ =>
      if !@fs.path_exists(path) {
        raise @types.ParseError("cannot create directory: \{path}")
      }
  }
}

///|
fn ensure_parent_dir(path : String) -> Unit raise @types.TokenizerError {
  match parent_dir(path) {
    Some(parent) => ensure_dir(parent)
    None => ()
  }
}

///|
fn parent_dir(path : String) -> String? {
  let chars = path.to_array()
  let mut i = chars.length() - 1
  while i >= 0 {
    if chars[i] == '/' {
      if i == 0 {
        return Some("/")
      }
      let sb = StringBuilder()
      for j in 0..<i {
        sb.write_char(chars[j])
      }
      let p = sb.to_string()
      return if p.is_empty() { None } else { Some(p) }
    }
    i = i - 1
  }
  None
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
      insert_pretrained_source_cache(path, content)
      content
    }
  }
}

///|
fn insert_pretrained_source_cache(path : String, content : String) -> Unit {
  if pretrained_source_cache.length() >= pretrained_source_cache_limit {
    evict_oldest_pretrained_source_cache_entry()
  }
  pretrained_source_cache[path] = content
  pretrained_source_cache_order.push(path)
}

///|
fn evict_oldest_pretrained_source_cache_entry() -> Unit {
  if pretrained_source_cache_order.length() == 0 {
    pretrained_source_cache.clear()
    return
  }
  let keep_keys : Array[String] = []
  let keep_values : Array[String] = []
  let evict = pretrained_source_cache_order[0]
  for i in 1..<pretrained_source_cache_order.length() {
    let key = pretrained_source_cache_order[i]
    if key != evict {
      match pretrained_source_cache.get(key) {
        Some(value) => {
          keep_keys.push(key)
          keep_values.push(value)
        }
        None => ()
      }
    }
  }
  pretrained_source_cache.clear()
  pretrained_source_cache_order.clear()
  for i in 0..<keep_keys.length() {
    pretrained_source_cache[keep_keys[i]] = keep_values[i]
    pretrained_source_cache_order.push(keep_keys[i])
  }
}

///|
fn join_tokenizer_json(path : String) -> String {
  join_path(path, "tokenizer.json")
}

///|
fn join_path(path : String, name : String) -> String {
  if path.has_suffix("/") {
    path + name
  } else {
    path + "/" + name
  }
}

///|
fn is_valid_aux_filename(name : String) -> Bool {
  if name.is_empty() || name == "." || name == ".." {
    return false
  }
  for c in name {
    let ok = (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '_' ||
      c == '-'
    if !ok {
      return false
    }
  }
  true
}
