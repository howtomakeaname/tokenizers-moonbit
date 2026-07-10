///|
test "Trainer set_unk_token" {
  // WordLevel: String -> should be set
  let wl = Trainer::wordlevel(unk_token="[UNK]")
  let wl2 = wl.set_unk_token(Some("[PAD]"))
  @test.assert_eq(wl2.get_unk_token(), Some("[PAD]"))

  // WordPiece: String -> should be set
  let wp = Trainer::wordpiece(unk_token="[UNK]")
  let wp2 = wp.set_unk_token(Some("[PAD]"))
  @test.assert_eq(wp2.get_unk_token(), Some("[PAD]"))

  // BPE: String? -> should be set
  let bpe = Trainer::bpe(unk_token=None)
  let bpe2 = bpe.set_unk_token(Some("[PAD]"))
  @test.assert_eq(bpe2.get_unk_token(), Some("[PAD]"))

  // Unigram: String? -> should be set
  let uni = Trainer::unigram(unk_token=None)
  let uni2 = uni.set_unk_token(Some("[PAD]"))
  @test.assert_eq(uni2.get_unk_token(), Some("[PAD]"))
}

///|
test "Trainer set_unk_token_alias" {
  let wl = Trainer::wordlevel(unk_token="[UNK]")
  let wl2 = wl.set_unk_token_alias(Some("[PAD]"))
  @test.assert_eq(wl2.get_unk_token(), Some("[PAD]"))
}

///|
test "Trainer set_min_frequency" {
  let wl = Trainer::wordlevel(min_frequency=0)
  let wl2 = wl.set_min_frequency(5)
  @test.assert_eq(wl2.get_min_frequency(), 5)

  let bpe = Trainer::bpe(min_frequency=0)
  let bpe2 = bpe.set_min_frequency(10)
  @test.assert_eq(bpe2.get_min_frequency(), 10)
}

///|
test "Trainer set_min_frequency_alias" {
  let wl = Trainer::wordlevel(min_frequency=0)
  let wl2 = wl.set_min_frequency_alias(5)
  @test.assert_eq(wl2.get_min_frequency(), 5)
}

///|
test "Trainer set_special_tokens" {
  let wl = Trainer::wordlevel(special_tokens=["[PAD]"])
  let wl2 = wl.set_special_tokens(["[CLS]", "[SEP]"])
  @test.assert_eq(wl2.get_special_tokens(), ["[CLS]", "[SEP]"])
}

///|
test "Trainer set_special_tokens_alias" {
  let wl = Trainer::wordlevel(special_tokens=["[PAD]"])
  let wl2 = wl.set_special_tokens_alias(["[CLS]", "[SEP]"])
  @test.assert_eq(wl2.get_special_tokens(), ["[CLS]", "[SEP]"])
}

///|
test "Trainer set_special_added_tokens" {
  let mask = AddedToken::special("[MASK]")
  let cls = AddedToken::special("[CLS]")
  let wl = Trainer::wordlevel(special_added_tokens=[mask])
  let wl2 = wl.set_special_added_tokens([cls])
  @test.assert_eq(wl2.get_special_added_tokens()[0].content(), "[CLS]")
}

///|
test "Trainer set_special_added_tokens_alias" {
  let mask = AddedToken::special("[MASK]")
  let cls = AddedToken::special("[CLS]")
  let wl = Trainer::wordlevel(special_added_tokens=[mask])
  let wl2 = wl.set_special_added_tokens_alias([cls])
  @test.assert_eq(wl2.get_special_added_tokens()[0].content(), "[CLS]")
}

///|
test "Trainer set_vocab_size" {
  let wl = Trainer::wordlevel(vocab_size=Some(30000))
  let wl2 = wl.set_vocab_size(Some(50000))
  @test.assert_eq(wl2.get_vocab_size(), Some(50000))

  let bpe = Trainer::bpe(vocab_size=Some(30000))
  let bpe2 = bpe.set_vocab_size(None)
  @test.assert_eq(bpe2.get_vocab_size(), None)
}

