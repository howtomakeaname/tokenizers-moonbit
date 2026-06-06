///|
test "from_str parses a minimal BPE tokenizer.json" {
  let json =
    #|{"version":"1.0","model":{"type":"BPE","vocab":{"a":0,"b":1,"ab":2},"merges":[["a","b"]]}}
  let tok = Tokenizer::from_str(json)
  @test.assert_eq(tok.get_vocab_size(), 3)
  @test.assert_eq(tok.token_to_id("ab"), Some(2))
  @test.assert_eq(tok.id_to_token(1), Some("b"))
  @test.assert_eq(tok.token_to_id("zzz"), None)
}

///|
test "get_vocab can include added tokens" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":3,"content":"<extra>","special":true}],
    #| "model":{"type":"BPE","vocab":{"a":0,"b":1,"ab":2},"merges":[["a","b"]]}}
  let tok = Tokenizer::from_str(json)
  @test.assert_eq(tok.get_vocab_size(with_added_tokens=false), 3)
  @test.assert_eq(tok.get_vocab_size(with_added_tokens=true), 4)
  @test.assert_eq(tok.get_vocab(with_added_tokens=false).get("<extra>"), None)
  @test.assert_eq(tok.get_vocab().get("<extra>"), Some(3))
}

///|
test "decode_batch decodes each id sequence" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0," ":1,"moon":2},"unk_token":"hello"}}
  let tok = Tokenizer::from_str(json)
  @test.assert_eq(tok.decode_batch([[0, 1, 2], [2]]), ["hello moon", "moon"])
}

///|
test "from_str loads root truncation and padding config" {
  let json =
    #|{"version":"1.0",
    #| "truncation":{"direction":"Right","max_length":2,"stride":0,"strategy":"LongestFirst"},
    #| "padding":{"strategy":"Fixed","length":4,"direction":"Right","pad_id":9,"pad_type_id":0,"pad_token":"[PAD]"},
    #| "model":{"type":"BPE","vocab":{"a":0,"b":1,"c":2,"d":3,"[PAD]":9},"merges":[]}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("abcd", add_special_tokens=false)
  @test.assert_eq(enc.ids, [0, 1, 9, 9])
  @test.assert_eq(enc.attention_mask, [1, 1, 0, 0])
}

///|
test "from_str decodes optional components and added tokens" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":0,"content":"[UNK]","special":true}],
    #| "normalizer":{"type":"Lowercase"},
    #| "pre_tokenizer":{"type":"Whitespace"},
    #| "model":{"type":"WordPiece","vocab":{"[UNK]":0,"foo":1},"unk_token":"[UNK]"},
    #| "decoder":{"type":"WordPiece"}}
  let tok = Tokenizer::from_str(json)
  // [UNK] is an added special token: it resolves via the public lookups.
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(0))
  @test.assert_eq(tok.id_to_token(0), Some("[UNK]"))
  @test.assert_eq(tok.token_to_id("foo"), Some(1))
}

///|
test "from_str rejects non-object root" {
  let mut raised = false
  try Tokenizer::from_str("[1, 2, 3]") |> ignore catch {
    @types.ParseError(_) => raised = true
    _ => raised = false
  }
  assert_true(raised)
}

///|
test "from_str supports legacy string merges format" {
  let json =
    #|{"model":{"type":"BPE","vocab":{"h":0,"e":1,"he":2},"merges":["h e"]}}
  let tok = Tokenizer::from_str(json)
  // merge of "h"+"e" produced surface "he" present in vocab
  @test.assert_eq(tok.token_to_id("he"), Some(2))
}
