///|
test "tokenizer_json_url trims endpoint slash" {
  @test.assert_eq(
    tokenizer_json_url("https://huggingface.co/", "bert-base-uncased", "main"),
    "https://huggingface.co/bert-base-uncased/resolve/main/tokenizer.json",
  )
  @test.assert_eq(
    tokenizer_json_url("https://hf-mirror.example", "org/model", "abc123"),
    "https://hf-mirror.example/org/model/resolve/abc123/tokenizer.json",
  )
  @test.assert_eq(
    tokenizer_json_url("https://hf.example", "org/model", "refs/pr/7"),
    "https://hf.example/org/model/resolve/refs%2Fpr%2F7/tokenizer.json",
  )
  @test.assert_eq(
    tokenizer_json_url("https://hf.example", "org/model", "feature/foo"),
    "https://hf.example/org/model/resolve/feature%2Ffoo/tokenizer.json",
  )
  @test.assert_eq(
    hub_file_url(
      "https://hf.example/", "org/model", "refs/pr/7", "tokenizer_config.json",
    ),
    "https://hf.example/org/model/resolve/refs%2Fpr%2F7/tokenizer_config.json",
  )
  let mut bad_filename = false
  try
    hub_file_url("https://hf.example", "org/model", "main", "../config.json")
    |> ignore
  catch {
    @types.ParseError(msg) =>
      bad_filename = msg.contains("Hub filename must be a basename")
    _ => ()
  }
  @test.assert_eq(bad_filename, true)
}

///|
test "download options default to online main revision" {
  let opts = HubDownloadOptions::new()
  @test.assert_eq(opts.endpoint, "https://huggingface.co")
  @test.assert_eq(opts.revision, "main")
  @test.assert_eq(opts.local_files_only, false)
  @test.assert_eq(opts.stream_chunk_size, 65536)
  @test.assert_eq(opts.with_stream_chunk_size(17).stream_chunk_size, 17)
  @test.assert_eq(opts.with_stream_chunk_size(0).stream_chunk_size, 65536)
}

///|
test "download options honor Hub environment defaults" {
  @sys.set_env_var("HF_ENDPOINT", "https://env-hf.example")
  @sys.set_env_var("HF_HUB_OFFLINE", "1")
  let env_opts = HubDownloadOptions::new()
  @test.assert_eq(env_opts.endpoint, "https://env-hf.example")
  @test.assert_eq(env_opts.local_files_only, true)

  let explicit = HubDownloadOptions::new(
    endpoint="https://explicit-hf.example",
    local_files_only=false,
  )
  @test.assert_eq(explicit.endpoint, "https://explicit-hf.example")
  @test.assert_eq(explicit.local_files_only, false)

  @sys.set_env_var("HF_ENDPOINT", "")
  @sys.set_env_var("HF_HUB_OFFLINE", "false")
  let reset = HubDownloadOptions::new()
  @test.assert_eq(reset.endpoint, "https://huggingface.co")
  @test.assert_eq(reset.local_files_only, false)
}

///|
test "Hub cache application validates model id and revision" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let mut bad_model = false
  try
    apply_tokenizer_json_response(
      "org/model name",
      json,
      HubResponseMetadata::new(200),
      options=HubDownloadOptions::new(cache_dir=Some("_build/hub_validation")),
    )
    |> ignore
  catch {
    @types.ParseError(msg) => bad_model = msg.contains("Model")
    _ => ()
  }
  @test.assert_eq(bad_model, true)

  let mut bad_revision = false
  try
    apply_tokenizer_json_response(
      "org/model",
      json,
      HubResponseMetadata::new(200),
      options=HubDownloadOptions::new(
        revision="../escape",
        cache_dir=Some("_build/hub_validation"),
      ),
    )
    |> ignore
  catch {
    @types.ParseError(msg) => bad_revision = msg.contains("Revision")
    _ => ()
  }
  @test.assert_eq(bad_revision, true)
}

