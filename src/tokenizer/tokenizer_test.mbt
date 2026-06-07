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
test "BPE ignore_merges uses whole-token fast path before fallback merges" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"BPE","vocab":{"a":0,"b":1,"c":2,"ab":3,"abc":4},"merges":[["a","b"]],"ignore_merges":true}}
  let tok = Tokenizer::from_str(json)
  let direct = tok.encode("abc", add_special_tokens=false)
  @test.assert_eq(direct.tokens, ["abc"])
  @test.assert_eq(direct.ids, [4])
  let fallback = tok.encode("ab c", add_special_tokens=false)
  @test.assert_eq(fallback.tokens, ["ab", "c"])
  @test.assert_eq(fallback.ids, [3, 2])
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
test "decode_batch handles duplicate id sequences" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0," ":1,"moon":2},"unk_token":"hello"}}
  let tok = Tokenizer::from_str(json)
  @test.assert_eq(tok.decode_batch([[0, 1, 2], [0, 1, 2], [], []]), [
    "hello moon", "hello moon", "", "",
  ])
}

///|
test "encode_with_byte_offsets converts unicode char offsets" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"我":0,"🙂":1,"a":2,"[UNK]":3},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode_with_byte_offsets("我 🙂 a", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["我", "🙂", "a"])
  @test.assert_eq(enc.offsets, [(0, 3), (4, 8), (9, 10)])
  @test.assert_eq(enc.sequence_ids(), [Some(0), Some(0), Some(0)])
  @test.assert_eq(enc.word_ids(), [Some(0), Some(1), Some(2)])
  @test.assert_eq(enc.word_to_tokens(1), Some((1, 2)))
  @test.assert_eq(enc.word_to_chars(1), Some((4, 8)))
  @test.assert_eq(enc.char_to_word(5), Some(1))
}

///|
test "encode_pair tracks sequence ids separate from type ids" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"我":2,"b":3,"[UNK]":4},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","cls":["[CLS]",0],"sep":["[SEP]",1]}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode_pair_with_byte_offsets(
    "我",
    "b",
    add_special_tokens=true,
  )
  @test.assert_eq(enc.tokens, ["[CLS]", "我", "[SEP]", "b", "[SEP]"])
  @test.assert_eq(enc.offsets, [(0, 0), (0, 3), (0, 0), (0, 1), (0, 0)])
  @test.assert_eq(enc.sequence_ids(), [None, Some(0), None, Some(1), None])
  @test.assert_eq(enc.type_ids, [0, 0, 0, 1, 1])
  @test.assert_eq(enc.token_to_sequence(0), None)
  @test.assert_eq(enc.token_to_chars(1), Some((0, (0, 3))))
  @test.assert_eq(enc.token_to_chars(3), Some((1, (0, 1))))
  @test.assert_eq(enc.char_to_token(1, sequence_id=0), Some(1))
  @test.assert_eq(enc.char_to_token(0, sequence_id=1), Some(3))
  @test.assert_eq(enc.char_to_token(3, sequence_id=0), None)
  @test.assert_eq(enc.word_ids(), [None, Some(0), None, Some(0), None])
  @test.assert_eq(enc.token_to_word(1), Some((0, 0)))
  @test.assert_eq(enc.token_to_word(3), Some((1, 0)))
  @test.assert_eq(enc.word_to_tokens(0, sequence_id=1), Some((3, 4)))
  @test.assert_eq(enc.word_to_chars(0, sequence_id=1), Some((0, 1)))
  @test.assert_eq(enc.char_to_word(0, sequence_id=1), Some(0))
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
test "from_str rejects unsupported Split regex" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"Split","pattern":{"Regex":"\\p{L}{2,4}(?=x)"},"behavior":"Isolated","invert":false},
    #| "model":{"type":"WordLevel","vocab":{"[UNK]":0},"unk_token":"[UNK]"}}
  let mut raised = false
  try Tokenizer::from_str(json) |> ignore catch {
    @types.UnsupportedComponent(_) => raised = true
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

///|
test "to_json round-trips loaded tokenizer behavior" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":4,"content":"[SPECIAL]","special":true}],
    #| "normalizer":{"type":"Lowercase"},
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"[UNK]":2,"[PAD]":3,"[SPECIAL]":4},"unk_token":"[UNK]"},
    #| "truncation":{"direction":"Right","max_length":3,"stride":0,"strategy":"LongestFirst"},
    #| "padding":{"strategy":"Fixed","length":5,"direction":"Right","pad_id":3,"pad_type_id":0,"pad_token":"[PAD]"}}
  let tok = Tokenizer::from_str(json)
  let out = tok.to_json()
  @test.assert_eq(out, json)
  let tok2 = Tokenizer::from_str(out)
  let enc1 = tok.encode("HELLO moon extra [SPECIAL]", add_special_tokens=false)
  let enc2 = tok2.encode("HELLO moon extra [SPECIAL]", add_special_tokens=false)
  @test.assert_eq(enc2.ids, enc1.ids)
  @test.assert_eq(enc2.tokens, enc1.tokens)
  @test.assert_eq(enc2.attention_mask, enc1.attention_mask)
}

