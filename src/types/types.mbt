// Core shared types for the tokenizer library.

/// The output of `Tokenizer::encode`, mirroring HuggingFace's `Encoding`.
pub struct Encoding {
  ids : Array[Int]
  type_ids : Array[Int]
  tokens : Array[String]
  offsets : Array[(Int, Int)]
  special_tokens_mask : Array[Int]
  attention_mask : Array[Int]
} derive(Show, Eq)

/// A token produced by a model: its id, surface string and char offsets.
pub struct Token {
  id : Int
  value : String
  offsets : (Int, Int)
} derive(Show, Eq)

/// An intermediate piece produced by pre-tokenization: a substring plus the
/// char offsets it occupies in the original (normalized) text.
pub struct Split {
  value : String
  offsets : (Int, Int)
} derive(Show, Eq)

/// Errors raised across the tokenizer pipeline.
pub(all) suberror TokenizerError {
  /// The tokenizer.json could not be parsed or had an unexpected shape.
  ParseError(String)
  /// A normalizer/pre_tokenizer/model/decoder type that is not yet implemented.
  UnsupportedComponent(String)
  /// vocab / merges data was malformed.
  VocabError(String)
} derive(Show)

/// Build an empty `Encoding`.
pub fn Encoding::empty() -> Encoding {
  {
    ids: [],
    type_ids: [],
    tokens: [],
    offsets: [],
    special_tokens_mask: [],
    attention_mask: [],
  }
}
