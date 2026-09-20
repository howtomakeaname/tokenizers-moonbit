// Parity residual fixes, expectations probed from Python `tokenizers`
// 0.22.2: single-encode BatchLongest padding, authoritative ByteLevel
// trim rules, standalone StripAccents vs BertNormalizer accents, and
// added-token id allocation (model-id reuse + collision reassignment).

///|
/// BatchLongest pads a single encode too: longest of a one-element batch
/// is the encoding itself, rounded up to pad_to_multiple_of
/// (Python 0.22.2: len 5 with multiple 2 -> 6).
test "batch-longest pads single encode to multiple" {
  let json =
    #|{"version":"1.0","pre_tokenizer":{"type":"WhitespaceSplit"},"padding":{"strategy":"BatchLongest","direction":"Right","pad_id":0,"pad_token":"[PAD]","pad_to_multiple_of":2,"pad_type_id":0},"model":{"type":"WordLevel","vocab":{"a":1,"[PAD]":0,"[UNK]":2},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let e = tok.encode("a a a a a")
  @test.assert_eq(e.ids.length(), 6)
  @test.assert_eq(e.tokens[e.ids.length() - 1], "[PAD]")
  @test.assert_eq(e.attention_mask(), [1, 1, 1, 1, 1, 0])
}
