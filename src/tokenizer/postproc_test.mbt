// Post-processing (P7): special tokens, type_ids, special_tokens_mask.

test "bert post-processing adds CLS/SEP and masks" {
  guard load_text("tests/data/bert.full.json") is Some(model_json) else {
    return
  }
  guard load_text("tests/data/bert_special_expected.json") is Some(exp_json) else {
    return
  }
  let tok = Tokenizer::from_str(model_json)
  let cases = @types.as_array(@json.parse(exp_json), "expected")
  for case in cases {
    let obj = @types.as_object(case, "case")
    let text = @types.get_str(obj, "text", default="")
    let enc = tok.encode(text, add_special_tokens=true)
    assert_eq(enc.ids, parse_int_array(obj, "ids"))
    assert_eq(enc.type_ids, parse_int_array(obj, "type_ids"))
    assert_eq(enc.special_tokens_mask, parse_int_array(obj, "special_tokens_mask"))
    // attention mask is all ones for a single sequence
    assert_eq(enc.attention_mask.length(), enc.ids.length())
  }
}

test "bert encode_pair builds [CLS] A [SEP] B [SEP] with type ids" {
  guard load_text("tests/data/bert.full.json") is Some(model_json) else {
    return
  }
  let tok = Tokenizer::from_str(model_json)
  let enc = tok.encode_pair("hello", "world", add_special_tokens=true)
  // [CLS] hello [SEP] world [SEP]
  assert_eq(enc.tokens, ["[CLS]", "hello", "[SEP]", "world", "[SEP]"])
  assert_eq(enc.type_ids, [0, 0, 0, 1, 1])
  assert_eq(enc.special_tokens_mask, [1, 0, 1, 0, 1])
}
