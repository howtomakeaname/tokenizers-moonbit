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
test "from_str parse cache returns fresh tokenizer state" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"[PAD]":2,"[UNK]":3},"unk_token":"[UNK]"}}
  let first = Tokenizer::from_str(json).with_padding(
    Some(PaddingParams::new(Fixed(4), pad_id=2, pad_token="[PAD]")),
  )
  @test.assert_eq(first.encode("hello", add_special_tokens=false).ids, [
    0, 2, 2, 2,
  ])
  let second = Tokenizer::from_str(json)
  @test.assert_eq(second.encode("hello", add_special_tokens=false).ids, [0])
  @test.assert_eq(second.encode("moon", add_special_tokens=false).ids, [1])
}

///|
test "from_str parse cache keeps several tokenizer jsons hot" {
  let json1 =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"one":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let json2 =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"two":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let a1 = Tokenizer::from_str(json1).with_padding(
    Some(PaddingParams::new(Fixed(2), pad_id=1, pad_token="[UNK]")),
  )
  let b = Tokenizer::from_str(json2)
  let a2 = Tokenizer::from_str(json1)
  @test.assert_eq(a1.encode("one", add_special_tokens=false).ids, [0, 1])
  @test.assert_eq(b.encode("two", add_special_tokens=false).ids, [0])
  @test.assert_eq(a2.encode("one", add_special_tokens=false).ids, [0])
  @test.assert_eq(a2.encode("two", add_special_tokens=false).ids, [1])
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
test "Encoding exposes HF-style getter accessors" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"[PAD]":2,"[UNK]":3},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json).with_padding(
    Some(PaddingParams::fixed(4, pad_id=2, pad_token="[PAD]")),
  )
  let enc = tok.encode("hello moon", add_special_tokens=false)
  @test.assert_eq(enc.get_ids(), [0, 1, 2, 2])
  @test.assert_eq(enc.get_type_ids(), [0, 0, 0, 0])
  @test.assert_eq(enc.get_tokens(), ["hello", "moon", "[PAD]", "[PAD]"])
  @test.assert_eq(enc.get_offsets(), [(0, 5), (6, 10), (0, 0), (0, 0)])
  @test.assert_eq(enc.get_special_tokens_mask(), [0, 0, 1, 1])
  @test.assert_eq(enc.get_attention_mask(), [1, 1, 0, 0])
  @test.assert_eq(enc.get_overflowing().length(), 0)
  @test.assert_eq(enc.get_sequence_ids(), [Some(0), Some(0), None, None])
  @test.assert_eq(enc.get_word_ids(), [Some(0), Some(1), None, None])
  @test.assert_eq(enc.sequence_ids(), [Some(0), Some(0), None, None])
  @test.assert_eq(enc.word_ids(), [Some(0), Some(1), None, None])
  @test.assert_eq(enc.len(), 4)
  @test.assert_eq(enc.is_empty(), false)
  @test.assert_eq(enc.n_sequences(), 1)
  @test.assert_eq(@types.Encoding::empty().is_empty(), true)
  @test.assert_eq(@types.Encoding::empty().n_sequences(), 0)
}

///|
test "programmatic builder APIs attach pipeline components" {
  let model = @model.Model::train_wordlevel_from_tokens(
    [["hello", "moon"], ["world"]],
    unk_token="[UNK]",
  )
  let tok = Tokenizer::new(model)
    .with_pre_tokenizer(Some(@pretokenizer.PreTokenizer::whitespace_split()))
    .with_decoder(Some(@decoder.Decoder::wordpiece(prefix="", cleanup=false)))
  let enc = tok.encode("hello moon", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["hello", "moon"])
  @test.assert_eq(tok.decode(enc.ids, skip_special_tokens=false), "hellomoon")
  @test.assert_eq(tok.get_pre_tokenizer() is Some(_), true)
  @test.assert_eq(tok.get_decoder() is Some(_), true)
  @test.assert_eq(tok.get_normalizer() is None, true)
  @test.assert_eq(tok.get_post_processor() is None, true)
  @test.assert_eq(tok.get_truncation() is None, true)
  @test.assert_eq(tok.get_padding() is None, true)
  @test.assert_eq(tok.get_model().vocab_size(), 4)

  let replacement = @model.Model::train_wordlevel_from_tokens(
    [["hello", "world"], ["[UNK]"]],
    unk_token="[UNK]",
  )
  let with_model = tok.with_model(replacement)
  @test.assert_eq(
    with_model.encode("hello moon", add_special_tokens=false).tokens,
    ["hello", "[UNK]"],
  )
}

