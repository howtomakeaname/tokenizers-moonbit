// Whitebox tests for Model setter aliases (Python binding compatibility).

///|
test "Model::set_unk_token for BPE" {
  let m = mk_bpe(
    [("hello", 0), ("world", 1), ("<unk>", 2)],
    [],
    unk_token=Some("<unk>"),
  )
  @test.assert_eq(m.unk_token(), Some("<unk>"))
  let m2 = m.set_unk_token("[UNK]")
  @test.assert_eq(m2.unk_token(), Some("[UNK]"))
  // Original unchanged
  @test.assert_eq(m.unk_token(), Some("<unk>"))
}

///|
test "Model::set_unk_token for WordPiece" {
  let v : Map[String, Int] = { "hello": 0, "world": 1, "[UNK]": 2 }
  let vr : Array[String?] = []
  set_vocab_r(vr, 0, "hello")
  set_vocab_r(vr, 1, "world")
  set_vocab_r(vr, 2, "[UNK]")
  let m = WordPiece(WordPieceModel::{
    vocab: v,
    vocab_r: vr,
    unk_token: "[UNK]",
    continuing_subword_prefix: "##",
    end_of_word_suffix: None,
    max_input_chars_per_word: 100,
    cache: {},
    cache_capacity: None,
  })
  @test.assert_eq(m.unk_token(), Some("[UNK]"))
  let m2 = m.set_unk_token("<unk>")
  @test.assert_eq(m2.unk_token(), Some("<unk>"))
}

///|
test "Model::set_dropout for BPE" {
  let m = mk_bpe([("a", 0)], [], unk_token=None)
  @test.assert_eq(m.dropout(), None)
  let m2 = m.set_dropout(Some(0.5))
  @test.assert_eq(m2.dropout(), Some(0.5))
  let m3 = m2.set_dropout(None)
  @test.assert_eq(m3.dropout(), None)
}

///|
test "Model::set_dropout for non-BPE returns self" {
  let vr : Array[String?] = []
  set_vocab_r(vr, 0, "a")
  let m = Unigram(UnigramModel::{
    vocab: { "a": (0, -1.0) },
    vocab_r: vr,
    unk_id: None,
    byte_fallback: false,
    fuse_unk: false,
    alpha: None,
    nbest_size: None,
    cache: {},
    cache_capacity: None,
  })
  // set_dropout on Unigram should be a no-op
  let m2 = m.set_dropout(Some(0.5))
  @test.assert_eq(m2.dropout(), None)
}

///|
test "Model::set_continuing_subword_prefix for BPE" {
  let m = mk_bpe([("a", 0)], [])
  @test.assert_eq(m.continuing_subword_prefix(), None)
  let m2 = m.set_continuing_subword_prefix(Some("##"))
  @test.assert_eq(m2.continuing_subword_prefix(), Some("##"))
}

///|
test "Model::set_end_of_word_suffix for BPE" {
  let m = mk_bpe([("a", 0)], [])
  @test.assert_eq(m.end_of_word_suffix(), None)
  let m2 = m.set_end_of_word_suffix(Some("</w>"))
  @test.assert_eq(m2.end_of_word_suffix(), Some("</w>"))
}

///|
test "Model::set_byte_fallback for BPE" {
  let m = mk_bpe([("a", 0)], [])
  @test.assert_eq(m.byte_fallback(), Some(false))
  let m2 = m.set_byte_fallback(true)
  @test.assert_eq(m2.byte_fallback(), Some(true))
}

///|
test "Model::set_fuse_unk for BPE" {
  let m = mk_bpe([("a", 0)], [], unk_token=Some("<unk>"))
  @test.assert_eq(m.fuse_unk(), Some(false))
  let m2 = m.set_fuse_unk(true)
  @test.assert_eq(m2.fuse_unk(), Some(true))
}

///|
test "Model::set_ignore_merges for BPE" {
  let m = mk_bpe([("a", 0)], [])
  @test.assert_eq(m.ignore_merges(), Some(false))
  let m2 = m.set_ignore_merges(true)
  @test.assert_eq(m2.ignore_merges(), Some(true))
}

///|
test "Model::set_alpha for Unigram" {
  let vr : Array[String?] = []
  set_vocab_r(vr, 0, "a")
  let m = Unigram(UnigramModel::{
    vocab: { "a": (0, -1.0) },
    vocab_r: vr,
    unk_id: None,
    byte_fallback: false,
    fuse_unk: false,
    alpha: None,
    nbest_size: None,
    cache: {},
    cache_capacity: None,
  })
  @test.assert_eq(m.alpha(), None)
  let m2 = m.set_alpha(Some(0.5))
  @test.assert_eq(m2.alpha(), Some(0.5))
}

///|
test "Model::set_nbest_size for Unigram" {
  let vr : Array[String?] = []
  set_vocab_r(vr, 0, "a")
  let m = Unigram(UnigramModel::{
    vocab: { "a": (0, -1.0) },
    vocab_r: vr,
    unk_id: None,
    byte_fallback: false,
    fuse_unk: false,
    alpha: None,
    nbest_size: None,
    cache: {},
    cache_capacity: None,
  })
  @test.assert_eq(m.nbest_size(), None)
  let m2 = m.set_nbest_size(Some(10))
  @test.assert_eq(m2.nbest_size(), Some(10))
}

///|
test "Model::set_max_input_chars_per_word for WordPiece" {
  let v : Map[String, Int] = { "a": 0 }
  let vr : Array[String?] = []
  set_vocab_r(vr, 0, "a")
  let m = WordPiece(WordPieceModel::{
    vocab: v,
    vocab_r: vr,
    unk_token: "[UNK]",
    continuing_subword_prefix: "##",
    end_of_word_suffix: None,
    max_input_chars_per_word: 100,
    cache: {},
    cache_capacity: None,
  })
  @test.assert_eq(m.max_input_chars_per_word(), Some(100))
  let m2 = m.set_max_input_chars_per_word(200)
  @test.assert_eq(m2.max_input_chars_per_word(), Some(200))
}
