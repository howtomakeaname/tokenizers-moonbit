// Shared helpers for the small Split regex subset that can be implemented with
// deterministic char scanners instead of a general regex engine.

///|
pub(all) struct Span {
  start : Int
  stop : Int
}

///|
/// Lightweight public Regex wrapper for the deterministic regex subset shared by
/// Split, Normalizer::Replace and Decoder::Replace. It deliberately exposes a
/// capability check so callers can avoid assuming a full backtracking regex
/// engine exists on every MoonBit target.
pub struct Regex {
  pattern : String
} derive(Debug, Eq)

///|
pub fn Regex::new(pattern : String) -> Regex {
  { pattern, }
}

///|
pub fn Regex::pattern(self : Regex) -> String {
  self.pattern
}

///|
/// Whether this pattern is handled by the built-in deterministic scanner.
pub fn Regex::is_supported(self : Regex) -> Bool {
  simple_split_regex_matches([], self.pattern) is Some(_)
}

///|
/// Return half-open char spans for all matches, or `None` when the pattern is
/// outside the supported deterministic subset.
pub fn Regex::find_matches(self : Regex, text : String) -> Array[(Int, Int)]? {
  match simple_split_regex_matches(text.to_array(), self.pattern) {
    Some(spans) => Some(spans.map(s => (s.start, s.stop)))
    None => None
  }
}

///|
/// Replace all matches of the supported deterministic subset. Unsupported
/// patterns return `None` instead of silently falling back to literal matching.
pub fn Regex::replace_all(
  self : Regex,
  text : String,
  content : String,
) -> String? {
  replace_simple_regex(text, self.pattern, content)
}