///|
test "Trainer set_vocab_size_alias" {
  let wl = Trainer::wordlevel(vocab_size=Some(30000))
  let wl2 = wl.set_vocab_size_alias(Some(50000))
  @test.assert_eq(wl2.get_vocab_size(), Some(50000))
}

///|
test "Trainer set_show_progress" {
  let wl = Trainer::wordlevel(show_progress=true)
  let wl2 = wl.set_show_progress(false)
  @test.assert_eq(wl2.get_show_progress(), false)

  let bpe = Trainer::bpe(show_progress=true)
  let bpe2 = bpe.set_show_progress(false)
  @test.assert_eq(bpe2.get_show_progress(), false)
}

///|
test "Trainer set_show_progress_alias" {
  let wl = Trainer::wordlevel(show_progress=true)
  let wl2 = wl.set_show_progress_alias(false)
  @test.assert_eq(wl2.get_show_progress(), false)
}

///|
test "Trainer set_continuing_subword_prefix" {
  // WordPiece: String -> should be set
  let wp = Trainer::wordpiece(continuing_subword_prefix="##")
  let wp2 = wp.set_continuing_subword_prefix(Some("@@"))
  @test.assert_eq(wp2.get_continuing_subword_prefix(), Some("@@"))

  // BPE: String? -> should be set
  let bpe = Trainer::bpe(continuing_subword_prefix=None)
  let bpe2 = bpe.set_continuing_subword_prefix(Some("@@"))
  @test.assert_eq(bpe2.get_continuing_subword_prefix(), Some("@@"))

  // Non-matching variant returns self
  let wl = Trainer::wordlevel()
  @test.assert_eq(
    wl.set_continuing_subword_prefix(Some("##")).kind(),
    "WordLevelTrainer",
  )
}

///|
test "Trainer set_continuing_subword_prefix_alias" {
  let wp = Trainer::wordpiece(continuing_subword_prefix="##")
  let wp2 = wp.set_continuing_subword_prefix_alias(Some("@@"))
  @test.assert_eq(wp2.get_continuing_subword_prefix(), Some("@@"))
}

///|
test "Trainer set_end_of_word_suffix" {
  let wp = Trainer::wordpiece(end_of_word_suffix=None)
  let wp2 = wp.set_end_of_word_suffix(Some("</w>"))
  @test.assert_eq(wp2.get_end_of_word_suffix(), Some("</w>"))

  let bpe = Trainer::bpe(end_of_word_suffix=None)
  let bpe2 = bpe.set_end_of_word_suffix(Some("</w>"))
  @test.assert_eq(bpe2.get_end_of_word_suffix(), Some("</w>"))

  // Non-matching variant returns self
  let wl = Trainer::wordlevel()
  @test.assert_eq(
    wl.set_end_of_word_suffix(Some("</w>")).kind(),
    "WordLevelTrainer",
  )
}

///|
test "Trainer set_end_of_word_suffix_alias" {
  let wp = Trainer::wordpiece(end_of_word_suffix=None)
  let wp2 = wp.set_end_of_word_suffix_alias(Some("</w>"))
  @test.assert_eq(wp2.get_end_of_word_suffix(), Some("</w>"))
}

///|
test "Trainer set_max_input_chars_per_word" {
  let wp = Trainer::wordpiece(max_input_chars_per_word=100)
  let wp2 = wp.set_max_input_chars_per_word(200)
  @test.assert_eq(wp2.get_max_input_chars_per_word(), Some(200))

  // Non-matching variant returns self
  let bpe = Trainer::bpe()
  @test.assert_eq(bpe.set_max_input_chars_per_word(200).kind(), "BpeTrainer")
}

///|
test "Trainer set_max_input_chars_per_word_alias" {
  let wp = Trainer::wordpiece(max_input_chars_per_word=100)
  let wp2 = wp.set_max_input_chars_per_word_alias(200)
  @test.assert_eq(wp2.get_max_input_chars_per_word(), Some(200))
}

