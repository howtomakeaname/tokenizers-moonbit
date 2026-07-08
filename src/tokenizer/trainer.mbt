// Minimal tokenizer-level training helpers.

///|
/// HF-style tokenizer trainer configuration used by `Tokenizer::train` and
/// `train_from_iterator`. It intentionally wraps the existing deterministic model
/// trainers while preserving tokenizer-level normalizer/pre-tokenizer and added
/// vocabulary handling.
pub enum Trainer {
  WordLevelTrainer(
    unk_token~ : String,
    min_frequency~ : Int,
    special_tokens~ : Array[String],
    special_added_tokens~ : Array[AddedToken],
    vocab_size~ : Int?,
    show_progress~ : Bool
  )
  WordPieceTrainer(
    unk_token~ : String,
    continuing_subword_prefix~ : String,
    end_of_word_suffix~ : String?,
    min_frequency~ : Int,
    special_tokens~ : Array[String],
    special_added_tokens~ : Array[AddedToken],
    vocab_size~ : Int?,
    max_input_chars_per_word~ : Int,
    max_token_length~ : Int?,
    initial_alphabet~ : Array[String],
    limit_alphabet~ : Int?,
    show_progress~ : Bool
  )
  BpeTrainer(
    unk_token~ : String?,
    min_frequency~ : Int,
    special_tokens~ : Array[String],
    special_added_tokens~ : Array[AddedToken],
    vocab_size~ : Int?,
    continuing_subword_prefix~ : String?,
    end_of_word_suffix~ : String?,
    fuse_unk~ : Bool,
    initial_alphabet~ : Array[String],
    limit_alphabet~ : Int?,
    max_token_length~ : Int?,
    show_progress~ : Bool,
    progress_format~ : String
  )
  UnigramTrainer(
    unk_token~ : String,
    min_frequency~ : Int,
    special_tokens~ : Array[String],
    special_added_tokens~ : Array[AddedToken],
    vocab_size~ : Int?,
    byte_fallback~ : Bool,
    fuse_unk~ : Bool,
    shrinking_factor~ : Double,
    max_piece_length~ : Int?,
    initial_alphabet~ : Array[String],
    n_sub_iterations~ : Int,
    show_progress~ : Bool,
    seed_size~ : Int
  )
} derive(Debug, Eq)

///|
/// Typed, copy-returning trainer configuration snapshot for binding layers.
pub struct TrainerState {
  kind : String
  unk_token : String?
  min_frequency : Int
  special_tokens : Array[String]
  special_added_tokens : Array[AddedToken]
  vocab_size : Int?
  show_progress : Bool
  continuing_subword_prefix : String?
  end_of_word_suffix : String?
  max_input_chars_per_word : Int?
  max_token_length : Int?
  initial_alphabet : Array[String]
  limit_alphabet : Int?
  fuse_unk : Bool?
  byte_fallback : Bool?
  shrinking_factor : Double?
  max_piece_length : Int?
  n_sub_iterations : Int?
  seed_size : Int?
  progress_format : String?
} derive(Debug, Eq)

