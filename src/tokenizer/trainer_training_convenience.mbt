///|
/// in first-seen order that meet `min_frequency`.
pub fn Tokenizer::train_wordlevel(
  texts : Array[String],
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = Some(30000),
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
  vocab_size? : Int? = Some(30000),
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
  vocab_size? : Int? = Some(30000),
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
  vocab_size? : Int? = Some(30000),
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
  vocab_size? : Int? = Some(30000),
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
  vocab_size? : Int? = Some(30000),
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
  unk_token? : String? = None,
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = Some(30000),
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
  unk_token? : String? = None,
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = Some(30000),
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
  unk_token? : String? = None,
  min_frequency? : Int = 0,
  special_tokens? : Array[String] = [],
  pre_tokenizer? : @pretokenizer.PreTokenizer? = None,
  vocab_size? : Int? = Some(30000),
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
  unk_token? : String? = None,
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = Some(8000),
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
    Some(piece) => Some(piece)
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
  unk_token? : String? = None,
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = Some(8000),
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
    Some(piece) => Some(piece)
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
  unk_token? : String? = None,
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  pre_tokenizer? : @pretokenizer.PreTokenizer? = None,
  vocab_size? : Int? = Some(8000),
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
    Some(piece) => Some(piece)
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
