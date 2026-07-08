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
test "BPE dropout parses serializes disables cache and skips merges" {
  let json =
    #|{"version":"1.0",
    #| "model":{"type":"BPE","vocab":{"a":0,"b":1,"c":2,"ab":3,"abc":4},"merges":[["a","b"],["ab","c"]],"dropout":1.0}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("abc", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["a", "b", "c"])
  @test.assert_eq(enc.ids, [0, 1, 2])
  @test.assert_eq(tok.cache_size(), 0)
  @test.assert_eq(tok.to_json().contains("\"dropout\":1"), true)
  let no_dropout_json =
    #|{"version":"1.0",
    #| "model":{"type":"BPE","vocab":{"a":0,"b":1,"c":2,"ab":3,"abc":4},"merges":[["a","b"],["ab","c"]],"dropout":0.0}}
  let deterministic = Tokenizer::from_str(no_dropout_json)
  @test.assert_eq(deterministic.encode("abc", add_special_tokens=false).ids, [4])
  @test.assert_eq(deterministic.cache_size(), 1)
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
  @test.assert_eq(tok.vocab_size(with_added_tokens=false), 3)
  @test.assert_eq(tok.get_vocab(with_added_tokens=false).get("<extra>"), None)
  @test.assert_eq(tok.get_vocab().get("<extra>"), Some(3))
  @test.assert_eq(tok.vocab().get("<extra>"), Some(3))
}

///|
test "Tokenizer exposes Python property-style component and config aliases" {
  let json =
    #|{"version":"1.0",
    #| "normalizer":{"type":"Lowercase"},
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "added_tokens":[{"id":3,"content":"<extra>","special":true},{"id":4,"content":"<plain>","special":false}],
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"[PAD]":1,"[UNK]":2,"<extra>":3},"unk_token":"[UNK]"},
    #| "decoder":{"type":"WordPiece","prefix":"##","cleanup":false}}
  let tok = Tokenizer::from_str(json)
    .enable_truncation(5, stride=2, strategy=OnlyFirst, direction=Left)
    .enable_padding(
      length=Some(8),
      direction=Left,
      pad_id=1,
      pad_type_id=7,
      pad_token="[PAD]",
      pad_to_multiple_of=Some(4),
    )
    .enable_encode_special_tokens()
  guard tok.normalizer() is Some(_) else { abort("missing normalizer alias") }
  guard tok.get_normalizer() is Some(_) else {
    abort("missing normalizer getter")
  }
  guard tok.pre_tokenizer() is Some(_) else {
    abort("missing pre-tokenizer alias")
  }
  guard tok.get_pre_tokenizer() is Some(_) else {
    abort("missing pre-tokenizer getter")
  }
  @test.assert_eq(tok.model().get_vocab().get("hello"), Some(0))
  match tok.post_processor() {
    Some(_) => abort("unexpected post-processor alias")
    None => ()
  }
  match tok.get_post_processor() {
    Some(_) => abort("unexpected post-processor getter")
    None => ()
  }
  guard tok.decoder() is Some(_) else { abort("missing decoder alias") }
  guard tok.get_decoder() is Some(_) else { abort("missing decoder getter") }
  @test.assert_eq(tok.encode_special_tokens(), true)
  @test.assert_eq(tok.added_tokens_decoder().get(3).unwrap().content, "<extra>")
  @test.assert_eq(tok.get_added_tokens().map(t => t.content), [
    "<extra>", "<plain>",
  ])
  @test.assert_eq(tok.added_tokens().map(t => t.content), ["<extra>", "<plain>"])
  @test.assert_eq(tok.get_added_tokens_count(), 2)
  @test.assert_eq(tok.added_tokens_count(special_only=true), 1)
  @test.assert_eq(tok.all_special_tokens(), ["<extra>"])
  @test.assert_eq(tok.all_special_ids(), [3])
  @test.assert_eq(tok.is_special_token("<extra>"), true)
  @test.assert_eq(tok.is_special_token("<plain>"), false)
  @test.assert_eq(tok.convert_token_to_id("hello"), Some(0))
  @test.assert_eq(tok.convert_id_to_token(3), Some("<extra>"))
  @test.assert_eq(tok.convert_tokens_to_ids(["hello", "<extra>", "missing"]), [
    Some(0),
    Some(3),
    None,
  ])
  @test.assert_eq(tok.convert_ids_to_tokens([0, 3, 99]), [
    Some("hello"),
    Some("<extra>"),
    None,
  ])
  let trunc = tok.truncation().unwrap()
  @test.assert_eq(trunc.max_length(), 5)
  @test.assert_eq(trunc.get_max_length(), 5)
  @test.assert_eq(trunc.stride(), 2)
  @test.assert_eq(trunc.get_stride(), 2)
  @test.assert_eq(trunc.strategy(), OnlyFirst)
  @test.assert_eq(trunc.get_strategy(), OnlyFirst)
  @test.assert_eq(trunc.direction(), Left)
  @test.assert_eq(trunc.get_direction(), Left)
  @test.assert_eq(trunc.as_tuple(), (5, 2, Left, OnlyFirst))
  let trunc_state = trunc.__getstate__()
  @test.assert_eq(trunc_state.max_length, 5)
  @test.assert_eq(TruncationParams::__setstate__(trunc_state), trunc)
  @test.assert_eq(
    TruncationParams::from_tuple((6, 1, Right, LongestFirst)).as_tuple(),
    (6, 1, Right, LongestFirst),
  )
  let padding = tok.padding().unwrap()
  @test.assert_eq(padding.strategy(), Fixed(8))
  @test.assert_eq(padding.get_strategy(), Fixed(8))
  @test.assert_eq(padding.direction(), Left)
  @test.assert_eq(padding.get_direction(), Left)
  @test.assert_eq(padding.pad_id(), 1)
  @test.assert_eq(padding.get_pad_id(), 1)
  @test.assert_eq(padding.pad_type_id(), 7)
  @test.assert_eq(padding.get_pad_type_id(), 7)
  @test.assert_eq(padding.pad_token(), "[PAD]")
  @test.assert_eq(padding.get_pad_token(), "[PAD]")
  @test.assert_eq(padding.pad_to_multiple_of(), Some(4))
  @test.assert_eq(padding.get_pad_to_multiple_of(), Some(4))
  @test.assert_eq(padding.as_tuple(), (Fixed(8), Left, 1, 7, "[PAD]", Some(4)))
  let padding_state = padding.__getstate__()
  @test.assert_eq(padding_state.pad_id, 1)
  @test.assert_eq(PaddingParams::__setstate__(padding_state), padding)
  @test.assert_eq(
    PaddingParams::from_tuple((BatchLongest, Right, 0, 0, "<pad>", None)).as_tuple(),
    (BatchLongest, Right, 0, 0, "<pad>", None),
  )
  @test.assert_eq(tok.no_truncation().truncation(), None)
  @test.assert_eq(tok.no_padding().padding(), None)
}

///|
test "Tokenizer component hooks override normalize pretokenize and decode" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  @test.assert_eq(tok.encode("HELLO,MOON", add_special_tokens=false).ids, [2])
  let hooks = TokenizerComponentHooks::new(
    normalize=Some(hook_lowercase),
    pre_tokenize=Some(hook_comma_pre_tokenize),
    decode=Some(hook_pipe_decode),
  )
  let enc = tok.encode_with_hooks("HELLO,MOON", hooks, add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["hello", "moon"])
  @test.assert_eq(enc.ids, [0, 1])
  @test.assert_eq(enc.offsets, [(0, 5), (6, 10)])
  @test.assert_eq(enc.word_ids, [Some(0), Some(1)])
  let fast = tok.encode_with_hooks_fast(
    "HELLO,MOON",
    hooks,
    add_special_tokens=false,
  )
  @test.assert_eq(fast.ids, enc.ids)
  @test.assert_eq(fast.offsets, [(0, 0), (0, 0)])
  @test.assert_eq(tok.decode_with_hooks([0, 1], hooks), "hello|moon")
}

///|
test "Tokenizer persists component hooks on normal encode and decode paths" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let hooks = TokenizerComponentHooks::new(
    normalize=Some(hook_lowercase),
    pre_tokenize=Some(hook_comma_pre_tokenize),
    decode=Some(hook_pipe_decode),
  )
  let tok = Tokenizer::from_str(json).with_component_hooks(hooks)
  let enc = tok.encode("HELLO,MOON", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["hello", "moon"])
  @test.assert_eq(enc.ids, [0, 1])
  @test.assert_eq(enc.offsets, [(0, 5), (6, 10)])
  @test.assert_eq(
    tok.encode_fast("HELLO,MOON", add_special_tokens=false).offsets,
    [(0, 0), (0, 0)],
  )
  @test.assert_eq(tok.decode([0, 1]), "hello|moon")
  let override_hooks = TokenizerComponentHooks::new(
    normalize=Some(hook_force_moon),
  )
  @test.assert_eq(
    tok.encode_with_hooks(
      "HELLO,MOON",
      override_hooks,
      add_special_tokens=false,
    ).ids,
    [1],
  )
  let cleared = tok.clear_component_hooks()
  @test.assert_eq(cleared.encode("HELLO,MOON", add_special_tokens=false).ids, [
    2,
  ])
}

///|
fn hook_lowercase(text : String) -> String {
  text.to_lower()
}

///|
fn hook_force_moon(_text : String) -> String {
  "moon"
}

///|
fn hook_pipe_decode(tokens : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i, token in tokens {
    if i > 0 {
      sb.write_char('|')
    }
    sb.write_string(token)
  }
  sb.to_string()
}

///|
fn hook_comma_pre_tokenize(
  text : String,
  base_offset : Int,
) -> Array[@types.Split] {
  let chars = text.to_array()
  let out : Array[@types.Split] = []
  let mut start = 0
  for i, c in chars {
    if c == ',' {
      if i > start {
        out.push({
          value: hook_string_slice(chars, start, i),
          offsets: (base_offset + start, base_offset + i),
        })
      }
      start = i + 1
    }
  }
  if start < chars.length() {
    out.push({
      value: hook_string_slice(chars, start, chars.length()),
      offsets: (base_offset + start, base_offset + chars.length()),
    })
  }
  out
}

///|
fn hook_string_slice(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
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
  @test.assert_eq(enc.ids(), [0, 1, 2, 2])
  @test.assert_eq(enc.get_type_ids(), [0, 0, 0, 0])
  @test.assert_eq(enc.type_ids(), [0, 0, 0, 0])
  @test.assert_eq(enc.get_tokens(), ["hello", "moon", "[PAD]", "[PAD]"])
  @test.assert_eq(enc.tokens(), ["hello", "moon", "[PAD]", "[PAD]"])
  @test.assert_eq(enc.get_offsets(), [(0, 5), (6, 10), (0, 0), (0, 0)])
  @test.assert_eq(enc.offsets(), [(0, 5), (6, 10), (0, 0), (0, 0)])
  @test.assert_eq(enc.get_special_tokens_mask(), [0, 0, 1, 1])
  @test.assert_eq(enc.special_tokens_mask(), [0, 0, 1, 1])
  @test.assert_eq(enc.get_attention_mask(), [1, 1, 0, 0])
  @test.assert_eq(enc.attention_mask(), [1, 1, 0, 0])
  @test.assert_eq(enc.get_overflowing().length(), 0)
  @test.assert_eq(enc.overflowing().length(), 0)
  @test.assert_eq(enc.get_sequence_ids(), [Some(0), Some(0), None, None])
  @test.assert_eq(enc.get_word_ids(), [Some(0), Some(1), None, None])
  @test.assert_eq(enc.sequence_ids(), [Some(0), Some(0), None, None])
  @test.assert_eq(enc.word_ids(), [Some(0), Some(1), None, None])
  @test.assert_eq(enc.len(), 4)
  @test.assert_eq(enc.__len__(), 4)
  @test.assert_eq(enc.is_empty(), false)
  @test.assert_eq(enc.n_sequences(), 1)
  @test.assert_eq(enc.get_n_sequences(), 1)
  @test.assert_eq(enc.set_sequence_id(3).sequence_ids(), [
    Some(3),
    Some(3),
    Some(3),
    Some(3),
  ])
  @test.assert_eq(@types.Encoding::empty().is_empty(), true)
  @test.assert_eq(@types.Encoding::empty().n_sequences(), 0)
  let buffers = enc.as_buffers()
  @test.assert_eq(buffers.ids, [0, 1, 2, 2])
  let from_buffers = @types.Encoding::from_buffers(
    buffers,
    sequence_ids=enc.get_sequence_ids(),
    word_ids=enc.get_word_ids(),
  )
  @test.assert_eq(from_buffers.get_ids(), enc.get_ids())
  @test.assert_eq(from_buffers.get_attention_mask(), enc.get_attention_mask())
  let state = enc.__getstate__()
  @test.assert_eq(state.ids, [0, 1, 2, 2])
  @test.assert_eq(state.tokens, ["hello", "moon", "[PAD]", "[PAD]"])
  @test.assert_eq(
    enc.__repr__(),
    "Encoding(num_tokens=4, attributes=[ids, type_ids, tokens, offsets, attention_mask, special_tokens_mask, overflowing])",
  )
  let restored = @types.Encoding::__setstate__(state)
  @test.assert_eq(restored.get_ids(), enc.get_ids())
  @test.assert_eq(restored.get_tokens(), enc.get_tokens())
  @test.assert_eq(restored.get_word_ids(), enc.get_word_ids())
  let tuple = enc.as_tuple()
  @test.assert_eq(tuple.0, [0, 1, 2, 2])
  @test.assert_eq(tuple.2, ["hello", "moon", "[PAD]", "[PAD]"])
  @test.assert_eq(@types.Encoding::from_tuple(tuple).as_tuple(), tuple)
}

