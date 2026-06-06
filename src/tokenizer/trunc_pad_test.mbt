// Truncation / padding / encode_batch tests, cross-checked against Python
// tokenizers (gpt2). Uses the disk fixture; self-skips when absent.

///|
test "truncation caps length (gpt2, right, max=5)" {
  guard load_text("tests/data/gpt2.full.json") is Some(mj) else { return }
  let tok = Tokenizer::from_str(mj).with_truncation(
    Some(TruncationParams::new(5)),
  )
  let enc = tok.encode(
    "The quick brown fox jumps over the lazy dog",
    add_special_tokens=false,
  )
  @test.assert_eq(enc.ids, [464, 2068, 7586, 21831, 18045])
}

///|
test "fixed padding pads right with attention mask (gpt2, len=8)" {
  guard load_text("tests/data/gpt2.full.json") is Some(mj) else { return }
  let tok = Tokenizer::from_str(mj).with_padding(
    Some(PaddingParams::new(Fixed(8), pad_id=0, pad_token="!")),
  )
  let enc = tok.encode("Hello world", add_special_tokens=false)
  @test.assert_eq(enc.ids, [15496, 995, 0, 0, 0, 0, 0, 0])
  @test.assert_eq(enc.attention_mask, [1, 1, 0, 0, 0, 0, 0, 0])
}

///|
test "batch padding pads to longest in batch" {
  guard load_text("tests/data/gpt2.full.json") is Some(mj) else { return }
  let tok = Tokenizer::from_str(mj).with_padding(
    Some(PaddingParams::new(BatchLongest)),
  )
  let batch = tok.encode_batch(["Hello world", "a"], add_special_tokens=false)
  // longest is "Hello world" (2 tokens); both padded to length 2.
  @test.assert_eq(batch.length(), 2)
  @test.assert_eq(batch[0].ids.length(), 2)
  @test.assert_eq(batch[1].ids.length(), 2)
  @test.assert_eq(batch[1].attention_mask, [1, 0])
}

///|
test "encode_pair applies fixed padding" {
  guard load_text("tests/data/bert.full.json") is Some(mj) else { return }
  let tok = Tokenizer::from_str(mj).with_padding(
    Some(PaddingParams::new(Fixed(8), pad_id=0, pad_token="[PAD]")),
  )
  let enc = tok.encode_pair("hello", "world", add_special_tokens=true)
  @test.assert_eq(enc.ids.length(), 8)
  @test.assert_eq(enc.attention_mask, [1, 1, 1, 1, 1, 0, 0, 0])
}

///|
fn trunc_strategy_json(strategy : String) -> String {
  "{\"version\":\"1.0\"," +
  "\"truncation\":{\"direction\":\"Right\",\"max_length\":8,\"stride\":0,\"strategy\":\"" +
  strategy +
  "\"}," +
  "\"pre_tokenizer\":{\"type\":\"WhitespaceSplit\"}," +
  "\"model\":{\"type\":\"WordLevel\",\"vocab\":{\"[CLS]\":0,\"[SEP]\":1,\"a0\":10,\"a1\":11,\"a2\":12,\"a3\":13,\"a4\":14,\"b0\":20,\"b1\":21,\"b2\":22,\"b3\":23,\"b4\":24,\"[UNK]\":99},\"unk_token\":\"[UNK]\"}," +
  "\"post_processor\":{\"type\":\"BertProcessing\",\"cls\":[\"[CLS]\",0],\"sep\":[\"[SEP]\",1]}}"
}

///|
test "pair truncation LongestFirst reserves special token slots" {
  let tok = Tokenizer::from_str(trunc_strategy_json("LongestFirst"))
  let enc = tok.encode_pair("a0 a1 a2 a3 a4", "b0 b1 b2 b3 b4")
  @test.assert_eq(enc.tokens, [
    "[CLS]", "a0", "a1", "[SEP]", "b0", "b1", "b2", "[SEP]",
  ])
  @test.assert_eq(enc.sequence_ids(), [
    None,
    Some(0),
    Some(0),
    None,
    Some(1),
    Some(1),
    Some(1),
    None,
  ])
}

///|
test "pair truncation OnlyFirst and OnlySecond target one side" {
  let first = Tokenizer::from_str(trunc_strategy_json("OnlyFirst"))
  let enc_first = first.encode_pair("a0 a1 a2 a3 a4", "b0 b1 b2 b3 b4")
  @test.assert_eq(enc_first.tokens, [
    "[CLS]", "[SEP]", "b0", "b1", "b2", "b3", "b4", "[SEP]",
  ])
  let second = Tokenizer::from_str(trunc_strategy_json("OnlySecond"))
  let enc_second = second.encode_pair("a0 a1 a2 a3 a4", "b0 b1 b2 b3 b4")
  @test.assert_eq(enc_second.tokens, [
    "[CLS]", "a0", "a1", "a2", "a3", "a4", "[SEP]", "[SEP]",
  ])
}
