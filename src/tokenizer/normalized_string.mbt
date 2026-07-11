///|
pub struct NormalizedString {
  original : String
  normalized : String
}

///|
/// Serializable/interoperable snapshot of a `NormalizedString` for Python
/// binding pickle/state transfer.
pub struct NormalizedStringState {
  original : String
  normalized : String
} derive(Debug, Eq)

///|
pub fn NormalizedString::new(s : String) -> NormalizedString {
  { original: s, normalized: s }
}

///|
/// Restore a normalized string from a binding-friendly state snapshot.
pub fn NormalizedString::from_state(
  state : NormalizedStringState,
) -> NormalizedString {
  { original: state.original, normalized: state.normalized }
}

///|
/// Build from the compact tuple representation `(original, normalized)`.
pub fn NormalizedString::from_tuple(t : (String, String)) -> NormalizedString {
  { original: t.0, normalized: t.1 }
}

///|
/// Return `(original, normalized)` for simple Python/FFI shims.
pub fn NormalizedString::as_tuple(self : NormalizedString) -> (String, String) {
  (self.original, self.normalized)
}

///|
/// Return a pickle/state snapshot.
pub fn NormalizedString::get_state(
  self : NormalizedString,
) -> NormalizedStringState {
  { original: self.original, normalized: self.normalized }
}

///|
/// Python pickle compatibility alias for `get_state`.
pub fn NormalizedString::__getstate__(
  self : NormalizedString,
) -> NormalizedStringState {
  self.get_state()
}

///|
/// Python pickle compatibility alias for restoring state.
pub fn NormalizedString::__setstate__(
  state : NormalizedStringState,
) -> NormalizedString {
  NormalizedString::from_state(state)
}

///|
/// Python binding alias for `str(normalized_string)`.
pub fn NormalizedString::__str__(self : NormalizedString) -> String {
  self.normalized
}

///|
/// Python binding alias for `repr(normalized_string)`.
pub fn NormalizedString::__repr__(self : NormalizedString) -> String {
  let sb = StringBuilder::new()
  sb.write_string("NormalizedString(original=")
  write_repr_string(sb, self.original)
  sb.write_string(", normalized=")
  write_repr_string(sb, self.normalized)
  sb.write_char(')')
  sb.to_string()
}

///|
pub fn NormalizedString::get_original(self : NormalizedString) -> String {
  self.original
}

///|
/// Python/property-style alias for `get_original`.
pub fn NormalizedString::original(self : NormalizedString) -> String {
  self.get_original()
}

///|
pub fn NormalizedString::get(self : NormalizedString) -> String {
  self.normalized
}

///|
/// Python-binding getter alias for the normalized/current string.
pub fn NormalizedString::get_normalized(self : NormalizedString) -> String {
  self.get()
}

///|
/// Python/property-style alias for `get`.
pub fn NormalizedString::normalized(self : NormalizedString) -> String {
  self.get()
}

///|
/// String-conversion alias useful for binding layers.
pub fn NormalizedString::to_string(self : NormalizedString) -> String {
  self.get()
}

///|
pub fn NormalizedString::len(self : NormalizedString) -> Int {
  self.normalized.char_length()
}

///|
/// Python `__len__`-style alias for `len`.
pub fn NormalizedString::__len__(self : NormalizedString) -> Int {
  self.len()
}

///|
/// HF-style single-index access for Python binding shims.
pub fn NormalizedString::get_item(
  self : NormalizedString,
  index : Int,
) -> NormalizedString? {
  if index < 0 {
    return None
  }
  let chars = self.normalized.to_array()
  if index >= chars.length() {
    return None
  }
  let normalized = @common.char_string(chars[index])
  // This immutable migration wrapper does not track per-char original offsets
  // yet, so the item keeps the parent original and exposes a one-char current view.
  Some({ original: self.original, normalized })
}

///|
/// Python `__getitem__`-style alias for `get_item`.
pub fn NormalizedString::__getitem__(
  self : NormalizedString,
  index : Int,
) -> NormalizedString? {
  self.get_item(index)
}

///|
pub fn NormalizedString::is_empty(self : NormalizedString) -> Bool {
  self.normalized.is_empty()
}

///|
pub fn NormalizedString::normalize(
  self : NormalizedString,
  normalizer : @normalizer.Normalizer,
) -> NormalizedString {
  { ..self, normalized: normalizer.normalize(self.normalized) }
}

///|
/// Append text to the current normalized string.
pub fn NormalizedString::append(
  self : NormalizedString,
  suffix : String,
) -> NormalizedString {
  { ..self, normalized: self.normalized + suffix }
}

///|
/// Clear the current normalized string while preserving the original snapshot.
pub fn NormalizedString::clear(self : NormalizedString) -> NormalizedString {
  { ..self, normalized: "" }
}

///|
/// HF-style lowercase convenience alias.
pub fn NormalizedString::lowercase(self : NormalizedString) -> NormalizedString {
  self.normalize(@normalizer.Normalizer::Lowercase)
}

