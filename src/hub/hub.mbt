// Optional HuggingFace Hub downloader for native/js backends.
//
// The core tokenizer package intentionally stays synchronous and all-backend.
// This package uses moonbitlang/async HTTP support, downloads tokenizer.json, and
// then delegates cache layout + parsing back to @tokenizer.

///|
pub struct HubDownloadOptions {
  /// HuggingFace-compatible base URL. Pass a mirror endpoint such as
  /// `https://hf-mirror.com` for regions where huggingface.co is slow.
  endpoint : String
  revision : String
  cache_dir : String?
  token : String?
  local_files_only : Bool
  max_redirects : Int
  /// Native-only explicit User-Agent. JavaScript/browser fetch forbids setting
  /// User-Agent manually, so the browser/runtime supplied UA is used there.
  user_agent : String?
  /// Maximum bytes requested from the HTTP stream per read. This controls how
  /// often resume metadata is refreshed while downloading large tokenizer.json
  /// files. Values <= 0 fall back to the default chunk size.
  stream_chunk_size : Int
} derive(Debug, Eq)

///|
pub fn HubDownloadOptions::new(
  endpoint? : String = default_endpoint(),
  revision? : String = "main",
  cache_dir? : String? = None,
  token? : String? = None,
  local_files_only? : Bool = default_local_files_only(),
  max_redirects? : Int = 5,
  user_agent? : String? = Some(
    "unknown/None; hf_hub/0.34.4; python/3.x; tokenizers/0.21.4",
  ),
  stream_chunk_size? : Int = 65536,
) -> HubDownloadOptions {
  {
    endpoint,
    revision,
    cache_dir,
    token,
    local_files_only,
    max_redirects,
    user_agent,
    stream_chunk_size: positive_stream_chunk_size(stream_chunk_size),
  }
}

///|
/// Return a copy using a custom HuggingFace-compatible endpoint or mirror.
/// Example: `opts.with_endpoint("https://hf-mirror.com")`.
pub fn HubDownloadOptions::with_endpoint(
  self : HubDownloadOptions,
  endpoint : String,
) -> HubDownloadOptions {
  { ..self, endpoint, }
}

///|
/// Return a copy using a custom streaming read chunk size. Non-positive values
/// are normalized to the default so callers cannot accidentally disable reads.
pub fn HubDownloadOptions::with_stream_chunk_size(
  self : HubDownloadOptions,
  stream_chunk_size : Int,
) -> HubDownloadOptions {
  { ..self, stream_chunk_size: positive_stream_chunk_size(stream_chunk_size) }
}

///|
fn positive_stream_chunk_size(n : Int) -> Int {
  if n > 0 {
    n
  } else {
    65536
  }
}

///|
fn default_endpoint() -> String {
  match @sys.get_env_var("HF_ENDPOINT") {
    Some(v) => if !v.is_empty() { v } else { "https://huggingface.co" }
    None => "https://huggingface.co"
  }
}

///|
fn default_local_files_only() -> Bool {
  match @sys.get_env_var("HF_HUB_OFFLINE") {
    Some(v) => is_truthy_env(v)
    None => false
  }
}

///|
fn is_truthy_env(value : String) -> Bool {
  let lower = value.to_lower()
  lower == "1" || lower == "true" || lower == "yes" || lower == "on"
}

///|
/// Deterministic request plan for fetching `tokenizer.json`. It combines the
/// HuggingFace-compatible URL, auth headers, local cache metadata, conditional
/// `If-None-Match`, and optional Range resume headers without performing IO.
pub struct HubRequestPlan {
  url : String
  headers : Map[String, String]
  cache_paths : @tokenizer.PretrainedCachePaths?
  cache_metadata : @tokenizer.PretrainedCacheMetadata?
  resume_metadata : @tokenizer.PretrainedDownloadResumeMetadata?
  range_start : Int?
  conditional_etag : String?
} derive(Debug, Eq)