///|
test "add_tokens and add_special_tokens extend the added vocabulary" {
  let model = @model.Model::train_wordlevel_from_tokens(
    [["hello", "moon"], ["[CLS]", "[SEP]"]],
    unk_token="[UNK]",
  )
  let base = Tokenizer::new(model)
    .with_pre_tokenizer(Some(@pretokenizer.PreTokenizer::whitespace_split()))
    .with_post_processor(
      Some(@processor.PostProcessor::bert(("[SEP]", 4), ("[CLS]", 3))),
    )
  let (tok, added_count) = base.add_tokens_with_count([
    AddedToken::new("<tag>").with_single_word(true),
    AddedToken::new("hello"),
  ])
  @test.assert_eq(added_count, 1)
  @test.assert_eq(tok.token_to_id("<tag>"), Some(5))
  @test.assert_eq(tok.get_vocab_size(with_added_tokens=true), 6)
  @test.assert_eq(tok.get_vocab_size(with_added_tokens=false), 5)
  let enc = tok.encode("hello <tag> moon", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["hello", "<tag>", "moon"])
  @test.assert_eq(enc.ids, [
    tok.token_to_id("hello").unwrap(),
    5,
    tok.token_to_id("moon").unwrap(),
  ])
  let embedded = tok.encode("hello<tag> moon", add_special_tokens=false)
  @test.assert_eq(embedded.tokens, ["hello", "[UNK]", "moon"])

  let (tok, special_count) = tok.add_special_tokens_with_count([
    AddedToken::new("[MASK]").with_lstrip(true).with_rstrip(true),
    AddedToken::new("[CLS]"),
  ])
  @test.assert_eq(special_count, 1)
  @test.assert_eq(tok.token_to_id("[MASK]"), Some(6))
  @test.assert_eq(tok.token_to_id("[CLS]") is Some(_), true)
  let special = tok.encode("hello [MASK] moon", add_special_tokens=false)
  @test.assert_eq(special.tokens, ["hello", "[MASK]", "moon"])
  @test.assert_eq(special.special_tokens_mask, [0, 1, 0])
  let processed = tok.encode("hello", add_special_tokens=true)
  @test.assert_eq(processed.tokens, ["[CLS]", "hello", "[SEP]"])
  @test.assert_eq(processed.sequence_ids(), [None, Some(0), None])
}

///|
test "special token encode switch and added-token introspection match HF" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":3,"content":"[MASK]","special":true,"normalized":false}],
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"[MASK]":1,"[UNK]":2},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","sep":["[SEP]",4],"cls":["[CLS]",5]}}
  let tok = Tokenizer::from_str(json)
  @test.assert_eq(tok.get_encode_special_tokens(), false)
  @test.assert_eq(tok.is_special_token("[MASK]"), true)
  @test.assert_eq(tok.is_special_token("hello"), false)
  @test.assert_eq(tok.get_added_tokens_decoder().get(3).unwrap().content, "[MASK]")
  @test.assert_eq(tok.num_special_tokens_to_add(), 2)
  @test.assert_eq(tok.num_special_tokens_to_add(is_pair=true), 3)
  let extracted = tok.encode("hello [MASK]", add_special_tokens=false)
  @test.assert_eq(extracted.tokens, ["hello", "[MASK]"])
  @test.assert_eq(extracted.special_tokens_mask, [0, 1])

  let plain = tok.set_encode_special_tokens(true)
  @test.assert_eq(plain.get_encode_special_tokens(), true)
  let encoded_plain = plain.encode("hello [MASK]", add_special_tokens=false)
  @test.assert_eq(encoded_plain.tokens, ["hello", "[MASK]"])
  @test.assert_eq(encoded_plain.special_tokens_mask, [0, 0])
  let roundtrip = Tokenizer::from_str(plain.to_json())
  @test.assert_eq(roundtrip.get_encode_special_tokens(), true)
}

