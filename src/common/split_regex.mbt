// Shared helpers for the small Split regex subset that can be implemented with
// deterministic char scanners instead of a general regex engine.

///|
pub(all) struct Span {
  start : Int
  stop : Int
}

///|
pub fn simple_split_regex_matches(
  chars : Array[Char],
  pattern : String,
) -> Array[Span]? {
  match simple_bounded_regex_matches(chars, pattern) {
    Some(spans) => return Some(spans)
    None => ()
  }
  if pattern == "\\s+" {
    Some(run_matches(chars, fn(c) { is_unicode_whitespace(c.to_int()) }))
  } else if pattern == "\\s{2,}" || pattern == "[\\s]{2,}" {
    Some(
      run_matches_min(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) },
        min_run=2,
      ),
    )
  } else if pattern == "\\s{3,}" || pattern == "[\\s]{3,}" {
    Some(
      run_matches_min(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) },
        min_run=3,
      ),
    )
  } else if pattern == "\\s{4,}" || pattern == "[\\s]{4,}" {
    Some(
      run_matches_min(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) },
        min_run=4,
      ),
    )
  } else if pattern == "\\s{2}" || pattern == "[\\s]{2}" {
    Some(
      run_matches_exact(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) },
        exact_run=2,
      ),
    )
  } else if pattern == "\\s{3}" || pattern == "[\\s]{3}" {
    Some(
      run_matches_exact(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) },
        exact_run=3,
      ),
    )
  } else if pattern == "\\s{4}" || pattern == "[\\s]{4}" {
    Some(
      run_matches_exact(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) },
        exact_run=4,
      ),
    )
  } else if pattern == "^\\s+" {
    Some(leading_run_match(chars, fn(c) { is_unicode_whitespace(c.to_int()) }))
  } else if pattern == "\\S+" || pattern == "[^\\s]+" {
    Some(run_matches(chars, fn(c) { !is_unicode_whitespace(c.to_int()) }))
  } else if pattern == "\\s+$" {
    Some(trailing_run_match(chars, fn(c) { is_unicode_whitespace(c.to_int()) }))
  } else if pattern == "[ \\t]+" || pattern == "[^\\S\\r\\n]+" {
    Some(
      run_matches(chars, fn(c) {
        is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      }),
    )
  } else if pattern == "[ \\t]{2,}" || pattern == "[^\\S\\r\\n]{2,}" {
    Some(
      run_matches_min(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n' },
        min_run=2,
      ),
    )
  } else if pattern == "[ \\t]{3,}" || pattern == "[^\\S\\r\\n]{3,}" {
    Some(
      run_matches_min(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n' },
        min_run=3,
      ),
    )
  } else if pattern == "[ \\t]{4,}" || pattern == "[^\\S\\r\\n]{4,}" {
    Some(
      run_matches_min(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n' },
        min_run=4,
      ),
    )
  } else if pattern == "[ \\t]{2}" || pattern == "[^\\S\\r\\n]{2}" {
    Some(
      run_matches_exact(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n' },
        exact_run=2,
      ),
    )
  } else if pattern == "[ \\t]{3}" || pattern == "[^\\S\\r\\n]{3}" {
    Some(
      run_matches_exact(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n' },
        exact_run=3,
      ),
    )
  } else if pattern == "[ \\t]{4}" || pattern == "[^\\S\\r\\n]{4}" {
    Some(
      run_matches_exact(
        chars,
        fn(c) { is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n' },
        exact_run=4,
      ),
    )
  } else if pattern == "[\\r\\n]" ||
    pattern == "[\r\n]" ||
    pattern == "[\\r\\n]+" ||
    pattern == "[\r\n]+" {
    Some(run_matches(chars, fn(c) { c == '\r' || c == '\n' }))
  } else if pattern == "[\\r\\n]{2,}" || pattern == "[\r\n]{2,}" {
    Some(run_matches_min(chars, fn(c) { c == '\r' || c == '\n' }, min_run=2))
  } else if pattern == "[\\r\\n]{3,}" || pattern == "[\r\n]{3,}" {
    Some(run_matches_min(chars, fn(c) { c == '\r' || c == '\n' }, min_run=3))
  } else if pattern == "[\\r\\n]{4,}" || pattern == "[\r\n]{4,}" {
    Some(run_matches_min(chars, fn(c) { c == '\r' || c == '\n' }, min_run=4))
  } else if pattern == "[\\r\\n]{2}" || pattern == "[\r\n]{2}" {
    Some(
      run_matches_exact(chars, fn(c) { c == '\r' || c == '\n' }, exact_run=2),
    )
  } else if pattern == "[\\r\\n]{3}" || pattern == "[\r\n]{3}" {
    Some(
      run_matches_exact(chars, fn(c) { c == '\r' || c == '\n' }, exact_run=3),
    )
  } else if pattern == "[\\r\\n]{4}" || pattern == "[\r\n]{4}" {
    Some(
      run_matches_exact(chars, fn(c) { c == '\r' || c == '\n' }, exact_run=4),
    )
  } else if pattern == "\\w+" ||
    pattern == "[A-Za-z0-9_]+" ||
    pattern == "\\b\\w+\\b" ||
    pattern == "\\b[A-Za-z0-9_]+\\b" {
    Some(run_matches(chars, fn(c) { is_word_char(c) }))
  } else if pattern == "^\\w+" || pattern == "^[A-Za-z0-9_]+" {
    Some(leading_run_match(chars, fn(c) { is_word_char(c) }))
  } else if pattern == "\\w+$" || pattern == "[A-Za-z0-9_]+$" {
    Some(trailing_run_match(chars, fn(c) { is_word_char(c) }))
  } else if pattern == "\\W+" ||
    pattern == "[^\\w]+" ||
    pattern == "[^A-Za-z0-9_]+" {
    Some(run_matches(chars, fn(c) { !is_word_char(c) }))
  } else if pattern == "\\w{2,}" || pattern == "[A-Za-z0-9_]{2,}" {
    Some(run_matches_min(chars, fn(c) { is_word_char(c) }, min_run=2))
  } else if pattern == "\\w{2}" || pattern == "[A-Za-z0-9_]{2}" {
    Some(run_matches_exact(chars, fn(c) { is_word_char(c) }, exact_run=2))
  } else if pattern == "\\w{3}" || pattern == "[A-Za-z0-9_]{3}" {
    Some(run_matches_exact(chars, fn(c) { is_word_char(c) }, exact_run=3))
  } else if pattern == "\\w{4}" || pattern == "[A-Za-z0-9_]{4}" {
    Some(run_matches_exact(chars, fn(c) { is_word_char(c) }, exact_run=4))
  } else if pattern == "[A-Za-z0-9]+" || pattern == "[a-zA-Z0-9]+" {
    Some(run_matches(chars, fn(c) { is_ascii_alnum(c) }))
  } else if pattern == "[A-Za-z0-9]{2,}" || pattern == "[a-zA-Z0-9]{2,}" {
    Some(run_matches_min(chars, fn(c) { is_ascii_alnum(c) }, min_run=2))
  } else if pattern == "[A-Za-z0-9]{2}" || pattern == "[a-zA-Z0-9]{2}" {
    Some(run_matches_exact(chars, fn(c) { is_ascii_alnum(c) }, exact_run=2))
  } else if pattern == "[A-Za-z0-9]{3}" || pattern == "[a-zA-Z0-9]{3}" {
    Some(run_matches_exact(chars, fn(c) { is_ascii_alnum(c) }, exact_run=3))
  } else if pattern == "[A-Za-z0-9]{4}" || pattern == "[a-zA-Z0-9]{4}" {
    Some(run_matches_exact(chars, fn(c) { is_ascii_alnum(c) }, exact_run=4))
  } else if pattern == "^[A-Za-z0-9]+" || pattern == "^[a-zA-Z0-9]+" {
    Some(leading_run_match(chars, fn(c) { is_ascii_alnum(c) }))
  } else if pattern == "[A-Za-z0-9]+$" || pattern == "[a-zA-Z0-9]+$" {
    Some(trailing_run_match(chars, fn(c) { is_ascii_alnum(c) }))
  } else if pattern == "[^A-Za-z0-9]+" || pattern == "[^a-zA-Z0-9]+" {
    Some(run_matches(chars, fn(c) { !is_ascii_alnum(c) }))
  } else if pattern == "[A-Za-z]+" || pattern == "[a-zA-Z]+" {
    Some(run_matches(chars, fn(c) { is_ascii_letter(c) }))
  } else if pattern == "[A-Za-z]{2,}" || pattern == "[a-zA-Z]{2,}" {
    Some(run_matches_min(chars, fn(c) { is_ascii_letter(c) }, min_run=2))
  } else if pattern == "[A-Za-z]{2}" || pattern == "[a-zA-Z]{2}" {
    Some(run_matches_exact(chars, fn(c) { is_ascii_letter(c) }, exact_run=2))
  } else if pattern == "[A-Za-z]{3}" || pattern == "[a-zA-Z]{3}" {
    Some(run_matches_exact(chars, fn(c) { is_ascii_letter(c) }, exact_run=3))
  } else if pattern == "[A-Za-z]{4}" || pattern == "[a-zA-Z]{4}" {
    Some(run_matches_exact(chars, fn(c) { is_ascii_letter(c) }, exact_run=4))
  } else if pattern == "^[A-Za-z]+" || pattern == "^[a-zA-Z]+" {
    Some(leading_run_match(chars, fn(c) { is_ascii_letter(c) }))
  } else if pattern == "[A-Za-z]+$" || pattern == "[a-zA-Z]+$" {
    Some(trailing_run_match(chars, fn(c) { is_ascii_letter(c) }))
  } else if pattern == "[^A-Za-z]+" || pattern == "[^a-zA-Z]+" {
    Some(run_matches(chars, fn(c) { !is_ascii_letter(c) }))
  } else if pattern == "\\p{L}+" ||
    pattern == "\\p{Letter}+" ||
    pattern == "[\\p{L}]+" ||
    pattern == "[\\p{Letter}]+" {
    Some(run_matches(chars, fn(c) { is_unicode_letter(c) }))
  } else if pattern == "\\p{L}{2,}" ||
    pattern == "\\p{Letter}{2,}" ||
    pattern == "[\\p{L}]{2,}" ||
    pattern == "[\\p{Letter}]{2,}" {
    Some(run_matches_min(chars, fn(c) { is_unicode_letter(c) }, min_run=2))
  } else if pattern == "\\p{L}{2}" ||
    pattern == "\\p{Letter}{2}" ||
    pattern == "[\\p{L}]{2}" ||
    pattern == "[\\p{Letter}]{2}" {
    Some(run_matches_exact(chars, fn(c) { is_unicode_letter(c) }, exact_run=2))
  } else if pattern == "\\p{L}{3}" ||
    pattern == "\\p{Letter}{3}" ||
    pattern == "[\\p{L}]{3}" ||
    pattern == "[\\p{Letter}]{3}" {
    Some(run_matches_exact(chars, fn(c) { is_unicode_letter(c) }, exact_run=3))
  } else if pattern == "\\p{L}{4}" ||
    pattern == "\\p{Letter}{4}" ||
    pattern == "[\\p{L}]{4}" ||
    pattern == "[\\p{Letter}]{4}" {
    Some(run_matches_exact(chars, fn(c) { is_unicode_letter(c) }, exact_run=4))
  } else if pattern == "^\\p{L}+" ||
    pattern == "^\\p{Letter}+" ||
    pattern == "^[\\p{L}]+" ||
    pattern == "^[\\p{Letter}]+" {
    Some(leading_run_match(chars, fn(c) { is_unicode_letter(c) }))
  } else if pattern == "\\p{L}+$" ||
    pattern == "\\p{Letter}+$" ||
    pattern == "[\\p{L}]+$" ||
    pattern == "[\\p{Letter}]+$" {
    Some(trailing_run_match(chars, fn(c) { is_unicode_letter(c) }))
  } else if pattern == "\\P{L}+" ||
    pattern == "\\P{Letter}+" ||
    pattern == "[^\\p{L}]+" ||
    pattern == "[^\\p{Letter}]+" {
    Some(run_matches(chars, fn(c) { !is_unicode_letter(c) }))
  } else if pattern == "\\p{P}+" ||
    pattern == "\\p{Punctuation}+" ||
    pattern == "[\\p{P}]+" ||
    pattern == "[\\p{Punctuation}]+" {
    Some(run_matches(chars, fn(c) { is_unicode_punctuation(c) }))
  } else if pattern == "\\p{P}{2,}" ||
    pattern == "\\p{Punctuation}{2,}" ||
    pattern == "[\\p{P}]{2,}" ||
    pattern == "[\\p{Punctuation}]{2,}" {
    Some(run_matches_min(chars, fn(c) { is_unicode_punctuation(c) }, min_run=2))
  } else if pattern == "\\p{P}{2}" ||
    pattern == "\\p{Punctuation}{2}" ||
    pattern == "[\\p{P}]{2}" ||
    pattern == "[\\p{Punctuation}]{2}" {
    Some(
      run_matches_exact(chars, fn(c) { is_unicode_punctuation(c) }, exact_run=2),
    )
  } else if pattern == "\\p{P}{3}" ||
    pattern == "\\p{Punctuation}{3}" ||
    pattern == "[\\p{P}]{3}" ||
    pattern == "[\\p{Punctuation}]{3}" {
    Some(
      run_matches_exact(chars, fn(c) { is_unicode_punctuation(c) }, exact_run=3),
    )
  } else if pattern == "\\p{P}{4}" ||
    pattern == "\\p{Punctuation}{4}" ||
    pattern == "[\\p{P}]{4}" ||
    pattern == "[\\p{Punctuation}]{4}" {
    Some(
      run_matches_exact(chars, fn(c) { is_unicode_punctuation(c) }, exact_run=4),
    )
  } else if pattern == "^\\p{P}+" ||
    pattern == "^\\p{Punctuation}+" ||
    pattern == "^[\\p{P}]+" ||
    pattern == "^[\\p{Punctuation}]+" {
    Some(leading_run_match(chars, fn(c) { is_unicode_punctuation(c) }))
  } else if pattern == "\\p{P}+$" ||
    pattern == "\\p{Punctuation}+$" ||
    pattern == "[\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}]+$" {
    Some(trailing_run_match(chars, fn(c) { is_unicode_punctuation(c) }))
  } else if pattern == "\\P{P}+" ||
    pattern == "\\P{Punctuation}+" ||
    pattern == "[^\\p{P}]+" ||
    pattern == "[^\\p{Punctuation}]+" {
    Some(run_matches(chars, fn(c) { !is_unicode_punctuation(c) }))
  } else if pattern == "\\p{S}+" ||
    pattern == "\\p{Symbol}+" ||
    pattern == "[\\p{S}]+" ||
    pattern == "[\\p{Symbol}]+" {
    Some(run_matches(chars, fn(c) { is_unicode_symbol(c) }))
  } else if pattern == "\\p{S}{2,}" ||
    pattern == "\\p{Symbol}{2,}" ||
    pattern == "[\\p{S}]{2,}" ||
    pattern == "[\\p{Symbol}]{2,}" {
    Some(run_matches_min(chars, fn(c) { is_unicode_symbol(c) }, min_run=2))
  } else if pattern == "\\p{S}{2}" ||
    pattern == "\\p{Symbol}{2}" ||
    pattern == "[\\p{S}]{2}" ||
    pattern == "[\\p{Symbol}]{2}" {
    Some(run_matches_exact(chars, fn(c) { is_unicode_symbol(c) }, exact_run=2))
  } else if pattern == "\\p{S}{3}" ||
    pattern == "\\p{Symbol}{3}" ||
    pattern == "[\\p{S}]{3}" ||
    pattern == "[\\p{Symbol}]{3}" {
    Some(run_matches_exact(chars, fn(c) { is_unicode_symbol(c) }, exact_run=3))
  } else if pattern == "\\p{S}{4}" ||
    pattern == "\\p{Symbol}{4}" ||
    pattern == "[\\p{S}]{4}" ||
    pattern == "[\\p{Symbol}]{4}" {
    Some(run_matches_exact(chars, fn(c) { is_unicode_symbol(c) }, exact_run=4))
  } else if pattern == "^\\p{S}+" ||
    pattern == "^\\p{Symbol}+" ||
    pattern == "^[\\p{S}]+" ||
    pattern == "^[\\p{Symbol}]+" {
    Some(leading_run_match(chars, fn(c) { is_unicode_symbol(c) }))
  } else if pattern == "\\p{S}+$" ||
    pattern == "\\p{Symbol}+$" ||
    pattern == "[\\p{S}]+$" ||
    pattern == "[\\p{Symbol}]+$" {
    Some(trailing_run_match(chars, fn(c) { is_unicode_symbol(c) }))
  } else if pattern == "\\P{S}+" ||
    pattern == "\\P{Symbol}+" ||
    pattern == "[^\\p{S}]+" ||
    pattern == "[^\\p{Symbol}]+" {
    Some(run_matches(chars, fn(c) { !is_unicode_symbol(c) }))
  } else if pattern == "[\\p{P}\\p{S}]+" ||
    pattern == "[\\p{S}\\p{P}]+" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+" {
    Some(run_matches(chars, fn(c) { is_unicode_punctuation_or_symbol(c) }))
  } else if pattern == "[\\p{P}\\p{S}]{2,}" ||
    pattern == "[\\p{S}\\p{P}]{2,}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2,}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2,}" {
    Some(
      run_matches_min(
        chars,
        fn(c) { is_unicode_punctuation_or_symbol(c) },
        min_run=2,
      ),
    )
  } else if pattern == "[\\p{P}\\p{S}]{2}" ||
    pattern == "[\\p{S}\\p{P}]{2}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2}" {
    Some(
      run_matches_exact(
        chars,
        fn(c) { is_unicode_punctuation_or_symbol(c) },
        exact_run=2,
      ),
    )
  } else if pattern == "[\\p{P}\\p{S}]{3}" ||
    pattern == "[\\p{S}\\p{P}]{3}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{3}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{3}" {
    Some(
      run_matches_exact(
        chars,
        fn(c) { is_unicode_punctuation_or_symbol(c) },
        exact_run=3,
      ),
    )
  } else if pattern == "[\\p{P}\\p{S}]{4}" ||
    pattern == "[\\p{S}\\p{P}]{4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{4}" {
    Some(
      run_matches_exact(
        chars,
        fn(c) { is_unicode_punctuation_or_symbol(c) },
        exact_run=4,
      ),
    )
  } else if pattern == "^[\\p{P}\\p{S}]+" ||
    pattern == "^[\\p{S}\\p{P}]+" ||
    pattern == "^[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "^[\\p{Symbol}\\p{Punctuation}]+" {
    Some(
      leading_run_match(chars, fn(c) { is_unicode_punctuation_or_symbol(c) }),
    )
  } else if pattern == "[\\p{P}\\p{S}]+$" ||
    pattern == "[\\p{S}\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+$" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+$" {
    Some(
      trailing_run_match(chars, fn(c) { is_unicode_punctuation_or_symbol(c) }),
    )
  } else if pattern == "[^\\p{P}\\p{S}]+" ||
    pattern == "[^\\p{S}\\p{P}]+" ||
    pattern == "[^\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[^\\p{Symbol}\\p{Punctuation}]+" {
    Some(run_matches(chars, fn(c) { !is_unicode_punctuation_or_symbol(c) }))
  } else if pattern == "[^\\s\\p{L}\\p{N}]+" ||
    pattern == "[^\\s\\p{N}\\p{L}]+" ||
    pattern == "[^\\p{L}\\p{N}\\s]+" ||
    pattern == "[^\\p{N}\\p{L}\\s]+" ||
    pattern == "[^\\s\\p{Letter}\\p{Number}]+" {
    Some(run_matches(chars, fn(c) { is_not_whitespace_letter_or_number(c) }))
  } else if pattern == "\\d+" ||
    pattern == "[\\d]+" ||
    pattern == "[0-9]+" ||
    pattern == "\\p{N}+" ||
    pattern == "\\p{Number}+" ||
    pattern == "[\\p{N}]+" ||
    pattern == "[\\p{Number}]+" {
    Some(run_matches(chars, fn(c) { is_decimal_number(c) }))
  } else if pattern == "^\\d+" ||
    pattern == "^[\\d]+" ||
    pattern == "^[0-9]+" ||
    pattern == "^\\p{N}+" ||
    pattern == "^\\p{Number}+" ||
    pattern == "^[\\p{N}]+" ||
    pattern == "^[\\p{Number}]+" {
    Some(leading_run_match(chars, fn(c) { is_decimal_number(c) }))
  } else if pattern == "\\d+$" ||
    pattern == "[\\d]+$" ||
    pattern == "[0-9]+$" ||
    pattern == "\\p{N}+$" ||
    pattern == "\\p{Number}+$" ||
    pattern == "[\\p{N}]+$" ||
    pattern == "[\\p{Number}]+$" {
    Some(trailing_run_match(chars, fn(c) { is_decimal_number(c) }))
  } else if pattern == "\\D+" ||
    pattern == "[\\D]+" ||
    pattern == "[^\\d]+" ||
    pattern == "[^0-9]+" ||
    pattern == "\\P{N}+" ||
    pattern == "\\P{Number}+" ||
    pattern == "[^\\p{N}]+" ||
    pattern == "[^\\p{Number}]+" {
    Some(run_matches(chars, fn(c) { !is_decimal_number(c) }))
  } else if pattern == "\\d{2,}" ||
    pattern == "[\\d]{2,}" ||
    pattern == "[0-9]{2,}" ||
    pattern == "\\p{N}{2,}" ||
    pattern == "\\p{Number}{2,}" ||
    pattern == "[\\p{N}]{2,}" ||
    pattern == "[\\p{Number}]{2,}" {
    Some(run_matches_min(chars, fn(c) { is_decimal_number(c) }, min_run=2))
  } else if pattern == "\\p{N}{2}" ||
    pattern == "\\p{Number}{2}" ||
    pattern == "[\\p{N}]{2}" ||
    pattern == "[\\p{Number}]{2}" ||
    pattern == "\\d{2}" ||
    pattern == "[\\d]{2}" ||
    pattern == "[0-9]{2}" {
    Some(number_exact_matches(chars, exact_digits=2))
  } else if pattern == "\\p{N}{3}" ||
    pattern == "\\p{Number}{3}" ||
    pattern == "[\\p{N}]{3}" ||
    pattern == "[\\p{Number}]{3}" ||
    pattern == "\\d{3}" ||
    pattern == "[\\d]{3}" ||
    pattern == "[0-9]{3}" {
    Some(number_exact_matches(chars, exact_digits=3))
  } else if pattern == "\\p{N}{4}" ||
    pattern == "\\p{Number}{4}" ||
    pattern == "[\\p{N}]{4}" ||
    pattern == "[\\p{Number}]{4}" ||
    pattern == "\\d{4}" ||
    pattern == "[\\d]{4}" ||
    pattern == "[0-9]{4}" {
    Some(number_exact_matches(chars, exact_digits=4))
  } else if pattern == "\\p{N}{1,2}" ||
    pattern == "\\p{Number}{1,2}" ||
    pattern == "[\\p{N}]{1,2}" ||
    pattern == "[\\p{Number}]{1,2}" ||
    pattern == "\\d{1,2}" ||
    pattern == "[\\d]{1,2}" ||
    pattern == "[0-9]{1,2}" ||
    pattern == "[0-9][0-9]" {
    Some(number_run_matches(chars, max_digits=2))
  } else if pattern == "\\p{N}{1,3}" ||
    pattern == "\\p{Number}{1,3}" ||
    pattern == "[\\p{N}]{1,3}" ||
    pattern == "[\\p{Number}]{1,3}" ||
    pattern == "\\d{1,3}" ||
    pattern == "[\\d]{1,3}" ||
    pattern == "[0-9]{1,3}" ||
    pattern == "[0-9][0-9][0-9]" {
    Some(number_run_matches(chars, max_digits=3))
  } else if pattern == "\\p{N}{1,4}" ||
    pattern == "\\p{Number}{1,4}" ||
    pattern == "[\\p{N}]{1,4}" ||
    pattern == "[\\p{Number}]{1,4}" ||
    pattern == "\\d{1,4}" ||
    pattern == "[\\d]{1,4}" ||
    pattern == "[0-9]{1,4}" ||
    pattern == "[0-9][0-9][0-9][0-9]" {
    Some(number_run_matches(chars, max_digits=4))
  } else {
    None
  }
}

