// WordLevel model: whole-token lookup with unk fallback (inline, all backends).

///|
test "wordlevel maps whole tokens with unk fallback" {
  let json =
    #|{"model":{"type":"WordLevel",
    #| "vocab":{"hello":0,"world":1,"<unk>":2},"unk_token":"<unk>"},
    #| "pre_tokenizer":{"type":"WhitespaceSplit"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("hello world foo", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["hello", "world", "<unk>"])
  @test.assert_eq(enc.ids, [0, 1, 2])
}
