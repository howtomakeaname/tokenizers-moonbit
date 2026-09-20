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
  let tok = @tokenizer.Tokenizer::from_str(json)
  let e = tok.encode("a a a a a")
  @test.assert_eq(e.ids.length(), 6)
  @test.assert_eq(e.tokens[e.ids.length() - 1], "[PAD]")
  @test.assert_eq(e.attention_mask(), [1, 1, 1, 1, 1, 0])
}

///|
/// ByteLevel trim_offsets (HF byte_level.rs process_offsets): an
/// all-whitespace token collapses to its end; a real leading space is
/// trimmed; the single leading space added by add_prefix_space on the
/// first token is kept.
test "byte-level trim follows the authoritative rules" {
  // add_prefix_space=false: "  leading..." -> ĠĠ collapses to (2,2)
  let json_no_prefix =
    #|{"version":"1.0","pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":false,"trim_offsets":true},"model":{"type":"BPE","unk_token":"<|eot|>","vocab":{"ĠĠ":0,"l":1,"e":2,"a":3,"d":4,"i":5,"n":6,"g":7,"Ġ":8},"merges":[["Ġ","Ġ"]]},"post_processor":{"type":"ByteLevel","add_prefix_space":false,"trim_offsets":true}}
  let tok = @tokenizer.Tokenizer::from_str(json_no_prefix)
  let e = tok.encode("  leading")
  @test.assert_eq(e.tokens[0], "ĠĠ")
  @test.assert_eq(e.offsets[0], (2, 2))
  @test.assert_eq(e.offsets[1], (2, 3))
  // add_prefix_space=true + trim: the added prefix space maps to a
  // zero-width span at 0 and is kept on the first token
  let json_prefix =
    #|{"version":"1.0","pre_tokenizer":{"type":"ByteLevel","add_prefix_space":true,"use_regex":false,"trim_offsets":true},"model":{"type":"BPE","unk_token":"<|eot|>","vocab":{"a":0,"Ġb":1,"b":2,"Ġ":3},"merges":[["Ġ","b"]]},"post_processor":{"type":"ByteLevel","add_prefix_space":true,"trim_offsets":true}}
  let tok2 = @tokenizer.Tokenizer::from_str(json_prefix)
  let e2 = tok2.encode("a b")
  // the added prefix space maps to a zero-width span at 0 (Python 0.22.2)
  @test.assert_eq(e2.tokens, ["Ġ", "a", "Ġb"])
  @test.assert_eq(e2.offsets, [(0, 0), (0, 1), (2, 3)])
  // real leading space (not added by us) with aps=false post: trimmed
  // (Python 0.22.2 Roberta pair 'a'+' b' -> [(0,1),(1,2)]); note the
  // pair+aps pretokenizer path has a separate known gap (see PROGRESS).
  let json_pair =
    #|{"version":"1.0","pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":false,"trim_offsets":true},"model":{"type":"BPE","unk_token":"<|eot|>","vocab":{"a":0,"Ġb":1,"b":2,"Ġ":3},"merges":[["Ġ","b"]]},"post_processor":{"type":"RobertaProcessing","sep":["</s>",9],"cls":["<s>",8],"trim_offsets":true,"add_prefix_space":false}}
  let tok3 = @tokenizer.Tokenizer::from_str(json_pair)
  let p = tok3.encode_pair("a", " b", add_special_tokens=false)
  @test.assert_eq(p.tokens, ["a", "Ġb"])
  @test.assert_eq(p.offsets, [(0, 1), (1, 2)])
}

///|
/// Standalone StripAccents removes only already-decomposed combining
/// marks (precomposed é untouched); BertNormalizer strip_accents does
/// NFD-then-drop (é -> e).
test "standalone strip accents differs from bert strip accents" {
  // via a full tokenizer with an "é"-vs-"cafe"-sensitive vocab:
  // standalone keeps precomposed é intact, Bert strip_accents maps it to e
  let standalone_json =
    #|{"version":"1.0","normalizer":{"type":"StripAccents"},"model":{"type":"WordLevel","vocab":{"café":0,"cafe":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let standalone = @tokenizer.Tokenizer::from_str(standalone_json)
  @test.assert_eq(standalone.encode("café", add_special_tokens=false).ids, [0])
  @test.assert_eq(
    standalone.encode("cafe\u{301}", add_special_tokens=false).ids,
    [1],
  )
  let bert_json =
    #|{"version":"1.0","normalizer":{"type":"BertNormalizer","clean_text":false,"handle_chinese_chars":false,"strip_accents":true,"lowercase":false},"model":{"type":"WordLevel","vocab":{"café":0,"cafe":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let bert = @tokenizer.Tokenizer::from_str(bert_json)
  @test.assert_eq(bert.encode("café", add_special_tokens=false).ids, [1])
}

///|
/// Added-token id allocation (HF add_tokens): content already in the
/// model vocab reuses the model id; a declared id colliding with a
/// DIFFERENT vocab token is reassigned to vocab_size + counter.
test "added token ids reuse model ids and reassign collisions" {
  // reuse: [SPECIAL] declared 2, vocab has it as 0 -> id 0 everywhere
  let reuse_json =
    #|{"version":"1.0","added_tokens":[{"id":2,"content":"[SPECIAL]","special":true,"single_word":false,"lstrip":false,"rstrip":false,"normalized":false}],"model":{"type":"WordLevel","vocab":{"[SPECIAL]":0,"[UNK]":1},"unk_token":"[UNK]"}}
  let tok = @tokenizer.Tokenizer::from_str(reuse_json)
  @test.assert_eq(tok.encode("[SPECIAL]", add_special_tokens=false).ids, [0])
  // collision: <|eot|> declared 5 collides with vocab hello:5 -> vocab
  // size 3, reassigned to 3; hello keeps working
  let collision_json =
    #|{"version":"1.0","added_tokens":[{"id":5,"content":"<|eot|>","special":true,"single_word":false,"lstrip":false,"rstrip":false,"normalized":false}],"model":{"type":"WordLevel","vocab":{"hello":5,"world":6,"[UNK]":9},"unk_token":"[UNK]"}}
  let tok2 = @tokenizer.Tokenizer::from_str(collision_json)
  @test.assert_eq(tok2.token_to_id("hello"), Some(5))
  @test.assert_eq(tok2.token_to_id("<|eot|>"), Some(3))
}
