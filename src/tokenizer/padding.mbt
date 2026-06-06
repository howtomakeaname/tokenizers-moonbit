// Padding: extend encodings to a common length. Mirrors HuggingFace
// PaddingParams.

pub(all) enum PaddingStrategy {
  BatchLongest
  Fixed(Int)
} derive(Show, Eq)

pub(all) enum PaddingDirection {
  Left
  Right
} derive(Show, Eq)

pub(all) struct PaddingParams {
  strategy : PaddingStrategy
  direction : PaddingDirection
  pad_id : Int
  pad_type_id : Int
  pad_token : String
  pad_to_multiple_of : Int?
} derive(Show, Eq)

/// Default padding: right direction, pad id/token 0 / "[PAD]".
pub fn PaddingParams::new(
  strategy : PaddingStrategy,
  pad_id~ : Int = 0,
  pad_token~ : String = "[PAD]",
) -> PaddingParams {
  {
    strategy,
    direction: Right,
    pad_id,
    pad_type_id: 0,
    pad_token,
    pad_to_multiple_of: None,
  }
}

fn round_up(n : Int, multiple : Int) -> Int {
  if multiple <= 0 || n % multiple == 0 {
    n
  } else {
    (n / multiple + 1) * multiple
  }
}

/// Pad a single encoding to `target_len` (no-op if already >= target).
pub fn pad_encoding(
  enc : @types.Encoding,
  target_len : Int,
  params : PaddingParams,
) -> @types.Encoding {
  let n = enc.ids.length()
  if n >= target_len {
    return enc
  }
  let pad = target_len - n
  let pad_ids = Array::make(pad, params.pad_id)
  let pad_types = Array::make(pad, params.pad_type_id)
  let pad_toks = Array::make(pad, params.pad_token)
  let pad_offs : Array[(Int, Int)] = Array::make(pad, (0, 0))
  let pad_special = Array::make(pad, 1)
  let pad_attn = Array::make(pad, 0)
  match params.direction {
    Right =>
      {
        ids: concat(enc.ids, pad_ids),
        type_ids: concat(enc.type_ids, pad_types),
        tokens: concat(enc.tokens, pad_toks),
        offsets: concat(enc.offsets, pad_offs),
        special_tokens_mask: concat(enc.special_tokens_mask, pad_special),
        attention_mask: concat(enc.attention_mask, pad_attn),
        overflowing: [],
      }
    Left =>
      {
        ids: concat(pad_ids, enc.ids),
        type_ids: concat(pad_types, enc.type_ids),
        tokens: concat(pad_toks, enc.tokens),
        offsets: concat(pad_offs, enc.offsets),
        special_tokens_mask: concat(pad_special, enc.special_tokens_mask),
        attention_mask: concat(pad_attn, enc.attention_mask),
        overflowing: [],
      }
  }
}

/// Pad a batch of encodings according to the strategy.
pub fn pad_batch(
  encodings : Array[@types.Encoding],
  params : PaddingParams,
) -> Array[@types.Encoding] {
  let base = match params.strategy {
    Fixed(n) => n
    BatchLongest => {
      let mut m = 0
      for e in encodings {
        if e.ids.length() > m {
          m = e.ids.length()
        }
      }
      m
    }
  }
  let target = round_up(base, params.pad_to_multiple_of.unwrap_or(0))
  encodings.map(e => pad_encoding(e, target, params))
}

fn[T] concat(a : Array[T], b : Array[T]) -> Array[T] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
}
