///|
/// Set unk_token. Returns a new Trainer; all variants support it.
pub fn Trainer::set_unk_token(self : Trainer, val : String?) -> Trainer {
  match self {
    WordLevelTrainer(
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      show_progress~,
      ..
    ) =>
      WordLevelTrainer(
        unk_token=val.unwrap_or(""),
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        show_progress~,
      )
    WordPieceTrainer(
      continuing_subword_prefix~,
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
        unk_token=val.unwrap_or(""),
        continuing_subword_prefix~,
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
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      continuing_subword_prefix~,
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
        unk_token=val,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        fuse_unk~,
        initial_alphabet~,
        limit_alphabet~,
        max_token_length~,
        show_progress~,
        progress_format~,
      )
    UnigramTrainer(
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      byte_fallback~,
      fuse_unk~,
      shrinking_factor~,
      max_piece_length~,
      initial_alphabet~,
      n_sub_iterations~,
      show_progress~,
      seed_size~,
      ..
    ) =>
      UnigramTrainer(
        unk_token=val,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        byte_fallback~,
        fuse_unk~,
        shrinking_factor~,
        max_piece_length~,
        initial_alphabet~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
  }
}

///|
/// Python/property-style setter alias for unk_token.
pub fn Trainer::set_unk_token_alias(self : Trainer, val : String?) -> Trainer {
  self.set_unk_token(val)
}

///|
/// Set min_frequency. Returns a new Trainer; all variants support it.
pub fn Trainer::set_min_frequency(self : Trainer, val : Int) -> Trainer {
  match self {
    WordLevelTrainer(
      unk_token~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      show_progress~,
      ..
    ) =>
      WordLevelTrainer(
        unk_token~,
        min_frequency=val,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        show_progress~,
      )
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
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
        end_of_word_suffix~,
        min_frequency=val,
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
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      continuing_subword_prefix~,
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
        min_frequency=val,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        fuse_unk~,
        initial_alphabet~,
        limit_alphabet~,
        max_token_length~,
        show_progress~,
        progress_format~,
      )
    UnigramTrainer(
      unk_token~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      byte_fallback~,
      fuse_unk~,
      shrinking_factor~,
      max_piece_length~,
      initial_alphabet~,
      n_sub_iterations~,
      show_progress~,
      seed_size~,
      ..
    ) =>
      UnigramTrainer(
        unk_token~,
        min_frequency=val,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        byte_fallback~,
        fuse_unk~,
        shrinking_factor~,
        max_piece_length~,
        initial_alphabet~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
  }
}

///|
/// Python/property-style setter alias for min_frequency.
pub fn Trainer::set_min_frequency_alias(self : Trainer, val : Int) -> Trainer {
  self.set_min_frequency(val)
}

///|
/// Set special_tokens. Returns a new Trainer; all variants support it.
pub fn Trainer::set_special_tokens(
  self : Trainer,
  val : Array[String],
) -> Trainer {
  match self {
    WordLevelTrainer(
      unk_token~,
      min_frequency~,
      special_added_tokens~,
      vocab_size~,
      show_progress~,
      ..
    ) =>
      WordLevelTrainer(
        unk_token~,
        min_frequency~,
        special_tokens=val,
        special_added_tokens~,
        vocab_size~,
        show_progress~,
      )
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      min_frequency~,
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
        end_of_word_suffix~,
        min_frequency~,
        special_tokens=val,
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
      special_added_tokens~,
      vocab_size~,
      continuing_subword_prefix~,
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
        special_tokens=val,
        special_added_tokens~,
        vocab_size~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        fuse_unk~,
        initial_alphabet~,
        limit_alphabet~,
        max_token_length~,
        show_progress~,
        progress_format~,
      )
    UnigramTrainer(
      unk_token~,
      min_frequency~,
      special_added_tokens~,
      vocab_size~,
      byte_fallback~,
      fuse_unk~,
      shrinking_factor~,
      max_piece_length~,
      initial_alphabet~,
      n_sub_iterations~,
      show_progress~,
      seed_size~,
      ..
    ) =>
      UnigramTrainer(
        unk_token~,
        min_frequency~,
        special_tokens=val,
        special_added_tokens~,
        vocab_size~,
        byte_fallback~,
        fuse_unk~,
        shrinking_factor~,
        max_piece_length~,
        initial_alphabet~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
  }
}

///|
/// Python/property-style setter alias for special_tokens.
pub fn Trainer::set_special_tokens_alias(
  self : Trainer,
  val : Array[String],
) -> Trainer {
  self.set_special_tokens(val)
}

///|
/// Set special_added_tokens. Returns a new Trainer; all variants support it.
pub fn Trainer::set_special_added_tokens(
  self : Trainer,
  val : Array[AddedToken],
) -> Trainer {
  match self {
    WordLevelTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      vocab_size~,
      show_progress~,
      ..
    ) =>
      WordLevelTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens=val,
        vocab_size~,
        show_progress~,
      )
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      min_frequency~,
      special_tokens~,
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
        end_of_word_suffix~,
        min_frequency~,
        special_tokens~,
        special_added_tokens=val,
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
      vocab_size~,
      continuing_subword_prefix~,
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
        special_added_tokens=val,
        vocab_size~,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        fuse_unk~,
        initial_alphabet~,
        limit_alphabet~,
        max_token_length~,
        show_progress~,
        progress_format~,
      )
    UnigramTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      vocab_size~,
      byte_fallback~,
      fuse_unk~,
      shrinking_factor~,
      max_piece_length~,
      initial_alphabet~,
      n_sub_iterations~,
      show_progress~,
      seed_size~,
      ..
    ) =>
      UnigramTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens=val,
        vocab_size~,
        byte_fallback~,
        fuse_unk~,
        shrinking_factor~,
        max_piece_length~,
        initial_alphabet~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
  }
}