///|
test "Hub request plan uses cache etag and resume range" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let cache = "_build/hub_request_plan_cache"
  @tokenizer.Tokenizer::from_pretrained_downloaded(
    "org/request-plan-tokenizer",
    json,
    revision="main",
    resolved_revision=Some("abc123"),
    cache_dir=Some(cache),
    etag=Some("etag-existing"),
  )
  |> ignore
  @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
    "org/request-plan-tokenizer",
    revision="main",
    cache_dir=Some(cache),
    etag=Some("etag-partial"),
    expected_size=Some(1000),
    downloaded_size=256,
  )
  |> ignore
  let plan = plan_tokenizer_json_request(
    "org/request-plan-tokenizer",
    options=HubDownloadOptions::new(
      endpoint="https://hf.example/",
      revision="main",
      cache_dir=Some(cache),
      token=Some("tok"),
    ),
  )
  @test.assert_eq(
    plan.url,
    "https://hf.example/org/request-plan-tokenizer/resolve/main/tokenizer.json",
  )
  @test.assert_eq(plan.headers.get("If-None-Match"), Some("etag-existing"))
  @test.assert_eq(plan.headers.get("Range"), Some("bytes=256-"))
  @test.assert_eq(plan.headers.get("If-Range"), Some("etag-partial"))
  @test.assert_eq(plan.headers.get("Authorization"), Some("Bearer tok"))
  @test.assert_eq(plan.headers.get("Accept"), Some("*/*"))
  @test.assert_eq(plan.range_start, Some(256))
  @test.assert_eq(plan.conditional_etag, Some("etag-existing"))
  @test.assert_eq(
    plan.cache_paths.unwrap().snapshot_dir.has_suffix("/snapshots/abc123"),
    true,
  )
  @test.assert_eq(plan.resume_metadata.unwrap().downloaded_size, 256)
  let sidecar_plan = plan_hub_file_request(
    "org/request-plan-tokenizer",
    "added_tokens.json",
    options=HubDownloadOptions::new(
      endpoint="https://hf.example/",
      revision="refs/pr/7",
      cache_dir=Some(cache),
      token=Some("tok"),
    ),
  )
  @test.assert_eq(
    sidecar_plan.url,
    "https://hf.example/org/request-plan-tokenizer/resolve/refs%2Fpr%2F7/added_tokens.json",
  )
  @test.assert_eq(sidecar_plan.headers.get("Authorization"), Some("Bearer tok"))
  @test.assert_eq(sidecar_plan.headers.get("Accept"), Some("*/*"))
  @test.assert_eq(sidecar_plan.cache_paths, None)
  @test.assert_eq(sidecar_plan.resume_metadata, None)
  @test.assert_eq(sidecar_plan.range_start, None)
}

///|
test "Hub sidecar download result writes raw file into cache" {
  let cache = "_build/hub_sidecar_apply_cache"
  let model = "org/sidecar-apply-tokenizer"
  let result = apply_hub_file_download_result(
    model,
    "added_tokens.json",
    "{\"added\":[]}",
    HubResponseMetadata::new(
      200,
      resolved_revision=Some("sidecarrev"),
      etag=Some("etag-added"),
    ),
    "https://hf.example/org/sidecar-apply-tokenizer/resolve/main/added_tokens.json",
    options=HubDownloadOptions::new(cache_dir=Some(cache)),
  )
  @test.assert_eq(result.filename, "added_tokens.json")
  @test.assert_eq(result.content, "{\"added\":[]}")
  @test.assert_eq(result.status, 200)
  @test.assert_eq(result.resolved_revision, Some("sidecarrev"))
  @test.assert_eq(result.etag, Some("etag-added"))
  @test.assert_eq(
    result.cache_path.has_suffix(
      "/models--org--sidecar-apply-tokenizer/snapshots/sidecarrev/added_tokens.json",
    ),
    true,
  )
  @test.assert_eq(
    @tokenizer.Tokenizer::from_pretrained_ref_revision(
      model,
      revision="main",
      cache_dir=Some(cache),
    ),
    Some("sidecarrev"),
  )
  @test.assert_eq(
    @tokenizer.Tokenizer::from_pretrained_aux_file(
      model,
      "added_tokens.json",
      revision="main",
      cache_dir=Some(cache),
    ),
    Some("{\"added\":[]}"),
  )

  let mut rejected_tokenizer_json = false
  try
    apply_hub_file_download_result(
      model,
      "tokenizer.json",
      "{}",
      HubResponseMetadata::new(200),
      "https://hf.example/tokenizer.json",
      options=HubDownloadOptions::new(cache_dir=Some(cache)),
    )
    |> ignore
  catch {
    @types.ParseError(msg) =>
      rejected_tokenizer_json = msg.contains("sidecar files")
    _ => ()
  }
  @test.assert_eq(rejected_tokenizer_json, true)

  let mut rejected_status = false
  try
    apply_hub_file_download_result(
      model,
      "special_tokens_map.json",
      "{}",
      HubResponseMetadata::new(404),
      "https://hf.example/missing",
      options=HubDownloadOptions::new(cache_dir=Some(cache)),
    )
    |> ignore
  catch {
    @types.ParseError(msg) => rejected_status = msg.contains("HTTP 404")
    _ => ()
  }
  @test.assert_eq(rejected_status, true)
}