///|
test "post_process applies or skips configured post processor" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"world":1,"[SEP]":2,"[CLS]":3,"[UNK]":4},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","sep":["[SEP]",2],"cls":["[CLS]",3]}}
  let tok = Tokenizer::from_str(json)
  let a = tok.encode("hello", add_special_tokens=false)
  let b = tok.encode("world", add_special_tokens=false)
  let single = tok.post_process(a, add_special_tokens=true)
  @test.assert_eq(single.tokens, ["[CLS]", "hello", "[SEP]"])
  @test.assert_eq(single.sequence_ids(), [None, Some(0), None])
  let pair = tok.post_process(a, pair=Some(b), add_special_tokens=true)
  @test.assert_eq(pair.tokens, ["[CLS]", "hello", "[SEP]", "world", "[SEP]"])
  @test.assert_eq(pair.sequence_ids(), [None, Some(0), None, Some(1), None])
  let plain = tok.post_process(a, pair=Some(b), add_special_tokens=false)
  @test.assert_eq(plain.tokens, ["hello", "world"])
  @test.assert_eq(plain.sequence_ids(), [Some(0), Some(1)])
}

///|
test "post_process applies truncation and fixed padding like HF" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"b":1,"c":2,"d":3,"[SEP]":4,"[CLS]":5,"[PAD]":6,"[UNK]":7},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","sep":["[SEP]",4],"cls":["[CLS]",5]},
    #| "truncation":{"max_length":5,"strategy":"LongestFirst","stride":0,"direction":"Right"},
    #| "padding":{"strategy":{"Fixed":7},"direction":"Right","pad_id":6,"pad_type_id":0,"pad_token":"[PAD]"}}
  let tok = Tokenizer::from_str(json)
  let raw = tok.encode("a b c d", add_special_tokens=false)
  let processed = tok.post_process(raw, add_special_tokens=true)
  @test.assert_eq(processed.tokens, [
    "[CLS]", "a", "b", "c", "[SEP]", "[PAD]", "[PAD]",
  ])
  @test.assert_eq(processed.attention_mask, [1, 1, 1, 1, 1, 0, 0])
}

///|
test "Encoding public manipulation APIs mirror HF style" {
  let base = @types.Encoding::from_tokens([
    { id: 1, value: "he", offsets: (0, 2) },
    { id: 2, value: "llo", offsets: (2, 5) },
    { id: 3, value: "!", offsets: (5, 6) },
  ])
  @test.assert_eq(base.ids, [1, 2, 3])
  @test.assert_eq(base.word_ids(), [Some(0), Some(1), Some(2)])
  let typed = base.with_type_ids([7, 7, 7]).with_sequence_id(2)
  @test.assert_eq(typed.type_ids, [7, 7, 7])
  @test.assert_eq(typed.sequence_ids(), [Some(2), Some(2), Some(2)])
  let truncated = typed.truncate(2, stride=1, direction=@types.Right)
  @test.assert_eq(truncated.ids, [1, 2])
  @test.assert_eq(truncated.get_overflowing().length(), 1)
  @test.assert_eq(truncated.get_overflowing()[0].ids, [2, 3])
  let padded = truncated.pad(4, pad_id=0, pad_type_id=9, pad_token="[PAD]", direction=@types.Left)
  @test.assert_eq(padded.ids, [0, 0, 1, 2])
  @test.assert_eq(padded.attention_mask, [0, 0, 1, 1])
  let merged = @types.Encoding::merge([
    @types.Encoding::from_tokens([{ id: 10, value: "ab", offsets: (0, 2) }]),
    @types.Encoding::from_tokens([{ id: 11, value: "cd", offsets: (0, 2) }]),
  ], growing_offsets=true)
  @test.assert_eq(merged.ids, [10, 11])
  @test.assert_eq(merged.offsets, [(0, 2), (2, 4)])
  let (without_overflow, overflow) = truncated.take_overflowing()
  @test.assert_eq(without_overflow.get_overflowing().length(), 0)
  @test.assert_eq(overflow.length(), 1)
}

