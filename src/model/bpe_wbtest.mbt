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
    dropout: None,
    dropout_rng_state: 1,
    cache: {},
    cache_capacity: None,
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

///|
test "bpe trainer keeps caller initial alphabet" {
  let model = Model::train_bpe(
    ["ab ab"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
    initial_alphabet=["z"],
  )
  @test.assert_eq(model.token_to_id("z") is Some(_), true)
  @test.assert_eq(model.token_to_id("ab") is Some(_), true)
}

///|
test "bpe trainer limit_alphabet includes initial alphabet in the cap" {
  let model = Model::train_bpe(
    ["ccc bb a"],
    unk_token=Some("[UNK]"),
    min_frequency=10,
    initial_alphabet=["z"],
    limit_alphabet=Some(2),
  )
  @test.assert_eq(model.token_to_id("z") is Some(_), true)
  @test.assert_eq(model.token_to_id("c") is Some(_), true)
  @test.assert_eq(model.token_to_id("b"), None)
  @test.assert_eq(model.token_to_id("a"), None)
}

///|
test "bpe trainer max_token_length filters long merges" {
  let capped = Model::train_bpe(
    ["aaaaaaaa aaaaaaaa"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
    vocab_size=Some(32),
    max_token_length=Some(2),
  )
  @test.assert_eq(capped.token_to_id("aa") is Some(_), true)
  @test.assert_eq(capped.token_to_id("aaaa"), None)
  @test.assert_eq(capped.token_to_id("aaaaaaaa"), None)

  let uncapped = Model::train_bpe(
    ["aaaaaaaa aaaaaaaa"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
    vocab_size=Some(32),
  )
  @test.assert_eq(uncapped.token_to_id("aaaaaaaa") is Some(_), true)
}

///|
test "bpe trainer max_token_length does not drop initial alphabet" {
  let model = Model::train_bpe(
    ["ab ab"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
    initial_alphabet=["zz"],
    max_token_length=Some(1),
  )
  @test.assert_eq(model.token_to_id("z") is Some(_), true)
  @test.assert_eq(model.token_to_id("ab"), None)
}

///|
test "model JSON state aliases round-trip serializable models" {
  let bpe = Model::train_bpe(
    ["abab abab"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
    continuing_subword_prefix=Some("@@"),
    end_of_word_suffix=Some("</w>"),
  )
  let bpe_state = bpe.__getstate__()
  @test.assert_eq(bpe.__str__(), bpe_state.json)
  @test.assert_eq(bpe.__repr__(), bpe_state.json)
  @test.assert_eq(Model::__setstate__(bpe_state).to_json(), bpe.to_json())
  @test.assert_eq(
    Model::from_state(ModelState::new(bpe.__str__()))
    .tokenize("abab")
    .map(t => t.value),
    bpe.tokenize("abab").map(t => t.value),
  )

  let wordlevel = Model::train_wordlevel_from_tokens(
    [["hello", "[UNK]"]],
    unk_token="[UNK]",
  )
  @test.assert_eq(
    Model::__setstate__(wordlevel.__getstate__()).to_json(),
    wordlevel.to_json(),
  )

  let wordpiece = Model::train_wordpiece(
    ["hello hello"],
    unk_token="[UNK]",
    continuing_subword_prefix="##",
  )
  @test.assert_eq(
    Model::__setstate__(wordpiece.__getstate__()).to_json(),
    wordpiece.to_json(),
  )

  let unigram = Model::train_unigram(
    ["hello hello"],
    unk_token="<unk>",
    show_progress=false,
  )
  @test.assert_eq(
    Model::__setstate__(unigram.__getstate__()).to_json(),
    unigram.to_json(),
  )
}

///|
test "model unigram trainer accepts unk_piece alias" {
  let unigram = Model::train_unigram(
    ["hello hello help"],
    unk_token="<unused>",
    unk_piece=Some("<UNK>"),
    min_frequency=1,
    show_progress=false,
  )
  @test.assert_eq(unigram.kind(), "Unigram")
  @test.assert_eq(unigram.unk_token(), Some("<UNK>"))
  @test.assert_eq(unigram.unk_id(), unigram.token_to_id("<UNK>"))
  @test.assert_eq(unigram.token_to_id("<unused>"), None)

  let from_tokens = Model::train_unigram_from_tokens(
    [["hello", "hello"]],
    unk_token="<unused>",
    unk_piece=Some("<TOK_UNK>"),
    show_progress=false,
  )
  @test.assert_eq(from_tokens.unk_token(), Some("<TOK_UNK>"))
  @test.assert_eq(from_tokens.token_to_id("<unused>"), None)
}

///|
test "model exposes HF-style cache maintenance aliases" {
  let bpe = Model::train_bpe(
    ["lower lower"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
  )
  ignore(bpe.tokenize("lower"))
  @test.assert_eq(bpe.cache_size(), 1)
  bpe._clear_cache()
  @test.assert_eq(bpe.cache_size(), 0)
  bpe._resize_cache(0)
  ignore(bpe.tokenize("lower"))
  @test.assert_eq(bpe.cache_size(), 0)
  bpe._resize_cache(1)
  ignore(bpe.tokenize("lower"))
  ignore(bpe.tokenize("low"))
  @test.assert_eq(bpe.cache_size(), 1)
}

///|
test "standalone model artifact loaders round trip saved artifacts" {
  let dir = "_build/model-artifact-loaders"
  let bpe = Model::train_bpe(
    ["abab abab"],
    unk_token=Some("[UNK]"),
    min_frequency=2,
    vocab_size=Some(16),
  )
  let bpe_paths = bpe.save(dir, prefix="bpe") catch {
    _ => abort("save bpe artifacts failed")
  }
  let loaded_bpe = Model::from_bpe_files(bpe_paths[0], bpe_paths[1]) catch {
    _ => abort("load bpe artifacts failed")
  }
  @test.assert_eq(loaded_bpe.kind(), "BPE")
  @test.assert_eq(loaded_bpe.token_to_id("ab"), bpe.token_to_id("ab"))
  @test.assert_eq(
    loaded_bpe.id_to_token(loaded_bpe.token_to_id("ab").unwrap()),
    Some("ab"),
  )
  @test.assert_eq(loaded_bpe.tokenize("abab").map(t => t.value), ["abab"])

  let wordpiece = Model::train_wordpiece(
    ["hello hello"],
    unk_token="[UNK]",
    continuing_subword_prefix="##",
  )
  let wordpiece_paths = wordpiece.save(dir, prefix="wp") catch {
    _ => abort("save wordpiece artifact failed")
  }
  let loaded_wordpiece = Model::from_wordpiece_file(wordpiece_paths[0]) catch {
    _ => abort("load wordpiece artifact failed")
  }
  @test.assert_eq(loaded_wordpiece.kind(), "WordPiece")
  @test.assert_eq(
    loaded_wordpiece.token_to_id("hello"),
    wordpiece.token_to_id("hello"),
  )
  @test.assert_eq(
    loaded_wordpiece.id_to_token(loaded_wordpiece.token_to_id("hello").unwrap()),
    Some("hello"),
  )
  @test.assert_eq(loaded_wordpiece.tokenize("hello").map(t => t.value), [
    "hello",
  ])

  let wordlevel = Model::train_wordlevel_from_tokens(
    [["hello", "[UNK]"]],
    unk_token="[UNK]",
  )
  let wordlevel_paths = wordlevel.save(dir, prefix="wl") catch {
    _ => abort("save wordlevel artifact failed")
  }
  let loaded_wordlevel = Model::from_wordlevel_file(wordlevel_paths[0]) catch {
    _ => abort("load wordlevel artifact failed")
  }
  @test.assert_eq(loaded_wordlevel.kind(), "WordLevel")
  @test.assert_eq(
    loaded_wordlevel.token_to_id("hello"),
    wordlevel.token_to_id("hello"),
  )
  @test.assert_eq(
    loaded_wordlevel.id_to_token(loaded_wordlevel.token_to_id("hello").unwrap()),
    Some("hello"),
  )
  @test.assert_eq(loaded_wordlevel.tokenize("missing").map(t => t.value), [
    "[UNK]",
  ])
}

///|
test "bpe standalone loader skips version comments and reads text merges" {
  let dir = "_build/model-artifact-loaders"
  ensure_dir(dir) catch {
    _ => abort("create loader test dir failed")
  }
  let vocab_path = dir + "/manual-bpe-vocab.json"
  let merges_path = dir + "/manual-bpe-merges.txt"
  write_artifact(
    vocab_path, "{\"[UNK]\":0,\"l\":1,\"o\":2,\"w\":3,\"lo\":4,\"low\":5}",
  ) catch {
    _ => abort("write manual bpe vocab failed")
  }
  write_artifact(merges_path, "#version: 0.2\nl o\nlo w\n") catch {
    _ => abort("write manual bpe merges failed")
  }
  let loaded = Model::from_bpe_files(vocab_path, merges_path) catch {
    _ => abort("load manual bpe artifacts failed")
  }
  @test.assert_eq(loaded.token_to_id("low"), Some(5))
  @test.assert_eq(loaded.id_to_token(5), Some("low"))
  @test.assert_eq(loaded.tokenize("low").map(t => t.value), ["low"])
}
