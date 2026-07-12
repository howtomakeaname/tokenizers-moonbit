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