///|
test "Hub request headers avoid empty auth and optional user agent" {
  let no_auth = plan_tokenizer_json_request(
    "bert-base-uncased",
    options=HubDownloadOptions::new(token=Some(""), user_agent=None),
  )
  @test.assert_eq(no_auth.headers.get("Accept"), Some("*/*"))
  @test.assert_eq(no_auth.headers.get("Authorization"), None)
  @test.assert_eq(no_auth.headers.get("User-Agent"), None)

  let with_user_agent = plan_tokenizer_json_request(
    "bert-base-uncased",
    options=HubDownloadOptions::new(
      token=Some("tok"),
      user_agent=Some("custom-agent"),
    ),
  )
  @test.assert_eq(
    with_user_agent.headers.get("Authorization"),
    Some("Bearer tok"),
  )
  @test.assert_eq(
    with_user_agent.headers.get("User-Agent"),
    expected_user_agent_header(Some("custom-agent")),
  )

  @fs.write_string_to_file("_build/hub_token_path", " file-token \n") catch {
    _ => ()
  }
  @sys.set_env_var("HF_TOKEN", "")
  @sys.set_env_var("HF_TOKEN_PATH", "_build/hub_token_path")
  let from_token_path = plan_tokenizer_json_request(
    "bert-base-uncased",
    options=HubDownloadOptions::new(user_agent=None),
  )
  @test.assert_eq(
    from_token_path.headers.get("Authorization"),
    Some("Bearer file-token"),
  )

  @sys.set_env_var("HF_TOKEN", "env-token")
  let from_env_token = plan_tokenizer_json_request(
    "bert-base-uncased",
    options=HubDownloadOptions::new(user_agent=None),
  )
  @test.assert_eq(
    from_env_token.headers.get("Authorization"),
    Some("Bearer env-token"),
  )

  @fs.create_dir("_build/hub_hf_home_token") catch {
    _ => ()
  }
  @fs.write_string_to_file("_build/hub_hf_home_token/token", " home-token\n") catch {
    _ => ()
  }
  @sys.set_env_var("HF_TOKEN", "")
  @sys.set_env_var("HF_TOKEN_PATH", "")
  @sys.set_env_var("HF_HOME", "_build/hub_hf_home_token")
  let from_hf_home = plan_tokenizer_json_request(
    "bert-base-uncased",
    options=HubDownloadOptions::new(user_agent=None),
  )
  @test.assert_eq(
    from_hf_home.headers.get("Authorization"),
    Some("Bearer home-token"),
  )
  @sys.set_env_var("HF_TOKEN", "")
  @sys.set_env_var("HF_TOKEN_PATH", "")
  @sys.set_env_var("HF_HOME", "")
}

///|
#cfg(target="js")
fn expected_user_agent_header(_expected : String?) -> String? {
  None
}

///|
#cfg(not(target="js"))
fn expected_user_agent_header(expected : String?) -> String? {
  expected
}

///|
test "Hub response metadata parses cache headers" {
  let meta = HubResponseMetadata::from_headers(200, {
    "x-repo-commit": "abc123",
    "etag": "etag-new",
    "content-length": "4096",
    "accept-ranges": "bytes",
  })
  @test.assert_eq(meta.status, 200)
  @test.assert_eq(meta.resolved_revision, Some("abc123"))
  @test.assert_eq(meta.etag, Some("etag-new"))
  @test.assert_eq(meta.content_length, Some(4096))
  @test.assert_eq(meta.accept_ranges, true)
}

///|
test "Hub response metadata parses headers case-insensitively" {
  let meta = HubResponseMetadata::from_headers(206, {
    "X-Repo-Commit": "abc123",
    "ETag": "etag-new",
    "Content-Length": "224",
    "Accept-Ranges": "bytes",
    "Content-Range": "bytes 32-255/256",
  })
  @test.assert_eq(meta.resolved_revision, Some("abc123"))
  @test.assert_eq(meta.etag, Some("etag-new"))
  @test.assert_eq(meta.content_length, Some(224))
  @test.assert_eq(meta.accept_ranges, true)
  @test.assert_eq(meta.content_range_start, Some(32))
  @test.assert_eq(meta.content_range_end, Some(255))
  @test.assert_eq(meta.content_range_total, Some(256))
}

