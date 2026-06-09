// Padding: extend encodings to a common length. Mirrors HuggingFace
// PaddingParams.

///|
pub(all) enum PaddingStrategy {
  BatchLongest
  Fixed(Int)
} derive(Debug, Eq)

///|
pub(all) enum PaddingDirection {
  Left
  Right
} derive(Debug, Eq)

///|
pub(all) struct PaddingParams {
  strategy : PaddingStrategy
  direction : PaddingDirection
  pad_id : Int
  pad_type_id : Int
  pad_token : String
  pad_to_multiple_of : Int?
} derive(Debug, Eq)

///|
/// Default padding: right direction, pad id/token 0 / "[PAD]".
pub fn PaddingParams::new(
  strategy : PaddingStrategy,
  pad_id? : Int = 0,
  pad_token? : String = "[PAD]",
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

///|
/// Convenience constructor for fixed-length padding, mirroring HF's
/// `enable_padding(length=...)` workflow.
pub fn PaddingParams::fixed(
  length : Int,
  pad_id? : Int = 0,
  pad_token? : String = "[PAD]",
) -> PaddingParams {
  PaddingParams::new(Fixed(length), pad_id~, pad_token~)
}

///|
/// Convenience constructor for batch-longest padding.
pub fn PaddingParams::batch_longest(
  pad_id? : Int = 0,
  pad_token? : String = "[PAD]",
) -> PaddingParams {
  PaddingParams::new(BatchLongest, pad_id~, pad_token~)
}

///|
pub fn PaddingParams::with_direction(
  self : PaddingParams,
  direction : PaddingDirection,
) -> PaddingParams {
  { ..self, direction, }
}

///|
pub fn PaddingParams::with_pad_type_id(
  self : PaddingParams,
  pad_type_id : Int,
) -> PaddingParams {
  { ..self, pad_type_id, }
}

///|
pub fn PaddingParams::with_pad_to_multiple_of(
  self : PaddingParams,
  pad_to_multiple_of : Int?,
) -> PaddingParams {
  { ..self, pad_to_multiple_of, }
}

///|
fn round_up(n : Int, multiple : Int) -> Int {
  if multiple <= 0 || n % multiple == 0 {
    n
  } else {
    (n / multiple + 1) * multiple
  }
}

///|
/// Pad a single encoding to `target_len` (no-op if already >= target).
fn pad_encoding(
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
  let pad_seq : Array[Int?] = Array::make(pad, None)
  let pad_word : Array[Int?] = Array::make(pad, None)
  match params.direction {
    Right =>
      {
        ids: concat(enc.ids, pad_ids),
        type_ids: concat(enc.type_ids, pad_types),
        tokens: concat(enc.tokens, pad_toks),
        offsets: concat(enc.offsets, pad_offs),
        special_tokens_mask: concat(enc.special_tokens_mask, pad_special),
        attention_mask: concat(enc.attention_mask, pad_attn),
        sequence_ids: concat(enc.sequence_ids, pad_seq),
        word_ids: concat(enc.word_ids, pad_word),
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
        sequence_ids: concat(pad_seq, enc.sequence_ids),
        word_ids: concat(pad_word, enc.word_ids),
        overflowing: [],
      }
  }
}

///|
/// Pad a batch of encodings according to the strategy.
fn pad_batch(
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

///|
fn[T] concat(a : Array[T], b : Array[T]) -> Array[T] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
}
