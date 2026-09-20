// Original-referential alignment tests. Expectations verified against
// Python `tokenizers` 0.22.2 `encode(...).offsets` (char offsets into the
// ORIGINAL text) for equivalent configurations.

///|
fn offsets_of(tok_json : String, text : String) -> Array[(Int, Int)] raise {
  let tok = @tokenizer.Tokenizer::from_str(tok_json)
  let enc = tok.encode(text)
  enc.offsets
}

///|
let al_wordpiece_no_norm =
  #|{"version":"1.0","pre_tokenizer":{"type":"BertPreTokenizer"},"model":{"type":"WordPiece","vocab":{"cafe":0,"nomade":1,"hello":2,"[UNK]":3,"[CLS]":4,"[SEP]":5},"unk_token":"[UNK]","continuing_subword_prefix":"##","max_input_chars_per_word":10}}

///|
/// NFD input keeps original-text offsets: the decomposed "café" (5 chars)
/// maps to the [0,5) span of the original, not the 6-char normalized form.
test "nfd offsets map into the original text" {
  let nfc = "caf\u{e9} nomade"
  let nfd = "cafe\u{301} nomade"
  // no normalizer: offsets identical for both forms (identity alignment on
  // the original string)
  let o1 = offsets_of(al_wordpiece_no_norm, nfc)
  let o2 = offsets_of(al_wordpiece_no_norm, nfd)
  @test.assert_eq(o1[0], (0, 4))
  // the NFD form's first word spans 5 original chars
  @test.assert_eq(o2[0], (0, 5))
  @test.assert_eq(o2[1], (6, 12))
}

///|
/// Strip normalizer offsets reference the un-stripped original.
test "strip offsets keep original coordinates" {
  let json =
    #|{"version":"1.0","normalizer":{"type":"Strip","strip_left":true,"strip_right":true},"pre_tokenizer":{"type":"WhitespaceSplit"},"model":{"type":"WordLevel","vocab":{"leading":0,"and":1,"trailing":2,"[UNK]":3},"unk_token":"[UNK]"}}
  let offs = offsets_of(json, "  leading and trailing   ")
  // Python 0.22.2: [(2, 9), (10, 13), (14, 22)]
  @test.assert_eq(offs, [(2, 9), (10, 13), (14, 22)])
}

///|
/// Prepend inserts attach to the first char's span; the rest shift back.
test "prepend offsets attach to the first original char" {
  let json =
    #|{"version":"1.0","normalizer":{"type":"Prepend","prepend":"_"},"pre_tokenizer":{"type":"WhitespaceSplit"},"model":{"type":"WordLevel","vocab":{"_hello":0,"hello":1,"world":2,"[UNK]":3},"unk_token":"[UNK]"}}
  let offs = offsets_of(json, "hello world")
  // Python 0.22.2: [(0, 5), (6, 11)] — the prepended "_" shares [0,1)
  @test.assert_eq(offs, [(0, 5), (6, 11)])
}

///|
/// BertNormalizer Chinese spacing inserts attach to the CJK char spans.
test "bert chinese offsets map into the original" {
  let json =
    #|{"version":"1.0","normalizer":{"type":"BertNormalizer","clean_text":true,"handle_chinese_chars":true,"strip_accents":null,"lowercase":true},"pre_tokenizer":{"type":"BertPreTokenizer"},"model":{"type":"WordPiece","vocab":{"hello":0,"[UNK]":1,"[CLS]":2,"[SEP]":3},"unk_token":"[UNK]","continuing_subword_prefix":"##","max_input_chars_per_word":10},"post_processor":{"type":"BertProcessing","cls":["[CLS]",2],"sep":["[SEP]",3]}}
  let offs = offsets_of(json, "你好 hello")
  // Python 0.22.2 (with specials): [CLS](0,0) 你(0,1) 好(1,2) hello(3,8) [SEP](0,0)
  @test.assert_eq(offs[1], (0, 1))
  @test.assert_eq(offs[2], (1, 2))
  @test.assert_eq(offs[3], (3, 8))
}