///|
test "Hub HTTP status diagnostics describe common failures" {
  @test.assert_eq(
    hub_http_status_diagnostic(401),
    "HTTP 401 (private or gated repository; provide a valid Hub token)",
  )
  @test.assert_eq(
    hub_http_status_diagnostic(403),
    "HTTP 403 (private or gated repository; provide a valid Hub token)",
  )
  @test.assert_eq(
    hub_http_status_diagnostic(404),
    "HTTP 404 (missing repository, revision, or tokenizer.json file)",
  )
  @test.assert_eq(
    hub_http_status_diagnostic(429),
    "HTTP 429 (rate limit exceeded; retry later or use a Hub token)",
  )
  @test.assert_eq(
    hub_http_status_diagnostic(503),
    "HTTP 503 (Hub service unavailable; retry later)",
  )
  @test.assert_eq(hub_http_status_diagnostic(418), "HTTP 418")
}

///|
test "Hub response decision handles cache and range statuses" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let cache = "_build/hub_response_decision_cache"
  @tokenizer.Tokenizer::from_pretrained_downloaded(
    "org/response-decision-tokenizer",
    json,
    revision="main",
    resolved_revision=Some("abc123"),
    cache_dir=Some(cache),
    etag=Some("etag-existing"),
  )
  |> ignore
  @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
    "org/response-decision-tokenizer",
    revision="main",
    cache_dir=Some(cache),
    etag=Some("etag-existing"),
    expected_size=Some(256),
    downloaded_size=32,
  )
  |> ignore
  let plan = plan_tokenizer_json_request(
    "org/response-decision-tokenizer",
    options=HubDownloadOptions::new(cache_dir=Some(cache)),
  )
  let not_modified = decide_tokenizer_json_response(
    plan,
    HubResponseMetadata::new(
      304,
      resolved_revision=Some("abc123"),
      etag=Some("etag-existing"),
      accept_ranges=true,
    ),
  )
  @test.assert_eq(not_modified.can_use_cache(), true)
  let partial = decide_tokenizer_json_response(
    plan,
    HubResponseMetadata::new(
      206,
      resolved_revision=Some("def456"),
      etag=Some("etag-new"),
      content_length=Some(224),
      content_range_start=Some(32),
      content_range_end=Some(255),
      content_range_total=Some(256),
      accept_ranges=true,
    ),
  )
  @test.assert_eq(partial.should_append_range(), true)
  @test.assert_eq(partial.range_start, Some(32))
  @test.assert_eq(partial.expected_size, Some(256))
  let partial_with_larger_total = decide_tokenizer_json_response(
    plan,
    HubResponseMetadata::new(
      206,
      resolved_revision=Some("def456"),
      etag=Some("etag-new"),
      content_length=Some(96),
      content_range_start=Some(32),
      content_range_end=Some(127),
      content_range_total=Some(512),
      accept_ranges=true,
    ),
  )
  @test.assert_eq(partial_with_larger_total.should_append_range(), true)
  @test.assert_eq(partial_with_larger_total.expected_size, Some(512))
  let bad_partial = decide_tokenizer_json_response(
    plan_tokenizer_json_request(
      "org/no-resume-tokenizer",
      options=HubDownloadOptions::new(cache_dir=Some(cache)),
    ),
    HubResponseMetadata::new(
      206,
      resolved_revision=Some("def456"),
      etag=Some("etag-new"),
      content_length=Some(224),
      content_range_start=Some(32),
      content_range_end=Some(255),
      content_range_total=Some(256),
      accept_ranges=true,
    ),
  )
  @test.assert_eq(bad_partial.should_retry_without_range(), true)
  let mismatched_total = decide_tokenizer_json_response(
    plan,
    HubResponseMetadata::new(
      206,
      resolved_revision=Some("def456"),
      etag=Some("etag-new"),
      content_length=Some(225),
      content_range_start=Some(32),
      content_range_end=Some(256),
      content_range_total=Some(256),
      accept_ranges=true,
    ),
  )
  @test.assert_eq(mismatched_total.should_retry_without_range(), true)
  let mismatched_body_length = decide_tokenizer_json_response(
    plan,
    HubResponseMetadata::new(
      206,
      resolved_revision=Some("def456"),
      etag=Some("etag-new"),
      content_length=Some(223),
      content_range_start=Some(32),
      content_range_end=Some(255),
      content_range_total=Some(256),
      accept_ranges=true,
    ),
  )
  @test.assert_eq(mismatched_body_length.should_retry_without_range(), true)
  let mismatched_range = decide_tokenizer_json_response(
    plan,
    HubResponseMetadata::new(
      206,
      resolved_revision=Some("def456"),
      etag=Some("etag-new"),
      content_length=Some(224),
      content_range_start=Some(16),
      content_range_end=Some(239),
      content_range_total=Some(256),
      accept_ranges=true,
    ),
  )
  @test.assert_eq(mismatched_range.should_retry_without_range(), true)
  let unauthorized = decide_tokenizer_json_response(
    plan,
    HubResponseMetadata::new(401),
  )
  @test.assert_eq(unauthorized.can_use_cache(), false)
  @test.assert_eq(
    unauthorized.message,
    "Hub response cannot be applied to tokenizer cache: HTTP 401 (private or gated repository; provide a valid Hub token)",
  )
  let missing = decide_tokenizer_json_response(
    plan,
    HubResponseMetadata::new(404),
  )
  @test.assert_eq(
    missing.message,
    "Hub response cannot be applied to tokenizer cache: HTTP 404 (missing repository, revision, or tokenizer.json file)",
  )
}

