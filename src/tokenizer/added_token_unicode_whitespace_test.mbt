///|
let unicode_ws_added_token_json : String =
  #|{
  #|  "version": "1.0",
  #|  "added_tokens": [
  #|    {"id": 3, "content": "[MASK]", "special": true, "lstrip": true, "rstrip": true, "normalized": false}
  #|  ],
  #|  "pre_tokenizer": {"type": "WhitespaceSplit"},
  #|  "model": {
  #|    "type": "WordLevel",
  #|    "vocab": {"foo": 0, "bar": 1, "[UNK]": 2, "[MASK]": 3},
  #|    "unk_token": "[UNK]"
  #|  }
  #|}

///|
test "AddedToken lstrip/rstrip consumes NBSP around token" {
  let tok = Tokenizer::from_str(unicode_ws_added_token_json)
  let enc = tok.encode("foo\u{00A0}[MASK]\u{00A0}bar", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["foo", "\u{00A0}[MASK]\u{00A0}", "bar"])
  @test.assert_eq(enc.ids, [0, 3, 1])
  @test.assert_eq(enc.offsets, [(0, 3), (3, 11), (11, 14)])
}

///|
test "AddedToken lstrip/rstrip consumes mixed Unicode whitespace" {
  let tok = Tokenizer::from_str(unicode_ws_added_token_json)
  let enc = tok.encode(
    "foo\u{2003}\u{202F}[MASK]\u{0B}\u{0C}\u{3000}bar",
    add_special_tokens=false,
  )
  @test.assert_eq(enc.tokens, [
    "foo", "\u{2003}\u{202F}[MASK]\u{0B}\u{0C}\u{3000}", "bar",
  ])
  @test.assert_eq(enc.ids, [0, 3, 1])
  @test.assert_eq(enc.offsets, [(0, 3), (3, 14), (14, 17)])
}
