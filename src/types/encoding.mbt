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
/// Serializable/interoperable snapshot of an `Encoding`. This mirrors the shape
/// Python binding layers need for pickle/state transfer while keeping the core
/// MoonBit API strongly typed.
pub(all) struct EncodingState {
  ids : Array[Int]
  type_ids : Array[Int]
  tokens : Array[String]
  offsets : Array[(Int, Int)]
  special_tokens_mask : Array[Int]
  attention_mask : Array[Int]
  sequence_ids : Array[Int?]
  word_ids : Array[Int?]
  overflowing : Array[Encoding]
} derive(Debug, Eq)

///|
/// Compact tuple-oriented interop view of an `Encoding`. Python bindings often
/// move ids/type ids/tokens/offsets/masks as parallel buffers; this shape keeps
/// that common path explicit while `EncodingState` remains the full pickle state.
pub(all) struct EncodingBuffers {
  ids : Array[Int]
  type_ids : Array[Int]
  tokens : Array[String]
  offsets : Array[(Int, Int)]
  special_tokens_mask : Array[Int]
  attention_mask : Array[Int]
} derive(Debug, Eq)

///|
/// Direction used by HF-style public Encoding manipulation helpers.
pub(all) enum EncodingDirection {
  Left
  Right
} derive(Debug, Eq)

///|
/// Build an Encoding from its parallel arrays. Optional metadata arrays default
/// to HF-compatible values (`sequence_ids`/`word_ids` all `Some(0)`/`None`, no
/// overflowing windows) when omitted.
pub fn Encoding::new(
  ids : Array[Int],
  type_ids : Array[Int],
  tokens : Array[String],
  offsets : Array[(Int, Int)],
  special_tokens_mask : Array[Int],
  attention_mask : Array[Int],
  sequence_ids? : Array[Int?] = [],
  word_ids? : Array[Int?] = [],
  overflowing? : Array[Encoding] = [],
) -> Encoding raise TokenizerError {
  validate_encoding_required_lengths(
    ids, type_ids, tokens, offsets, special_tokens_mask, attention_mask,
  )
  validate_encoding_optional_length(
    "sequence_ids",
    sequence_ids.length(),
    ids.length(),
  )
  validate_encoding_optional_length("word_ids", word_ids.length(), ids.length())
  encoding_from_parts_unchecked(
    ids,
    type_ids,
    tokens,
    offsets,
    special_tokens_mask,
    attention_mask,
    sequence_ids~,
    word_ids~,
    overflowing~,
  )
}

///|
fn encoding_from_parts_unchecked(
  ids : Array[Int],
  type_ids : Array[Int],
  tokens : Array[String],
  offsets : Array[(Int, Int)],
  special_tokens_mask : Array[Int],
  attention_mask : Array[Int],
  sequence_ids~ : Array[Int?],
  word_ids~ : Array[Int?],
  overflowing~ : Array[Encoding],
) -> Encoding {
  let n = ids.length()
  {
    ids: ids.copy(),
    type_ids: type_ids.copy(),
    tokens: tokens.copy(),
    offsets: offsets.copy(),
    special_tokens_mask: special_tokens_mask.copy(),
    attention_mask: attention_mask.copy(),
    sequence_ids: if sequence_ids.length() == n {
      sequence_ids.copy()
    } else {
      Array::make(n, Some(0))
    },
    word_ids: if word_ids.length() == n {
      word_ids.copy()
    } else {
      Array::make(n, None)
    },
    overflowing: overflowing.copy(),
  }
}

///|
fn validate_encoding_required_lengths(
  ids : Array[Int],
  type_ids : Array[Int],
  tokens : Array[String],
  offsets : Array[(Int, Int)],
  special_tokens_mask : Array[Int],
  attention_mask : Array[Int],
) -> Unit raise TokenizerError {
  let n = ids.length()
  validate_encoding_length("type_ids", type_ids.length(), n)
  validate_encoding_length("tokens", tokens.length(), n)
  validate_encoding_length("offsets", offsets.length(), n)
  validate_encoding_length(
    "special_tokens_mask",
    special_tokens_mask.length(),
    n,
  )
  validate_encoding_length("attention_mask", attention_mask.length(), n)
}