///|
/// Response metadata extracted from HEAD/GET responses. Network callers can use
/// it to decide whether to reuse the cache, refresh refs, or continue a partial
/// download.
pub struct HubResponseMetadata {
  status : Int
  resolved_revision : String?
  etag : String?
  content_length : Int?
  content_range_start : Int?
  content_range_end : Int?
  content_range_total : Int?
  accept_ranges : Bool
} derive(Debug, Eq)

///|
pub fn HubResponseMetadata::new(
  status : Int,
  resolved_revision? : String? = None,
  etag? : String? = None,
  content_length? : Int? = None,
  content_range_start? : Int? = None,
  content_range_end? : Int? = None,
  content_range_total? : Int? = None,
  accept_ranges? : Bool = false,
) -> HubResponseMetadata {
  {
    status,
    resolved_revision,
    etag,
    content_length,
    content_range_start,
    content_range_end,
    content_range_total,
    accept_ranges,
  }
}

///|
/// Cache/write action selected after inspecting a Hub response. It is separated
/// from actual network IO so native/js/wasm host layers can share the same
/// HuggingFace-compatible 304/200/206 policy.
pub enum HubTransferAction {
  /// The server answered 304 Not Modified; load the existing tokenizer.json from
  /// cache and optionally refresh refs from response metadata.
  UseCachedTokenizer
  /// The server returned a complete body; overwrite tokenizer.json and clear any
  /// stale resume sidecar.
  ReplaceCachedTokenizer
  /// The server honored Range with 206; append the body to the recorded
  /// `.incomplete` prefix, then atomically promote through the normal cache write
  /// path.
  AppendRangeToCachedTokenizer
  /// The response cannot safely be applied to the current Range plan. Callers
  /// should retry once without Range/If-Range before surfacing a transport error.
  RetryWithoutRange
  /// Non-cacheable/non-success HTTP status.
  RejectResponse
} derive(Debug, Eq)

///|
/// Pure transfer decision derived from a request plan and response headers.
pub struct HubResponseDecision {
  action : HubTransferAction
  resolved_revision : String?
  etag : String?
  expected_size : Int?
  range_start : Int?
  message : String
} derive(Debug, Eq)

///|
/// Result of a real HTTP HEAD preflight. `decision` tells callers whether the
/// existing cache is fresh enough to reuse or whether a GET body should still be
/// downloaded and applied through `apply_tokenizer_json_download_result`.
pub struct HubHeadResult {
  metadata : HubResponseMetadata
  decision : HubResponseDecision
  final_url : String
} derive(Debug, Eq)

///|
/// Local-only diagnostic for non-success Hub HTTP statuses. This helper performs
/// no network IO and keeps GET/HEAD rejection messages consistent.
pub fn hub_http_status_diagnostic(status : Int) -> String {
  if status == 401 || status == 403 {
    "HTTP " +
    status.to_string() +
    " (private or gated repository; provide a valid Hub token)"
  } else if status == 404 {
    "HTTP 404 (missing repository, revision, or tokenizer.json file)"
  } else if status == 429 {
    "HTTP 429 (rate limit exceeded; retry later or use a Hub token)"
  } else if status >= 500 && status < 600 {
    "HTTP " + status.to_string() + " (Hub service unavailable; retry later)"
  } else {
    "HTTP " + status.to_string()
  }
}