///|
/// HF-style uppercase convenience alias.
pub fn NormalizedString::uppercase(self : NormalizedString) -> NormalizedString {
  { ..self, normalized: self.normalized.to_upper() }
}

///|
/// Strip leading ASCII whitespace, matching the existing Strip normalizer.
pub fn NormalizedString::lstrip(self : NormalizedString) -> NormalizedString {
  self.normalize(@normalizer.Normalizer::Strip(left=true, right=false))
}

///|
/// Strip trailing ASCII whitespace, matching the existing Strip normalizer.
pub fn NormalizedString::rstrip(self : NormalizedString) -> NormalizedString {
  self.normalize(@normalizer.Normalizer::Strip(left=false, right=true))
}

///|
/// Strip leading and trailing ASCII whitespace.
pub fn NormalizedString::strip(self : NormalizedString) -> NormalizedString {
  self.normalize(@normalizer.Normalizer::Strip(left=true, right=true))
}

///|
/// Unicode NFC convenience alias.
pub fn NormalizedString::nfc(self : NormalizedString) -> NormalizedString {
  self.normalize(@normalizer.Normalizer::NFC)
}

///|
/// Unicode NFD convenience alias.
pub fn NormalizedString::nfd(self : NormalizedString) -> NormalizedString {
  self.normalize(@normalizer.Normalizer::NFD)
}

///|
/// Unicode NFKC convenience alias.
pub fn NormalizedString::nfkc(self : NormalizedString) -> NormalizedString {
  self.normalize(@normalizer.Normalizer::NFKC)
}

///|
/// Unicode NFKD convenience alias.
pub fn NormalizedString::nfkd(self : NormalizedString) -> NormalizedString {
  self.normalize(@normalizer.Normalizer::NFKD)
}

///|
pub fn NormalizedString::replace(
  self : NormalizedString,
  pattern : String,
  content : String,
) -> NormalizedString {
  {
    ..self,
    normalized: @common.replace_literal(self.normalized, pattern, content),
  }
}

///|
pub fn NormalizedString::prepend(
  self : NormalizedString,
  prefix : String,
) -> NormalizedString {
  { ..self, normalized: prefix + self.normalized }
}

///|
pub fn NormalizedString::slice(
  self : NormalizedString,
  start : Int,
  stop : Int,
) -> NormalizedString {
  let chars = self.normalized.to_array()
  let a = clamp_int(start, 0, chars.length())
  let b = clamp_int(stop, a, chars.length())
  let sb = StringBuilder::new()
  for i in a..<b {
    sb.write_char(chars[i])
  }
  { original: self.original, normalized: sb.to_string() }
}

///|
pub fn NormalizedString::filter(
  self : NormalizedString,
  keep : (Char) -> Bool,
) -> NormalizedString {
  let sb = StringBuilder::new()
  for c in self.normalized {
    if keep(c) {
      sb.write_char(c)
    }
  }
  { ..self, normalized: sb.to_string() }
}

///|
pub fn NormalizedString::map(
  self : NormalizedString,
  f : (Char) -> String,
) -> NormalizedString {
  let sb = StringBuilder::new()
  for c in self.normalized {
    sb.write_string(f(c))
  }
  { ..self, normalized: sb.to_string() }
}

///|
/// Iterate over each character of the normalized string (HF
/// `NormalizedString.for_each`). Useful for side effects like counting or
/// logging; returns `Unit`.
pub fn NormalizedString::for_each(
  self : NormalizedString,
  f : (Char) -> Unit,
) -> Unit {
  for c in self.normalized {
    f(c)
  }
}

///|
pub fn NormalizedString::split(
  self : NormalizedString,
  pattern : String,
) -> Array[NormalizedString] {
  let spans = @common.literal_matches(self.normalized.to_array(), pattern)
  match spans {
    Some(matches) => split_normalized_by_spans(self, matches)
    None => [self]
  }
}

///|
pub fn NormalizedString::split_regex(
  self : NormalizedString,
  regex : @common.Regex,
) -> Array[NormalizedString]? {
  match regex.find_matches(self.normalized) {
    Some(raw_spans) => {
      let spans : Array[@common.Span] = raw_spans.map(p => {
        start: p.0,
        stop: p.1,
      })
      Some(split_normalized_by_spans(self, spans))
    }
    None => None
  }
}

///|
fn split_normalized_by_spans(
  ns : NormalizedString,
  spans : Array[@common.Span],
) -> Array[NormalizedString] {
  let chars = ns.normalized.to_array()
  let out : Array[NormalizedString] = []
  let mut cursor = 0
  for span in spans {
    if span.start > cursor {
      out.push(ns.slice(cursor, span.start))
    }
    cursor = span.stop
  }
  if cursor < chars.length() {
    out.push(ns.slice(cursor, chars.length()))
  }
  out
}

///|
/// Minimal HF-style pre-tokenized string wrapper. Splits are ordinary
/// tokenizer `Split` values and can be normalized, pre-tokenized further, or
/// converted into an Encoding with a Model.
