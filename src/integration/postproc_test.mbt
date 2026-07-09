// Post-processing (P7): special tokens, type_ids, special_tokens_mask.

///|
test "bert post-processing adds CLS/SEP and masks" {
  guard load_text("tests/data/bert.full.json") is Some(model_json) else {
    return
  }
  guard load_text("tests/data/bert_special_expected.json") is Some(exp_json) else {
    return
  }
  let tok = @tokenizer.Tokenizer::from_str(model_json)
  let cases = @types.as_array(@json.parse(exp_json), "expected")
  for case in cases {
    let obj = @types.as_object(case, "case")
    let text = @types.get_str(obj, "text", default="")
    let enc = tok.encode(text, add_special_tokens=true)
    @test.assert_eq(enc.ids, parse_int_array(obj, "ids"))
    @test.assert_eq(enc.type_ids, parse_int_array(obj, "type_ids"))
    @test.assert_eq(
      enc.special_tokens_mask,
      parse_int_array(obj, "special_tokens_mask"),
    )
    // attention mask is all ones for a single sequence
    @test.assert_eq(enc.attention_mask.length(), enc.ids.length())
  }
}

///|
test "bert encode_pair builds [CLS] A [SEP] B [SEP] with type ids" {
  guard load_text("tests/data/bert.full.json") is Some(model_json) else {
    return
  }
  let tok = @tokenizer.Tokenizer::from_str(model_json)
  let enc = tok.encode_pair("hello", "world", add_special_tokens=true)
  // [CLS] hello [SEP] world [SEP]
  @test.assert_eq(enc.tokens, ["[CLS]", "hello", "[SEP]", "world", "[SEP]"])
  @test.assert_eq(enc.type_ids, [0, 0, 0, 1, 1])
  @test.assert_eq(enc.special_tokens_mask, [1, 0, 1, 0, 1])
}

///|
test "sequence post-processor preserves pair input without duplication" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"[UNK]":0,"[CLS]":1,"[SEP]":2,"a":3,"Ġb":4},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"Sequence","processors":[{"type":"ByteLevel","trim_offsets":true},{"type":"BertProcessing","sep":["[SEP]",2],"cls":["[CLS]",1]}]}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  let enc = tok.encode_pair("a", " b", add_special_tokens=true)
  @test.assert_eq(enc.tokens, ["[CLS]", "a", "[SEP]", "Ġb", "[SEP]"])
  @test.assert_eq(enc.ids, [1, 3, 2, 4, 2])
  @test.assert_eq(enc.type_ids, [0, 0, 0, 1, 1])
  @test.assert_eq(enc.offsets, [(0, 0), (0, 1), (0, 0), (0, 2), (0, 0)])
  @test.assert_eq(enc.sequence_ids(), [None, Some(0), None, Some(1), None])
  @test.assert_eq(enc.special_tokens_mask, [1, 0, 1, 0, 1])
}

///|
test "sequence bytelevel-only post-processor keeps pair input" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"[UNK]":0,"a":1,"Ġb":2},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"Sequence","processors":[{"type":"ByteLevel","trim_offsets":true}]}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  let enc = tok.encode_pair("a", " b", add_special_tokens=true)
  @test.assert_eq(enc.tokens, ["a", "Ġb"])
  @test.assert_eq(enc.ids, [1, 2])
  @test.assert_eq(enc.type_ids, [0, 1])
  @test.assert_eq(enc.offsets, [(0, 1), (0, 2)])
  @test.assert_eq(enc.sequence_ids(), [Some(0), Some(1)])
  @test.assert_eq(enc.special_tokens_mask, [0, 0])
}

///|
test "roberta encode_pair keeps all type ids zero" {
  guard load_text("tests/data/roberta.full.json") is Some(model_json) else {
    return
  }
  let tok = @tokenizer.Tokenizer::from_str(model_json)
  let enc = tok.encode_pair("hello", "world", add_special_tokens=true)
  for tid in enc.type_ids {
    @test.assert_eq(tid, 0)
  }
  @test.assert_eq(enc.special_tokens_mask[0], 1)
}