///|
pub fn is_simple_split_regex_pattern(pattern : String) -> Bool {
  is_simple_space_regex_pattern(pattern) ||
  is_bounded_regex_pattern(pattern) ||
  pattern == "\\w+" ||
  pattern == "[A-Za-z0-9_]+" ||
  pattern == "\\b\\w+\\b" ||
  pattern == "\\b[A-Za-z0-9_]+\\b" ||
  pattern == "^\\w+" ||
  pattern == "^[A-Za-z0-9_]+" ||
  pattern == "\\w+$" ||
  pattern == "[A-Za-z0-9_]+$" ||
  pattern == "\\W+" ||
  pattern == "[^\\w]+" ||
  pattern == "[^A-Za-z0-9_]+" ||
  pattern == "\\w{2,}" ||
  pattern == "[A-Za-z0-9_]{2,}" ||
  pattern == "\\w{2}" ||
  pattern == "[A-Za-z0-9_]{2}" ||
  pattern == "\\w{3}" ||
  pattern == "[A-Za-z0-9_]{3}" ||
  pattern == "\\w{4}" ||
  pattern == "[A-Za-z0-9_]{4}" ||
  pattern == "[A-Za-z0-9]+" ||
  pattern == "[a-zA-Z0-9]+" ||
  pattern == "[A-Za-z0-9]{2,}" ||
  pattern == "[a-zA-Z0-9]{2,}" ||
  pattern == "[A-Za-z0-9]{2}" ||
  pattern == "[a-zA-Z0-9]{2}" ||
  pattern == "[A-Za-z0-9]{3}" ||
  pattern == "[a-zA-Z0-9]{3}" ||
  pattern == "[A-Za-z0-9]{4}" ||
  pattern == "[a-zA-Z0-9]{4}" ||
  pattern == "^[A-Za-z0-9]+" ||
  pattern == "^[a-zA-Z0-9]+" ||
  pattern == "[A-Za-z0-9]+$" ||
  pattern == "[a-zA-Z0-9]+$" ||
  pattern == "[^A-Za-z0-9]+" ||
  pattern == "[^a-zA-Z0-9]+" ||
  pattern == "[A-Za-z]+" ||
  pattern == "[a-zA-Z]+" ||
  pattern == "[A-Za-z]{2,}" ||
  pattern == "[a-zA-Z]{2,}" ||
  pattern == "[A-Za-z]{2}" ||
  pattern == "[a-zA-Z]{2}" ||
  pattern == "[A-Za-z]{3}" ||
  pattern == "[a-zA-Z]{3}" ||
  pattern == "[A-Za-z]{4}" ||
  pattern == "[a-zA-Z]{4}" ||
  pattern == "^[A-Za-z]+" ||
  pattern == "^[a-zA-Z]+" ||
  pattern == "[A-Za-z]+$" ||
  pattern == "[a-zA-Z]+$" ||
  pattern == "[^A-Za-z]+" ||
  pattern == "[^a-zA-Z]+" ||
  pattern == "\\p{L}+" ||
  pattern == "\\p{Letter}+" ||
  pattern == "[\\p{L}]+" ||
  pattern == "[\\p{Letter}]+" ||
  pattern == "\\p{L}{2,}" ||
  pattern == "\\p{Letter}{2,}" ||
  pattern == "[\\p{L}]{2,}" ||
  pattern == "[\\p{Letter}]{2,}" ||
  pattern == "\\p{L}{2}" ||
  pattern == "\\p{Letter}{2}" ||
  pattern == "[\\p{L}]{2}" ||
  pattern == "[\\p{Letter}]{2}" ||
  pattern == "\\p{L}{3}" ||
  pattern == "\\p{Letter}{3}" ||
  pattern == "[\\p{L}]{3}" ||
  pattern == "[\\p{Letter}]{3}" ||
  pattern == "\\p{L}{4}" ||
  pattern == "\\p{Letter}{4}" ||
  pattern == "[\\p{L}]{4}" ||
  pattern == "[\\p{Letter}]{4}" ||
  pattern == "^\\p{L}+" ||
  pattern == "^\\p{Letter}+" ||
  pattern == "^[\\p{L}]+" ||
  pattern == "^[\\p{Letter}]+" ||
  pattern == "\\p{L}+$" ||
  pattern == "\\p{Letter}+$" ||
  pattern == "[\\p{L}]+$" ||
  pattern == "[\\p{Letter}]+$" ||
  pattern == "\\P{L}+" ||
  pattern == "\\P{Letter}+" ||
  pattern == "[^\\p{L}]+" ||
  pattern == "[^\\p{Letter}]+" ||
  is_simple_punctuation_symbol_regex_pattern(pattern) ||
  is_simple_number_regex_pattern(pattern)
}

