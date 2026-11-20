// Minimal tokenizer-level training helpers.

///|
/// HF-style tokenizer trainer configuration used by `Tokenizer::train` and
/// `train_from_iterator`. It intentionally wraps the existing deterministic model
/// trainers while preserving tokenizer-level normalizer/pre-tokenizer and added
/// vocabulary handling.
#derive(Debug, Eq)
pub enum Trainer {
  WordLevelTrainer(
    unk_token~ : String,
    min_frequency~ : Int32,
    special_tokens~ : Array[String],
    special_added_tokens~ : Array[AddedToken],
    vocab_size~ : Int32?,
    show_progress~ : Bool,
  )
  WordPieceTrainer(
    unk_token~ : String,
    continuing_subword_prefix~ : String,
    end_of_word_suffix~ : String?,
    min_frequency~ : Int32,
    special_tokens~ : Array[String],
    special_added_tokens~ : Array[AddedToken],
    vocab_size~ : Int32?,
    max_input_chars_per_word~ : Int32,
    max_token_length~ : Int32?,
    initial_alphabet~ : Array[String],
    limit_alphabet~ : Int32?,
    show_progress~ : Bool,
  )
  BpeTrainer(
    unk_token~ : String?,
    min_frequency~ : Int32,
    special_tokens~ : Array[String],
    special_added_tokens~ : Array[AddedToken],
    vocab_size~ : Int32?,
    continuing_subword_prefix~ : String?,
    end_of_word_suffix~ : String?,
    fuse_unk~ : Bool,
    initial_alphabet~ : Array[String],
    limit_alphabet~ : Int32?,
    max_token_length~ : Int32?,
    show_progress~ : Bool,
    progress_format~ : String,
  )
  UnigramTrainer(
    unk_token~ : String?,
    min_frequency~ : Int32,
    special_tokens~ : Array[String],
    special_added_tokens~ : Array[AddedToken],
    vocab_size~ : Int32?,
    byte_fallback~ : Bool,
    fuse_unk~ : Bool,
    shrinking_factor~ : Double,
    max_piece_length~ : Int32?,
    initial_alphabet~ : Array[String],
    n_sub_iterations~ : Int32,
    show_progress~ : Bool,
    seed_size~ : Int32,
  )
}

///|
/// Typed, copy-returning trainer configuration snapshot for binding layers.
#derive(Debug, Eq)
pub struct TrainerState {
  kind : String
  unk_token : String?
  min_frequency : Int32
  special_tokens : Array[String]
  special_added_tokens : Array[AddedToken]
  vocab_size : Int32?
  show_progress : Bool
  continuing_subword_prefix : String?
  end_of_word_suffix : String?
  max_input_chars_per_word : Int32?
  max_token_length : Int32?
  initial_alphabet : Array[String]
  limit_alphabet : Int32?
  fuse_unk : Bool?
  byte_fallback : Bool?
  shrinking_factor : Double?
  max_piece_length : Int32?
  n_sub_iterations : Int32?
  seed_size : Int32?
  progress_format : String?
}

///|
priv struct BpeTrainingOptions {
  byte_fallback : Bool
  ignore_merges : Bool
  dropout : Double?
  cache_capacity : Int32?
}

///|
pub fn TrainerState::with_kind(
  self : TrainerState,
  kind : String,
) -> TrainerState {
  { ..self, kind, }
}

///|
pub fn Trainer::wordlevel(
  unk_token~ : String = "[UNK]",
  min_frequency~ : Int32 = 0,
  special_tokens~ : Array[String] = [],
  special_added_tokens~ : Array[AddedToken] = [],
  vocab_size~ : Int32? = Some(30000),
  show_progress~ : Bool = true,
) -> Trainer {
  WordLevelTrainer(
    unk_token~,
    min_frequency~,
    special_tokens~,
    special_added_tokens~,
    vocab_size~,
    show_progress~,
  )
}

///|
/// HF Python-style constructor alias for binding layers.
pub fn Trainer::wordlevel_trainer(
  unk_token~ : String = "[UNK]",
  min_frequency~ : Int32 = 0,
  special_tokens~ : Array[String] = [],
  special_added_tokens~ : Array[AddedToken] = [],
  vocab_size~ : Int32? = Some(30000),
  show_progress~ : Bool = true,
) -> Trainer {
  Trainer::wordlevel(
    unk_token~,
    min_frequency~,
    special_tokens~,
    special_added_tokens~,
    vocab_size~,
    show_progress~,
  )
}