///|
test "template string constructor supports multi-id special token counting" {
  let specials : Map[String, @processor.SpecialToken] = {}
  specials["<pair>"] = @processor.SpecialToken::new(
    "<pair>",
    [8, 9],
    ["<p0>", "<p1>"],
  )
  let pp = @processor.PostProcessor::template_from_strings(
    "$A <pair>",
    "$A <pair> $B:1",
    specials,
  )
  @test.assert_eq(pp.added_tokens(), 2)
  @test.assert_eq(pp.added_tokens(pair=true), 2)
}

///|
test "programmatic tokenizer serializes typed components for roundtrip" {
  let model = @model.Model::train_wordlevel_from_tokens(
    [["hello", "moon", "[CLS]", "[SEP]", "[PAD]"]],
    unk_token="[UNK]",
  )
  let normalizer = @normalizer.Normalizer::from_json(
    @json.parse(
      (
        #|{"type":"Lowercase"}
      ),
    ),
  )
  let tok = Tokenizer::new(model)
    .with_normalizer(Some(normalizer))
    .with_pre_tokenizer(Some(@pretokenizer.PreTokenizer::whitespace_split()))
    .with_post_processor(
      Some(@processor.PostProcessor::bert(("[SEP]", 4), ("[CLS]", 3))),
    )
    .with_decoder(Some(@decoder.Decoder::wordpiece(prefix="", cleanup=false)))
    .with_truncation(Some(TruncationParams::new(4)))
    .with_padding(Some(PaddingParams::fixed(6, pad_id=5, pad_token="[PAD]")))
    .add_special_token_strings(["[MASK]"])
  let json = tok.to_json()
  @test.assert_eq(json.contains("\"normalizer\""), true)
  @test.assert_eq(json.contains("\"post_processor\""), true)
  @test.assert_eq(json.contains("\"decoder\""), true)
  @test.assert_eq(json.contains("\"truncation\""), true)
  @test.assert_eq(json.contains("\"padding\""), true)
  let roundtrip = Tokenizer::from_str(json)
  let enc = roundtrip.encode("HELLO moon", add_special_tokens=true)
  @test.assert_eq(enc.tokens, [
    "[CLS]", "hello", "moon", "[SEP]", "[PAD]", "[PAD]",
  ])
  @test.assert_eq(enc.attention_mask, [1, 1, 1, 1, 0, 0])
  let raw = [
    roundtrip.token_to_id("hello").unwrap(),
    roundtrip.token_to_id("moon").unwrap(),
  ]
  @test.assert_eq(roundtrip.decode(raw, skip_special_tokens=false), "hellomoon")
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
test "decode_stream emits chunks matching full decode" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0," ":1,"moon":2},"unk_token":"hello"}}
  let tok = Tokenizer::from_str(json)
  let ids = [0, 1, 2]
  let mut stream = tok.decode_stream(skip_special_tokens=false)
  let sb = StringBuilder::new()
  for id in ids {
    let (next, chunk) = stream.step(id)
    stream = next
    match chunk {
      Some(text) => sb.write_string(text)
      None => ()
    }
  }
  @test.assert_eq(sb.to_string(), tok.decode(ids, skip_special_tokens=false))
}