///|
fn is_simple_space_regex_pattern(pattern : String) -> Bool {
  pattern == "\\s+" ||
  pattern == "\\s{2,}" ||
  pattern == "[\\s]{2,}" ||
  pattern == "\\s{3,}" ||
  pattern == "[\\s]{3,}" ||
  pattern == "\\s{4,}" ||
  pattern == "[\\s]{4,}" ||
  pattern == "\\s{2}" ||
  pattern == "[\\s]{2}" ||
  pattern == "\\s{3}" ||
  pattern == "[\\s]{3}" ||
  pattern == "\\s{4}" ||
  pattern == "[\\s]{4}" ||
  pattern == "^\\s+" ||
  pattern == "\\S+" ||
  pattern == "[^\\s]+" ||
  pattern == "\\s+$" ||
  pattern == "[ \\t]+" ||
  pattern == "[^\\S\\r\\n]+" ||
  pattern == "[ \\t]{2,}" ||
  pattern == "[^\\S\\r\\n]{2,}" ||
  pattern == "[ \\t]{3,}" ||
  pattern == "[^\\S\\r\\n]{3,}" ||
  pattern == "[ \\t]{4,}" ||
  pattern == "[^\\S\\r\\n]{4,}" ||
  pattern == "[ \\t]{2}" ||
  pattern == "[^\\S\\r\\n]{2}" ||
  pattern == "[ \\t]{3}" ||
  pattern == "[^\\S\\r\\n]{3}" ||
  pattern == "[ \\t]{4}" ||
  pattern == "[^\\S\\r\\n]{4}" ||
  pattern == "[\\r\\n]" ||
  pattern == "[\r\n]" ||
  pattern == "[\\r\\n]+" ||
  pattern == "[\r\n]+" ||
  pattern == "[\\r\\n]{2,}" ||
  pattern == "[\r\n]{2,}" ||
  pattern == "[\\r\\n]{3,}" ||
  pattern == "[\r\n]{3,}" ||
  pattern == "[\\r\\n]{4,}" ||
  pattern == "[\r\n]{4,}" ||
  pattern == "[\\r\\n]{2}" ||
  pattern == "[\r\n]{2}" ||
  pattern == "[\\r\\n]{3}" ||
  pattern == "[\r\n]{3}" ||
  pattern == "[\\r\\n]{4}" ||
  pattern == "[\r\n]{4}"
}

