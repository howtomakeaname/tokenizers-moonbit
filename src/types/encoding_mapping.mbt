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
/// Python-binding getter alias for `token_to_sequence`.
pub fn Encoding::get_token_sequence(self : Encoding, token : Int) -> Int? {
  self.token_to_sequence(token)
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
/// Python-binding getter alias for `token_to_chars`.
pub fn Encoding::get_token_chars(
  self : Encoding,
  token : Int,
) -> (Int, (Int, Int))? {
  self.token_to_chars(token)
}

///|
/// Convenience alias returning only the char/byte offsets for a token.
pub fn Encoding::token_to_offsets(self : Encoding, token : Int) -> (Int, Int)? {
  match self.token_to_chars(token) {
    Some((_, offsets)) => Some(offsets)
    None => None
  }
}

///|
/// HF Python shape helper returning only `(start, end)` for a token.
pub fn Encoding::token_to_char_offsets(
  self : Encoding,
  token : Int,
) -> (Int, Int)? {
  self.token_to_offsets(token)
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
/// Python-binding getter alias for `token_to_word`.
pub fn Encoding::get_token_word(self : Encoding, token : Int) -> (Int, Int)? {
  self.token_to_word(token)
}

///|
/// HF Python shape helper returning only the word index for a token.
pub fn Encoding::token_to_word_index(self : Encoding, token : Int) -> Int? {
  match self.token_to_word(token) {
    Some((_, word)) => Some(word)
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
/// Python-binding getter alias for `word_to_tokens`.
pub fn Encoding::get_word_tokens(
  self : Encoding,
  word : Int,
  sequence_id? : Int = 0,
) -> (Int, Int)? {
  self.word_to_tokens(word, sequence_id~)
}

///|
/// HF Python naming alias for `word_to_tokens(..., sequence_index=...)`.
pub fn Encoding::word_to_tokens_by_sequence_index(
  self : Encoding,
  word : Int,
  sequence_index? : Int = 0,
) -> (Int, Int)? {
  self.word_to_tokens(word, sequence_id=sequence_index)
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
/// Python-binding getter alias for `word_to_chars`.
pub fn Encoding::get_word_chars(
  self : Encoding,
  word : Int,
  sequence_id? : Int = 0,
) -> (Int, Int)? {
  self.word_to_chars(word, sequence_id~)
}

///|
/// HF Python naming alias for `word_to_chars(..., sequence_index=...)`.
pub fn Encoding::word_to_chars_by_sequence_index(
  self : Encoding,
  word : Int,
  sequence_index? : Int = 0,
) -> (Int, Int)? {
  self.word_to_chars(word, sequence_id=sequence_index)
}

///|
/// Naming alias for binding layers that expose offsets instead of chars.
pub fn Encoding::word_to_offsets(
  self : Encoding,
  word : Int,
  sequence_id? : Int = 0,
) -> (Int, Int)? {
  self.word_to_chars(word, sequence_id~)
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
/// Python-binding getter alias for `char_to_token`.
pub fn Encoding::get_char_token(
  self : Encoding,
  pos : Int,
  sequence_id? : Int = 0,
) -> Int? {
  self.char_to_token(pos, sequence_id~)
}

///|
/// HF Python naming alias for `char_to_token(..., sequence_index=...)`.
pub fn Encoding::char_to_token_by_sequence_index(
  self : Encoding,
  pos : Int,
  sequence_index? : Int = 0,
) -> Int? {
  self.char_to_token(pos, sequence_id=sequence_index)
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
/// Python-binding getter alias for `char_to_word`.
pub fn Encoding::get_char_word(
  self : Encoding,
  pos : Int,
  sequence_id? : Int = 0,
) -> Int? {
  self.char_to_word(pos, sequence_id~)
}

///|
/// HF Python naming alias for `char_to_word(..., sequence_index=...)`.
pub fn Encoding::char_to_word_by_sequence_index(
  self : Encoding,
  pos : Int,
  sequence_index? : Int = 0,
) -> Int? {
  self.char_to_word(pos, sequence_id=sequence_index)
}

///|
/// A token produced by a model: its id, surface string and char offsets.