///|
test "bytelevel post-processor trims whitespace offsets" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"Ġ":1,"Ġb":2,"[UNK]":3},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"ByteLevel","trim_offsets":true}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  let enc = tok.encode("a  b", add_special_tokens=true)
  @test.assert_eq(enc.tokens, ["a", "Ġ", "Ġb"])
  @test.assert_eq(enc.offsets, [(0, 1), (2, 2), (3, 4)])
  @test.assert_eq(enc.char_to_token(1), None)
  @test.assert_eq(enc.char_to_token(3), Some(2))

  let leading = tok.encode(" b", add_special_tokens=true)
  @test.assert_eq(leading.tokens, ["Ġb"])
  @test.assert_eq(leading.offsets, [(0, 2)])
}

///|
test "bytelevel post-processor can keep raw offsets" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"Ġ":1,"Ġb":2,"[UNK]":3},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"ByteLevel","trim_offsets":false}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  let enc = tok.encode("a  b", add_special_tokens=true)
  @test.assert_eq(enc.tokens, ["a", "Ġ", "Ġb"])
  @test.assert_eq(enc.offsets, [(0, 1), (1, 2), (2, 4)])
}

///|
test "roberta post-processor trims bytelevel offsets before specials" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"Ġ":1,"Ġb":2,"[UNK]":3},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"RobertaProcessing","sep":["</s>",4],"cls":["<s>",5],"trim_offsets":true,"add_prefix_space":false}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  let enc = tok.encode("a  b", add_special_tokens=true)
  @test.assert_eq(enc.tokens, ["<s>", "a", "Ġ", "Ġb", "</s>"])
  @test.assert_eq(enc.offsets, [(0, 0), (0, 1), (2, 2), (3, 4), (0, 0)])
  @test.assert_eq(enc.sequence_ids(), [None, Some(0), Some(0), Some(0), None])
}

///|
test "template processing parses HF string DSL" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"<s>":0,"</s>":1,"hello":2,"world":3,"[UNK]":4},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"TemplateProcessing",
    #|   "single":"<s>:0 $A </s>:0",
    #|   "pair":"<s>:0 $A </s>:0 $B:1 </s>:1",
    #|   "special_tokens":{"<s>":{"id":"<s>","ids":[0],"tokens":["<s>"]},"</s>":{"id":"</s>","ids":[1],"tokens":["</s>"]}}}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  let single = tok.encode("hello", add_special_tokens=true)
  @test.assert_eq(single.tokens, ["<s>", "hello", "</s>"])
  @test.assert_eq(single.type_ids, [0, 0, 0])
  @test.assert_eq(single.special_tokens_mask, [1, 0, 1])

  let pair = tok.encode_pair("hello", "world", add_special_tokens=true)
  @test.assert_eq(pair.tokens, ["<s>", "hello", "</s>", "world", "</s>"])
  @test.assert_eq(pair.type_ids, [0, 0, 0, 1, 1])
  @test.assert_eq(pair.sequence_ids(), [None, Some(0), None, Some(1), None])
}

///|
test "template processing accepts numeric sequence aliases" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"<s>":0,"</s>":1,"hello":2,"world":3,"[UNK]":4},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"TemplateProcessing",
    #|   "single":"<s>:0 $0 </s>:0",
    #|   "pair":"<s>:0 $0 </s>:0 $1:1 </s>:1",
    #|   "special_tokens":{"<s>":{"id":"<s>","ids":[0],"tokens":["<s>"]},"</s>":{"id":"</s>","ids":[1],"tokens":["</s>"]}}}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  let pair = tok.encode_pair("hello", "world", add_special_tokens=true)
  @test.assert_eq(pair.tokens, ["<s>", "hello", "</s>", "world", "</s>"])
  @test.assert_eq(pair.type_ids, [0, 0, 0, 1, 1])
  @test.assert_eq(pair.sequence_ids(), [None, Some(0), None, Some(1), None])
}
