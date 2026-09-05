// End-to-end overflow-window tests. Every expected value below was verified
// against Python `tokenizers` 0.22.2 with the equivalent WordLevel tokenizer
// (`enable_truncation(max_length=..., stride=...)`).

///|
let overflowing_bert_json =
  #|{"version":"1.0",
  #| "pre_tokenizer":{"type":"WhitespaceSplit"},
  #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"a":2,"b":3,"c":4,"d":5,"e":6,"f":7,"g":8,"h":9,"[UNK]":10},"unk_token":"[UNK]"},
  #| "post_processor":{"type":"BertProcessing","cls":["[CLS]",0],"sep":["[SEP]",1]}}

///|
let overflowing_template_json =
  #|{"version":"1.0",
  #| "pre_tokenizer":{"type":"WhitespaceSplit"},
  #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"a":2,"b":3,"c":4,"d":5,"e":6,"f":7,"g":8,"h":9,"[UNK]":10},"unk_token":"[UNK]"},
  #| "post_processor":{"type":"TemplateProcessing",
  #|   "single":"[CLS]:0 $A:0 [SEP]:1",
  #|   "pair":"[CLS]:0 $A:0 [SEP]:1 $B:1 [SEP]:1",
  #|   "special_tokens":{"[CLS]":{"id":"[CLS]","ids":[0],"tokens":["[CLS]"]},"[SEP]":{"id":"[SEP]","ids":[1],"tokens":["[SEP]" ]}}}}

///|
let overflowing_plain_json =
  #|{"version":"1.0",
  #| "pre_tokenizer":{"type":"WhitespaceSplit"},
  #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"a":2,"b":3,"c":4,"d":5,"e":6,"f":7,"g":8,"h":9,"[UNK]":10},"unk_token":"[UNK]"}}

///|
let overflowing_bytelevel_json =
  #|{"version":"1.0",
  #| "pre_tokenizer":{"type":"WhitespaceSplit"},
  #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"a":2,"b":3,"c":4,"d":5,"e":6,"f":7,"g":8,"h":9,"[UNK]":10},"unk_token":"[UNK]"},
  #| "post_processor":{"type":"ByteLevel","add_prefix_space":false,"trim_offsets":false}}

///|
/// BertProcessing wraps each truncated overflow window in [CLS]/[SEP].
test "bert post-processor keeps template-wrapped overflow windows" {
  let tok = Tokenizer::from_str(overflowing_bert_json)
  let tok4 = tok.with_truncation(Some(TruncationParams::new(4)))
  let enc = tok4.encode("a b c d e f g h")
  @test.assert_eq(enc.ids, [0, 2, 3, 1])
  @test.assert_eq(enc.overflowing.length(), 3)
  @test.assert_eq(enc.overflowing[0].ids, [0, 4, 5, 1])
  @test.assert_eq(enc.overflowing[1].ids, [0, 6, 7, 1])
  @test.assert_eq(enc.overflowing[2].ids, [0, 8, 9, 1])
}

///|
/// With `stride > 0` the windows overlap the main sequence by `stride`.
test "bert post-processor stride windows overlap and wrap" {
  let tok = Tokenizer::from_str(overflowing_bert_json)
  let tok6 = tok.with_truncation(Some(TruncationParams::new(6).with_stride(2)))
  let enc = tok6.encode("a b c d e f g h")
  @test.assert_eq(enc.ids, [0, 2, 3, 4, 5, 1])
  @test.assert_eq(enc.overflowing.length(), 2)
  @test.assert_eq(enc.overflowing[0].ids, [0, 4, 5, 6, 7, 1])
  @test.assert_eq(enc.overflowing[1].ids, [0, 6, 7, 8, 9, 1])
}

///|
/// `add_special_tokens=false` skips specials on the main encoding and on
/// every window, and truncation then uses the full max_length budget.
test "bert post-processor windows respect add_special_tokens=false" {
  let tok = Tokenizer::from_str(overflowing_bert_json)
  let tok6 = tok.with_truncation(Some(TruncationParams::new(6).with_stride(2)))
  let enc = tok6.encode("a b c d e f g h", add_special_tokens=false)
  @test.assert_eq(enc.ids, [2, 3, 4, 5, 6, 7])
  @test.assert_eq(enc.overflowing.length(), 1)
  @test.assert_eq(enc.overflowing[0].ids, [6, 7, 8, 9])
}