///|
/// Python/property-style setter alias for special_added_tokens.
pub fn Trainer::set_special_added_tokens_alias(
  self : Trainer,
  val : Array[AddedToken],
) -> Trainer {
  self.set_special_added_tokens(val)
}

///|
/// Set vocab_size. Returns a new Trainer; all variants support it.
pub fn Trainer::set_vocab_size(self : Trainer, val : Int?) -> Trainer {
  match self {
    WordLevelTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      show_progress~,
      ..
    ) =>
      WordLevelTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size=val,
        show_progress~,
      )
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
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
        end_of_word_suffix~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size=val,
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
      continuing_subword_prefix~,
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
        vocab_size=val,
        continuing_subword_prefix~,
        end_of_word_suffix~,
        fuse_unk~,
        initial_alphabet~,
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
      byte_fallback~,
      fuse_unk~,
      shrinking_factor~,
      max_piece_length~,
      initial_alphabet~,
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
        vocab_size=val,
        byte_fallback~,
        fuse_unk~,
        shrinking_factor~,
        max_piece_length~,
        initial_alphabet~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
  }
}

///|
/// Python/property-style setter alias for vocab_size.
pub fn Trainer::set_vocab_size_alias(self : Trainer, val : Int?) -> Trainer {
  self.set_vocab_size(val)
}

///|
/// Set show_progress. Returns a new Trainer; all variants support it.
pub fn Trainer::set_show_progress(self : Trainer, val : Bool) -> Trainer {
  match self {
    WordLevelTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      ..
    ) =>
      WordLevelTrainer(
        unk_token~,
        min_frequency~,
        special_tokens~,
        special_added_tokens~,
        vocab_size~,
        show_progress=val,
      )
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
      limit_alphabet~,
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
        limit_alphabet~,
        show_progress=val,
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
      max_token_length~,
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
        max_token_length~,
        show_progress=val,
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
      initial_alphabet~,
      n_sub_iterations~,
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
        initial_alphabet~,
        n_sub_iterations~,
        show_progress=val,
        seed_size~,
      )
  }
}

///|
/// Python/property-style setter alias for show_progress.
pub fn Trainer::set_show_progress_alias(self : Trainer, val : Bool) -> Trainer {
  self.set_show_progress(val)
}

///|
/// Set continuing_subword_prefix. Returns a new Trainer; WordPiece and BPE support it.
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
