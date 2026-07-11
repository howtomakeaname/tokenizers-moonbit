///|
pub fn Trainer::set_continuing_subword_prefix(
  self : Trainer,
  val : String?,
) -> Trainer {
  match self {
    WordPieceTrainer(
      unk_token~,
      end_of_word_suffix~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      max_input_chars_per_word~,
      max_token_length~,
      initial_alphabet~,
      limit_alphabet~,
      show_progress~,
      ..
    ) =>
      WordPieceTrainer(
        unk_token~,
        continuing_subword_prefix=val.unwrap_or(""),
        end_of_word_suffix~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        max_input_chars_per_word~,
        max_token_length~,
        initial_alphabet~,
        limit_alphabet~,
        show_progress~,
      )
    BpeTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      end_of_word_suffix~,
      fuse_unk~,
      initial_alphabet~,
      limit_alphabet~,
      max_token_length~,
      show_progress~,
      progress_format~,
      ..
    ) =>
      BpeTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        continuing_subword_prefix=val,
        end_of_word_suffix~,
        fuse_unk~,
        initial_alphabet~,
        limit_alphabet~,
        max_token_length~,
        show_progress~,
        progress_format~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for continuing_subword_prefix.
pub fn Trainer::set_continuing_subword_prefix_alias(
  self : Trainer,
  val : String?,
) -> Trainer {
  self.set_continuing_subword_prefix(val)
}

///|
/// Set end_of_word_suffix. Returns a new Trainer; WordPiece and BPE support it.
pub fn Trainer::set_end_of_word_suffix(
  self : Trainer,
  val : String?,
) -> Trainer {
  match self {
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      max_input_chars_per_word~,
      max_token_length~,
      initial_alphabet~,
      limit_alphabet~,
      show_progress~,
      ..
    ) =>
      WordPieceTrainer(
        unk_token~,
        continuing_subword_prefix~,
        end_of_word_suffix=val,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        max_input_chars_per_word~,
        max_token_length~,
        initial_alphabet~,
        limit_alphabet~,
        show_progress~,
      )
    BpeTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      continuing_subword_prefix~,
      fuse_unk~,
      initial_alphabet~,
      limit_alphabet~,
      max_token_length~,
      show_progress~,
      progress_format~,
      ..
    ) =>
      BpeTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        continuing_subword_prefix~,
        end_of_word_suffix=val,
        fuse_unk~,
        initial_alphabet~,
        limit_alphabet~,
        max_token_length~,
        show_progress~,
        progress_format~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for end_of_word_suffix.
pub fn Trainer::set_end_of_word_suffix_alias(
  self : Trainer,
  val : String?,
) -> Trainer {
  self.set_end_of_word_suffix(val)
}

///|
/// Set max_input_chars_per_word. Returns a new Trainer; only WordPiece supports it.
pub fn Trainer::set_max_input_chars_per_word(
  self : Trainer,
  val : Int,
) -> Trainer {
  match self {
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      max_token_length~,
      initial_alphabet~,
      limit_alphabet~,
      show_progress~,
      ..
    ) =>
      WordPieceTrainer(
        unk_token~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        max_input_chars_per_word=val,
        max_token_length~,
        initial_alphabet~,
        limit_alphabet~,
        show_progress~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for max_input_chars_per_word.
pub fn Trainer::set_max_input_chars_per_word_alias(
  self : Trainer,
  val : Int,
) -> Trainer {
  self.set_max_input_chars_per_word(val)
}

///|
/// Set max_token_length. Returns a new Trainer; WordPiece and BPE support it.
pub fn Trainer::set_max_token_length(self : Trainer, val : Int?) -> Trainer {
  match self {
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      max_input_chars_per_word~,
      initial_alphabet~,
      limit_alphabet~,
      show_progress~,
      ..
    ) =>
      WordPieceTrainer(
        unk_token~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        max_input_chars_per_word~,
        max_token_length=val,
        initial_alphabet~,
        limit_alphabet~,
        show_progress~,
      )
    BpeTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      fuse_unk~,
      initial_alphabet~,
      limit_alphabet~,
      show_progress~,
      progress_format~,
      ..
    ) =>
      BpeTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        fuse_unk~,
        initial_alphabet~,
        limit_alphabet~,
        max_token_length=val,
        show_progress~,
        progress_format~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for max_token_length.
pub fn Trainer::set_max_token_length_alias(
  self : Trainer,
  val : Int?,
) -> Trainer {
  self.set_max_token_length(val)
}

///|
/// Set initial_alphabet. Returns a new Trainer; WordPiece, BPE, and Unigram support it.
pub fn Trainer::set_initial_alphabet(
  self : Trainer,
  val : Array[String],
) -> Trainer {
  match self {
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      max_input_chars_per_word~,
      max_token_length~,
      limit_alphabet~,
      show_progress~,
      ..
    ) =>
      WordPieceTrainer(
        unk_token~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        max_input_chars_per_word~,
        max_token_length~,
        initial_alphabet=val,
        limit_alphabet~,
        show_progress~,
      )
    BpeTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      fuse_unk~,
      limit_alphabet~,
      max_token_length~,
      show_progress~,
      progress_format~,
      ..
    ) =>
      BpeTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        fuse_unk~,
        initial_alphabet=val,
        limit_alphabet~,
        max_token_length~,
        show_progress~,
        progress_format~,
      )
    UnigramTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      byte_fallback~,
      fuse_unk~,
      shrinking_factor~,
      max_piece_length~,
      n_sub_iterations~,
      show_progress~,
      seed_size~,
      ..
    ) =>
      UnigramTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        byte_fallback~,
        fuse_unk~,
        shrinking_factor~,
        max_piece_length~,
        initial_alphabet=val,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for initial_alphabet.
pub fn Trainer::set_initial_alphabet_alias(
  self : Trainer,
  val : Array[String],
) -> Trainer {
  self.set_initial_alphabet(val)
}

///|
/// Set limit_alphabet. Returns a new Trainer; WordPiece and BPE support it.
pub fn Trainer::set_limit_alphabet(self : Trainer, val : Int?) -> Trainer {
  match self {
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      max_input_chars_per_word~,
      max_token_length~,
      initial_alphabet~,
      show_progress~,
      ..
    ) =>
      WordPieceTrainer(
        unk_token~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        max_input_chars_per_word~,
        max_token_length~,
        initial_alphabet~,
        limit_alphabet=val,
        show_progress~,
      )
    BpeTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      fuse_unk~,
      initial_alphabet~,
      max_token_length~,
      show_progress~,
      progress_format~,
      ..
    ) =>
      BpeTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        fuse_unk~,
        initial_alphabet~,
        limit_alphabet=val,
        max_token_length~,
        show_progress~,
        progress_format~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for limit_alphabet.
pub fn Trainer::set_limit_alphabet_alias(self : Trainer, val : Int?) -> Trainer {
  self.set_limit_alphabet(val)
}

///|
/// Set fuse_unk. Returns a new Trainer; BPE and Unigram support it.
