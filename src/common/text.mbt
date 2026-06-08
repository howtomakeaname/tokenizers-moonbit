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
/// Unicode `\p{L}` approximation used by hand-written GPT/Qwen scanners and
/// the common simple-regex fallback. It intentionally covers the script ranges
/// that appear in the fixture matrix and common multilingual tokenizers without
/// pulling in a full Unicode property table.
pub fn is_unicode_letter(c : Char) -> Bool {
  let u = c.to_int()
  if (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) {
    return true
  }
  if (u >= 0xC0 && u <= 0x24F) && u != 0xD7 && u != 0xF7 {
    return true
  }
  if u >= 0x370 && u <= 0x3FF {
    return true
  }
  if u >= 0x400 && u <= 0x4FF {
    return true
  }
  if u >= 0x590 && u <= 0x5FF {
    return true
  }
  if u >= 0x620 && u <= 0x64A {
    return true
  }
  if u >= 0x0900 && u <= 0x097F {
    return true
  }
  if u >= 0x3040 && u <= 0x30FF {
    return true
  }
  if u >= 0x3400 && u <= 0x4DBF {
    return true
  }
  if u >= 0x4E00 && u <= 0x9FFF {
    return true
  }
  if u >= 0xAC00 && u <= 0xD7A3 {
    return true
  }
  false
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