///|
test "save and Tokenizer::from_file preserve tokenizer behavior" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let path = "_build/tokenizer_save_roundtrip.json"
  tok.save(path)
  let loaded = Tokenizer::from_file(path)
  @test.assert_eq(loaded.to_json(), json)
  @test.assert_eq(
    loaded.encode("hello moon", add_special_tokens=false).ids,
    tok.encode("hello moon", add_special_tokens=false).ids,
  )
}

///|
test "from_pretrained loads local directory or tokenizer file" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"local":0,"dir":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let path = "_build/tokenizer.json"
  tok.save(path)
  let from_dir = Tokenizer::from_pretrained("_build")
  let from_file = Tokenizer::from_pretrained(path)
  @test.assert_eq(from_dir.encode("local dir", add_special_tokens=false).ids, [
    0, 1,
  ])
  @test.assert_eq(from_file.encode("local dir", add_special_tokens=false).ids, [
    0, 1,
  ])
}

///|
test "save invalidates from_pretrained source cache" {
  let path = "_build/tokenizer_cache_invalidation.json"
  let json1 =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"old":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let json2 =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"new":0,"[UNK]":1},"unk_token":"[UNK]"}}
  Tokenizer::from_str(json1).save(path)
  let old_tok = Tokenizer::from_pretrained(path)
  @test.assert_eq(old_tok.encode("old", add_special_tokens=false).ids, [0])
  Tokenizer::from_str(json2).save(path)
  let new_tok = Tokenizer::from_pretrained(path)
  @test.assert_eq(new_tok.encode("new", add_special_tokens=false).ids, [0])
}

///|
test "encode_batch reuses duplicate inputs without aliasing encodings" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"[PAD]":2,"[UNK]":3},"unk_token":"[UNK]"},
    #| "padding":{"strategy":"BatchLongest","direction":"Right","pad_id":2,"pad_type_id":0,"pad_token":"[PAD]"}}
  let tok = Tokenizer::from_str(json)
  let batch = tok.encode_batch(
    ["hello", "hello moon", "hello"],
    add_special_tokens=false,
  )
  @test.assert_eq(batch[0].ids, [0, 2])
  @test.assert_eq(batch[1].ids, [0, 1])
  @test.assert_eq(batch[2].ids, [0, 2])
  @test.assert_eq(batch[0].attention_mask, [1, 0])
  @test.assert_eq(batch[2].attention_mask, [1, 0])
}

///|
test "train_wordlevel builds deterministic tokenizer" {
  let tok = Tokenizer::train_wordlevel(
    ["hello moon", "hello tokenizer", "rare"],
    unk_token="[UNK]",
    min_frequency=2,
    special_tokens=["[PAD]"],
  )
  @test.assert_eq(tok.token_to_id("[PAD]"), Some(0))
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(1))
  @test.assert_eq(tok.token_to_id("hello"), Some(2))
  @test.assert_eq(tok.token_to_id("moon"), None)
  let enc = tok.encode("hello moon", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["hello", "[UNK]"])
  @test.assert_eq(enc.ids, [2, 1])
  @test.assert_eq(tok.decode(enc.ids, skip_special_tokens=false), "hello[UNK]")
}

///|
test "train_wordlevel orders tokens like HF by frequency then token" {
  let tok = Tokenizer::train_wordlevel(
    ["b a a c c c d", "b b a"],
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
  )
  @test.assert_eq(tok.token_to_id("[PAD]"), Some(0))
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(1))
  @test.assert_eq(tok.token_to_id("a"), Some(2))
  @test.assert_eq(tok.token_to_id("b"), Some(3))
  @test.assert_eq(tok.token_to_id("c"), Some(4))
  @test.assert_eq(tok.token_to_id("d"), Some(5))
}