///|
fn is_simple_punctuation_symbol_regex_pattern(pattern : String) -> Bool {
  pattern == "\\p{P}+" ||
  pattern == "\\p{Punctuation}+" ||
  pattern == "[\\p{P}]+" ||
  pattern == "[\\p{Punctuation}]+" ||
  pattern == "\\p{P}{2,}" ||
  pattern == "\\p{Punctuation}{2,}" ||
  pattern == "[\\p{P}]{2,}" ||
  pattern == "[\\p{Punctuation}]{2,}" ||
  pattern == "\\p{P}{2}" ||
  pattern == "\\p{Punctuation}{2}" ||
  pattern == "[\\p{P}]{2}" ||
  pattern == "[\\p{Punctuation}]{2}" ||
  pattern == "\\p{P}{3}" ||
  pattern == "\\p{Punctuation}{3}" ||
  pattern == "[\\p{P}]{3}" ||
  pattern == "[\\p{Punctuation}]{3}" ||
  pattern == "\\p{P}{4}" ||
  pattern == "\\p{Punctuation}{4}" ||
  pattern == "[\\p{P}]{4}" ||
  pattern == "[\\p{Punctuation}]{4}" ||
  pattern == "^\\p{P}+" ||
  pattern == "^\\p{Punctuation}+" ||
  pattern == "^[\\p{P}]+" ||
  pattern == "^[\\p{Punctuation}]+" ||
  pattern == "\\p{P}+$" ||
  pattern == "\\p{Punctuation}+$" ||
  pattern == "[\\p{P}]+$" ||
  pattern == "[\\p{Punctuation}]+$" ||
  pattern == "\\P{P}+" ||
  pattern == "\\P{Punctuation}+" ||
  pattern == "[^\\p{P}]+" ||
  pattern == "[^\\p{Punctuation}]+" ||
  pattern == "\\p{S}+" ||
  pattern == "\\p{Symbol}+" ||
  pattern == "[\\p{S}]+" ||
  pattern == "[\\p{Symbol}]+" ||
  pattern == "\\p{S}{2,}" ||
  pattern == "\\p{Symbol}{2,}" ||
  pattern == "[\\p{S}]{2,}" ||
  pattern == "[\\p{Symbol}]{2,}" ||
  pattern == "\\p{S}{2}" ||
  pattern == "\\p{Symbol}{2}" ||
  pattern == "[\\p{S}]{2}" ||
  pattern == "[\\p{Symbol}]{2}" ||
  pattern == "\\p{S}{3}" ||
  pattern == "\\p{Symbol}{3}" ||
  pattern == "[\\p{S}]{3}" ||
  pattern == "[\\p{Symbol}]{3}" ||
  pattern == "\\p{S}{4}" ||
  pattern == "\\p{Symbol}{4}" ||
  pattern == "[\\p{S}]{4}" ||
  pattern == "[\\p{Symbol}]{4}" ||
  pattern == "^\\p{S}+" ||
  pattern == "^\\p{Symbol}+" ||
  pattern == "^[\\p{S}]+" ||
  pattern == "^[\\p{Symbol}]+" ||
  pattern == "\\p{S}+$" ||
  pattern == "\\p{Symbol}+$" ||
  pattern == "[\\p{S}]+$" ||
  pattern == "[\\p{Symbol}]+$" ||
  pattern == "\\P{S}+" ||
  pattern == "\\P{Symbol}+" ||
  pattern == "[^\\p{S}]+" ||
  pattern == "[^\\p{Symbol}]+" ||
  pattern == "[\\p{P}\\p{S}]+" ||
  pattern == "[\\p{S}\\p{P}]+" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]+" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]+" ||
  pattern == "[\\p{P}\\p{S}]{2,}" ||
  pattern == "[\\p{S}\\p{P}]{2,}" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]{2,}" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]{2,}" ||
  pattern == "[\\p{P}\\p{S}]{2}" ||
  pattern == "[\\p{S}\\p{P}]{2}" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]{2}" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]{2}" ||
  pattern == "[\\p{P}\\p{S}]{3}" ||
  pattern == "[\\p{S}\\p{P}]{3}" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]{3}" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]{3}" ||
  pattern == "[\\p{P}\\p{S}]{4}" ||
  pattern == "[\\p{S}\\p{P}]{4}" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]{4}" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]{4}" ||
  pattern == "^[\\p{P}\\p{S}]+" ||
  pattern == "^[\\p{S}\\p{P}]+" ||
  pattern == "^[\\p{Punctuation}\\p{Symbol}]+" ||
  pattern == "^[\\p{Symbol}\\p{Punctuation}]+" ||
  pattern == "[\\p{P}\\p{S}]+$" ||
  pattern == "[\\p{S}\\p{P}]+$" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]+$" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]+$" ||
  pattern == "[^\\p{P}\\p{S}]+" ||
  pattern == "[^\\p{S}\\p{P}]+" ||
  pattern == "[^\\p{Punctuation}\\p{Symbol}]+" ||
  pattern == "[^\\p{Symbol}\\p{Punctuation}]+" ||
  pattern == "[^\\s\\p{L}\\p{N}]+" ||
  pattern == "[^\\s\\p{N}\\p{L}]+" ||
  pattern == "[^\\p{L}\\p{N}\\s]+" ||
  pattern == "[^\\p{N}\\p{L}\\s]+" ||
  pattern == "[^\\s\\p{Letter}\\p{Number}]+"
}