///|
test "Hub HEAD plan and decision validate cached metadata" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"head":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let cache = "_build/hub_head_decision_cache"
  @tokenizer.Tokenizer::from_pretrained_downloaded(
    "org/head-decision-tokenizer",
    json,
    revision="main",
    resolved_revision=Some("headrev"),
    cache_dir=Some(cache),
    etag=Some("etag-head"),
  )
  |> ignore
  @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
    "org/head-decision-tokenizer",
    revision="main",
    cache_dir=Some(cache),
    etag=Some("etag-partial"),
    expected_size=Some(1024),
    downloaded_size=64,
  )
  |> ignore
  let head_plan = head_tokenizer_json_request(
    "org/head-decision-tokenizer",
    options=HubDownloadOptions::new(cache_dir=Some(cache)),
  )
  @test.assert_eq(head_plan.headers.get("If-None-Match"), Some("etag-head"))
  @test.assert_eq(head_plan.headers.get("Range"), None)
  @test.assert_eq(head_plan.headers.get("If-Range"), None)
  @test.assert_eq(head_plan.range_start, None)
  @test.assert_eq(head_plan.resume_metadata, None)
  let slash_revision_head_plan = head_tokenizer_json_request(
    "org/head-decision-tokenizer",
    options=HubDownloadOptions::new(
      endpoint="https://hf.example",
      revision="refs/pr/7",
      cache_dir=Some(cache),
    ),
  )
  @test.assert_eq(
    slash_revision_head_plan.url,
    "https://hf.example/org/head-decision-tokenizer/resolve/refs%2Fpr%2F7/tokenizer.json",
  )
  @test.assert_eq(slash_revision_head_plan.headers.get("Range"), None)
  @test.assert_eq(slash_revision_head_plan.headers.get("If-Range"), None)
  let not_modified = decide_tokenizer_json_head_response(
    head_plan,
    HubResponseMetadata::new(
      304,
      resolved_revision=Some("headrev"),
      etag=Some("etag-head"),
    ),
  )
  @test.assert_eq(not_modified.can_use_cache(), true)
  let reused_with_new_revision = apply_tokenizer_json_response(
    "org/head-decision-tokenizer",
    "",
    HubResponseMetadata::new(
      304,
      resolved_revision=Some("newrev"),
      etag=Some("etag-head"),
    ),
    options=HubDownloadOptions::new(cache_dir=Some(cache)),
  )
  @test.assert_eq(
    reused_with_new_revision.encode("head", add_special_tokens=false).ids,
    [0],
  )
  @test.assert_eq(
    @tokenizer.Tokenizer::from_pretrained_ref_revision(
      "org/head-decision-tokenizer",
      revision="main",
      cache_dir=Some(cache),
    ),
    Some("headrev"),
  )
  let same_etag = decide_tokenizer_json_head_response(
    head_plan,
    HubResponseMetadata::new(
      200,
      resolved_revision=Some("headrev"),
      etag=Some("etag-head"),
      content_length=Some(json.length()),
      accept_ranges=true,
    ),
  )
  @test.assert_eq(same_etag.can_use_cache(), true)
  let changed = decide_tokenizer_json_head_response(
    head_plan,
    HubResponseMetadata::new(
      200,
      resolved_revision=Some("newrev"),
      etag=Some("etag-new"),
      content_length=Some(json.length() + 1),
      accept_ranges=true,
    ),
  )
  @test.assert_eq(changed.should_write_full_body(), true)
  let unsupported = decide_tokenizer_json_head_response(
    head_plan,
    HubResponseMetadata::new(405),
  )
  @test.assert_eq(unsupported.can_use_cache(), false)
  @test.assert_eq(unsupported.should_write_full_body(), false)
  @test.assert_eq(
    unsupported.message,
    "Hub HEAD response cannot validate tokenizer cache: HTTP 405",
  )
  let unavailable = decide_tokenizer_json_head_response(
    head_plan,
    HubResponseMetadata::new(503),
  )
  @test.assert_eq(
    unavailable.message,
    "Hub HEAD response cannot validate tokenizer cache: HTTP 503 (Hub service unavailable; retry later)",
  )
}