///|
fn validate_encoding_optional_length(
  name : String,
  actual : Int,
  expected : Int,
) -> Unit raise TokenizerError {
  if actual != 0 {
    validate_encoding_length(name, actual, expected)
  }
}

///|
fn validate_encoding_length(
  name : String,
  actual : Int,
  expected : Int,
) -> Unit raise TokenizerError {
  if actual != expected {
    raise ParseError(
      "Encoding \{name} length \{actual} does not match ids length \{expected}",
    )
  }
}

///|
/// Restore an Encoding from an interop state snapshot.
pub fn Encoding::from_state(
  state : EncodingState,
) -> Encoding raise TokenizerError {
  Encoding::new(
    state.ids,
    state.type_ids,
    state.tokens,
    state.offsets,
    state.special_tokens_mask,
    state.attention_mask,
    sequence_ids=state.sequence_ids,
    word_ids=state.word_ids,
    overflowing=state.overflowing,
  )
}

///|
/// Build an Encoding from the common parallel-buffer representation. Optional
/// metadata arrays follow the same defaults as `Encoding::new`.
pub fn Encoding::from_buffers(
  buffers : EncodingBuffers,
  sequence_ids? : Array[Int?] = [],
  word_ids? : Array[Int?] = [],
  overflowing? : Array[Encoding] = [],
) -> Encoding raise TokenizerError {
  Encoding::new(
    buffers.ids,
    buffers.type_ids,
    buffers.tokens,
    buffers.offsets,
    buffers.special_tokens_mask,
    buffers.attention_mask,
    sequence_ids~,
    word_ids~,
    overflowing~,
  )
}

///|
/// Return a Python-binding-friendly state snapshot. Arrays are copied so callers
/// cannot mutate the original encoding through the returned value.
pub fn Encoding::get_state(self : Encoding) -> EncodingState {
  {
    ids: self.ids.copy(),
    type_ids: self.type_ids.copy(),
    tokens: self.tokens.copy(),
    offsets: self.offsets.copy(),
    special_tokens_mask: self.special_tokens_mask.copy(),
    attention_mask: self.attention_mask.copy(),
    sequence_ids: self.sequence_ids.copy(),
    word_ids: self.word_ids.copy(),
    overflowing: self.overflowing.copy(),
  }
}

///|
/// Return the compact parallel-buffer view used by many binding layers.
pub fn Encoding::get_buffers(self : Encoding) -> EncodingBuffers {
  {
    ids: self.ids.copy(),
    type_ids: self.type_ids.copy(),
    tokens: self.tokens.copy(),
    offsets: self.offsets.copy(),
    special_tokens_mask: self.special_tokens_mask.copy(),
    attention_mask: self.attention_mask.copy(),
  }
}

///|
/// Tuple alias for simple Python/Rust FFI shims that already marshal a single
/// state object.
pub fn Encoding::as_buffers(self : Encoding) -> EncodingBuffers {
  self.get_buffers()
}

///|
/// Python pickle compatibility alias for `get_state`.
pub fn Encoding::__getstate__(self : Encoding) -> EncodingState {
  self.get_state()
}

///|
/// Python pickle compatibility alias for restoring an Encoding state.
pub fn Encoding::__setstate__(
  state : EncodingState,
) -> Encoding raise TokenizerError {
  Encoding::from_state(state)
}

///|
/// Python binding convenience alias for `len(encoding)` shims.
pub fn Encoding::__len__(self : Encoding) -> Int {
  self.len()
}

///|
/// Python binding alias for `str(encoding)`.
pub fn Encoding::__str__(self : Encoding) -> String {
  self.__repr__()
}

