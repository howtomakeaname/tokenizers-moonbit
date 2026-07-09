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
/// Serializable/interoperable snapshot of padding parameters for Python binding
/// and pickle/state migration layers.
pub(all) struct PaddingParamsState {
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
pub fn PaddingParams::from_state(state : PaddingParamsState) -> PaddingParams {
  {
    strategy: state.strategy,
    direction: state.direction,
    pad_id: state.pad_id,
    pad_type_id: state.pad_type_id,
    pad_token: state.pad_token,
    pad_to_multiple_of: state.pad_to_multiple_of,
  }
}

///|
pub fn PaddingParams::from_tuple(
  t : (PaddingStrategy, PaddingDirection, Int, Int, String, Int?),
) -> PaddingParams {
  {
    strategy: t.0,
    direction: t.1,
    pad_id: t.2,
    pad_type_id: t.3,
    pad_token: t.4,
    pad_to_multiple_of: t.5,
  }
}

///|
pub fn PaddingParams::as_tuple(
  self : PaddingParams,
) -> (PaddingStrategy, PaddingDirection, Int, Int, String, Int?) {
  (
    self.strategy,
    self.direction,
    self.pad_id,
    self.pad_type_id,
    self.pad_token,
    self.pad_to_multiple_of,
  )
}

///|
pub fn PaddingParams::get_state(self : PaddingParams) -> PaddingParamsState {
  {
    strategy: self.strategy,
    direction: self.direction,
    pad_id: self.pad_id,
    pad_type_id: self.pad_type_id,
    pad_token: self.pad_token,
    pad_to_multiple_of: self.pad_to_multiple_of,
  }
}

///|
/// Python pickle compatibility alias for `get_state`.
pub fn PaddingParams::__getstate__(self : PaddingParams) -> PaddingParamsState {
  self.get_state()
}

///|
/// Python pickle compatibility alias for restoring padding params state.
pub fn PaddingParams::__setstate__(state : PaddingParamsState) -> PaddingParams {
  PaddingParams::from_state(state)
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
pub fn PaddingParams::with_direction_hf(
  self : PaddingParams,
  direction : String,
) -> PaddingParams raise @types.TokenizerError {
  self.with_direction(parse_padding_param_direction_hf(direction))
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
pub fn PaddingParams::get_strategy(self : PaddingParams) -> PaddingStrategy {
  self.strategy
}

///|
pub fn PaddingParams::strategy(self : PaddingParams) -> PaddingStrategy {
  self.strategy
}

///|
pub fn PaddingParams::get_direction(self : PaddingParams) -> PaddingDirection {
  self.direction
}

///|
pub fn PaddingParams::direction(self : PaddingParams) -> PaddingDirection {
  self.direction
}

///|
pub fn PaddingParams::direction_string(self : PaddingParams) -> String {
  match self.direction {
    Left => "left"
    Right => "right"
  }
}

///|
pub fn PaddingParams::get_direction_string(self : PaddingParams) -> String {
  self.direction_string()
}

///|
pub fn PaddingParams::get_pad_id(self : PaddingParams) -> Int {
  self.pad_id
}

///|
pub fn PaddingParams::pad_id(self : PaddingParams) -> Int {
  self.pad_id
}

///|
pub fn PaddingParams::get_pad_type_id(self : PaddingParams) -> Int {
  self.pad_type_id
}

///|
pub fn PaddingParams::pad_type_id(self : PaddingParams) -> Int {
  self.pad_type_id
}

///|
pub fn PaddingParams::get_pad_token(self : PaddingParams) -> String {
  self.pad_token
}

///|
pub fn PaddingParams::pad_token(self : PaddingParams) -> String {
  self.pad_token
}

///|
pub fn PaddingParams::get_pad_to_multiple_of(self : PaddingParams) -> Int? {
  self.pad_to_multiple_of
}

///|
pub fn PaddingParams::pad_to_multiple_of(self : PaddingParams) -> Int? {
  self.pad_to_multiple_of
}

///|
fn parse_padding_param_direction_hf(
  direction : String,
) -> PaddingDirection raise @types.TokenizerError {
  match direction.to_lower() {
    "left" => Left
    "right" => Right
    other => raise @types.ParseError("invalid padding direction: \{other}")
  }
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
