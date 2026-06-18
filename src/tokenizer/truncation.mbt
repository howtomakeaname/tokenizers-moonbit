// Truncation: cap an encoding's length, optionally producing stride windows
// in `overflowing`. Mirrors HuggingFace TruncationParams.

///|
pub(all) enum TruncationDirection {
  Left
  Right
} derive(Debug, Eq)

///|
pub(all) enum TruncationStrategy {
  LongestFirst
  OnlyFirst
  OnlySecond
} derive(Debug, Eq)

///|
pub(all) struct TruncationParams {
  max_length : Int
  stride : Int
  direction : TruncationDirection
  strategy : TruncationStrategy
} derive(Debug, Eq)

///|
/// Default truncation: right direction, no stride.
pub fn TruncationParams::new(max_length : Int) -> TruncationParams {
  { max_length, stride: 0, direction: Right, strategy: LongestFirst }
}

///|
pub fn TruncationParams::with_stride(
  self : TruncationParams,
  stride : Int,
) -> TruncationParams {
  { ..self, stride, }
}

///|
pub fn TruncationParams::with_direction(
  self : TruncationParams,
  direction : TruncationDirection,
) -> TruncationParams {
  { ..self, direction, }
}

///|
pub fn TruncationParams::with_strategy(
  self : TruncationParams,
  strategy : TruncationStrategy,
) -> TruncationParams {
  { ..self, strategy, }
}

///|
pub fn TruncationParams::get_max_length(self : TruncationParams) -> Int {
  self.max_length
}

///|
pub fn TruncationParams::max_length(self : TruncationParams) -> Int {
  self.max_length
}

///|
pub fn TruncationParams::get_stride(self : TruncationParams) -> Int {
  self.stride
}

///|
pub fn TruncationParams::stride(self : TruncationParams) -> Int {
  self.stride
}

///|
pub fn TruncationParams::get_direction(
  self : TruncationParams,
) -> TruncationDirection {
  self.direction
}

///|
pub fn TruncationParams::direction(
  self : TruncationParams,
) -> TruncationDirection {
  self.direction
}

///|
pub fn TruncationParams::get_strategy(
  self : TruncationParams,
) -> TruncationStrategy {
  self.strategy
}

///|
pub fn TruncationParams::strategy(
  self : TruncationParams,
) -> TruncationStrategy {
  self.strategy
}

// Slice an encoding's parallel arrays to [start, stop).

///|
fn slice_encoding(
  enc : @types.Encoding,
  start : Int,
  stop : Int,
) -> @types.Encoding {
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
/// Truncate `enc` to `params.max_length`. With `stride > 0`, the trimmed tail
/// is emitted as overflow windows (each overlapping the previous by `stride`).
fn truncate_encoding(
  enc : @types.Encoding,
  params : TruncationParams,
) -> @types.Encoding {
  let n = enc.ids.length()
  if n <= params.max_length {
    return enc
  }
  let max = params.max_length
  if max <= 0 {
    return slice_encoding(enc, 0, 0)
  }
  match params.direction {
    Right => {
      let main = slice_encoding(enc, 0, max)
      // Overflow windows over the trimmed region, with stride overlap.
      let windows : Array[@types.Encoding] = []
      let step = if max - params.stride > 0 { max - params.stride } else { max }
      let mut start = step
      while start < n {
        let stop = if start + max < n { start + max } else { n }
        windows.push(slice_encoding(enc, start, stop))
        if stop == n {
          break
        }
        start = start + step
      }
      { ..main, overflowing: windows }
    }
    Left =>
      // Keep the last `max` tokens.
      slice_encoding(enc, n - max, n)
  }
}

///|
/// Truncate a pair *before* post-processing, matching HF's strategy semantics.
/// Returns the truncated A and optional B encodings.
fn truncate_pair_raw(
  a : @types.Encoding,
  b : @types.Encoding?,
  params : TruncationParams,
) -> (@types.Encoding, @types.Encoding?) {
  let len_a = a.ids.length()
  let len_b = match b {
    Some(x) => x.ids.length()
    None => 0
  }
  let total = len_a + len_b
  if total <= params.max_length {
    return (a, b)
  }
  let remove = total - params.max_length
  match params.strategy {
    LongestFirst =>
      match b {
        Some(eb) => {
          let (keep_a, keep_b) = longest_first_lengths(
            len_a,
            len_b,
            params.max_length,
          )
          (
            truncate_to_len(a, keep_a, params),
            Some(truncate_to_len(eb, keep_b, params)),
          )
        }
        None => (truncate_to_len(a, params.max_length, params), None)
      }
    OnlyFirst => {
      let keep = if len_a > remove { len_a - remove } else { 0 }
      (truncate_to_len(a, keep, params), b)
    }
    OnlySecond =>
      match b {
        Some(eb) => {
          let keep = if len_b > remove { len_b - remove } else { 0 }
          (a, Some(truncate_to_len(eb, keep, params)))
        }
        None => (a, b)
      }
  }
}

///|
fn truncate_to_len(
  enc : @types.Encoding,
  max_length : Int,
  params : TruncationParams,
) -> @types.Encoding {
  truncate_encoding(enc, { ..params, max_length, })
}

///|
fn longest_first_lengths(
  len_a : Int,
  len_b : Int,
  max_length : Int,
) -> (Int, Int) {
  let mut n1 = len_a
  let mut n2 = len_b
  let mut swapped = false
  if n1 > n2 {
    swapped = true
    let tmp = n1
    n1 = n2
    n2 = tmp
  }
  if n1 > max_length {
    n2 = n1
  } else {
    let candidate = max_length - n1
    n2 = if n1 > candidate { n1 } else { candidate }
  }
  if n1 + n2 > max_length {
    n1 = max_length / 2
    n2 = n1 + max_length % 2
  }
  if swapped {
    (n2, n1)
  } else {
    (n1, n2)
  }
}