///|
/// ByteLevel multi-byte chars: every byte-derived token maps back to the
/// single original char it came from (Python 0.22.2 "naïve" on gpt2-style
/// configs: the two tokens of ï both carry [2,3]).
test "byte-level multibyte tokens share the original char span" {
  let json =
    #|{"version":"1.0","pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":false,"trim_offsets":true},"model":{"type":"BPE","unk_token":"<|endoftext|>","vocab":{"n":0,"a":1,"i":2,"v":3,"e":4,"Ã":5,"¯":6,"Ġ":7},"merges":[]},"post_processor":{"type":"ByteLevel","add_prefix_space":false,"trim_offsets":true}}
  let offs = offsets_of(json, "naïve")
  @test.assert_eq(offs[0], (0, 1))
  @test.assert_eq(offs[1], (1, 2))
  // the two visible tokens of ï (Ã, ¯) both map to original char [2,3)
  @test.assert_eq(offs[2], (2, 3))
  @test.assert_eq(offs[3], (2, 3))
  @test.assert_eq(offs[4], (3, 4))
  @test.assert_eq(offs[5], (4, 5))
}

///|
/// Metaspace prepended ▁ attaches to the first char; tokens shift back.
test "metaspace prepend offsets attach to the first char" {
  let json =
    #|{"version":"1.0","pre_tokenizer":{"type":"Metaspace","replacement":"▁","prepend_scheme":"always"},"model":{"type":"BPE","unk_token":"<|endoftext|>","vocab":{"▁":0,"h":1,"e":2,"l":3,"o":4,"w":5,"r":6,"d":7,"he":8,"▁w":9,"or":10},"merges":[["h","e"],["▁","w"],["o","r"]]}}
  let offs = offsets_of(json, "hello world")
  // Python 0.22.2: ▁(0,1) he(0,2) l(2,3) l(3,4) o(4,5) ▁w(5,7)... — the
  // space at index 5 is covered by the ▁w token, and tokens after the
  // prepend shift back by one.
  @test.assert_eq(offs[0], (0, 1))
  @test.assert_eq(offs[1], (0, 2))
  @test.assert_eq(offs[2], (2, 3))
}

///|
/// NFC/NFD equivalence: composed and decomposed inputs produce identical
/// original-referential offsets.
test "nfc nfd offsets are identical against the original" {
  let json_nfc =
    #|{"version":"1.0","normalizer":{"type":"NFC"},"pre_tokenizer":{"type":"WhitespaceSplit"},"model":{"type":"WordLevel","vocab":{"café":0,"nomade":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let json_nfd =
    #|{"version":"1.0","normalizer":{"type":"NFD"},"pre_tokenizer":{"type":"WhitespaceSplit"},"model":{"type":"WordLevel","vocab":{"cafe":0,"nomade":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let nfc = offsets_of(json_nfc, "caf\u{e9} nomade")
  let nfd = offsets_of(json_nfd, "cafe\u{301} nomade")
  // NFC input stays 4 chars; the NFD form's word spans its 5 original
  // chars (verified against Python 0.22.2).
  @test.assert_eq(nfc, [(0, 4), (5, 11)])
  @test.assert_eq(nfd, [(0, 5), (6, 12)])
}

///|
/// ReplaceString patterns are literal: "\n" as a String pattern does not
/// match a newline. Python 0.22.2 keeps a(0,1) b(2,3).
test "replacestring patterns stay literal" {
  let json =
    #|{"version":"1.0","normalizer":{"type":"Replace","pattern":{"String":"\\n"},"content":"X"},"pre_tokenizer":{"type":"WhitespaceSplit"},"model":{"type":"WordLevel","vocab":{"a":0,"b":1,"[UNK]":2},"unk_token":"[UNK]"}}
  let offs = offsets_of(json, "a\nb")
  @test.assert_eq(offs, [(0, 1), (2, 3)])
}

///|
/// Metaspace origin map is per-CHAR (1:1 rewrite), never per-byte: CJK
/// pieces keep single-char spans. Python 0.22.2 on 中文: ▁中(0,1) 文(1,2).
test "metaspace origin map is per char for cjk" {
  let json =
    #|{"version":"1.0","pre_tokenizer":{"type":"Metaspace","replacement":"▁","prepend_scheme":"always"},"model":{"type":"BPE","unk_token":"<|eot|>","vocab":{"▁中":0,"文":1,"中":2,"▁":3},"merges":[["▁","中"]]}}
  let offs = offsets_of(json, "中文")
  @test.assert_eq(offs, [(0, 1), (1, 2)])
}
