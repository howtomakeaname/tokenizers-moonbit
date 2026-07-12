///|
pub fn Encoding::len(self : Encoding) -> Int {
  self.ids.length()
}

///|
/// Whether this encoding contains no tokens.
pub fn Encoding::is_empty(self : Encoding) -> Bool {
  self.ids.length() == 0
}

///|
/// Number of input sequences represented by this encoding. Pair encodings
/// return `2`; single encodings return `1`; empty/special-only encodings return
/// `0` because no token carries a sequence id.
pub fn Encoding::n_sequences(self : Encoding) -> Int {
  let mut max_seq = -1
  for sid in self.sequence_ids {
    match sid {
      Some(seq) => if seq > max_seq { max_seq = seq }
      None => ()
    }
  }
  max_seq + 1
}

///|
/// HF/Python binding naming alias for `n_sequences`.
pub fn Encoding::get_n_sequences(self : Encoding) -> Int {
  self.n_sequences()
}

///|
/// Return token ids. The returned array is a copy, matching HF-style immutable
/// accessor expectations and preventing callers from mutating the encoding.
pub fn Encoding::get_ids(self : Encoding) -> Array[Int] {
  self.ids.copy()
}

///|
/// Python/property-style alias for `get_ids`.
pub fn Encoding::ids(self : Encoding) -> Array[Int] {
  self.get_ids()
}

///|
/// Return per-token type ids.
pub fn Encoding::get_type_ids(self : Encoding) -> Array[Int] {
  self.type_ids.copy()
}

///|
/// Python/property-style alias for `get_type_ids`.
pub fn Encoding::type_ids(self : Encoding) -> Array[Int] {
  self.get_type_ids()
}

///|
/// Return token surface strings.
pub fn Encoding::get_tokens(self : Encoding) -> Array[String] {
  self.tokens.copy()
}

///|
/// Python/property-style alias for `get_tokens`.
pub fn Encoding::tokens(self : Encoding) -> Array[String] {
  self.get_tokens()
}

///|
/// Return per-token offsets. Offsets are char offsets by default and byte
/// offsets for explicit byte-offset encode APIs.
pub fn Encoding::get_offsets(self : Encoding) -> Array[(Int, Int)] {
  self.offsets.copy()
}

///|
/// Python/property-style alias for `get_offsets`.
pub fn Encoding::offsets(self : Encoding) -> Array[(Int, Int)] {
  self.get_offsets()
}

///|
/// Return the HF-style special tokens mask (`1` for special/padding, `0` for
/// ordinary tokens).
pub fn Encoding::get_special_tokens_mask(self : Encoding) -> Array[Int] {
  self.special_tokens_mask.copy()
}

///|
/// Python/property-style alias for `get_special_tokens_mask`.
pub fn Encoding::special_tokens_mask(self : Encoding) -> Array[Int] {
  self.get_special_tokens_mask()
}

///|
/// Return the HF-style attention mask (`1` for real tokens, `0` for padding).
pub fn Encoding::get_attention_mask(self : Encoding) -> Array[Int] {
  self.attention_mask.copy()
}

///|
/// Python/property-style alias for `get_attention_mask`.
pub fn Encoding::attention_mask(self : Encoding) -> Array[Int] {
  self.get_attention_mask()
}

///|
/// Return truncation overflow windows.
pub fn Encoding::get_overflowing(self : Encoding) -> Array[Encoding] {
  self.overflowing.copy()
}

///|
/// Python/property-style alias for `get_overflowing`.
pub fn Encoding::overflowing(self : Encoding) -> Array[Encoding] {
  self.get_overflowing()
}

///|
/// HF-style alias for `sequence_ids()`.
pub fn Encoding::get_sequence_ids(self : Encoding) -> Array[Int?] {
  self.sequence_ids.copy()
}

///|
/// HF-style alias for `word_ids()`.
pub fn Encoding::get_word_ids(self : Encoding) -> Array[Int?] {
  self.word_ids.copy()
}

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
/// Deprecated HF/Python property alias for `word_ids`.
pub fn Encoding::words(self : Encoding) -> Array[Int?] {
  self.word_ids()
}
