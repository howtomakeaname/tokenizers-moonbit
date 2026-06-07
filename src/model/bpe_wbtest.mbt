// BPE tokenize tests (non byte-level): a hand-built vocab/merges.

// Build a small BPE model directly (bypassing JSON) for algorithm tests.

///|
fn mk_bpe(
  vocab : Array[(String, Int)],
  merges : Array[(String, String)],
) -> Model {
  let v : Map[String, Int] = {}
  let vr : Array[String?] = []
  for kv in vocab {
    v[kv.0] = kv.1
    set_vocab_r(vr, kv.1, kv.0)
  }
  let m : Map[(String, String), Int] = {}
  for i, p in merges {
    m[p] = i
  }
  BPE(BPEModel::{
    vocab: v,
    vocab_r: vr,
    merges: m,
    unk_token: None,
    continuing_subword_prefix: None,
    end_of_word_suffix: None,
    fuse_unk: false,
    byte_fallback: false,
    ignore_merges: false,
    cache: {},
  })
}

///|
fn ids_of(tokens : Array[@types.Token]) -> Array[Int] {
  tokens.map(t => t.id)
}

///|
fn surfaces_of(tokens : Array[@types.Token]) -> Array[String] {
  tokens.map(t => t.value)
}

///|
test "bpe merges adjacent pairs by rank" {
  // chars: l o w e r ; merges build: lo, low, we, wer? choose ranks.
  let model = mk_bpe(
    [
      ("l", 0),
      ("o", 1),
      ("w", 2),
      ("e", 3),
      ("r", 4),
      ("lo", 5),
      ("low", 6),
      ("er", 7),
      ("lower", 8),
    ],
    // rank order: first merge l+o, then lo+w, then e+r, then low+er
    [("l", "o"), ("lo", "w"), ("e", "r"), ("low", "er")],
  )
  let toks = model.tokenize("lower")
  @test.assert_eq(surfaces_of(toks), ["lower"])
  @test.assert_eq(ids_of(toks), [8])
}

///|
test "bpe stops when no merge applies and leaves separate symbols" {
  let model = mk_bpe([("a", 0), ("b", 1), ("c", 2), ("ab", 3)], [("a", "b")])
  let toks = model.tokenize("abc")
  @test.assert_eq(surfaces_of(toks), ["ab", "c"])
  @test.assert_eq(ids_of(toks), [3, 2])
}

///|
test "bpe respects merge ranks over greedy order" {
  // "ab" and "bc" both exist; rank says merge b+c first.
  let model = mk_bpe(
    [("a", 0), ("b", 1), ("c", 2), ("ab", 3), ("bc", 4), ("abc", 5)],
    // b+c has lower rank than a+b, so bc forms first -> then a + bc, no abc merge
    [("b", "c"), ("a", "b")],
  )
  let toks = model.tokenize("abc")
  // After b+c -> "a","bc"; pair (a,bc) not in merges -> stop.
  @test.assert_eq(surfaces_of(toks), ["a", "bc"])
}

///|
test "bpe offsets track code-point spans" {
  let model = mk_bpe([("a", 0), ("b", 1), ("ab", 2)], [("a", "b")])
  let toks = model.tokenize("ab", offset=3)
  @test.assert_eq(toks[0].offsets, (3, 5))
}

///|
test "legacy merge splitter preserves right side spaces" {
  @test.assert_eq(split_legacy_merge("Ġ t"), ("Ġ", "t"))
  @test.assert_eq(split_legacy_merge("a b c"), ("a", "b c"))
  @test.assert_eq(split_legacy_merge("abc"), ("abc", ""))
}
