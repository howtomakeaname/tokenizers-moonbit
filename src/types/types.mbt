// Core shared types for the tokenizer library.

///|
/// The output of `Tokenizer::encode`, mirroring HuggingFace's `Encoding`.
pub(all) struct Encoding {
  ids : Array[Int]
  type_ids : Array[Int]
  tokens : Array[String]
  offsets : Array[(Int, Int)]
  special_tokens_mask : Array[Int]
  attention_mask : Array[Int]
  // Sequence id for each token: Some(0) for A, Some(1) for B, None for
  // post-processor/padding special tokens. Mirrors HF Encoding.sequence_ids().
  sequence_ids : Array[Int?]
  // Truncation overflow windows (empty unless truncation with stride trims).
  overflowing : Array[Encoding]
} derive(Debug, Eq)

///|
/// Return per-token sequence ids (`None` for special/padding tokens).
pub fn Encoding::sequence_ids(self : Encoding) -> Array[Int?] {
  self.sequence_ids.copy()
}

///|
/// A token produced by a model: its id, surface string and char offsets.
pub(all) struct Token {
  id : Int
  value : String
  offsets : (Int, Int)
} derive(Debug, Eq)

///|
/// An intermediate piece produced by pre-tokenization: a substring plus the
/// char offsets it occupies in the original (normalized) text.
pub(all) struct Split {
  value : String
  offsets : (Int, Int)
} derive(Debug, Eq)

///|
/// Errors raised across the tokenizer pipeline.
pub(all) suberror TokenizerError {
  /// The tokenizer.json could not be parsed or had an unexpected shape.
  ParseError(String)
  /// A normalizer/pre_tokenizer/model/decoder type that is not yet implemented.
  UnsupportedComponent(String)
  /// vocab / merges data was malformed.
  VocabError(String)
} derive(Debug)

///|
/// Build an empty `Encoding`.
pub fn Encoding::empty() -> Encoding {
  {
    ids: [],
    type_ids: [],
    tokens: [],
    offsets: [],
    special_tokens_mask: [],
    attention_mask: [],
    sequence_ids: [],
    overflowing: [],
  }
}
