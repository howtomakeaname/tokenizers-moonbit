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