///|
test "apply Hub response reuses cache replaces cache and appends ranges" {
  let old_json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"old":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let new_json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"new":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let cache = "_build/hub_apply_response_cache"
  let opts = HubDownloadOptions::new(cache_dir=Some(cache))
  @tokenizer.Tokenizer::from_pretrained_downloaded(
    "org/apply-response-tokenizer",
    old_json,
    revision="main",
    resolved_revision=Some("oldrev"),
    cache_dir=Some(cache),
    etag=Some("etag-old"),
  )
  |> ignore
  let cached = apply_tokenizer_json_response(
    "org/apply-response-tokenizer",
    "",
    HubResponseMetadata::new(
      304,
      resolved_revision=Some("oldrev"),
      etag=Some("etag-old"),
      accept_ranges=true,
    ),
    options=opts,
  )
  @test.assert_eq(cached.token_to_id("old"), Some(0))
  let replaced = apply_tokenizer_json_response(
    "org/apply-response-tokenizer",
    new_json,
    HubResponseMetadata::new(
      200,
      resolved_revision=Some("newrev"),
      etag=Some("etag-new"),
      content_length=Some(new_json.length()),
      accept_ranges=true,
    ),
    options=opts,
  )
  @test.assert_eq(replaced.token_to_id("new"), Some(0))
  let range_model = "org/apply-range-tokenizer"
  let split = 35
  let prefix = string_prefix(new_json, split)
  let suffix = string_suffix(new_json, split)
  let resume_meta = @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
    range_model,
    revision="main",
    cache_dir=Some(cache),
    etag=Some("etag-range"),
    expected_size=Some(new_json.length()),
    downloaded_size=prefix.length(),
  )
  @fs.write_string_to_file(resume_meta.incomplete_path, prefix) catch {
    _ => abort("cannot write incomplete tokenizer cache")
  }
  let ranged = apply_tokenizer_json_response(
    range_model,
    suffix,
    HubResponseMetadata::new(
      206,
      resolved_revision=Some("rangerev"),
      etag=Some("etag-range"),
      content_length=Some(suffix.length()),
      accept_ranges=true,
    ),
    options=opts,
  )
  @test.assert_eq(ranged.token_to_id("new"), Some(0))
  @test.assert_eq(
    @tokenizer.Tokenizer::from_pretrained_download_resume_metadata(
      range_model,
      revision="main",
      cache_dir=Some(cache),
    ),
    None,
  )
}

///|
test "Hub download result helper reuses cache and combines ranges" {
  let cached_json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"cached":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let range_json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"range":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let cache = "_build/hub_download_result_cache"
  let model = "org/download-result-tokenizer"
  @tokenizer.Tokenizer::from_pretrained_downloaded(
    model,
    cached_json,
    revision="main",
    resolved_revision=Some("cachedrev"),
    cache_dir=Some(cache),
    etag=Some("etag-cached"),
  )
  |> ignore
  let plan = plan_tokenizer_json_request(
    model,
    options=HubDownloadOptions::new(cache_dir=Some(cache)),
  )
  let not_modified = apply_tokenizer_json_download_result(
    plan,
    None,
    HubResponseMetadata::new(
      304,
      resolved_revision=Some("cachedrev"),
      etag=Some("etag-cached"),
    ),
    "https://hf.example/cached",
  )
  @test.assert_eq(not_modified.status, 304)
  @test.assert_eq(not_modified.content, cached_json)
  let full = apply_tokenizer_json_download_result(
    plan,
    Some(range_json),
    HubResponseMetadata::new(
      200,
      resolved_revision=Some("fullrev"),
      etag=Some("etag-full"),
      content_length=Some(range_json.length()),
    ),
    "https://hf.example/full",
  )
  @test.assert_eq(full.status, 200)
  @test.assert_eq(full.content, range_json)
  let split = 40
  let prefix = string_prefix(range_json, split)
  let suffix = string_suffix(range_json, split)
  let resume_meta = @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
    model,
    revision="main",
    cache_dir=Some(cache),
    etag=Some("etag-range"),
    expected_size=Some(range_json.length()),
    downloaded_size=prefix.length(),
  )
  @fs.write_string_to_file(resume_meta.incomplete_path, prefix) catch {
    _ => abort("cannot write incomplete tokenizer cache")
  }
  let range_plan = plan_tokenizer_json_request(
    model,
    options=HubDownloadOptions::new(cache_dir=Some(cache)),
  )
  let partial = apply_tokenizer_json_download_result(
    range_plan,
    Some(suffix),
    HubResponseMetadata::new(
      206,
      resolved_revision=Some("rangerev"),
      etag=Some("etag-range"),
      content_length=Some(suffix.length()),
    ),
    "https://hf.example/range",
  )
  @test.assert_eq(partial.status, 206)
  @test.assert_eq(partial.content, range_json)
}

