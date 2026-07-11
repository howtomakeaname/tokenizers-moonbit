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
/// Unicode word predicate used by HF/Rust-regex `\w`-style matching and
/// AddedVocabulary `single_word` boundaries. Rust regex treats letters and
/// numbers from Unicode scripts as word characters (plus `_`), so CJK/Greek/etc.
/// neighbors must block single-word added-token extraction just like ASCII
/// letters do.
pub fn is_word_char(c : Char) -> Bool {
  is_unicode_letter(c) || is_decimal_number(c) || c == '_'
}

///|
/// Unicode `\p{L}` approximation used by hand-written GPT/Qwen scanners and
/// the common simple-regex fallback. It intentionally covers the script ranges
/// that appear in the fixture matrix and common multilingual tokenizers without
/// pulling in a full Unicode property table.
pub fn is_unicode_letter(c : Char) -> Bool {
  let u = c.to_int()
  // Basic Latin + Latin Extended (covers most European scripts)
  if (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) {
    return true
  }
  if (u >= 0xC0 && u <= 0x24F) && u != 0xD7 && u != 0xF7 {
    return true
  }
  // Greek and Coptic
  if u >= 0x370 && u <= 0x3FF {
    return true
  }
  // Cyrillic
  if u >= 0x400 && u <= 0x4FF {
    return true
  }
  // Armenian
  if u >= 0x530 && u <= 0x58F {
    return true
  }
  // Hebrew
  if u >= 0x590 && u <= 0x5FF {
    return true
  }
  // Arabic
  if u >= 0x620 && u <= 0x64A {
    return true
  }
  // Devanagari (Hindi, Sanskrit)
  if u >= 0x0900 && u <= 0x097F {
    return true
  }
  // Bengali
  if u >= 0x0980 && u <= 0x09FF {
    return true
  }
  // Gurmukhi (Punjabi)
  if u >= 0x0A00 && u <= 0x0A7F {
    return true
  }
  // Gujarati
  if u >= 0x0A80 && u <= 0x0AFF {
    return true
  }
  // Oriya
  if u >= 0x0B00 && u <= 0x0B7F {
    return true
  }
  // Tamil
  if u >= 0x0B80 && u <= 0x0BFF {
    return true
  }
  // Telugu
  if u >= 0x0C00 && u <= 0x0C7F {
    return true
  }
  // Kannada
  if u >= 0x0C80 && u <= 0x0CFF {
    return true
  }
  // Malayalam
  if u >= 0x0D00 && u <= 0x0D7F {
    return true
  }
  // Sinhala
  if u >= 0x0D80 && u <= 0x0DFF {
    return true
  }
  // Thai
  if u >= 0x0E00 && u <= 0x0E7F {
    return true
  }
  // Lao
  if u >= 0x0E80 && u <= 0x0EFF {
    return true
  }
  // Tibetan
  if u >= 0x0F00 && u <= 0x0FFF {
    return true
  }
  // Myanmar
  if u >= 0x1000 && u <= 0x109F {
    return true
  }
  // Georgian
  if u >= 0x10A0 && u <= 0x10FF {
    return true
  }
  // Khmer
  if u >= 0x1780 && u <= 0x17FF {
    return true
  }
  // Hiragana + Katakana (Japanese)
  if u >= 0x3040 && u <= 0x30FF {
    return true
  }
  // CJK Unified Ideographs (Extension A + Main)
  if u >= 0x3400 && u <= 0x4DBF {
    return true
  }
  if u >= 0x4E00 && u <= 0x9FFF {
    return true
  }
  // Hangul Syllables (Korean)
  if u >= 0xAC00 && u <= 0xD7A3 {
    return true
  }
  // Ethiopic (Amharic, Tigrinya)
  if u >= 0x1200 && u <= 0x137F {
    return true
  }
  // Ethiopic Supplement
  if u >= 0x1380 && u <= 0x139F {
    return true
  }
  // Cherokee
  if u >= 0x13A0 && u <= 0x13FF {
    return true
  }
  // Canadian Aboriginal Syllabics
  if u >= 0x1400 && u <= 0x167F {
    return true
  }
  // Ogham (Old Irish)
  if u >= 0x1680 && u <= 0x169F {
    return true
  }
  // Runic (Norse, Germanic)
  if u >= 0x16A0 && u <= 0x16FF {
    return true
  }
  // Latin Extended Additional (Vietnamese, etc.)
  if u >= 0x1E00 && u <= 0x1EFF {
    return true
  }
  // Greek Extended
  if u >= 0x1F00 && u <= 0x1FFF {
    return true
  }
  // CJK Unified Ideographs Extension B
  if u >= 0x20000 && u <= 0x2A6DF {
    return true
  }
  // CJK Unified Ideographs Extension C + D
  if u >= 0x2A700 && u <= 0x2B73F {
    return true
  }
  // CJK Compatibility Ideographs
  if u >= 0xF900 && u <= 0xFAFF {
    return true
  }
  // Hangul Jamo (Korean consonants/vowels)
  if u >= 0x1100 && u <= 0x11FF {
    return true
  }
  // Hangul Jamo Extended-A
  if u >= 0xA960 && u <= 0xA97F {
    return true
  }
  // Hangul Jamo Extended-B
  if u >= 0xD7B0 && u <= 0xD7FF {
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
  (u >= 0x27C0 && u <= 0x27EF) ||
  (u >= 0x2980 && u <= 0x29FF) ||
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