///|
priv struct BpeTrainingOptions {
  byte_fallback : Bool
  ignore_merges : Bool
  dropout : Double?
  cache_capacity : Int?
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
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  special_added_tokens? : Array[AddedToken] = [],
  vocab_size? : Int? = Some(30000),
  show_progress? : Bool = true,
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
pub fn Trainer::wordpiece(
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None,
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  special_added_tokens? : Array[AddedToken] = [],
  vocab_size? : Int? = Some(30000),
  max_input_chars_per_word? : Int = 100,
  max_token_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  show_progress? : Bool = true,
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
pub fn Trainer::bpe(
  unk_token? : String? = Some("[UNK]"),
  min_frequency? : Int = 2,
  special_tokens? : Array[String] = [],
  special_added_tokens? : Array[AddedToken] = [],
  vocab_size? : Int? = Some(30000),
  continuing_subword_prefix? : String? = None,
  end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  max_token_length? : Int? = None,
  show_progress? : Bool = true,
  progress_format? : String = "indicatif",
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
pub fn Trainer::unigram(
  unk_token? : String = "<unk>",
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  special_added_tokens? : Array[AddedToken] = [],
  vocab_size? : Int? = Some(8000),
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
  shrinking_factor? : Double = 0.75,
  max_piece_length? : Int? = Some(16),
  initial_alphabet? : Array[String] = [],
  n_sub_iterations? : Int = 2,
  show_progress? : Bool = true,
  seed_size? : Int = 1000000,
) -> Trainer {
  let unk_token = match unk_piece {
    Some(piece) => piece
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
    UnigramTrainer(unk_token~, ..) => Some(unk_token)
  }
}

///|
pub fn Trainer::min_frequency(self : Trainer) -> Int {
  match self {
    WordLevelTrainer(min_frequency~, ..) => min_frequency
    WordPieceTrainer(min_frequency~, ..) => min_frequency
    BpeTrainer(min_frequency~, ..) => min_frequency
    UnigramTrainer(min_frequency~, ..) => min_frequency
  }
}

///|
pub fn Trainer::special_tokens(self : Trainer) -> Array[String] {
  trainer_special_tokens(self)
}

///|
pub fn Trainer::special_added_tokens(self : Trainer) -> Array[AddedToken] {
  trainer_special_added_tokens(self)
}

///|
pub fn Trainer::vocab_size(self : Trainer) -> Int? {
  match self {
    WordLevelTrainer(vocab_size~, ..) => vocab_size
    WordPieceTrainer(vocab_size~, ..) => vocab_size
    BpeTrainer(vocab_size~, ..) => vocab_size
    UnigramTrainer(vocab_size~, ..) => vocab_size
  }
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
pub fn Trainer::continuing_subword_prefix(self : Trainer) -> String? {
  match self {
    WordPieceTrainer(continuing_subword_prefix~, ..) =>
      Some(continuing_subword_prefix)
    BpeTrainer(continuing_subword_prefix~, ..) => continuing_subword_prefix
    _ => None
  }
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
pub fn Trainer::initial_alphabet(self : Trainer) -> Array[String] {
  match self {
    WordPieceTrainer(initial_alphabet~, ..) => initial_alphabet.copy()
    BpeTrainer(initial_alphabet~, ..) => initial_alphabet.copy()
    UnigramTrainer(initial_alphabet~, ..) => initial_alphabet.copy()
    _ => []
  }
}

///|
pub fn Trainer::limit_alphabet(self : Trainer) -> Int? {
  match self {
    WordPieceTrainer(limit_alphabet~, ..) => limit_alphabet
    BpeTrainer(limit_alphabet~, ..) => limit_alphabet
    _ => None
  }
}

///|
pub fn Trainer::max_token_length(self : Trainer) -> Int? {
  match self {
    WordPieceTrainer(max_token_length~, ..) => max_token_length
    BpeTrainer(max_token_length~, ..) => max_token_length
    _ => None
  }
}

///|
pub fn Trainer::max_input_chars_per_word(self : Trainer) -> Int? {
  match self {
    WordPieceTrainer(max_input_chars_per_word~, ..) =>
      Some(max_input_chars_per_word)
    _ => None
  }
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
pub fn Trainer::byte_fallback(self : Trainer) -> Bool? {
  match self {
    UnigramTrainer(byte_fallback~, ..) => Some(byte_fallback)
    _ => None
  }
}

///|
pub fn Trainer::shrinking_factor(self : Trainer) -> Double? {
  match self {
    UnigramTrainer(shrinking_factor~, ..) => Some(shrinking_factor)
    _ => None
  }
}

///|
pub fn Trainer::max_piece_length(self : Trainer) -> Int? {
  match self {
    UnigramTrainer(max_piece_length~, ..) => max_piece_length
    _ => None
  }
}

///|
pub fn Trainer::n_sub_iterations(self : Trainer) -> Int? {
  match self {
    UnigramTrainer(n_sub_iterations~, ..) => Some(n_sub_iterations)
    _ => None
  }
}

///|
pub fn Trainer::seed_size(self : Trainer) -> Int? {
  match self {
    UnigramTrainer(seed_size~, ..) => Some(seed_size)
    _ => None
  }
}

///|
pub fn Trainer::progress_format(self : Trainer) -> String? {
  match self {
    BpeTrainer(progress_format~, ..) => Some(progress_format)
    _ => None
  }
}

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
        unk_token=state.unk_token.unwrap_or("<unk>"),
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
fn trainer_state_to_json(state : TrainerState) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":")
  write_json_string(sb, state.kind)
  sb.write_string(",\"unk_token\":")
  write_optional_string_json(sb, state.unk_token)
  sb.write_string(",\"min_frequency\":")
  sb.write_string(state.min_frequency.to_string())
  sb.write_string(",\"special_tokens\":")
  write_string_array_json(sb, state.special_tokens)
  sb.write_string(",\"special_added_tokens\":")
  write_added_token_array_json(sb, state.special_added_tokens)
  sb.write_string(",\"vocab_size\":")
  write_optional_int_json(sb, state.vocab_size)
  sb.write_string(",\"show_progress\":")
  sb.write_string(bool_json(state.show_progress))
  sb.write_string(",\"continuing_subword_prefix\":")
  write_optional_string_json(sb, state.continuing_subword_prefix)
  sb.write_string(",\"end_of_word_suffix\":")
  write_optional_string_json(sb, state.end_of_word_suffix)
  sb.write_string(",\"max_input_chars_per_word\":")
  write_optional_int_json(sb, state.max_input_chars_per_word)
  sb.write_string(",\"max_token_length\":")
  write_optional_int_json(sb, state.max_token_length)
  sb.write_string(",\"initial_alphabet\":")
  write_string_array_json(sb, state.initial_alphabet)
  sb.write_string(",\"limit_alphabet\":")
  write_optional_int_json(sb, state.limit_alphabet)
  sb.write_string(",\"fuse_unk\":")
  write_optional_bool_json(sb, state.fuse_unk)
  sb.write_string(",\"byte_fallback\":")
  write_optional_bool_json(sb, state.byte_fallback)
  sb.write_string(",\"shrinking_factor\":")
  write_optional_double_json(sb, state.shrinking_factor)
  sb.write_string(",\"max_piece_length\":")
  write_optional_int_json(sb, state.max_piece_length)
  sb.write_string(",\"n_sub_iterations\":")
  write_optional_int_json(sb, state.n_sub_iterations)
  sb.write_string(",\"seed_size\":")
  write_optional_int_json(sb, state.seed_size)
  sb.write_string(",\"progress_format\":")
  write_optional_string_json(sb, state.progress_format)
  sb.write_char('}')
  sb.to_string()
}

///|
fn normalize_progress_format(format : String) -> String {
  match format {
    "json" => "json"
    "silent" => "silent"
    "indicatif" => "indicatif"
    _ => "indicatif"
  }
}

///|
fn write_optional_string_json(sb : StringBuilder, value : String?) -> Unit {
  match value {
    Some(s) => write_json_string(sb, s)
    None => sb.write_string("null")
  }
}

///|
fn write_optional_int_json(sb : StringBuilder, value : Int?) -> Unit {
  match value {
    Some(n) => sb.write_string(n.to_string())
    None => sb.write_string("null")
  }
}

///|
fn write_optional_bool_json(sb : StringBuilder, value : Bool?) -> Unit {
  match value {
    Some(v) => sb.write_string(bool_json(v))
    None => sb.write_string("null")
  }
}

///|
fn write_optional_double_json(sb : StringBuilder, value : Double?) -> Unit {
  match value {
    Some(v) => sb.write_string(v.to_string())
    None => sb.write_string("null")
  }
}

///|
fn write_string_array_json(sb : StringBuilder, values : Array[String]) -> Unit {
  sb.write_char('[')
  for i, value in values {
    if i > 0 {
      sb.write_char(',')
    }
    write_json_string(sb, value)
  }
  sb.write_char(']')
}

///|
fn write_added_token_array_json(
  sb : StringBuilder,
  values : Array[AddedToken],
) -> Unit {
  sb.write_char('[')
  for i, token in values {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_string("{\"content\":")
    write_json_string(sb, token.content)
    sb.write_string(",\"single_word\":")
    sb.write_string(bool_json(token.single_word))
    sb.write_string(",\"lstrip\":")
    sb.write_string(bool_json(token.lstrip))
    sb.write_string(",\"rstrip\":")
    sb.write_string(bool_json(token.rstrip))
    sb.write_string(",\"normalized\":")
    sb.write_string(bool_json(token.normalized))
    sb.write_string(",\"special\":")
    sb.write_string(bool_json(token.special))
    sb.write_char('}')
  }
  sb.write_char(']')
}

///|
/// Train this tokenizer's model in-place style while preserving its configured
/// normalizer, pre-tokenizer, decoder/post-processor/truncation/padding and added
/// vocabulary. Text is first split by added-vocabulary extraction, then passed
/// through the tokenizer's normalizer and pre-tokenizer before reaching the
/// selected model trainer.
pub fn Tokenizer::train(
  self : Tokenizer,
  texts : Array[String],
  trainer : Trainer,
) -> Tokenizer {
  self.train_from_iterator(texts, trainer)
}

///|
/// Alias for HF's `train_from_iterator`; arrays are used as the deterministic
/// iterator representation across MoonBit targets.
pub fn Tokenizer::train_from_iterator(
  self : Tokenizer,
  texts : Array[String],
  trainer : Trainer,
) -> Tokenizer {
  let tokenized = self.training_tokenized_texts(texts)
  let special_added_tokens = trainer_special_added_tokens(trainer)
  let special_tokens = merge_training_special_tokens(
    merge_training_special_tokens(
      trainer_special_tokens(trainer),
      added_tokens_contents(special_added_tokens),
    ),
    self.added_vocabulary.training_special_tokens(),
  )
  let model = match trainer {
    WordLevelTrainer(unk_token~, min_frequency~, vocab_size~, ..) =>
      @model.Model::train_wordlevel_from_tokens(
        tokenized,
        unk_token~,
        min_frequency~,
        special_tokens~,
        vocab_size~,
      )
    WordPieceTrainer(
      unk_token~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      min_frequency~,
      vocab_size~,
      max_input_chars_per_word~,
      max_token_length~,
      initial_alphabet~,
      limit_alphabet~,
      ..
    ) =>
      @model.Model::train_wordpiece_from_tokens(
        tokenized,
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
      )
    BpeTrainer(
      unk_token~,
      min_frequency~,
      vocab_size~,
      continuing_subword_prefix~,
      end_of_word_suffix~,
      fuse_unk~,
      initial_alphabet~,
      limit_alphabet~,
      max_token_length~,
      ..
    ) => {
      let options = self.bpe_training_options()
      @model.Model::train_bpe_from_tokens(
        tokenized,
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
        byte_fallback=options.byte_fallback,
        ignore_merges=options.ignore_merges,
        dropout=options.dropout,
        cache_capacity=options.cache_capacity,
      )
    }
    UnigramTrainer(
      unk_token~,
      min_frequency~,
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
      @model.Model::train_unigram_from_tokens(
        tokenized,
        unk_token~,
        min_frequency~,
        special_tokens~,
        vocab_size~,
        byte_fallback~,
        fuse_unk~,
        max_piece_length~,
        initial_alphabet~,
        shrinking_factor~,
        n_sub_iterations~,
        show_progress~,
        seed_size~,
      )
  }
  let trained = {
    ..self,
    model,
    added_vocabulary: self.added_vocabulary.with_model_ids(
      model,
      self.normalizer,
    ),
    source_json: None,
  }
  if special_added_tokens.length() > 0 {
    trained.add_special_tokens(special_added_tokens)
  } else {
    trained
  }
}

///|
/// Train from line-oriented files. Files are read eagerly to keep behavior
/// deterministic across backends.
pub fn Tokenizer::train_from_files(
  self : Tokenizer,
  files : Array[String],
  trainer : Trainer,
) -> Tokenizer raise @types.TokenizerError {
  let texts : Array[String] = []
  for file in files {
    let content = @fs.read_file_to_string(file) catch {
      _ => raise @types.ParseError("cannot read training file: \{file}")
    }
    for line in split_training_lines(content) {
      texts.push(line)
    }
  }
  self.train_from_iterator(texts, trainer)
}

///|
fn trainer_special_tokens(trainer : Trainer) -> Array[String] {
  match trainer {
    WordLevelTrainer(special_tokens~, ..) => special_tokens.copy()
    WordPieceTrainer(special_tokens~, ..) => special_tokens.copy()
    BpeTrainer(special_tokens~, ..) => special_tokens.copy()
    UnigramTrainer(special_tokens~, ..) => special_tokens.copy()
  }
}

///|
fn trainer_special_added_tokens(trainer : Trainer) -> Array[AddedToken] {
  match trainer {
    WordLevelTrainer(special_added_tokens~, ..) => special_added_tokens.copy()
    WordPieceTrainer(special_added_tokens~, ..) => special_added_tokens.copy()
    BpeTrainer(special_added_tokens~, ..) => special_added_tokens.copy()
    UnigramTrainer(special_added_tokens~, ..) => special_added_tokens.copy()
  }
}

///|
fn added_tokens_contents(tokens : Array[AddedToken]) -> Array[String] {
  tokens.map(t => t.content)
}

///|
fn AddedVocabulary::training_special_tokens(
  self : AddedVocabulary,
) -> Array[String] {
  let out : Array[String] = []
  for info in self.to_infos() {
    if info.special {
      out.push(info.content)
    }
  }
  out
}

///|
fn AddedVocabulary::with_model_ids(
  self : AddedVocabulary,
  model : @model.Model,
  normalizer : @normalizer.Normalizer?,
) -> AddedVocabulary {
  let infos : Array[AddedTokenInfo] = []
  for info in self.to_infos() {
    let id = model.token_to_id(info.content).unwrap_or(info.id)
    infos.push({ ..info, id, })
  }
  AddedVocabulary::new_with_normalizer(
    infos,
    self.get_encode_special_tokens(),
    normalizer,
  )
}

///|
fn merge_training_special_tokens(
  a : Array[String],
  b : Array[String],
) -> Array[String] {
  let seen : Map[String, Bool] = {}
  let out : Array[String] = []
  fn add(tok : String) -> Unit {
    if !seen.contains(tok) {
      seen[tok] = true
      out.push(tok)
    }
  }
  for tok in a {
    add(tok)
  }
  for tok in b {
    add(tok)
  }
  out
}

///|
fn Tokenizer::training_tokenized_texts(
  self : Tokenizer,
  texts : Array[String],
) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for text in texts {
    out.push(self.training_tokenize_text(text))
  }
  out
}

///|
fn Tokenizer::training_tokenize_text(
  self : Tokenizer,
  text : String,
) -> Array[String] {
  let tokens : Array[String] = []
  for seg1 in self.added_vocabulary.extract_stage1(text, keep_special=true) {
    match seg1 {
      Special(value~, ..) => tokens.push(value)
      Normal(text=raw, base_offset~) => {
        let normalized = match self.normalizer {
          Some(nm) => nm.normalize(raw)
          None => raw
        }
        for
          seg2 in self.added_vocabulary.extract_stage2(
            normalized,
            base_offset,
            keep_special=true,
          ) {
          match seg2 {
            Special(value~, ..) => tokens.push(value)
            Normal(text=ntext, base_offset=base2) => {
              let pieces : Array[@types.Split] = match self.pre_tokenizer {
                Some(pt) => pt.pre_tokenize(ntext, base_offset=base2)
                None =>
                  [
                    {
                      value: ntext,
                      offsets: (base2, base2 + ntext.char_length()),
                    },
                  ]
              }
              for piece in pieces {
                tokens.push(piece.value)
              }
            }
          }
        }
      }
    }
  }
  tokens
}

///|
fn split_training_lines(content : String) -> Array[String] {
  let out : Array[String] = []
  let chars = content.to_array()
  let mut sb = StringBuilder::new()
  for c in chars {
    sb.write_char(c)
    if c == '\n' {
      out.push(sb.to_string())
      sb = StringBuilder::new()
    }
  }
  let tail = sb.to_string()
  if !tail.is_empty() || chars.length() == 0 {
    out.push(tail)
  }
  out
}

///|
fn Tokenizer::bpe_training_options(self : Tokenizer) -> BpeTrainingOptions {
  match self.model {
    @model.BPE(m) =>
      {
        byte_fallback: m.byte_fallback,
        ignore_merges: m.ignore_merges,
        dropout: m.dropout,
        cache_capacity: m.cache_capacity,
      }
    _ =>
      {
        byte_fallback: false,
        ignore_merges: false,
        dropout: None,
        cache_capacity: None,
      }
  }
}

///|
/// Train a deterministic WordLevel tokenizer from whitespace-delimited text.
/// Special tokens are assigned first, followed by `unk_token`, then corpus words
/// in first-seen order that meet `min_frequency`.
pub fn Tokenizer::train_wordlevel(
  texts : Array[String],
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer {
  Tokenizer::train_wordlevel_with_pretokenizer(
    texts,
    @pretokenizer.PreTokenizer::whitespace_split(),
    unk_token~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
    show_progress~,
  )
}

///|
/// Train a WordLevel tokenizer using a caller-provided pre-tokenizer, mirroring
/// HF's `Tokenizer.pre_tokenizer + WordLevelTrainer` workflow.
pub fn Tokenizer::train_wordlevel_with_pretokenizer(
  texts : Array[String],
  pre_tokenizer : @pretokenizer.PreTokenizer,
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer {
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(
      pre_tokenizer.pre_tokenize(text, base_offset=0).map(x => x.value),
    )
  }
  Tokenizer::train_wordlevel_from_tokens(
    tokenized,
    unk_token~,
    min_frequency~,
    special_tokens~,
    pre_tokenizer=Some(pre_tokenizer),
    vocab_size~,
    show_progress~,
  )
}

///|
/// Train a WordLevel tokenizer from pre-tokenized token streams. If a
/// pre-tokenizer is supplied, it is attached to the returned tokenizer for raw
/// text encoding and serialization; otherwise raw encode treats input as a
/// single model piece.
pub fn Tokenizer::train_wordlevel_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  pre_tokenizer? : @pretokenizer.PreTokenizer? = None,
  vocab_size? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer {
  {
    normalizer: None,
    pre_tokenizer,
    model: @model.Model::train_wordlevel_from_tokens(
      tokenized_texts,
      unk_token~,
      min_frequency~,
      special_tokens~,
      vocab_size~,
      show_progress~,
    ),
    post_processor: None,
    decoder: None,
    component_hooks: TokenizerComponentHooks::empty(),
    added_vocabulary: AddedVocabulary::new([]),
    truncation: None,
    padding: None,
    source_json: None,
  }
}

///|
/// Train a deterministic WordPiece tokenizer from whitespace-delimited text.
pub fn Tokenizer::train_wordpiece(
  texts : Array[String],
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None,
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
  max_token_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer {
  Tokenizer::train_wordpiece_with_pretokenizer(
    texts,
    @pretokenizer.PreTokenizer::whitespace_split(),
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
  )
}

///|
/// Train a WordPiece tokenizer with a caller-provided pre-tokenizer.
pub fn Tokenizer::train_wordpiece_with_pretokenizer(
  texts : Array[String],
  pre_tokenizer : @pretokenizer.PreTokenizer,
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None,
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
  max_token_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer {
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(
      pre_tokenizer.pre_tokenize(text, base_offset=0).map(x => x.value),
    )
  }
  Tokenizer::train_wordpiece_from_tokens(
    tokenized,
    unk_token~,
    continuing_subword_prefix~,
    end_of_word_suffix~,
    min_frequency~,
    special_tokens~,
    pre_tokenizer=Some(pre_tokenizer),
    vocab_size~,
    max_input_chars_per_word~,
    max_token_length~,
    initial_alphabet~,
    limit_alphabet~,
    show_progress~,
  )
}

///|
/// Train a WordPiece tokenizer from pre-tokenized token streams.
pub fn Tokenizer::train_wordpiece_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None,
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  pre_tokenizer? : @pretokenizer.PreTokenizer? = None,
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
  max_token_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer {
  {
    normalizer: None,
    pre_tokenizer,
    model: @model.Model::train_wordpiece_from_tokens(
      tokenized_texts,
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
    ),
    post_processor: None,
    decoder: None,
    component_hooks: TokenizerComponentHooks::empty(),
    added_vocabulary: AddedVocabulary::new([]),
    truncation: None,
    padding: None,
    source_json: None,
  }
}

///|
/// Train a deterministic BPE tokenizer from whitespace-delimited text.
pub fn Tokenizer::train_bpe(
  texts : Array[String],
  unk_token? : String? = Some("[UNK]"),
  min_frequency? : Int = 2,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  continuing_subword_prefix? : String? = None,
  end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  max_token_length? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer {
  Tokenizer::train_bpe_with_pretokenizer(
    texts,
    @pretokenizer.PreTokenizer::whitespace_split(),
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
  )
}

///|
/// Train a BPE tokenizer with a caller-provided pre-tokenizer.
pub fn Tokenizer::train_bpe_with_pretokenizer(
  texts : Array[String],
  pre_tokenizer : @pretokenizer.PreTokenizer,
  unk_token? : String? = Some("[UNK]"),
  min_frequency? : Int = 2,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  continuing_subword_prefix? : String? = None,
  end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  max_token_length? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer {
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(
      pre_tokenizer.pre_tokenize(text, base_offset=0).map(x => x.value),
    )
  }
  Tokenizer::train_bpe_from_tokens(
    tokenized,
    unk_token~,
    min_frequency~,
    special_tokens~,
    pre_tokenizer=Some(pre_tokenizer),
    vocab_size~,
    continuing_subword_prefix~,
    end_of_word_suffix~,
    fuse_unk~,
    initial_alphabet~,
    limit_alphabet~,
    max_token_length~,
    show_progress~,
  )
}

///|
/// Train a BPE tokenizer from pre-tokenized token streams.
pub fn Tokenizer::train_bpe_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String? = Some("[UNK]"),
  min_frequency? : Int = 2,
  special_tokens? : Array[String] = [],
  pre_tokenizer? : @pretokenizer.PreTokenizer? = None,
  vocab_size? : Int? = None,
  continuing_subword_prefix? : String? = None,
  end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  max_token_length? : Int? = None,
  show_progress? : Bool = true,
) -> Tokenizer {
  {
    normalizer: None,
    pre_tokenizer,
    model: @model.Model::train_bpe_from_tokens(
      tokenized_texts,
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
    ),
    post_processor: None,
    decoder: None,
    component_hooks: TokenizerComponentHooks::empty(),
    added_vocabulary: AddedVocabulary::new([]),
    truncation: None,
    padding: None,
    source_json: None,
  }
}

///|
/// Train a deterministic Unigram tokenizer from whitespace-delimited text.
pub fn Tokenizer::train_unigram(
  texts : Array[String],
  unk_token? : String = "<unk>",
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
  max_piece_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  shrinking_factor? : Double = 0.75,
  n_sub_iterations? : Int = 2,
  show_progress? : Bool = true,
  seed_size? : Int = 1000000,
) -> Tokenizer {
  let unk_token = match unk_piece {
    Some(piece) => piece
    None => unk_token
  }
  Tokenizer::train_unigram_with_pretokenizer(
    texts,
    @pretokenizer.PreTokenizer::whitespace_split(),
    unk_token~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
    byte_fallback~,
    fuse_unk~,
    max_piece_length~,
    initial_alphabet~,
    shrinking_factor~,
    n_sub_iterations~,
    show_progress~,
    seed_size~,
  )
}

///|
/// Train a Unigram tokenizer with a caller-provided pre-tokenizer.
pub fn Tokenizer::train_unigram_with_pretokenizer(
  texts : Array[String],
  pre_tokenizer : @pretokenizer.PreTokenizer,
  unk_token? : String = "<unk>",
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
  max_piece_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  shrinking_factor? : Double = 0.75,
  n_sub_iterations? : Int = 2,
  show_progress? : Bool = true,
  seed_size? : Int = 1000000,
) -> Tokenizer {
  let unk_token = match unk_piece {
    Some(piece) => piece
    None => unk_token
  }
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(
      pre_tokenizer.pre_tokenize(text, base_offset=0).map(x => x.value),
    )
  }
  Tokenizer::train_unigram_from_tokens(
    tokenized,
    unk_token~,
    min_frequency~,
    special_tokens~,
    pre_tokenizer=Some(pre_tokenizer),
    vocab_size~,
    byte_fallback~,
    fuse_unk~,
    max_piece_length~,
    initial_alphabet~,
    shrinking_factor~,
    n_sub_iterations~,
    show_progress~,
    seed_size~,
  )
}

///|
/// Train a Unigram tokenizer from pre-tokenized token streams.
pub fn Tokenizer::train_unigram_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String = "<unk>",
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  pre_tokenizer? : @pretokenizer.PreTokenizer? = None,
  vocab_size? : Int? = None,
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
  max_piece_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  shrinking_factor? : Double = 0.75,
  n_sub_iterations? : Int = 2,
  show_progress? : Bool = true,
  seed_size? : Int = 1000000,
) -> Tokenizer {
  let unk_token = match unk_piece {
    Some(piece) => piece
    None => unk_token
  }
  {
    normalizer: None,
    pre_tokenizer,
    model: @model.Model::train_unigram_from_tokens(
      tokenized_texts,
      unk_token~,
      min_frequency~,
      special_tokens~,
      vocab_size~,
      byte_fallback~,
      fuse_unk~,
      max_piece_length~,
      initial_alphabet~,
      shrinking_factor~,
      n_sub_iterations~,
      show_progress~,
      seed_size~,
    ),
    post_processor: None,
    decoder: None,
    component_hooks: TokenizerComponentHooks::empty(),
    added_vocabulary: AddedVocabulary::new([]),
    truncation: None,
    padding: None,
    source_json: None,
  }
}