///|
test "Hub streamed chunk helper writes incomplete cache and clears resume" {
  let full_json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"full":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let range_json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"range":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let cache = "_build/hub_stream_chunks_cache"
  let full_model = "org/stream-full-tokenizer"
  let opts = HubDownloadOptions::new(cache_dir=Some(cache))
  let full_result = apply_tokenizer_json_download_chunks(
    full_model,
    [string_prefix(full_json, 35), string_suffix(full_json, 35)],
    HubResponseMetadata::new(
      200,
      resolved_revision=Some("fullrev"),
      etag=Some("etag-full"),
      content_length=Some(full_json.length()),
      accept_ranges=true,
    ),
    "https://hf.example/full-stream",
    options=opts,
  )
  @test.assert_eq(full_result.content, full_json)
  @test.assert_eq(full_result.status, 200)
  @test.assert_eq(
    @tokenizer.Tokenizer::from_pretrained_download_resume_metadata(
      full_model,
      revision="main",
      cache_dir=Some(cache),
    ),
    None,
  )
  let full_paths = @tokenizer.Tokenizer::from_pretrained_cache_paths(
    full_model,
    revision="main",
    cache_dir=Some(cache),
  ).unwrap()
  @test.assert_eq(
    @fs.path_exists(full_paths.tokenizer_json_path + ".incomplete"),
    false,
  )

  let range_model = "org/stream-range-tokenizer"
  let split = 42
  let prefix = string_prefix(range_json, split)
  let suffix = string_suffix(range_json, split)
  let resume_meta = @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
    range_model,
    revision="main",
    cache_dir=Some(cache),
    etag=Some("etag-range"),
    expected_size=Some(range_json.length()),
    downloaded_size=prefix.length(),
  )
  @fs.write_string_to_file(resume_meta.incomplete_path, prefix) catch {
    _ => abort("cannot write incomplete tokenizer cache")
  }
  let range_result = apply_tokenizer_json_download_chunks(
    range_model,
    [string_prefix(suffix, 17), string_suffix(suffix, 17)],
    HubResponseMetadata::new(
      206,
      resolved_revision=Some("rangerev"),
      etag=Some("etag-range"),
      content_length=Some(suffix.length()),
      accept_ranges=true,
    ),
    "https://hf.example/range-stream",
    options=opts,
  )
  @test.assert_eq(range_result.content, range_json)
  @test.assert_eq(range_result.status, 206)
  @test.assert_eq(
    @tokenizer.Tokenizer::from_pretrained_download_resume_metadata(
      range_model,
      revision="main",
      cache_dir=Some(cache),
    ),
    None,
  )
  @test.assert_eq(@fs.path_exists(resume_meta.incomplete_path), false)
}

///|
test "Hub streamed byte helper preserves UTF-8 split across chunks" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"你好🙂":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let bytes = @utf8.encode(json)
  let cache = "_build/hub_stream_utf8_cache"
  let model = "org/stream-utf8-tokenizer"
  let opts = HubDownloadOptions::new(cache_dir=Some(cache))
  let meta = HubResponseMetadata::new(
    200,
    resolved_revision=Some("utf8rev"),
    etag=Some("etag-utf8"),
    content_length=Some(bytes.length()),
    accept_ranges=true,
  )
  let result = apply_tokenizer_json_download_bytes(
    model,
    [bytes[0:56].to_owned(), bytes[56:57].to_owned(), bytes[57:].to_owned()],
    meta,
    "https://hf.example/utf8-stream",
    options=opts,
  )
  @test.assert_eq(result.content, json)
  @test.assert_eq(result.status, 200)
  @test.assert_eq(
    @tokenizer.Tokenizer::from_pretrained_download_resume_metadata(
      model,
      revision="main",
      cache_dir=Some(cache),
    ),
    None,
  )
  let paths = @tokenizer.Tokenizer::from_pretrained_cache_paths(
    model,
    revision="main",
    resolved_revision=Some("utf8rev"),
    cache_dir=Some(cache),
  ).unwrap()
  @test.assert_eq(
    @fs.path_exists(paths.tokenizer_json_path + ".incomplete"),
    false,
  )
}