///|
test "train_wordlevel supports custom pretokenizer" {
  let pt = @pretokenizer.PreTokenizer::split(
    ",",
    @pretokenizer.SplitBehavior::removed(),
    false,
    false,
  )
  let tok = Tokenizer::train_wordlevel_with_pretokenizer(
    ["hello,world", "hello"],
    pt,
    unk_token="[UNK]",
  )
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(0))
  @test.assert_eq(tok.token_to_id("hello"), Some(1))
  @test.assert_eq(tok.token_to_id("world"), Some(2))
  let enc = tok.encode("hello,missing", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["hello", "[UNK]"])
  @test.assert_eq(enc.ids, [1, 0])

  let loaded = Tokenizer::from_str(tok.to_json())
  @test.assert_eq(
    loaded.encode("world,missing", add_special_tokens=false).ids,
    [2, 0],
  )
}

///|
test "train_wordlevel_from_tokens preserves pretokenized stream order" {
  let tok = Tokenizer::train_wordlevel_from_tokens(
    [["hello", ",", "world"], ["hello"]],
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
  )
  @test.assert_eq(tok.token_to_id("[PAD]"), Some(0))
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(1))
  @test.assert_eq(tok.token_to_id("hello"), Some(2))
  @test.assert_eq(tok.token_to_id(","), Some(3))
  @test.assert_eq(tok.token_to_id("world"), Some(4))
}

///|
test "train_wordlevel respects vocab_size cap for corpus tokens" {
  let tok = Tokenizer::train_wordlevel(
    ["alpha beta gamma alpha"],
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
    vocab_size=Some(4),
  )
  @test.assert_eq(tok.get_vocab_size(), 4)
  @test.assert_eq(tok.token_to_id("[PAD]"), Some(0))
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(1))
  @test.assert_eq(tok.token_to_id("alpha"), Some(2))
  @test.assert_eq(tok.token_to_id("beta"), Some(3))
  @test.assert_eq(tok.token_to_id("gamma"), None)
  @test.assert_eq(tok.encode("alpha gamma", add_special_tokens=false).ids, [
    2, 1,
  ])
}

///|
test "trained wordlevel tokenizer can save and reload" {
  let tok = Tokenizer::train_wordlevel(
    ["hello moon", "hello tokenizer"],
    unk_token="<unk>",
    special_tokens=["<pad>"],
  )
  let json = tok.to_json()
  let loaded = Tokenizer::from_str(json)
  @test.assert_eq(loaded.token_to_id("<pad>"), Some(0))
  @test.assert_eq(loaded.token_to_id("<unk>"), Some(1))
  @test.assert_eq(
    loaded.encode("hello missing", add_special_tokens=false).ids,
    [2, 1],
  )
  let path = "_build/trained_wordlevel_tokenizer.json"
  tok.save(path)
  let from_file = Tokenizer::from_file(path)
  @test.assert_eq(
    from_file.encode("moon missing", add_special_tokens=false).ids,
    [3, 1],
  )
}

///|
test "train_wordpiece builds alphabet and whole-word tokens" {
  let tok = Tokenizer::train_wordpiece(
    ["hello hell", "hello helper"],
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
  )
  @test.assert_eq(tok.token_to_id("[PAD]"), Some(0))
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(1))
  assert_true(tok.token_to_id("h") is Some(_))
  assert_true(tok.token_to_id("##e") is Some(_))
  assert_true(tok.token_to_id("hello") is Some(_))
  let enc = tok.encode("hello help", add_special_tokens=false)
  @test.assert_eq(enc.tokens[0], "hello")
  @test.assert_eq(enc.tokens[1], "h")
  @test.assert_eq(enc.tokens[2], "##e")
  @test.assert_eq(enc.tokens[3], "##l")
  @test.assert_eq(enc.tokens[4], "##p")
}

