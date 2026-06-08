// Cross-check the BERT WordPiece encoder against Python `tokenizers`.
// add_special_tokens=false (post-processing/[CLS]/[SEP] is covered in P7).

///|
test "bert wordpiece encode matches python tokenizers" {
  guard load_text("tests/data/bert.full.json") is Some(model_json) else {
    return
  }
  guard load_text("tests/data/bert_expected.json") is Some(exp_json) else {
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
