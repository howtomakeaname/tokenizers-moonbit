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
  // bare assertion sequences (`\b$`, `^\b`, `^$`...) are zero-width
  match regex_literal_assertions_spec(pattern) {
    Some((bs, be, ws, we)) =>
      return Some(assertion_sequence_matches(chars, bs, be, ws, we))
    None => ()
  }
  // double-anchored whole-line windows (probed 0.22.2: '^.{0,2}$'
  // as an Isolated Split on 'ab\nabc\n\na' -> 4 pieces incl. the
  // empty-line match)
  match double_anchored_spec(pattern) {
    Some((kind, literal, lo, hi)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { bounded_regex_kind_pred(kind, x) }
      }
      return Some(double_anchored_line_spans(chars, pred, lo, hi))
    }
    None => ()
  }
  // bare single-char classes match per char (issue #47; probed 0.22.2:
  // '\s' Isolated on 'a b' -> a, ' '(1,2), b)
  match bare_class_kind(pattern) {
    Some(kind) =>
      return Some(
        exact_one_matches(chars, fn(c) { bounded_regex_kind_pred(kind, c) }),
      )
    None => ()
  }
  if pattern == "[\\s]+" {
    return Some(run_matches(chars, fn(c) { is_unicode_whitespace(c.to_int()) }))
  }
  // PER-BRANCH anchors first: `^foo|bar$` binds anchors per branch —
  // the global-anchor reading below would misread it (probed 0.22.2)
  match regex_literal_branch_alternatives_spec(pattern) {
    Some(spec) => {
      let (branches, _global_ws, _global_we) = spec
      return Some(literal_branch_alternation_matches(chars, branches))
    }
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
    Some(
      leading_run_match_multiline(chars, fn(c) {
        is_unicode_whitespace(c.to_int())
      }),
    )
  } else if pattern == "^[\\r\\n]+" {
    Some(leading_run_match_multiline(chars, fn(c) { c == '\r' || c == '\n' }))
  } else if pattern == "[\\r\\n]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { c == '\r' || c == '\n' }))
  } else if pattern == "\\S+" || pattern == "[^\\s]+" {
    Some(run_matches(chars, fn(c) { !is_unicode_whitespace(c.to_int()) }))
  } else if pattern == "\\s+$" {
    Some(
      trailing_run_match_multiline(chars, fn(c) {
        is_unicode_whitespace(c.to_int())
      }),
    )
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
  } else if pattern == "[\\r\\n]" || pattern == "[\r\n]" {
    // no-plus spelling matches SINGLE chars (probed 0.22.2: 'a\n\nb'
    // Isolated -> a, \n(1,2), \n(2,3), b) — not maximal runs
    Some(exact_one_matches(chars, fn(c) { c == '\r' || c == '\n' }))
  } else if pattern == "[\\r\\n]+" || pattern == "[\r\n]+" {
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
  } else if pattern == "\\w+" || pattern == "\\b\\w+\\b" {
    Some(run_matches(chars, fn(c) { is_word_char(c) }))
  } else if pattern == "[\\w]+" || pattern == "[^\\W]+" {
    Some(run_matches(chars, fn(c) { is_word_char_class(c) }))
  } else if pattern == "[^\\w]+" || pattern == "[\\W]+" {
    Some(run_matches(chars, fn(c) { !is_word_char_class(c) }))
  } else if pattern == "[A-Za-z0-9_]+" {
    Some(run_matches(chars, fn(c) { is_ascii_word_char(c) }))
  } else if pattern == "\\b[A-Za-z0-9_]+\\b" {
    // \b boundaries use the UNICODE word set (bare table incl. quirks)
    Some(ascii_word_boundary_run_matches(chars))
  } else if pattern == "^\\w+" {
    Some(leading_run_match_multiline(chars, fn(c) { is_word_char(c) }))
  } else if pattern == "^[\\w]+" || pattern == "^[^\\W]+" {
    Some(leading_run_match_multiline(chars, fn(c) { is_word_char_class(c) }))
  } else if pattern == "^[^\\w]+" || pattern == "^[\\W]+" {
    Some(leading_run_match_multiline(chars, fn(c) { !is_word_char_class(c) }))
  } else if pattern == "^[A-Za-z0-9_]+" {
    Some(leading_run_match_multiline(chars, fn(c) { is_ascii_word_char(c) }))
  } else if pattern == "\\w+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { is_word_char(c) }))
  } else if pattern == "[\\w]+$" || pattern == "[^\\W]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { is_word_char_class(c) }))
  } else if pattern == "[^\\w]+$" || pattern == "[\\W]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { !is_word_char_class(c) }))
  } else if pattern == "[A-Za-z0-9_]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { is_ascii_word_char(c) }))
  } else if pattern == "\\W+" || pattern == "[^\\w]+" {
    Some(run_matches(chars, fn(c) { !is_word_char(c) }))
  } else if pattern == "[^A-Za-z0-9_]+" {
    Some(run_matches(chars, fn(c) { !is_ascii_word_char(c) }))
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
    Some(leading_run_match_multiline(chars, fn(c) { is_ascii_alnum(c) }))
  } else if pattern == "[A-Za-z0-9]+$" || pattern == "[a-zA-Z0-9]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { is_ascii_alnum(c) }))
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
    Some(leading_run_match_multiline(chars, fn(c) { is_ascii_letter(c) }))
  } else if pattern == "[A-Za-z]+$" || pattern == "[a-zA-Z]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { is_ascii_letter(c) }))
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
    Some(leading_run_match_multiline(chars, fn(c) { is_unicode_letter(c) }))
  } else if pattern == "\\p{L}+$" ||
    pattern == "\\p{Letter}+$" ||
    pattern == "[\\p{L}]+$" ||
    pattern == "[\\p{Letter}]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { is_unicode_letter(c) }))
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
    Some(
      leading_run_match_multiline(chars, fn(c) { is_unicode_punctuation(c) }),
    )
  } else if pattern == "\\p{P}+$" ||
    pattern == "\\p{Punctuation}+$" ||
    pattern == "[\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}]+$" {
    Some(
      trailing_run_match_multiline(chars, fn(c) { is_unicode_punctuation(c) }),
    )
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
    Some(leading_run_match_multiline(chars, fn(c) { is_unicode_symbol(c) }))
  } else if pattern == "\\p{S}+$" ||
    pattern == "\\p{Symbol}+$" ||
    pattern == "[\\p{S}]+$" ||
    pattern == "[\\p{Symbol}]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { is_unicode_symbol(c) }))
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
      leading_run_match_multiline(chars, fn(c) {
        is_unicode_punctuation_or_symbol(c)
      }),
    )
  } else if pattern == "[\\p{P}\\p{S}]+$" ||
    pattern == "[\\p{S}\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+$" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+$" {
    Some(
      trailing_run_match_multiline(chars, fn(c) {
        is_unicode_punctuation_or_symbol(c)
      }),
    )
  } else if pattern == "[^\\p{P}\\p{S}]+" ||
    pattern == "[^\\p{S}\\p{P}]+" ||
    pattern == "[^\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[^\\p{Symbol}\\p{Punctuation}]+" {
    Some(run_matches(chars, fn(c) { !is_unicode_punctuation_or_symbol(c) }))
  } else if pattern == "[^\\s\\p{L}\\p{N}]+" ||
    pattern == "[^\\s\\p{N}\\p{L}]+" ||
    pattern == "[^\\p{L}\\s\\p{N}]+" ||
    pattern == "[^\\p{L}\\p{N}\\s]+" ||
    pattern == "[^\\p{N}\\s\\p{L}]+" ||
    pattern == "[^\\p{N}\\p{L}\\s]+" ||
    pattern == "[^\\s\\p{Letter}\\p{Number}]+" ||
    pattern == "[^\\s\\p{Number}\\p{Letter}]+" ||
    pattern == "[^\\p{Letter}\\s\\p{Number}]+" ||
    pattern == "[^\\p{Letter}\\p{Number}\\s]+" ||
    pattern == "[^\\p{Number}\\s\\p{Letter}]+" ||
    pattern == "[^\\p{Number}\\p{Letter}\\s]+" {
    Some(run_matches(chars, fn(c) { is_not_whitespace_letter_or_number(c) }))
  } else if pattern == "\\d+" || pattern == "[\\d]+" {
    Some(run_matches(chars, fn(c) { is_decimal_number(c) }))
  } else if pattern == "\\p{N}+" ||
    pattern == "\\p{Number}+" ||
    pattern == "[\\p{N}]+" ||
    pattern == "[\\p{Number}]+" {
    Some(run_matches(chars, fn(c) { is_unicode_number(c) }))
  } else if pattern == "[0-9]+" {
    Some(run_matches(chars, fn(c) { c >= '0' && c <= '9' }))
  } else if pattern == "[^0-9]+" {
    Some(run_matches(chars, fn(c) { !(c >= '0' && c <= '9') }))
  } else if pattern == "^\\d+" || pattern == "^[\\d]+" {
    Some(leading_run_match_multiline(chars, fn(c) { is_decimal_number(c) }))
  } else if pattern == "^\\p{N}+" ||
    pattern == "^\\p{Number}+" ||
    pattern == "^[\\p{N}]+" ||
    pattern == "^[\\p{Number}]+" {
    Some(leading_run_match_multiline(chars, fn(c) { is_unicode_number(c) }))
  } else if pattern == "^[0-9]+" {
    Some(leading_run_match_multiline(chars, fn(c) { c >= '0' && c <= '9' }))
  } else if pattern == "\\d+$" || pattern == "[\\d]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { is_decimal_number(c) }))
  } else if pattern == "\\p{N}+$" ||
    pattern == "\\p{Number}+$" ||
    pattern == "[\\p{N}]+$" ||
    pattern == "[\\p{Number}]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { is_unicode_number(c) }))
  } else if pattern == "[0-9]+$" {
    Some(trailing_run_match_multiline(chars, fn(c) { c >= '0' && c <= '9' }))
  } else if pattern == "\\D+" ||
    pattern == "[\\D]+" ||
    pattern == "[^\\d]+" ||
    pattern == "[^0-9]+" {
    Some(run_matches(chars, fn(c) { !is_decimal_number(c) }))
  } else if pattern == "\\P{N}+" ||
    pattern == "\\P{Number}+" ||
    pattern == "[^\\p{N}]+" ||
    pattern == "[^\\p{Number}]+" {
    Some(run_matches(chars, fn(c) { !is_unicode_number(c) }))
  } else if pattern == "\\d{2,}" ||
    pattern == "[\\d]{2,}" ||
    pattern == "[0-9]{2,}" {
    Some(run_matches_min(chars, fn(c) { is_decimal_number(c) }, min_run=2))
  } else if pattern == "\\p{N}{2,}" ||
    pattern == "\\p{Number}{2,}" ||
    pattern == "[\\p{N}]{2,}" ||
    pattern == "[\\p{Number}]{2,}" {
    Some(run_matches_min(chars, fn(c) { is_unicode_number(c) }, min_run=2))
  } else if pattern == "\\d{2}" ||
    pattern == "[\\d]{2}" ||
    pattern == "[0-9]{2}" {
    Some(number_exact_matches(chars, exact_digits=2, pred=is_decimal_number))
  } else if pattern == "\\p{N}{2}" ||
    pattern == "\\p{Number}{2}" ||
    pattern == "[\\p{N}]{2}" ||
    pattern == "[\\p{Number}]{2}" {
    Some(number_exact_matches(chars, exact_digits=2, pred=is_unicode_number))
  } else if pattern == "\\d{3}" ||
    pattern == "[\\d]{3}" ||
    pattern == "[0-9]{3}" {
    Some(number_exact_matches(chars, exact_digits=3, pred=is_decimal_number))
  } else if pattern == "\\p{N}{3}" ||
    pattern == "\\p{Number}{3}" ||
    pattern == "[\\p{N}]{3}" ||
    pattern == "[\\p{Number}]{3}" {
    Some(number_exact_matches(chars, exact_digits=3, pred=is_unicode_number))
  } else if pattern == "\\d{4}" ||
    pattern == "[\\d]{4}" ||
    pattern == "[0-9]{4}" {
    Some(number_exact_matches(chars, exact_digits=4, pred=is_decimal_number))
  } else if pattern == "\\p{N}{4}" ||
    pattern == "\\p{Number}{4}" ||
    pattern == "[\\p{N}]{4}" ||
    pattern == "[\\p{Number}]{4}" {
    Some(number_exact_matches(chars, exact_digits=4, pred=is_unicode_number))
  } else if pattern == "\\d{1,2}" ||
    pattern == "[\\d]{1,2}" ||
    pattern == "[0-9]{1,2}" ||
    pattern == "[0-9][0-9]" {
    Some(number_run_matches(chars, max_digits=2, pred=is_decimal_number))
  } else if pattern == "\\p{N}{1,2}" ||
    pattern == "\\p{Number}{1,2}" ||
    pattern == "[\\p{N}]{1,2}" ||
    pattern == "[\\p{Number}]{1,2}" {
    Some(number_run_matches(chars, max_digits=2, pred=is_unicode_number))
  } else if pattern == "\\d{1,3}" ||
    pattern == "[\\d]{1,3}" ||
    pattern == "[0-9]{1,3}" ||
    pattern == "[0-9][0-9][0-9]" {
    Some(number_run_matches(chars, max_digits=3, pred=is_decimal_number))
  } else if pattern == "\\p{N}{1,3}" ||
    pattern == "\\p{Number}{1,3}" ||
    pattern == "[\\p{N}]{1,3}" ||
    pattern == "[\\p{Number}]{1,3}" {
    Some(number_run_matches(chars, max_digits=3, pred=is_unicode_number))
  } else if pattern == "\\d{1,4}" ||
    pattern == "[\\d]{1,4}" ||
    pattern == "[0-9]{1,4}" ||
    pattern == "[0-9][0-9][0-9][0-9]" {
    Some(number_run_matches(chars, max_digits=4, pred=is_decimal_number))
  } else if pattern == "\\p{N}{1,4}" ||
    pattern == "\\p{Number}{1,4}" ||
    pattern == "[\\p{N}]{1,4}" ||
    pattern == "[\\p{Number}]{1,4}" {
    Some(number_run_matches(chars, max_digits=4, pred=is_unicode_number))
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
          leading_run_match_multiline(chars, fn(c) {
            bounded_regex_kind_pred(kind, c)
          }),
        )
      } else {
        Some(
          trailing_run_match_multiline(chars, fn(c) {
            bounded_regex_kind_pred(kind, c)
          }),
        )
      }
    None => None
  }
}

///|

///|
pub extend Regex with @debug.Debug::{to_repr}

///|
pub extend Regex with Eq::{equal, not_equal}

///|
/// Exact-1 per-character spans (a bare class with no quantifier).
fn exact_one_matches(chars : Array[Char], pred : (Char) -> Bool) -> Array[Span] {
  let out : Array[Span] = []
  for i, c in chars {
    if pred(c) {
      out.push({ start: i, stop: i + 1, })
    }
  }
  out
}
