///|
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
  if !is_valid_hub_identifier(model_id) ||
    !is_valid_hub_identifier(revision) ||
    !valid_optional_hub_revision(resolved_revision) {
    return None
  }
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
  validate_hub_model_id(model_id)
  validate_hub_revision(revision)
  validate_hub_revision(resolved_revision)
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
        "write_pretrained_ref_revision needs cache_dir or HOME/HF_HOME/HF_HUB_CACHE/HUGGINGFACE_HUB_CACHE",
      )
  }
  ensure_parent_dir(paths.ref_path)
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
  validate_hub_model_id(model_id)
  validate_hub_revision(revision)
  match resolved_revision {
    Some(rev) => if !rev.is_empty() { validate_hub_revision(rev) }
    None => ()
  }
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
        "write_pretrained_download_resume_metadata needs cache_dir or HOME/HF_HOME/HF_HUB_CACHE/HUGGINGFACE_HUB_CACHE",
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
  if !is_valid_hub_identifier(model_id) || !is_valid_hub_identifier(revision) {
    return {
      model_id,
      revision,
      cache_dir: root,
      repo_cache_dir: None,
      ref_path: None,
      resolved_revision: None,
      snapshot_dir: None,
      tokenizer_json_path: None,
      cache_exists: false,
      message: "from_pretrained cannot inspect local HuggingFace Hub cache for '" +
      model_id +
      "' because the model id or revision contains invalid characters; expected only alphanumeric or '-', '_', '.', '/'.",
    }
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
        "' because no cache_dir/HUGGINGFACE_HUB_CACHE/HF_HUB_CACHE/HF_HOME/HOME is configured. For private or gated repositories, download with an authenticated Hub client first and pass cache_dir or tokenizer.json explicitly.",
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
