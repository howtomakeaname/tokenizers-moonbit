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
    12 => !is_unicode_whitespace(c.to_int())
    13 => !is_word_char(c)
    14 => !is_decimal_number(c)
    15 => !is_ascii_alnum(c)
    16 => !is_ascii_letter(c)
    17 => !is_unicode_letter(c)
    18 => !is_unicode_punctuation(c)
    19 => !is_unicode_symbol(c)
    20 => !is_unicode_punctuation_or_symbol(c)
    21 => is_not_whitespace_letter_or_number(c)
    _ => false
  }
}

///|
/// Unicode whitespace coverage used for HF/Rust-regex `\s`.
pub fn is_unicode_whitespace(u : Int) -> Bool {
  u == 0x09 ||
  u == 0x0A ||
  u == 0x0B ||
  u == 0x0C ||
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
