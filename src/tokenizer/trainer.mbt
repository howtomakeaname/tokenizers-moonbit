// Minimal tokenizer-level training helpers.

///|
/// Train a deterministic WordLevel tokenizer from whitespace-delimited text.
/// Special tokens are assigned first, followed by `unk_token`, then corpus words
/// in first-seen order that meet `min_frequency`.
pub fn Tokenizer::train_wordlevel(
  texts : Array[String],
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
) -> Tokenizer {
  Tokenizer::train_wordlevel_with_pretokenizer(
    texts,
    @pretokenizer.PreTokenizer::whitespace_split(),
    unk_token~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
  )
}

///|
/// Train a WordLevel tokenizer using a caller-provided pre-tokenizer, mirroring
/// HF's `Tokenizer.pre_tokenizer + WordLevelTrainer` workflow.
pub fn Tokenizer::train_wordlevel_with_pretokenizer(
  texts : Array[String],
  pre_tokenizer : @pretokenizer.PreTokenizer,
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
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
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  pre_tokenizer? : @pretokenizer.PreTokenizer? = None,
  vocab_size? : Int? = None,
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
    ),
    post_processor: None,
    decoder: None,
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
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
) -> Tokenizer {
  Tokenizer::train_wordpiece_with_pretokenizer(
    texts,
    @pretokenizer.PreTokenizer::whitespace_split(),
    unk_token~,
    continuing_subword_prefix~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
    max_input_chars_per_word~,
  )
}

///|
/// Train a WordPiece tokenizer with a caller-provided pre-tokenizer.
pub fn Tokenizer::train_wordpiece_with_pretokenizer(
  texts : Array[String],
  pre_tokenizer : @pretokenizer.PreTokenizer,
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
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
    min_frequency~,
    special_tokens~,
    pre_tokenizer=Some(pre_tokenizer),
    vocab_size~,
    max_input_chars_per_word~,
  )
}

///|
/// Train a WordPiece tokenizer from pre-tokenized token streams.
pub fn Tokenizer::train_wordpiece_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  pre_tokenizer? : @pretokenizer.PreTokenizer? = None,
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
) -> Tokenizer {
  {
    normalizer: None,
    pre_tokenizer,
    model: @model.Model::train_wordpiece_from_tokens(
      tokenized_texts,
      unk_token~,
      continuing_subword_prefix~,
      min_frequency~,
      special_tokens~,
      vocab_size~,
      max_input_chars_per_word~,
    ),
    post_processor: None,
    decoder: None,
    added_vocabulary: AddedVocabulary::new([]),
    truncation: None,
    padding: None,
    source_json: None,
  }
}
