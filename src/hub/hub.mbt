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
  endpoint? : String = "https://huggingface.co",
  revision? : String = "main",
  cache_dir? : String? = None,
  token? : String? = None,
  local_files_only? : Bool = false,
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
pub fn plan_tokenizer_json_request(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubRequestPlan {
  let url = tokenizer_json_url(options.endpoint, model_id, options.revision)
  let headers = build_headers(options)
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
          Some(resume_meta) =>
            if start > 0 &&
              resume_meta.downloaded_size == start &&
              content_range_matches_start(metadata, start) {
              return {
                action: AppendRangeToCachedTokenizer,
                resolved_revision,
                etag,
                expected_size: combine_range_size(
                  start,
                  metadata.content_length,
                ),
                range_start: Some(start),
                message: "Hub response 206: append ranged body to incomplete tokenizer.json",
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
    message: "Hub response cannot be applied to tokenizer cache: HTTP " +
    metadata.status.to_string(),
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
    message: "Hub HEAD response cannot validate tokenizer cache: HTTP " +
    metadata.status.to_string(),
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
fn content_range_matches_start(
  metadata : HubResponseMetadata,
  start : Int,
) -> Bool {
  match metadata.content_range_start {
    Some(range_start) => range_start == start
    None => true
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
      if !rev.is_empty() {
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
/// Convert a Hub response into a download result using the same 304/200/206 cache
/// policy as the async downloader. This pure-ish helper lets tests and alternate
/// transports share the cache/resume application logic without depending on the
/// async HTTP runtime.
pub fn apply_tokenizer_json_download_result(
  plan : HubRequestPlan,
  response_body : String?,
  metadata : HubResponseMetadata,
  final_url : String,
) -> HubDownloadResult raise @types.TokenizerError {
  let decision = decide_tokenizer_json_response(plan, metadata)
  match decision.action {
    UseCachedTokenizer => {
      let paths = match plan.cache_paths {
        Some(p) => p
        None =>
          raise @types.ParseError(
            "Hub response 304 cannot be applied without cache paths",
          )
      }
      let content = @fs.read_file_to_string(paths.tokenizer_json_path) catch {
        _ =>
          raise @types.ParseError(
            "cannot read cached Hub tokenizer: \{paths.tokenizer_json_path}",
          )
      }
      {
        content,
        resolved_revision: decision.resolved_revision,
        etag: decision.etag,
        final_url,
        status: metadata.status,
      }
    }
    ReplaceCachedTokenizer =>
      {
        content: require_response_body(response_body, decision),
        resolved_revision: decision.resolved_revision,
        etag: decision.etag,
        final_url,
        status: metadata.status,
      }
    AppendRangeToCachedTokenizer => {
      let resume_meta = match plan.resume_metadata {
        Some(r) => r
        None =>
          raise @types.ParseError(
            "Hub response 206 cannot be applied without resume metadata",
          )
      }
      let prefix = @fs.read_file_to_string(resume_meta.incomplete_path) catch {
        _ =>
          raise @types.ParseError(
            "cannot read incomplete Hub tokenizer cache: \{resume_meta.incomplete_path}",
          )
      }
      {
        content: prefix + require_response_body(response_body, decision),
        resolved_revision: decision.resolved_revision,
        etag: decision.etag,
        final_url,
        status: metadata.status,
      }
    }
    RetryWithoutRange | RejectResponse =>
      raise @types.ParseError(decision.message)
  }
}

///|
/// Apply a streamed tokenizer.json response represented as ordered text chunks.
///
/// Successful 200/206 bodies are persisted through the HF-style
/// `tokenizer.json.incomplete` sidecar while chunks arrive, updating resume
/// metadata after each write. On success the combined content is returned and the
/// temporary resume sidecar is cleared. This keeps the cache decision logic shared
/// with the regular downloader while giving host transports a chunk-oriented entry
/// point that does not need to buffer the full body before touching disk.
pub fn apply_tokenizer_json_download_chunks(
  model_id : String,
  chunks : Array[String],
  metadata : HubResponseMetadata,
  final_url : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubDownloadResult raise @types.TokenizerError {
  validate_hub_request(model_id, options.revision)
  let plan = plan_tokenizer_json_request(model_id, options~)
  let decision = decide_tokenizer_json_response(plan, metadata)
  match decision.action {
    UseCachedTokenizer =>
      apply_tokenizer_json_download_result(plan, None, metadata, final_url)
    ReplaceCachedTokenizer | AppendRangeToCachedTokenizer => {
      let content = write_tokenizer_json_stream_chunks(
        model_id, options, plan, decision, chunks,
      )
      {
        content,
        resolved_revision: decision.resolved_revision,
        etag: decision.etag,
        final_url,
        status: metadata.status,
      }
    }
    RetryWithoutRange | RejectResponse =>
      raise @types.ParseError(decision.message)
  }
}

///|
/// Byte-oriented counterpart of `apply_tokenizer_json_download_chunks`. This is
/// the preferred entry point for real HTTP streams because Range/resume metadata
/// is byte-based and UTF-8 code points may be split across transport chunks.
pub fn apply_tokenizer_json_download_bytes(
  model_id : String,
  chunks : Array[Bytes],
  metadata : HubResponseMetadata,
  final_url : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubDownloadResult raise @types.TokenizerError {
  validate_hub_request(model_id, options.revision)
  let plan = plan_tokenizer_json_request(model_id, options~)
  let decision = decide_tokenizer_json_response(plan, metadata)
  match decision.action {
    UseCachedTokenizer =>
      apply_tokenizer_json_download_result(plan, None, metadata, final_url)
    ReplaceCachedTokenizer | AppendRangeToCachedTokenizer => {
      let content = write_tokenizer_json_stream_bytes(
        model_id, options, plan, decision, chunks,
      )
      {
        content,
        resolved_revision: decision.resolved_revision,
        etag: decision.etag,
        final_url,
        status: metadata.status,
      }
    }
    RetryWithoutRange | RejectResponse =>
      raise @types.ParseError(decision.message)
  }
}

///|
fn write_tokenizer_json_stream_chunks(
  model_id : String,
  options : HubDownloadOptions,
  plan : HubRequestPlan,
  decision : HubResponseDecision,
  chunks : Array[String],
) -> String raise @types.TokenizerError {
  if chunks.length() == 0 {
    raise @types.ParseError(
      "Hub streamed response body is required for cache action: " +
      decision.message,
    )
  }
  match decision.action {
    ReplaceCachedTokenizer => {
      let resume_meta = create_stream_resume_metadata(
        model_id, options, decision,
      )
      write_stream_chunks_to_incomplete(
        model_id,
        options,
        resume_meta.incomplete_path,
        "",
        chunks,
        decision,
      )
    }
    AppendRangeToCachedTokenizer => {
      let resume_meta = match plan.resume_metadata {
        Some(r) => r
        None =>
          raise @types.ParseError(
            "Hub response 206 cannot stream without resume metadata",
          )
      }
      let prefix = @fs.read_file_to_string(resume_meta.incomplete_path) catch {
        _ =>
          raise @types.ParseError(
            "cannot read incomplete Hub tokenizer cache: \{resume_meta.incomplete_path}",
          )
      }
      write_stream_chunks_to_incomplete(
        model_id,
        options,
        resume_meta.incomplete_path,
        prefix,
        chunks,
        decision,
      )
    }
    _ => raise @types.ParseError(decision.message)
  }
}

///|
fn write_tokenizer_json_stream_bytes(
  model_id : String,
  options : HubDownloadOptions,
  plan : HubRequestPlan,
  decision : HubResponseDecision,
  chunks : Array[Bytes],
) -> String raise @types.TokenizerError {
  if chunks.length() == 0 {
    raise @types.ParseError(
      "Hub streamed response body is required for cache action: " +
      decision.message,
    )
  }
  match decision.action {
    ReplaceCachedTokenizer => {
      let resume_meta = create_stream_resume_metadata(
        model_id, options, decision,
      )
      write_stream_bytes_to_incomplete(
        model_id,
        options,
        resume_meta.incomplete_path,
        b"",
        chunks,
        decision,
      )
    }
    AppendRangeToCachedTokenizer => {
      let resume_meta = match plan.resume_metadata {
        Some(r) => r
        None =>
          raise @types.ParseError(
            "Hub response 206 cannot stream without resume metadata",
          )
      }
      let prefix = @fs.read_file_to_bytes(resume_meta.incomplete_path) catch {
        _ =>
          raise @types.ParseError(
            "cannot read incomplete Hub tokenizer cache: \{resume_meta.incomplete_path}",
          )
      }
      write_stream_bytes_to_incomplete(
        model_id,
        options,
        resume_meta.incomplete_path,
        prefix,
        chunks,
        decision,
      )
    }
    _ => raise @types.ParseError(decision.message)
  }
}

///|
fn create_stream_resume_metadata(
  model_id : String,
  options : HubDownloadOptions,
  decision : HubResponseDecision,
) -> @tokenizer.PretrainedDownloadResumeMetadata raise @types.TokenizerError {
  @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
    model_id,
    revision=options.revision,
    cache_dir=options.cache_dir,
    etag=decision.etag,
    expected_size=decision.expected_size,
    downloaded_size=0,
  )
}

///|
fn concat_bytes(prefix : Bytes, chunks : Array[Bytes]) -> Bytes {
  let mut total = prefix.length()
  for chunk in chunks {
    total = total + chunk.length()
  }
  Bytes::makei(total, i => {
    if i < prefix.length() {
      prefix[i]
    } else {
      let mut pos = i - prefix.length()
      let mut out = (0 : Byte)
      for chunk in chunks {
        if pos < chunk.length() {
          out = chunk[pos]
          break
        }
        pos = pos - chunk.length()
      }
      out
    }
  })
}

///|
fn write_stream_bytes_to_incomplete(
  model_id : String,
  options : HubDownloadOptions,
  incomplete_path : String,
  prefix : Bytes,
  chunks : Array[Bytes],
  decision : HubResponseDecision,
) -> String raise @types.TokenizerError {
  let written : Array[Bytes] = []
  for chunk in chunks {
    written.push(chunk)
    let content = concat_bytes(prefix, written)
    @fs.write_bytes_to_file(incomplete_path, content) catch {
      _ =>
        raise @types.ParseError(
          "cannot write incomplete Hub tokenizer cache: \{incomplete_path}",
        )
    }
    ignore(
      @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
        model_id,
        revision=options.revision,
        cache_dir=options.cache_dir,
        etag=decision.etag,
        expected_size=decision.expected_size,
        downloaded_size=content.length(),
      ) catch {
        _ =>
          raise @types.ParseError(
            "cannot update Hub download resume metadata while streaming tokenizer.json",
          )
      },
    )
  }
  ignore(
    @tokenizer.Tokenizer::clear_pretrained_download_resume_metadata(
      model_id,
      revision=options.revision,
      cache_dir=options.cache_dir,
    ),
  )
  ignore(@fs.remove_file(incomplete_path) catch { _ => () })
  @utf8.decode_lossy(concat_bytes(prefix, chunks)[:])
}

///|
fn write_stream_chunks_to_incomplete(
  model_id : String,
  options : HubDownloadOptions,
  incomplete_path : String,
  prefix : String,
  chunks : Array[String],
  decision : HubResponseDecision,
) -> String raise @types.TokenizerError {
  let mut content = prefix
  for chunk in chunks {
    content = content + chunk
    @fs.write_string_to_file(incomplete_path, content) catch {
      _ =>
        raise @types.ParseError(
          "cannot write incomplete Hub tokenizer cache: \{incomplete_path}",
        )
    }
    ignore(
      @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
        model_id,
        revision=options.revision,
        cache_dir=options.cache_dir,
        etag=decision.etag,
        expected_size=decision.expected_size,
        downloaded_size=content.length(),
      ) catch {
        _ =>
          raise @types.ParseError(
            "cannot update Hub download resume metadata while streaming tokenizer.json",
          )
      },
    )
  }
  ignore(
    @tokenizer.Tokenizer::clear_pretrained_download_resume_metadata(
      model_id,
      revision=options.revision,
      cache_dir=options.cache_dir,
    ),
  )
  ignore(@fs.remove_file(incomplete_path) catch { _ => () })
  content
}

///|
pub async fn download_tokenizer_json(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubDownloadResult raise @types.TokenizerError {
  validate_hub_request(model_id, options.revision)
  let plan = plan_tokenizer_json_request(model_id, options~)
  async_download_with_redirects(
    model_id,
    options,
    plan,
    max_redirects=options.max_redirects,
  )
}

///|
/// Perform a real HTTP HEAD preflight for `tokenizer.json`, following redirects
/// and returning cache-freshness metadata without reading a response body.
pub async fn head_tokenizer_json(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubHeadResult raise @types.TokenizerError {
  validate_hub_request(model_id, options.revision)
  let plan = head_tokenizer_json_request(model_id, options~)
  async_head_with_redirects(plan, max_redirects=options.max_redirects)
}

///|
pub fn tokenizer_json_url(
  endpoint : String,
  model_id : String,
  revision : String,
) -> String {
  trim_trailing_slash(endpoint) +
  "/" +
  model_id +
  "/resolve/" +
  revision +
  "/tokenizer.json"
}

///|
async fn async_download_with_redirects(
  model_id : String,
  options : HubDownloadOptions,
  plan : HubRequestPlan,
  max_redirects~ : Int,
) -> HubDownloadResult raise @types.TokenizerError {
  let mut current = plan.url
  let mut remaining = max_redirects
  let mut headers = plan.headers
  let mut retried_without_range = false
  while true {
    let (response, client) = @http.get_stream(current, headers~) catch {
      _ => raise @types.ParseError("Hub download failed: \{current}")
    }
    if is_redirect(response.code) {
      client.close()
      if remaining <= 0 {
        raise @types.ParseError(
          "Hub download exceeded redirect limit: \{plan.url}",
        )
      }
      match header(response.headers, "location") {
        Some(next) => {
          current = resolve_redirect(current, next)
          remaining = remaining - 1
          continue
        }
        None =>
          raise @types.ParseError(
            "Hub redirect missing Location header: \{current}",
          )
      }
    }
    let meta = HubResponseMetadata::from_headers(
      response.code,
      response.headers,
    )
    let decision = decide_tokenizer_json_response(plan, meta)
    if decision.should_retry_without_range() && !retried_without_range {
      client.close()
      headers = headers_without_range(headers)
      current = plan.url
      remaining = max_redirects
      retried_without_range = true
      continue
    }
    let content = if decision.can_use_cache() {
      client.close()
      []
    } else {
      let chunks = read_tokenizer_json_stream_bytes(
        client,
        current,
        options.stream_chunk_size,
      )
      client.close()
      chunks
    }
    if decision.can_use_cache() {
      return apply_tokenizer_json_download_chunks(
        model_id,
        [],
        meta,
        current,
        options~,
      )
    }
    return apply_tokenizer_json_download_bytes(
      model_id,
      content,
      meta,
      current,
      options~,
    )
  }
  raise @types.ParseError("unreachable Hub download loop")
}

///|
async fn read_tokenizer_json_stream_bytes(
  client : @http.Client,
  url : String,
  chunk_size : Int,
) -> Array[Bytes] raise @types.TokenizerError {
  let chunks : Array[Bytes] = []
  let max_len = positive_stream_chunk_size(chunk_size)
  while (client.read_some(max_len~) catch {
          _ =>
            raise @types.ParseError("Hub response stream read failed: \{url}")
        })
        is Some(bytes) {
    chunks.push(bytes)
  }
  if chunks.length() == 0 {
    raise @types.ParseError("Hub response body is empty: \{url}")
  }
  chunks
}

///|
async fn async_head_with_redirects(
  plan : HubRequestPlan,
  max_redirects~ : Int,
) -> HubHeadResult raise @types.TokenizerError {
  let mut current = plan.url
  let mut remaining = max_redirects
  let headers = headers_without_range(plan.headers)
  while true {
    let (client_origin, path) = split_url_for_client(current)
    let client = @http.Client(client_origin, headers~) catch {
      _ => raise @types.ParseError("Hub HEAD failed: \{current}")
    }
    let response = client..request(@http.Head, path).end_request() catch {
        _ => {
          client.close()
          raise @types.ParseError("Hub HEAD failed: \{current}")
        }
      }
    client.close()
    if is_redirect(response.code) {
      if remaining <= 0 {
        raise @types.ParseError("Hub HEAD exceeded redirect limit: \{plan.url}")
      }
      match header(response.headers, "location") {
        Some(next) => {
          current = resolve_redirect(current, next)
          remaining = remaining - 1
          continue
        }
        None =>
          raise @types.ParseError(
            "Hub HEAD redirect missing Location header: \{current}",
          )
      }
    }
    let metadata = HubResponseMetadata::from_headers(
      response.code,
      response.headers,
    )
    return {
      metadata,
      decision: decide_tokenizer_json_head_response(plan, metadata),
      final_url: current,
    }
  }
  raise @types.ParseError("unreachable Hub HEAD loop")
}

///|
fn require_response_body(
  response_body : String?,
  decision : HubResponseDecision,
) -> String raise @types.TokenizerError {
  match response_body {
    Some(body) => body
    None =>
      raise @types.ParseError(
        "Hub response body is required for cache action: " + decision.message,
      )
  }
}

///|
fn headers_without_range(headers : Map[String, String]) -> Map[String, String] {
  let out : Map[String, String] = {}
  for kv in headers.to_array() {
    let key_lower = kv.0.to_lower()
    if key_lower != "range" && key_lower != "if-range" {
      out[kv.0] = kv.1
    }
  }
  out
}

///|
fn build_headers(options : HubDownloadOptions) -> Map[String, String] {
  // Keep close to HuggingFace Hub/tokenizers client requests: a tokenizers- and
  // hf_hub-flavoured User-Agent (native only), broad Accept, and optional bearer
  // token. Do not add library-specific identifiers here; the intent is to match
  // HuggingFace client traffic as closely as possible. Avoid Host/Content-Length/
  // Connection/Accept-Encoding because the HTTP runtime owns them and JS fetch
  // forbids several of these headers.
  let out : Map[String, String] = { "Accept": "*/*" }
  if user_agent_header_allowed() {
    match options.user_agent {
      Some(ua) => if !ua.is_empty() { out["User-Agent"] = ua }
      None => ()
    }
  }
  let token = match options.token {
    Some(t) => Some(t)
    None => @sys.get_env_var("HF_TOKEN")
  }
  match token {
    Some(t) => if !t.is_empty() { out["Authorization"] = "Bearer " + t }
    None => ()
  }
  out
}

///|
fn validate_hub_request(
  model_id : String,
  revision : String,
) -> Unit raise @types.TokenizerError {
  @tokenizer.Tokenizer::validate_hub_model_id(model_id)
  @tokenizer.Tokenizer::validate_hub_revision(revision)
}

///|
#cfg(target="js")
fn user_agent_header_allowed() -> Bool {
  false
}

///|
#cfg(not(target="js"))
fn user_agent_header_allowed() -> Bool {
  true
}

///|
fn header(headers : Map[String, String], name : String) -> String? {
  match headers.get(name) {
    Some(v) => return Some(v)
    None => ()
  }
  let lower = name.to_lower()
  match headers.get(lower) {
    Some(v) => return Some(v)
    None => ()
  }
  for kv in headers {
    if kv.0.to_lower() == lower {
      return Some(kv.1)
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
fn parse_content_range(s : String) -> (Int?, Int?, Int?) {
  let prefix = "bytes "
  if !s.has_prefix(prefix) {
    return (None, None, None)
  }
  let chars = s.to_array()
  let rest = string_slice(chars, prefix.char_length(), chars.length())
  let rest_chars = rest.to_array()
  let slash = find_char(rest_chars, '/')
  if slash < 0 {
    return (None, None, None)
  }
  let range_text = string_slice(rest_chars, 0, slash)
  let total_text = string_slice(rest_chars, slash + 1, rest_chars.length())
  let range_chars = range_text.to_array()
  let dash = find_char(range_chars, '-')
  if dash < 0 {
    return (None, None, parse_content_range_total(total_text))
  }
  (
    parse_non_negative_int(string_slice(range_chars, 0, dash)),
    parse_non_negative_int(
      string_slice(range_chars, dash + 1, range_chars.length()),
    ),
    parse_content_range_total(total_text),
  )
}

///|
fn parse_content_range_total(s : String) -> Int? {
  if s == "*" {
    None
  } else {
    parse_non_negative_int(s)
  }
}

///|
fn find_char(chars : Array[Char], target : Char) -> Int {
  for i, c in chars {
    if c == target {
      return i
    }
  }
  -1
}

///|
fn is_redirect(code : Int) -> Bool {
  code == 301 || code == 302 || code == 303 || code == 307 || code == 308
}

///|
fn resolve_redirect(base : String, location : String) -> String {
  if location.has_prefix("http://") || location.has_prefix("https://") {
    location
  } else if location.has_prefix("/") {
    origin(base) + location
  } else {
    parent_url(base) + "/" + location
  }
}

///|
fn origin(url : String) -> String {
  let chars = url.to_array()
  let mut slash_count = 0
  for i, c in chars {
    if c == '/' {
      slash_count = slash_count + 1
      if slash_count == 3 {
        return string_slice(chars, 0, i)
      }
    }
  }
  url
}

///|
fn split_url_for_client(
  url : String,
) -> (String, String) raise @types.TokenizerError {
  if !(url.has_prefix("http://") || url.has_prefix("https://")) {
    raise @types.ParseError(
      "Hub URL must start with http:// or https://: \{url}",
    )
  }
  let chars = url.to_array()
  let mut slash_count = 0
  for i, c in chars {
    if c == '/' {
      slash_count = slash_count + 1
      if slash_count == 3 {
        return (
          string_slice(chars, 0, i),
          string_slice(chars, i, chars.length()),
        )
      }
    }
  }
  (url, "/")
}

///|
fn parent_url(url : String) -> String {
  let chars = url.to_array()
  let mut last = -1
  for i, c in chars {
    if c == '/' {
      last = i
    }
  }
  if last <= 0 {
    url
  } else {
    string_slice(chars, 0, last)
  }
}

///|
fn trim_trailing_slash(s : String) -> String {
  let chars = s.to_array()
  let mut stop = chars.length()
  while stop > 0 && chars[stop - 1] == '/' {
    stop = stop - 1
  }
  string_slice(chars, 0, stop)
}

///|
fn string_slice(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}