///|
test "decode_stream respects special-token skipping" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":1,"content":"[MASK]","special":true,"normalized":false}],
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"[MASK]":1},"unk_token":"hello"}}
  let tok = Tokenizer::from_str(json)
  let mut stream = tok.decode_stream(skip_special_tokens=true)
  let (next, first) = stream.step(1)
  stream = next
  @test.assert_eq(first, None)
  let (_, second) = stream.step(0)
  @test.assert_eq(second, Some("hello"))
}

///|
test "decode_stream buffers incomplete byte fallback sequences" {
  let json =
    #|{"version":"1.0",
    #| "model":{"type":"WordLevel","vocab":{"<0xC3>":0,"<0xA9>":1,"[UNK]":2},"unk_token":"[UNK]"},
    #| "decoder":{"type":"ByteFallback"}}
  let tok = Tokenizer::from_str(json)
  let mut stream = tok.decode_stream(skip_special_tokens=false)
  let (next, first) = stream.step(0)
  stream = next
  @test.assert_eq(first, None)
  let (_, second) = stream.step(1)
  @test.assert_eq(second, Some("é"))
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
test "encode_pretokenized skips pretokenizer but keeps normalizer and word ids" {
  let json =
    #|{"version":"1.0",
    #| "normalizer":{"type":"Lowercase"},
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"我":2,"[UNK]":3},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode_pretokenized(
    ["Hello Moon", "我"],
    add_special_tokens=false,
  )
  @test.assert_eq(enc.tokens, ["[UNK]", "我"])
  @test.assert_eq(enc.ids, [3, 2])
  @test.assert_eq(enc.offsets, [(0, 10), (11, 12)])
  @test.assert_eq(enc.word_ids(), [Some(0), Some(1)])
  @test.assert_eq(enc.word_to_tokens(1), Some((1, 2)))
}

///|
test "encode_pretokenized byte offsets and batch padding" {
  let json =
    #|{"version":"1.0",
    #| "padding":{"strategy":"BatchLongest","direction":"Right","pad_id":4,"pad_type_id":0,"pad_token":"[PAD]"},
    #| "model":{"type":"WordLevel","vocab":{"我":0,"🙂":1,"a":2,"[UNK]":3,"[PAD]":4},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let one = tok.encode_pretokenized_with_byte_offsets(
    ["我", "🙂", "a"],
    add_special_tokens=false,
  )
  @test.assert_eq(one.tokens, ["我", "🙂", "a"])
  @test.assert_eq(one.offsets, [(0, 3), (4, 8), (9, 10)])
  let encs = tok.encode_pretokenized_batch_with_byte_offsets(
    [["我", "🙂", "a"], ["🙂"]],
    add_special_tokens=false,
  )
  @test.assert_eq(encs.length(), 2)
  @test.assert_eq(encs[0].tokens, ["我", "🙂", "a"])
  @test.assert_eq(encs[1].tokens, ["🙂", "[PAD]", "[PAD]"])
  @test.assert_eq(encs[1].offsets, [(0, 4), (0, 0), (0, 0)])
  @test.assert_eq(encs[1].attention_mask, [1, 0, 0])
  @test.assert_eq(encs[1].word_ids(), [Some(0), None, None])
}

