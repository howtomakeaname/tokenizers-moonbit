test "from_str parses a minimal BPE tokenizer.json" {
  let json =
    #|{"version":"1.0","model":{"type":"BPE","vocab":{"a":0,"b":1,"ab":2},"merges":[["a","b"]]}}
  let tok = Tokenizer::from_str(json)
  assert_eq(tok.get_vocab_size(), 3)
  assert_eq(tok.token_to_id("ab"), Some(2))
  assert_eq(tok.id_to_token(1), Some("b"))
  assert_eq(tok.token_to_id("zzz"), None)
}

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
  assert_eq(tok.token_to_id("[UNK]"), Some(0))
  assert_eq(tok.id_to_token(0), Some("[UNK]"))
  assert_eq(tok.token_to_id("foo"), Some(1))
}

test "from_str rejects non-object root" {
  let mut raised = false
  try Tokenizer::from_str("[1, 2, 3]") |> ignore catch {
    @types.ParseError(_) => raised = true
    _ => raised = false
  }
  assert_true(raised)
}

test "from_str supports legacy string merges format" {
  let json =
    #|{"model":{"type":"BPE","vocab":{"h":0,"e":1,"he":2},"merges":["h e"]}}
  let tok = Tokenizer::from_str(json)
  // merge of "h"+"e" produced surface "he" present in vocab
  assert_eq(tok.token_to_id("he"), Some(2))
}
