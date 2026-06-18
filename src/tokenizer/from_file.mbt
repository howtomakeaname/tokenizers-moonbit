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
  pretty? : Bool = false,
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
/// Read optional HF tokenizer sidecar files (`tokenizer_config.json` and
/// `special_tokens_map.json`) from the same local directory / file / Hub cache
/// resolution rules as `from_pretrained`.
pub fn Tokenizer::from_pretrained_aux_files(
  path : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> PretrainedAuxFiles {
  let base = resolve_pretrained_base_dir(path, revision~, cache_dir~)
  match base {
    Some(dir) =>
      {
        tokenizer_config_json: read_optional_file(
          join_path(dir, "tokenizer_config.json"),
        ),
        special_tokens_map_json: read_optional_file(
          join_path(dir, "special_tokens_map.json"),
        ),
      }
    None => { tokenizer_config_json: None, special_tokens_map_json: None }
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
/// Store downloaded `tokenizer.json` content into an HF-style Hub cache snapshot
/// and load it immediately. This is the bridge used by network-capable callers
/// such as the optional `hub` package: the core package only handles cache
/// layout, serialization and parsing, while the caller owns transport policy.
///
/// If `resolved_revision` is provided (for example from HuggingFace's
/// `x-repo-commit` response header), `refs/<revision>` points to that resolved
/// snapshot. Otherwise the requested `revision` itself is used as the snapshot
/// directory, which keeps custom endpoints and tests deterministic.
pub fn Tokenizer::from_pretrained_downloaded(
  model_id : String,
  tokenizer_json : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
  tokenizer_config_json? : String? = None,
  special_tokens_map_json? : String? = None,
  etag? : String? = None,
) -> Tokenizer raise @types.TokenizerError {
  let path = cache_pretrained_tokenizer_json(
    model_id,
    tokenizer_json,
    revision~,
    resolved_revision~,
    cache_dir~,
  )
  let snapshot_dir = parent_dir(path).unwrap_or("")
  write_optional_snapshot_file(
    snapshot_dir, "tokenizer_config.json", tokenizer_config_json,
  )
  write_optional_snapshot_file(
    snapshot_dir, "special_tokens_map.json", special_tokens_map_json,
  )
  write_optional_snapshot_file(snapshot_dir, "tokenizer.json.etag", etag)
  insert_pretrained_source_cache(path, tokenizer_json)
  Tokenizer::from_str(tokenizer_json)
}

///|
pub fn from_pretrained_downloaded(
  model_id : String,
  tokenizer_json : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
  tokenizer_config_json? : String? = None,
  special_tokens_map_json? : String? = None,
  etag? : String? = None,
) -> Tokenizer raise @types.TokenizerError {
  Tokenizer::from_pretrained_downloaded(
    model_id,
    tokenizer_json,
    revision~,
    resolved_revision~,
    cache_dir~,
    tokenizer_config_json~,
    special_tokens_map_json~,
    etag~,
  )
}

///|
/// Resolve local cache metadata for a model id/revision. Returns `None` when the
/// tokenizer is not present in local cache, matching the offline-only core API.
pub fn Tokenizer::from_pretrained_cache_metadata(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> PretrainedCacheMetadata? {
  match resolve_hub_cache_path(model_id, revision~, cache_dir~) {
    Some(tokenizer_path) => {
      let dir = parent_dir(tokenizer_path).unwrap_or("")
      let root = match cache_dir {
        Some(c) => c
        None => default_hub_cache_dir().unwrap_or("")
      }
      let repo = root + "/" + hub_model_dir(model_id)
      let resolved_revision = read_revision_ref(repo, revision).unwrap_or(
        revision,
      )
      let tokenizer_config_path = optional_existing_path(
        join_path(dir, "tokenizer_config.json"),
      )
      let special_tokens_map_path = optional_existing_path(
        join_path(dir, "special_tokens_map.json"),
      )
      Some({
        tokenizer_json_path: tokenizer_path,
        tokenizer_config_path,
        special_tokens_map_path,
        revision,
        resolved_revision,
        etag: read_optional_file(join_path(dir, "tokenizer.json.etag")),
      })
    }
    None => None
  }
}

///|
pub fn from_pretrained_cache_metadata(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> PretrainedCacheMetadata? {
  Tokenizer::from_pretrained_cache_metadata(model_id, revision~, cache_dir~)
}

///|
/// Resolve the deterministic HF cache paths for a model/revision. If
/// `resolved_revision` is `None`, refs are inspected and finally the requested
/// revision is used as the snapshot name, mirroring `from_pretrained_cached`.
pub fn Tokenizer::from_pretrained_cache_paths(
  model_id : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> PretrainedCachePaths? {
  let root = match cache_dir {
    Some(c) => c
    None =>
      match default_hub_cache_dir() {
        Some(c) => c
        None => return None
      }
  }
  Some(
    build_pretrained_cache_paths(root, model_id, revision, resolved_revision~),
  )
}

///|
pub fn from_pretrained_cache_paths(
  model_id : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> PretrainedCachePaths? {
  Tokenizer::from_pretrained_cache_paths(
    model_id,
    revision~,
    resolved_revision~,
    cache_dir~,
  )
}

///|
/// Return the resolved commit/snapshot recorded in `refs/<revision>`, if any.
pub fn Tokenizer::from_pretrained_ref_revision(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> String? {
  match
    Tokenizer::from_pretrained_cache_paths(model_id, revision~, cache_dir~) {
    Some(paths) =>
      match read_optional_file(paths.ref_path) {
        Some(content) => Some(trim_ascii_ws(content))
        None => None
      }
    None => None
  }
}

///|
pub fn from_pretrained_ref_revision(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> String? {
  Tokenizer::from_pretrained_ref_revision(model_id, revision~, cache_dir~)
}

///|
/// Update `refs/<revision>` to a resolved commit/snapshot and return the ref
/// path. This is useful after a successful HEAD request that only refreshed the
/// revision pointer.
pub fn Tokenizer::write_pretrained_ref_revision(
  model_id : String,
  resolved_revision : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> String raise @types.TokenizerError {
  let paths = match
    Tokenizer::from_pretrained_cache_paths(
      model_id,
      revision~,
      resolved_revision=Some(resolved_revision),
      cache_dir~,
    ) {
    Some(p) => p
    None =>
      raise @types.ParseError(
        "write_pretrained_ref_revision needs cache_dir or HOME/HF_HOME/HUGGINGFACE_HUB_CACHE",
      )
  }
  ensure_dir(paths.refs_dir)
  @fs.write_string_to_file(paths.ref_path, resolved_revision) catch {
    _ =>
      raise @types.ParseError("cannot write Hub cache ref: \{paths.ref_path}")
  }
  paths.ref_path
}

///|
pub fn write_pretrained_ref_revision(
  model_id : String,
  resolved_revision : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> String raise @types.TokenizerError {
  Tokenizer::write_pretrained_ref_revision(
    model_id,
    resolved_revision,
    revision~,
    cache_dir~,
  )
}

///|
/// Write resumable-download sidecar metadata and return the recorded state. The
/// optional network layer can use `incomplete_path` for partial bytes and this
/// sidecar for ETag/size validation before issuing a Range request.
pub fn Tokenizer::write_pretrained_download_resume_metadata(
  model_id : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
  etag? : String? = None,
  expected_size? : Int? = None,
  downloaded_size? : Int = 0,
) -> PretrainedDownloadResumeMetadata raise @types.TokenizerError {
  let paths = match
    Tokenizer::from_pretrained_cache_paths(
      model_id,
      revision~,
      resolved_revision~,
      cache_dir~,
    ) {
    Some(p) => p
    None =>
      raise @types.ParseError(
        "write_pretrained_download_resume_metadata needs cache_dir or HOME/HF_HOME/HUGGINGFACE_HUB_CACHE",
      )
  }
  ensure_dir(paths.snapshot_dir)
  let downloaded = if downloaded_size < 0 { 0 } else { downloaded_size }
  let content = resume_metadata_to_string(
    etag~,
    expected_size~,
    downloaded_size=downloaded,
  )
  @fs.write_string_to_file(paths.resume_path, content) catch {
    _ =>
      raise @types.ParseError(
        "cannot write Hub download resume metadata: \{paths.resume_path}",
      )
  }
  {
    resume_path: paths.resume_path,
    incomplete_path: incomplete_tokenizer_path(paths.tokenizer_json_path),
    etag,
    expected_size,
    downloaded_size: downloaded,
  }
}

///|
pub fn write_pretrained_download_resume_metadata(
  model_id : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
  etag? : String? = None,
  expected_size? : Int? = None,
  downloaded_size? : Int = 0,
) -> PretrainedDownloadResumeMetadata raise @types.TokenizerError {
  Tokenizer::write_pretrained_download_resume_metadata(
    model_id,
    revision~,
    resolved_revision~,
    cache_dir~,
    etag~,
    expected_size~,
    downloaded_size~,
  )
}

///|
/// Read resumable-download metadata for a cached tokenizer snapshot, if present.
pub fn Tokenizer::from_pretrained_download_resume_metadata(
  model_id : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> PretrainedDownloadResumeMetadata? {
  let paths = match
    Tokenizer::from_pretrained_cache_paths(
      model_id,
      revision~,
      resolved_revision~,
      cache_dir~,
    ) {
    Some(p) => p
    None => return None
  }
  match read_optional_file(paths.resume_path) {
    Some(content) =>
      parse_resume_metadata(
        content,
        paths.resume_path,
        incomplete_tokenizer_path(paths.tokenizer_json_path),
      )
    None => None
  }
}

///|
pub fn from_pretrained_download_resume_metadata(
  model_id : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> PretrainedDownloadResumeMetadata? {
  Tokenizer::from_pretrained_download_resume_metadata(
    model_id,
    revision~,
    resolved_revision~,
    cache_dir~,
  )
}

///|
/// Remove stale resumable-download sidecar metadata. Successful full downloads
/// call this automatically after writing `tokenizer.json`.
pub fn Tokenizer::clear_pretrained_download_resume_metadata(
  model_id : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> Bool {
  let paths = match
    Tokenizer::from_pretrained_cache_paths(
      model_id,
      revision~,
      resolved_revision~,
      cache_dir~,
    ) {
    Some(p) => p
    None => return false
  }
  if !@fs.path_exists(paths.resume_path) {
    return false
  }
  @fs.remove_file(paths.resume_path) catch {
    _ => return false
  }
  true
}

///|
pub fn clear_pretrained_download_resume_metadata(
  model_id : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> Bool {
  Tokenizer::clear_pretrained_download_resume_metadata(
    model_id,
    revision~,
    resolved_revision~,
    cache_dir~,
  )
}

///|
/// True when the locally-resolved cache metadata still points at an existing
/// `tokenizer.json`. This lets offline callers distinguish "metadata object was
/// produced" from "all referenced files are still available".
pub fn PretrainedCacheMetadata::cache_exists(
  self : PretrainedCacheMetadata,
) -> Bool {
  @fs.path_exists(self.tokenizer_json_path)
}

///|
/// Compare a cached tokenizer ETag against an expected value. `None` means the
/// caller has no ETag to validate, so the check is considered satisfied.
pub fn PretrainedCacheMetadata::etag_matches(
  self : PretrainedCacheMetadata,
  expected_etag : String?,
) -> Bool {
  match expected_etag {
    Some(expected) => self.etag == Some(expected)
    None => true
  }
}

///|
/// Validate local cache freshness using the pieces available offline: existing
/// tokenizer file, optional resolved revision, optional ETag, and optional
/// sidecar requirements.
pub fn PretrainedCacheMetadata::is_fresh(
  self : PretrainedCacheMetadata,
  resolved_revision? : String? = None,
  etag? : String? = None,
  require_tokenizer_config? : Bool = false,
  require_special_tokens_map? : Bool = false,
) -> Bool {
  if !self.cache_exists() {
    return false
  }
  match resolved_revision {
    Some(expected) =>
      if !expected.is_empty() && self.resolved_revision != expected {
        return false
      }
    None => ()
  }
  if !self.etag_matches(etag) {
    return false
  }
  if require_tokenizer_config && self.tokenizer_config_path is None {
    return false
  }
  if require_special_tokens_map && self.special_tokens_map_path is None {
    return false
  }
  true
}

///|
/// Offline cache existence check for a model id/revision.
pub fn Tokenizer::from_pretrained_cache_exists(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> Bool {
  match
    Tokenizer::from_pretrained_cache_metadata(model_id, revision~, cache_dir~) {
    Some(meta) => meta.cache_exists()
    None => false
  }
}

///|
pub fn from_pretrained_cache_exists(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> Bool {
  Tokenizer::from_pretrained_cache_exists(model_id, revision~, cache_dir~)
}

///|
/// Offline cache freshness check for a model id/revision.
pub fn Tokenizer::from_pretrained_cache_is_fresh(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
  resolved_revision? : String? = None,
  etag? : String? = None,
  require_tokenizer_config? : Bool = false,
  require_special_tokens_map? : Bool = false,
) -> Bool {
  match
    Tokenizer::from_pretrained_cache_metadata(model_id, revision~, cache_dir~) {
    Some(meta) =>
      meta.is_fresh(
        resolved_revision~,
        etag~,
        require_tokenizer_config~,
        require_special_tokens_map~,
      )
    None => false
  }
}

///|
pub fn from_pretrained_cache_is_fresh(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
  resolved_revision? : String? = None,
  etag? : String? = None,
  require_tokenizer_config? : Bool = false,
  require_special_tokens_map? : Bool = false,
) -> Bool {
  Tokenizer::from_pretrained_cache_is_fresh(
    model_id,
    revision~,
    cache_dir~,
    resolved_revision~,
    etag~,
    require_tokenizer_config~,
    require_special_tokens_map~,
  )
}

///|
/// Convenience ETag-only check for offline Hub cache validation.
pub fn Tokenizer::from_pretrained_cache_etag_matches(
  model_id : String,
  expected_etag : String?,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> Bool {
  match
    Tokenizer::from_pretrained_cache_metadata(model_id, revision~, cache_dir~) {
    Some(meta) => meta.cache_exists() && meta.etag_matches(expected_etag)
    None => false
  }
}

///|
pub fn from_pretrained_cache_etag_matches(
  model_id : String,
  expected_etag : String?,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> Bool {
  Tokenizer::from_pretrained_cache_etag_matches(
    model_id,
    expected_etag,
    revision~,
    cache_dir~,
  )
}

///|
/// Return an actionable offline-resolution diagnostic for `from_pretrained`.
/// This does not perform network IO; it explains which local cache locations were
/// inspected and includes guidance for private/gated repositories.
pub fn Tokenizer::from_pretrained_resolution_hint(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> PretrainedResolutionHint {
  let root = match cache_dir {
    Some(c) => Some(c)
    None => default_hub_cache_dir()
  }
  match root {
    None =>
      {
        model_id,
        revision,
        cache_dir: None,
        repo_cache_dir: None,
        ref_path: None,
        resolved_revision: None,
        snapshot_dir: None,
        tokenizer_json_path: None,
        cache_exists: false,
        message: "from_pretrained cannot inspect local HuggingFace Hub cache for '" +
        model_id +
        "' because no cache_dir/HUGGINGFACE_HUB_CACHE/HF_HOME/HOME is configured. For private or gated repositories, download with an authenticated Hub client first and pass cache_dir or tokenizer.json explicitly.",
      }
    Some(root_dir) => {
      let repo = root_dir + "/" + hub_model_dir(model_id)
      let ref_path = repo + "/refs/" + revision
      let resolved = read_revision_ref(repo, revision).unwrap_or(revision)
      let snapshot_dir = repo + "/snapshots/" + resolved
      let tok = snapshot_dir + "/tokenizer.json"
      let repo_exists = @fs.path_exists(repo)
      let snapshot_exists = @fs.path_exists(snapshot_dir)
      let tokenizer_exists = @fs.path_exists(tok)
      let message = if tokenizer_exists {
        "from_pretrained can resolve cached tokenizer for '" +
        model_id +
        "' at " +
        tok
      } else if !repo_exists {
        "from_pretrained could not find a local cache entry for '" +
        model_id +
        "' under " +
        repo +
        ". If this is a private or gated repository, download it with an authenticated Hub client/token first, or pass a local tokenizer.json path."
      } else if !snapshot_exists {
        "from_pretrained found repository cache for '" +
        model_id +
        "' but revision '" +
        revision +
        "' resolves to missing snapshot " +
        snapshot_dir +
        ". Refresh the cache for this revision or pass resolved_revision/tokenizer.json explicitly."
      } else {
        "from_pretrained found snapshot " +
        snapshot_dir +
        " for '" +
        model_id +
        "' but tokenizer.json is missing. The repository may not contain a fast tokenizer artifact, or the cache is incomplete; download tokenizer.json or use a local file path."
      }
      {
        model_id,
        revision,
        cache_dir: Some(root_dir),
        repo_cache_dir: Some(repo),
        ref_path: Some(ref_path),
        resolved_revision: Some(resolved),
        snapshot_dir: Some(snapshot_dir),
        tokenizer_json_path: Some(tok),
        cache_exists: tokenizer_exists,
        message,
      }
    }
  }
}

///|
pub fn from_pretrained_resolution_hint(
  model_id : String,
  revision? : String = "main",
  cache_dir? : String? = None,
) -> PretrainedResolutionHint {
  Tokenizer::from_pretrained_resolution_hint(model_id, revision~, cache_dir~)
}

///|
/// Write downloaded tokenizer JSON into the same local cache layout used by the
/// HuggingFace Hub client: `models--org--name/snapshots/<rev>/tokenizer.json`
/// plus `refs/<revision>` when a symbolic revision is resolved.
pub fn cache_pretrained_tokenizer_json(
  model_id : String,
  tokenizer_json : String,
  revision? : String = "main",
  resolved_revision? : String? = None,
  cache_dir? : String? = None,
) -> String raise @types.TokenizerError {
  let root = match cache_dir {
    Some(c) => c
    None =>
      match default_hub_cache_dir() {
        Some(c) => c
        None =>
          raise @types.ParseError(
            "from_pretrained download needs cache_dir or HOME/HF_HOME/HUGGINGFACE_HUB_CACHE",
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
fn resolve_pretrained_base_dir(
  path : String,
  revision~ : String,
  cache_dir~ : String?,
) -> String? {
  if path.has_suffix(".json") {
    return parent_dir(path)
  }
  let local_path = join_tokenizer_json(path)
  if @fs.path_exists(local_path) {
    return Some(path)
  }
  match resolve_hub_cache_path(path, revision~, cache_dir~) {
    Some(tok) => parent_dir(tok)
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