///|
test "Trainer set_max_token_length" {
  let wp = Trainer::wordpiece(max_token_length=None)
  let wp2 = wp.set_max_token_length(Some(10))
  @test.assert_eq(wp2.get_max_token_length(), Some(10))

  let bpe = Trainer::bpe(max_token_length=None)
  let bpe2 = bpe.set_max_token_length(Some(15))
  @test.assert_eq(bpe2.get_max_token_length(), Some(15))

  // Non-matching variant returns self
  let uni = Trainer::unigram()
  @test.assert_eq(uni.set_max_token_length(Some(10)).kind(), "UnigramTrainer")
}

///|
test "Trainer set_max_token_length_alias" {
  let wp = Trainer::wordpiece(max_token_length=None)
  let wp2 = wp.set_max_token_length_alias(Some(10))
  @test.assert_eq(wp2.get_max_token_length(), Some(10))
}

///|
test "Trainer set_initial_alphabet" {
  let wp = Trainer::wordpiece(initial_alphabet=[])
  let wp2 = wp.set_initial_alphabet(["a", "b", "c"])
  @test.assert_eq(wp2.get_initial_alphabet(), ["a", "b", "c"])

  let bpe = Trainer::bpe(initial_alphabet=[])
  let bpe2 = bpe.set_initial_alphabet(["x", "y"])
  @test.assert_eq(bpe2.get_initial_alphabet(), ["x", "y"])

  let uni = Trainer::unigram(initial_alphabet=[])
  let uni2 = uni.set_initial_alphabet(["z"])
  @test.assert_eq(uni2.get_initial_alphabet(), ["z"])

  // Non-matching variant returns self
  let wl = Trainer::wordlevel()
  @test.assert_eq(wl.set_initial_alphabet(["a"]).kind(), "WordLevelTrainer")
}

///|
test "Trainer set_initial_alphabet_alias" {
  let wp = Trainer::wordpiece(initial_alphabet=[])
  let wp2 = wp.set_initial_alphabet_alias(["a", "b"])
  @test.assert_eq(wp2.get_initial_alphabet(), ["a", "b"])
}

///|
test "Trainer set_limit_alphabet" {
  let wp = Trainer::wordpiece(limit_alphabet=None)
  let wp2 = wp.set_limit_alphabet(Some(100))
  @test.assert_eq(wp2.get_limit_alphabet(), Some(100))

  let bpe = Trainer::bpe(limit_alphabet=None)
  let bpe2 = bpe.set_limit_alphabet(Some(200))
  @test.assert_eq(bpe2.get_limit_alphabet(), Some(200))

  // Non-matching variant returns self
  let uni = Trainer::unigram()
  @test.assert_eq(uni.set_limit_alphabet(Some(100)).kind(), "UnigramTrainer")
}

///|
test "Trainer set_limit_alphabet_alias" {
  let wp = Trainer::wordpiece(limit_alphabet=None)
  let wp2 = wp.set_limit_alphabet_alias(Some(100))
  @test.assert_eq(wp2.get_limit_alphabet(), Some(100))
}

///|
test "Trainer set_fuse_unk" {
  let bpe = Trainer::bpe(fuse_unk=false)
  let bpe2 = bpe.set_fuse_unk(true)
  @test.assert_eq(bpe2.get_fuse_unk(), Some(true))

  let uni = Trainer::unigram(fuse_unk=true)
  let uni2 = uni.set_fuse_unk(false)
  @test.assert_eq(uni2.get_fuse_unk(), Some(false))

  // Non-matching variant returns self
  let wp = Trainer::wordpiece()
  @test.assert_eq(wp.set_fuse_unk(true).kind(), "WordPieceTrainer")
}

///|
test "Trainer set_fuse_unk_alias" {
  let bpe = Trainer::bpe(fuse_unk=false)
  let bpe2 = bpe.set_fuse_unk_alias(true)
  @test.assert_eq(bpe2.get_fuse_unk(), Some(true))
}

