// from_file: load a tokenizer.json from disk.
//
// Backed by moonbitlang/x/fs, which provides read_file_to_string on all
// backends (js / native / wasm / wasm-gc).

// `from_pretrained` models are typically stable artifacts resolved by path. Keep
// a tiny source cache so repeated loads (common in tests, CLIs and server
// warmups) avoid paying filesystem + UTF-8 conversion repeatedly. Plain
// `from_file` intentionally stays uncached for direct file round-trips.

///|
let pretrained_source_cache : Map[String, String] = {}

///|
let pretrained_source_cache_limit : Int = 16

///|
let pretrained_source_cache_order : Array[String] = []

///|
/// Optional non-tokenizer.json files that commonly live next to HF tokenizer
/// artifacts. The core tokenizer does not interpret these files yet; exposing
/// their raw JSON lets migration layers inspect `tokenizer_config.json` and
/// `special_tokens_map.json` without reimplementing cache resolution.
pub struct PretrainedAuxFiles {
  tokenizer_config_json : String?
  special_tokens_map_json : String?
} derive(Debug, Eq)

///|
/// Local Hub-cache metadata for a resolved tokenizer artifact. This is useful for
/// HF-compatible offline layers that need to validate resolved revisions, ETags
/// or sidecar presence without duplicating the cache layout logic.
pub struct PretrainedCacheMetadata {
  tokenizer_json_path : String
  tokenizer_config_path : String?
  special_tokens_map_path : String?
  revision : String
  resolved_revision : String
  etag : String?
} derive(Debug, Eq)

///|
/// Concrete paths used by the local HuggingFace Hub cache layout for a tokenizer
/// artifact. Optional Hub/Python layers can use this to implement HEAD checks,
/// ref updates or resumable downloads without duplicating path construction.
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
} derive(Debug, Eq)

///|
/// Sidecar state for an interrupted `tokenizer.json` download. The core package
/// never performs partial network IO itself, but exposing stable resume metadata
/// lets network-capable packages coordinate Range/ETag resume policies.
pub struct PretrainedDownloadResumeMetadata {
  resume_path : String
  incomplete_path : String
  etag : String?
  expected_size : Int?
  downloaded_size : Int
} derive(Debug, Eq)

///|
/// Diagnostic information for offline `from_pretrained` resolution failures.
/// It is intentionally string/path based so optional Hub/Python layers can turn
/// it into actionable private-repo, gated-repo or missing-file exceptions.
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
} derive(Debug, Eq)

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
  pretty? : Bool = true,
) -> Unit raise @types.TokenizerError {
  let content = self.to_str(pretty~)
  @fs.write_string_to_file(path, content) catch {
    _ => raise @types.ParseError("cannot write file: \{path}")
  }
  pretrained_source_cache.clear()
  pretrained_source_cache_order.clear()
}

///|
/// Save this tokenizer into an HF-style directory as `tokenizer.json`.
///
/// This mirrors the common `save_pretrained(dir)` workflow used by HF users and
/// returns the concrete JSON path so callers can pass it to `from_file` or log
/// the produced artifact. The directory is created when possible; parent
/// directory creation remains the caller's responsibility to keep filesystem
/// behavior deterministic across MoonBit backends.
pub fn Tokenizer::save_pretrained(
  self : Tokenizer,
  dir : String,
  pretty? : Bool = false,
  save_model? : Bool = false,
  model_prefix? : String = "",
) -> String raise @types.TokenizerError {
  if !@fs.path_exists(dir) {
    @fs.create_dir(dir) catch {
      _ => ()
    }
  }
  let path = join_tokenizer_json(dir)
  self.save(path, pretty~)
  if save_model {
    ignore(self.model.save(dir, prefix=model_prefix))
  }
  path
}

///|
/// Save just the tokenizer model artifacts into `folder`, mirroring HF's
/// `tokenizer.model.save(folder, prefix=None)` convenience path while keeping the
/// model field encapsulated behind the Tokenizer façade.
pub fn Tokenizer::save_model(
  self : Tokenizer,
  folder : String,
  prefix? : String = "",
) -> Array[String] raise @types.TokenizerError {
  self.model.save(folder, prefix~)
}