///|
/// TemplateProcessing applies the single template to each window too.
test "template post-processor keeps wrapped overflow windows" {
  let tok = Tokenizer::from_str(overflowing_template_json)
  let tok4 = tok.with_truncation(Some(TruncationParams::new(4)))
  let enc = tok4.encode("a b c d e f g h")
  @test.assert_eq(enc.ids, [0, 2, 3, 1])
  @test.assert_eq(enc.overflowing.length(), 3)
  @test.assert_eq(enc.overflowing[0].ids, [0, 4, 5, 1])
  @test.assert_eq(enc.overflowing[1].ids, [0, 6, 7, 1])
  @test.assert_eq(enc.overflowing[2].ids, [0, 8, 9, 1])
  @test.assert_eq(enc.overflowing[0].special_tokens_mask, [1, 0, 0, 1])
}

///|
/// ByteLevel has no special pieces; windows pass through untouched.
test "byte-level post-processor keeps raw overflow windows" {
  let tok = Tokenizer::from_str(overflowing_bytelevel_json)
  let tok4 = tok.with_truncation(Some(TruncationParams::new(4)))
  let enc = tok4.encode("a b c d e f g h")
  @test.assert_eq(enc.ids, [2, 3, 4, 5])
  @test.assert_eq(enc.overflowing.length(), 1)
  @test.assert_eq(enc.overflowing[0].ids, [6, 7, 8, 9])
}

///|
/// Without any post-processor the truncated windows surface unchanged.
test "no post-processor keeps raw overflow windows" {
  let tok = Tokenizer::from_str(overflowing_plain_json)
  let tok4 = tok.with_truncation(Some(TruncationParams::new(4)))
  let enc = tok4.encode("a b c d e f g h")
  @test.assert_eq(enc.ids, [2, 3, 4, 5])
  @test.assert_eq(enc.overflowing.length(), 1)
  @test.assert_eq(enc.overflowing[0].ids, [6, 7, 8, 9])
}

///|
/// `Left` truncation keeps the tail as main and turns the removed head into
/// windows ordered closest-to-main first (HF `Encoding::truncate`).
test "left truncation keeps head windows" {
  let tok = Tokenizer::from_str(overflowing_bert_json)
  let left = tok.with_truncation(
    Some(TruncationParams::new(6).with_stride(2).with_direction_hf("left")),
  )
  let enc = left.encode("a b c d e f g h")
  @test.assert_eq(enc.ids, [0, 6, 7, 8, 9, 1])
  @test.assert_eq(enc.overflowing.length(), 2)
  @test.assert_eq(enc.overflowing[0].ids, [0, 4, 5, 6, 7, 1])
  @test.assert_eq(enc.overflowing[1].ids, [0, 2, 3, 4, 5, 1])
}

///|
/// HF pads overflow windows to the same target as the main encoding.
test "fixed padding pads overflow windows too" {
  let tok = Tokenizer::from_str(overflowing_bert_json)
  let padded = tok
    .with_truncation(Some(TruncationParams::new(4)))
    .with_padding(Some(PaddingParams::fixed(8, pad_id=5, pad_token="[UNK]")))
  let enc = padded.encode("a b c d e f g h")
  @test.assert_eq(enc.ids, [0, 2, 3, 1, 5, 5, 5, 5])
  @test.assert_eq(enc.overflowing.length(), 3)
  @test.assert_eq(enc.overflowing[0].ids, [0, 4, 5, 1, 5, 5, 5, 5])
  @test.assert_eq(enc.overflowing[2].ids, [0, 8, 9, 1, 5, 5, 5, 5])
  @test.assert_eq(enc.overflowing[0].attention_mask, [1, 1, 1, 1, 0, 0, 0, 0])
}

///|
/// HF rejects `stride >= effective max_length` (max minus added specials).
test "stride at or above effective max_length raises" {
  let tok = Tokenizer::from_str(overflowing_bert_json)
  let bad = tok.with_truncation(Some(TruncationParams::new(4).with_stride(4)))
  let message = try {
    let _ = bad.encode("a b c d e f g h")
    "no error"
  } catch {
    e => e.message()
  }
  @test.assert_eq(
    message, "truncation stride 4 must be strictly less than the effective max_length 2",
  )
}

///|
/// Pair overflow windows follow an HF cross-product scheme that is not
/// reproduced yet; pair results keep `overflowing` empty (documented gap).
test "pair encode keeps overflowing empty for now" {
  let tok = Tokenizer::from_str(overflowing_bert_json)
  let tok4 = tok.with_truncation(Some(TruncationParams::new(4)))
  let enc = tok4.encode_pair("a b c d e f g h", "a b c d e f g h")
  @test.assert_eq(enc.ids.length(), 4)
  @test.assert_eq(enc.overflowing.length(), 0)
}
