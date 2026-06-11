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