///|
test "encode_pretokenized_pair_batch tracks sequence ids and padding" {
  let json =
    #|{"version":"1.0",
    #| "padding":{"strategy":"BatchLongest","direction":"Right","pad_id":5,"pad_type_id":0,"pad_token":"[PAD]"},
    #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"hello":2,"world":3,"月":4,"[PAD]":5,"[UNK]":6},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","cls":["[CLS]",0],"sep":["[SEP]",1]}}
  let tok = Tokenizer::from_str(json)
  let encs = tok.encode_pretokenized_pair_batch_with_byte_offsets(
    [(["hello"], ["world"]), (["月"], ["world", "hello"])],
    add_special_tokens=true,
  )
  @test.assert_eq(encs.length(), 2)
  @test.assert_eq(encs[0].tokens, [
    "[CLS]", "hello", "[SEP]", "world", "[SEP]", "[PAD]",
  ])
  @test.assert_eq(encs[0].sequence_ids(), [
    None,
    Some(0),
    None,
    Some(1),
    None,
    None,
  ])
  @test.assert_eq(encs[0].attention_mask, [1, 1, 1, 1, 1, 0])
  @test.assert_eq(encs[1].tokens, [
    "[CLS]", "月", "[SEP]", "world", "hello", "[SEP]",
  ])
  @test.assert_eq(encs[1].offsets, [
    (0, 0),
    (0, 3),
    (0, 0),
    (0, 5),
    (6, 11),
    (0, 0),
  ])
  @test.assert_eq(encs[1].word_ids(), [
    None,
    Some(0),
    None,
    Some(0),
    Some(1),
    None,
  ])
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
test "encode_pair_batch pads pair inputs and preserves sequence offsets" {
  let json =
    #|{"version":"1.0",
    #| "padding":{"strategy":"BatchLongest","direction":"Right","pad_id":5,"pad_type_id":0,"pad_token":"[PAD]"},
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"hello":2,"world":3,"月":4,"[PAD]":5,"[UNK]":6},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","cls":["[CLS]",0],"sep":["[SEP]",1]}}
  let tok = Tokenizer::from_str(json)
  let encs = tok.encode_pair_batch_with_byte_offsets(
    [("hello", "world"), ("月", "world hello")],
    add_special_tokens=true,
  )
  @test.assert_eq(encs.length(), 2)
  @test.assert_eq(encs[0].tokens, [
    "[CLS]", "hello", "[SEP]", "world", "[SEP]", "[PAD]",
  ])
  @test.assert_eq(encs[0].sequence_ids(), [
    None,
    Some(0),
    None,
    Some(1),
    None,
    None,
  ])
  @test.assert_eq(encs[0].attention_mask, [1, 1, 1, 1, 1, 0])
  @test.assert_eq(encs[1].tokens, [
    "[CLS]", "月", "[SEP]", "world", "hello", "[SEP]",
  ])
  @test.assert_eq(encs[1].offsets, [
    (0, 0),
    (0, 3),
    (0, 0),
    (0, 5),
    (6, 11),
    (0, 0),
  ])
  @test.assert_eq(encs[1].word_ids(), [
    None,
    Some(0),
    None,
    Some(0),
    Some(1),
    None,
  ])
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
test "WordPiece repeated words keep offsets with word cache" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordPiece","vocab":{"[UNK]":0,"token":1,"##ization":2},"unk_token":"[UNK]","continuing_subword_prefix":"##"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("tokenization tokenization", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["token", "##ization", "token", "##ization"])
  @test.assert_eq(enc.offsets, [(0, 5), (5, 12), (13, 18), (18, 25)])
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
test "from_str supports ranged Split regex quantifiers" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"Split","pattern":{"Regex":"\\d{2,4}"},"behavior":"Isolated","invert":false},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"1234":1,"567":2,"b":3,"[UNK]":4},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("a1234567b", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["a", "1234", "567", "b"])
  @test.assert_eq(enc.ids, [0, 1, 2, 3])
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
test "save_pretrained writes HF-style directory artifact" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"saved":0,"dir":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let path = tok.save_pretrained("_build/tokenizer_save_pretrained")
  @test.assert_eq(path, "_build/tokenizer_save_pretrained/tokenizer.json")
  let loaded = Tokenizer::from_pretrained("_build/tokenizer_save_pretrained")
  @test.assert_eq(loaded.to_json(), json)
  @test.assert_eq(loaded.encode("saved dir", add_special_tokens=false).ids, [
    0, 1,
  ])
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
fn ensure_dir(path : String) -> Unit {
  @fs.create_dir(path) catch {
    _ => ()
  }
}

