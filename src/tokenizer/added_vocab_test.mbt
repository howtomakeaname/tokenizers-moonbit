// AddedVocabulary: special/added tokens are extracted from text before the
// model runs, even when they appear in the middle of text.

///|
let av_bpe : String =
  #|{
  #|  "added_tokens": [
  #|    {"id": 5, "content": "<s>", "special": true},
  #|    {"id": 6, "content": "</s>", "special": true},
  #|    {"id": 7, "content": "[MASK]", "special": true, "lstrip": true, "rstrip": true}
  #|  ],
  #|  "model": {
  #|    "type": "BPE",
  #|    "vocab": {"a":0,"b":1,"c":2,"ab":3,"abc":4,"<s>":5,"</s>":6,"[MASK]":7},
  #|    "merges": [["a","b"],["ab","c"]]
  #|  }
  #|}

///|
test "added tokens split out of surrounding text" {
  let tok = Tokenizer::from_str(av_bpe)
  let enc = tok.encode("<s>abc</s>", add_special_tokens=false)
  // <s> | abc(merged) | </s>
  @test.assert_eq(enc.tokens, ["<s>", "abc", "</s>"])
  @test.assert_eq(enc.ids, [5, 4, 6])
  @test.assert_eq(enc.special_tokens_mask, [1, 0, 1])
}

///|
test "added token in the middle of text" {
  let tok = Tokenizer::from_str(av_bpe)
  let enc = tok.encode("ab[MASK]ab", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["ab", "[MASK]", "ab"])
  @test.assert_eq(enc.ids, [3, 7, 3])
}

///|
test "lstrip/rstrip eats surrounding whitespace" {
  let tok = Tokenizer::from_str(av_bpe)
  // [MASK] has lstrip+rstrip: the spaces around it are absorbed into the token.
  let enc = tok.encode("ab [MASK] ab", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["ab", "[MASK]", "ab"])
}

///|
test "decode skips special added tokens" {
  let tok = Tokenizer::from_str(av_bpe)
  let s = tok.decode([5, 4, 6], skip_special_tokens=true)
  // <s> and </s> dropped; only "abc" remains (no decoder -> join surfaces)
  @test.assert_eq(s, "abc")
  let s2 = tok.decode([5, 4, 6], skip_special_tokens=false)
  @test.assert_eq(s2, "<s>abc</s>")
}