///|
/// Python binding alias for `repr(encoding)`.
pub fn Encoding::__repr__(self : Encoding) -> String {
  "Encoding(num_tokens=" +
  self.ids.length().to_string() +
  ", attributes=[ids, type_ids, tokens, offsets, attention_mask, special_tokens_mask, overflowing])"
}

///|
/// Build an Encoding from the full HF-style tuple representation. This is
/// intentionally equivalent to `Encoding::from_state` but easier for thin
/// Python/FFI shims that already marshal positional buffers.
pub fn Encoding::from_tuple(
  t : (
    Array[Int],
    Array[Int],
    Array[String],
    Array[(Int, Int)],
    Array[Int],
    Array[Int],
    Array[Int?],
    Array[Int?],
    Array[Encoding],
  ),
) -> Encoding raise TokenizerError {
  Encoding::new(
    t.0,
    t.1,
    t.2,
    t.3,
    t.4,
    t.5,
    sequence_ids=t.6,
    word_ids=t.7,
    overflowing=t.8,
  )
}

///|
/// Return the full positional buffer tuple used by simple binding layers.
/// Arrays are copied through `get_state` to avoid exposing mutable internals.
pub fn Encoding::as_tuple(
  self : Encoding,
) -> (
  Array[Int],
  Array[Int],
  Array[String],
  Array[(Int, Int)],
  Array[Int],
  Array[Int],
  Array[Int?],
  Array[Int?],
  Array[Encoding],
) {
  let state = self.get_state()
  (
    state.ids,
    state.type_ids,
    state.tokens,
    state.offsets,
    state.special_tokens_mask,
    state.attention_mask,
    state.sequence_ids,
    state.word_ids,
    state.overflowing,
  )
}

///|
/// Build an Encoding from model tokens, mirroring HF's `Encoding::from_tokens`.
pub fn Encoding::from_tokens(
  tokens : Array[Token],
  type_id? : Int = 0,
) -> Encoding {
  let ids : Array[Int] = []
  let type_ids : Array[Int] = []
  let values : Array[String] = []
  let offsets : Array[(Int, Int)] = []
  let special : Array[Int] = []
  let attention : Array[Int] = []
  let sequence_ids : Array[Int?] = []
  let word_ids : Array[Int?] = []
  for i, t in tokens {
    ids.push(t.id)
    type_ids.push(type_id)
    values.push(t.value)
    offsets.push(t.offsets)
    special.push(0)
    attention.push(1)
    sequence_ids.push(Some(0))
    word_ids.push(Some(i))
  }
  encoding_from_parts_unchecked(
    ids,
    type_ids,
    values,
    offsets,
    special,
    attention,
    sequence_ids~,
    word_ids~,
    overflowing=[],
  )
}

///|
pub fn Encoding::with_type_ids(
  self : Encoding,
  type_ids : Array[Int],
) -> Encoding raise TokenizerError {
  validate_encoding_length("type_ids", type_ids.length(), self.ids.length())
  { ..self, type_ids: type_ids.copy() }
}

///|
pub fn Encoding::with_special_tokens_mask(
  self : Encoding,
  special_tokens_mask : Array[Int],
) -> Encoding raise TokenizerError {
  validate_encoding_length(
    "special_tokens_mask",
    special_tokens_mask.length(),
    self.ids.length(),
  )
  { ..self, special_tokens_mask: special_tokens_mask.copy() }
}

///|
pub fn Encoding::with_attention_mask(
  self : Encoding,
  attention_mask : Array[Int],
) -> Encoding raise TokenizerError {
  validate_encoding_length(
    "attention_mask",
    attention_mask.length(),
    self.ids.length(),
  )
  { ..self, attention_mask: attention_mask.copy() }
}

///|
pub fn Encoding::with_word_ids(
  self : Encoding,
  word_ids : Array[Int?],
) -> Encoding raise TokenizerError {
  validate_encoding_length("word_ids", word_ids.length(), self.ids.length())
  { ..self, word_ids: word_ids.copy() }
}

