///|
pub fn Trainer::get_state(self : Trainer) -> TrainerState {
  {
    kind: self.kind(),
    unk_token: self.unk_token(),
    min_frequency: self.min_frequency(),
    special_tokens: self.special_tokens(),
    special_added_tokens: self.special_added_tokens(),
    vocab_size: self.vocab_size(),
    show_progress: self.show_progress(),
    continuing_subword_prefix: self.continuing_subword_prefix(),
    end_of_word_suffix: self.end_of_word_suffix(),
    max_input_chars_per_word: self.max_input_chars_per_word(),
    max_token_length: self.max_token_length(),
    initial_alphabet: self.initial_alphabet(),
    limit_alphabet: self.limit_alphabet(),
    fuse_unk: self.fuse_unk(),
    byte_fallback: self.byte_fallback(),
    shrinking_factor: self.shrinking_factor(),
    max_piece_length: self.max_piece_length(),
    n_sub_iterations: self.n_sub_iterations(),
    seed_size: self.seed_size(),
    progress_format: self.progress_format(),
  }
}

///|
pub fn Trainer::from_state(
  state : TrainerState,
) -> Trainer raise @types.TokenizerError {
  match state.kind {
    "WordLevelTrainer" | "WordLevel" =>
      Trainer::wordlevel(
        unk_token=state.unk_token.unwrap_or("[UNK]"),
        min_frequency=state.min_frequency,
        special_tokens=state.special_tokens,
        special_added_tokens=state.special_added_tokens,
        vocab_size=state.vocab_size,
        show_progress=state.show_progress,
      )
    "WordPieceTrainer" | "WordPiece" =>
      Trainer::wordpiece(
        unk_token=state.unk_token.unwrap_or("[UNK]"),
        continuing_subword_prefix=state.continuing_subword_prefix.unwrap_or(
          "##",
        ),
        end_of_word_suffix=state.end_of_word_suffix,
        min_frequency=state.min_frequency,
        special_tokens=state.special_tokens,
        special_added_tokens=state.special_added_tokens,
        vocab_size=state.vocab_size,
        max_input_chars_per_word=state.max_input_chars_per_word.unwrap_or(100),
        max_token_length=state.max_token_length,
        initial_alphabet=state.initial_alphabet,
        limit_alphabet=state.limit_alphabet,
        show_progress=state.show_progress,
      )
    "BpeTrainer" | "BPE" | "Bpe" =>
      Trainer::bpe(
        unk_token=state.unk_token,
        min_frequency=state.min_frequency,
        special_tokens=state.special_tokens,
        special_added_tokens=state.special_added_tokens,
        vocab_size=state.vocab_size,
        continuing_subword_prefix=state.continuing_subword_prefix,
        end_of_word_suffix=state.end_of_word_suffix,
        fuse_unk=state.fuse_unk.unwrap_or(false),
        initial_alphabet=state.initial_alphabet,
        limit_alphabet=state.limit_alphabet,
        max_token_length=state.max_token_length,
        show_progress=state.show_progress,
        progress_format=state.progress_format.unwrap_or("indicatif"),
      )
    "UnigramTrainer" | "Unigram" =>
      Trainer::unigram(
        unk_token=state.unk_token,
        min_frequency=state.min_frequency,
        special_tokens=state.special_tokens,
        special_added_tokens=state.special_added_tokens,
        vocab_size=state.vocab_size,
        byte_fallback=state.byte_fallback.unwrap_or(false),
        fuse_unk=state.fuse_unk.unwrap_or(true),
        shrinking_factor=state.shrinking_factor.unwrap_or(0.75),
        max_piece_length=state.max_piece_length,
        initial_alphabet=state.initial_alphabet,
        n_sub_iterations=state.n_sub_iterations.unwrap_or(2),
        show_progress=state.show_progress,
        seed_size=state.seed_size.unwrap_or(1000000),
      )
    other => raise @types.UnsupportedComponent("trainer type: \{other}")
  }
}

///|
pub fn Trainer::__getstate__(self : Trainer) -> TrainerState {
  self.get_state()
}

///|
pub fn Trainer::__setstate__(
  state : TrainerState,
) -> Trainer raise @types.TokenizerError {
  Trainer::from_state(state)
}

///|
pub fn Trainer::__str__(self : Trainer) -> String {
  trainer_state_to_json(self.get_state())
}

///|
pub fn Trainer::__repr__(self : Trainer) -> String {
  self.__str__()
}

///|