///|
test "Tokenizer exposes Python pickle-style state roundtrip" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let state = tok.__getstate__()
  @test.assert_eq(state.json, tok.to_str())
  @test.assert_eq(tok.__str__(), tok.to_str())
  @test.assert_eq(tok.__repr__(), tok.to_str())
  let restored = Tokenizer::__setstate__(state)
  @test.assert_eq(restored.to_str(), tok.to_str())
  @test.assert_eq(
    restored.encode("hello missing", add_special_tokens=false).ids,
    [0, 2],
  )
  @test.assert_eq(
    Tokenizer::from_state(tok.get_state()).to_json(),
    tok.to_json(),
  )
}

///|
test "Token exposes tuple interop helpers" {
  let tok = @types.Token::new(7, "hello", offsets=(2, 7))
  @test.assert_eq(tok.get_id(), 7)
  @test.assert_eq(tok.id(), 7)
  @test.assert_eq(tok.get_value(), "hello")
  @test.assert_eq(tok.value(), "hello")
  @test.assert_eq(tok.get_offsets(), (2, 7))
  @test.assert_eq(tok.offsets(), (2, 7))
  @test.assert_eq(tok.as_tuple(), (7, "hello", (2, 7)))
  let state = tok.__getstate__()
  @test.assert_eq(state.id, 7)
  @test.assert_eq(@types.Token::__setstate__(state).as_tuple(), tok.as_tuple())
  @test.assert_eq(
    @types.Token::from_tuple((8, "moon", (0, 4))).as_tuple(),
    (8, "moon", (0, 4)),
  )
}

///|
test "AddedToken exposes binding property aliases" {
  let tok = AddedToken::new("<tag>")
    .with_single_word(true)
    .with_lstrip(true)
    .with_rstrip(true)
    .with_normalized(false)
    .with_special(true)
  @test.assert_eq(tok.get_content(), "<tag>")
  @test.assert_eq(tok.content(), "<tag>")
  @test.assert_eq(tok.get_single_word(), true)
  @test.assert_eq(tok.single_word(), true)
  @test.assert_eq(tok.get_lstrip(), true)
  @test.assert_eq(tok.lstrip(), true)
  @test.assert_eq(tok.get_rstrip(), true)
  @test.assert_eq(tok.rstrip(), true)
  @test.assert_eq(tok.get_normalized(), false)
  @test.assert_eq(tok.normalized(), false)
  @test.assert_eq(tok.get_special(), true)
  @test.assert_eq(tok.is_special(), true)
  @test.assert_eq(tok.as_tuple(), ("<tag>", true, true, true, false, true))
  @test.assert_eq(tok.__str__(), "<tag>")
  @test.assert_eq(
    tok.__repr__(),
    "AddedToken(\"<tag>\", rstrip=True, lstrip=True, single_word=True, normalized=False, special=True)",
  )
  let state = tok.__getstate__()
  @test.assert_eq(state.content, "<tag>")
  @test.assert_eq(state.single_word, true)
  @test.assert_eq(AddedToken::__setstate__(state).as_tuple(), tok.as_tuple())
  @test.assert_eq(
    AddedToken::from_tuple(("<x>", true, false, true, false, true)).as_tuple(),
    ("<x>", true, false, true, false, true),
  )
  let special = AddedToken::special("[MASK]")
  @test.assert_eq(special.content(), "[MASK]")
  @test.assert_eq(special.normalized(), false)
  @test.assert_eq(special.is_special(), true)
  @test.assert_eq(
    AddedToken::new("a\"b\\c\n").__repr__(),
    "AddedToken(\"a\\\"b\\\\c\\n\", rstrip=False, lstrip=False, single_word=False, normalized=True, special=False)",
  )
}

///|
test "TokenizerError exposes stable binding categories" {
  let parse = @types.ParseError("bad json")
  let unsupported = @types.UnsupportedComponent("normalizer type: X")
  let vocab = @types.VocabError("bad vocab")
  @test.assert_eq(parse.kind(), @types.ParseKind)
  @test.assert_eq(unsupported.kind(), @types.UnsupportedComponentKind)
  @test.assert_eq(vocab.kind(), @types.VocabKind)
  @test.assert_eq(parse.message(), "bad json")
  @test.assert_eq(unsupported.message(), "normalizer type: X")
}