///|
/// Load a tokenizer from a local HF-style directory containing `tokenizer.json`,
/// directly from a tokenizer JSON file path, or from an existing HuggingFace Hub
/// cache snapshot when `path` is a model id such as `bert-base-uncased` or
/// `org/model`. Network/Hub fetching lives in the optional `hub` package so the
/// core tokenizer package remains deterministic and available on all MoonBit
/// backends.
pub fn from_pretrained(path : String) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_pretrained(path)
}

///|
/// Load a tokenizer from a local HF-style directory containing `tokenizer.json`,
/// directly from a tokenizer JSON file path, or an already-populated HF Hub
/// cache (`$HUGGINGFACE_HUB_CACHE`, `$HF_HUB_CACHE`, `$HF_HOME/hub`, or
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
/// Read optional HF tokenizer sidecar files (`tokenizer_config.json` and
/// `special_tokens_map.json`) from the same local directory / file / Hub cache
/// resolution rules as `from_pretrained`.
pub fn Tokenizer::from_pretrained_aux_files(
  path : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> PretrainedAuxFiles {
  {
    tokenizer_config_json: Tokenizer::from_pretrained_aux_file(
      path,
      "tokenizer_config.json",
      revision~,
      cache_dir~,
    ),
    special_tokens_map_json: Tokenizer::from_pretrained_aux_file(
      path,
      "special_tokens_map.json",
      revision~,
      cache_dir~,
    ),
  }
}

///|
pub fn from_pretrained_aux_files(
  path : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> PretrainedAuxFiles {
  Tokenizer::from_pretrained_aux_files(path, revision~, cache_dir~)
}

///|
/// Resolve a tokenizer-adjacent sidecar file by basename using the same local
/// directory / file / Hub cache rules as `from_pretrained`.
pub fn Tokenizer::from_pretrained_aux_file_path(
  path : String,
  filename : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> String? {
  if !is_valid_aux_filename(filename) {
    return None
  }
  match resolve_pretrained_base_dir(path, revision~, cache_dir~) {
    Some(dir) => optional_existing_path(join_path(dir, filename))
    None => None
  }
}

///|
pub fn from_pretrained_aux_file_path(
  path : String,
  filename : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> String? {
  Tokenizer::from_pretrained_aux_file_path(
    path,
    filename,
    revision~,
    cache_dir~,
  )
}

///|
/// Read a tokenizer-adjacent sidecar file by basename, returning raw text when
/// present. The core package does not interpret the content.
pub fn Tokenizer::from_pretrained_aux_file(
  path : String,
  filename : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> String? {
  match
    Tokenizer::from_pretrained_aux_file_path(
      path,
      filename,
      revision~,
      cache_dir~,
    ) {
    Some(p) => read_optional_file(p)
    None => None
  }
}

///|
pub fn from_pretrained_aux_file(
  path : String,
  filename : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> String? {
  Tokenizer::from_pretrained_aux_file(path, filename, revision~, cache_dir~)
}

///|
/// Store a downloaded tokenizer-adjacent sidecar into an HF-style Hub cache
/// snapshot and update `refs/<revision>` when a resolved revision is available.
/// The content is not interpreted; callers can read it back with
/// `from_pretrained_aux_file`.
pub fn Tokenizer::cache_pretrained_aux_file(
  model_id : String,
  filename : String,
  content : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> String raise @types.TokenizerError {
  if !is_valid_aux_filename(filename) {
    raise @types.ParseError(
      "Hub sidecar filename must be a basename: \{filename}",
    )
  }
  validate_hub_model_id(model_id)
  validate_hub_revision(revision)
  match resolved_revision {
    Some(rev) => if !rev.is_empty() { validate_hub_revision(rev) }
    None => ()
  }
  let root = match cache_dir {
    Some(c) => c
    None =>
      match default_hub_cache_dir() {
        Some(c) => c
        None =>
          raise @types.ParseError(
            "cache_pretrained_aux_file needs cache_dir or HOME/HF_HOME/HF_HUB_CACHE/HUGGINGFACE_HUB_CACHE",
          )
      }
  }
  let repo_root = root + "/" + hub_model_dir(model_id)
  let snapshot = match resolved_revision {
    Some(r) => if r.is_empty() { revision } else { r }
    None => read_revision_ref(repo_root, revision).unwrap_or(revision)
  }
  let paths = build_pretrained_cache_paths(
    root,
    model_id,
    revision,
    resolved_revision=Some(snapshot),
  )
  ensure_dir(root)
  ensure_dir(paths.repo_cache_dir)
  ensure_dir(paths.repo_cache_dir + "/snapshots")
  ensure_dir(paths.snapshot_dir)
  ensure_dir(paths.refs_dir)
  ensure_parent_dir(paths.ref_path)
  @fs.write_string_to_file(paths.ref_path, snapshot) catch {
    _ =>
      raise @types.ParseError("cannot write Hub cache ref: \{paths.ref_path}")
  }
  let path = join_path(paths.snapshot_dir, filename)
  @fs.write_string_to_file(path, content) catch {
    _ => raise @types.ParseError("cannot write downloaded Hub sidecar: \{path}")
  }
  path
}

///|
pub fn cache_pretrained_aux_file(
  model_id : String,
  filename : String,
  content : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> String raise @types.TokenizerError {
  Tokenizer::cache_pretrained_aux_file(
    model_id,
    filename,
    content,
    revision~,
    resolved_revision~,
    cache_dir~,
  )
}

///|
/// Store downloaded `tokenizer.json` content into an HF-style Hub cache snapshot
/// and load it immediately. This is the bridge used by network-capable callers
/// such as the optional `hub` package: the core package only handles cache
/// layout, serialization and parsing, while the caller owns transport policy.
///
/// If `resolved_revision` is provided (for example from HuggingFace's
/// `x-repo-commit` response header), `refs/<revision>` points to that resolved
/// snapshot. Otherwise the requested `revision` itself is used as the snapshot

///|
/// HuggingFace Hub client: `models--org--name/snapshots/<rev>/tokenizer.json`
/// plus `refs/<revision>` when a symbolic revision is resolved.
pub fn cache_pretrained_tokenizer_json(
  model_id : String,
  tokenizer_json : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> String raise @types.TokenizerError {
  validate_hub_model_id(model_id)
  validate_hub_revision(revision)
  match resolved_revision {
    Some(rev) => if !rev.is_empty() { validate_hub_revision(rev) }
    None => ()
  }
  let root = match cache_dir {
    Some(c) => c
    None =>
      match default_hub_cache_dir() {
        Some(c) => c
        None =>
          raise @types.ParseError(
            "from_pretrained download needs cache_dir or HOME/HF_HOME/HF_HUB_CACHE/HUGGINGFACE_HUB_CACHE",
          )
      }
  }
  let snapshot = match resolved_revision {
    Some(r) => if r.is_empty() { revision } else { r }
    None => revision
  }
  let paths = build_pretrained_cache_paths(
    root,
    model_id,
    revision,
    resolved_revision=Some(snapshot),
  )
  ensure_dir(root)
  ensure_dir(paths.repo_cache_dir)
  ensure_dir(paths.repo_cache_dir + "/snapshots")
  ensure_dir(paths.snapshot_dir)
  ensure_dir(paths.refs_dir)
  ensure_parent_dir(paths.ref_path)
  @fs.write_string_to_file(paths.ref_path, snapshot) catch {
    _ => ()
  }
  @fs.write_string_to_file(paths.tokenizer_json_path, tokenizer_json) catch {
    _ =>
      raise @types.ParseError(
        "cannot write downloaded tokenizer cache: \{paths.tokenizer_json_path}",
      )
  }
  ignore(
    Tokenizer::clear_pretrained_download_resume_metadata(
      model_id,
      revision~,
      resolved_revision=Some(snapshot),
      cache_dir=Some(root),
    ),
  )
  paths.tokenizer_json_path
}

///|
fn resolve_pretrained_path(
  path : String,
  revision~ : String,
  cache_dir~ : String?,
) -> String raise @types.TokenizerError {
  if path.has_suffix(".json") {
    if @fs.path_exists(path) {
      return path
    }
    raise @types.ParseError("from_pretrained tokenizer file not found: \{path}")
  }
  let local_path = join_tokenizer_json(path)
  if @fs.path_exists(local_path) {
    return local_path
  }
  if @fs.path_exists(path) {
    raise @types.ParseError(
      "from_pretrained directory missing tokenizer.json: \{path}",
    )
  }
  match resolve_hub_cache_path(path, revision~, cache_dir~) {
    Some(p) => p
    None => {
      let hint = Tokenizer::from_pretrained_resolution_hint(
        path,
        revision~,
        cache_dir~,
      )
      raise @types.ParseError(
        "from_pretrained could not resolve '\{path}' as a tokenizer.json file, HF directory, or local HuggingFace Hub cache snapshot (revision=\{revision}). " +
        hint.message,
      )
    }
  }
}

///|
fn resolve_hub_cache_path(
  model_id : String,
  revision~ : String,
  cache_dir~ : String?,
) -> String? {
  match
    Tokenizer::from_pretrained_cache_paths(model_id, revision~, cache_dir~) {
    Some(paths) =>
      if @fs.path_exists(paths.tokenizer_json_path) {
        Some(paths.tokenizer_json_path)
      } else {
        None
      }
    None => None
  }
}

///|
fn resolve_pretrained_base_dir(
  path : String,
  revision~ : String,
  cache_dir~ : String?,
) -> String? {
  if path.has_suffix(".json") {
    if @fs.path_exists(path) {
      return parent_dir(path)
    }
    return None
  }
  let local_path = join_tokenizer_json(path)
  if @fs.path_exists(local_path) {
    return Some(path)
  }
  match resolve_hub_cache_path(path, revision~, cache_dir~) {
    Some(tok) => parent_dir(tok)
    None => resolve_hub_cache_snapshot_dir(path, revision~, cache_dir~)
  }
}

///|
fn resolve_hub_cache_snapshot_dir(
  model_id : String,
  revision~ : String,
  cache_dir~ : String?,
) -> String? {
  match
    Tokenizer::from_pretrained_cache_paths(model_id, revision~, cache_dir~) {
    Some(paths) =>
      if @fs.path_exists(paths.snapshot_dir) {
        Some(paths.snapshot_dir)
      } else {
        None
      }
    None => None
  }
}

///|
fn read_optional_file(path : String) -> String? {
  if !@fs.path_exists(path) {
    return None
  }
  Some(@fs.read_file_to_string(path)) catch {
    _ => None
  }
}

///|
fn optional_existing_path(path : String) -> String? {
  if @fs.path_exists(path) {
    Some(path)
  } else {
    None
  }
}

///|
fn write_optional_snapshot_file(
  snapshot_dir : String,
  name : String,
  content : String?,
) -> Unit raise @types.TokenizerError {
  match content {
    Some(text) => {
      let path = join_path(snapshot_dir, name)
      @fs.write_string_to_file(path, text) catch {
        _ =>
          raise @types.ParseError(
            "cannot write downloaded tokenizer sidecar: \{path}",
          )
      }
    }
    None => ()
  }
}

///|
fn default_hub_cache_dir() -> String? {
  match @sys.get_env_var("HUGGINGFACE_HUB_CACHE") {
    Some(v) => if !v.is_empty() { return Some(v) }
    None => ()
  }
  match @sys.get_env_var("HF_HUB_CACHE") {
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
pub fn is_valid_hub_identifier(value : String) -> Bool {
  if value.is_empty() || value.has_prefix("/") || value.has_suffix("/") {
    return false
  }
  let mut segment_len = 0
  let mut segment = StringBuilder::new()
  for c in value {
    if !is_hub_identifier_char(c) {
      return false
    }
    if c == '/' {
      if !valid_hub_path_segment(segment.to_string()) {
        return false
      }
      segment = StringBuilder::new()
      segment_len = 0
    } else {
      segment.write_char(c)
      segment_len = segment_len + 1
    }
  }
  segment_len > 0 && valid_hub_path_segment(segment.to_string())
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
pub fn validate_hub_revision(
  revision : String,
) -> Unit raise @types.TokenizerError {
  validate_hub_identifier(revision, "Revision")
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
  if !is_valid_hub_identifier(value) {
    raise @types.ParseError(
      "\{label} \"\{value}\" contains invalid characters, expected only alphanumeric or '-', '_', '.', '/'",
    )
  }
}

///|
fn valid_optional_hub_revision(value : String?) -> Bool {
  match value {
    Some(v) => v.is_empty() || is_valid_hub_identifier(v)
    None => true
  }
}

///|
fn is_hub_identifier_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == '.' ||
  c == '/'
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
  let sb = StringBuilder::new()
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
  Some({ resume_path, incomplete_path, etag, expected_size, downloaded_size })
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
  let sb = StringBuilder::new()
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
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
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
      let sb = StringBuilder::new()
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