///|
fn assert_from_pretrained_parse_error_contains(
  path : String,
  needle : String,
) -> Unit raise {
  let mut raised = false
  try Tokenizer::from_pretrained(path) |> ignore catch {
    @types.ParseError(msg) => raised = msg.contains(needle)
    _ => raised = false
  }
  assert_true(raised)
}

///|
test "from_pretrained resolves local HuggingFace hub cache snapshots" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hub":0,"cache":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let root = "_build/hf_cache_test"
  let hub = root + "/hub"
  let repo = hub + "/models--org--toy-tokenizer"
  let refs = repo + "/refs"
  let snapshots = repo + "/snapshots"
  let rev = snapshots + "/abc123"
  ensure_dir(root)
  ensure_dir(hub)
  ensure_dir(repo)
  ensure_dir(refs)
  ensure_dir(snapshots)
  ensure_dir(rev)
  @fs.write_string_to_file(refs + "/main", "abc123\n") catch {
    _ => ()
  }
  @fs.write_string_to_file(rev + "/tokenizer.json", json) catch {
    _ => ()
  }

  let explicit = Tokenizer::from_pretrained_cached(
    "org/toy-tokenizer",
    cache_dir=Some(hub),
  )
  @test.assert_eq(explicit.encode("hub cache", add_special_tokens=false).ids, [
    0, 1,
  ])

  @sys.set_env_var("HUGGINGFACE_HUB_CACHE", hub)
  let implicit = Tokenizer::from_pretrained("org/toy-tokenizer")
  @test.assert_eq(
    implicit.encode("cache missing", add_special_tokens=false).ids,
    [1, 2],
  )

  let explicit_rev = Tokenizer::from_pretrained_cached(
    "org/toy-tokenizer",
    revision="abc123",
    cache_dir=Some(hub),
  )
  @test.assert_eq(explicit_rev.encode("hub", add_special_tokens=false).ids, [0])
}

///|
test "from_pretrained reports actionable offline resolution errors" {
  ensure_dir("_build/missing_tokenizer_dir")
  assert_from_pretrained_parse_error_contains(
    "_build/not-a-tokenizer.json", "tokenizer file not found",
  )
  assert_from_pretrained_parse_error_contains(
    "_build/missing_tokenizer_dir", "directory missing tokenizer.json",
  )
  assert_from_pretrained_parse_error_contains(
    "missing-org/missing-model", "could not resolve",
  )
}

///|
test "from_pretrained source cache evicts oldest entry instead of clearing all" {
  let old_path = "_build/tokenizer_cache_fifo_old.json"
  let old_json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"old":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let new_json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"new":0,"[UNK]":1},"unk_token":"[UNK]"}}
  @fs.write_string_to_file(old_path, old_json) catch {
    _ => ()
  }
  @test.assert_eq(
    Tokenizer::from_pretrained(old_path).encode("old", add_special_tokens=false).ids,
    [0],
  )
  for i in 0..<17 {
    let p = "_build/tokenizer_cache_fifo_" + i.to_string() + ".json"
    @fs.write_string_to_file(p, new_json) catch {
      _ => ()
    }
    Tokenizer::from_pretrained(p) |> ignore
  }
  @fs.write_string_to_file(old_path, new_json) catch {
    _ => ()
  }
  @test.assert_eq(
    Tokenizer::from_pretrained(old_path).encode("new", add_special_tokens=false).ids,
    [0],
  )
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
test "from_pretrained source cache keeps multiple stable paths" {
  let path1 = "_build/tokenizer_cache_multi_1.json"
  let path2 = "_build/tokenizer_cache_multi_2.json"
  let json1 =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"one":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let json2 =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"two":0,"[UNK]":1},"unk_token":"[UNK]"}}
  Tokenizer::from_str(json1).save(path1)
  Tokenizer::from_str(json2).save(path2)
  @test.assert_eq(
    Tokenizer::from_pretrained(path1).encode("one", add_special_tokens=false).ids,
    [0],
  )
  @test.assert_eq(
    Tokenizer::from_pretrained(path2).encode("two", add_special_tokens=false).ids,
    [0],
  )
  @test.assert_eq(
    Tokenizer::from_pretrained(path1).encode("two", add_special_tokens=false).ids,
    [1],
  )
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
test "train_wordpiece supports initial and limited alphabet" {
  let tok = Tokenizer::train_wordpiece(
    ["cccc bbb aa"],
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
    min_frequency=10,
    initial_alphabet=["z"],
    limit_alphabet=Some(2),
  )
  @test.assert_eq(tok.token_to_id("z") is Some(_), true)
  @test.assert_eq(tok.token_to_id("##c") is Some(_), true)
  @test.assert_eq(tok.token_to_id("##b") is Some(_), true)
  @test.assert_eq(tok.token_to_id("a"), None)
}