///|
test "NormalizedString and PreTokenizedString expose low level migration API" {
  let ns = NormalizedString::new(" Hello  Moon ")
    .normalize(@normalizer.Normalizer::Lowercase)
    .filter(fn(c) { c != ' ' })
    .prepend("_")
  @test.assert_eq(ns.get_original(), " Hello  Moon ")
  @test.assert_eq(ns.original(), " Hello  Moon ")
  @test.assert_eq(ns.get(), "_hellomoon")
  @test.assert_eq(ns.get_normalized(), "_hellomoon")
  @test.assert_eq(ns.normalized(), "_hellomoon")
  @test.assert_eq(ns.to_string(), "_hellomoon")
  @test.assert_eq(ns.__str__(), "_hellomoon")
  @test.assert_eq(
    ns.__repr__(),
    "NormalizedString(original=\" Hello  Moon \", normalized=\"_hellomoon\")",
  )
  @test.assert_eq(ns.len(), 10)
  @test.assert_eq(ns.__len__(), 10)
  @test.assert_eq(ns.is_empty(), false)
  @test.assert_eq(ns.get_item(0).unwrap().as_tuple(), (" Hello  Moon ", "_"))
  @test.assert_eq(ns.__getitem__(1).unwrap().as_tuple(), (" Hello  Moon ", "h"))
  @test.assert_eq(ns.get_item(-1) is None, true)
  @test.assert_eq(ns.__getitem__(10) is None, true)
  @test.assert_eq(ns.as_tuple(), (" Hello  Moon ", "_hellomoon"))
  let ns_state = ns.__getstate__()
  @test.assert_eq(ns_state.normalized, "_hellomoon")
  @test.assert_eq(
    NormalizedString::__setstate__(ns_state).as_tuple(),
    ns.as_tuple(),
  )
  @test.assert_eq(
    NormalizedString::from_tuple(("Raw", "raw")).as_tuple(),
    ("Raw", "raw"),
  )
  @test.assert_eq(
    NormalizedString::new("Line\n\"Q\"\\").lowercase().__repr__(),
    "NormalizedString(original=\"Line\\n\\\"Q\\\"\\\\\", normalized=\"line\\n\\\"q\\\"\\\\\")",
  )
  @test.assert_eq(
    NormalizedString::new("Line\n\"Q\"\\")
    .lowercase()
    .__getitem__(4)
    .unwrap()
    .__repr__(),
    "NormalizedString(original=\"Line\\n\\\"Q\\\"\\\\\", normalized=\"\\n\")",
  )
  let appended = ns.append("!").uppercase()
  @test.assert_eq(appended.get_original(), " Hello  Moon ")
  @test.assert_eq(appended.get(), "_HELLOMOON!")
  @test.assert_eq(
    NormalizedString::new("  MiXeD  ").lowercase().strip().get(),
    "mixed",
  )
  @test.assert_eq(NormalizedString::new("  left  ").lstrip().get(), "left  ")
  @test.assert_eq(NormalizedString::new("  right  ").rstrip().get(), "  right")
  @test.assert_eq(NormalizedString::new("clear").clear().get(), "")
  @test.assert_eq(NormalizedString::new("e\u{301}").nfc().get(), "é")
  @test.assert_eq(NormalizedString::new("é").nfd().get(), "e\u{301}")
  @test.assert_eq(NormalizedString::new("\u{ff21}\u{ff22}").nfkc().get(), "AB")
  @test.assert_eq(NormalizedString::new("\u{fb01}").nfkd().get(), "fi")
  @test.assert_eq(ns.slice(1, 6).get(), "hello")
  let parts = NormalizedString::new("a,b,c").split(",")
  @test.assert_eq(parts.map(p => p.get()), ["a", "b", "c"])
  let regex_parts = NormalizedString::new("a12b003").split_regex(
    @common.Regex::new("\\d+"),
  )
  @test.assert_eq(regex_parts.unwrap().map(p => p.get()), ["a", "b"])

  let model = @model.Model::train_wordlevel_from_tokens(
    [["hello", "moon", "[UNK]"]],
    unk_token="[UNK]",
  )
  let pts = PreTokenizedString::new("Hello Moon")
    .normalize(@normalizer.Normalizer::Lowercase)
    .split(@pretokenizer.PreTokenizer::whitespace_split())
  @test.assert_eq(pts.get_original(), "Hello Moon")
  @test.assert_eq(pts.original(), "Hello Moon")
  @test.assert_eq(pts.len(), 2)
  @test.assert_eq(pts.__len__(), 2)
  @test.assert_eq(pts.is_empty(), false)
  @test.assert_eq(pts.get_splits().map(s => s.value), ["hello", "moon"])
  @test.assert_eq(pts.splits().map(s => s.value), ["hello", "moon"])
  let first_split = pts.splits()[0]
  @test.assert_eq(first_split.get_value(), "hello")
  @test.assert_eq(first_split.value(), "hello")
  @test.assert_eq(first_split.get_offsets(), (0, 5))
  @test.assert_eq(first_split.offsets(), (0, 5))
  @test.assert_eq(first_split.as_tuple(), ("hello", (0, 5)))
  let split_state = first_split.__getstate__()
  @test.assert_eq(split_state.value, "hello")
  @test.assert_eq(
    @types.Split::__setstate__(split_state).as_tuple(),
    first_split.as_tuple(),
  )
  @test.assert_eq(
    @types.Split::from_tuple(("x", (2, 3))).as_tuple(),
    ("x", (2, 3)),
  )
  @test.assert_eq(@types.Split::new("y", offsets=(4, 5)).value(), "y")
  let pts_tuple = pts.as_tuple()
  @test.assert_eq(pts_tuple.0, "Hello Moon")
  @test.assert_eq(pts_tuple.1.map(s => s.value), ["hello", "moon"])
  let pts_state = pts.__getstate__()
  @test.assert_eq(pts_state.original, "Hello Moon")
  @test.assert_eq(
    PreTokenizedString::__setstate__(pts_state).as_tuple(),
    pts_tuple,
  )
  @test.assert_eq(
    PreTokenizedString::from_tuple(pts_tuple).splits().map(s => s.value),
    ["hello", "moon"],
  )
  @test.assert_eq(pts.to_encoding(model).tokens, ["hello", "moon"])
  @test.assert_eq(pts.into_encoding(model, type_id=3).type_ids, [3, 3])
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
test "Model exposes HF-style configuration getters" {
  let wordlevel = Tokenizer::from_str(
    (
      #|{"version":"1.0",
      #| "model":{"type":"WordLevel","vocab":{"[UNK]":0,"hello":1},"unk_token":"[UNK]"}}
    ),
  ).get_model()
  @test.assert_eq(wordlevel.kind(), "WordLevel")
  @test.assert_eq(wordlevel.unk_token(), Some("[UNK]"))
  @test.assert_eq(wordlevel.unk_id(), Some(0))
  @test.assert_eq(wordlevel.continuing_subword_prefix(), None)

  let wordpiece = Tokenizer::from_str(
    (
      #|{"version":"1.0",
      #| "model":{"type":"WordPiece","vocab":{"[UNK]":0,"token":1,"##s</w>":2},"unk_token":"[UNK]","continuing_subword_prefix":"##","end_of_word_suffix":"</w>","max_input_chars_per_word":42}}
    ),
  ).get_model()
  @test.assert_eq(wordpiece.kind(), "WordPiece")
  @test.assert_eq(wordpiece.unk_token(), Some("[UNK]"))
  @test.assert_eq(wordpiece.unk_id(), Some(0))
  @test.assert_eq(wordpiece.continuing_subword_prefix(), Some("##"))
  @test.assert_eq(wordpiece.end_of_word_suffix(), Some("</w>"))
  @test.assert_eq(wordpiece.max_input_chars_per_word(), Some(42))

  let bpe = Tokenizer::from_str(
    (
      #|{"version":"1.0",
      #| "model":{"type":"BPE","vocab":{"[UNK]":0,"a":1,"b":2,"ab</w>":3},"merges":[["a","b"]],"unk_token":"[UNK]","continuing_subword_prefix":"@@","end_of_word_suffix":"</w>","dropout":0.25,"byte_fallback":true,"fuse_unk":true,"ignore_merges":true}}
    ),
  ).get_model()
  @test.assert_eq(bpe.kind(), "BPE")
  @test.assert_eq(bpe.unk_token(), Some("[UNK]"))
  @test.assert_eq(bpe.unk_id(), Some(0))
  @test.assert_eq(bpe.continuing_subword_prefix(), Some("@@"))
  @test.assert_eq(bpe.end_of_word_suffix(), Some("</w>"))
  @test.assert_eq(bpe.dropout(), Some(0.25))
  @test.assert_eq(bpe.byte_fallback(), Some(true))
  @test.assert_eq(bpe.fuse_unk(), Some(true))
  @test.assert_eq(bpe.ignore_merges(), Some(true))

  let unigram = Tokenizer::from_str(
    (
      #|{"version":"1.0",
      #| "model":{"type":"Unigram","vocab":[["<unk>",0.0],["hello",-1.0]],"unk_id":0,"byte_fallback":true,"fuse_unk":false}}
    ),
  ).get_model()
  @test.assert_eq(unigram.kind(), "Unigram")
  @test.assert_eq(unigram.unk_token(), Some("<unk>"))
  @test.assert_eq(unigram.unk_id(), Some(0))
  @test.assert_eq(unigram.byte_fallback(), Some(true))
  @test.assert_eq(unigram.fuse_unk(), Some(false))
  @test.assert_eq(unigram.dropout(), None)
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
  @test.assert_eq(special.tokens, ["hello", " [MASK] ", "moon"])
  @test.assert_eq(special.special_tokens_mask, [0, 0, 0])
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
  @test.assert_eq(
    tok.get_added_tokens_decoder().get(3).unwrap().content,
    "[MASK]",
  )
  @test.assert_eq(tok.num_special_tokens_to_add(), 2)
  @test.assert_eq(tok.num_special_tokens_to_add(is_pair=true), 3)
  let extracted = tok.encode("hello [MASK]", add_special_tokens=false)
  @test.assert_eq(extracted.tokens, ["hello", "[MASK]"])
  @test.assert_eq(extracted.special_tokens_mask, [0, 0])

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
test "post_process false keeps HF processor metadata without specials" {
  let template_json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"world":1,"<s>":2,"</s>":3,"[UNK]":4},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"TemplateProcessing",
    #|   "single":"<s>:3 $A:2 </s>:3",
    #|   "pair":"<s>:3 $A:2 </s>:3 $B:4 </s>:4",
    #|   "special_tokens":{"<s>":{"id":"<s>","ids":[2],"tokens":["<s>"]},"</s>":{"id":"</s>","ids":[3],"tokens":["</s>"]}}}}
  let template_tok = Tokenizer::from_str(template_json)
  let template_a = template_tok.encode("hello", add_special_tokens=false)
  let template_b = template_tok.encode("world", add_special_tokens=false)
  let template_processed = template_tok.post_process(
    template_a,
    pair=Some(template_b),
    add_special_tokens=false,
  )
  @test.assert_eq(template_processed.tokens, ["hello", "world"])
  @test.assert_eq(template_processed.type_ids, [2, 4])
  @test.assert_eq(template_processed.special_tokens_mask, [0, 0])
  @test.assert_eq(template_processed.sequence_ids(), [Some(0), Some(1)])

  let byte_json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"\u0120":1,"\u0120b":2,"[UNK]":3},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"ByteLevel","trim_offsets":true}}
  let byte_tok = Tokenizer::from_str(byte_json)
  let byte_raw = byte_tok.encode("a  b", add_special_tokens=false)
  @test.assert_eq(byte_raw.offsets, [(0, 1), (1, 2), (2, 4)])
  let byte_processed = byte_tok.post_process(byte_raw, add_special_tokens=false)
  @test.assert_eq(byte_processed.tokens, ["a", "\u{0120}", "\u{0120}b"])
  @test.assert_eq(byte_processed.offsets, [(0, 1), (2, 2), (3, 4)])
  @test.assert_eq(byte_processed.special_tokens_mask, [0, 0, 0])

  let roberta_json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"\u0120":1,"\u0120b":2,"</s>":4,"<s>":5,"[UNK]":3},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"RobertaProcessing","sep":["</s>",4],"cls":["<s>",5],"trim_offsets":true,"add_prefix_space":false}}
  let roberta_tok = Tokenizer::from_str(roberta_json)
  let roberta_raw = roberta_tok.encode("a  b", add_special_tokens=false)
  let roberta_processed = roberta_tok.post_process(
    roberta_raw,
    add_special_tokens=false,
  )
  @test.assert_eq(roberta_processed.tokens, ["a", "\u{0120}", "\u{0120}b"])
  @test.assert_eq(roberta_processed.offsets, [(0, 1), (2, 2), (3, 4)])
  @test.assert_eq(roberta_processed.special_tokens_mask, [0, 0, 0])
  @test.assert_eq(roberta_processed.sequence_ids(), [Some(0), Some(0), Some(0)])

  let sequence_json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"\u0120":1,"\u0120b":2,"[UNK]":3,"[SEP]":4,"[CLS]":5},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"Sequence","processors":[{"type":"ByteLevel","trim_offsets":true},{"type":"BertProcessing","sep":["[SEP]",4],"cls":["[CLS]",5]}]}}
  let sequence_tok = Tokenizer::from_str(sequence_json)
  let sequence_raw = sequence_tok.encode("a  b", add_special_tokens=false)
  let sequence_processed = sequence_tok.post_process(
    sequence_raw,
    add_special_tokens=false,
  )
  @test.assert_eq(sequence_processed.tokens, ["a", "\u{0120}", "\u{0120}b"])
  @test.assert_eq(sequence_processed.offsets, [(0, 1), (2, 2), (3, 4)])
  @test.assert_eq(sequence_processed.special_tokens_mask, [0, 0, 0])
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
  @test.assert_eq(base.words(), [Some(0), Some(1), Some(2)])
  let typed = base.with_type_ids([7, 7, 7]).with_sequence_id(2)
  @test.assert_eq(typed.type_ids, [7, 7, 7])
  @test.assert_eq(typed.sequence_ids(), [Some(2), Some(2), Some(2)])
  let truncated = typed.truncate(2, stride=1, direction=@types.Right)
  @test.assert_eq(truncated.ids, [1, 2])
  @test.assert_eq(truncated.get_overflowing().length(), 1)
  @test.assert_eq(truncated.get_overflowing()[0].ids, [2, 3])
  let padded = truncated.pad(
    4,
    pad_id=0,
    pad_type_id=9,
    pad_token="[PAD]",
    direction=@types.Left,
  )
  @test.assert_eq(padded.ids, [0, 0, 1, 2])
  @test.assert_eq(padded.attention_mask, [0, 0, 1, 1])
  let merged = @types.Encoding::merge([
    @types.Encoding::from_tokens([{ id: 10, value: "ab", offsets: (0, 2) }]),
    @types.Encoding::from_tokens([{ id: 11, value: "cd", offsets: (0, 2) }]),
  ])
  @test.assert_eq(merged.ids, [10, 11])
  @test.assert_eq(merged.offsets, [(0, 2), (2, 4)])
  let merged_without_growing = @types.Encoding::merge(
    [
      @types.Encoding::from_tokens([{ id: 10, value: "ab", offsets: (0, 2) }]),
      @types.Encoding::from_tokens([{ id: 11, value: "cd", offsets: (0, 2) }]),
    ],
    growing_offsets=false,
  )
  @test.assert_eq(merged_without_growing.offsets, [(0, 2), (0, 2)])
  @test.assert_eq(
    @types.Encoding::from_tokens([{ id: 12, value: "xy", offsets: (0, 2) }]).merge_with(
      @types.Encoding::from_tokens([{ id: 13, value: "zz", offsets: (0, 2) }]),
    ).offsets,
    [(0, 2), (2, 4)],
  )
  let (without_overflow, overflow) = truncated.take_overflowing()
  @test.assert_eq(without_overflow.get_overflowing().length(), 0)
  @test.assert_eq(overflow.length(), 1)
}

