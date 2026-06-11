// Cross-check Llama BPE (byte_fallback + Metaspace) against Python tokenizers.
// The emoji case exercises byte_fallback: 😀 -> <0xF0><0x9F><0x98><0x80>.

///|
test "llama byte-fallback BPE matches python tokenizers" {
  guard load_text("tests/data/llama.full.json") is Some(model_json) else {
    return
  }
  guard load_text("tests/data/llama_expected.json") is Some(exp_json) else {
    return
  }
  let tok = @tokenizer.Tokenizer::from_str(model_json)
  let cases = @types.as_array(@json.parse(exp_json), "expected")
  for case in cases {
    let obj = @types.as_object(case, "case")
    let text = @types.get_str(obj, "text", default="")
    let want_ids = parse_int_array(obj, "ids")
    let enc = tok.encode(text, add_special_tokens=false)
    @test.assert_eq(enc.ids, want_ids)
  }
}

///|
test "llama decode round-trip reconstructs text incl. emoji" {
  guard load_text("tests/data/llama.full.json") is Some(model_json) else {
    return
  }
  let tok = @tokenizer.Tokenizer::from_str(model_json)
  // emoji survives the byte_fallback encode -> ByteFallback decode round-trip.
  for text in ["Hello world", "emoji 😀 test", "日本語"] {
    let enc = tok.encode(text, add_special_tokens=false)
    @test.assert_eq(tok.decode(enc.ids, skip_special_tokens=false), text)
  }
}

///|
test "llama normalized special tokens match python tokenizers" {
  guard load_text("tests/data/llama.full.json") is Some(model_json) else {
    return
  }
  let tok = @tokenizer.Tokenizer::from_str(model_json)

  let spaced = tok.encode("hello </s> world", add_special_tokens=false)
  @test.assert_eq(spaced.tokens, ["▁hello", "▁</s>", "▁world"])
  @test.assert_eq(spaced.ids, [22172, 2, 3186])
  @test.assert_eq(spaced.special_tokens_mask, [0, 0, 0])

  let embedded = tok.encode("hello</s>world", add_special_tokens=false)
  @test.assert_eq(embedded.tokens, ["▁hello", "</", "s", ">", "world"])
  @test.assert_eq(embedded.ids, [22172, 829, 29879, 29958, 11526])

  let instruction = tok.encode(
    "<s>[INST] hi [/INST]</s>",
    add_special_tokens=false,
  )
  @test.assert_eq(instruction.ids, [
    1, 29961, 25580, 29962, 7251, 518, 29914, 25580, 29962, 829, 29879, 29958,
  ])
}