///|
pub fn Trainer::wordpiece(
  unk_token~ : String = "[UNK]",
  continuing_subword_prefix~ : String = "##",
  end_of_word_suffix~ : String? = None,
  min_frequency~ : Int32 = 0,
  special_tokens~ : Array[String] = [],
  special_added_tokens~ : Array[AddedToken] = [],
  vocab_size~ : Int32? = Some(30000),
  max_input_chars_per_word~ : Int32 = 100,
  max_token_length~ : Int32? = None,
  initial_alphabet~ : Array[String] = [],
  limit_alphabet~ : Int32? = None,
  show_progress~ : Bool = true,
) -> Trainer {
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
    show_progress~,
  )
}

///|
/// HF Python-style constructor alias for binding layers.
pub fn Trainer::wordpiece_trainer(
  unk_token~ : String = "[UNK]",
  continuing_subword_prefix~ : String = "##",
  end_of_word_suffix~ : String? = None,
  min_frequency~ : Int32 = 0,
  special_tokens~ : Array[String] = [],
  special_added_tokens~ : Array[AddedToken] = [],
  vocab_size~ : Int32? = Some(30000),
  max_input_chars_per_word~ : Int32 = 100,
  max_token_length~ : Int32? = None,
  initial_alphabet~ : Array[String] = [],
  limit_alphabet~ : Int32? = None,
  show_progress~ : Bool = true,
) -> Trainer {
  Trainer::wordpiece(
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
    show_progress~,
  )
}

///|
pub fn Trainer::bpe(
  unk_token~ : String? = None,
  min_frequency~ : Int32 = 0,
  special_tokens~ : Array[String] = [],
  special_added_tokens~ : Array[AddedToken] = [],
  vocab_size~ : Int32? = Some(30000),
  continuing_subword_prefix~ : String? = None,
  end_of_word_suffix~ : String? = None,
  fuse_unk~ : Bool = false,
  initial_alphabet~ : Array[String] = [],
  limit_alphabet~ : Int32? = None,
  max_token_length~ : Int32? = None,
  show_progress~ : Bool = true,
  progress_format~ : String = "indicatif",
) -> Trainer {
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
    progress_format=normalize_progress_format(progress_format),
  )
}

///|
/// HF Python-style constructor alias for binding layers.
pub fn Trainer::bpe_trainer(
  unk_token~ : String? = None,
  min_frequency~ : Int32 = 0,
  special_tokens~ : Array[String] = [],
  special_added_tokens~ : Array[AddedToken] = [],
  vocab_size~ : Int32? = Some(30000),
  continuing_subword_prefix~ : String? = None,
  end_of_word_suffix~ : String? = None,
  fuse_unk~ : Bool = false,
  initial_alphabet~ : Array[String] = [],
  limit_alphabet~ : Int32? = None,
  max_token_length~ : Int32? = None,
  show_progress~ : Bool = true,
  progress_format~ : String = "indicatif",
) -> Trainer {
  Trainer::bpe(
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
    progress_format~,
  )
}

///|
pub fn Trainer::unigram(
  unk_token~ : String? = None,
  unk_piece~ : String? = None,
  min_frequency~ : Int32 = 1,
  special_tokens~ : Array[String] = [],
  special_added_tokens~ : Array[AddedToken] = [],
  vocab_size~ : Int32? = Some(8000),
  byte_fallback~ : Bool = false,
  fuse_unk~ : Bool = true,
  shrinking_factor~ : Double = 0.75,
  max_piece_length~ : Int32? = Some(16),
  initial_alphabet~ : Array[String] = [],
  n_sub_iterations~ : Int32 = 2,
  show_progress~ : Bool = true,
  seed_size~ : Int32 = 1000000,
) -> Trainer {
  let unk_token = match unk_piece {
    Some(piece) => Some(piece)
    None => unk_token
  }
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
    seed_size~,
  )
}

