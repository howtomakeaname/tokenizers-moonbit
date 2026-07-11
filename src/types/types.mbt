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
pub(all) struct Token {
  id : Int
  value : String
  offsets : (Int, Int)
} derive(Debug, Eq)

///|
/// Serializable/interoperable snapshot of a model token.
pub(all) struct TokenState {
  id : Int
  value : String
  offsets : (Int, Int)
} derive(Debug, Eq)

///|
/// Build a model token from its id, surface value and half-open offsets.
pub fn Token::new(
  id : Int,
  value : String,
  offsets? : (Int, Int) = (0, 0),
) -> Token {
  { id, value, offsets }
}

///|
/// Build a token from the common HF-style tuple representation
/// `(id, value, offsets)`.
pub fn Token::from_tuple(t : (Int, String, (Int, Int))) -> Token {
  { id: t.0, value: t.1, offsets: t.2 }
}

///|
/// Restore a token from a state snapshot.
pub fn Token::from_state(state : TokenState) -> Token {
  { id: state.id, value: state.value, offsets: state.offsets }
}

///|
/// Return `(id, value, offsets)`, useful for tests and simple interop layers.
pub fn Token::as_tuple(self : Token) -> (Int, String, (Int, Int)) {
  (self.id, self.value, self.offsets)
}

///|
/// Return a Python-binding-friendly token state snapshot.
pub fn Token::get_state(self : Token) -> TokenState {
  { id: self.id, value: self.value, offsets: self.offsets }
}

///|
/// Python pickle compatibility alias for `get_state`.
pub fn Token::__getstate__(self : Token) -> TokenState {
  self.get_state()
}

///|
/// Python pickle compatibility alias for restoring token state.
pub fn Token::__setstate__(state : TokenState) -> Token {
  Token::from_state(state)
}

///|
/// Python binding alias for `str(token)`.
pub fn Token::__str__(self : Token) -> String {
  self.value
}

///|
/// Python binding alias for `repr(token)`.
pub fn Token::__repr__(self : Token) -> String {
  let sb = StringBuilder::new()
  sb.write_string("Token(id=")
  sb.write_string(self.id.to_string())
  sb.write_string(", value=")
  write_repr_string(sb, self.value)
  sb.write_string(", offsets=(")
  sb.write_string(self.offsets.0.to_string())
  sb.write_string(", ")
  sb.write_string(self.offsets.1.to_string())
  sb.write_string("))")
  sb.to_string()
}

///|
pub fn Token::get_id(self : Token) -> Int {
  self.id
}

///|
/// Python/property-style alias for `get_id`.
pub fn Token::id(self : Token) -> Int {
  self.get_id()
}

///|
pub fn Token::get_value(self : Token) -> String {
  self.value
}

///|
/// Python/property-style alias for `get_value`.
pub fn Token::value(self : Token) -> String {
  self.get_value()
}

///|
pub fn Token::get_offsets(self : Token) -> (Int, Int) {
  self.offsets
}

///|
/// Python/property-style alias for `get_offsets`.
pub fn Token::offsets(self : Token) -> (Int, Int) {
  self.get_offsets()
}

///|
/// An intermediate piece produced by pre-tokenization: a substring plus the
/// char offsets it occupies in the original (normalized) text.
pub(all) struct Split {
  value : String
  offsets : (Int, Int)
} derive(Debug, Eq)

///|
/// Serializable/interoperable snapshot of a pre-tokenizer split.
pub(all) struct SplitState {
  value : String
  offsets : (Int, Int)
} derive(Debug, Eq)

///|
/// Build a split from its value and half-open offsets.
pub fn Split::new(value : String, offsets? : (Int, Int) = (0, 0)) -> Split {
  { value, offsets }
}

///|
/// Build a split from the common tuple representation `(value, offsets)`.
pub fn Split::from_tuple(t : (String, (Int, Int))) -> Split {
  { value: t.0, offsets: t.1 }
}

///|
/// Restore a split from a state snapshot.
pub fn Split::from_state(state : SplitState) -> Split {
  { value: state.value, offsets: state.offsets }
}

///|
/// Return `(value, offsets)` for simple binding shims.
pub fn Split::as_tuple(self : Split) -> (String, (Int, Int)) {
  (self.value, self.offsets)
}

