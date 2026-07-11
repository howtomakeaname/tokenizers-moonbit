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
  // ASCII digits
  (u >= 0x0030 && u <= 0x0039) ||
  // Arabic-Indic
  (u >= 0x0660 && u <= 0x0669) ||
  // Extended Arabic-Indic
  (u >= 0x06F0 && u <= 0x06F9) ||
  // Devanagari
  (u >= 0x0966 && u <= 0x096F) ||
  // Bengali
  (u >= 0x09E6 && u <= 0x09EF) ||
  // Gurmukhi
  (u >= 0x0A66 && u <= 0x0A6F) ||
  // Gujarati
  (u >= 0x0AE6 && u <= 0x0AEF) ||
  // Oriya
  (u >= 0x0B66 && u <= 0x0B6F) ||
  // Tamil
  (u >= 0x0BE6 && u <= 0x0BEF) ||
  // Telugu
  (u >= 0x0C66 && u <= 0x0C6F) ||
  // Kannada
  (u >= 0x0CE6 && u <= 0x0CEF) ||
  // Malayalam
  (u >= 0x0D66 && u <= 0x0D7F) ||
  // Thai
  (u >= 0x0E50 && u <= 0x0E59) ||
  // Lao
  (u >= 0x0ED0 && u <= 0x0ED9) ||
  // Tibetan
  (u >= 0x0F20 && u <= 0x0F29) ||
  // Myanmar
  (u >= 0x1040 && u <= 0x1049) ||
  // Khmer
  (u >= 0x17E0 && u <= 0x17E9) ||
  // Fullwidth
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
