// Shared replacement helpers for the small Regex subset supported by
// Normalizer::Replace and Decoder::Replace. These functions deliberately work on
// Char arrays so offsets/behaviour stay identical across MoonBit backends.

///|
pub fn replace_literal(
  s : String,
  pattern : String,
  content : String,
) -> String {
  if pattern.is_empty() {
    return s
  }
  let pat = pattern.to_array()
  let src = s.to_array()
  let n = src.length()
  let m = pat.length()
  if m == 1 {
    return replace_char_literal(src, pat[0], content)
  }
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    if i + m <= n && matches_at(src, i, pat) {
      sb.write_string(content)
      i = i + m
    } else {
      sb.write_char(src[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
fn replace_char_literal(
  src : Array[Char],
  pattern : Char,
  content : String,
) -> String {
  let sb = StringBuilder()
  for c in src {
    if c == pattern {
      sb.write_string(content)
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
pub fn replace_leading_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n && pred(chars[i]) {
    i = i + 1
  }
  if i == 0 {
    return s
  }
  let sb = StringBuilder()
  sb.write_string(content)
  for k in i..<n {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

///|
pub fn replace_trailing_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let chars = s.to_array()
  let mut stop = chars.length()
  while stop > 0 && pred(chars[stop - 1]) {
    stop = stop - 1
  }
  if stop == chars.length() {
    return s
  }
  let sb = StringBuilder()
  for k in 0..<stop {
    sb.write_char(chars[k])
  }
  sb.write_string(content)
  sb.to_string()
}

///|
pub fn replace_char_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      while i < n && pred(chars[i]) {
        i = i + 1
      }
      sb.write_string(content)
    } else {
      sb.write_char(chars[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
pub fn replace_min_char_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  min_run~ : Int,
) -> String {
  if min_run <= 1 {
    return replace_char_runs(s, content, pred)
  }
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      while i < n && pred(chars[i]) {
        i = i + 1
      }
      let run = i - start
      if run >= min_run {
        sb.write_string(content)
      } else {
        for k in start..<i {
          sb.write_char(chars[k])
        }
      }
    } else {
      sb.write_char(chars[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
pub fn replace_bounded_char_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  max_run~ : Int,
) -> String {
  if max_run <= 0 {
    return s
  }
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let mut count = 0
      while i < n && pred(chars[i]) && count < max_run {
        i = i + 1
        count = count + 1
      }
      sb.write_string(content)
    } else {
      sb.write_char(chars[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
pub fn replace_exact_char_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  exact_run~ : Int,
) -> String {
  if exact_run <= 0 {
    return s
  }
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      while i < n && pred(chars[i]) {
        i = i + 1
      }
      let run = i - start
      let full = run / exact_run
      let rem = run % exact_run
      for _ in 0..<full {
        sb.write_string(content)
      }
      for k in (i - rem)..<i {
        sb.write_char(chars[k])
      }
    } else {
      sb.write_char(chars[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
pub fn replace_ranged_char_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  min_run~ : Int,
  max_run~ : Int,
) -> String {
  if min_run <= 1 {
    return replace_bounded_char_runs(s, content, pred, max_run~)
  }
  if max_run < min_run {
    return s
  }
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      while i < n && pred(chars[i]) {
        i = i + 1
      }
      let run = i - start
      let full = run / max_run
      let rem = run % max_run
      for _ in 0..<full {
        sb.write_string(content)
      }
      if rem >= min_run {
        sb.write_string(content)
      } else {
        for k in (i - rem)..<i {
          sb.write_char(chars[k])
        }
      }
    } else {
      sb.write_char(chars[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
pub fn replace_bounded_simple_regex(
  s : String,
  pattern : String,
  content : String,
) -> String? {
  match bounded_regex_kind(pattern) {
    Some((kind, max_run)) =>
      Some(
        replace_bounded_char_runs(
          s,
          content,
          fn(c) { bounded_regex_kind_pred(kind, c) },
          max_run~,
        ),
      )
    None => None
  }
}

///|
pub fn replace_ranged_simple_regex(
  s : String,
  pattern : String,
  content : String,
) -> String? {
  match ranged_regex_kind(pattern) {
    Some((kind, min_run, max_run)) =>
      Some(
        replace_ranged_char_runs(
          s,
          content,
          fn(c) { bounded_regex_kind_pred(kind, c) },
          min_run~,
          max_run~,
        ),
      )
    None => None
  }
}

///|
/// Replace every match of the shared simple Split regex subset. This keeps
/// Normalizer::Replace, Decoder::Replace and PreTokenizer::Split on the same
/// deterministic scanner instead of maintaining three separate regex tables.
pub fn replace_simple_regex(
  s : String,
  pattern : String,
  content : String,
) -> String? {
  let chars = s.to_array()
  match simple_split_regex_matches(chars, pattern) {
    Some(spans) => Some(replace_spans(chars, spans, content))
    None => None
  }
}

///|
fn replace_spans(
  chars : Array[Char],
  spans : Array[Span],
  content : String,
) -> String {
  if spans.length() == 0 {
    let sb = StringBuilder()
    for c in chars {
      sb.write_char(c)
    }
    return sb.to_string()
  }
  let sb = StringBuilder()
  let mut pos = 0
  for span in spans {
    if span.start < pos {
      continue
    }
    for i in pos..<span.start {
      sb.write_char(chars[i])
    }
    sb.write_string(content)
    pos = span.stop
  }
  for i in pos..<chars.length() {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
pub fn replace_anchored_simple_regex(
  s : String,
  pattern : String,
  content : String,
) -> String? {
  match anchored_regex_kind(pattern) {
    Some((kind, leading)) =>
      if leading {
        // HF/onig `^` is MULTILINE: the anchor matches at the string start
        // AND after every \n / \r\n boundary (probed 0.22.2:
        // "^\s+" on "\tA\n  B\nC" -> "#A\n#B\nC").
        Some(
          replace_line_leading_runs(s, content, fn(c) {
            bounded_regex_kind_pred(kind, c)
          }),
        )
      } else {
        // `$` matches before every \n and at the string end; the newline
        // itself is kept ("\s+$" on "x\t\n56\r\n78" keeps the \n).
        Some(
          replace_line_trailing_runs(s, content, fn(c) {
            bounded_regex_kind_pred(kind, c)
          }),
        )
      }
    None => None
  }
}

///|
/// MULTILINE `^` + class-run (e.g. `^\s+`): a match starts at a line head
/// (string start or after any `\n`) and extends greedily over predicate
/// chars, newlines included; one non-overlapping replacement per match
/// (HF probes: "^\s+" on "\n\n  B" -> "#B", on "A\n\n  B" -> "A\n#B").
fn replace_line_leading_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  let mut at_line_head = true
  while i < n {
    if at_line_head {
      let g = i
      let mut j = i
      while j < n && pred(chars[j]) {
        j = j + 1
      }
      if j > g {
        sb.write_string(content)
        i = j
        at_line_head = false // consumed chars decide; recompute below
        at_line_head = i == 0 || chars[i - 1] == '\n'
        continue
      }
      at_line_head = false
      continue
    }
    sb.write_char(chars[i])
    if chars[i] == '\n' {
      at_line_head = true
    }
    i = i + 1
  }
  sb.to_string()
}

///|
/// MULTILINE `$` + class-run (e.g. `\s+$`): the match is the longest
/// prefix of a greedy predicate run that ends at a line boundary (right
/// before a `\n` or at the string end); the newline is kept
/// (HF probes: "\s+$" on "x  \n\n  y" -> "x#\n  y" — match "  \n").
fn replace_line_trailing_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      let mut g = i
      while g < n && pred(chars[g]) {
        g = g + 1
      }
      // longest j in (start, g] with boundary at j
      let mut j = -1
      if g == n {
        j = g
      } else {
        // scan back for the nearest '\n' inside (start, g]
        let mut k = g
        while k > start {
          if chars[k] == '\n' {
            j = k
            break
          }
          k = k - 1
        }
      }
      if j > start {
        sb.write_string(content)
        i = j
        continue
      }
      // no boundary-anchored match: copy the run verbatim, continue after
      for t in start..<g {
        sb.write_char(chars[t])
      }
      i = g
      continue
    }
    sb.write_char(chars[i])
    i = i + 1
  }
  sb.to_string()
}

///|
pub fn replace_space_runs(
  s : String,
  content : String,
  min_run~ : Int,
) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    if chars[i] == ' ' {
      let start = i
      while i < n && chars[i] == ' ' {
        i = i + 1
      }
      let run = i - start
      if run >= min_run {
        sb.write_string(content)
      } else {
        for _ in 0..<run {
          sb.write_char(' ')
        }
      }
    } else {
      sb.write_char(chars[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
pub fn replace_whitespace_runs(s : String, content : String) -> String {
  replace_char_runs(s, content, fn(c) { is_unicode_whitespace(c.to_int()) })
}

///|
fn matches_at(src : Array[Char], at : Int, pat : Array[Char]) -> Bool {
  for k in 0..<pat.length() {
    if src[at + k] != pat[k] {
      return false
    }
  }
  true
}

///|
/// Single-character-literal bounded quantifier: `c{n}`, `c{n,}`, `c{n,m}`
/// where `c` is an ordinary literal char and 1 <= n <= m <= 4. Greedy
/// bounded runs of `c` are replaced (HF probes: `a{2}` on "zaaz" -> "z#z",
/// `a{2,3}` on "zaaaay" -> "z#ay", `a{1}` on "zaaz" -> "z##z").
/// Returns None unless the pattern has exactly this shape.
pub fn replace_char_bounded_runs(
  s : String,
  pattern : String,
  content : String,
) -> String? {
  let chars = pattern.to_array()
  let n = chars.length()
  // shape: c { digits }  |  c { digits , }  |  c { digits , digits }
  if n < 4 || chars[1] != '{' || chars[n - 1] != '}' {
    return None
  }
  let c = chars[0]
  // metacharacter bases excluded (mirrors char_bounded_quantifier_shape):
  // `.{n}` is any-char in HF; `?{n}`/`+{n}`/etc. are construction errors
  if c == '{' ||
    c == '}' ||
    c == '\\' ||
    c == '[' ||
    c == ']' ||
    c == '.' ||
    c == '^' ||
    c == '$' ||
    c == '*' ||
    c == '+' ||
    c == '?' ||
    c == '(' ||
    c == ')' ||
    c == '|' {
    return None
  }
  let mut i = 2
  let mut lo = 0
  let mut lo_digits = 0
  while i < n && chars[i] >= '0' && chars[i] <= '9' {
    lo = lo * 10 + (chars[i].to_int() - '0'.to_int())
    lo_digits = lo_digits + 1
    i = i + 1
  }
  if lo_digits == 0 || lo == 0 || lo > 4 {
    return None
  }
  let mut hi = lo
  if i < n && chars[i] == ',' {
    i = i + 1
    if i == n - 1 {
      // {n,} — unbounded above; consume the whole run (HF-exact, matches
      // the sibling replace_min_char_runs handlers)
      hi = 1_000_000_000
    } else {
      let mut hi_digits = 0
      hi = 0
      while i < n && chars[i] >= '0' && chars[i] <= '9' {
        hi = hi * 10 + (chars[i].to_int() - '0'.to_int())
        hi_digits = hi_digits + 1
        i = i + 1
      }
      if hi_digits == 0 || hi < lo || hi > 4 {
        return None
      }
      ignore(hi)
    }
  } else if i != n - 1 {
    return None
  }
  // greedy bounded runs over s
  let src = s.to_array()
  let m = src.length()
  let sb = StringBuilder()
  let mut j = 0
  while j < m {
    if src[j] == c {
      let start = j
      while j < m && src[j] == c && j - start < hi {
        j = j + 1
      }
      let len = j - start
      if len >= lo {
        sb.write_string(content)
      } else {
        for k in start..<j {
          sb.write_char(src[k])
        }
      }
    } else {
      sb.write_char(src[j])
      j = j + 1
    }
  }
  Some(sb.to_string())
}

///|
/// Zero-minimum bounded quantifier replace (`c{0}`, `c{0,m}`, `c{0,}`, and
/// class bases like `\\d{0,2}`): HF/onig global-replace semantics derived
/// from probes (13-case trace battery):
///   - greedy match up to `max` (unbounded when `max` is None)
///   - an EMPTY match at the position where the previous match ended is
///     SKIPPED (copy one char, advance, no insert)
///   - an inserted empty match copies one char and advances; the "previous
///     end" becomes the empty match's own position
///   - an empty match at end-of-string inserts only when its position
///     differs from the previous match end
///   - the empty input string produces no matches at all
pub fn replace_zero_min_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  max : Int?, // None = unbounded
) -> String {
  let chars = s.to_array()
  let n = chars.length()
  if n == 0 {
    return s
  }
  let cap = match max {
    Some(m) => m
    None => n
  }
  let sb = StringBuilder()
  let mut p = 0
  let mut prev_end = -1
  while p <= n {
    if p == n {
      // end-of-string empty match only when not adjacent to prev end
      if p != prev_end {
        sb.write_string(content)
      }
      break
    }
    // greedy bounded run at p
    let mut g = p
    while g < n && g - p < cap && pred(chars[g]) {
      g = g + 1
    }
    if g > p {
      // non-empty match
      sb.write_string(content)
      prev_end = g
      p = g
      continue
    }
    // empty match
    if p == prev_end {
      // skipped: copy one char, advance, no insert
      sb.write_char(chars[p])
      p = p + 1
      continue
    }
    sb.write_string(content)
    sb.write_char(chars[p])
    prev_end = p
    p = p + 1
  }
  sb.to_string()
}