///|
/// Return a Python-binding-friendly split state snapshot.
pub fn Split::get_state(self : Split) -> SplitState {
  { value: self.value, offsets: self.offsets }
}

///|
/// Python pickle compatibility alias for `get_state`.
pub fn Split::__getstate__(self : Split) -> SplitState {
  self.get_state()
}

///|
/// Python pickle compatibility alias for restoring split state.
pub fn Split::__setstate__(state : SplitState) -> Split {
  Split::from_state(state)
}

///|
/// Python binding alias for `str(split)`.
pub fn Split::__str__(self : Split) -> String {
  self.value
}

///|
/// Python binding alias for `repr(split)`.
pub fn Split::__repr__(self : Split) -> String {
  let sb = StringBuilder::new()
  sb.write_string("Split(value=")
  write_repr_string(sb, self.value)
  sb.write_string(", offsets=(")
  sb.write_string(self.offsets.0.to_string())
  sb.write_string(", ")
  sb.write_string(self.offsets.1.to_string())
  sb.write_string("))")
  sb.to_string()
}

///|
pub fn Split::get_value(self : Split) -> String {
  self.value
}

///|
/// Python/property-style alias for `get_value`.
pub fn Split::value(self : Split) -> String {
  self.get_value()
}

///|
pub fn Split::get_offsets(self : Split) -> (Int, Int) {
  self.offsets
}

///|
/// Python/property-style alias for `get_offsets`.
pub fn Split::offsets(self : Split) -> (Int, Int) {
  self.get_offsets()
}

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
/// Stable high-level error category for Python binding exception mapping.
pub(all) enum TokenizerErrorKind {
  ParseKind
  UnsupportedComponentKind
  VocabKind
} derive(Debug, Eq)

///|
/// Classify a tokenizer error into a stable category so bindings can map it to
/// dedicated Python exception classes without parsing debug strings.
pub fn TokenizerError::kind(self : TokenizerError) -> TokenizerErrorKind {
  match self {
    ParseError(_) => ParseKind
    UnsupportedComponent(_) => UnsupportedComponentKind
    VocabError(_) => VocabKind
  }
}

///|
/// Extract the human-readable message from a tokenizer error.
pub fn TokenizerError::message(self : TokenizerError) -> String {
  match self {
    ParseError(msg) => msg
    UnsupportedComponent(msg) => msg
    VocabError(msg) => msg
  }
}

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

///|
fn encoding_slice(enc : Encoding, start : Int, stop : Int) -> Encoding {
  {
    ids: enc.ids[start:stop].to_owned(),
    type_ids: enc.type_ids[start:stop].to_owned(),
    tokens: enc.tokens[start:stop].to_owned(),
    offsets: enc.offsets[start:stop].to_owned(),
    special_tokens_mask: enc.special_tokens_mask[start:stop].to_owned(),
    attention_mask: enc.attention_mask[start:stop].to_owned(),
    sequence_ids: enc.sequence_ids[start:stop].to_owned(),
    word_ids: enc.word_ids[start:stop].to_owned(),
    overflowing: [],
  }
}

///|
fn concat_ints(a : Array[Int], b : Array[Int]) -> Array[Int] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
}

///|
fn concat_strings(a : Array[String], b : Array[String]) -> Array[String] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
}

///|
fn concat_offsets(
  a : Array[(Int, Int)],
  b : Array[(Int, Int)],
) -> Array[(Int, Int)] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
}

///|
fn concat_opt_ints(a : Array[Int?], b : Array[Int?]) -> Array[Int?] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
}

///|
fn write_repr_string(sb : StringBuilder, s : String) -> Unit {
  sb.write_char('"')
  for c in s {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ =>
        if c.to_int() < 0x20 {
          write_control_escape(sb, c.to_int())
        } else {
          sb.write_char(c)
        }
    }
  }
  sb.write_char('"')
}

///|
fn write_control_escape(sb : StringBuilder, u : Int) -> Unit {
  let hex = "0123456789ABCDEF".to_array()
  sb.write_string("\\u00")
  sb.write_char(hex[u / 16 % 16])
  sb.write_char(hex[u % 16])
}
