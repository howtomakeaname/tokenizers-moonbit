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
  ) |> ignore
  @tokenizer.Tokenizer::write_pretrained_download_resume_metadata(
    "org/request-plan-tokenizer",
    revision="main",
    cache_dir=Some(cache),
    etag=Some("etag-partial"),
    expected_size=Some(1000),
    downloaded_size=256,
  ) |> ignore
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
  @test.assert_eq(plan.cache_paths.unwrap().snapshot_dir.has_suffix("/snapshots/abc123"), true)
  @test.assert_eq(plan.resume_metadata.unwrap().downloaded_size, 256)
}

///|
test "Hub response metadata parses cache headers" {
  let meta = HubResponseMetadata::from_headers(
    200,
    {
      "x-repo-commit": "abc123",
      "etag": "etag-new",
      "content-length": "4096",
      "accept-ranges": "bytes",
    },
  )
  @test.assert_eq(meta.status, 200)
  @test.assert_eq(meta.resolved_revision, Some("abc123"))
  @test.assert_eq(meta.etag, Some("etag-new"))
  @test.assert_eq(meta.content_length, Some(4096))
  @test.assert_eq(meta.accept_ranges, true)
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
