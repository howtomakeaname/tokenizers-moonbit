///|
test "Hub redirect and client URL parsing are deterministic" {
  @test.assert_eq(
    resolve_redirect(
      "https://hf.example/org/model/resolve/main/tokenizer.json", "https://cdn.example/file.json",
    ),
    "https://cdn.example/file.json",
  )
  @test.assert_eq(
    resolve_redirect(
      "https://hf.example/org/model/resolve/main/tokenizer.json", "/org/model/resolve/commit/tokenizer.json",
    ),
    "https://hf.example/org/model/resolve/commit/tokenizer.json",
  )
  @test.assert_eq(
    resolve_redirect(
      "https://hf.example/org/model/resolve/main/tokenizer.json", "added_tokens.json",
    ),
    "https://hf.example/org/model/resolve/main/added_tokens.json",
  )
  @test.assert_eq(
    split_url_for_client("https://hf.example/org/model/tokenizer.json"),
    ("https://hf.example", "/org/model/tokenizer.json"),
  )
  @test.assert_eq(
    split_url_for_client("https://hf.example"),
    ("https://hf.example", "/"),
  )
  let mut invalid = false
  try split_url_for_client("ftp://hf.example/model") |> ignore catch {
    @types.ParseError(msg) => invalid = msg.contains("must start with")
    _ => ()
  }
  @test.assert_eq(invalid, true)
}
