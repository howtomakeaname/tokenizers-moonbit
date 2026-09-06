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
/// Serializable/interoperable snapshot of truncation parameters for Python
/// binding and pickle/state migration layers.
pub(all) struct TruncationParamsState {
  max_length : Int
  stride : Int
  direction : TruncationDirection
  strategy : TruncationStrategy
} derive(Debug, Eq)

///|
/// Default truncation: right direction, no stride.
pub fn TruncationParams::new(max_length : Int) -> TruncationParams {
  { max_length, stride: 0, direction: Right, strategy: LongestFirst, }
}

///|
pub fn TruncationParams::from_state(
  state : TruncationParamsState,
) -> TruncationParams {
  {
    max_length: state.max_length,
    stride: state.stride,
    direction: state.direction,
    strategy: state.strategy,
  }
}

///|
pub fn TruncationParams::from_tuple(
  t : (Int, Int, TruncationDirection, TruncationStrategy),
) -> TruncationParams {
  { max_length: t.0, stride: t.1, direction: t.2, strategy: t.3, }
}

///|
pub fn TruncationParams::as_tuple(
  self : TruncationParams,
) -> (Int, Int, TruncationDirection, TruncationStrategy) {
  (self.max_length, self.stride, self.direction, self.strategy)
}

///|
pub fn TruncationParams::get_state(
  self : TruncationParams,
) -> TruncationParamsState {
  {
    max_length: self.max_length,
    stride: self.stride,
    direction: self.direction,
    strategy: self.strategy,
  }
}

///|
/// Python pickle compatibility alias for `get_state`.
pub fn TruncationParams::__getstate__(
  self : TruncationParams,
) -> TruncationParamsState {
  self.get_state()
}

///|
/// Python pickle compatibility alias for restoring truncation params state.
pub fn TruncationParams::__setstate__(
  state : TruncationParamsState,
) -> TruncationParams {
  TruncationParams::from_state(state)
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
pub fn TruncationParams::with_direction_hf(
  self : TruncationParams,
  direction : String,
) -> TruncationParams raise @types.TokenizerError {
  self.with_direction(parse_truncation_param_direction_hf(direction))
}

///|
pub fn TruncationParams::with_strategy(
  self : TruncationParams,
  strategy : TruncationStrategy,
) -> TruncationParams {
  { ..self, strategy, }
}

///|
pub fn TruncationParams::with_strategy_hf(
  self : TruncationParams,
  strategy : String,
) -> TruncationParams raise @types.TokenizerError {
  self.with_strategy(parse_truncation_param_strategy_hf(strategy))
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
pub fn TruncationParams::direction_string(self : TruncationParams) -> String {
  match self.direction {
    Left => "left"
    Right => "right"
  }
}

///|
pub fn TruncationParams::get_direction_string(
  self : TruncationParams,
) -> String {
  self.direction_string()
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

///|
pub fn TruncationParams::strategy_string(self : TruncationParams) -> String {
  match self.strategy {
    LongestFirst => "longest_first"
    OnlyFirst => "only_first"
    OnlySecond => "only_second"
  }
}

///|
pub fn TruncationParams::get_strategy_string(self : TruncationParams) -> String {
  self.strategy_string()
}

///|
fn parse_truncation_param_direction_hf(
  direction : String,
) -> TruncationDirection raise @types.TokenizerError {
  match direction.to_lower() {
    "left" => Left
    "right" => Right
    other => raise @types.ParseError("invalid truncation direction: \{other}")
  }
}

///|
fn parse_truncation_param_strategy_hf(
  strategy : String,
) -> TruncationStrategy raise @types.TokenizerError {
  match strategy.to_lower() {
    "longest_first" => LongestFirst
    "only_first" => OnlyFirst
    "only_second" => OnlySecond
    other => raise @types.ParseError("invalid truncation strategy: \{other}")
  }
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
/// Truncate `enc` to `params.max_length`, mirroring HF `Encoding::truncate`:
/// the first generated range becomes the main encoding and every following
/// range becomes an overflow window (for both `Right` and `Left` directions).
fn truncate_encoding(
  enc : @types.Encoding,
  params : TruncationParams,
) -> @types.Encoding raise @types.TokenizerError {
  let n = enc.ids.length()
  if n <= params.max_length {
    return enc
  }
  let max = params.max_length
  if max <= 0 {
    // HF: the whole encoding becomes an overflow window of an empty main.
    let window = slice_encoding(enc, 0, n)
    return { ..slice_encoding(enc, 0, 0), overflowing: [window], }
  }
  if params.stride >= max {
    raise @types.ParseError(
      "truncation stride \{params.stride} must be strictly less than the effective max_length \{max}",
    )
  }
  // HF walks fixed-size ranges with step `max - stride`; for `Left` it walks
  // stops backward from the end, so the removed head becomes the windows.
  let offset = max - params.stride
  let ranges : Array[(Int, Int)] = []
  match params.direction {
    Right => {
      let mut end = false
      let mut start = 0
      while !end && start < n {
        let stop = if start + max < n { start + max } else { n }
        end = stop == n
        ranges.push((start, stop))
        start = start + offset
      }
    }
    Left => {
      let mut end = false
      let mut stop_idx = n - 1
      while !end && stop_idx >= 0 {
        let stop = stop_idx + 1
        let start = if stop - max > 0 { stop - max } else { 0 }
        if start < stop {
          end = start == 0
          ranges.push((start, stop))
        }
        stop_idx = stop_idx - offset
      }
    }
  }
  let first = ranges[0]
  let main = slice_encoding(enc, first.0, first.1)
  let windows : Array[@types.Encoding] = []
  for i in 1..<ranges.length() {
    let (start, stop) = ranges[i]
    windows.push(slice_encoding(enc, start, stop))
  }
  { ..main, overflowing: windows, }
}

///|
/// Truncate a pair *before* post-processing, matching HF's strategy semantics.
/// Returns the truncated A and optional B encodings.
fn truncate_pair_raw(
  a : @types.Encoding,
  b : @types.Encoding?,
  params : TruncationParams,
) -> (@types.Encoding, @types.Encoding?) raise @types.TokenizerError {
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
) -> @types.Encoding raise @types.TokenizerError {
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
