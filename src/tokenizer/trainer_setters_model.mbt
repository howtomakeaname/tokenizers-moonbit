///|
pub fn Trainer::set_fuse_unk(self : Trainer, val : Bool) -> Trainer {
  match self {
    BpeTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
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
        end_of_word_suffix~,
        fuse_unk=val,
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
      vocab_size~,
      byte_fallback~,
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
        vocab_size~,
        byte_fallback~,
        fuse_unk=val,
        shrinking_factor~,
        max_piece_length~,
        initial_alphabet~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for fuse_unk.
pub fn Trainer::set_fuse_unk_alias(self : Trainer, val : Bool) -> Trainer {
  self.set_fuse_unk(val)
}

///|
/// Set byte_fallback. Returns a new Trainer; only Unigram supports it.
pub fn Trainer::set_byte_fallback(self : Trainer, val : Bool) -> Trainer {
  match self {
    UnigramTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
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
        vocab_size~,
        byte_fallback=val,
        fuse_unk~,
        shrinking_factor~,
        max_piece_length~,
        initial_alphabet~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for byte_fallback.
pub fn Trainer::set_byte_fallback_alias(self : Trainer, val : Bool) -> Trainer {
  self.set_byte_fallback(val)
}

///|
/// Set shrinking_factor. Returns a new Trainer; only Unigram supports it.
pub fn Trainer::set_shrinking_factor(self : Trainer, val : Double) -> Trainer {
  match self {
    UnigramTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      byte_fallback~,
      fuse_unk~,
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
        vocab_size~,
        byte_fallback~,
        fuse_unk~,
        shrinking_factor=val,
        max_piece_length~,
        initial_alphabet~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for shrinking_factor.
pub fn Trainer::set_shrinking_factor_alias(
  self : Trainer,
  val : Double,
) -> Trainer {
  self.set_shrinking_factor(val)
}

///|
/// Set max_piece_length. Returns a new Trainer; only Unigram supports it.
pub fn Trainer::set_max_piece_length(self : Trainer, val : Int?) -> Trainer {
  match self {
    UnigramTrainer(
      unk_token~,
      min_frequency~,
      special_tokens~,
      special_added_tokens~,
      vocab_size~,
      byte_fallback~,
      fuse_unk~,
      shrinking_factor~,
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
        vocab_size~,
        byte_fallback~,
        fuse_unk~,
        shrinking_factor~,
        max_piece_length=val,
        initial_alphabet~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for max_piece_length.
pub fn Trainer::set_max_piece_length_alias(
  self : Trainer,
  val : Int?,
) -> Trainer {
  self.set_max_piece_length(val)
}

///|
/// Set n_sub_iterations. Returns a new Trainer; only Unigram supports it.
pub fn Trainer::set_n_sub_iterations(self : Trainer, val : Int) -> Trainer {
  match self {
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
        initial_alphabet~,
        n_sub_iterations=val,
        show_progress~,
        seed_size~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for n_sub_iterations.
pub fn Trainer::set_n_sub_iterations_alias(
  self : Trainer,
  val : Int,
) -> Trainer {
  self.set_n_sub_iterations(val)
}

///|
/// Set seed_size. Returns a new Trainer; only Unigram supports it.
pub fn Trainer::set_seed_size(self : Trainer, val : Int) -> Trainer {
  match self {
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
      show_progress~,
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
        show_progress~,
        seed_size=val,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for seed_size.
pub fn Trainer::set_seed_size_alias(self : Trainer, val : Int) -> Trainer {
  self.set_seed_size(val)
}

///|
/// Set progress_format. Returns a new Trainer; only BPE supports it.
pub fn Trainer::set_progress_format(self : Trainer, val : String) -> Trainer {
  match self {
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
      show_progress~,
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
        show_progress~,
        progress_format=val,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for progress_format.
pub fn Trainer::set_progress_format_alias(
  self : Trainer,
  val : String,
) -> Trainer {
  self.set_progress_format(val)
}