///|
pub fn Encoding::with_sequence_id(
  self : Encoding,
  sequence_id : Int,
) -> Encoding raise TokenizerError {
  if sequence_id < 0 {
    raise ParseError("sequence_id must be non-negative")
  }
  { ..self, sequence_ids: Array::make(self.ids.length(), Some(sequence_id)) }
}

///|
/// HF/Python migration alias for assigning one sequence id to every token. The
/// core API stays immutable, so this returns a new Encoding like
/// `with_sequence_id` instead of mutating in place.
pub fn Encoding::set_sequence_id(
  self : Encoding,
  sequence_id : Int,
) -> Encoding raise TokenizerError {
  self.with_sequence_id(sequence_id)
}

///|
/// Python binding alias for `with_type_ids`. Returns a new Encoding with the
/// updated type ids, preserving immutability.
pub fn Encoding::set_type_ids(
  self : Encoding,
  type_ids : Array[Int],
) -> Encoding raise TokenizerError {
  self.with_type_ids(type_ids)
}

///|
/// Python binding alias for `with_special_tokens_mask`. Returns a new Encoding
/// with the updated special tokens mask, preserving immutability.
pub fn Encoding::set_special_tokens_mask(
  self : Encoding,
  special_tokens_mask : Array[Int],
) -> Encoding raise TokenizerError {
  self.with_special_tokens_mask(special_tokens_mask)
}

///|
/// Python binding alias for `with_attention_mask`. Returns a new Encoding
/// with the updated attention mask, preserving immutability.
pub fn Encoding::set_attention_mask(
  self : Encoding,
  attention_mask : Array[Int],
) -> Encoding raise TokenizerError {
  self.with_attention_mask(attention_mask)
}

///|
/// Python binding alias for `with_word_ids`. Returns a new Encoding with the
/// updated word ids, preserving immutability.
pub fn Encoding::set_word_ids(
  self : Encoding,
  word_ids : Array[Int?],
) -> Encoding raise TokenizerError {
  self.with_word_ids(word_ids)
}

///|
/// Python binding alias for `with_overflowing`. Returns a new Encoding with
/// the updated overflowing encodings, preserving immutability.
pub fn Encoding::set_overflowing(
  self : Encoding,
  overflowing : Array[Encoding],
) -> Encoding {
  self.with_overflowing(overflowing)
}

///|
pub fn Encoding::with_overflowing(
  self : Encoding,
  overflowing : Array[Encoding],
) -> Encoding {
  { ..self, overflowing: overflowing.copy() }
}

///|
pub fn Encoding::take_overflowing(
  self : Encoding,
) -> (Encoding, Array[Encoding]) {
  ({ ..self, overflowing: [] }, self.overflowing.copy())
}

///|
/// Return a new Encoding with updated ids, preserving all other fields.
/// Raises TokenizerError if the new ids length doesn't match the original.
/// This enables programmatic construction and patching of encodings.
pub fn Encoding::with_ids(
  self : Encoding,
  ids : Array[Int],
) -> Encoding raise TokenizerError {
  validate_encoding_length("ids", ids.length(), self.ids.length())
  { ..self, ids: ids.copy() }
}

///|
/// Python binding alias for `with_ids`. Returns a new Encoding with the
/// updated token ids, preserving immutability.
pub fn Encoding::set_ids(
  self : Encoding,
  ids : Array[Int],
) -> Encoding raise TokenizerError {
  self.with_ids(ids)
}

///|
/// Return a new Encoding with updated token strings, preserving all other fields.
/// Raises TokenizerError if the new tokens length doesn't match the original.
pub fn Encoding::with_tokens(
  self : Encoding,
  tokens : Array[String],
) -> Encoding raise TokenizerError {
  validate_encoding_length("tokens", tokens.length(), self.ids.length())
  { ..self, tokens: tokens.copy() }
}

///|
/// Python binding alias for `with_tokens`. Returns a new Encoding with the
/// updated token strings, preserving immutability.
pub fn Encoding::set_tokens(
  self : Encoding,
  tokens : Array[String],
) -> Encoding raise TokenizerError {
  self.with_tokens(tokens)
}