///|
test "template string constructor supports multi-id special token counting" {
  let specials : Map[String, @processor.SpecialToken] = {}
  specials["<pair>"] = @processor.SpecialToken::new("<pair>", [8, 9], [
    "<p0>", "<p1>",
  ])
  let pp = @processor.PostProcessor::template_from_strings(
    "$A <pair>", "$A <pair> $B:1", specials,
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
  @test.assert_eq(tok.decode_ids([0, 1, 2]), "hello moon")
  @test.assert_eq(tok.batch_decode([[2], [0, 1, 2]]), ["moon", "hello moon"])
  @test.assert_eq(tok.decode_ids_batch([[2], [0, 1, 2]]), ["moon", "hello moon"])
  @test.assert_eq(tok.async_decode([0, 1, 2]), "hello moon")
  @test.assert_eq(tok.async_decode_batch([[2], [0, 1, 2]]), [
    "moon", "hello moon",
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
fn assert_fast_encoding_matches(
  reference : @types.Encoding,
  fast : @types.Encoding,
) -> Unit raise {
  @test.assert_eq(fast.ids, reference.ids)
  @test.assert_eq(fast.type_ids, reference.type_ids)
  @test.assert_eq(fast.tokens, reference.tokens)
  @test.assert_eq(fast.special_tokens_mask, reference.special_tokens_mask)
  @test.assert_eq(fast.attention_mask, reference.attention_mask)
  @test.assert_eq(fast.sequence_ids(), reference.sequence_ids())
  @test.assert_eq(fast.word_ids(), reference.word_ids())
  @test.assert_eq(fast.offsets, Array::make(reference.offsets.length(), (0, 0)))
  @test.assert_eq(
    fast.get_overflowing().length(),
    reference.get_overflowing().length(),
  )
  for i in 0..<reference.get_overflowing().length() {
    assert_fast_encoding_matches(
      reference.get_overflowing()[i],
      fast.get_overflowing()[i],
    )
  }
}

///|
test "encode_fast keeps encoding metadata and zeros offsets" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":5,"content":"[MASK]","special":true,"normalized":false}],
    #| "normalizer":{"type":"Lowercase"},
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"hello":2,"moon":3,"world":4,"[MASK]":5,"[PAD]":6,"[UNK]":7},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","cls":["[CLS]",0],"sep":["[SEP]",1]},
    #| "padding":{"strategy":{"Fixed":8},"direction":"Right","pad_id":6,"pad_type_id":0,"pad_token":"[PAD]"}}
  let tok = Tokenizer::from_str(json)
  assert_fast_encoding_matches(
    tok.encode("HELLO [MASK] moon", add_special_tokens=true),
    tok.encode_fast("HELLO [MASK] moon", add_special_tokens=true),
  )
  assert_fast_encoding_matches(
    tok.encode_pair("HELLO moon", "world [MASK]", add_special_tokens=true),
    tok.encode_pair_fast("HELLO moon", "world [MASK]", add_special_tokens=true),
  )
  @test.assert_eq(
    tok.encode_text("HELLO moon", add_special_tokens=false).ids,
    tok.encode("HELLO moon", add_special_tokens=false).ids,
  )
  assert_fast_encoding_matches(
    tok.encode("HELLO moon", add_special_tokens=false),
    tok.encode_text_fast("HELLO moon", add_special_tokens=false),
  )
  @test.assert_eq(
    tok.encode_plus("HELLO", pair=Some("moon"), add_special_tokens=false).ids,
    tok.encode_pair("HELLO", "moon", add_special_tokens=false).ids,
  )
  assert_fast_encoding_matches(
    tok.encode_pair("HELLO", "moon", add_special_tokens=false),
    tok.encode_plus_fast("HELLO", pair=Some("moon"), add_special_tokens=false),
  )
}

///|
test "encode_batch_fast matches cached batch behavior with zero offsets" {
  let json =
    #|{"version":"1.0",
    #| "padding":{"strategy":"BatchLongest","direction":"Right","pad_id":5,"pad_type_id":0,"pad_token":"[PAD]"},
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"hello":2,"world":3,"moon":4,"[PAD]":5,"[UNK]":6},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","cls":["[CLS]",0],"sep":["[SEP]",1]}}
  let tok = Tokenizer::from_str(json)
  let regular = tok.encode_batch(
    ["hello world", "hello", "hello world"],
    add_special_tokens=true,
  )
  let fast = tok.encode_batch_fast(
    ["hello world", "hello", "hello world"],
    add_special_tokens=true,
  )
  @test.assert_eq(fast.length(), regular.length())
  for i in 0..<regular.length() {
    assert_fast_encoding_matches(regular[i], fast[i])
  }
  @test.assert_eq(
    tok
    .encode_text_batch(["hello world", "hello"], add_special_tokens=true)
    .map(e => e.ids),
    tok
    .encode_batch(["hello world", "hello"], add_special_tokens=true)
    .map(e => e.ids),
  )
  @test.assert_eq(
    tok.encode_text_batch_fast(["hello world"], add_special_tokens=true)[0].offsets,
    Array::make(4, (0, 0)),
  )
  let pair_regular = tok.encode_pair_batch(
    [("hello", "world moon"), ("hello", "world moon"), ("moon", "hello")],
    add_special_tokens=true,
  )
  let pair_fast = tok.encode_pair_batch_fast(
    [("hello", "world moon"), ("hello", "world moon"), ("moon", "hello")],
    add_special_tokens=true,
  )
  @test.assert_eq(pair_fast.length(), pair_regular.length())
  for i in 0..<pair_regular.length() {
    assert_fast_encoding_matches(pair_regular[i], pair_fast[i])
  }
}

///|
test "EncodeInput unified API dispatches raw pretokenized pair and fast batch" {
  let json =
    #|{"version":"1.0",
    #| "padding":{"strategy":"BatchLongest","direction":"Right","pad_id":5,"pad_type_id":0,"pad_token":"[PAD]"},
    #| "normalizer":{"type":"Lowercase"},
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"hello":2,"moon":3,"world":4,"[PAD]":5,"[UNK]":6},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","cls":["[CLS]",0],"sep":["[SEP]",1]}}
  let tok = Tokenizer::from_str(json)
  @test.assert_eq(
    tok.encode_input(EncodeInput::single("HELLO moon"), add_special_tokens=true).ids,
    tok.encode("HELLO moon", add_special_tokens=true).ids,
  )
  @test.assert_eq(
    tok.encode_input(
      EncodeInput::single_pretokenized(["HELLO", "moon"]),
      add_special_tokens=true,
    ).ids,
    tok.encode_pretokenized(["HELLO", "moon"], add_special_tokens=true).ids,
  )
  @test.assert_eq(
    tok
    .encode_input(
      EncodeInput::mixed_pair(
        TextInputSequence::text("HELLO"),
        TextInputSequence::pretokenized(["moon", "world"]),
      ),
      add_special_tokens=true,
    )
    .sequence_ids(),
    [None, Some(0), None, Some(1), Some(1), None],
  )
  @test.assert_eq(
    tok
    .encode_sequence_input(
      TextInputSequence::text("HELLO"),
      pair=Some(TextInputSequence::pretokenized(["moon", "world"])),
      add_special_tokens=true,
    )
    .sequence_ids(),
    [None, Some(0), None, Some(1), Some(1), None],
  )
  assert_fast_encoding_matches(
    tok.encode_sequence_input(
      TextInputSequence::text("HELLO"),
      pair=Some(TextInputSequence::pretokenized(["moon", "world"])),
      add_special_tokens=true,
    ),
    tok.encode_sequence_input_fast(
      TextInputSequence::text("HELLO"),
      pair=Some(TextInputSequence::pretokenized(["moon", "world"])),
      add_special_tokens=true,
    ),
  )
  let batch = [
    EncodeInput::single("HELLO moon"),
    EncodeInput::single_pretokenized(["world"]),
    EncodeInput::single("HELLO moon"),
  ]
  let regular = tok.encode_input_batch(batch, add_special_tokens=true)
  let fast = tok.encode_input_batch_fast(batch, add_special_tokens=true)
  let plus = tok.batch_encode_plus(batch, add_special_tokens=true)
  let plus_fast = tok.batch_encode_plus_fast(batch, add_special_tokens=true)
  @test.assert_eq(regular.length(), 3)
  for i in 0..<regular.length() {
    @test.assert_eq(plus[i].ids, regular[i].ids)
    assert_fast_encoding_matches(regular[i], fast[i])
    assert_fast_encoding_matches(plus[i], plus_fast[i])
  }
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
test "encode_pretokenized_fast preserves ids masks and word ids" {
  let json =
    #|{"version":"1.0",
    #| "normalizer":{"type":"Lowercase"},
    #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"hello":2,"moon":3,"world":4,"[UNK]":5},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","cls":["[CLS]",0],"sep":["[SEP]",1]}}
  let tok = Tokenizer::from_str(json)
  assert_fast_encoding_matches(
    tok.encode_pretokenized(["Hello", "moon"], add_special_tokens=true),
    tok.encode_pretokenized_fast(["Hello", "moon"], add_special_tokens=true),
  )
  assert_fast_encoding_matches(
    tok.encode_pretokenized_pair(
      ["Hello"],
      ["moon", "world"],
      add_special_tokens=true,
    ),
    tok.encode_pretokenized_pair_fast(
      ["Hello"],
      ["moon", "world"],
      add_special_tokens=true,
    ),
  )
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
test "encode_pretokenized_batch_fast matches batch padding behavior" {
  let json =
    #|{"version":"1.0",
    #| "padding":{"strategy":"BatchLongest","direction":"Right","pad_id":5,"pad_type_id":0,"pad_token":"[PAD]"},
    #| "normalizer":{"type":"Lowercase"},
    #| "model":{"type":"WordLevel","vocab":{"[CLS]":0,"[SEP]":1,"hello":2,"moon":3,"world":4,"[PAD]":5,"[UNK]":6},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"BertProcessing","cls":["[CLS]",0],"sep":["[SEP]",1]}}
  let tok = Tokenizer::from_str(json)
  let regular = tok.encode_pretokenized_batch(
    [["Hello", "moon"], ["world"], ["Hello", "moon"]],
    add_special_tokens=true,
  )
  let fast = tok.encode_pretokenized_batch_fast(
    [["Hello", "moon"], ["world"], ["Hello", "moon"]],
    add_special_tokens=true,
  )
  @test.assert_eq(fast.length(), regular.length())
  for i in 0..<regular.length() {
    assert_fast_encoding_matches(regular[i], fast[i])
  }
  let pair_regular = tok.encode_pretokenized_pair_batch(
    [
      (["Hello"], ["moon", "world"]),
      (["Hello"], ["moon", "world"]),
      (["moon"], ["Hello"]),
    ],
    add_special_tokens=true,
  )
  let pair_fast = tok.encode_pretokenized_pair_batch_fast(
    [
      (["Hello"], ["moon", "world"]),
      (["Hello"], ["moon", "world"]),
      (["moon"], ["Hello"]),
    ],
    add_special_tokens=true,
  )
  @test.assert_eq(pair_fast.length(), pair_regular.length())
  for i in 0..<pair_regular.length() {
    assert_fast_encoding_matches(pair_regular[i], pair_fast[i])
  }
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
  @test.assert_eq(enc.get_token_sequence(3), Some(1))
  @test.assert_eq(enc.token_to_chars(1), Some((0, (0, 3))))
  @test.assert_eq(enc.token_to_chars(3), Some((1, (0, 1))))
  @test.assert_eq(enc.get_token_chars(1), Some((0, (0, 3))))
  @test.assert_eq(enc.token_to_offsets(3), Some((0, 1)))
  @test.assert_eq(enc.token_to_char_offsets(3), Some((0, 1)))
  @test.assert_eq(enc.token_to_char_offsets(0), None)
  @test.assert_eq(enc.char_to_token(1, sequence_id=0), Some(1))
  @test.assert_eq(enc.char_to_token(0, sequence_id=1), Some(3))
  @test.assert_eq(
    enc.char_to_token_by_sequence_index(0, sequence_index=1),
    Some(3),
  )
  @test.assert_eq(enc.get_char_token(0, sequence_id=1), Some(3))
  @test.assert_eq(enc.char_to_token(3, sequence_id=0), None)
  @test.assert_eq(enc.word_ids(), [None, Some(0), None, Some(0), None])
  @test.assert_eq(enc.token_to_word(1), Some((0, 0)))
  @test.assert_eq(enc.token_to_word(3), Some((1, 0)))
  @test.assert_eq(enc.get_token_word(3), Some((1, 0)))
  @test.assert_eq(enc.token_to_word_index(3), Some(0))
  @test.assert_eq(enc.token_to_word_index(0), None)
  @test.assert_eq(enc.word_to_tokens(0, sequence_id=1), Some((3, 4)))
  @test.assert_eq(
    enc.word_to_tokens_by_sequence_index(0, sequence_index=1),
    Some((3, 4)),
  )
  @test.assert_eq(enc.get_word_tokens(0, sequence_id=1), Some((3, 4)))
  @test.assert_eq(enc.word_to_chars(0, sequence_id=1), Some((0, 1)))
  @test.assert_eq(
    enc.word_to_chars_by_sequence_index(0, sequence_index=1),
    Some((0, 1)),
  )
  @test.assert_eq(enc.get_word_chars(0, sequence_id=1), Some((0, 1)))
  @test.assert_eq(enc.word_to_offsets(0, sequence_id=1), Some((0, 1)))
  @test.assert_eq(enc.char_to_word(0, sequence_id=1), Some(0))
  @test.assert_eq(
    enc.char_to_word_by_sequence_index(0, sequence_index=1),
    Some(0),
  )
  @test.assert_eq(enc.get_char_word(0, sequence_id=1), Some(0))
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
test "WordPiece supports end_of_word_suffix in model config" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordPiece","vocab":{"[UNK]":0,"token":1,"##ization</w>":2,"token</w>":3},"unk_token":"[UNK]","continuing_subword_prefix":"##","end_of_word_suffix":"</w>"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("tokenization token", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["token", "##ization</w>", "token</w>"])
  @test.assert_eq(enc.offsets, [(0, 5), (5, 12), (13, 18)])
  let round_trip = Tokenizer::from_str(tok.to_json())
  @test.assert_eq(round_trip.encode("token", add_special_tokens=false).tokens, [
    "token</w>",
  ])
}

///|
test "Tokenizer cache control clears resizes and isolates model caches" {
  let wp_json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordPiece","vocab":{"[UNK]":0,"token":1,"##ization":2,"other":3},"unk_token":"[UNK]","continuing_subword_prefix":"##"}}
  let wp = Tokenizer::from_str(wp_json)
  @test.assert_eq(wp.cache_size(), 0)
  @test.assert_eq(
    wp.encode("tokenization tokenization", add_special_tokens=false).ids,
    [1, 2, 1, 2],
  )
  @test.assert_eq(wp.cache_size(), 1)
  wp.clear_cache() |> ignore
  @test.assert_eq(wp.cache_size(), 0)
  wp.resize_cache(0) |> ignore
  @test.assert_eq(wp.encode("tokenization", add_special_tokens=false).ids, [
    1, 2,
  ])
  @test.assert_eq(wp.cache_size(), 0)
  wp.resize_cache(1) |> ignore
  wp.encode("tokenization other", add_special_tokens=false) |> ignore
  @test.assert_eq(wp.cache_size(), 1)
  let fresh = Tokenizer::from_str(wp_json)
  @test.assert_eq(fresh.cache_size(), 0)
  @test.assert_eq(fresh.encode("tokenization", add_special_tokens=false).ids, [
    1, 2,
  ])
  @test.assert_eq(fresh.cache_size(), 1)

  let bpe_json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"BPE","vocab":{"a":0,"b":1,"ab":2,"c":3,"abc":4},"merges":[["a","b"],["ab","c"]]}}
  let bpe = Tokenizer::from_str(bpe_json).resize_cache(0)
  @test.assert_eq(bpe.encode("abc", add_special_tokens=false).ids, [4])
  @test.assert_eq(bpe.cache_size(), 0)
  bpe.resize_cache(2) |> ignore
  bpe.encode("abc ab", add_special_tokens=false) |> ignore
  @test.assert_eq(bpe.cache_size(), 2)

  let unigram_json =
    #|{"version":"1.0",
    #| "model":{"type":"Unigram","vocab":[["a",0.0],["b",0.0],["ab",1.0],["<unk>",-10.0]],"unk_id":3}}
  let uni = Tokenizer::from_str(unigram_json)
  @test.assert_eq(uni.encode("ab", add_special_tokens=false).ids, [2])
  @test.assert_eq(uni.cache_size(), 1)
  uni.clear_cache() |> ignore
  @test.assert_eq(uni.cache_size(), 0)
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
  for pattern in ["\\\\p{L}{2,4}(?=x)", "(.)\\\\1", "foo.*bar", "[A-Z]{5,}"] {
    let json = "{\"version\":\"1.0\",\"pre_tokenizer\":{\"type\":\"Split\",\"pattern\":{\"Regex\":\"" +
      pattern +
      "\"},\"behavior\":\"Isolated\",\"invert\":false},\"model\":{\"type\":\"WordLevel\",\"vocab\":{\"[UNK]\":0},\"unk_token\":\"[UNK]\"}}"
    let mut raised = false
    try Tokenizer::from_str(json) |> ignore catch {
      @types.UnsupportedComponent(_) => raised = true
      _ => raised = false
    }
    assert_true(raised)
  }
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
test "from_str supports grouped literal Split regex" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"Split","pattern":{"Regex":"(?:foo)"},"behavior":"Removed","invert":false},
    #| "model":{"type":"WordLevel","vocab":{"xx":0," ":1,"d ":2,"[UNK]":3},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("xxfoo food foo", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["xx", " ", "d "])
  @test.assert_eq(enc.ids, [0, 1, 2])
}

