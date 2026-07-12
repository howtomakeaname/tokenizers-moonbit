///|
pub fn apply_hub_file_download_result(
  model_id : String,
  filename : String,
  response_body : String,
  metadata : HubResponseMetadata,
  final_url : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubFileDownloadResult raise @types.TokenizerError {
  validate_hub_request(model_id, options.revision)
  validate_hub_filename(filename)
  if filename == "tokenizer.json" {
    raise @types.ParseError(
      "apply_hub_file_download_result is for tokenizer sidecar files",
    )
  }
  if metadata.status < 200 || metadata.status >= 300 {
    raise @types.ParseError(
      "Hub sidecar response cannot be cached: " +
      hub_http_status_diagnostic(metadata.status),
    )
  }
  let cache_path = @tokenizer.Tokenizer::cache_pretrained_aux_file(
    model_id,
    filename,
    response_body,
    revision=options.revision,
    resolved_revision=metadata.resolved_revision,
    cache_dir=options.cache_dir,
  )
  {
    filename,
    content: response_body,
    cache_path,
    resolved_revision: metadata.resolved_revision,
    etag: metadata.etag,
    final_url,
    status: metadata.status,
  }
}

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
  reject_local_files_only_direct_download(options.local_files_only)
  let plan = plan_tokenizer_json_request(model_id, options~)
  async_download_with_redirects(
    model_id,
    options,
    plan,
    max_redirects=options.max_redirects,
  )
}

///|
/// Download a tokenizer-adjacent Hub file such as `added_tokens.json` as raw
/// text, following redirects. This helper intentionally uses a simple 2xx-only
/// policy and does not apply tokenizer.json cache/Range/resume decisions.
pub async fn download_hub_file(
  model_id : String,
  filename : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubDownloadResult raise @types.TokenizerError {
  validate_hub_request(model_id, options.revision)
  validate_hub_filename(filename)
  if filename == "tokenizer.json" {
    return download_tokenizer_json(model_id, options~)
  }
  reject_local_files_only_direct_download(options.local_files_only)
  let plan = plan_hub_file_request(model_id, filename, options~)
  async_download_file_with_redirects(
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
  reject_local_files_only_direct_download(options.local_files_only)
  let plan = head_tokenizer_json_request(model_id, options~)
  async_head_with_redirects(plan, max_redirects=options.max_redirects)
}

///|

///|
/// Standard sidecar files that HuggingFace tokenizers automatically downloads
/// alongside `tokenizer.json`. These are optional and download failures are
/// silently ignored.
fn hub_tokenizer_sidecar_files() -> Array[String] {
  ["tokenizer_config.json", "special_tokens_map.json"]
}

///|
/// Download `tokenizer.json` and its standard sidecar files from the Hub,
/// cache them in an HF-compatible local snapshot, and return the loaded
/// Tokenizer. Sidecar file download failures are silently ignored since they
/// are optional.
///
/// This function mirrors the Python `AutoTokenizer.from_pretrained` workflow
/// where the hub client fetches the full file family automatically.
pub async fn download_tokenizer_with_sidecars(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> @tokenizer.Tokenizer raise @types.TokenizerError {
  // 1. Download tokenizer.json (required)
  let result = download_tokenizer_json(model_id, options~)
  let tokenizer_json = result.content

  // 2. Cache tokenizer.json and load the tokenizer
  let tok = @tokenizer.Tokenizer::from_pretrained_downloaded(
    model_id,
    tokenizer_json,
    revision=options.revision,
    resolved_revision=result.resolved_revision,
    cache_dir=options.cache_dir,
    etag=result.etag,
  )

  // 3. Attempt to download and cache sidecar files (optional, failures ignored)
  let sidecars = hub_tokenizer_sidecar_files()
  for filename in sidecars {
    // Skip if already in local cache
    let existing = @tokenizer.Tokenizer::from_pretrained_aux_file(
      model_id,
      filename,
      revision=options.revision,
      cache_dir=options.cache_dir,
    )
    if existing != None {
      continue
    }
    // Attempt download; silently ignore failures
    let file_result = download_hub_file(model_id, filename, options~) catch {
      _ => continue
    }
    // Cache the downloaded sidecar file (ignore failures)
    ignore(
      @tokenizer.Tokenizer::cache_pretrained_aux_file(
        model_id,
        filename,
        file_result.content,
        revision=options.revision,
        resolved_revision=result.resolved_revision,
        cache_dir=options.cache_dir,
      ) catch {
        _ => ""
      },
    )
  }

  tok
}
