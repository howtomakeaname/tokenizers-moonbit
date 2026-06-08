// Shared text predicates and tiny conversion helpers used across tokenizer
// components. Keep this package dependency-free so model/normalizer/
// pretokenizer/decoder/tokenizer can all import it without introducing cycles.

///|
/// ASCII whitespace used by HF strip/lstrip/rstrip-style helpers.
pub fn is_ascii_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// ASCII decimal digit predicate.
pub fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Word-boundary approximation used by AddedVocabulary single_word matching.
pub fn is_word_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  is_ascii_digit(c) ||
  c == '_'
}

///|
/// Unicode whitespace coverage used for the common HF Regex `\s` subset.
pub fn is_unicode_whitespace(u : Int) -> Bool {
  u == 0x09 ||
  u == 0x0A ||
  u == 0x0D ||
  u == 0x20 ||
  u == 0x85 ||
  u == 0xA0 ||
  u == 0x1680 ||
  (u >= 0x2000 && u <= 0x200A) ||
  u == 0x2028 ||
  u == 0x2029 ||
  u == 0x202F ||
  u == 0x205F ||
  u == 0x3000
}

///|
/// Build a one-character String.
pub fn char_string(c : Char) -> String {
  let sb = StringBuilder::new()
  sb.write_char(c)
  sb.to_string()
}
