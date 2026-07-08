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
  @test.assert_eq(plan.range_start, Some(256))
  @test.assert_eq(plan.conditional_etag, Some("etag-existing"))
  @test.assert_eq(
    plan.cache_paths.unwrap().snapshot_dir.has_suffix("/snapshots/abc123"),
    true,
  )
  @test.assert_eq(plan.resume_metadata.unwrap().downloaded_size, 256)
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
  let not_modified = decide_tokenizer_json_head_response(
    head_plan,
    HubResponseMetadata::new(
      304,
      resolved_revision=Some("headrev"),
      etag=Some("etag-head"),
    ),
  )
  @test.assert_eq(not_modified.can_use_cache(), true)
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