///|
test "from_str supports ascii space-run Split regex" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"Split","pattern":{"Regex":" {2,}"},"behavior":"Removed","invert":false},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"b\t\tc":1,"d":2,"[UNK]":3},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  let enc = tok.encode("a   b\t\tc  d", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["a", "b\t\tc", "d"])
  @test.assert_eq(enc.ids, [0, 1, 2])
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
test "from_buffer and to_str pretty mirror HF migration APIs" {
  let json =
    #|{"version":"1.0","pre_tokenizer":{"type":"WhitespaceSplit"},"model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_buffer(@utf8.encode(json))
  @test.assert_eq(tok.encode("hello moon", add_special_tokens=false).ids, [0, 1])
  @test.assert_eq(tok.to_str(), json)
  let pretty = tok.to_str(pretty=true)
  @test.assert_eq(pretty.contains("\n"), true)
  @test.assert_eq(pretty.contains("  \"model\""), true)
  let roundtrip = Tokenizer::from_str(pretty)
  @test.assert_eq(
    roundtrip.encode("hello missing", add_special_tokens=false).ids,
    [0, 2],
  )
}

///|
test "HF mutating config aliases mirror builder APIs" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"hello":0,"moon":1,"extra":2,"[PAD]":3,"[UNK]":4},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
    .enable_truncation(2)
    .enable_padding(length=Some(4), pad_id=3, pad_token="[PAD]")
  @test.assert_eq(
    tok.encode("hello moon extra", add_special_tokens=false).ids,
    [0, 1, 3, 3],
  )
  @test.assert_eq(tok.get_truncation() is Some(_), true)
  @test.assert_eq(tok.get_padding() is Some(_), true)
  let cleared = tok.no_truncation().no_padding()
  @test.assert_eq(cleared.get_truncation() is None, true)
  @test.assert_eq(cleared.get_padding() is None, true)
  @test.assert_eq(
    cleared.encode("hello moon extra", add_special_tokens=false).ids,
    [0, 1, 2],
  )
}