///|
test "train_wordpiece supports custom pretokenizer and to_json reload" {
  let pt = @pretokenizer.PreTokenizer::split(
    ",",
    @pretokenizer.SplitBehavior::removed(),
    false,
    false,
  )
  let tok = Tokenizer::train_wordpiece_with_pretokenizer(
    ["moon,bit", "moon"],
    pt,
    unk_token="[UNK]",
    continuing_subword_prefix="@@",
    special_tokens=["[PAD]"],
  )
  assert_true(tok.token_to_id("moon") is Some(_))
  assert_true(tok.token_to_id("@@o") is Some(_))
  let loaded = Tokenizer::from_str(tok.to_json())
  @test.assert_eq(loaded.encode("moon,bit", add_special_tokens=false).tokens, [
    "moon", "bit",
  ])
}

///|
test "train_wordpiece respects vocab_size cap" {
  let tok = Tokenizer::train_wordpiece(
    ["ab ac"],
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
    vocab_size=Some(4),
  )
  @test.assert_eq(tok.get_vocab_size(), 4)
  @test.assert_eq(tok.token_to_id("[PAD]"), Some(0))
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(1))
  @test.assert_eq(tok.token_to_id("a"), Some(2))
}

///|
test "train_bpe learns frequent merges" {
  let tok = Tokenizer::train_bpe(
    ["lower lower low", "lower"],
    unk_token=Some("[UNK]"),
    special_tokens=["[PAD]"],
    min_frequency=2,
  )
  @test.assert_eq(tok.token_to_id("[PAD]"), Some(0))
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(1))
  assert_true(tok.token_to_id("lower") is Some(_))
  let enc = tok.encode("lower low", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["lower", "low"])
}

///|
test "train_bpe supports custom pretokenizer and reload" {
  let pt = @pretokenizer.PreTokenizer::split(
    ",",
    @pretokenizer.SplitBehavior::removed(),
    false,
    false,
  )
  let tok = Tokenizer::train_bpe_with_pretokenizer(
    ["moon,moon,bit"],
    pt,
    unk_token=Some("[UNK]"),
    special_tokens=["[PAD]"],
    min_frequency=1,
  )
  let loaded = Tokenizer::from_str(tok.to_json())
  @test.assert_eq(loaded.encode("moon,bit", add_special_tokens=false).tokens, [
    "moon", "bit",
  ])
}

///|
test "train_bpe respects vocab_size cap" {
  let tok = Tokenizer::train_bpe(
    ["lower lower"],
    unk_token=Some("[UNK]"),
    special_tokens=["[PAD]"],
    vocab_size=Some(4),
    min_frequency=1,
  )
  @test.assert_eq(tok.get_vocab_size(), 4)
  @test.assert_eq(tok.token_to_id("[PAD]"), Some(0))
  @test.assert_eq(tok.token_to_id("[UNK]"), Some(1))
  @test.assert_eq(tok.token_to_id("lower"), None)
}

///|
test "train_unigram prefers learned whole words" {
  let tok = Tokenizer::train_unigram(["hello hello help"], unk_token="<unk>", special_tokens=[
    "<pad>",
  ])
  @test.assert_eq(tok.token_to_id("<pad>"), Some(0))
  @test.assert_eq(tok.token_to_id("<unk>"), Some(1))
  assert_true(tok.token_to_id("hello") is Some(_))
  let enc = tok.encode("hello help", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["hello", "help"])
}

///|
test "train_unigram supports custom pretokenizer and reload" {
  let pt = @pretokenizer.PreTokenizer::split(
    ",",
    @pretokenizer.SplitBehavior::removed(),
    false,
    false,
  )
  let tok = Tokenizer::train_unigram_with_pretokenizer(
    ["moon,moon,bit"],
    pt,
    unk_token="<unk>",
    special_tokens=["<pad>"],
  )
  let loaded = Tokenizer::from_str(tok.to_json())
  @test.assert_eq(loaded.encode("moon,bit", add_special_tokens=false).tokens, [
    "moon", "bit",
  ])
}

///|
test "train_unigram respects vocab_size cap" {
  let tok = Tokenizer::train_unigram(
    ["ab ac"],
    unk_token="<unk>",
    special_tokens=["<pad>"],
    vocab_size=Some(4),
  )
  @test.assert_eq(tok.get_vocab_size(), 4)
  @test.assert_eq(tok.token_to_id("<pad>"), Some(0))
  @test.assert_eq(tok.token_to_id("<unk>"), Some(1))
  @test.assert_eq(tok.token_to_id("ab"), None)
}