///|
pub fn simple_split_regex_matches(
  chars : Array[Char],
  pattern : String,
) -> Array[Span]? {
  match regex_literal_spec(pattern) {
    Some((lit, anchored_start, anchored_end, word_start, word_end)) =>
      return Some(
        literal_alternation_matches(
          chars,
          [lit],
          anchored_start~,
          anchored_end~,
          word_start~,
          word_end~,
        ),
      )
    None => ()
  }
  match regex_literal_alternatives_spec(pattern) {
    Some((alts, anchored_start, anchored_end, word_start, word_end)) =>
      return Some(
        literal_alternation_matches(
          chars,
          alts,
          anchored_start~,
          anchored_end~,
          word_start~,
          word_end~,
        ),
      )
    None => ()
  }
  match simple_exact_regex_matches(chars, pattern) {
    Some(spans) => return Some(spans)
    None => ()
  }
  match simple_min_regex_matches(chars, pattern) {
    Some(spans) => return Some(spans)
    None => ()
  }
  match simple_bounded_regex_matches(chars, pattern) {
    Some(spans) => return Some(spans)
    None => ()
  }
  match simple_anchored_regex_matches(chars, pattern) {
    Some(spans) => return Some(spans)
    None => ()
  }
  match simple_ranged_regex_matches(chars, pattern) {
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
fn simple_anchored_regex_matches(
  chars : Array[Char],
  pattern : String,
) -> Array[Span]? {
  match anchored_regex_kind(pattern) {
    Some((kind, leading)) =>
      if leading {
        Some(
          leading_run_match(chars, fn(c) { bounded_regex_kind_pred(kind, c) }),
        )
      } else {
        Some(
          trailing_run_match(chars, fn(c) { bounded_regex_kind_pred(kind, c) }),
        )
      }
    None => None
  }
}

///|
pub fn is_simple_split_regex_pattern(pattern : String) -> Bool {
  regex_literal_spec(pattern) is Some(_) ||
  regex_literal_alternatives_spec(pattern) is Some(_) ||
  is_simple_space_regex_pattern(pattern) ||
  is_exact_regex_pattern(pattern) ||
  is_min_regex_pattern(pattern) ||
  is_bounded_regex_pattern(pattern) ||
  is_anchored_regex_pattern(pattern) ||
  is_ranged_regex_pattern(pattern) ||
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
/// Interpret the subset of regex patterns that are plain literals. This covers
/// real tokenizer configs that set `regex=true` while still using exact text
/// delimiters, escaped regex metacharacters such as `\\.`, and simple HF/Rust
/// regex wrappers such as `^foo`, `foo$`, `^foo$` and `\\bfoo\\b`. Patterns with
/// active regex operators intentionally return `None` so callers keep using the
/// explicit deterministic scanners above instead of silently changing meaning.
fn regex_literal_spec(pattern : String) -> (String, Bool, Bool, Bool, Bool)? {
  if pattern.is_empty() {
    return None
  }
  let chars = pattern.to_array()
  match regex_literal_wrapper_bounds(chars) {
    Some((start, stop, anchored_start, anchored_end, word_start, word_end)) => {
      if start >= stop {
        return None
      }
      let body = regex_alternation_body(char_slice(chars, start, stop))
      if has_unescaped_pipe(body) {
        return None
      }
      match parse_regex_literal_body(body) {
        Some(lit) =>
          Some((lit, anchored_start, anchored_end, word_start, word_end))
        None => None
      }
    }
    None => None
  }
}

///|
fn parse_regex_literal_body(chars : Array[Char]) -> String? {
  if chars.length() == 0 {
    return None
  }
  let sb = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '\\' {
      if i + 1 >= chars.length() {
        return None
      }
      let next = chars[i + 1]
      if is_regex_escaped_literal(next) {
        sb.write_char(next)
      } else if next == 'n' {
        sb.write_char('\n')
      } else if next == 'r' {
        sb.write_char('\r')
      } else if next == 't' {
        sb.write_char('\t')
      } else {
        return None
      }
      i = i + 2
    } else if is_regex_operator(c) {
      return None
    } else {
      sb.write_char(c)
      i = i + 1
    }
  }
  Some(sb.to_string())
}

///|
fn regex_literal_wrapper_bounds(
  chars : Array[Char],
) -> (Int, Int, Bool, Bool, Bool, Bool)? {
  let mut start = 0
  let mut stop = chars.length()
  let mut anchored_start = false
  let mut anchored_end = false
  let mut word_start = false
  let mut word_end = false
  if start < stop && chars[start] == '^' {
    anchored_start = true
    start = start + 1
  }
  if start + 1 < stop && chars[start] == '\\' && chars[start + 1] == 'b' {
    word_start = true
    start = start + 2
  }
  if start < stop && chars[stop - 1] == '$' && !is_escaped_at(chars, stop - 1) {
    anchored_end = true
    stop = stop - 1
  }
  if start + 1 < stop && chars[stop - 2] == '\\' && chars[stop - 1] == 'b' {
    word_end = true
    stop = stop - 2
  }
  Some((start, stop, anchored_start, anchored_end, word_start, word_end))
}

///|
/// Interpret simple literal alternations such as `foo|bar`, `(foo|bar)`,
/// `(?:foo|bar)`, `^(?:foo|bar)`, `(?:foo|bar)$` and word-boundary wrapped
/// `\b(?:foo|bar)\b`. Each branch must itself be a regex literal (including
/// escaped metacharacters like `\\.` or `\\|`). This intentionally does not
/// implement nested groups or arbitrary regex alternation; unsupported forms
/// still return `None` so callers fail explicitly instead of producing
/// approximate matches.
fn regex_literal_alternatives_spec(
  pattern : String,
) -> (Array[String], Bool, Bool, Bool, Bool)? {
  if pattern.is_empty() {
    return None
  }
  let chars = pattern.to_array()
  let (start, stop, anchored_start, anchored_end, word_start, word_end) = match
    regex_literal_wrapper_bounds(chars) {
    Some(spec) => spec
    None => return None
  }
  if start >= stop {
    return None
  }
  let body = regex_alternation_body(char_slice(chars, start, stop))
  if body.length() == 0 || !has_unescaped_pipe(body) {
    return None
  }
  let out : Array[String] = []
  let mut current : Array[Char] = []
  let mut i = 0
  while i < body.length() {
    let c = body[i]
    if c == '\\' {
      if i + 1 >= body.length() {
        return None
      }
      let next = body[i + 1]
      if is_regex_escaped_literal(next) {
        current.push(next)
      } else if next == 'n' {
        current.push('\n')
      } else if next == 'r' {
        current.push('\r')
      } else if next == 't' {
        current.push('\t')
      } else {
        return None
      }
      i = i + 2
    } else if c == '|' {
      let lit = chars_to_string(current)
      if lit.is_empty() {
        return None
      }
      out.push(lit)
      current = []
      i = i + 1
    } else if is_regex_operator(c) {
      return None
    } else {
      current.push(c)
      i = i + 1
    }
  }
  let last = chars_to_string(current)
  if last.is_empty() {
    return None
  }
  out.push(last)
  if out.length() >= 2 {
    Some((out, anchored_start, anchored_end, word_start, word_end))
  } else {
    None
  }
}

///|
fn is_escaped_at(chars : Array[Char], index : Int) -> Bool {
  if index <= 0 || index >= chars.length() {
    return false
  }
  let mut count = 0
  let mut i = index - 1
  while i >= 0 && chars[i] == '\\' {
    count = count + 1
    if i == 0 {
      break
    }
    i = i - 1
  }
  count % 2 == 1
}

///|
fn regex_alternation_body(chars : Array[Char]) -> Array[Char] {
  if chars.length() >= 3 && chars[0] == '(' && chars[chars.length() - 1] == ')' {
    if chars.length() >= 4 && chars[1] == '?' && chars[2] == ':' {
      return char_slice(chars, 3, chars.length() - 1)
    }
    return char_slice(chars, 1, chars.length() - 1)
  }
  chars
}

///|
fn char_slice(chars : Array[Char], start : Int, stop : Int) -> Array[Char] {
  let out : Array[Char] = []
  let lo = if start < 0 { 0 } else { start }
  let hi = if stop > chars.length() { chars.length() } else { stop }
  for i in lo..<hi {
    out.push(chars[i])
  }
  out
}

///|
fn chars_to_string(chars : Array[Char]) -> String {
  let sb = StringBuilder::new()
  for c in chars {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn has_unescaped_pipe(chars : Array[Char]) -> Bool {
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' {
      i = i + 2
    } else if chars[i] == '|' {
      return true
    } else {
      i = i + 1
    }
  }
  false
}

///|
fn literal_alternation_matches(
  chars : Array[Char],
  alternatives : Array[String],
  anchored_start? : Bool = false,
  anchored_end? : Bool = false,
  word_start? : Bool = false,
  word_end? : Bool = false,
) -> Array[Span] {
  let pats = alternatives.map(alt => alt.to_array())
  if anchored_start || anchored_end {
    return literal_alternation_matches_anchored(
      chars,
      pats,
      anchored_start~,
      anchored_end~,
      word_start~,
      word_end~,
    )
  }
  let out : Array[Span] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    let mut matched_len : Int? = None
    for pat in pats {
      let m = pat.length()
      if m > 0 &&
        i + m <= n &&
        chars_match_at(chars, i, pat) &&
        literal_word_boundaries_match(chars, i, i + m, word_start, word_end) {
        matched_len = Some(m)
        break
      }
    }
    match matched_len {
      Some(m) => {
        out.push({ start: i, stop: i + m })
        i = i + m
      }
      None => i = i + 1
    }
  }
  out
}

///|
fn literal_alternation_matches_anchored(
  chars : Array[Char],
  pats : Array[Array[Char]],
  anchored_start~ : Bool,
  anchored_end~ : Bool,
  word_start~ : Bool,
  word_end~ : Bool,
) -> Array[Span] {
  let n = chars.length()
  if anchored_start {
    for pat in pats {
      let m = pat.length()
      if m > 0 &&
        m <= n &&
        (!anchored_end || m == n) &&
        chars_match_at(chars, 0, pat) &&
        literal_word_boundaries_match(chars, 0, m, word_start, word_end) {
        return [{ start: 0, stop: m }]
      }
    }
    return []
  }
  let mut i = 0
  while i < n {
    for pat in pats {
      let m = pat.length()
      if m > 0 &&
        i + m == n &&
        chars_match_at(chars, i, pat) &&
        literal_word_boundaries_match(chars, i, n, word_start, word_end) {
        return [{ start: i, stop: n }]
      }
    }
    i = i + 1
  }
  []
}

///|
fn literal_word_boundaries_match(
  chars : Array[Char],
  start : Int,
  stop : Int,
  word_start : Bool,
  word_end : Bool,
) -> Bool {
  (!word_start || regex_word_boundary_at(chars, start)) &&
  (!word_end || regex_word_boundary_at(chars, stop))
}

///|
fn regex_word_boundary_at(chars : Array[Char], pos : Int) -> Bool {
  let left = pos > 0 && pos <= chars.length() && is_word_char(chars[pos - 1])
  let right = pos >= 0 && pos < chars.length() && is_word_char(chars[pos])
  left != right
}

///|
fn is_regex_operator(c : Char) -> Bool {
  c == '.' ||
  c == '^' ||
  c == '$' ||
  c == '*' ||
  c == '+' ||
  c == '?' ||
  c == '{' ||
  c == '}' ||
  c == '[' ||
  c == ']' ||
  c == '(' ||
  c == ')' ||
  c == '|'
}

///|
fn is_regex_escaped_literal(c : Char) -> Bool {
  is_regex_operator(c) || c == '\\'
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
fn run_matches_ranged(
  chars : Array[Char],
  pred : (Char) -> Bool,
  min_run~ : Int,
  max_run~ : Int,
) -> Array[Span] {
  let out : Array[Span] = []
  if min_run <= 0 || max_run < min_run {
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
      let stop = i
      let mut j = start
      while stop - j >= min_run {
        let mut take = max_run
        if stop - j < take {
          take = stop - j
        }
        out.push({ start: j, stop: j + take })
        j = j + take
      }
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
fn simple_exact_regex_matches(
  chars : Array[Char],
  pattern : String,
) -> Array[Span]? {
  match exact_regex_kind(pattern) {
    Some((kind, exact_run)) =>
      Some(
        run_matches_exact(
          chars,
          fn(c) { bounded_regex_kind_pred(kind, c) },
          exact_run~,
        ),
      )
    None => None
  }
}

///|
fn simple_min_regex_matches(
  chars : Array[Char],
  pattern : String,
) -> Array[Span]? {
  match min_regex_kind(pattern) {
    Some((kind, min_run)) =>
      Some(
        run_matches_min(
          chars,
          fn(c) { bounded_regex_kind_pred(kind, c) },
          min_run~,
        ),
      )
    None => None
  }
}

///|
fn simple_ranged_regex_matches(
  chars : Array[Char],
  pattern : String,
) -> Array[Span]? {
  match ranged_regex_kind(pattern) {
    Some((kind, min_run, max_run)) =>
      Some(
        run_matches_ranged(
          chars,
          fn(c) { bounded_regex_kind_pred(kind, c) },
          min_run~,
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