///|
test "encode special token aliases switch added-token extraction" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":2,"content":"[SPECIAL]","special":true}],
    #| "model":{"type":"WordLevel","vocab":{"[SPECIAL]":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let tok = Tokenizer::from_str(json)
  @test.assert_eq(tok.encode("[SPECIAL]", add_special_tokens=false).ids, [2])
  let literal = tok.enable_encode_special_tokens()
  @test.assert_eq(literal.encode("[SPECIAL]", add_special_tokens=false).ids, [0])
  @test.assert_eq(
    literal
    .disable_encode_special_tokens()
    .encode("[SPECIAL]", add_special_tokens=false).ids,
    [2],
  )
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
  let pretty_path = "_build/tokenizer_save_roundtrip_pretty.json"
  tok.save(pretty_path, pretty=true)
  let pretty = @fs.read_file_to_string(pretty_path)
  @test.assert_eq(pretty.contains("\n"), true)
  @test.assert_eq(
    Tokenizer::from_file(pretty_path).encode(
      "hello moon",
      add_special_tokens=false,
    ).ids,
    [0, 1],
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
test "model save writes HF-style standalone artifacts" {
  let bpe_json =
    #|{"version":"1.0",
    #| "model":{"type":"BPE","vocab":{"a":0,"b":1,"ab":2},"merges":[["a","b"]]}}
  let bpe_paths = Tokenizer::from_str(bpe_json)
    .get_model()
    .save("_build/model_save_bpe", prefix="toy")
  @test.assert_eq(bpe_paths, [
    "_build/model_save_bpe/toy-vocab.json", "_build/model_save_bpe/toy-merges.txt",
  ])
  @test.assert_eq(
    @fs.read_file_to_string("_build/model_save_bpe/toy-vocab.json"),
    "{\"a\":0,\"b\":1,\"ab\":2}",
  )
  @test.assert_eq(
    @fs.read_file_to_string("_build/model_save_bpe/toy-merges.txt"),
    "#version: 0.2\na b\n",
  )
  let facade_paths = Tokenizer::from_str(bpe_json).save_model(
    "_build/model_save_bpe_facade",
    prefix="tok",
  )
  @test.assert_eq(facade_paths, [
    "_build/model_save_bpe_facade/tok-vocab.json", "_build/model_save_bpe_facade/tok-merges.txt",
  ])

  let wp_json =
    #|{"version":"1.0",
    #| "model":{"type":"WordPiece","vocab":{"[UNK]":0,"hello":1,"##s":2},"unk_token":"[UNK]"}}
  let wp_paths = Tokenizer::from_str(wp_json)
    .get_model()
    .save("_build/model_save_wordpiece")
  @test.assert_eq(wp_paths, ["_build/model_save_wordpiece/vocab.txt"])
  @test.assert_eq(
    @fs.read_file_to_string("_build/model_save_wordpiece/vocab.txt"),
    "[UNK]\nhello\n##s\n",
  )

  let unigram_json =
    #|{"version":"1.0",
    #| "model":{"type":"Unigram","vocab":[["a",0.0],["b",1.0]],"unk_id":0}}
  let uni_paths = Tokenizer::from_str(unigram_json)
    .get_model()
    .save("_build/model_save_unigram")
  @test.assert_eq(uni_paths, ["_build/model_save_unigram/unigram.json"])
  @test.assert_eq(
    @fs.read_file_to_string("_build/model_save_unigram/unigram.json"),
    "{\"type\":\"Unigram\",\"vocab\":[[\"a\",0],[\"b\",1]],\"unk_id\":0}",
  )

  let saved_json_path = Tokenizer::from_str(bpe_json).save_pretrained(
    "_build/model_save_with_pretrained_artifacts",
    save_model=true,
    model_prefix="aux",
  )
  @test.assert_eq(
    saved_json_path, "_build/model_save_with_pretrained_artifacts/tokenizer.json",
  )
  @test.assert_eq(
    @fs.read_file_to_string(
      "_build/model_save_with_pretrained_artifacts/aux-merges.txt",
    ),
    "#version: 0.2\na b\n",
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
test "from_pretrained_downloaded writes HF-style cache and refs" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"WordLevel","vocab":{"downloaded":0,"hub":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let root = "_build/hf_download_cache_test"
  let hub = root + "/hub"
  ensure_dir(root)
  ensure_dir(hub)
  let tok = Tokenizer::from_pretrained_downloaded(
    "org/downloaded-tokenizer",
    json,
    revision="main",
    resolved_revision=Some("def456"),
    cache_dir=Some(hub),
    tokenizer_config_json=Some("{\"model_max_length\":128}"),
    special_tokens_map_json=Some("{\"unk_token\":\"[UNK]\"}"),
    etag=Some("etag-tokenizer-json"),
  )
  @test.assert_eq(tok.encode("downloaded hub", add_special_tokens=false).ids, [
    0, 1,
  ])
  let cached = Tokenizer::from_pretrained_cached(
    "org/downloaded-tokenizer",
    revision="main",
    cache_dir=Some(hub),
  )
  @test.assert_eq(cached.encode("hub missing", add_special_tokens=false).ids, [
    1, 2,
  ])
  let aux = Tokenizer::from_pretrained_aux_files(
    "org/downloaded-tokenizer",
    revision="main",
    cache_dir=Some(hub),
  )
  @test.assert_eq(aux.tokenizer_config_json, Some("{\"model_max_length\":128}"))
  @test.assert_eq(
    aux.special_tokens_map_json,
    Some("{\"unk_token\":\"[UNK]\"}"),
  )
  let meta = Tokenizer::from_pretrained_cache_metadata(
    "org/downloaded-tokenizer",
    revision="main",
    cache_dir=Some(hub),
  ).unwrap()
  @test.assert_eq(meta.revision, "main")
  @test.assert_eq(meta.resolved_revision, "def456")
  @test.assert_eq(meta.etag, Some("etag-tokenizer-json"))
  @test.assert_eq(meta.cache_exists(), true)
  @test.assert_eq(meta.etag_matches(Some("etag-tokenizer-json")), true)
  @test.assert_eq(meta.etag_matches(Some("stale-etag")), false)
  @test.assert_eq(
    meta.is_fresh(
      resolved_revision=Some("def456"),
      etag=Some("etag-tokenizer-json"),
      require_tokenizer_config=true,
      require_special_tokens_map=true,
    ),
    true,
  )
  @test.assert_eq(meta.is_fresh(resolved_revision=Some("old")), false)
  @test.assert_eq(meta.tokenizer_json_path.has_suffix("/tokenizer.json"), true)
  @test.assert_eq(
    meta.tokenizer_config_path.unwrap().has_suffix("/tokenizer_config.json"),
    true,
  )
  @test.assert_eq(
    meta.special_tokens_map_path.unwrap().has_suffix("/special_tokens_map.json"),
    true,
  )
  @test.assert_eq(
    Tokenizer::from_pretrained_cache_metadata(
      "org/not-cached",
      cache_dir=Some(hub),
    ),
    None,
  )
  @test.assert_eq(
    Tokenizer::from_pretrained_cache_exists(
      "org/downloaded-tokenizer",
      revision="main",
      cache_dir=Some(hub),
    ),
    true,
  )
  @test.assert_eq(
    Tokenizer::from_pretrained_cache_etag_matches(
      "org/downloaded-tokenizer",
      Some("etag-tokenizer-json"),
      revision="main",
      cache_dir=Some(hub),
    ),
    true,
  )
  @test.assert_eq(
    Tokenizer::from_pretrained_cache_is_fresh(
      "org/downloaded-tokenizer",
      revision="main",
      cache_dir=Some(hub),
      resolved_revision=Some("def456"),
      etag=Some("etag-tokenizer-json"),
      require_tokenizer_config=true,
      require_special_tokens_map=true,
    ),
    true,
  )
  @test.assert_eq(
    Tokenizer::from_pretrained_cache_is_fresh(
      "org/downloaded-tokenizer",
      revision="main",
      cache_dir=Some(hub),
      etag=Some("stale-etag"),
    ),
    false,
  )
  @test.assert_eq(
    from_pretrained_cache_exists("org/not-cached", cache_dir=Some(hub)),
    false,
  )
  let ok_hint = Tokenizer::from_pretrained_resolution_hint(
    "org/downloaded-tokenizer",
    revision="main",
    cache_dir=Some(hub),
  )
  @test.assert_eq(ok_hint.cache_exists, true)
  @test.assert_eq(ok_hint.resolved_revision, Some("def456"))
  @test.assert_eq(
    ok_hint.message.contains("can resolve cached tokenizer"),
    true,
  )
  let paths = Tokenizer::from_pretrained_cache_paths(
    "org/downloaded-tokenizer",
    revision="main",
    cache_dir=Some(hub),
  ).unwrap()
  @test.assert_eq(paths.ref_path.has_suffix("/refs/main"), true)
  @test.assert_eq(paths.snapshot_dir.has_suffix("/snapshots/def456"), true)
  @test.assert_eq(
    Tokenizer::from_pretrained_ref_revision(
      "org/downloaded-tokenizer",
      revision="main",
      cache_dir=Some(hub),
    ),
    Some("def456"),
  )
  let ref_path = Tokenizer::write_pretrained_ref_revision(
    "org/downloaded-tokenizer",
    "def789",
    revision="dev",
    cache_dir=Some(hub),
  )
  @test.assert_eq(ref_path.has_suffix("/refs/dev"), true)
  @test.assert_eq(
    Tokenizer::from_pretrained_ref_revision(
      "org/downloaded-tokenizer",
      revision="dev",
      cache_dir=Some(hub),
    ),
    Some("def789"),
  )
  let nested_ref = Tokenizer::write_pretrained_ref_revision(
    "org/downloaded-tokenizer",
    "pr007",
    revision="refs/pr/7",
    cache_dir=Some(hub),
  )
  @test.assert_eq(nested_ref.has_suffix("/refs/refs/pr/7"), true)
  @test.assert_eq(
    Tokenizer::from_pretrained_ref_revision(
      "org/downloaded-tokenizer",
      revision="refs/pr/7",
      cache_dir=Some(hub),
    ),
    Some("pr007"),
  )
  let feature_ref = Tokenizer::write_pretrained_ref_revision(
    "org/downloaded-tokenizer",
    "feature123",
    revision="feature/foo",
    cache_dir=Some(hub),
  )
  @test.assert_eq(feature_ref.has_suffix("/refs/feature/foo"), true)
  @test.assert_eq(
    Tokenizer::from_pretrained_ref_revision(
      "org/downloaded-tokenizer",
      revision="feature/foo",
      cache_dir=Some(hub),
    ),
    Some("feature123"),
  )
  let resume_meta = Tokenizer::write_pretrained_download_resume_metadata(
    "org/downloaded-tokenizer",
    revision="dev",
    resolved_revision=Some("def789"),
    cache_dir=Some(hub),
    etag=Some("etag-resume"),
    expected_size=Some(4096),
    downloaded_size=1024,
  )
  @test.assert_eq(
    resume_meta.incomplete_path.has_suffix("/tokenizer.json.incomplete"),
    true,
  )
  let loaded_resume = Tokenizer::from_pretrained_download_resume_metadata(
    "org/downloaded-tokenizer",
    revision="dev",
    cache_dir=Some(hub),
  ).unwrap()
  @test.assert_eq(loaded_resume.etag, Some("etag-resume"))
  @test.assert_eq(loaded_resume.expected_size, Some(4096))
  @test.assert_eq(loaded_resume.downloaded_size, 1024)
  @test.assert_eq(
    Tokenizer::clear_pretrained_download_resume_metadata(
      "org/downloaded-tokenizer",
      revision="dev",
      cache_dir=Some(hub),
    ),
    true,
  )
  @test.assert_eq(
    Tokenizer::from_pretrained_download_resume_metadata(
      "org/downloaded-tokenizer",
      revision="dev",
      cache_dir=Some(hub),
    ),
    None,
  )
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
  assert_from_pretrained_parse_error_contains(
    "missing-org/missing-model", "private or gated",
  )
  let hint = Tokenizer::from_pretrained_resolution_hint(
    "private-org/private-model",
    cache_dir=Some("_build/empty_hub_cache"),
  )
  @test.assert_eq(hint.cache_exists, false)
  @test.assert_eq(
    hint.repo_cache_dir.unwrap().contains("models--private-org--private-model"),
    true,
  )
  @test.assert_eq(hint.message.contains("private or gated"), true)
}

///|
test "Hub identifier validation accepts HF-safe ids and revisions" {
  @test.assert_eq(Tokenizer::is_valid_hub_identifier("bert-base-uncased"), true)
  @test.assert_eq(Tokenizer::is_valid_hub_identifier("org/model_1.0"), true)
  @test.assert_eq(Tokenizer::is_valid_hub_identifier("refs/pr/7"), true)
  @test.assert_eq(Tokenizer::is_valid_hub_identifier("feature/foo"), true)
  @test.assert_eq(Tokenizer::is_valid_hub_identifier("org/model name"), false)
  @test.assert_eq(Tokenizer::is_valid_hub_identifier("org/model@x"), false)
  @test.assert_eq(Tokenizer::is_valid_hub_identifier("../escape"), false)
  @test.assert_eq(Tokenizer::is_valid_hub_identifier("org/../model"), false)
  @test.assert_eq(Tokenizer::is_valid_hub_identifier("refs//pr"), false)
}

///|
test "Hub validation rejects unsafe cache writes without rejecting local paths" {
  let root = "_build/hub_validation_cache"
  ensure_dir(root)
  let local_dir = "_build/local model@unsafe"
  ensure_dir(local_dir)
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"local":0,"[UNK]":1},"unk_token":"[UNK]"}}
  @fs.write_string_to_file(local_dir + "/tokenizer.json", json) catch {
    _ => ()
  }
  let local_tok = Tokenizer::from_pretrained(local_dir)
  @test.assert_eq(local_tok.encode("local", add_special_tokens=false).ids, [0])

  let mut bad_model = false
  try
    Tokenizer::from_pretrained_downloaded(
      "org/model name",
      json,
      cache_dir=Some(root),
    )
    |> ignore
  catch {
    @types.ParseError(msg) => bad_model = msg.contains("expected only")
    _ => ()
  }
  @test.assert_eq(bad_model, true)

  let mut bad_revision = false
  try
    Tokenizer::write_pretrained_ref_revision(
      "org/model",
      "abc123",
      revision="../escape",
      cache_dir=Some(root),
    )
    |> ignore
  catch {
    @types.ParseError(msg) => bad_revision = msg.contains("Revision")
    _ => ()
  }
  @test.assert_eq(bad_revision, true)
  @test.assert_eq(@fs.path_exists(root + "/escape"), false)
  @test.assert_eq(
    Tokenizer::from_pretrained_cache_paths(
      "org/../model",
      revision="main",
      cache_dir=Some(root),
    ),
    None,
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
  let parallel = tok.encode_batch_parallel(
    ["hello", "hello moon", "hello"],
    add_special_tokens=false,
  )
  let parallel_fast = tok.encode_batch_parallel_fast(
    ["hello", "hello moon", "hello"],
    add_special_tokens=false,
  )
  @test.assert_eq(parallel.map(e => e.ids), batch.map(e => e.ids))
  @test.assert_eq(parallel_fast.map(e => e.ids), batch.map(e => e.ids))
  @test.assert_eq(parallel_fast[0].offsets, [(0, 0), (0, 0)])

  let pair_batch = tok.encode_pair_batch(
    [("hello", "moon"), ("hello", "moon"), ("moon", "hello")],
    add_special_tokens=false,
  )
  let pair_parallel = tok.encode_pair_batch_parallel(
    [("hello", "moon"), ("hello", "moon"), ("moon", "hello")],
    add_special_tokens=false,
  )
  let pair_parallel_fast = tok.encode_pair_batch_parallel_fast(
    [("hello", "moon"), ("hello", "moon"), ("moon", "hello")],
    add_special_tokens=false,
  )
  @test.assert_eq(pair_parallel.map(e => e.ids), pair_batch.map(e => e.ids))
  @test.assert_eq(
    pair_parallel_fast.map(e => e.ids),
    pair_batch.map(e => e.ids),
  )
  @test.assert_eq(pair_parallel[0].type_ids, pair_batch[0].type_ids)
  @test.assert_eq(pair_parallel_fast[0].offsets, [(0, 0), (0, 0)])

  let pre_batch = tok.encode_pretokenized_batch(
    [["hello"], ["hello", "moon"], ["hello"]],
    add_special_tokens=false,
  )
  let pre_parallel = tok.encode_pretokenized_batch_parallel(
    [["hello"], ["hello", "moon"], ["hello"]],
    add_special_tokens=false,
  )
  let pre_parallel_fast = tok.encode_pretokenized_batch_parallel_fast(
    [["hello"], ["hello", "moon"], ["hello"]],
    add_special_tokens=false,
  )
  @test.assert_eq(pre_parallel.map(e => e.ids), pre_batch.map(e => e.ids))
  @test.assert_eq(pre_parallel_fast.map(e => e.ids), pre_batch.map(e => e.ids))
  @test.assert_eq(pre_parallel_fast[0].offsets, [(0, 0), (0, 0)])

  let pre_pair_batch = tok.encode_pretokenized_pair_batch(
    [(["hello"], ["moon"]), (["hello"], ["moon"])],
    add_special_tokens=false,
  )
  let pre_pair_parallel = tok.encode_pretokenized_pair_batch_parallel(
    [(["hello"], ["moon"]), (["hello"], ["moon"])],
    add_special_tokens=false,
  )
  let pre_pair_parallel_fast = tok.encode_pretokenized_pair_batch_parallel_fast(
    [(["hello"], ["moon"]), (["hello"], ["moon"])],
    add_special_tokens=false,
  )
  @test.assert_eq(
    pre_pair_parallel.map(e => e.ids),
    pre_pair_batch.map(e => e.ids),
  )
  @test.assert_eq(
    pre_pair_parallel_fast.map(e => e.ids),
    pre_pair_batch.map(e => e.ids),
  )
  @test.assert_eq(pre_pair_parallel_fast[0].offsets, [(0, 0), (0, 0)])
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
test "Tokenizer train_from_iterator applies pipeline and preserves added specials" {
  let base = Tokenizer::new(@model.Model::train_wordlevel_from_tokens([[]]))
    .with_normalizer(Some(@normalizer.Normalizer::Lowercase))
    .with_pre_tokenizer(Some(@pretokenizer.PreTokenizer::whitespace_split()))
    .add_special_tokens([AddedToken::special("[MASK]")])
  let trained = base.train_from_iterator(
    ["HELLO [MASK]", "hello Moon", "MOON"],
    Trainer::wordlevel(unk_token="[UNK]", min_frequency=1),
  )
  @test.assert_eq(trained.token_to_id("[MASK]"), Some(0))
  @test.assert_eq(trained.token_to_id("[UNK]"), Some(1))
  @test.assert_eq(trained.token_to_id("hello") is Some(_), true)
  @test.assert_eq(trained.token_to_id("moon") is Some(_), true)
  @test.assert_eq(
    trained.encode("HELLO moon [MASK]", add_special_tokens=false).tokens,
    ["hello", "moon", "[MASK]"],
  )
  @test.assert_eq(trained.get_normalizer() is Some(_), true)
  @test.assert_eq(trained.get_pre_tokenizer() is Some(_), true)
}

///|
test "BPE train_from_iterator preserves model-only options" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"BPE","vocab":{"[UNK]":0,"a":1,"b":2,"ab":3},"merges":[["a","b"]],"unk_token":"[UNK]","byte_fallback":true,"dropout":0.25,"ignore_merges":true}}
  let base = Tokenizer::from_str(json).resize_cache(0)
  let trained = base.train_from_iterator(
    ["abab abab", "ab"],
    Trainer::bpe(
      unk_token=Some("[UNK]"),
      min_frequency=1,
      vocab_size=Some(16),
      show_progress=false,
    ),
  )
  let rendered = trained.to_json()
  @test.assert_eq(rendered.contains("\"byte_fallback\":true"), true)
  @test.assert_eq(rendered.contains("\"dropout\":0.25"), true)
  @test.assert_eq(rendered.contains("\"ignore_merges\":true"), true)
  @test.assert_eq(trained.get_model().byte_fallback(), Some(true))
  @test.assert_eq(trained.get_model().dropout(), Some(0.25))
  @test.assert_eq(trained.get_model().ignore_merges(), Some(true))
  match trained.get_model() {
    @model.BPE(m) => @test.assert_eq(m.cache_capacity, Some(0))
    _ => abort("expected BPE model")
  }
}

