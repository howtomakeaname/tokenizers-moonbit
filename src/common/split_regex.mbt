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
  } else if pattern == " {2,}" {
    Some(run_matches_min(chars, fn(c) { c == ' ' }, min_run=2))
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
