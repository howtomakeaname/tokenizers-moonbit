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
) -> Tokenizer {
  {
    normalizer: None,
    pre_tokenizer: Some(@pretokenizer.PreTokenizer::whitespace_split()),
    model: @model.Model::train_wordlevel(
      texts,
      unk_token~,
      min_frequency~,
      special_tokens~,
    ),
    post_processor: None,
    decoder: None,
    added_vocabulary: AddedVocabulary::new([]),
    truncation: None,
    padding: None,
    source_json: None,
  }
}