///|
/// Return a new Encoding with updated offsets, preserving all other fields.
/// Raises TokenizerError if the new offsets length doesn't match the original.
pub fn Encoding::with_offsets(
  self : Encoding,
  offsets : Array[(Int, Int)],
) -> Encoding raise TokenizerError {
  validate_encoding_length("offsets", offsets.length(), self.ids.length())
  { ..self, offsets: offsets.copy() }
}

///|
/// Python binding alias for `with_offsets`. Returns a new Encoding with the
/// updated offsets, preserving immutability.
pub fn Encoding::set_offsets(
  self : Encoding,
  offsets : Array[(Int, Int)],
) -> Encoding raise TokenizerError {
  self.with_offsets(offsets)
}

///|
/// Truncate this encoding and keep overflow windows, matching HF's public
/// `Encoding.truncate(max_len, stride, direction)` shape. MoonBit returns the
/// updated value instead of mutating in place.
pub fn Encoding::truncate(
  self : Encoding,
  max_len : Int,
  stride? : Int = 0,
  direction? : EncodingDirection = Right,
) -> Encoding {
  let n = self.ids.length()
  if max_len >= n {
    return self
  }
  if max_len <= 0 {
    return { ..encoding_slice(self, 0, 0), overflowing: [self] }
  }
  let step = if max_len - stride > 0 { max_len - stride } else { max_len }
  let ranges : Array[(Int, Int)] = []
  match direction {
    Right => {
      let mut start = 0
      while start < n {
        let stop = if start + max_len < n { start + max_len } else { n }
        ranges.push((start, stop))
        if stop == n {
          break
        }
        start = start + step
      }
    }
    Left => {
      let mut stop = n
      while stop > 0 {
        let start = if stop > max_len { stop - max_len } else { 0 }
        ranges.push((start, stop))
        if start == 0 {
          break
        }
        stop = if stop > step { stop - step } else { 0 }
      }
    }
  }
  if ranges.length() == 0 {
    return encoding_slice(self, 0, 0)
  }
  let main = encoding_slice(self, ranges[0].0, ranges[0].1)
  let overflow : Array[Encoding] = []
  for i in 1..<ranges.length() {
    overflow.push(encoding_slice(self, ranges[i].0, ranges[i].1))
  }
  { ..main, overflowing: overflow }
}

///|
/// HF Python-style truncate wrapper using string directions.
pub fn Encoding::truncate_hf(
  self : Encoding,
  max_len : Int,
  stride? : Int = 0,
  direction? : String = "right",
) -> Encoding raise TokenizerError {
  if stride >= max_len && max_len > 0 {
    raise ParseError("stride must be strictly less than max_len=\{max_len}")
  }
  self.truncate(max_len, stride~, direction=parse_encoding_direction(direction))
}