///|
test "Trainer set_byte_fallback" {
  let uni = Trainer::unigram(byte_fallback=false)
  let uni2 = uni.set_byte_fallback(true)
  @test.assert_eq(uni2.get_byte_fallback(), Some(true))

  // Non-matching variant returns self
  let bpe = Trainer::bpe()
  @test.assert_eq(bpe.set_byte_fallback(true).kind(), "BpeTrainer")
}

///|
test "Trainer set_byte_fallback_alias" {
  let uni = Trainer::unigram(byte_fallback=false)
  let uni2 = uni.set_byte_fallback_alias(true)
  @test.assert_eq(uni2.get_byte_fallback(), Some(true))
}

///|
test "Trainer set_shrinking_factor" {
  let uni = Trainer::unigram(shrinking_factor=0.75)
  let uni2 = uni.set_shrinking_factor(0.5)
  @test.assert_eq(uni2.get_shrinking_factor(), Some(0.5))

  // Non-matching variant returns self
  let bpe = Trainer::bpe()
  @test.assert_eq(bpe.set_shrinking_factor(0.5).kind(), "BpeTrainer")
}

///|
test "Trainer set_shrinking_factor_alias" {
  let uni = Trainer::unigram(shrinking_factor=0.75)
  let uni2 = uni.set_shrinking_factor_alias(0.5)
  @test.assert_eq(uni2.get_shrinking_factor(), Some(0.5))
}

///|
test "Trainer set_max_piece_length" {
  let uni = Trainer::unigram(max_piece_length=None)
  let uni2 = uni.set_max_piece_length(Some(20))
  @test.assert_eq(uni2.get_max_piece_length(), Some(20))

  // Non-matching variant returns self
  let bpe = Trainer::bpe()
  @test.assert_eq(bpe.set_max_piece_length(Some(20)).kind(), "BpeTrainer")
}

///|
test "Trainer set_max_piece_length_alias" {
  let uni = Trainer::unigram(max_piece_length=None)
  let uni2 = uni.set_max_piece_length_alias(Some(20))
  @test.assert_eq(uni2.get_max_piece_length(), Some(20))
}

///|
test "Trainer set_n_sub_iterations" {
  let uni = Trainer::unigram(n_sub_iterations=2)
  let uni2 = uni.set_n_sub_iterations(5)
  @test.assert_eq(uni2.get_n_sub_iterations(), Some(5))

  // Non-matching variant returns self
  let bpe = Trainer::bpe()
  @test.assert_eq(bpe.set_n_sub_iterations(5).kind(), "BpeTrainer")
}

///|
test "Trainer set_n_sub_iterations_alias" {
  let uni = Trainer::unigram(n_sub_iterations=2)
  let uni2 = uni.set_n_sub_iterations_alias(5)
  @test.assert_eq(uni2.get_n_sub_iterations(), Some(5))
}

///|
test "Trainer set_seed_size" {
  let uni = Trainer::unigram(seed_size=1000000)
  let uni2 = uni.set_seed_size(500000)
  @test.assert_eq(uni2.get_seed_size(), Some(500000))

  // Non-matching variant returns self
  let bpe = Trainer::bpe()
  @test.assert_eq(bpe.set_seed_size(500000).kind(), "BpeTrainer")
}

///|
test "Trainer set_seed_size_alias" {
  let uni = Trainer::unigram(seed_size=1000000)
  let uni2 = uni.set_seed_size_alias(500000)
  @test.assert_eq(uni2.get_seed_size(), Some(500000))
}

///|
test "Trainer set_progress_format" {
  let bpe = Trainer::bpe(progress_format="indicatif")
  let bpe2 = bpe.set_progress_format("json")
  @test.assert_eq(bpe2.get_progress_format(), Some("json"))

  // Non-matching variant returns self
  let uni = Trainer::unigram()
  @test.assert_eq(uni.set_progress_format("json").kind(), "UnigramTrainer")
}

///|
test "Trainer set_progress_format_alias" {
  let bpe = Trainer::bpe(progress_format="indicatif")
  let bpe2 = bpe.set_progress_format_alias("json")
  @test.assert_eq(bpe2.get_progress_format(), Some("json"))
}