///|
test "BPE train_from_iterator lets trainer override prefix and suffix" {
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"WhitespaceSplit"},
    #| "model":{"type":"BPE","vocab":{"[UNK]":0,"a":1,"b":2,"ab":3},"merges":[["a","b"]],"unk_token":"[UNK]","continuing_subword_prefix":"OLD","end_of_word_suffix":"OLDEND","byte_fallback":true,"ignore_merges":true}}
  let trained = Tokenizer::from_str(json).train_from_iterator(
    ["abab abab", "ab"],
    Trainer::bpe(
      unk_token=Some("[UNK]"),
      min_frequency=1,
      vocab_size=Some(16),
      continuing_subword_prefix=Some("@@"),
      end_of_word_suffix=Some("</w>"),
      show_progress=false,
    ),
  )
  let rendered = trained.to_json()
  @test.assert_eq(trained.get_model().continuing_subword_prefix(), Some("@@"))
  @test.assert_eq(trained.get_model().end_of_word_suffix(), Some("</w>"))
  @test.assert_eq(
    rendered.contains("\"continuing_subword_prefix\":\"@@\""),
    true,
  )
  @test.assert_eq(rendered.contains("\"end_of_word_suffix\":\"</w>\""), true)
  @test.assert_eq(rendered.contains("OLD"), false)
}

///|
test "Trainer preserves AddedToken metadata for special tokens" {
  let base = Tokenizer::new(@model.Model::train_wordlevel_from_tokens([[]])).with_pre_tokenizer(
    Some(@pretokenizer.PreTokenizer::whitespace_split()),
  )
  let trained = base.train_from_iterator(
    ["hello <extra>", "world"],
    Trainer::wordlevel(
      unk_token="[UNK]",
      special_added_tokens=[
        AddedToken::special("<extra>")
        .with_single_word(true)
        .with_lstrip(true)
        .with_rstrip(true),
      ],
      show_progress=false,
    ),
  )
  @test.assert_eq(trained.token_to_id("<extra>"), Some(0))
  let decoder = trained.get_added_tokens_decoder()
  let extra = decoder.get(0).unwrap()
  @test.assert_eq(extra.content, "<extra>")
  @test.assert_eq(extra.special, true)
  @test.assert_eq(extra.normalized, false)
  @test.assert_eq(extra.single_word, true)
  @test.assert_eq(extra.lstrip, true)
  @test.assert_eq(extra.rstrip, true)
  @test.assert_eq(
    trained.encode("hello <extra> world", add_special_tokens=false).tokens,
    ["hello", " <extra> ", "world"],
  )
}

///|
test "Trainer exposes HF-style configuration getters" {
  let mask = AddedToken::special("[MASK]").with_lstrip(true)
  let wordlevel = Trainer::wordlevel(
    unk_token="[UNK]",
    min_frequency=2,
    special_tokens=["[PAD]"],
    special_added_tokens=[mask],
    vocab_size=Some(8),
    show_progress=false,
  )
  @test.assert_eq(wordlevel.kind(), "WordLevelTrainer")
  @test.assert_eq(wordlevel.unk_token(), Some("[UNK]"))
  @test.assert_eq(wordlevel.min_frequency(), 2)
  @test.assert_eq(wordlevel.special_tokens(), ["[PAD]"])
  @test.assert_eq(wordlevel.special_added_tokens()[0].content(), "[MASK]")
  @test.assert_eq(wordlevel.vocab_size(), Some(8))
  @test.assert_eq(wordlevel.show_progress(), false)

  let specials = wordlevel.special_tokens()
  specials.push("[CLS]")
  @test.assert_eq(wordlevel.special_tokens(), ["[PAD]"])

  let wordpiece = Trainer::wordpiece(
    continuing_subword_prefix="@@",
    end_of_word_suffix=Some("</w>"),
    initial_alphabet=["z"],
    limit_alphabet=Some(16),
    max_input_chars_per_word=42,
    max_token_length=Some(6),
  )
  @test.assert_eq(wordpiece.kind(), "WordPieceTrainer")
  @test.assert_eq(wordpiece.continuing_subword_prefix(), Some("@@"))
  @test.assert_eq(wordpiece.end_of_word_suffix(), Some("</w>"))
  @test.assert_eq(wordpiece.initial_alphabet(), ["z"])
  @test.assert_eq(wordpiece.limit_alphabet(), Some(16))
  @test.assert_eq(wordpiece.max_input_chars_per_word(), Some(42))
  @test.assert_eq(wordpiece.max_token_length(), Some(6))

  let bpe = Trainer::bpe(
    unk_token=None,
    continuing_subword_prefix=Some("@@"),
    end_of_word_suffix=Some("</w>"),
    fuse_unk=true,
    initial_alphabet=["x"],
    limit_alphabet=Some(9),
    max_token_length=Some(5),
    progress_format="json",
  )
  @test.assert_eq(bpe.kind(), "BpeTrainer")
  @test.assert_eq(bpe.unk_token(), None)
  @test.assert_eq(bpe.continuing_subword_prefix(), Some("@@"))
  @test.assert_eq(bpe.end_of_word_suffix(), Some("</w>"))
  @test.assert_eq(bpe.fuse_unk(), Some(true))
  @test.assert_eq(bpe.initial_alphabet(), ["x"])
  @test.assert_eq(bpe.limit_alphabet(), Some(9))
  @test.assert_eq(bpe.max_token_length(), Some(5))
  @test.assert_eq(bpe.progress_format(), Some("json"))

  let unigram = Trainer::unigram(
    unk_piece=Some("<UNK>"),
    byte_fallback=true,
    fuse_unk=false,
    shrinking_factor=0.5,
    max_piece_length=Some(4),
    initial_alphabet=["z", "xy"],
    n_sub_iterations=3,
    seed_size=128,
  )
  @test.assert_eq(unigram.kind(), "UnigramTrainer")
  @test.assert_eq(unigram.unk_token(), Some("<UNK>"))
  @test.assert_eq(unigram.byte_fallback(), Some(true))
  @test.assert_eq(unigram.fuse_unk(), Some(false))
  @test.assert_eq(unigram.shrinking_factor(), Some(0.5))
  @test.assert_eq(unigram.max_piece_length(), Some(4))
  @test.assert_eq(unigram.initial_alphabet(), ["z", "xy"])
  @test.assert_eq(unigram.n_sub_iterations(), Some(3))
  @test.assert_eq(unigram.seed_size(), Some(128))
  @test.assert_eq(unigram.continuing_subword_prefix(), None)
  @test.assert_eq(unigram.progress_format(), None)
  @test.assert_eq(Trainer::unigram().seed_size(), Some(1000000))
}

///|
test "Trainer default vocab_size mirrors HF caps" {
  @test.assert_eq(Trainer::wordlevel().vocab_size(), Some(30000))
  @test.assert_eq(Trainer::wordpiece().vocab_size(), Some(30000))
  @test.assert_eq(Trainer::bpe().vocab_size(), Some(30000))
  @test.assert_eq(Trainer::unigram().vocab_size(), Some(8000))
  @test.assert_eq(Trainer::wordlevel(vocab_size=None).vocab_size(), None)
  @test.assert_eq(Trainer::wordpiece(vocab_size=None).vocab_size(), None)
  @test.assert_eq(Trainer::bpe(vocab_size=None).vocab_size(), None)
  @test.assert_eq(Trainer::unigram(vocab_size=None).vocab_size(), None)
}

///|
test "Trainer exposes state and string aliases" {
  let mask = AddedToken::special("[MASK]")
    .with_lstrip(true)
    .with_rstrip(true)
    .with_single_word(true)
  let trainer = Trainer::bpe(
    unk_token=Some("[UNK]"),
    min_frequency=3,
    special_tokens=["[PAD]"],
    special_added_tokens=[mask],
    vocab_size=Some(32),
    continuing_subword_prefix=Some("@@"),
    end_of_word_suffix=Some("</w>"),
    fuse_unk=true,
    initial_alphabet=["x"],
    limit_alphabet=Some(7),
    max_token_length=Some(5),
    show_progress=false,
    progress_format="silent",
  )
  let state = trainer.__getstate__()
  @test.assert_eq(state.kind, "BpeTrainer")
  @test.assert_eq(state.unk_token, Some("[UNK]"))
  @test.assert_eq(state.min_frequency, 3)
  @test.assert_eq(state.special_tokens, ["[PAD]"])
  @test.assert_eq(state.special_added_tokens[0].content(), "[MASK]")
  @test.assert_eq(state.special_added_tokens[0].lstrip(), true)
  @test.assert_eq(state.special_added_tokens[0].rstrip(), true)
  @test.assert_eq(state.special_added_tokens[0].single_word(), true)
  @test.assert_eq(state.vocab_size, Some(32))
  @test.assert_eq(state.show_progress, false)
  @test.assert_eq(state.continuing_subword_prefix, Some("@@"))
  @test.assert_eq(state.end_of_word_suffix, Some("</w>"))
  @test.assert_eq(state.fuse_unk, Some(true))
  @test.assert_eq(state.initial_alphabet, ["x"])
  @test.assert_eq(state.limit_alphabet, Some(7))
  @test.assert_eq(state.max_token_length, Some(5))
  @test.assert_eq(state.progress_format, Some("silent"))

  let restored = Trainer::__setstate__(state)
  @test.assert_eq(restored.kind(), "BpeTrainer")
  @test.assert_eq(restored.unk_token(), Some("[UNK]"))
  @test.assert_eq(restored.min_frequency(), 3)
  @test.assert_eq(restored.special_tokens(), ["[PAD]"])
  @test.assert_eq(restored.special_added_tokens()[0].content(), "[MASK]")
  @test.assert_eq(restored.show_progress(), false)
  @test.assert_eq(restored.continuing_subword_prefix(), Some("@@"))
  @test.assert_eq(restored.end_of_word_suffix(), Some("</w>"))
  @test.assert_eq(restored.fuse_unk(), Some(true))
  @test.assert_eq(restored.initial_alphabet(), ["x"])
  @test.assert_eq(restored.limit_alphabet(), Some(7))
  @test.assert_eq(restored.max_token_length(), Some(5))
  @test.assert_eq(restored.progress_format(), Some("silent"))

  let copied_alphabet = state.initial_alphabet
  copied_alphabet.push("y")
  @test.assert_eq(trainer.initial_alphabet(), ["x"])

  let rendered = trainer.__str__()
  @test.assert_eq(trainer.__repr__(), rendered)
  @test.assert_eq(rendered.contains("\"type\":\"BpeTrainer\""), true)
  @test.assert_eq(rendered.contains("\"special_added_tokens\""), true)
  @test.assert_eq(
    rendered.contains("\"continuing_subword_prefix\":\"@@\""),
    true,
  )
  @test.assert_eq(rendered.contains("\"progress_format\":\"silent\""), true)

  @test.assert_eq(
    Trainer::bpe(progress_format="unknown").progress_format(),
    Some("indicatif"),
  )
}

///|
test "Trainer unigram seed_size state defaults and roundtrips" {
  let default_trainer = Trainer::unigram(show_progress=false)
  let default_state = default_trainer.__getstate__()
  @test.assert_eq(default_state.seed_size, Some(1000000))
  @test.assert_eq(default_trainer.seed_size(), Some(1000000))
  @test.assert_eq(
    default_trainer.__str__().contains("\"seed_size\":1000000"),
    true,
  )

  let trainer = Trainer::unigram(
    initial_alphabet=["z"],
    seed_size=3,
    show_progress=false,
  )
  let state = trainer.__getstate__()
  @test.assert_eq(state.seed_size, Some(3))
  let restored = Trainer::from_state(state)
  @test.assert_eq(restored.kind(), "UnigramTrainer")
  @test.assert_eq(restored.initial_alphabet(), ["z"])
  @test.assert_eq(restored.seed_size(), Some(3))
  @test.assert_eq(restored.__str__().contains("\"seed_size\":3"), true)
}

