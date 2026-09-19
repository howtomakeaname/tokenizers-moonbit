// HF 0.22.2 BertPreTokenizer semantics: whitespace split (Removed) +
// punctuation isolated with HF's classifier. CJK runs are NOT split per
// char (that is BertNormalizer's handle_chinese_chars concern).
// Expectations verified against Python `tokenizers` 0.22.2 probes.

///|
test "bert pre-tokenizer groups CJK and isolates fullwidth punctuation" {
  let json =
    #|{"version":"1.0","pre_tokenizer":{"type":"BertPreTokenizer"},"model":{"type":"WordLevel","vocab":{"x":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  // Python 0.22.2 pieces: 你好 | ， | 世界 | ！ | Hello
  let enc = tok.encode("你好，世界！ Hello", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["[UNK]", "[UNK]", "[UNK]", "[UNK]", "[UNK]"])
  @test.assert_eq(enc.offsets, [(0, 2), (2, 3), (3, 5), (5, 6), (7, 12)])
}

///|
/// Fullwidth apostrophe splits words exactly like ASCII apostrophes.
/// Python 0.22.2 "a＇b" with BertPreTokenizer -> a | ＇ | b.
test "bert pre-tokenizer isolates fullwidth apostrophe" {
  let json =
    #|{"version":"1.0","pre_tokenizer":{"type":"BertPreTokenizer"},"model":{"type":"WordLevel","vocab":{"x":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("x＇x", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["x", "[UNK]", "x"])
}

///|
/// Punctuation pre-tokenizer uses the same HF classifier.
/// Python 0.22.2 "a！b" Isolated -> a | ！ | b.
test "punctuation pre-tokenizer isolates fullwidth punct" {
  let json =
    #|{"version":"1.0","pre_tokenizer":{"type":"Punctuation","behavior":"Isolated"},"model":{"type":"WordLevel","vocab":{"x":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("x！x", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["x", "[UNK]", "x"])
}