///|
/// HF Python-style constructor alias for binding layers.
pub fn Trainer::unigram_trainer(
  unk_token~ : String? = None,
  unk_piece~ : String? = None,
  min_frequency~ : Int32 = 1,
  special_tokens~ : Array[String] = [],
  special_added_tokens~ : Array[AddedToken] = [],
  vocab_size~ : Int32? = Some(8000),
  byte_fallback~ : Bool = false,
  fuse_unk~ : Bool = true,
  shrinking_factor~ : Double = 0.75,
  max_piece_length~ : Int32? = Some(16),
  initial_alphabet~ : Array[String] = [],
  n_sub_iterations~ : Int32 = 2,
  show_progress~ : Bool = true,
  seed_size~ : Int32 = 1000000,
) -> Trainer {
  Trainer::unigram(
    unk_token~,
    unk_piece~,
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

///|
/// Return the trainer family name used by thin binding layers.
pub fn Trainer::kind(self : Trainer) -> String {
  match self {
    WordLevelTrainer(..) => "WordLevelTrainer"
    WordPieceTrainer(..) => "WordPieceTrainer"
    BpeTrainer(..) => "BpeTrainer"
    UnigramTrainer(..) => "UnigramTrainer"
  }
}

///|
pub fn Trainer::unk_token(self : Trainer) -> String? {
  match self {
    WordLevelTrainer(unk_token~, ..) => Some(unk_token)
    WordPieceTrainer(unk_token~, ..) => Some(unk_token)
    BpeTrainer(unk_token~, ..) => unk_token
    UnigramTrainer(unk_token~, ..) => unk_token
  }
}

///|
pub fn Trainer::get_unk_token(self : Trainer) -> String? {
  self.unk_token()
}

///|
pub fn Trainer::min_frequency(self : Trainer) -> Int32 {
  match self {
    WordLevelTrainer(min_frequency~, ..) => min_frequency
    WordPieceTrainer(min_frequency~, ..) => min_frequency
    BpeTrainer(min_frequency~, ..) => min_frequency
    UnigramTrainer(min_frequency~, ..) => min_frequency
  }
}

///|
pub fn Trainer::get_min_frequency(self : Trainer) -> Int32 {
  self.min_frequency()
}

///|
pub fn Trainer::special_tokens(self : Trainer) -> Array[String] {
  trainer_special_tokens(self)
}

///|
pub fn Trainer::get_special_tokens(self : Trainer) -> Array[String] {
  self.special_tokens()
}

///|
pub fn Trainer::special_added_tokens(self : Trainer) -> Array[AddedToken] {
  trainer_special_added_tokens(self)
}

///|
pub fn Trainer::get_special_added_tokens(self : Trainer) -> Array[AddedToken] {
  self.special_added_tokens()
}

///|
pub fn Trainer::vocab_size(self : Trainer) -> Int32? {
  match self {
    WordLevelTrainer(vocab_size~, ..) => vocab_size
    WordPieceTrainer(vocab_size~, ..) => vocab_size
    BpeTrainer(vocab_size~, ..) => vocab_size
    UnigramTrainer(vocab_size~, ..) => vocab_size
  }
}

///|
pub fn Trainer::get_vocab_size(self : Trainer) -> Int32? {
  self.vocab_size()
}

///|
pub fn Trainer::show_progress(self : Trainer) -> Bool {
  match self {
    WordLevelTrainer(show_progress~, ..) => show_progress
    WordPieceTrainer(show_progress~, ..) => show_progress
    BpeTrainer(show_progress~, ..) => show_progress
    UnigramTrainer(show_progress~, ..) => show_progress
  }
}

///|
pub fn Trainer::get_show_progress(self : Trainer) -> Bool {
  self.show_progress()
}

///|
pub fn Trainer::continuing_subword_prefix(self : Trainer) -> String? {
  match self {
    WordPieceTrainer(continuing_subword_prefix~, ..) =>
      Some(continuing_subword_prefix)
    BpeTrainer(continuing_subword_prefix~, ..) => continuing_subword_prefix
    _ => None
  }
}

///|
pub fn Trainer::get_continuing_subword_prefix(self : Trainer) -> String? {
  self.continuing_subword_prefix()
}

///|
pub fn Trainer::end_of_word_suffix(self : Trainer) -> String? {
  match self {
    WordPieceTrainer(end_of_word_suffix~, ..) => end_of_word_suffix
    BpeTrainer(end_of_word_suffix~, ..) => end_of_word_suffix
    _ => None
  }
}

///|
pub fn Trainer::get_end_of_word_suffix(self : Trainer) -> String? {
  self.end_of_word_suffix()
}

///|
pub fn Trainer::initial_alphabet(self : Trainer) -> Array[String] {
  match self {
    WordPieceTrainer(initial_alphabet~, ..) => initial_alphabet.copy()
    BpeTrainer(initial_alphabet~, ..) => initial_alphabet.copy()
    UnigramTrainer(initial_alphabet~, ..) => initial_alphabet.copy()
    _ => []
  }
}

///|
pub fn Trainer::get_initial_alphabet(self : Trainer) -> Array[String] {
  self.initial_alphabet()
}

///|
pub fn Trainer::limit_alphabet(self : Trainer) -> Int32? {
  match self {
    WordPieceTrainer(limit_alphabet~, ..) => limit_alphabet
    BpeTrainer(limit_alphabet~, ..) => limit_alphabet
    _ => None
  }
}

///|
pub fn Trainer::get_limit_alphabet(self : Trainer) -> Int32? {
  self.limit_alphabet()
}

///|
pub fn Trainer::max_token_length(self : Trainer) -> Int32? {
  match self {
    WordPieceTrainer(max_token_length~, ..) => max_token_length
    BpeTrainer(max_token_length~, ..) => max_token_length
    _ => None
  }
}

///|
pub fn Trainer::get_max_token_length(self : Trainer) -> Int32? {
  self.max_token_length()
}

///|
pub fn Trainer::max_input_chars_per_word(self : Trainer) -> Int32? {
  match self {
    WordPieceTrainer(max_input_chars_per_word~, ..) =>
      Some(max_input_chars_per_word)
    _ => None
  }
}

///|
pub fn Trainer::get_max_input_chars_per_word(self : Trainer) -> Int32? {
  self.max_input_chars_per_word()
}

///|
pub fn Trainer::fuse_unk(self : Trainer) -> Bool? {
  match self {
    BpeTrainer(fuse_unk~, ..) => Some(fuse_unk)
    UnigramTrainer(fuse_unk~, ..) => Some(fuse_unk)
    _ => None
  }
}

///|
pub fn Trainer::get_fuse_unk(self : Trainer) -> Bool? {
  self.fuse_unk()
}

///|
pub fn Trainer::byte_fallback(self : Trainer) -> Bool? {
  match self {
    UnigramTrainer(byte_fallback~, ..) => Some(byte_fallback)
    _ => None
  }
}

///|
pub fn Trainer::get_byte_fallback(self : Trainer) -> Bool? {
  self.byte_fallback()
}

///|
pub fn Trainer::shrinking_factor(self : Trainer) -> Double? {
  match self {
    UnigramTrainer(shrinking_factor~, ..) => Some(shrinking_factor)
    _ => None
  }
}

///|
pub fn Trainer::get_shrinking_factor(self : Trainer) -> Double? {
  self.shrinking_factor()
}

///|
pub fn Trainer::max_piece_length(self : Trainer) -> Int32? {
  match self {
    UnigramTrainer(max_piece_length~, ..) => max_piece_length
    _ => None
  }
}

///|
pub fn Trainer::get_max_piece_length(self : Trainer) -> Int32? {
  self.max_piece_length()
}

///|
pub fn Trainer::n_sub_iterations(self : Trainer) -> Int32? {
  match self {
    UnigramTrainer(n_sub_iterations~, ..) => Some(n_sub_iterations)
    _ => None
  }
}

///|
pub fn Trainer::get_n_sub_iterations(self : Trainer) -> Int32? {
  self.n_sub_iterations()
}

///|
pub fn Trainer::seed_size(self : Trainer) -> Int32? {
  match self {
    UnigramTrainer(seed_size~, ..) => Some(seed_size)
    _ => None
  }
}

///|
pub fn Trainer::get_seed_size(self : Trainer) -> Int32? {
  self.seed_size()
}

///|
pub fn Trainer::progress_format(self : Trainer) -> String? {
  match self {
    BpeTrainer(progress_format~, ..) => Some(progress_format)
    _ => None
  }
}

///|
pub fn Trainer::get_progress_format(self : Trainer) -> String? {
  self.progress_format()
}

///|
pub extend Trainer with @debug.Debug::{to_repr}

///|
pub extend Trainer with Eq::{equal, not_equal}

///|
pub extend TrainerState with @debug.Debug::{to_repr}

///|
pub extend TrainerState with Eq::{equal, not_equal}