///|
test "Trainer state rejects unknown trainer kind" {
  let state = Trainer::wordlevel().__getstate__()
  let bad = state.with_kind("UnknownTrainer")
  let mut raised = false
  try Trainer::from_state(bad) |> ignore catch {
    @types.UnsupportedComponent(_) => raised = true
    _ => ()
  }
  @test.assert_eq(raised, true)
}

///|
test "Tokenizer train_from_files trains line oriented corpus" {
  let path = "_build/tokenizer_train_from_files.txt"
  @fs.write_string_to_file(path, "Hello moon\nhello tokenizer\n") catch {
    _ => ()
  }
  let base = Tokenizer::new(@model.Model::train_wordlevel_from_tokens([[]]))
    .with_normalizer(Some(@normalizer.Normalizer::Lowercase))
    .with_pre_tokenizer(Some(@pretokenizer.PreTokenizer::whitespace_split()))
  let trained = base.train_from_files(
    [path],
    Trainer::wordpiece(unk_token="[UNK]", min_frequency=1),
  )
  @test.assert_eq(
    trained.encode("HELLO", add_special_tokens=false).ids.length(),
    1,
  )
  @test.assert_eq(trained.to_json().contains("WordPiece"), true)
}

///|
test "Tokenizer train_from_files preserves line endings without pretokenizer" {
  let path = "_build/tokenizer_train_from_files_line_endings.txt"
  @fs.write_string_to_file(path, "aa\nbb\r\n") catch {
    _ => ()
  }
  let base = Tokenizer::new(@model.Model::train_wordlevel_from_tokens([[]]))
  let trained = base.train_from_files(
    [path],
    Trainer::wordlevel(unk_token="[UNK]", min_frequency=1),
  )
  @test.assert_eq(trained.token_to_id("aa\n") is Some(_), true)
  @test.assert_eq(trained.token_to_id("bb\r\n") is Some(_), true)
  @test.assert_eq(trained.token_to_id("aa"), None)
  @test.assert_eq(trained.token_to_id("bb"), None)
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
test "train_wordpiece supports HF end_of_word_suffix knob" {
  let tok = Tokenizer::train_wordpiece(
    ["low lower"],
    unk_token="[UNK]",
    continuing_subword_prefix="##",
    end_of_word_suffix=Some("</w>"),
    special_tokens=["[PAD]"],
  )
  assert_true(tok.token_to_id("low</w>") is Some(_))
  assert_true(tok.token_to_id("##w</w>") is Some(_))
  @test.assert_eq(tok.encode("low", add_special_tokens=false).tokens, [
    "low</w>",
  ])
  @test.assert_eq(tok.to_json().contains("\"end_of_word_suffix\""), true)
  let loaded = Tokenizer::from_str(tok.to_json())
  @test.assert_eq(loaded.encode("low", add_special_tokens=false).tokens, [
    "low</w>",
  ])
}

///|
test "train_wordpiece supports HF max_token_length knob" {
  let tok = Tokenizer::train_wordpiece(
    ["hello hell"],
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
    max_token_length=Some(3),
  )
  @test.assert_eq(tok.token_to_id("hello"), None)
  @test.assert_eq(tok.token_to_id("hell"), None)
  assert_true(tok.token_to_id("h") is Some(_))
  assert_true(tok.token_to_id("##e") is Some(_))
  assert_true(tok.token_to_id("##o") is Some(_))
  @test.assert_eq(tok.encode("hello", add_special_tokens=false).tokens, [
    "h", "##e", "##l", "##l", "##o",
  ])
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
  @test.assert_eq(tok.token_to_id("##b"), None)
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
test "train_bpe limit_alphabet includes initial alphabet in the cap" {
  let tok = Tokenizer::train_bpe(
    ["cccc bbb aa"],
    unk_token=Some("[UNK]"),
    min_frequency=10,
    initial_alphabet=["z"],
    limit_alphabet=Some(2),
  )
  @test.assert_eq(tok.token_to_id("z") is Some(_), true)
  @test.assert_eq(tok.token_to_id("c") is Some(_), true)
  @test.assert_eq(tok.token_to_id("b"), None)
  @test.assert_eq(tok.token_to_id("a"), None)
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
test "train_bpe strips continuation prefix from merged token surface" {
  let tok = Tokenizer::train_bpe(
    ["abab abab"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
    vocab_size=Some(16),
    continuing_subword_prefix=Some("@@"),
    end_of_word_suffix=Some("</w>"),
  )
  @test.assert_eq(tok.token_to_id("a@@b"), None)
  @test.assert_eq(tok.token_to_id("ab") is Some(_), true)
  @test.assert_eq(tok.token_to_id("aba") is Some(_), true)
  @test.assert_eq(tok.token_to_id("abab</w>") is Some(_), true)
  let enc = tok.encode("abab", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["abab</w>"])
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
test "Trainer bpe accepts compatibility knobs and special AddedToken" {
  let base = Tokenizer::new(@model.Model::train_wordlevel_from_tokens([[]])).with_pre_tokenizer(
    Some(@pretokenizer.PreTokenizer::whitespace_split()),
  )
  let trained = base.train_from_iterator(
    ["abab abab <s>"],
    Trainer::bpe(
      unk_token=Some("[UNK]"),
      min_frequency=2,
      special_added_tokens=[AddedToken::special("<s>").with_lstrip(true)],
      vocab_size=Some(16),
      continuing_subword_prefix=Some("@@"),
      end_of_word_suffix=Some("</w>"),
      max_token_length=Some(4),
      show_progress=false,
    ),
  )
  @test.assert_eq(trained.token_to_id("<s>"), Some(0))
  @test.assert_eq(
    trained.get_added_tokens_decoder().get(0).unwrap().lstrip,
    true,
  )
  @test.assert_eq(trained.token_to_id("a@@b"), None)
  @test.assert_eq(trained.encode("abab <s>", add_special_tokens=false).tokens, [
    "aba", "@@b</w>", " <s>",
  ])
}

///|
test "train_unigram prefers learned whole words" {
  let tok = Tokenizer::train_unigram(["hello hello help"], unk_token="<unk>", special_tokens=[
    "<pad>",
  ])
  @test.assert_eq(tok.token_to_id("<unk>"), Some(0))
  @test.assert_eq(tok.token_to_id("<pad>"), Some(1))
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
  @test.assert_eq(tok.token_to_id("<unk>"), Some(0))
  @test.assert_eq(tok.token_to_id("<pad>"), Some(1))
  @test.assert_eq(tok.token_to_id("ab"), None)
}

///|
test "train_unigram ranks deterministic candidates before applying vocab cap" {
  let tok = Tokenizer::train_unigram(
    ["alpha alpha alp alp ha ha"],
    unk_token="<unk>",
    vocab_size=Some(6),
    shrinking_factor=0.5,
    n_sub_iterations=4,
    show_progress=false,
  )
  @test.assert_eq(tok.get_vocab_size(), 6)
  @test.assert_eq(tok.token_to_id("<unk>"), Some(0))
  assert_true(tok.token_to_id("alpha") is Some(_))
  @test.assert_eq(tok.encode("alpha", add_special_tokens=false).tokens, [
    "alpha",
  ])
}

///|
test "train_unigram supports unk_piece and max_piece_length" {
  let tok = Tokenizer::train_unigram(
    ["hello hello"],
    unk_piece=Some("<UNK>"),
    special_tokens=["<pad>"],
    max_piece_length=Some(2),
    show_progress=false,
    shrinking_factor=0.5,
    n_sub_iterations=4,
  )
  @test.assert_eq(tok.token_to_id("<UNK>"), Some(0))
  @test.assert_eq(tok.token_to_id("<pad>"), Some(1))
  @test.assert_eq(tok.token_to_id("hello"), None)
  @test.assert_eq(tok.token_to_id("he") is Some(_), true)
  @test.assert_eq(tok.token_to_id("ll") is Some(_), true)
  let enc = tok.encode("hello", add_special_tokens=false)
  @test.assert_eq(enc.tokens, ["h", "el", "lo"])
  for token in enc.tokens {
    @test.assert_eq(token.char_length() <= 2, true)
  }
}

///|
test "train_unigram preserves initial alphabet" {
  let trainer = Trainer::unigram(
    unk_token="<unk>",
    initial_alphabet=["z", "xy", ""],
    vocab_size=Some(4),
    show_progress=false,
  )
  @test.assert_eq(trainer.initial_alphabet(), ["z", "xy", ""])
  let restored = Trainer::__setstate__(trainer.__getstate__())
  @test.assert_eq(restored.initial_alphabet(), ["z", "xy", ""])

  let tok = Tokenizer::new(@model.Model::train_wordlevel_from_tokens([[]])).train_from_iterator(
    ["aa aa"],
    trainer,
  )
  @test.assert_eq(tok.token_to_id("<unk>"), Some(0))
  @test.assert_eq(tok.token_to_id("z"), Some(1))
  // HF keeps only the first character from each initial_alphabet string.
  @test.assert_eq(tok.token_to_id("x"), Some(2))
  @test.assert_eq(tok.token_to_id("xy"), None)
  @test.assert_eq(tok.token_to_id("a"), Some(3))
  @test.assert_eq(tok.token_to_id("aa"), None)
}

///|
test "train_unigram seed_size caps ranked seeds after characters" {
  let chars_only = Tokenizer::train_unigram(
    ["ab ab"],
    unk_token="<unk>",
    seed_size=2,
    show_progress=false,
  )
  @test.assert_eq(chars_only.token_to_id("a") is Some(_), true)
  @test.assert_eq(chars_only.token_to_id("b") is Some(_), true)
  @test.assert_eq(chars_only.token_to_id("ab"), None)
  @test.assert_eq(chars_only.encode("ab", add_special_tokens=false).tokens, [
    "a", "b",
  ])

  let with_top_seed = Tokenizer::train_unigram(
    ["ab ab"],
    unk_token="<unk>",
    seed_size=3,
    show_progress=false,
  )
  @test.assert_eq(with_top_seed.token_to_id("a") is Some(_), true)
  @test.assert_eq(with_top_seed.token_to_id("b") is Some(_), true)
  @test.assert_eq(with_top_seed.token_to_id("ab") is Some(_), true)
  @test.assert_eq(with_top_seed.encode("ab", add_special_tokens=false).tokens, [
    "ab",
  ])
}

///|
test "train_unigram preserves explicit unk position in special tokens" {
  let tok = Tokenizer::train_unigram(
    ["hello hello"],
    unk_token="<unk>",
    special_tokens=["<pad>", "<unk>"],
    show_progress=false,
  )
  @test.assert_eq(tok.token_to_id("<pad>"), Some(0))
  @test.assert_eq(tok.token_to_id("<unk>"), Some(1))
}

///|
test "Trainer unigram preserves AddedToken metadata and advanced knobs" {
  let base = Tokenizer::new(@model.Model::train_wordlevel_from_tokens([[]])).with_pre_tokenizer(
    Some(@pretokenizer.PreTokenizer::whitespace_split()),
  )
  let trained = base.train_from_iterator(
    ["moon moon <extra>"],
    Trainer::unigram(
      unk_piece=Some("<UNK>"),
      special_added_tokens=[AddedToken::special("<extra>").with_rstrip(true)],
      max_piece_length=Some(2),
      shrinking_factor=0.5,
      n_sub_iterations=3,
      show_progress=false,
    ),
  )
  @test.assert_eq(trained.token_to_id("<UNK>"), Some(0))
  @test.assert_eq(trained.token_to_id("<extra>"), Some(1))
  @test.assert_eq(
    trained.get_added_tokens_decoder().get(1).unwrap().rstrip,
    true,
  )
  @test.assert_eq(trained.token_to_id("moon"), None)
  @test.assert_eq(
    trained.encode("moon <extra>", add_special_tokens=false).tokens,
    ["mo", "on", "<extra>"],
  )
}
