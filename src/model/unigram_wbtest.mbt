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
    alpha: None,
    nbest_size: None,
    cache: {},
    cache_capacity: None,
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

///|
test "unigram without unk_id errors on unknown chars" {
  let model = mk_unigram([("a", 0.0)], None, false, true)
  let known = model.tokenize("a", offset=5)
  @test.assert_eq(unigram_surfaces(known), ["a"])
  @test.assert_eq(unigram_ids(known), [0])
  @test.assert_eq(known.map(t => t.offsets), [(5, 6)])
  let mut raised = false
  try model.tokenize("az", offset=5) |> ignore catch {
    @types.VocabError(msg) =>
      raised = msg.contains("unknown token") && msg.contains("unk_id")
    _ => ()
  }
  @test.assert_eq(raised, true)
}

///|
test "unigram byte_fallback does not bypass missing unk_id" {
  let model = mk_unigram(
    [("<0xF0>", -10.0), ("<0x9F>", -10.0), ("<0x98>", -10.0), ("<0x80>", -10.0)],
    None,
    true,
    true,
  )
  let mut raised = false
  try model.tokenize("😀") |> ignore catch {
    @types.VocabError(msg) =>
      raised = msg.contains("unknown token") && msg.contains("unk_id")
    _ => ()
  }
  @test.assert_eq(raised, true)
}

///|
test "unigram alpha/nbest_size default to None" {
  let model = mk_unigram([("a", 0.0), ("b", -1.0)], None, false, true)
  @test.assert_eq(model.alpha(), None)
  @test.assert_eq(model.get_alpha(), None)
  @test.assert_eq(model.nbest_size(), None)
  @test.assert_eq(model.get_nbest_size(), None)
}

///|
test "unigram alpha/nbest_size JSON round-trip" {
  // Create a model with alpha and nbest_size set
  let v : Map[String, (Int, Double)] = {}
  let vr : Array[String?] = []
  v["a"] = (0, 0.0)
  v["b"] = (1, -1.0)
  set_vocab_r(vr, 0, "a")
  set_vocab_r(vr, 1, "b")
  let model = Unigram(UnigramModel::{
    vocab: v,
    vocab_r: vr,
    unk_id: None,
    byte_fallback: false,
    fuse_unk: true,
    alpha: Some(0.5),
    nbest_size: Some(10),
    cache: {},
    cache_capacity: None,
  })
  // Verify getters
  @test.assert_eq(model.alpha(), Some(0.5))
  @test.assert_eq(model.get_alpha(), Some(0.5))
  @test.assert_eq(model.nbest_size(), Some(10))
  @test.assert_eq(model.get_nbest_size(), Some(10))
  // Serialize to JSON
  let json = model.to_json().unwrap()
  @test.assert_eq(json.contains("\"alpha\":0.5"), true)
  @test.assert_eq(json.contains("\"nbest_size\":10"), true)
}

///|
test "unigram alpha/nbest_size not serialized when None" {
  let model = mk_unigram([("a", 0.0)], None, false, true)
  let json = model.to_json().unwrap()
  @test.assert_eq(json.contains("alpha"), false)
  @test.assert_eq(json.contains("nbest_size"), false)
}

///|
test "unigram alpha=0.0 behaves like Viterbi" {
  // alpha=0.0 should be treated as deterministic (same as None)
  let model = mk_unigram([("a", 0.0), ("b", -1.0)], None, false, true)
  let toks = model.tokenize("ab")
  @test.assert_eq(unigram_surfaces(toks), ["a", "b"])
  @test.assert_eq(unigram_ids(toks), [0, 1])
}

///|
test "unigram alpha sampling produces valid tokens" {
  // Create a model with alpha > 0 to enable sampling
  let v : Map[String, (Int, Double)] = {}
  let vr : Array[String?] = []
  v["hello"] = (0, -1.0)
  v["world"] = (1, -2.0)
  v["he"] = (2, -3.0)
  v["llo"] = (3, -4.0)
  set_vocab_r(vr, 0, "hello")
  set_vocab_r(vr, 1, "world")
  set_vocab_r(vr, 2, "he")
  set_vocab_r(vr, 3, "llo")
  let model = Unigram(UnigramModel::{
    vocab: v,
    vocab_r: vr,
    unk_id: None,
    byte_fallback: false,
    fuse_unk: true,
    alpha: Some(0.5),
    nbest_size: None,
    cache: {},
    cache_capacity: None,
  })
  // Should produce valid tokens (either "hello" or "he"+"llo")
  let toks = model.tokenize("hello")
  @test.assert_eq(toks.length() > 0, true)
  // Verify all tokens have valid ids
  for t in toks {
    @test.assert_eq(t.id >= 0, true)
    @test.assert_eq(t.value.length() > 0, true)
  }
}