///|
fn is_simple_number_regex_pattern(pattern : String) -> Bool {
  pattern == "\\d+" ||
  pattern == "[\\d]+" ||
  pattern == "[0-9]+" ||
  pattern == "\\p{N}+" ||
  pattern == "\\p{Number}+" ||
  pattern == "[\\p{N}]+" ||
  pattern == "[\\p{Number}]+" ||
  pattern == "^\\d+" ||
  pattern == "^[\\d]+" ||
  pattern == "^[0-9]+" ||
  pattern == "^\\p{N}+" ||
  pattern == "^\\p{Number}+" ||
  pattern == "^[\\p{N}]+" ||
  pattern == "^[\\p{Number}]+" ||
  pattern == "\\d+$" ||
  pattern == "[\\d]+$" ||
  pattern == "[0-9]+$" ||
  pattern == "\\p{N}+$" ||
  pattern == "\\p{Number}+$" ||
  pattern == "[\\p{N}]+$" ||
  pattern == "[\\p{Number}]+$" ||
  pattern == "\\D+" ||
  pattern == "[\\D]+" ||
  pattern == "[^\\d]+" ||
  pattern == "[^0-9]+" ||
  pattern == "\\P{N}+" ||
  pattern == "\\P{Number}+" ||
  pattern == "[^\\p{N}]+" ||
  pattern == "[^\\p{Number}]+" ||
  pattern == "\\d{2,}" ||
  pattern == "[\\d]{2,}" ||
  pattern == "[0-9]{2,}" ||
  pattern == "\\p{N}{2,}" ||
  pattern == "\\p{Number}{2,}" ||
  pattern == "[\\p{N}]{2,}" ||
  pattern == "[\\p{Number}]{2,}" ||
  pattern == "\\p{N}{2}" ||
  pattern == "\\p{Number}{2}" ||
  pattern == "[\\p{N}]{2}" ||
  pattern == "[\\p{Number}]{2}" ||
  pattern == "\\d{2}" ||
  pattern == "[\\d]{2}" ||
  pattern == "[0-9]{2}" ||
  pattern == "\\p{N}{3}" ||
  pattern == "\\p{Number}{3}" ||
  pattern == "[\\p{N}]{3}" ||
  pattern == "[\\p{Number}]{3}" ||
  pattern == "\\d{3}" ||
  pattern == "[\\d]{3}" ||
  pattern == "[0-9]{3}" ||
  pattern == "\\p{N}{4}" ||
  pattern == "\\p{Number}{4}" ||
  pattern == "[\\p{N}]{4}" ||
  pattern == "[\\p{Number}]{4}" ||
  pattern == "\\d{4}" ||
  pattern == "[\\d]{4}" ||
  pattern == "[0-9]{4}" ||
  pattern == "\\p{N}{1,2}" ||
  pattern == "\\p{Number}{1,2}" ||
  pattern == "[\\p{N}]{1,2}" ||
  pattern == "[\\p{Number}]{1,2}" ||
  pattern == "\\d{1,2}" ||
  pattern == "[\\d]{1,2}" ||
  pattern == "[0-9]{1,2}" ||
  pattern == "[0-9][0-9]" ||
  pattern == "\\p{N}{1,3}" ||
  pattern == "\\p{Number}{1,3}" ||
  pattern == "[\\p{N}]{1,3}" ||
  pattern == "[\\p{Number}]{1,3}" ||
  pattern == "\\d{1,3}" ||
  pattern == "[\\d]{1,3}" ||
  pattern == "[0-9]{1,3}" ||
  pattern == "[0-9][0-9][0-9]" ||
  pattern == "\\p{N}{1,4}" ||
  pattern == "\\p{Number}{1,4}" ||
  pattern == "[\\p{N}]{1,4}" ||
  pattern == "[\\p{Number}]{1,4}" ||
  pattern == "\\d{1,4}" ||
  pattern == "[\\d]{1,4}" ||
  pattern == "[0-9]{1,4}" ||
  pattern == "[0-9][0-9][0-9][0-9]"
}

