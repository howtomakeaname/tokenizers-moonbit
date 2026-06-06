// Truncation: cap an encoding's length, optionally producing stride windows
// in `overflowing`. Mirrors HuggingFace TruncationParams.

pub(all) enum TruncationDirection {
  Left
  Right
} derive(Show, Eq)

pub(all) struct TruncationParams {
  max_length : Int
  stride : Int
  direction : TruncationDirection
} derive(Show, Eq)

/// Default truncation: right direction, no stride.
pub fn TruncationParams::new(max_length : Int) -> TruncationParams {
  { max_length, stride: 0, direction: Right }
}

// Slice an encoding's parallel arrays to [start, stop).
fn slice_encoding(
  enc : @types.Encoding,
  start : Int,
  stop : Int,
) -> @types.Encoding {
  {
    ids: enc.ids[start:stop].to_array(),
    type_ids: enc.type_ids[start:stop].to_array(),
    tokens: enc.tokens[start:stop].to_array(),
    offsets: enc.offsets[start:stop].to_array(),
    special_tokens_mask: enc.special_tokens_mask[start:stop].to_array(),
    attention_mask: enc.attention_mask[start:stop].to_array(),
    overflowing: [],
  }
}

/// Truncate `enc` to `params.max_length`. With `stride > 0`, the trimmed tail
/// is emitted as overflow windows (each overlapping the previous by `stride`).
pub fn truncate_encoding(
  enc : @types.Encoding,
  params : TruncationParams,
) -> @types.Encoding {
  let n = enc.ids.length()
  if n <= params.max_length {
    return enc
  }
  let max = params.max_length
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
    Left => {
      // Keep the last `max` tokens.
      slice_encoding(enc, n - max, n)
    }
  }
}
