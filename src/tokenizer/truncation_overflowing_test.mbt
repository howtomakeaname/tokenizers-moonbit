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
let overflowing_pair_json =
  #|{"version":"1.0",
  #| "pre_tokenizer":{"type":"WhitespaceSplit"},
  #| "model":{"type":"WordLevel","vocab":{"t0":0,"t1":1,"t2":2,"t3":3,"t4":4,"t5":5,"t6":6,"t7":7,"t8":8,"t9":9,"t10":10,"t11":11,"t12":12,"t13":13,"t14":14,"t15":15,"t16":16,"t17":17,"t18":18,"t19":19,"u0":20,"u1":21,"u2":22,"u3":23,"u4":24,"u5":25,"u6":26,"u7":27,"u8":28,"u9":29,"u10":30,"u11":31,"[UNK]":99},"unk_token":"[UNK]"}}

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
/// Pair overflow follows HF 0.22.x: every (a-part, b-part) combination of
/// the per-side truncation windows plus the truncated mains, except the
/// main pair itself. Expectations measured against Python `tokenizers`
/// 0.22.2 (`a` = 20 t-tokens, `b` = 12 u-tokens, keep 8/8, stride 4):
/// 7 windows, a-windows first (each against main-b then every b-window),
/// then main-a against each b-window.
test "pair overflow builds the 0.22.x window cross-product" {
  let tok = Tokenizer::from_str(overflowing_pair_json)
  let tok4 = tok.with_truncation(Some(TruncationParams::new(16).with_stride(4)))
  let enc = tok4.encode_pair(
    "t0 t1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11 t12 t13 t14 t15 t16 t17 t18 t19", "u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11",
  )
  @test.assert_eq(enc.ids, [
    0, 1, 2, 3, 4, 5, 6, 7, 20, 21, 22, 23, 24, 25, 26, 27,
  ])
  @test.assert_eq(enc.overflowing.length(), 7)
  @test.assert_eq(enc.overflowing[0].ids, [
    4, 5, 6, 7, 8, 9, 10, 11, 20, 21, 22, 23, 24, 25, 26, 27,
  ])
  @test.assert_eq(enc.overflowing[1].ids, [
    4, 5, 6, 7, 8, 9, 10, 11, 24, 25, 26, 27, 28, 29, 30, 31,
  ])
  @test.assert_eq(enc.overflowing[6].ids, [
    0, 1, 2, 3, 4, 5, 6, 7, 24, 25, 26, 27, 28, 29, 30, 31,
  ])
}

///|
/// BertProcessing pair overflow: the template wraps every cross-product
/// combination. Measured against Python `tokenizers` 0.22.2 (12 a-tokens,
/// 8 b-tokens, max 10, stride 2, pair-added 3, keep 4/3): 29 windows.
test "bert pair overflow wraps every cross-product combination" {
  let vocab = "{\"[CLS]\":40,\"[SEP]\":41,\"[UNK]\":99,\"t0\":0,\"t1\":1,\"t2\":2,\"t3\":3,\"t4\":4,\"t5\":5,\"t6\":6,\"t7\":7,\"t8\":8,\"t9\":9,\"t10\":10,\"t11\":11,\"u0\":20,\"u1\":21,\"u2\":22,\"u3\":23,\"u4\":24,\"u5\":25,\"u6\":26,\"u7\":27}"
  let json = "{\"version\":\"1.0\",\"pre_tokenizer\":{\"type\":\"WhitespaceSplit\"},\"model\":{\"type\":\"WordLevel\",\"vocab\":\{vocab},\"unk_token\":\"[UNK]\"},\"post_processor\":{\"type\":\"BertProcessing\",\"cls\":[\"[CLS]\",40],\"sep\":[\"[SEP]\",41]}}"
  let tok = Tokenizer::from_str(json)
  let tok_t = tok.with_truncation(
    Some(TruncationParams::new(10).with_stride(2)),
  )
  let enc = tok_t.encode_pair(
    "t0 t1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11", "u0 u1 u2 u3 u4 u5 u6 u7",
  )
  // main: [CLS] t0..t3 [SEP] u0..u2 [SEP]
  @test.assert_eq(enc.ids, [40, 0, 1, 2, 3, 41, 20, 21, 22, 41])
  @test.assert_eq(enc.overflowing.length(), 29)
  // First window: a-window t2..t5 against main-b.
  @test.assert_eq(enc.overflowing[0].ids, [40, 2, 3, 4, 5, 41, 20, 21, 22, 41])
  // Second: same a-window against b-window u1..u3.
  @test.assert_eq(enc.overflowing[1].ids, [40, 2, 3, 4, 5, 41, 21, 22, 23, 41])
  // Last window: main-a against the final b-window u5..u7.
  @test.assert_eq(enc.overflowing[28].ids, [40, 0, 1, 2, 3, 41, 25, 26, 27, 41])
  // Windows are padded/masked like the main encoding.
  @test.assert_eq(enc.overflowing[0].special_tokens_mask, [
    1, 0, 0, 0, 0, 1, 0, 0, 0, 1,
  ])
}
