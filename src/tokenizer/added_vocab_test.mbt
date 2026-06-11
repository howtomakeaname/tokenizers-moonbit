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
  // HF marks inline added/special tokens as ordinary input tokens; the
  // special_tokens_mask is reserved for post-processor-inserted tokens.
  @test.assert_eq(enc.special_tokens_mask, [0, 0, 0])
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
  @test.assert_eq(enc.tokens, ["ab", " [MASK] ", "ab"])
}

///|
test "single_word added tokens use Unicode word boundaries" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":1,"content":"TAG","single_word":true,"lstrip":false,"rstrip":false,"normalized":false,"special":false}],
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"[UNK]":0,"TAG":1,"αTAGβ":2,"中TAG文":3,"TAGα":4,"αTAG":5,"foo":6},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  @test.assert_eq(tok.encode("αTAGβ", add_special_tokens=false).tokens, [
    "αTAGβ",
  ])
  @test.assert_eq(tok.encode("中TAG文", add_special_tokens=false).tokens, [
    "中TAG文",
  ])
  @test.assert_eq(tok.encode("TAGα", add_special_tokens=false).tokens, [
    "TAGα",
  ])
  @test.assert_eq(tok.encode("αTAG", add_special_tokens=false).tokens, [
    "αTAG",
  ])
  @test.assert_eq(tok.encode("TAG!", add_special_tokens=false).tokens, [
    "TAG", "[UNK]",
  ])
  @test.assert_eq(tok.encode("!TAG", add_special_tokens=false).tokens, [
    "[UNK]", "TAG",
  ])
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

///|
test "pretokenized encode still extracts added tokens inside words" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":3,"content":"[MASK]","special":true,"normalized":false}],
    #| "normalizer":{"type":"Lowercase"},
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"world":1,"[UNK]":2,"[MASK]":3},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode_pretokenized(
    ["Hello[MASK]WORLD"],
    add_special_tokens=false,
  )
  @test.assert_eq(enc.tokens, ["hello", "[MASK]", "world"])
  @test.assert_eq(enc.ids, [0, 3, 1])
  @test.assert_eq(enc.offsets, [(0, 5), (5, 11), (11, 16)])
  @test.assert_eq(enc.special_tokens_mask, [0, 0, 0])
  @test.assert_eq(enc.word_ids(), [Some(0), Some(0), Some(0)])
}

///|
test "pretokenized added token offsets survive batch and byte conversion" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":4,"content":"[MASK]","special":true,"lstrip":true,"rstrip":true,"normalized":false}],
    #| "padding":{"strategy":"BatchLongest","direction":"Right","pad_id":3,"pad_type_id":0,"pad_token":"[PAD]"},
    #| "normalizer":{"type":"Lowercase"},
    #| "model":{"type":"WordLevel","vocab":{"我":0,"hello":1,"world":2,"[PAD]":3,"[MASK]":4,"[UNK]":5},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let encs = tok.encode_pretokenized_batch_with_byte_offsets(
    [["我", " [MASK] ", "WORLD"], ["Hello", "WORLD"]],
    add_special_tokens=false,
  )
  @test.assert_eq(encs.length(), 2)
  @test.assert_eq(encs[0].tokens, ["我", " [MASK] ", "world"])
  // Synthetic normalized text is "我  [mask]  world"; byte offsets include the
  // spaces consumed by lstrip/rstrip around [MASK].
  @test.assert_eq(encs[0].offsets, [(0, 3), (4, 12), (13, 18)])
  @test.assert_eq(encs[0].special_tokens_mask, [0, 0, 0])
  @test.assert_eq(encs[0].word_ids(), [Some(0), Some(1), Some(2)])
  @test.assert_eq(encs[1].tokens, ["hello", "world", "[PAD]"])
  @test.assert_eq(encs[1].attention_mask, [1, 1, 0])
}