///|
test "train_wordpiece alphabet controls survive custom pretokenizer reload" {
  let pt = @pretokenizer.PreTokenizer::split(
    ",",
    @pretokenizer.SplitBehavior::removed(),
    false,
    false,
  )
  let tok = Tokenizer::train_wordpiece_with_pretokenizer(
    ["moon,bit"],
    pt,
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
    min_frequency=10,
    initial_alphabet=["z"],
    limit_alphabet=Some(2),
  )
  @test.assert_eq(tok.token_to_id("z") is Some(_), true)
  let loaded = Tokenizer::from_str(tok.to_json())
  @test.assert_eq(loaded.token_to_id("z") is Some(_), true)
  @test.assert_eq(loaded.encode("z", add_special_tokens=false).tokens, ["z"])
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
test "byte_level_alphabet exposes unique 256 byte symbols" {
  let alphabet = @pretokenizer.byte_level_alphabet()
  @test.assert_eq(alphabet.length(), 256)
  let seen : Map[String, Bool] = {}
  for piece in alphabet {
    seen[piece] = true
  }
  @test.assert_eq(seen.length(), 256)
  @test.assert_eq(seen.get("A"), Some(true))
  @test.assert_eq(seen.get("!"), Some(true))
  for c in @pretokenizer.byte_level_encode_str("🙂") {
    @test.assert_eq(seen.get(@common.char_string(c)), Some(true))
  }
}

///|
test "train_bpe bytelevel initial alphabet encodes unseen bytes" {
  let tok = Tokenizer::train_bpe_with_pretokenizer(
    ["hello hello"],
    @pretokenizer.PreTokenizer::byte_level(
      add_prefix_space=false,
      use_regex=true,
    ),
    unk_token=Some("[UNK]"),
    min_frequency=2,
    special_tokens=["[PAD]"],
    initial_alphabet=@pretokenizer.byte_level_alphabet(),
  )
  let enc = tok.encode("🙂", add_special_tokens=false)
  @test.assert_eq(enc.tokens.length(), 4)
  for tok in enc.tokens {
    @test.assert_eq(tok == "[UNK]", false)
  }
}

///|
test "train_bpe passes max_token_length through tokenizer API" {
  let tok = Tokenizer::train_bpe(
    ["aaaaaaaa aaaaaaaa"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
    vocab_size=Some(32),
    max_token_length=Some(2),
  )
  @test.assert_eq(tok.token_to_id("aa") is Some(_), true)
  @test.assert_eq(tok.token_to_id("aaaa"), None)
  let enc = tok.encode("aaaaaaaa", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["aa", "aa", "aa", "aa"])
}

///|
test "train_bpe max_token_length survives to_json reload" {
  let tok = Tokenizer::train_bpe(
    ["abababab abababab"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
    vocab_size=Some(32),
    max_token_length=Some(4),
  )
  let loaded = Tokenizer::from_str(tok.to_json())
  @test.assert_eq(
    loaded.encode("abababab", add_special_tokens=false).tokens,
    tok.encode("abababab", add_special_tokens=false).tokens,
  )
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
