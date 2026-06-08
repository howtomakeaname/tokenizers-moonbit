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
/// ASCII alphabetic predicate for regex classes like `[A-Za-z]+`.
pub fn is_ascii_letter(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
/// ASCII alphanumeric predicate for regex classes like `[A-Za-z0-9]+` that do
/// not include `_` (unlike `\w`).
pub fn is_ascii_alnum(c : Char) -> Bool {
  is_ascii_letter(c) || is_ascii_digit(c)
}

///|
/// Word-boundary approximation used by AddedVocabulary single_word matching.
pub fn is_word_char(c : Char) -> Bool {
  is_ascii_alnum(c) || c == '_'
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
/// Unicode `\p{P}` / `\p{Punctuation}` approximation for regex-compatible
/// Split/Replace fast paths. This intentionally separates ASCII punctuation
/// from ASCII symbols (`$`, `+`, `<`, `=`, `>`, `^`, `` ` ``, `|`, `~`) so
/// `\p{P}` and `\p{S}` behave closer to HF's Rust regex engine than the older
/// broad pre-tokenizer punctuation helper.
pub fn is_unicode_punctuation(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x21 && u <= 0x23) ||
  (u >= 0x25 && u <= 0x2A) ||
  (u >= 0x2C && u <= 0x2F) ||
  (u >= 0x3A && u <= 0x3B) ||
  u == 0x3F ||
  u == 0x40 ||
  (u >= 0x5B && u <= 0x5D) ||
  u == 0x5F ||
  (u >= 0x7B && u <= 0x7D) ||
  (u >= 0x2010 && u <= 0x2027) ||
  (u >= 0x2030 && u <= 0x2043) ||
  (u >= 0x2045 && u <= 0x2051) ||
  (u >= 0x2053 && u <= 0x205E) ||
  (u >= 0x3001 && u <= 0x303F) ||
  (u >= 0xFE10 && u <= 0xFE1F) ||
  (u >= 0xFE30 && u <= 0xFE4F) ||
  (u >= 0xFF01 && u <= 0xFF03) ||
  (u >= 0xFF05 && u <= 0xFF0A) ||
  (u >= 0xFF0C && u <= 0xFF0F) ||
  (u >= 0xFF1A && u <= 0xFF1B) ||
  u == 0xFF1F ||
  u == 0xFF20 ||
  (u >= 0xFF3B && u <= 0xFF3D) ||
  u == 0xFF3F ||
  (u >= 0xFF5B && u <= 0xFF5D) ||
  (u >= 0xFF5F && u <= 0xFF65)
}

///|
/// Unicode `\p{S}` / `\p{Symbol}` approximation for common tokenizer regexes.
/// Covers ASCII math/currency/modifier symbols plus currency, math, technical,
/// dingbat and emoji blocks frequently seen in LLM tokenizers.
pub fn is_unicode_symbol(c : Char) -> Bool {
  let u = c.to_int()
  u == 0x24 ||
  u == 0x2B ||
  (u >= 0x3C && u <= 0x3E) ||
  u == 0x5E ||
  u == 0x60 ||
  u == 0x7C ||
  u == 0x7E ||
  (u >= 0x20A0 && u <= 0x20CF) ||
  (u >= 0x2100 && u <= 0x214F) ||
  (u >= 0x2190 && u <= 0x21FF) ||
  (u >= 0x2200 && u <= 0x22FF) ||
  (u >= 0x2300 && u <= 0x23FF) ||
  (u >= 0x2460 && u <= 0x24FF) ||
  (u >= 0x2500 && u <= 0x25FF) ||
  (u >= 0x2600 && u <= 0x27BF) ||
  (u >= 0x2B00 && u <= 0x2BFF) ||
  (u >= 0x1F000 && u <= 0x1FAFF) ||
  (u >= 0xFFE0 && u <= 0xFFE6)
}

///|
/// Combined Unicode punctuation/symbol predicate for regex classes such as
/// `[\p{P}\p{S}]+`, which are common in tokenizer Split rules for non-word
/// runs.
pub fn is_unicode_punctuation_or_symbol(c : Char) -> Bool {
  is_unicode_punctuation(c) || is_unicode_symbol(c)
}

///|
/// Approximation for `[^\s\p{L}\p{N}]`: match visible non-space separators such
/// as punctuation, symbols and other non-letter/non-number marks.
pub fn is_not_whitespace_letter_or_number(c : Char) -> Bool {
  !is_unicode_whitespace(c.to_int()) &&
  !is_unicode_letter(c) &&
  !is_decimal_number(c)
}

///|
/// Common bounded `{1,n}` regex class families used by HF tokenizer Split and
/// Replace configs. Return `(kind, max_run)`, where `kind` is consumed by
/// `bounded_regex_kind_pred`. Keeping this table shared prevents the Split
/// scanner, Normalizer Replace and Decoder Replace from drifting apart.
pub fn bounded_regex_kind(pattern : String) -> (Int, Int)? {
  let ws = bounded_max(pattern, "\\s{1,2}", "\\s{1,3}", "\\s{1,4}")
  if ws > 0 {
    return Some((1, ws))
  }
  let ws_class = bounded_max(pattern, "[\\s]{1,2}", "[\\s]{1,3}", "[\\s]{1,4}")
  if ws_class > 0 {
    return Some((1, ws_class))
  }
  let horizontal = bounded_max(
    pattern, "[ \\t]{1,2}", "[ \\t]{1,3}", "[ \\t]{1,4}",
  )
  if horizontal > 0 {
    return Some((2, horizontal))
  }
  let horizontal_inverse = bounded_max(
    pattern, "[^\\S\\r\\n]{1,2}", "[^\\S\\r\\n]{1,3}", "[^\\S\\r\\n]{1,4}",
  )
  if horizontal_inverse > 0 {
    return Some((2, horizontal_inverse))
  }
  let newlines = bounded_max(
    pattern, "[\\r\\n]{1,2}", "[\\r\\n]{1,3}", "[\\r\\n]{1,4}",
  )
  if newlines > 0 {
    return Some((3, newlines))
  }
  let word = bounded_max(pattern, "\\w{1,2}", "\\w{1,3}", "\\w{1,4}")
  if word > 0 {
    return Some((4, word))
  }
  let word_class = bounded_max(
    pattern, "[A-Za-z0-9_]{1,2}", "[A-Za-z0-9_]{1,3}", "[A-Za-z0-9_]{1,4}",
  )
  if word_class > 0 {
    return Some((4, word_class))
  }
  let alnum = bounded_max(
    pattern, "[A-Za-z0-9]{1,2}", "[A-Za-z0-9]{1,3}", "[A-Za-z0-9]{1,4}",
  )
  if alnum > 0 {
    return Some((5, alnum))
  }
  let alnum_alt = bounded_max(
    pattern, "[a-zA-Z0-9]{1,2}", "[a-zA-Z0-9]{1,3}", "[a-zA-Z0-9]{1,4}",
  )
  if alnum_alt > 0 {
    return Some((5, alnum_alt))
  }
  let ascii_letter = bounded_max(
    pattern, "[A-Za-z]{1,2}", "[A-Za-z]{1,3}", "[A-Za-z]{1,4}",
  )
  if ascii_letter > 0 {
    return Some((6, ascii_letter))
  }
  let ascii_letter_alt = bounded_max(
    pattern, "[a-zA-Z]{1,2}", "[a-zA-Z]{1,3}", "[a-zA-Z]{1,4}",
  )
  if ascii_letter_alt > 0 {
    return Some((6, ascii_letter_alt))
  }
  let letter = bounded_max(pattern, "\\p{L}{1,2}", "\\p{L}{1,3}", "\\p{L}{1,4}")
  if letter > 0 {
    return Some((7, letter))
  }
  let letter_long = bounded_max(
    pattern, "\\p{Letter}{1,2}", "\\p{Letter}{1,3}", "\\p{Letter}{1,4}",
  )
  if letter_long > 0 {
    return Some((7, letter_long))
  }
  let letter_class = bounded_max(
    pattern, "[\\p{L}]{1,2}", "[\\p{L}]{1,3}", "[\\p{L}]{1,4}",
  )
  if letter_class > 0 {
    return Some((7, letter_class))
  }
  let letter_long_class = bounded_max(
    pattern, "[\\p{Letter}]{1,2}", "[\\p{Letter}]{1,3}", "[\\p{Letter}]{1,4}",
  )
  if letter_long_class > 0 {
    return Some((7, letter_long_class))
  }
  let punctuation = bounded_max(
    pattern, "\\p{P}{1,2}", "\\p{P}{1,3}", "\\p{P}{1,4}",
  )
  if punctuation > 0 {
    return Some((8, punctuation))
  }
  let punctuation_long = bounded_max(
    pattern, "\\p{Punctuation}{1,2}", "\\p{Punctuation}{1,3}", "\\p{Punctuation}{1,4}",
  )
  if punctuation_long > 0 {
    return Some((8, punctuation_long))
  }
  let punctuation_class = bounded_max(
    pattern, "[\\p{P}]{1,2}", "[\\p{P}]{1,3}", "[\\p{P}]{1,4}",
  )
  if punctuation_class > 0 {
    return Some((8, punctuation_class))
  }
  let punctuation_long_class = bounded_max(
    pattern, "[\\p{Punctuation}]{1,2}", "[\\p{Punctuation}]{1,3}", "[\\p{Punctuation}]{1,4}",
  )
  if punctuation_long_class > 0 {
    return Some((8, punctuation_long_class))
  }
  let symbol = bounded_max(pattern, "\\p{S}{1,2}", "\\p{S}{1,3}", "\\p{S}{1,4}")
  if symbol > 0 {
    return Some((9, symbol))
  }
  let symbol_long = bounded_max(
    pattern, "\\p{Symbol}{1,2}", "\\p{Symbol}{1,3}", "\\p{Symbol}{1,4}",
  )
  if symbol_long > 0 {
    return Some((9, symbol_long))
  }
  let symbol_class = bounded_max(
    pattern, "[\\p{S}]{1,2}", "[\\p{S}]{1,3}", "[\\p{S}]{1,4}",
  )
  if symbol_class > 0 {
    return Some((9, symbol_class))
  }
  let symbol_long_class = bounded_max(
    pattern, "[\\p{Symbol}]{1,2}", "[\\p{Symbol}]{1,3}", "[\\p{Symbol}]{1,4}",
  )
  if symbol_long_class > 0 {
    return Some((9, symbol_long_class))
  }
  let punct_symbol = bounded_max(
    pattern, "[\\p{P}\\p{S}]{1,2}", "[\\p{P}\\p{S}]{1,3}", "[\\p{P}\\p{S}]{1,4}",
  )
  if punct_symbol > 0 {
    return Some((10, punct_symbol))
  }
  let symbol_punct = bounded_max(
    pattern, "[\\p{S}\\p{P}]{1,2}", "[\\p{S}\\p{P}]{1,3}", "[\\p{S}\\p{P}]{1,4}",
  )
  if symbol_punct > 0 {
    return Some((10, symbol_punct))
  }
  let punct_symbol_long = bounded_max(
    pattern, "[\\p{Punctuation}\\p{Symbol}]{1,2}", "[\\p{Punctuation}\\p{Symbol}]{1,3}",
    "[\\p{Punctuation}\\p{Symbol}]{1,4}",
  )
  if punct_symbol_long > 0 {
    return Some((10, punct_symbol_long))
  }
  let symbol_punct_long = bounded_max(
    pattern, "[\\p{Symbol}\\p{Punctuation}]{1,2}", "[\\p{Symbol}\\p{Punctuation}]{1,3}",
    "[\\p{Symbol}\\p{Punctuation}]{1,4}",
  )
  if symbol_punct_long > 0 {
    return Some((10, symbol_punct_long))
  }
  None
}

///|
pub fn is_bounded_regex_pattern(pattern : String) -> Bool {
  match bounded_regex_kind(pattern) {
    Some(_) => true
    None => false
  }
}

///|
fn bounded_max(pattern : String, p2 : String, p3 : String, p4 : String) -> Int {
  if pattern == p2 {
    2
  } else if pattern == p3 {
    3
  } else if pattern == p4 {
    4
  } else {
    0
  }
}

///|
pub fn bounded_regex_kind_pred(kind : Int, c : Char) -> Bool {
  match kind {
    1 => is_unicode_whitespace(c.to_int())
    2 => is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
    3 => c == '\r' || c == '\n'
    4 => is_word_char(c)
    5 => is_ascii_alnum(c)
    6 => is_ascii_letter(c)
    7 => is_unicode_letter(c)
    8 => is_unicode_punctuation(c)
    9 => is_unicode_symbol(c)
    10 => is_unicode_punctuation_or_symbol(c)
    11 => is_decimal_number(c)
    _ => false
  }
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
