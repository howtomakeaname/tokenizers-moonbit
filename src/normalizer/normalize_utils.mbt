///|
fn strip_accents(s : String) -> String {
  // HF standalone StripAccents removes ALREADY-DECOMPOSED combining marks
  // only — precomposed characters are untouched (Python 0.22.2:
  // normalize_str("café") == "café", "cafe" + U+0301 == "cafe"). The
  // NFD-then-drop behavior belongs to BertNormalizer's strip_accents.
  let sb = StringBuilder()
  for c in s {
    if is_combining_mark(c.to_int()) {
      continue
    }
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// BertNormalizer strip_accents: NFD-then-drop-marks (precomposed é -> e),
/// also removing marks that were already decomposed.
fn bert_strip_accents(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    let cp = c.to_int()
    if is_combining_mark(cp) {
      continue
    }
    match accent_map().get(cp) {
      Some(stripped) => sb.write_string(stripped)
      None => sb.write_char(c)
    }
  }
  sb.to_string()
}

// HF StripAccents is NFD then drop Unicode category Mn. The precomputed
// `accent_map` covers precomposed characters such as é -> e. This predicate
// additionally drops already-decomposed combining marks, which is required when
// StripAccents follows NFKD in tokenizer.json (e.g. ALBERT).

///|
fn is_combining_mark(cp : Int) -> Bool {
  (cp >= 0x0300 && cp <= 0x036F) ||
  (cp >= 0x1AB0 && cp <= 0x1AFF) ||
  (cp >= 0x1DC0 && cp <= 0x1DFF) ||
  (cp >= 0x20D0 && cp <= 0x20FF) ||
  (cp >= 0xFE20 && cp <= 0xFE2F)
}

// Lazily-built map: code point -> accent-stripped form.

///|
let accent_map_cache : Ref[Map[Int, String]?] = { val: None, }

///|
fn accent_map() -> Map[Int, String] {
  match accent_map_cache.val {
    Some(m) => m
    None => {
      let m : Map[Int, String] = Map([])
      for e in accent_entries() {
        m[e.0] = e.1
      }
      accent_map_cache.val = Some(m)
      m
    }
  }
}

// BertNormalizer clean_text: drop control chars and 0xFFFD, map whitespace to
// a single space.

///|
fn bert_clean_text(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    let u = c.to_int()
    if u == 0 || u == 0xFFFD || is_control(c) {
      continue
    }
    if @common.is_ascii_whitespace(c) {
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

// BertNormalizer handle_chinese_chars: surround each CJK char with spaces.

///|
fn bert_pad_chinese(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    if is_chinese_char(c) {
      sb.write_char(' ')
      sb.write_char(c)
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn is_control(c : Char) -> Bool {
  // \t \n \r are treated as whitespace, not control, by BERT.
  if c == '\t' || c == '\n' || c == '\r' {
    return false
  }
  let u = c.to_int()
  (u >= 0 && u < 0x20) || u == 0x7F
}

///|
fn is_chinese_char(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x4E00 && u <= 0x9FFF) ||
  (u >= 0x3400 && u <= 0x4DBF) ||
  (u >= 0x20000 && u <= 0x2A6DF) ||
  (u >= 0xF900 && u <= 0xFAFF)
}

///|
fn to_lowercase(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    sb.write_char(c.to_ascii_lowercase())
  }
  sb.to_string()
}

///|
fn strip(s : String, left : Bool, right : Bool) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let mut start = 0
  let mut stop = n
  if left {
    while start < stop && @common.is_ascii_whitespace(chars[start]) {
      start = start + 1
    }
  }
  if right {
    while stop > start && @common.is_ascii_whitespace(chars[stop - 1]) {
      stop = stop - 1
    }
  }
  let sb = StringBuilder()
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

// Replacement for HF Replace. Common Regex patterns used by SPM tokenizers are
// handled explicitly; otherwise this falls back to literal substring replace.

///|
fn replace_all(s : String, pattern : String, content : String) -> String {
  if pattern.is_empty() {
    return s
  }
  // lazy suffixes collapse to greedy equivalents first (probed 0.22.2)
  let pattern = match @common.lazy_normalize(pattern) {
    Some(p) => p
    None => pattern
  }
  match @common.nonboundary_window_spec(pattern) {
    Some((kind, literal, lo, hi, ws, we)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { @common.bounded_regex_kind_pred(kind, x) }
      }
      return @common.replace_nonboundary_window_runs(
        s, content, pred, lo, hi, ws, we,
      )
    }
    None => ()
  }
  match @common.nonboundary_lazy_exact_spec(pattern) {
    Some((kind, literal, n, ws, we)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { @common.bounded_regex_kind_pred(kind, x) }
      }
      return @common.replace_nonboundary_lazy_exact_runs(
        s, content, pred, n, ws, we,
      )
    }
    None => ()
  }
  match @common.boundary_lazy_exact_spec(pattern) {
    Some((kind, literal, n, ws, we)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { @common.bounded_regex_kind_pred(kind, x) }
      }
      return @common.replace_boundary_lazy_exact_runs(
        s, content, pred, n, ws, we,
      )
    }
    None => ()
  }
  match @common.single_anchor_window_spec(pattern) {
    Some((kind, literal, lo, hi, leading)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { @common.bounded_regex_kind_pred(kind, x) }
      }
      return @common.replace_single_anchor_window_runs(
        s, content, pred, lo, hi, leading,
      )
    }
    None => ()
  }
  match @common.boundary_window_spec(pattern) {
    Some((kind, literal, lo, hi, ws, we)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { @common.bounded_regex_kind_pred(kind, x) }
      }
      return @common.replace_boundary_window_runs(
        s, content, pred, lo, hi, ws, we,
      )
    }
    None => ()
  }
  match @common.mixed_anchor_window_spec(pattern) {
    Some((kind, literal, lo, hi, lead_nb, trail_nb)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { @common.bounded_regex_kind_pred(kind, x) }
      }
      return @common.replace_mixed_anchor_window_runs(
        s, content, pred, lo, hi, lead_nb, trail_nb,
      )
    }
    None => ()
  }
  match @common.bracket_set_spec(pattern) {
    Some((members, negated, lo, hi, lazy_group)) =>
      return @common.replace_bracket_set_runs(
        s,
        content,
        members,
        negated,
        lo,
        hi,
        lazy_group~,
      )
    None => ()
  }
  match @common.lazy_exact_spec(pattern) {
    Some((kind, literal, lo, hi)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { @common.bounded_regex_kind_pred(kind, x) }
      }
      return @common.replace_lazy_exact_runs(s, content, pred, lo, hi)
    }
    None => ()
  }
  if pattern.contains("{") {
    match @common.replace_bounded_simple_regex(s, pattern, content) {
      Some(out) => return out
      None => ()
    }
    match @common.replace_ranged_simple_regex(s, pattern, content) {
      Some(out) => return out
      None => ()
    }
    match @common.exact_regex_kind(pattern) {
      Some((kind, exact_run)) =>
        return @common.replace_exact_char_runs(
          s,
          content,
          fn(c) { @common.bounded_regex_kind_pred(kind, c) },
          exact_run~,
        )
      None => ()
    }
    match @common.min_regex_kind(pattern) {
      Some((kind, min_run)) =>
        return @common.replace_min_char_runs(
          s,
          content,
          fn(c) { @common.bounded_regex_kind_pred(kind, c) },
          min_run~,
        )
      None => ()
    }
  }
  match @common.double_anchored_spec(pattern) {
    Some((kind, literal, lo, hi)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { @common.bounded_regex_kind_pred(kind, x) }
      }
      return @common.replace_double_anchored_line_runs(s, content, pred, lo, hi)
    }
    None => ()
  }
  if pattern.has_prefix("^") || pattern.has_suffix("$") {
    match @common.replace_anchored_simple_regex(s, pattern, content) {
      Some(out) => return out
      None => ()
    }
  }
  // single-char literal bounded quantifiers: a{2} / a{2,} / a{2,3}
  match @common.replace_char_bounded_runs(s, pattern, content) {
    Some(out) => return out
    None => ()
  }
  // zero-minimum quantifiers: a{0} / a{0,m} / a{0,} and class bases
  match @common.zero_min_quantifier_spec(pattern) {
    Some((kind, literal, max)) => {
      let lit = literal
      let pred : (Char) -> Bool = if kind == -1 {
        let c = lit.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { @common.bounded_regex_kind_pred(kind, x) }
      }
      let m = if max < 0 { None } else { Some(max) }
      return @common.replace_zero_min_runs(s, content, pred, m)
    }
    None => ()
  }
  match @common.bare_class_kind(pattern) {
    Some(kind) =>
      return @common.replace_exact_char_runs(
        s,
        content,
        fn(c) { @common.bounded_regex_kind_pred(kind, c) },
        exact_run=1,
      )
    None => ()
  }
  match @common.replace_simple_regex(s, pattern, content) {
    Some(out) => return out
    None => ()
  }
  if pattern == "\\s{2,}" || pattern == "[\\s]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=2,
    )
  }
  if pattern == "\\s{3,}" || pattern == "[\\s]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=3,
    )
  }
  if pattern == "\\s{4,}" || pattern == "[\\s]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=4,
    )
  }
  if pattern == "\\s{2}" || pattern == "[\\s]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      exact_run=2,
    )
  }
  if pattern == "\\s{3}" || pattern == "[\\s]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      exact_run=3,
    )
  }
  if pattern == "\\s{4}" || pattern == "[\\s]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      exact_run=4,
    )
  }
  if pattern == "^\\s+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  if pattern == "\\s+" {
    return @common.replace_whitespace_runs(s, content)
  }
  if pattern == "\\s+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  if pattern == "[\\r\\n]+" || pattern == "[\r\n]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      c == '\r' || c == '\n'
    })
  }
  if pattern == "[\\r\\n]{2,}" || pattern == "[\r\n]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      min_run=2,
    )
  }
  if pattern == "[\\r\\n]{3,}" || pattern == "[\r\n]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      min_run=3,
    )
  }
  if pattern == "[\\r\\n]{4,}" || pattern == "[\r\n]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      min_run=4,
    )
  }
  if pattern == "[\\r\\n]{2}" || pattern == "[\r\n]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      exact_run=2,
    )
  }
  if pattern == "[\\r\\n]{3}" || pattern == "[\r\n]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      exact_run=3,
    )
  }
  if pattern == "[\\r\\n]{4}" || pattern == "[\r\n]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      exact_run=4,
    )
  }
  if pattern == "\\d+" || pattern == "[\\d]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  // \p{N} spellings are FULL N (Nd + Nl + No; probed 0.22.2)
  if pattern == "\\p{N}+" ||
    pattern == "\\p{Number}+" ||
    pattern == "[\\p{N}]+" ||
    pattern == "[\\p{Number}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_number(c)
    })
  }
  // `[0-9]+` is ASCII-only (HF: fullwidth digits stay)
  if pattern == "[0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) { c >= '0' && c <= '9' })
  }
  if pattern == "[^0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !(c >= '0' && c <= '9')
    })
  }
  if pattern == "^\\d+" || pattern == "^[\\d]+" || pattern == "^[0-9]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "^\\p{N}+" ||
    pattern == "^\\p{Number}+" ||
    pattern == "^[\\p{N}]+" ||
    pattern == "^[\\p{Number}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_number(c)
    })
  }
  if pattern == "\\d+$" || pattern == "[\\d]+$" || pattern == "[0-9]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "\\p{N}+$" ||
    pattern == "\\p{Number}+$" ||
    pattern == "[\\p{N}]+$" ||
    pattern == "[\\p{Number}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_number(c)
    })
  }
  if pattern == "\\D+" ||
    pattern == "[\\D]+" ||
    pattern == "[^\\d]+" ||
    pattern == "[^0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_decimal_number(c)
    })
  }
  if pattern == "\\P{N}+" ||
    pattern == "\\P{Number}+" ||
    pattern == "[^\\p{N}]+" ||
    pattern == "[^\\p{Number}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_number(c)
    })
  }
  if pattern == "\\d{2,}" || pattern == "[\\d]{2,}" || pattern == "[0-9]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{N}{2,}" ||
    pattern == "\\p{Number}{2,}" ||
    pattern == "[\\p{N}]{2,}" ||
    pattern == "[\\p{Number}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_number(c) },
      min_run=2,
    )
  }
  if pattern == "\\d{2}" || pattern == "[\\d]{2}" || pattern == "[0-9]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{N}{2}" ||
    pattern == "\\p{Number}{2}" ||
    pattern == "[\\p{N}]{2}" ||
    pattern == "[\\p{Number}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_number(c) },
      exact_run=2,
    )
  }
  if pattern == "\\d{3}" || pattern == "[\\d]{3}" || pattern == "[0-9]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{N}{3}" ||
    pattern == "\\p{Number}{3}" ||
    pattern == "[\\p{N}]{3}" ||
    pattern == "[\\p{Number}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_number(c) },
      exact_run=3,
    )
  }
  if pattern == "\\d{4}" || pattern == "[\\d]{4}" || pattern == "[0-9]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      exact_run=4,
    )
  }
  if pattern == "\\p{N}{4}" ||
    pattern == "\\p{Number}{4}" ||
    pattern == "[\\p{N}]{4}" ||
    pattern == "[\\p{Number}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_number(c) },
      exact_run=4,
    )
  }
  if pattern == "\\d{1,3}" || pattern == "[\\d]{1,3}" || pattern == "[0-9]{1,3}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      max_run=3,
    )
  }
  if pattern == "\\p{N}{1,3}" ||
    pattern == "\\p{Number}{1,3}" ||
    pattern == "[\\p{N}]{1,3}" ||
    pattern == "[\\p{Number}]{1,3}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_number(c) },
      max_run=3,
    )
  }
  if pattern == "\\d{1,2}" || pattern == "[\\d]{1,2}" || pattern == "[0-9]{1,2}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      max_run=2,
    )
  }
  if pattern == "\\d{1,4}" || pattern == "[\\d]{1,4}" || pattern == "[0-9]{1,4}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      max_run=4,
    )
  }
  if pattern == "[ \\t]+" {
    return @common.replace_char_runs(s, content, fn(c) { c == ' ' || c == '\t' })
  }
  if pattern == "[ \\t]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      min_run=2,
    )
  }
  if pattern == "[ \\t]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      min_run=3,
    )
  }
  if pattern == "[ \\t]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      min_run=4,
    )
  }
  if pattern == "[ \\t]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      exact_run=2,
    )
  }
  if pattern == "[ \\t]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      exact_run=3,
    )
  }
  if pattern == "[ \\t]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      exact_run=4,
    )
  }
  if pattern == "\\w+" || pattern == "\\b\\w+\\b" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_word_char(c)
    })
  }
  // bracket \w is class-context (quirks excluded, probed)
  if pattern == "[\\w]+" || pattern == "[^\\W]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_word_char_class(c)
    })
  }
  if pattern == "[^\\w]+" || pattern == "[\\W]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_word_char_class(c)
    })
  }
  // `[A-Za-z0-9_]+` (and \b-wrapped) is ASCII-only (HF: é/中 stay)
  if pattern == "[A-Za-z0-9_]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_ascii_word_char(c)
    })
  }
  // \\b boundaries use the UNICODE word set (bare table incl. quirks;
  // probed 0.22.2: 'a²b' has no match)
  if pattern == "\\b[A-Za-z0-9_]+\\b" {
    return @common.replace_ascii_word_boundary_runs(s, content)
  }
  if pattern == "^\\w+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_word_char(c)
    })
  }
  if pattern == "^[\\w]+" || pattern == "^[^\\W]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_word_char_class(c)
    })
  }
  if pattern == "^[^\\w]+" || pattern == "^[\\W]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      !@common.is_word_char_class(c)
    })
  }
  if pattern == "^[A-Za-z0-9_]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_ascii_word_char(c)
    })
  }
  if pattern == "\\w+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_word_char(c)
    })
  }
  if pattern == "[\\w]+$" || pattern == "[^\\W]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_word_char_class(c)
    })
  }
  if pattern == "[^\\w]+$" || pattern == "[\\W]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      !@common.is_word_char_class(c)
    })
  }
  if pattern == "[A-Za-z0-9_]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_ascii_word_char(c)
    })
  }
  if pattern == "\\W+" || pattern == "[^\\w]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_word_char(c)
    })
  }
  if pattern == "[^A-Za-z0-9_]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_ascii_word_char(c)
    })
  }
  if pattern == "\\w{2,}" || pattern == "[A-Za-z0-9_]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      min_run=2,
    )
  }
  if pattern == "\\w{2}" || pattern == "[A-Za-z0-9_]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      exact_run=2,
    )
  }
  if pattern == "\\w{3}" || pattern == "[A-Za-z0-9_]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      exact_run=3,
    )
  }
  if pattern == "\\w{4}" || pattern == "[A-Za-z0-9_]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      exact_run=4,
    )
  }
  if pattern == "[A-Za-z0-9]+" || pattern == "[a-zA-Z0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
  }
  if pattern == "[A-Za-z0-9]{2,}" || pattern == "[a-zA-Z0-9]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      min_run=2,
    )
  }
  if pattern == "[A-Za-z0-9]{2}" || pattern == "[a-zA-Z0-9]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      exact_run=2,
    )
  }
  if pattern == "[A-Za-z0-9]{3}" || pattern == "[a-zA-Z0-9]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      exact_run=3,
    )
  }
  if pattern == "[A-Za-z0-9]{4}" || pattern == "[a-zA-Z0-9]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      exact_run=4,
    )
  }
  if pattern == "^[A-Za-z0-9]+" || pattern == "^[a-zA-Z0-9]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
  }
  if pattern == "[A-Za-z0-9]+$" || pattern == "[a-zA-Z0-9]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
  }
  if pattern == "[^A-Za-z0-9]+" || pattern == "[^a-zA-Z0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_ascii_alnum(c)
    })
  }
  if pattern == "[A-Za-z]+" || pattern == "[a-zA-Z]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_ascii_letter(c)
    })
  }
  if pattern == "[A-Za-z]{2,}" || pattern == "[a-zA-Z]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      min_run=2,
    )
  }
  if pattern == "[A-Za-z]{2}" || pattern == "[a-zA-Z]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      exact_run=2,
    )
  }
  if pattern == "[A-Za-z]{3}" || pattern == "[a-zA-Z]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      exact_run=3,
    )
  }
  if pattern == "[A-Za-z]{4}" || pattern == "[a-zA-Z]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      exact_run=4,
    )
  }
  if pattern == "^[A-Za-z]+" || pattern == "^[a-zA-Z]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_ascii_letter(c)
    })
  }
  if pattern == "[A-Za-z]+$" || pattern == "[a-zA-Z]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_ascii_letter(c)
    })
  }
  if pattern == "[^A-Za-z]+" || pattern == "[^a-zA-Z]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_ascii_letter(c)
    })
  }
  if pattern == "\\p{L}+" ||
    pattern == "\\p{Letter}+" ||
    pattern == "[\\p{L}]+" ||
    pattern == "[\\p{Letter}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_letter(c)
    })
  }
  if pattern == "\\p{L}{2,}" ||
    pattern == "\\p{Letter}{2,}" ||
    pattern == "[\\p{L}]{2,}" ||
    pattern == "[\\p{Letter}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{L}{2}" ||
    pattern == "\\p{Letter}{2}" ||
    pattern == "[\\p{L}]{2}" ||
    pattern == "[\\p{Letter}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{L}{3}" ||
    pattern == "\\p{Letter}{3}" ||
    pattern == "[\\p{L}]{3}" ||
    pattern == "[\\p{Letter}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{L}{4}" ||
    pattern == "\\p{Letter}{4}" ||
    pattern == "[\\p{L}]{4}" ||
    pattern == "[\\p{Letter}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      exact_run=4,
    )
  }
  if pattern == "^\\p{L}+" ||
    pattern == "^\\p{Letter}+" ||
    pattern == "^[\\p{L}]+" ||
    pattern == "^[\\p{Letter}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_letter(c)
    })
  }
  if pattern == "\\p{L}+$" ||
    pattern == "\\p{Letter}+$" ||
    pattern == "[\\p{L}]+$" ||
    pattern == "[\\p{Letter}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_letter(c)
    })
  }
  if pattern == "\\P{L}+" ||
    pattern == "\\P{Letter}+" ||
    pattern == "[^\\p{L}]+" ||
    pattern == "[^\\p{Letter}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_letter(c)
    })
  }
  if pattern == "\\p{P}+" ||
    pattern == "\\p{Punctuation}+" ||
    pattern == "[\\p{P}]+" ||
    pattern == "[\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\p{P}{2,}" ||
    pattern == "\\p{Punctuation}{2,}" ||
    pattern == "[\\p{P}]{2,}" ||
    pattern == "[\\p{Punctuation}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{P}{2}" ||
    pattern == "\\p{Punctuation}{2}" ||
    pattern == "[\\p{P}]{2}" ||
    pattern == "[\\p{Punctuation}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{P}{3}" ||
    pattern == "\\p{Punctuation}{3}" ||
    pattern == "[\\p{P}]{3}" ||
    pattern == "[\\p{Punctuation}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{P}{4}" ||
    pattern == "\\p{Punctuation}{4}" ||
    pattern == "[\\p{P}]{4}" ||
    pattern == "[\\p{Punctuation}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      exact_run=4,
    )
  }
  if pattern == "^\\p{P}+" ||
    pattern == "^\\p{Punctuation}+" ||
    pattern == "^[\\p{P}]+" ||
    pattern == "^[\\p{Punctuation}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\p{P}+$" ||
    pattern == "\\p{Punctuation}+$" ||
    pattern == "[\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\P{P}+" ||
    pattern == "\\P{Punctuation}+" ||
    pattern == "[^\\p{P}]+" ||
    pattern == "[^\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\p{S}+" ||
    pattern == "\\p{Symbol}+" ||
    pattern == "[\\p{S}]+" ||
    pattern == "[\\p{Symbol}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_symbol(c)
    })
  }
  if pattern == "\\p{S}{2,}" ||
    pattern == "\\p{Symbol}{2,}" ||
    pattern == "[\\p{S}]{2,}" ||
    pattern == "[\\p{Symbol}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{S}{2}" ||
    pattern == "\\p{Symbol}{2}" ||
    pattern == "[\\p{S}]{2}" ||
    pattern == "[\\p{Symbol}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{S}{3}" ||
    pattern == "\\p{Symbol}{3}" ||
    pattern == "[\\p{S}]{3}" ||
    pattern == "[\\p{Symbol}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{S}{4}" ||
    pattern == "\\p{Symbol}{4}" ||
    pattern == "[\\p{S}]{4}" ||
    pattern == "[\\p{Symbol}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      exact_run=4,
    )
  }
  if pattern == "^\\p{S}+" ||
    pattern == "^\\p{Symbol}+" ||
    pattern == "^[\\p{S}]+" ||
    pattern == "^[\\p{Symbol}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_symbol(c)
    })
  }
  if pattern == "\\p{S}+$" ||
    pattern == "\\p{Symbol}+$" ||
    pattern == "[\\p{S}]+$" ||
    pattern == "[\\p{Symbol}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_symbol(c)
    })
  }
  if pattern == "\\P{S}+" ||
    pattern == "\\P{Symbol}+" ||
    pattern == "[^\\p{S}]+" ||
    pattern == "[^\\p{Symbol}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_symbol(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]+" ||
    pattern == "[\\p{S}\\p{P}]+" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]{2,}" ||
    pattern == "[\\p{S}\\p{P}]{2,}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2,}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      min_run=2,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{2}" ||
    pattern == "[\\p{S}\\p{P}]{2}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      exact_run=2,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{3}" ||
    pattern == "[\\p{S}\\p{P}]{3}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{3}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      exact_run=3,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{4}" ||
    pattern == "[\\p{S}\\p{P}]{4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      exact_run=4,
    )
  }
  if pattern == "^[\\p{P}\\p{S}]+" ||
    pattern == "^[\\p{S}\\p{P}]+" ||
    pattern == "^[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "^[\\p{Symbol}\\p{Punctuation}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]+$" ||
    pattern == "[\\p{S}\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+$" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[^\\p{P}\\p{S}]+" ||
    pattern == "[^\\p{S}\\p{P}]+" ||
    pattern == "[^\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[^\\p{Symbol}\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[^\\s\\p{L}\\p{N}]+" ||
    pattern == "[^\\s\\p{N}\\p{L}]+" ||
    pattern == "[^\\p{L}\\p{N}\\s]+" ||
    pattern == "[^\\p{N}\\p{L}\\s]+" ||
    pattern == "[^\\s\\p{Letter}\\p{Number}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_not_whitespace_letter_or_number(c)
    })
  }
  if pattern == "[^\\S\\r\\n]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
    })
  }
  if pattern == "[^\\S\\r\\n]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      min_run=2,
    )
  }
  if pattern == "[^\\S\\r\\n]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      min_run=3,
    )
  }
  if pattern == "[^\\S\\r\\n]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      min_run=4,
    )
  }
  if pattern == "[^\\S\\r\\n]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      exact_run=2,
    )
  }
  if pattern == "[^\\S\\r\\n]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      exact_run=3,
    )
  }
  if pattern == "[^\\S\\r\\n]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      exact_run=4,
    )
  }
  @common.replace_literal(s, pattern, content)
}
