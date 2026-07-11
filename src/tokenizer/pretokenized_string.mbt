///|
pub struct PreTokenizedString {
  original : String
  splits : Array[@types.Split]
}

///|
/// Serializable/interoperable snapshot of a `PreTokenizedString`.
pub struct PreTokenizedStringState {
  original : String
  splits : Array[@types.Split]
} derive(Debug, Eq)

///|
pub fn PreTokenizedString::new(text : String) -> PreTokenizedString {
  {
    original: text,
    splits: [{ value: text, offsets: (0, text.char_length()) }],
  }
}

///|
pub fn PreTokenizedString::from_splits(
  splits : Array[@types.Split],
) -> PreTokenizedString {
  let sb = StringBuilder::new()
  for i, s in splits {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string(s.value)
  }
  { original: sb.to_string(), splits: splits.copy() }
}

///|
/// Restore a pre-tokenized string from a binding-friendly state snapshot.
pub fn PreTokenizedString::from_state(
  state : PreTokenizedStringState,
) -> PreTokenizedString {
  { original: state.original, splits: state.splits.copy() }
}

///|
/// Build from the compact tuple representation `(original, splits)`.
pub fn PreTokenizedString::from_tuple(
  t : (String, Array[@types.Split]),
) -> PreTokenizedString {
  { original: t.0, splits: t.1.copy() }
}

///|
/// Return `(original, splits)` for simple Python/FFI shims.
pub fn PreTokenizedString::as_tuple(
  self : PreTokenizedString,
) -> (String, Array[@types.Split]) {
  (self.original, self.splits.copy())
}

///|
/// Return a pickle/state snapshot.
pub fn PreTokenizedString::get_state(
  self : PreTokenizedString,
) -> PreTokenizedStringState {
  { original: self.original, splits: self.splits.copy() }
}

///|
/// Python pickle compatibility alias for `get_state`.
pub fn PreTokenizedString::__getstate__(
  self : PreTokenizedString,
) -> PreTokenizedStringState {
  self.get_state()
}

///|
/// Python pickle compatibility alias for restoring state.
pub fn PreTokenizedString::__setstate__(
  state : PreTokenizedStringState,
) -> PreTokenizedString {
  PreTokenizedString::from_state(state)
}

///|
/// Return the original text used to initialize this pre-tokenized string.
pub fn PreTokenizedString::get_original(self : PreTokenizedString) -> String {
  self.original
}

///|
/// Python/property-style alias for `get_original`.
pub fn PreTokenizedString::original(self : PreTokenizedString) -> String {
  self.get_original()
}

///|
/// Number of current splits, matching Python `len(pretokenized)` binding needs.
pub fn PreTokenizedString::len(self : PreTokenizedString) -> Int {
  self.splits.length()
}

///|
/// Python `__len__`-style alias for `len`.
pub fn PreTokenizedString::__len__(self : PreTokenizedString) -> Int {
  self.len()
}

///|
pub fn PreTokenizedString::is_empty(self : PreTokenizedString) -> Bool {
  self.splits.length() == 0
}

///|
pub fn PreTokenizedString::get_splits(
  self : PreTokenizedString,
) -> Array[@types.Split] {
  self.splits.copy()
}

///|
/// Python/property-style alias for `get_splits`.
pub fn PreTokenizedString::splits(
  self : PreTokenizedString,
) -> Array[@types.Split] {
  self.get_splits()
}

///|
/// HF-style single-index split access for Python binding shims.
pub fn PreTokenizedString::get_item(
  self : PreTokenizedString,
  index : Int,
) -> @types.Split? {
  if index >= 0 && index < self.splits.length() {
    Some(self.splits[index])
  } else {
    None
  }
}

///|
/// Python `__getitem__`-style alias for `get_item`.
pub fn PreTokenizedString::__getitem__(
  self : PreTokenizedString,
  index : Int,
) -> @types.Split? {
  self.get_item(index)
}

///|
pub fn PreTokenizedString::normalize(
  self : PreTokenizedString,
  normalizer : @normalizer.Normalizer,
) -> PreTokenizedString {
  let out : Array[@types.Split] = []
  for s in self.splits {
    let value = normalizer.normalize(s.value)
    out.push({
      value,
      offsets: (s.offsets.0, s.offsets.0 + value.char_length()),
    })
  }
  { ..self, splits: out }
}

///|
pub fn PreTokenizedString::split(
  self : PreTokenizedString,
  pre_tokenizer : @pretokenizer.PreTokenizer,
) -> PreTokenizedString {
  let out : Array[@types.Split] = []
  for s in self.splits {
    for p in pre_tokenizer.pre_tokenize(s.value, base_offset=s.offsets.0) {
      out.push(p)
    }
  }
  { ..self, splits: out }
}

///|
pub fn PreTokenizedString::to_encoding(
  self : PreTokenizedString,
  model : @model.Model,
  type_id? : Int = 0,
) -> @types.Encoding raise @types.TokenizerError {
  let toks : Array[@types.Token] = []
  for s in self.splits {
    for t in model.tokenize(s.value, offset=s.offsets.0) {
      toks.push(t)
    }
  }
  @types.Encoding::from_tokens(toks, type_id~)
}

///|
/// Python binding-friendly alias for `to_encoding`.
pub fn PreTokenizedString::into_encoding(
  self : PreTokenizedString,
  model : @model.Model,
  type_id? : Int = 0,
) -> @types.Encoding raise @types.TokenizerError {
  self.to_encoding(model, type_id~)
}

///|
fn clamp_int(n : Int, lo : Int, hi : Int) -> Int {
  if n < lo {
    lo
  } else if n > hi {
    hi
  } else {
    n
  }
}

// `from_str` is often called repeatedly with the same stable tokenizer.json in
// benchmarks, REPLs and tests. Cache only parsed JSON trees (not Tokenizers), so
// each call still builds fresh mutable model/added-token caches and builder
// state while avoiding the largest repeated parse cost. Keep a few entries so
// alternating model loads (e.g. gpt2 + bert in services/tests) stay hot.