///|
fn string_prefix(s : String, stop : Int) -> String {
  let chars = s.to_array()
  let end = if stop < 0 {
    0
  } else if stop > chars.length() {
    chars.length()
  } else {
    stop
  }
  let sb = StringBuilder::new()
  for i in 0..<end {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn string_suffix(s : String, start : Int) -> String {
  let chars = s.to_array()
  let begin = if start < 0 {
    0
  } else if start > chars.length() {
    chars.length()
  } else {
    start
  }
  let sb = StringBuilder::new()
  for i in begin..<chars.length() {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
async test "direct Hub network APIs reject local_files_only" {
  let options = HubDownloadOptions::new(
    endpoint="https://127.0.0.1:9",
    local_files_only=true,
  )
  let mut download_rejected = false
  try download_tokenizer_json("bert-base-uncased", options~) |> ignore catch {
    @types.ParseError(msg) =>
      download_rejected = msg.contains("local_files_only=true")
    _ => ()
  }
  @test.assert_eq(download_rejected, true)

  let mut head_rejected = false
  try head_tokenizer_json("bert-base-uncased", options~) |> ignore catch {
    @types.ParseError(msg) =>
      head_rejected = msg.contains("local_files_only=true")
    _ => ()
  }
  @test.assert_eq(head_rejected, true)

  let mut sidecar_rejected = false
  try
    download_hub_file("bert-base-uncased", "added_tokens.json", options~)
    |> ignore
  catch {
    @types.ParseError(msg) =>
      sidecar_rejected = msg.contains("local_files_only=true")
    _ => ()
  }
  @test.assert_eq(sidecar_rejected, true)
}

///|
async test "from_pretrained loads local tokenizer file and directory without Hub" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hub":0,"local":1,"dir":2,"[UNK]":3},"unk_token":"[UNK]"}}
  let file_path = "_build/hub_local_tokenizer.json"
  let dir_path = "_build/hub_local_pretrained"
  @fs.write_string_to_file(file_path, json) catch {
    _ => abort("cannot write local tokenizer file")
  }
  @fs.create_dir(dir_path) catch {
    _ => ()
  }
  @fs.write_string_to_file(dir_path + "/tokenizer.json", json) catch {
    _ => abort("cannot write local tokenizer directory")
  }
  let options = HubDownloadOptions::new(
    endpoint="https://127.0.0.1:9",
    local_files_only=false,
  )
  let from_file = from_pretrained(file_path, options~)
  let from_dir = from_pretrained(dir_path, options~)
  @test.assert_eq(from_file.encode("hub local", add_special_tokens=false).ids, [
    0, 1,
  ])
  @test.assert_eq(
    from_dir.encode("hub local dir", add_special_tokens=false).ids,
    [0, 1, 2],
  )
}

///|
async test "from_pretrained reports local directory missing tokenizer before Hub" {
  let dir_path = "_build/hub_local_missing_tokenizer"
  @fs.create_dir(dir_path) catch {
    _ => ()
  }
  let mut missing = false
  try
    from_pretrained(
      dir_path,
      options=HubDownloadOptions::new(
        endpoint="https://127.0.0.1:9",
        local_files_only=false,
      ),
    )
    |> ignore
  catch {
    @types.ParseError(msg) =>
      missing = msg.contains("from_pretrained directory missing tokenizer.json")
    _ => ()
  }
  @test.assert_eq(missing, true)
}

///|
async test "from_pretrained honors local_files_only cache hit and miss" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"local":0,"only":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let cache = "_build/hub_from_pretrained_local_only_cache"
  @tokenizer.Tokenizer::from_pretrained_downloaded(
    "org/local-only",
    json,
    cache_dir=Some(cache),
    resolved_revision=Some("abc123"),
  )
  |> ignore

  let hit = from_pretrained(
    "org/local-only",
    options=HubDownloadOptions::new(
      cache_dir=Some(cache),
      endpoint="https://127.0.0.1:9",
      local_files_only=true,
    ),
  )
  @test.assert_eq(hit.encode("local only", add_special_tokens=false).ids, [0, 1])

  let mut missed = false
  try
    from_pretrained(
      "org/missing-local-only",
      options=HubDownloadOptions::new(
        cache_dir=Some(cache),
        endpoint="https://127.0.0.1:9",
        local_files_only=true,
      ),
    )
    |> ignore
  catch {
    @types.ParseError(msg) =>
      missed = msg.contains(
        "from_pretrained local cache miss and local_files_only=true",
      )
    _ => ()
  }
  @test.assert_eq(missed, true)
}

///|
async test "optional online Hub smoke" {
  guard @sys.get_env_var("TOKENIZERS_MOONBIT_HUB_ONLINE_TEST") == Some("1") else {
    return
  }
  let tok = from_pretrained(
    "hf-internal-testing/tiny-random-BertModel",
    options=HubDownloadOptions::new(cache_dir=Some("_build/hub_online_cache")),
  )
  assert_true(tok.get_vocab_size() > 0)
}