///|
pub fn plan_tokenizer_json_request(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubRequestPlan {
  plan_hub_file_request_unchecked(model_id, "tokenizer.json", options)
}

///|
/// Deterministic request plan for a tokenizer-adjacent Hub file. This shares
/// URL revision encoding and auth headers with tokenizer.json, but intentionally
/// leaves tokenizer-cache freshness/range metadata unset for non-tokenizer
/// files.
pub fn plan_hub_file_request(
  model_id : String,
  filename : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubRequestPlan raise @types.TokenizerError {
  validate_hub_filename(filename)
  plan_hub_file_request_unchecked(model_id, filename, options)
}

///|
fn plan_hub_file_request_unchecked(
  model_id : String,
  filename : String,
  options : HubDownloadOptions,
) -> HubRequestPlan {
  let url = hub_file_url_unchecked(
    options.endpoint,
    model_id,
    options.revision,
    filename,
  )
  let headers = build_headers(options)
  if filename != "tokenizer.json" {
    return {
      url,
      headers,
      cache_paths: None,
      cache_metadata: None,
      resume_metadata: None,
      range_start: None,
      conditional_etag: None,
    }
  }
  let paths = @tokenizer.Tokenizer::from_pretrained_cache_paths(
    model_id,
    revision=options.revision,
    cache_dir=options.cache_dir,
  )
  let resume_meta = @tokenizer.Tokenizer::from_pretrained_download_resume_metadata(
    model_id,
    revision=options.revision,
    cache_dir=options.cache_dir,
  )
  let cached = @tokenizer.Tokenizer::from_pretrained_cache_metadata(
    model_id,
    revision=options.revision,
    cache_dir=options.cache_dir,
  )
  let mut conditional_etag : String? = None
  match cached {
    Some(meta) =>
      match meta.etag {
        Some(etag) =>
          if !etag.is_empty() {
            headers["If-None-Match"] = etag
            conditional_etag = Some(etag)
          }
        None => ()
      }
    None => ()
  }
  let mut range_start : Int? = None
  match resume_meta {
    Some(meta) =>
      if meta.downloaded_size > 0 {
        headers["Range"] = "bytes=" + meta.downloaded_size.to_string() + "-"
        match meta.etag {
          Some(etag) => if !etag.is_empty() { headers["If-Range"] = etag }
          None => ()
        }
        range_start = Some(meta.downloaded_size)
      }
    None => ()
  }
  {
    url,
    headers,
    cache_paths: paths,
    cache_metadata: cached,
    resume_metadata: resume_meta,
    range_start,
    conditional_etag,
  }
}

///|
/// Build a HEAD preflight request plan. It shares the same URL/auth/conditional
/// ETag setup as GET, but deliberately strips Range/If-Range because HEAD is
/// used to validate cache freshness rather than continue a partial body.
pub fn head_tokenizer_json_request(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubRequestPlan {
  let plan = plan_tokenizer_json_request(model_id, options~)
  {
    ..plan,
    headers: headers_without_range(plan.headers),
    resume_metadata: None,
    range_start: None,
  }
}

///|
pub fn HubResponseMetadata::from_headers(
  status : Int,
  headers : Map[String, String],
) -> HubResponseMetadata {
  let content_length = match header(headers, "content-length") {
    Some(v) => parse_non_negative_int(v)
    None => None
  }
  let accept_ranges = match header(headers, "accept-ranges") {
    Some(v) => v.to_lower() == "bytes"
    None => false
  }
  let (content_range_start, content_range_end, content_range_total) = match
    header(headers, "content-range") {
    Some(v) => parse_content_range(v)
    None => (None, None, None)
  }
  {
    status,
    resolved_revision: header(headers, "x-repo-commit"),
    etag: header(headers, "etag"),
    content_length,
    content_range_start,
    content_range_end,
    content_range_total,
    accept_ranges,
  }
}

///|
/// Decide how a tokenizer.json Hub response should affect the local cache.
///
/// This covers the transfer states used by HuggingFace Hub clients while keeping
/// the core cache mutation explicit: 304 reuses cache, 200 replaces cache, 206 is
/// accepted only when it matches a previously recorded resume range, and unsafe
/// Range outcomes ask the caller to retry without Range.
pub fn decide_tokenizer_json_response(
  plan : HubRequestPlan,
  metadata : HubResponseMetadata,
) -> HubResponseDecision {
  let resolved_revision = metadata.resolved_revision
  let etag = metadata.etag
  if metadata.status == 304 {
    return {
      action: UseCachedTokenizer,
      resolved_revision,
      etag,
      expected_size: None,
      range_start: None,
      message: "Hub response 304: cached tokenizer.json is still fresh",
    }
  }
  if metadata.status == 200 {
    return {
      action: ReplaceCachedTokenizer,
      resolved_revision,
      etag,
      expected_size: metadata.content_length,
      range_start: None,
      message: "Hub response 200: replace cached tokenizer.json",
    }
  }
  if metadata.status == 206 {
    match plan.range_start {
      Some(start) =>
        match plan.resume_metadata {
          Some(resume_meta) => {
            let (range_matches, expected_size) = validate_range_response(
              metadata, start,
            )
            if start > 0 &&
              resume_meta.downloaded_size == start &&
              range_matches {
              return {
                action: AppendRangeToCachedTokenizer,
                resolved_revision,
                etag,
                expected_size,
                range_start: Some(start),
                message: "Hub response 206: append ranged body to incomplete tokenizer.json",
              }
            }
          }
          None => ()
        }
      None => ()
    }
    return {
      action: RetryWithoutRange,
      resolved_revision,
      etag,
      expected_size: metadata.content_length,
      range_start: None,
      message: "Hub response 206 did not match local resume metadata; retry without Range",
    }
  }
  if metadata.status == 416 {
    return {
      action: RetryWithoutRange,
      resolved_revision,
      etag,
      expected_size: metadata.content_length,
      range_start: None,
      message: "Hub response 416: recorded Range is not satisfiable; retry without Range",
    }
  }
  {
    action: RejectResponse,
    resolved_revision,
    etag,
    expected_size: metadata.content_length,
    range_start: None,
    message: "Hub response cannot be applied to tokenizer cache: " +
    hub_http_status_diagnostic(metadata.status),
  }
}

///|
/// Decide how a HEAD preflight affects tokenizer cache freshness.
///
/// `304` reuses cache directly. A `200` HEAD also reuses cache when the server's
/// resolved revision or ETag still matches the local metadata; otherwise callers
/// should follow up with a GET to fetch the new body. Unsupported HEAD statuses
/// are intentionally not fatal for higher-level callers: they may simply proceed
/// to the normal GET path.
pub fn decide_tokenizer_json_head_response(
  plan : HubRequestPlan,
  metadata : HubResponseMetadata,
) -> HubResponseDecision {
  let resolved_revision = metadata.resolved_revision
  let etag = metadata.etag
  if metadata.status == 304 {
    return {
      action: UseCachedTokenizer,
      resolved_revision,
      etag,
      expected_size: metadata.content_length,
      range_start: None,
      message: "Hub HEAD 304: cached tokenizer.json is still fresh",
    }
  }
  if metadata.status == 200 {
    match plan.cache_metadata {
      Some(cache_meta) =>
        if cache_meta.cache_exists() &&
          cache_matches_head_metadata(cache_meta, metadata) {
          return {
            action: UseCachedTokenizer,
            resolved_revision,
            etag,
            expected_size: metadata.content_length,
            range_start: None,
            message: "Hub HEAD 200: cached tokenizer.json matches remote metadata",
          }
        }
      None => ()
    }
    return {
      action: ReplaceCachedTokenizer,
      resolved_revision,
      etag,
      expected_size: metadata.content_length,
      range_start: None,
      message: "Hub HEAD 200: tokenizer.json should be downloaded",
    }
  }
  {
    action: RejectResponse,
    resolved_revision,
    etag,
    expected_size: metadata.content_length,
    range_start: None,
    message: "Hub HEAD response cannot validate tokenizer cache: " +
    hub_http_status_diagnostic(metadata.status),
  }
}

///|
pub fn HubResponseDecision::can_use_cache(self : HubResponseDecision) -> Bool {
  self.action == UseCachedTokenizer
}

///|
pub fn HubResponseDecision::should_write_full_body(
  self : HubResponseDecision,
) -> Bool {
  self.action == ReplaceCachedTokenizer
}

///|
pub fn HubResponseDecision::should_append_range(
  self : HubResponseDecision,
) -> Bool {
  self.action == AppendRangeToCachedTokenizer
}

///|
pub fn HubResponseDecision::should_retry_without_range(
  self : HubResponseDecision,
) -> Bool {
  self.action == RetryWithoutRange
}

///|
fn cache_matches_head_metadata(
  cache_meta : @tokenizer.PretrainedCacheMetadata,
  metadata : HubResponseMetadata,
) -> Bool {
  match metadata.resolved_revision {
    Some(rev) =>
      if !rev.is_empty() && cache_meta.resolved_revision == rev {
        return true
      }
    None => ()
  }
  match metadata.etag {
    Some(etag) =>
      if !etag.is_empty() && cache_meta.etag == Some(etag) {
        return true
      }
    None => ()
  }
  false
}

///|
/// Apply a GET response body to the tokenizer cache according to
/// `decide_tokenizer_json_response`, then return a parsed tokenizer. This helper
/// is intentionally body-as-string based: host/network layers still own HTTP and
/// byte streaming, while this package owns cache/ref/resume policy.
pub fn apply_tokenizer_json_response(
  model_id : String,
  response_body : String,
  metadata : HubResponseMetadata,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
  tokenizer_config_json? : String? = None,
  special_tokens_map_json? : String? = None,
) -> @tokenizer.Tokenizer raise @types.TokenizerError {
  validate_hub_request(model_id, options.revision)
  let plan = plan_tokenizer_json_request(model_id, options~)
  let decision = decide_tokenizer_json_response(plan, metadata)
  match decision.action {
    UseCachedTokenizer => {
      refresh_ref_from_decision(model_id, options, decision)
      @tokenizer.Tokenizer::from_pretrained_cached(
        model_id,
        revision=options.revision,
        cache_dir=options.cache_dir,
      )
    }
    ReplaceCachedTokenizer =>
      @tokenizer.Tokenizer::from_pretrained_downloaded(
        model_id,
        response_body,
        revision=options.revision,
        resolved_revision=decision.resolved_revision,
        cache_dir=options.cache_dir,
        tokenizer_config_json~,
        special_tokens_map_json~,
        etag=decision.etag,
      )
    AppendRangeToCachedTokenizer => {
      let resume_meta = match plan.resume_metadata {
        Some(r) => r
        None =>
          raise @types.ParseError(
            "Hub response decision requested range append without resume metadata",
          )
      }
      let prefix = @fs.read_file_to_string(resume_meta.incomplete_path) catch {
        _ =>
          raise @types.ParseError(
            "cannot read incomplete Hub tokenizer cache: \{resume_meta.incomplete_path}",
          )
      }
      @tokenizer.Tokenizer::from_pretrained_downloaded(
        model_id,
        prefix + response_body,
        revision=options.revision,
        resolved_revision=decision.resolved_revision,
        cache_dir=options.cache_dir,
        tokenizer_config_json~,
        special_tokens_map_json~,
        etag=decision.etag,
      )
    }
    RetryWithoutRange | RejectResponse =>
      raise @types.ParseError(decision.message)
  }
}

///|
fn combine_range_size(start : Int, body_length : Int?) -> Int? {
  match body_length {
    Some(n) => if n >= 0 { Some(start + n) } else { None }
    None => None
  }
}

///|
fn validate_range_response(
  metadata : HubResponseMetadata,
  start : Int,
) -> (Bool, Int?) {
  match
    (
      metadata.content_range_start,
      metadata.content_range_end,
      metadata.content_range_total,
    ) {
    (Some(range_start), Some(range_end), Some(total)) => {
      if range_start != start || range_end < range_start || range_end >= total {
        return (false, None)
      }
      match metadata.content_length {
        Some(body_length) =>
          if body_length != range_end - range_start + 1 {
            return (false, None)
          }
        None => ()
      }
      (true, Some(total))
    }
    (Some(range_start), _, _) =>
      if range_start == start {
        (true, combine_range_size(start, metadata.content_length))
      } else {
        (false, None)
      }
    (None, _, _) => (true, combine_range_size(start, metadata.content_length))
  }
}

///|
fn refresh_ref_from_decision(
  model_id : String,
  options : HubDownloadOptions,
  decision : HubResponseDecision,
) -> Unit {
  match decision.resolved_revision {
    Some(rev) =>
      if !rev.is_empty() && cached_snapshot_exists(model_id, options, rev) {
        ignore(
          @tokenizer.Tokenizer::write_pretrained_ref_revision(
            model_id,
            rev,
            revision=options.revision,
            cache_dir=options.cache_dir,
          ) catch {
            _ => ""
          },
        )
      }
    None => ()
  }
}

///|
fn cached_snapshot_exists(
  model_id : String,
  options : HubDownloadOptions,
  resolved_revision : String,
) -> Bool {
  match
    @tokenizer.Tokenizer::from_pretrained_cache_paths(
      model_id,
      revision=options.revision,
      resolved_revision=Some(resolved_revision),
      cache_dir=options.cache_dir,
    ) {
    Some(paths) => @fs.path_exists(paths.tokenizer_json_path)
    None => false
  }
}

///|
fn is_existing_local_pretrained_path(path : String) -> Bool {
  @fs.path_exists(path)
}

///|
/// Load a tokenizer from a local path/cache first, otherwise download
/// `tokenizer.json` from HuggingFace Hub (or a compatible endpoint), persist it
/// into the HF-style cache layout, and parse it with the core tokenizer loader.
///
/// Supported on native/js backends via `moonbitlang/async/http`. Wasm users can
/// keep using `@tokenizer.from_pretrained` against a pre-populated cache, or let
/// their host application fetch JSON and pass it to
/// `@tokenizer.from_pretrained_downloaded`.
pub async fn from_pretrained(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> @tokenizer.Tokenizer raise @types.TokenizerError {
  if is_existing_local_pretrained_path(model_id) {
    return @tokenizer.Tokenizer::from_pretrained_cached(
      model_id,
      revision=options.revision,
      cache_dir=options.cache_dir,
    )
  }
  try
    @tokenizer.Tokenizer::from_pretrained_cached(
      model_id,
      revision=options.revision,
      cache_dir=options.cache_dir,
    )
  catch {
    _ => ()
  } noraise {
    tok => {
      if options.local_files_only {
        return tok
      }
      try head_tokenizer_json(model_id, options~) catch {
        _ => return tok
      } noraise {
        result =>
          if result.decision.can_use_cache() {
            refresh_ref_from_decision(model_id, options, result.decision)
            return tok
          }
      }
    }
  }
  if options.local_files_only {
    raise @types.ParseError(
      "from_pretrained local cache miss and local_files_only=true: \{model_id}",
    )
  }
  validate_hub_request(model_id, options.revision)
  let result = download_tokenizer_json(model_id, options~)
  @tokenizer.Tokenizer::from_pretrained_downloaded(
    model_id,
    result.content,
    revision=options.revision,
    resolved_revision=result.resolved_revision,
    cache_dir=options.cache_dir,
    etag=result.etag,
  )
}

///|
pub struct HubDownloadResult {
  content : String
  resolved_revision : String?
  etag : String?
  final_url : String
  status : Int
} derive(Debug, Eq)

///|
/// Result of applying a tokenizer-adjacent Hub file body to the local snapshot
/// cache. Unlike tokenizer.json downloads, sidecar files are cached as raw text
/// without Range/ETag freshness decisions or content parsing.
pub struct HubFileDownloadResult {
  filename : String
  content : String
  cache_path : String
  resolved_revision : String?
  etag : String?
  final_url : String
  status : Int
} derive(Debug, Eq)

///|
/// Apply a complete tokenizer-adjacent Hub file body to the HF-style local cache.
/// This is the sidecar counterpart to `apply_tokenizer_json_download_result` but
/// intentionally omits tokenizer-specific 304/206 cache decisions.
