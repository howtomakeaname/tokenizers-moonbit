///|
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
