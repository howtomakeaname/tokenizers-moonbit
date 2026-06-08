// Cross-check the T5 Unigram (SentencePiece) encoder against Python tokenizers.
// add_special_tokens=false (post-processing covered in P7).

///|
test "t5 unigram encode matches python tokenizers" {
  guard load_text("tests/data/t5.full.json") is Some(model_json) else { return }
  guard load_text("tests/data/t5_expected.json") is Some(exp_json) else {
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
