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
  // Word/pre-token id for each token. For raw strings this is the pre-token
  // piece index after added-vocabulary/normalization/pre-tokenization. Special
  // and padding tokens use None, matching HF's optional word ids.
  word_ids : Array[Int?]
  // Truncation overflow windows (empty unless truncation with stride trims).
  overflowing : Array[Encoding]
} derive(Debug, Eq)

///|
/// Return per-token sequence ids (`None` for special/padding tokens).
pub fn Encoding::sequence_ids(self : Encoding) -> Array[Int?] {
  self.sequence_ids.copy()
}

///|
/// Return per-token word ids (`None` for special/padding tokens).
pub fn Encoding::word_ids(self : Encoding) -> Array[Int?] {
  self.word_ids.copy()
}

///|
/// Return the input sequence id that produced token `token`, or `None` for
/// special/padding tokens and out-of-range indices.
pub fn Encoding::token_to_sequence(self : Encoding, token : Int) -> Int? {
  if token < 0 || token >= self.sequence_ids.length() {
    None
  } else {
    self.sequence_ids[token]
  }
}

///|
/// Return `(sequence_id, offsets)` for token `token`, mirroring HF's
/// `Encoding.token_to_chars`. Special/padding tokens return `None`.
pub fn Encoding::token_to_chars(
  self : Encoding,
  token : Int,
) -> (Int, (Int, Int))? {
  match self.token_to_sequence(token) {
    Some(seq) => Some((seq, self.offsets[token]))
    None => None
  }
}

///|
/// Get the word that contains the token at index `token`.
pub fn Encoding::token_to_word(self : Encoding, token : Int) -> (Int, Int)? {
  match self.token_to_sequence(token) {
    Some(seq) =>
      if token >= 0 && token < self.word_ids.length() {
        match self.word_ids[token] {
          Some(w) => Some((seq, w))
          None => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
/// Get the half-open token range `[start, end)` for `word` in `sequence_id`.
pub fn Encoding::word_to_tokens(
  self : Encoding,
  word : Int,
  sequence_id? : Int = 0,
) -> (Int, Int)? {
  let mut start : Int? = None
  let mut stop : Int? = None
  for i in 0..<self.word_ids.length() {
    if self.sequence_ids[i] == Some(sequence_id) &&
      self.word_ids[i] == Some(word) {
      if start is None {
        start = Some(i)
      }
      stop = Some(i + 1)
    }
  }
  match (start, stop) {
    (Some(s), Some(e)) => Some((s, e))
    _ => None
  }
}

///|
/// Get character/byte offsets covering `word` in `sequence_id`.
pub fn Encoding::word_to_chars(
  self : Encoding,
  word : Int,
  sequence_id? : Int = 0,
) -> (Int, Int)? {
  match self.word_to_tokens(word, sequence_id~) {
    Some((start, stop)) =>
      if stop > start {
        Some((self.offsets[start].0, self.offsets[stop - 1].1))
      } else {
        None
      }
    None => None
  }
}

///|
/// Return the first token index in `sequence_id` whose offsets contain `pos`.
/// Offsets are half-open: `[start, end)`, matching HF tokenizers.
pub fn Encoding::char_to_token(
  self : Encoding,
  pos : Int,
  sequence_id? : Int = 0,
) -> Int? {
  for i in 0..<self.offsets.length() {
    guard self.sequence_ids[i] is Some(seq) else { continue }
    if seq != sequence_id {
      continue
    }
    let (start, stop) = self.offsets[i]
    if pos >= start && pos < stop {
      return Some(i)
    }
  }
  None
}

///|
/// Get the word id containing position `pos` in `sequence_id`.
pub fn Encoding::char_to_word(
  self : Encoding,
  pos : Int,
  sequence_id? : Int = 0,
) -> Int? {
  match self.char_to_token(pos, sequence_id~) {
    Some(tok) =>
      match self.token_to_word(tok) {
        Some((_, word)) => Some(word)
        None => None
      }
    None => None
  }
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
    word_ids: [],
    overflowing: [],
  }
}