///|
pub fn literal_matches(chars : Array[Char], pattern : String) -> Array[Span]? {
  if pattern.is_empty() {
    return None
  }
  let pat = pattern.to_array()
  let out : Array[Span] = []
  let n = chars.length()
  let m = pat.length()
  let mut i = 0
  while i < n {
    if i + m <= n && chars_match_at(chars, i, pat) {
      out.push({ start: i, stop: i + m })
      i = i + m
    } else {
      i = i + 1
    }
  }
  Some(out)
}

///|
pub fn is_decimal_number(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x30 && u <= 0x39) ||
  (u >= 0x0660 && u <= 0x0669) ||
  (u >= 0x06F0 && u <= 0x06F9) ||
  (u >= 0x0966 && u <= 0x096F) ||
  (u >= 0xFF10 && u <= 0xFF19)
}

///|
fn run_matches(chars : Array[Char], pred : (Char) -> Bool) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      while i < n && pred(chars[i]) {
        i = i + 1
      }
      out.push({ start, stop: i })
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn run_matches_min(
  chars : Array[Char],
  pred : (Char) -> Bool,
  min_run~ : Int,
) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      while i < n && pred(chars[i]) {
        i = i + 1
      }
      if i - start >= min_run {
        out.push({ start, stop: i })
      }
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn run_matches_exact(
  chars : Array[Char],
  pred : (Char) -> Bool,
  exact_run~ : Int,
) -> Array[Span] {
  let out : Array[Span] = []
  if exact_run <= 0 {
    return out
  }
  let n = chars.length()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      while i < n && pred(chars[i]) {
        i = i + 1
      }
      let run = i - start
      let full_stop = start + run / exact_run * exact_run
      let mut j = start
      while j < full_stop {
        out.push({ start: j, stop: j + exact_run })
        j = j + exact_run
      }
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn run_matches_bounded(
  chars : Array[Char],
  pred : (Char) -> Bool,
  max_run~ : Int,
) -> Array[Span] {
  let out : Array[Span] = []
  if max_run <= 0 {
    return out
  }
  let n = chars.length()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      let mut count = 0
      while i < n && pred(chars[i]) && count < max_run {
        i = i + 1
        count = count + 1
      }
      out.push({ start, stop: i })
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn simple_bounded_regex_matches(
  chars : Array[Char],
  pattern : String,
) -> Array[Span]? {
  match bounded_regex_kind(pattern) {
    Some((kind, max_run)) =>
      Some(
        run_matches_bounded(
          chars,
          fn(c) { bounded_regex_kind_pred(kind, c) },
          max_run~,
        ),
      )
    None => None
  }
}

///|
fn leading_run_match(chars : Array[Char], pred : (Char) -> Bool) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  let mut i = 0
  while i < n && pred(chars[i]) {
    i = i + 1
  }
  if i > 0 {
    out.push({ start: 0, stop: i })
  }
  out
}

///|
fn trailing_run_match(
  chars : Array[Char],
  pred : (Char) -> Bool,
) -> Array[Span] {
  let out : Array[Span] = []
  let mut i = chars.length()
  while i > 0 && pred(chars[i - 1]) {
    i = i - 1
  }
  if i < chars.length() {
    out.push({ start: i, stop: chars.length() })
  }
  out
}

///|
fn number_run_matches(chars : Array[Char], max_digits~ : Int) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    if is_decimal_number(chars[i]) {
      let start = i
      let mut count = 0
      while i < n && is_decimal_number(chars[i]) && count < max_digits {
        i = i + 1
        count = count + 1
      }
      out.push({ start, stop: i })
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn number_exact_matches(
  chars : Array[Char],
  exact_digits~ : Int,
) -> Array[Span] {
  let out : Array[Span] = []
  if exact_digits <= 0 {
    return out
  }
  let n = chars.length()
  let mut i = 0
  while i < n {
    if is_decimal_number(chars[i]) {
      let start = i
      while i < n && is_decimal_number(chars[i]) {
        i = i + 1
      }
      let run = i - start
      let full_stop = start + run / exact_digits * exact_digits
      let mut j = start
      while j < full_stop {
        out.push({ start: j, stop: j + exact_digits })
        j = j + exact_digits
      }
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn chars_match_at(src : Array[Char], at : Int, pat : Array[Char]) -> Bool {
  for k in 0..<pat.length() {
    if src[at + k] != pat[k] {
      return false
    }
  }
  true
}