///|
/// Pad this encoding to `target_length`; overflow windows are padded too. This
/// mirrors HF's public Encoding padding API but returns a new value.
pub fn Encoding::pad(
  self : Encoding,
  target_length : Int,
  pad_id? : Int = 0,
  pad_type_id? : Int = 0,
  pad_token? : String = "[PAD]",
  direction? : EncodingDirection = Right,
) -> Encoding {
  let padded_overflow = self.overflowing.map(e => {
    e.pad(target_length, pad_id~, pad_type_id~, pad_token~, direction~)
  })
  let base = { ..self, overflowing: padded_overflow }
  let n = base.ids.length()
  if n >= target_length {
    return base
  }
  let pad = target_length - n
  let pad_ids = Array::make(pad, pad_id)
  let pad_types = Array::make(pad, pad_type_id)
  let pad_tokens = Array::make(pad, pad_token)
  let pad_offsets : Array[(Int, Int)] = Array::make(pad, (0, 0))
  let pad_special = Array::make(pad, 1)
  let pad_attention = Array::make(pad, 0)
  let pad_seq : Array[Int?] = Array::make(pad, None)
  let pad_words : Array[Int?] = Array::make(pad, None)
  match direction {
    Right =>
      {
        ..base,
        ids: concat_ints(base.ids, pad_ids),
        type_ids: concat_ints(base.type_ids, pad_types),
        tokens: concat_strings(base.tokens, pad_tokens),
        offsets: concat_offsets(base.offsets, pad_offsets),
        special_tokens_mask: concat_ints(base.special_tokens_mask, pad_special),
        attention_mask: concat_ints(base.attention_mask, pad_attention),
        sequence_ids: concat_opt_ints(base.sequence_ids, pad_seq),
        word_ids: concat_opt_ints(base.word_ids, pad_words),
      }
    Left =>
      {
        ..base,
        ids: concat_ints(pad_ids, base.ids),
        type_ids: concat_ints(pad_types, base.type_ids),
        tokens: concat_strings(pad_tokens, base.tokens),
        offsets: concat_offsets(pad_offsets, base.offsets),
        special_tokens_mask: concat_ints(pad_special, base.special_tokens_mask),
        attention_mask: concat_ints(pad_attention, base.attention_mask),
        sequence_ids: concat_opt_ints(pad_seq, base.sequence_ids),
        word_ids: concat_opt_ints(pad_words, base.word_ids),
      }
  }
}

///|
/// HF Python-style pad wrapper using string directions and keyword order.
pub fn Encoding::pad_hf(
  self : Encoding,
  length : Int,
  direction? : String = "right",
  pad_id? : Int = 0,
  pad_type_id? : Int = 0,
  pad_token? : String = "[PAD]",
) -> Encoding raise TokenizerError {
  self.pad(
    length,
    pad_id~,
    pad_type_id~,
    pad_token~,
    direction=parse_encoding_direction(direction),
  )
}

///|
pub fn Encoding::merge(
  encodings : Array[Encoding],
  growing_offsets? : Bool = true,
) -> Encoding {
  let mut out = Encoding::empty()
  for enc in encodings {
    out = out.merge_with(enc, growing_offsets~)
  }
  out
}

///|
fn parse_encoding_direction(
  direction : String,
) -> EncodingDirection raise TokenizerError {
  match direction.to_lower() {
    "left" => Left
    "right" => Right
    other => raise ParseError("invalid encoding direction: \{other}")
  }
}

///|
pub fn Encoding::merge_with(
  self : Encoding,
  pair : Encoding,
  growing_offsets? : Bool = true,
) -> Encoding {
  let starting_offset = if growing_offsets {
    if self.offsets.length() > 0 {
      self.offsets[self.offsets.length() - 1].1
    } else {
      0
    }
  } else {
    0
  }
  let shifted_offsets : Array[(Int, Int)] = []
  for off in pair.offsets {
    shifted_offsets.push((off.0 + starting_offset, off.1 + starting_offset))
  }
  let overflow : Array[Encoding] = []
  for left in self.overflowing {
    overflow.push(left.merge_with(pair, growing_offsets~))
    for right in pair.overflowing {
      overflow.push(left.merge_with(right, growing_offsets~))
    }
  }
  for right in pair.overflowing {
    overflow.push(self.merge_with(right, growing_offsets~))
  }
  {
    ids: concat_ints(self.ids, pair.ids),
    type_ids: concat_ints(self.type_ids, pair.type_ids),
    tokens: concat_strings(self.tokens, pair.tokens),
    offsets: concat_offsets(self.offsets, shifted_offsets),
    special_tokens_mask: concat_ints(
      self.special_tokens_mask,
      pair.special_tokens_mask,
    ),
    attention_mask: concat_ints(self.attention_mask, pair.attention_mask),
    sequence_ids: concat_opt_ints(self.sequence_ids, pair.sequence_ids),
    word_ids: concat_opt_ints(self.word_ids, pair.word_ids),
    overflowing: overflow,
  }
}

///|
/// Number of tokens in this encoding.
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
