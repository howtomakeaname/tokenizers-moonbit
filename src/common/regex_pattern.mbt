///|
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
  let non_ws = bounded_max_variants(
    pattern,
    ["\\S{1,2}", "[^\\s]{1,2}"],
    ["\\S{1,3}", "[^\\s]{1,3}"],
    ["\\S{1,4}", "[^\\s]{1,4}"],
  )
  if non_ws > 0 {
    return Some((12, non_ws))
  }
  let digit = bounded_max_variants(
    pattern,
    [
      "\\d{1,2}", "[\\d]{1,2}", "[0-9]{1,2}", "\\p{N}{1,2}", "\\p{Number}{1,2}",
      "[\\p{N}]{1,2}", "[\\p{Number}]{1,2}",
    ],
    [
      "\\d{1,3}", "[\\d]{1,3}", "[0-9]{1,3}", "\\p{N}{1,3}", "\\p{Number}{1,3}",
      "[\\p{N}]{1,3}", "[\\p{Number}]{1,3}",
    ],
    [
      "\\d{1,4}", "[\\d]{1,4}", "[0-9]{1,4}", "\\p{N}{1,4}", "\\p{Number}{1,4}",
      "[\\p{N}]{1,4}", "[\\p{Number}]{1,4}",
    ],
  )
  if digit > 0 {
    return Some((11, digit))
  }
  let non_digit = bounded_max_variants(
    pattern,
    [
      "\\D{1,2}", "[\\D]{1,2}", "[^\\d]{1,2}", "[^0-9]{1,2}", "\\P{N}{1,2}", "\\P{Number}{1,2}",
      "[^\\p{N}]{1,2}", "[^\\p{Number}]{1,2}",
    ],
    [
      "\\D{1,3}", "[\\D]{1,3}", "[^\\d]{1,3}", "[^0-9]{1,3}", "\\P{N}{1,3}", "\\P{Number}{1,3}",
      "[^\\p{N}]{1,3}", "[^\\p{Number}]{1,3}",
    ],
    [
      "\\D{1,4}", "[\\D]{1,4}", "[^\\d]{1,4}", "[^0-9]{1,4}", "\\P{N}{1,4}", "\\P{Number}{1,4}",
      "[^\\p{N}]{1,4}", "[^\\p{Number}]{1,4}",
    ],
  )
  if non_digit > 0 {
    return Some((14, non_digit))
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
  let non_word = bounded_max_variants(
    pattern,
    ["\\W{1,2}", "[^\\w]{1,2}", "[^A-Za-z0-9_]{1,2}"],
    ["\\W{1,3}", "[^\\w]{1,3}", "[^A-Za-z0-9_]{1,3}"],
    ["\\W{1,4}", "[^\\w]{1,4}", "[^A-Za-z0-9_]{1,4}"],
  )
  if non_word > 0 {
    return Some((13, non_word))
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
  let non_alnum = bounded_max_variants(
    pattern,
    ["[^A-Za-z0-9]{1,2}", "[^a-zA-Z0-9]{1,2}"],
    ["[^A-Za-z0-9]{1,3}", "[^a-zA-Z0-9]{1,3}"],
    ["[^A-Za-z0-9]{1,4}", "[^a-zA-Z0-9]{1,4}"],
  )
  if non_alnum > 0 {
    return Some((15, non_alnum))
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
  let non_ascii_letter = bounded_max_variants(
    pattern,
    ["[^A-Za-z]{1,2}", "[^a-zA-Z]{1,2}"],
    ["[^A-Za-z]{1,3}", "[^a-zA-Z]{1,3}"],
    ["[^A-Za-z]{1,4}", "[^a-zA-Z]{1,4}"],
  )
  if non_ascii_letter > 0 {
    return Some((16, non_ascii_letter))
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
  let non_letter = bounded_max_variants(
    pattern,
    ["\\P{L}{1,2}", "\\P{Letter}{1,2}", "[^\\p{L}]{1,2}", "[^\\p{Letter}]{1,2}"],
    ["\\P{L}{1,3}", "\\P{Letter}{1,3}", "[^\\p{L}]{1,3}", "[^\\p{Letter}]{1,3}"],
    ["\\P{L}{1,4}", "\\P{Letter}{1,4}", "[^\\p{L}]{1,4}", "[^\\p{Letter}]{1,4}"],
  )
  if non_letter > 0 {
    return Some((17, non_letter))
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
  let non_punctuation = bounded_max_variants(
    pattern,
    [
      "\\P{P}{1,2}", "\\P{Punctuation}{1,2}", "[^\\p{P}]{1,2}", "[^\\p{Punctuation}]{1,2}",
    ],
    [
      "\\P{P}{1,3}", "\\P{Punctuation}{1,3}", "[^\\p{P}]{1,3}", "[^\\p{Punctuation}]{1,3}",
    ],
    [
      "\\P{P}{1,4}", "\\P{Punctuation}{1,4}", "[^\\p{P}]{1,4}", "[^\\p{Punctuation}]{1,4}",
    ],
  )
  if non_punctuation > 0 {
    return Some((18, non_punctuation))
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
  let non_symbol = bounded_max_variants(
    pattern,
    ["\\P{S}{1,2}", "\\P{Symbol}{1,2}", "[^\\p{S}]{1,2}", "[^\\p{Symbol}]{1,2}"],
    ["\\P{S}{1,3}", "\\P{Symbol}{1,3}", "[^\\p{S}]{1,3}", "[^\\p{Symbol}]{1,3}"],
    ["\\P{S}{1,4}", "\\P{Symbol}{1,4}", "[^\\p{S}]{1,4}", "[^\\p{Symbol}]{1,4}"],
  )
  if non_symbol > 0 {
    return Some((19, non_symbol))
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
  let non_punct_symbol = bounded_max_variants(
    pattern,
    [
      "[^\\p{P}\\p{S}]{1,2}", "[^\\p{S}\\p{P}]{1,2}", "[^\\p{Punctuation}\\p{Symbol}]{1,2}",
      "[^\\p{Symbol}\\p{Punctuation}]{1,2}",
    ],
    [
      "[^\\p{P}\\p{S}]{1,3}", "[^\\p{S}\\p{P}]{1,3}", "[^\\p{Punctuation}\\p{Symbol}]{1,3}",
      "[^\\p{Symbol}\\p{Punctuation}]{1,3}",
    ],
    [
      "[^\\p{P}\\p{S}]{1,4}", "[^\\p{S}\\p{P}]{1,4}", "[^\\p{Punctuation}\\p{Symbol}]{1,4}",
      "[^\\p{Symbol}\\p{Punctuation}]{1,4}",
    ],
  )
  if non_punct_symbol > 0 {
    return Some((20, non_punct_symbol))
  }
  let non_space_letter_number = bounded_max_variants(
    pattern,
    [
      "[^\\s\\p{L}\\p{N}]{1,2}", "[^\\s\\p{N}\\p{L}]{1,2}", "[^\\p{L}\\p{N}\\s]{1,2}",
      "[^\\p{N}\\p{L}\\s]{1,2}", "[^\\s\\p{Letter}\\p{Number}]{1,2}",
    ],
    [
      "[^\\s\\p{L}\\p{N}]{1,3}", "[^\\s\\p{N}\\p{L}]{1,3}", "[^\\p{L}\\p{N}\\s]{1,3}",
      "[^\\p{N}\\p{L}\\s]{1,3}", "[^\\s\\p{Letter}\\p{Number}]{1,3}",
    ],
    [
      "[^\\s\\p{L}\\p{N}]{1,4}", "[^\\s\\p{N}\\p{L}]{1,4}", "[^\\p{L}\\p{N}\\s]{1,4}",
      "[^\\p{N}\\p{L}\\s]{1,4}", "[^\\s\\p{Letter}\\p{Number}]{1,4}",
    ],
  )
  if non_space_letter_number > 0 {
    return Some((21, non_space_letter_number))
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
/// Common ranged `{m,n}` regex class families used by HF tokenizer Split and
/// Replace configs. Return `(kind, min_run, max_run)`. We intentionally keep the
/// supported range small and deterministic (2..4) because this covers the
/// practical tokenizer regexes that appear in modern pre-tokenizer cleanups
/// without embedding a full regex engine.
