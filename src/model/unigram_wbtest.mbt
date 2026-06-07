// Unigram byte_fallback / fuse_unk white-box tests.

///|
fn mk_unigram(
  vocab : Array[(String, Double)],
  unk_id : Int?,
  byte_fallback : Bool,
  fuse_unk : Bool,
) -> Model {
  let v : Map[String, (Int, Double)] = {}
  let vr : Array[String?] = []
  for i, kv in vocab {
    v[kv.0] = (i, kv.1)
    set_vocab_r(vr, i, kv.0)
  }
  Unigram(UnigramModel::{
    vocab: v,
    vocab_r: vr,
    unk_id,
    byte_fallback,
    fuse_unk,
    cache: {},
  })
}

///|
fn unigram_surfaces(tokens : Array[@types.Token]) -> Array[String] {
  tokens.map(t => t.value)
}

///|
fn unigram_ids(tokens : Array[@types.Token]) -> Array[Int] {
  tokens.map(t => t.id)
}

///|
test "unigram byte_fallback emits utf8 byte tokens" {
  let model = mk_unigram(
    [
      ("<unk>", 0.0),
      ("a", -1.0),
      ("<0xF0>", -10.0),
      ("<0x9F>", -10.0),
      ("<0x98>", -10.0),
      ("<0x80>", -10.0),
    ],
    Some(0),
    true,
    true,
  )
  let toks = model.tokenize("a😀", offset=7)
  @test.assert_eq(unigram_surfaces(toks), [
    "a", "<0xF0>", "<0x9F>", "<0x98>", "<0x80>",
  ])
  @test.assert_eq(unigram_ids(toks), [1, 2, 3, 4, 5])
  @test.assert_eq(toks[1].offsets, (8, 9))
  @test.assert_eq(toks[4].offsets, (8, 9))
}

///|
test "unigram byte_fallback requires all byte tokens" {
  let model = mk_unigram(
    [("<unk>", 0.0), ("<0xF0>", -10.0), ("<0x9F>", -10.0)],
    Some(0),
    true,
    true,
  )
  let toks = model.tokenize("😀")
  // Missing <0x98>/<0x80>, so the original unk fallback is preserved.
  @test.assert_eq(unigram_surfaces(toks), ["😀"])
  @test.assert_eq(unigram_ids(toks), [0])
}
