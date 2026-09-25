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
/// Parse the single-character-literal bounded quantifier shape: `c{n}`,
/// `c{n,}`, `c{n,m}` where `c` is an ordinary literal char and
/// 1 <= n <= m <= 4. Returns (base char, lo, hi); `hi` = -1 for `{n,}`
/// (unbounded above). Returns None for any other shape.
/// HF probes: `a{2}` on "zaaz" -> "z#z", `a{2,3}` on "zaaaay" -> "z#ay",
/// `a{1}` on "zaaz" -> "z##z". Metacharacter bases are excluded:
/// `.{n}` is any-char in HF; `?{n}`/`+{n}`/etc. are construction errors.
pub fn char_bounded_spec(pattern : String) -> (Char, Int, Int)? {
  let chars = pattern.to_array()
  let n = chars.length()
  // shape: c { digits }  |  c { digits , }  |  c { digits , digits }
  // where c is an ordinary literal char or an escaped literal (\n \t
  // \r \\ \. — probed 0.22.2: `\\n{2}` on "z\n\nz" -> 'z#z').
  // Escaped bases skip the metachar exclusion: the escape makes them
  // literal (`. {n}` is any-char in HF, `\\.{2}` is a literal dot).
  // Plus tails: 'c+' == 'c{1,}' and the lazy 'c+?' == 'c{1}' (probed
  // 0.22.2: 'a+' on 'aaa' -> '#', 'a+?' -> '###').
  if chars[n - 1] == '+' ||
    (n >= 3 && chars[n - 1] == '?' && chars[n - 2] == '+') {
    let lazy_tail = chars[n - 1] == '?'
    let base_end = if lazy_tail { n - 2 } else { n - 1 }
    if base_end == 1 {
      let c = chars[0]
      let plain = c != '\\' &&
        c != '[' &&
        c != ']' &&
        c != '.' &&
        c != '^' &&
        c != '$' &&
        c != '*' &&
        c != '+' &&
        c != '?' &&
        c != '(' &&
        c != ')' &&
        c != '|' &&
        c != '{' &&
        c != '}'
      if plain {
        return Some((c, 1, if lazy_tail { 1 } else { -1 }))
      }
      return None
    }
    if base_end == 2 && chars[0] == '\\' {
      let c : Char? = match chars[1] {
        'n' => Some('\n')
        't' => Some('\t')
        'r' => Some('\r')
        '\\' => Some('\\')
        '.' => Some('.')
        // escaped literal plus ('\+{2}' on '+ ++ ' -> '+ # ',
        // probed); unknown-escape letters ride the shared helper
        '+' => Some('+')
        _ => escaped_letter_literal(chars[1])
      }
      match c {
        Some(x) => return Some((x, 1, if lazy_tail { 1 } else { -1 }))
        None => return None
      }
    }
    return None
  }
  if n < 4 || chars[n - 1] != '}' {
    return None
  }
  let mut c : Char = '\u{0}'
  let mut brace : Int = 0
  if chars[1] == '{' {
    c = chars[0]
    brace = 1
  } else if chars[0] == '\\' && n >= 5 && chars[2] == '{' {
    brace = 2
    c = match chars[1] {
      'n' => '\n'
      't' => '\t'
      'r' => '\r'
      '\\' => '\\'
      '.' => '.'
      '+' => '+'
      _ =>
        match escaped_letter_literal(chars[1]) {
          Some(x) => x
          None => return None
        }
    }
  } else {
    return None
  }
  if brace == 1 &&
    (
      c == '{' ||
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
      c == '|'
    ) {
    return None
  }
  let mut i = brace + 1
  let mut lo = 0
  let mut lo_digits = 0
  while i < n && chars[i] >= '0' && chars[i] <= '9' {
    lo = lo * 10 + (chars[i].to_int() - '0'.to_int())
    if lo > 100000 {
      return None
    }
    lo_digits = lo_digits + 1
    i = i + 1
  }
  // onig's real repeat bound is 100000 (probed: a{100000} loads,
  // a{100001} errors) — windows above 4 compute like any other
  if lo_digits == 0 || lo == 0 || lo > 100000 {
    return None
  }
  let mut hi = lo
  if i < n && chars[i] == ',' {
    i = i + 1
    if i == n - 1 {
      // {n,} — unbounded above; consume the whole run (HF-exact, matches
      // the sibling replace_min_char_runs handlers)
      hi = -1
    } else {
      let mut hi_digits = 0
      hi = 0
      while i < n && chars[i] >= '0' && chars[i] <= '9' {
        hi = hi * 10 + (chars[i].to_int() - '0'.to_int())
        if hi > 100000 {
          return None
        }
        hi_digits = hi_digits + 1
        i = i + 1
      }
      if hi_digits == 0 || hi > 100000 {
        return None
      }
      // reversed {n,m} with n > m: onig swaps the window (probed:
      // a{6,4} on 'zaaaaaaz' -> 'z#z' == the {4,6} blocks). A {n,0}
      // swap has EMPTY-MATCH insertion semantics this engine lacks —
      // reject (the anchored family's rule; probed: a{2,0} on 'zaaaz'
      // -> '#z##z#' in HF)
      if hi < lo {
        if hi == 0 {
          return None
        }
        let t = lo
        lo = hi
        hi = t
      }
    }
  } else if i != n - 1 {
    return None
  }
  Some((c, lo, hi))
}

///|
/// Single-character-literal bounded quantifier replace over greedy
/// bounded runs of the base char (see `char_bounded_spec`).
pub fn replace_char_bounded_runs(
  s : String,
  pattern : String,
  content : String,
) -> String? {
  match char_bounded_spec(pattern) {
    Some((c, lo, hi)) => {
      let src = s.to_array()
      Some(
        replace_spans(
          src,
          block_match_spans(src, fn(x) { x == c }, lo, hi),
          content,
        ),
      )
    }
    None => None
  }
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
  replace_spans(chars, zero_min_match_spans(chars, pred, max), content)
}

///|
/// Match spans for zero-minimum quantifiers, including EMPTY spans `(p, p)`
/// for empty matches (the adjacency rules above applied at emission time).
/// The empty span's char stays outside any span, so both span walkers —
/// `replace_spans` for text and the normalizer's aligned walker — copy it
/// between inserted contents, reproducing the probed outputs.
pub fn zero_min_match_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  max : Int?, // None = unbounded
) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  if n == 0 {
    return out
  }
  let cap = match max {
    Some(m) => m
    None => n
  }
  let mut p = 0
  let mut prev_end = -1
  while p <= n {
    if p == n {
      // end-of-string empty match only when not adjacent to prev end
      if p != prev_end {
        out.push({ start: p, stop: p, })
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
      out.push({ start: p, stop: g, })
      prev_end = g
      p = g
      continue
    }
    // empty match
    if p == prev_end {
      // skipped: no span, the walker copies the char as unmatched gap
      p = p + 1
      continue
    }
    out.push({ start: p, stop: p, })
    prev_end = p
    p = p + 1
  }
  out
}

///|
/// Greedy block spans over predicate runs, unifying the run families
/// (`replace_bounded_char_runs`, `replace_exact_char_runs`,
/// `replace_min_char_runs`, `replace_ranged_char_runs`, and the literal
/// `replace_char_bounded_runs`): within each maximal run, consecutive
/// blocks of up to `hi` chars (the whole run when `hi < 0`); a block
/// becomes a match span iff its length >= `lo`, leftover shorter blocks
/// stay unmatched.
fn block_match_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      while i < n && pred(chars[i]) {
        let start = i
        let limit = if hi < 0 { n } else { start + hi }
        while i < n && i < limit && pred(chars[i]) {
          i = i + 1
        }
        if i - start >= lo {
          out.push({ start, stop: i, })
        }
      }
    } else {
      i = i + 1
    }
  }
  out
}

///|
/// MULTILINE `^` + class-run match spans (`^\s+`): a match starts at a
/// line head (string start or after any `\n`) and extends greedily over
/// predicate chars, newlines included — span mirror of
/// `replace_line_leading_runs` (HF probes: "^\s+" on "\n\n  B" -> "#B",
/// on "A\n\n  B" -> "A\n#B").
fn line_leading_match_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
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
        out.push({ start: g, stop: j, })
        i = j
        at_line_head = i == 0 || chars[i - 1] == '\n'
        continue
      }
      at_line_head = false
      continue
    }
    if chars[i] == '\n' {
      at_line_head = true
    }
    i = i + 1
  }
  out
}

///|
/// MULTILINE `$` + class-run match spans (`\s+$`): the match is the
/// longest prefix of a greedy predicate run that ends at a line boundary
/// (right before a `\n` or at the string end); the newline is kept —
/// span mirror of `replace_line_trailing_runs` (HF probe:
/// "\s+$" on "x  \n\n  y" -> "x#\n  y" — match "  \n").
fn line_trailing_match_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
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
        out.push({ start, stop: j, })
        i = j
        continue
      }
      // no boundary-anchored match: the run stays unmatched
      i = g
      continue
    }
    i = i + 1
  }
  out
}

///|
/// Match spans for every regex family the replace chain implements,
/// mirroring the dispatch order of the normalizer's `replace_all`:
/// bounded / ranged / exact / min class quantifiers, MULTILINE anchored
/// class runs, single-char literal bounded quantifiers, zero-min
/// quantifiers (with EMPTY spans for empty matches), bare single-char
/// classes, and the simple split scanner families. Returns None when no
/// family claims the pattern — the literal-substring fallback applies.
pub fn replace_family_spans(
  chars : Array[Char],
  pattern : String,
) -> Array[Span]? {
  // lazy suffixes collapse to their greedy equivalents first (probed
  // 0.22.2 — see lazy_normalize); unsupported bounds fall through
  // untouched and fail explicitly downstream
  let pattern = match lazy_normalize(pattern) {
    Some(p) => p
    None => pattern
  }
  match lazy_exact_spec(pattern) {
    Some((kind, literal, lo, hi)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { bounded_regex_kind_pred(kind, x) }
      }
      return Some(lazy_ranged_or_empty_spans(chars, pred, lo, hi))
    }
    None => ()
  }
  // lazy-exact anchored (\ba{2}?, \w{2}?\b ...)
  match boundary_lazy_exact_spec(pattern) {
    Some((kind, literal, n, ws, we)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { bounded_regex_kind_pred(kind, x) }
      }
      return Some(boundary_lazy_exact_spans(chars, pred, n, ws, we))
    }
    None => ()
  }
  // single-anchor windows (^\w{1,2}, \w{1,2}$)
  match single_anchor_window_spec(pattern) {
    Some((kind, literal, lo, hi, leading)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { bounded_regex_kind_pred(kind, x) }
      }
      return Some(single_anchor_window_spans(chars, pred, lo, hi, leading))
    }
    None => ()
  }
  // non-boundary (\B) windows and lazy-exact
  match nonboundary_window_spec(pattern) {
    Some((kind, literal, lo, hi, ws, we)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { bounded_regex_kind_pred(kind, x) }
      }
      return Some(nonboundary_window_spans(chars, pred, lo, hi, ws, we))
    }
    None => ()
  }
  match nonboundary_lazy_exact_spec(pattern) {
    Some((kind, literal, n, ws, we)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { bounded_regex_kind_pred(kind, x) }
      }
      return Some(nonboundary_lazy_exact_spans(chars, pred, n, ws, we))
    }
    None => ()
  }
  // mixed-anchor (\bX{..}\B, \BX{..}\b) windows
  match mixed_anchor_window_spec(pattern) {
    Some((kind, literal, lo, hi, lead_nb, trail_nb)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { bounded_regex_kind_pred(kind, x) }
      }
      return Some(
        mixed_anchor_window_spans(chars, pred, lo, hi, lead_nb, trail_nb),
      )
    }
    None => ()
  }
  // general bracket sets ([abc], [a-c], [a\w], [^\w-] ... with an
  // optional quantifier)
  match bracket_set_spec(pattern) {
    Some((members, negated, lo, hi, lazy_group)) => {
      let pred = fn(c) { bracket_set_holds(members, negated, c) }
      if lazy_group {
        return Some(lazy_ranged_or_empty_spans(chars, pred, lo, hi))
      }
      if lo == 0 {
        return Some(
          zero_min_match_spans(
            chars,
            pred,
            if hi < 0 {
              None
            } else {
              Some(hi)
            },
          ),
        )
      }
      return Some(block_match_spans(chars, pred, lo, hi))
    }
    None => ()
  }
  // boundary-windowed quantifiers (\b\w{5}, \w{5}\b, \ba{2,4}\b)
  match boundary_window_spec(pattern) {
    Some((kind, literal, lo, hi, ws, we)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { bounded_regex_kind_pred(kind, x) }
      }
      return Some(boundary_window_spans(chars, pred, lo, hi, ws, we))
    }
    None => ()
  }
  // generic class windows (\w{5}, \d{4,6}, [\p{L}]{5,} ... — any
  // bound up to onig 100000) precede the hardcoded {1,2}/{1,3}/{1,4}
  // spelling tables, which they subsume for the plain forms
  match class_bounded_spec(pattern) {
    Some((kind, lo, hi)) =>
      return Some(
        block_match_spans(
          chars,
          fn(c) { bounded_regex_kind_pred(kind, c) },
          lo,
          hi,
        ),
      )
    None => ()
  }
  if pattern.contains("{") {
    match bounded_regex_kind(pattern) {
      Some((kind, max_run)) =>
        return Some(
          block_match_spans(
            chars,
            fn(c) { bounded_regex_kind_pred(kind, c) },
            1,
            max_run,
          ),
        )
      None => ()
    }
    match ranged_regex_kind(pattern) {
      Some((kind, min_run, max_run)) =>
        return Some(
          block_match_spans(
            chars,
            fn(c) { bounded_regex_kind_pred(kind, c) },
            min_run,
            max_run,
          ),
        )
      None => ()
    }
    match exact_regex_kind(pattern) {
      Some((kind, exact_run)) =>
        return Some(
          block_match_spans(
            chars,
            fn(c) { bounded_regex_kind_pred(kind, c) },
            exact_run,
            exact_run,
          ),
        )
      None => ()
    }
    match min_regex_kind(pattern) {
      Some((kind, min_run)) =>
        return Some(
          block_match_spans(
            chars,
            fn(c) { bounded_regex_kind_pred(kind, c) },
            min_run,
            -1,
          ),
        )
      None => ()
    }
  }
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
  if pattern.has_prefix("^") || pattern.has_suffix("$") {
    match anchored_regex_kind(pattern) {
      Some((kind, leading)) => {
        let pred = fn(c) { bounded_regex_kind_pred(kind, c) }
        if leading {
          return Some(line_leading_match_spans(chars, pred))
        }
        return Some(line_trailing_match_spans(chars, pred))
      }
      None => ()
    }
  }
  match char_bounded_spec(pattern) {
    Some((c, lo, hi)) =>
      return Some(block_match_spans(chars, fn(x) { x == c }, lo, hi))
    None => ()
  }
  match zero_min_quantifier_spec(pattern) {
    Some((kind, literal, max)) => {
      let pred : (Char) -> Bool = if kind == -1 {
        let c = literal.unwrap_or('\u{0}')
        fn(x) { x == c }
      } else {
        fn(x) { bounded_regex_kind_pred(kind, x) }
      }
      let m : Int? = if max < 0 { None } else { Some(max) }
      return Some(zero_min_match_spans(chars, pred, m))
    }
    None => ()
  }
  match bare_class_kind(pattern) {
    Some(kind) =>
      return Some(
        block_match_spans(
          chars,
          fn(c) { bounded_regex_kind_pred(kind, c) },
          1,
          1,
        ),
      )
    None => ()
  }
  simple_split_regex_matches(chars, pattern)
}

///|
/// `\b[A-Za-z0-9_]+\b` match spans: ASCII word runs whose neighbors are
/// NOT word characters, where word-ness is the Unicode `\w` set (bare
/// table incl. the onig quirks) — probed 0.22.2: 'a²b' has NO match
/// (² is a word char, so there is no boundary between a|²), 'x_1y'
/// matches whole, '¼ab½'/'²ab'/'aéb' none. Backtracking cannot rescue a
/// sub-run: every shorter sub-run still borders a word char.
fn ascii_word_boundary_run_matches(chars : Array[Char]) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    if is_ascii_word_char(chars[i]) {
      let start = i
      while i < n && is_ascii_word_char(chars[i]) {
        i = i + 1
      }
      let prev_word = start > 0 && is_word_char(chars[start - 1])
      let next_word = i < n && is_word_char(chars[i])
      if !prev_word && !next_word {
        out.push({ start, stop: i, })
      }
    } else {
      i = i + 1
    }
  }
  out
}

///|
/// `\b[A-Za-z0-9_]+\b` replace (normalizer/decoder hardcode path).
pub fn replace_ascii_word_boundary_runs(s : String, content : String) -> String {
  let chars = s.to_array()
  replace_spans(chars, ascii_word_boundary_run_matches(chars), content)
}

///|
/// LAZY exact `base{n}?` / reversed `base{n,m}?` match spans (probed
/// 0.22.2): greedy ranged blocks (each block takes min(hi, remaining)
/// while the remainder stays >= lo — the replace_ranged block rule)
/// followed by the zero-min empty-match walk for everything the blocks
/// do not consume. Fixed `{n}?` is the lo == hi case.
fn lazy_ranged_or_empty_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
) -> Array[Span] {
  // a REVERSED-bound swap can arrive with lo == 0 ('\w{2,0}?' ==
  // the {0,2} walk, probed: 'aaa' -> '##'); delegate — walking the
  // optional-group loop with lo == 0 would emit empty spans forever
  // (a hostile tokenizer.json could hang normalize)
  if lo <= 0 {
    return zero_min_match_spans(
      chars,
      pred,
      if hi < 0 {
        None
      } else {
        Some(hi)
      },
    )
  }
  let out : Array[Span] = []
  let len = chars.length()
  if len == 0 {
    return out
  }
  let mut p = 0
  let mut prev_end = -1
  while p <= len {
    if p == len {
      if p != prev_end {
        out.push({ start: p, stop: p, })
      }
      break
    }
    if pred(chars[p]) {
      let mut g = p
      while g < len && pred(chars[g]) {
        g = g + 1
      }
      if g - p >= lo {
        let mut b = p
        while g - b >= lo {
          let remaining = g - b
          let take = if hi < 0 || remaining < hi { remaining } else { hi }
          out.push({ start: b, stop: b + take, })
          prev_end = b + take
          b = b + take
        }
        // fall through to the empty walk from b: the sub-lo remainder
        // positions each get their empty-match attempt (probed: a{3}?
        // on 'aaaaa' -> '#a#a#' — first remainder position is skipped
        // as prev_end-adjacent, the rest fire empties)
        p = b
        continue
      }
    }
    if p == prev_end {
      p = p + 1
      continue
    }
    out.push({ start: p, stop: p, })
    prev_end = p
    p = p + 1
  }
  out
}

///|
/// LAZY exact `base{n}?` replace (normalizer/decoder hardcode path).
pub fn replace_lazy_exact_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
) -> String {
  let chars = s.to_array()
  replace_spans(chars, lazy_ranged_or_empty_spans(chars, pred, lo, hi), content)
}

///|
/// DOUBLE-anchored `^BASE QUANT $` match spans: from each line start
/// (string start or after '\n'), a greedy predicate run (which may
/// CROSS newlines when the class includes them — probed: `^\s+$` on
/// " \n " matches the WHOLE string) capped by hi, ending at the
/// LONGEST line-end boundary (before a '\n' or at the string end)
/// with length >= lo. No empty matches (the quantifier needs >= 1).
fn double_anchored_line_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  let mut p = 0
  while p < n {
    let at_line_start = p == 0 || chars[p - 1] == '\n'
    // zero-min window: an EMPTY line matches zero-width — but only
    // when the predicate EXCLUDES '\n' (otherwise the greedy scan
    // below spans the newlines: probed '^\s{0,}$' on '\n\n' -> '#'
    // one span, while '^a{0,2}$' -> '#\n#\n' per empty line); and
    // never at the string end (loop guard p < n)
    if at_line_start && lo == 0 && chars[p] == '\n' && (!pred('\n') || hi == 0) {
      out.push({ start: p, stop: p, })
      p = p + 1
      continue
    }
    if at_line_start && pred(chars[p]) {
      let mut g = p
      while g < n && pred(chars[g]) {
        g = g + 1
      }
      let cap = if hi < 0 { g - p } else if g - p < hi { g - p } else { hi }
      // longest L in [max(lo,1), cap] with p+L a line end
      let mut le = -1
      let mut len = cap
      while len >= lo && len >= 1 {
        let pos = p + len
        if pos == n || chars[pos] == '\n' {
          le = pos
          break
        }
        len = len - 1
      }
      if le > p {
        out.push({ start: p, stop: le, })
        p = le
        continue
      }
    }
    p = p + 1
  }
  out
}

///|
/// DOUBLE-anchored line replace (normalizer/decoder hardcode path).
pub fn replace_double_anchored_line_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
) -> String {
  let chars = s.to_array()
  replace_spans(chars, double_anchored_line_spans(chars, pred, lo, hi), content)
}

///|
/// Generic unanchored CLASS-quantifier spec: `BASE{n}`, `BASE{n,}`,
/// `BASE{n,m}` (leading zeros allowed; window 1..100000 = onig's real
/// bound, `{100001}` rejects; reversed n > m swaps like the literal
/// family, `{n,0}` rejects — empty-match semantics). BASE resolves via
/// bare_class_kind (\w, \d, [0-9], [\w], \p{N}, [\p{L}] ...). Replaces
/// the hardcoded {1,2}/{1,3}/{1,4} spelling tables for the plain
/// window forms; anchored/zero-min shapes keep their own parsers.
pub fn class_bounded_spec(pattern : String) -> (Int, Int, Int)? {
  let chars = pattern.to_array()
  let n = chars.length()
  // plus tail: 'CLASS+' == 'CLASS{1,}' greedy runs — also claims the
  // unanchored DOT '.+' (kind 30, '.' != '\n'; probed: '.+' on
  // 'a\nb' -> '#\n#'), matching the block engine
  if n >= 2 && chars[n - 1] == '+' {
    let base_sb = StringBuilder()
    for i in 0..<(n - 1) {
      base_sb.write_char(chars[i])
    }
    let base = base_sb.to_string()
    let kind : Int? = if base == "." {
      Some(30)
    } else {
      match bare_class_kind(base) {
        Some(k) => Some(k)
        None => None
      }
    }
    // the '+' must be a quantifier, not part of an escaped base
    match kind {
      Some(k) =>
        if !is_escaped_at(chars, n - 1) {
          return Some((k, 1, -1))
        } else {
          return None
        }
      None => ()
    }
    return None
  }
  // find the LAST '{' whose body closes at the end; base = everything
  // before it (must resolve as a bare class; a 1-char base is fine —
  // only the dot resolves, literals fall to bare_class_kind's None)
  let mut open = -1
  for i in 0..<n {
    if chars[i] == '{' {
      open = i
    }
  }
  if open < 1 || chars[n - 1] != '}' {
    return None
  }
  // base must be a bare class spelling — reject literal chars so the
  // literal family (char_bounded_spec) keeps owning them
  let base_sb = StringBuilder()
  for i in 0..<open {
    base_sb.write_char(chars[i])
  }
  let base = base_sb.to_string()
  // the unanchored DOT base rides the same window (kind 30, '.' !=
  // '\n'; probed: '.{2,}' == dot greedy runs)
  let base_kind : Int? = if base == "." {
    Some(30)
  } else {
    match bare_class_kind(base) {
      Some(k) => Some(k)
      None => None
    }
  }
  match base_kind {
    Some(kind) => {
      let inner : Array[Char] = []
      let mut k = open + 1
      while k < n - 1 {
        inner.push(chars[k])
        k = k + 1
      }
      let m = inner.length()
      match parse_capped_digits(inner, 0, m) {
        Some((v, j)) => {
          if j == m {
            if v < 1 || v > 100000 {
              return None
            }
            return Some((kind, v, v))
          }
          if inner[j] == ',' {
            if j + 1 == m {
              if v < 1 || v > 100000 {
                return None
              }
              return Some((kind, v, -1))
            }
            match parse_capped_digits(inner, j + 1, m) {
              Some((w, k2)) =>
                if k2 == m && v >= 1 && v <= 100000 && w <= 100000 {
                  if w < v {
                    if w == 0 {
                      return None // {n,0}: empty-match semantics
                    }
                    return Some((kind, w, v)) // reversed swap
                  }
                  return Some((kind, v, w))
                } else {
                  return None
                }
              None => return None
            }
          }
          None
        }
        None => None
      }
    }
    None => None
  }
}

///|
/// Generic class-window replace (block semantics identical to the
/// literal family).
pub fn replace_class_bounded_runs(
  s : String,
  pattern : String,
  content : String,
) -> String? {
  match class_bounded_spec(pattern) {
    Some((kind, lo, hi)) => {
      let chars = s.to_array()
      Some(
        replace_spans(
          chars,
          block_match_spans(
            chars,
            fn(c) { bounded_regex_kind_pred(kind, c) },
            lo,
            hi,
          ),
          content,
        ),
      )
    }
    None => None
  }
}

///|
/// Boundary-windowed block spans (probed 0.22.2): with an end `\b`
/// the block must END on a word boundary — since positions inside a
/// predicate run are never boundaries, the block spans the FULL
/// remaining run (len = run_end - pos) when it fits the window, and
/// the scan advances one char otherwise (leftmost non-overlapping,
/// '\w{5}\b' on the 6-word run 'zaaaaaaz' -> span (2,7) -> 'zaa#');
/// with only a start `\b` the block starts at a word boundary and
/// consumes greedily within the window; with both, only whole words
/// in the window match. Zero-min windows walk the empty rules with
/// every empty requiring its boundary predicates at the position.
fn boundary_window_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
  ws : Bool,
  we : Bool,
) -> Array[Span] {
  boundary_window_impl(chars, pred, lo, hi, ws, we, false)
}

///|
/// Shared engine: `invert` flips every word-boundary test to the
/// non-boundary (\B) predicate — probed 0.22.2: '\B\w{5}' on
/// 'zaaaaaz' -> 'z#z' (blocks start at NON-boundaries, mid-word);
/// zero-min \B walks the empty rules inverted ('\B\w{0}' on
/// 'zaaz' -> 'z#a#a#z').
fn boundary_window_impl(
  chars : Array[Char],
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
  ws : Bool,
  we : Bool,
  invert : Bool,
) -> Array[Span] {
  fn holds(pos : Int) -> Bool {
    if invert {
      !regex_word_boundary_at(chars, pos)
    } else {
      regex_word_boundary_at(chars, pos)
    }
  }
  let n = chars.length()
  if n == 0 {
    return []
  }
  if lo == 0 {
    // zero-min: reuse the empty-walk spans, boundary-filtered
    let base = zero_min_match_spans(
      chars,
      pred,
      if hi < 0 {
        None
      } else {
        Some(hi)
      },
    )
    let out : Array[Span] = []
    for sp in base {
      let ok = (!ws || holds(sp.start)) && (!we || holds(sp.stop))
      if ok {
        out.push(sp)
      }
    }
    return out
  }
  let out : Array[Span] = []
  let mut p = 0
  while p < n {
    if pred(chars[p]) {
      let start_ok = !ws || holds(p)
      if start_ok {
        let mut g = p
        while g < n && pred(chars[g]) {
          g = g + 1
        }
        if we {
          // greedy within the window, then shrink one char at a time
          // until the end position is a boundary. For uniform bases
          // the interior never holds \b, so this equals the historical
          // full-run check — but MIXED word-ness classes (\S, \D,
          // [^0-9] ...) hold \b at interior run positions and HF
          // backtracks exactly this way ('\b\S+\b' on 'a\nb, c' ->
          // '#\n#, #': the 'b,' run shrinks to 'b'; '\b\S{1,2}\b' on
          // 'ab,' -> '#,': the hi cap shrinks the run BEFORE the
          // boundary test)
          let mut len = if hi < 0 || g - p < hi { g - p } else { hi }
          while len >= lo && !holds(p + len) {
            len = len - 1
          }
          if len >= lo {
            out.push({ start: p, stop: p + len, })
            p = p + len
            continue
          }
        } else {
          let len = if hi < 0 || g - p < hi { g - p } else { hi }
          if len >= lo {
            out.push({ start: p, stop: p + len, })
            p = p + len
            continue
          }
        }
      }
    }
    p = p + 1
  }
  out
}

///|
/// Boundary-windowed replace (replace chains).
pub fn replace_boundary_window_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
  ws : Bool,
  we : Bool,
) -> String {
  let chars = s.to_array()
  replace_spans(
    chars,
    boundary_window_spans(chars, pred, lo, hi, ws, we),
    content,
  )
}

///|
/// Single-anchor window spans: at each line start (leading) a greedy
/// block from the anchor within the window; at each line end
/// (trailing) the block ENDS at the anchor — greedily the largest
/// len <= min(hi, run reaching the anchor) (probed: '\w{5}$' on
/// 'abcdefg' -> 'ab#'; '^a{2,4}' on 'zaaaa' -> unchanged, the anchor
/// pins the start and 'z' fails the pred).
fn single_anchor_window_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
  leading : Bool,
) -> Array[Span] {
  let n = chars.length()
  let out : Array[Span] = []
  if leading {
    let mut p = 0
    while p < n {
      let at_line_start = p == 0 || chars[p - 1] == '\n'
      if at_line_start && pred(chars[p]) {
        let mut g = p
        while g < n && pred(chars[g]) {
          g = g + 1
        }
        let len = if hi < 0 || g - p < hi { g - p } else { hi }
        if len >= lo {
          out.push({ start: p, stop: p + len, })
          p = p + len
          continue
        }
      }
      p = p + 1
    }
    return out
  }
  // trailing: the block ENDS at each line end i — greedily the
  // largest len <= min(hi, run reaching i) with start > floor (the
  // line start after the previous line end)
  let mut floor = 0
  let mut i = 0
  while i <= n {
    let at_line_end = i == n || chars[i] == '\n'
    if at_line_end {
      let cap = if hi < 0 { n } else { hi }
      let mut start = i
      while start > floor && pred(chars[start - 1]) && i - start < cap {
        start = start - 1
      }
      if i - start >= lo && start < i {
        out.push({ start, stop: i, })
        floor = i
      } else {
        floor = i + 1
      }
    }
    i = i + 1
  }
  out
}

///|
/// Single-anchor window replace (replace chains).
pub fn replace_single_anchor_window_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
  leading : Bool,
) -> String {
  let chars = s.to_array()
  replace_spans(
    chars,
    single_anchor_window_spans(chars, pred, lo, hi, leading),
    content,
  )
}

///|
/// Lazy-exact anchored spans (probed 0.22.2): at each position the
/// block attempt requires the START flags at p and the END flags at
/// p+n; on failure an EMPTY fires when the start flags hold at p and
/// p is not prev_end-adjacent. Leftmost non-overlapping walk.
fn boundary_lazy_exact_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  n : Int,
  ws : Bool,
  we : Bool,
) -> Array[Span] {
  let len = chars.length()
  let out : Array[Span] = []
  if len == 0 {
    return out
  }
  fn start_ok(p : Int) -> Bool {
    !ws || regex_word_boundary_at(chars, p)
  }
  fn end_ok(q : Int) -> Bool {
    !we || regex_word_boundary_at(chars, q)
  }
  let mut p = 0
  let mut prev_end = -1
  while p <= len {
    if p == len {
      if start_ok(p) && end_ok(p) && p != prev_end {
        out.push({ start: p, stop: p, })
      }
      break
    }
    // block attempt (p, p+n)
    let mut fits = p + n <= len
    if fits {
      let mut k = p
      while k < p + n {
        if !pred(chars[k]) {
          fits = false
          break
        }
        k = k + 1
      }
    }
    if fits && start_ok(p) && end_ok(p + n) {
      out.push({ start: p, stop: p + n, })
      prev_end = p + n
      p = p + n
      continue
    }
    if start_ok(p) && end_ok(p) && p != prev_end {
      out.push({ start: p, stop: p, })
      prev_end = p
      p = p + 1
      continue
    }
    p = p + 1
  }
  out
}

///|
/// Lazy-exact anchored replace (replace chains).
pub fn replace_boundary_lazy_exact_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  n : Int,
  ws : Bool,
  we : Bool,
) -> String {
  let chars = s.to_array()
  replace_spans(
    chars,
    boundary_lazy_exact_spans(chars, pred, n, ws, we),
    content,
  )
}

///|
/// Non-boundary (\B) window spans — leftmost-greedy scan (probed
/// 0.22.2): from each position a greedy block within the window; an
/// end \B backtracks the length down to lo until the end position is
/// a NON-boundary ('\w{5}\B' on 'zaaaaaz' -> (0,5) -> '#az'); a
/// start \B only filters scan positions ('\B\w{5}' -> 'z#z').
/// Zero-min walks the empty rules inverted ('\B\w{0}' on 'zaaz' ->
/// 'z#a#a#z', empties at 1 and 2).
pub fn nonboundary_window_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
  ws : Bool,
  we : Bool,
) -> Array[Span] {
  let n = chars.length()
  let out : Array[Span] = []
  if n == 0 {
    return out
  }
  fn holds(pos : Int) -> Bool {
    !regex_word_boundary_at(chars, pos)
  }
  if lo == 0 {
    let cap : Int? = if hi < 0 { None } else { Some(hi) }
    let base = zero_min_match_spans(chars, pred, cap)
    for sp in base {
      let ok = (!ws || holds(sp.start)) && (!we || holds(sp.stop))
      if ok {
        out.push(sp)
      }
    }
    return out
  }
  let mut p = 0
  while p < n {
    if pred(chars[p]) && (!ws || holds(p)) {
      let mut g = p
      while g < n && pred(chars[g]) {
        g = g + 1
      }
      let mut len = if hi < 0 || g - p < hi { g - p } else { hi }
      // end \B: shrink until the end position is a non-boundary
      while len >= lo && we && !holds(p + len) {
        len = len - 1
      }
      if len >= lo {
        out.push({ start: p, stop: p + len, })
        p = p + len
        continue
      }
    }
    p = p + 1
  }
  out
}

///|
/// Non-boundary (\\B) window replace.
pub fn replace_nonboundary_window_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
  ws : Bool,
  we : Bool,
) -> String {
  let chars = s.to_array()
  replace_spans(
    chars,
    nonboundary_window_spans(chars, pred, lo, hi, ws, we),
    content,
  )
}

///|
/// Mixed-anchor window spans: the start is gated by one anchor kind
/// (\b or \B), the block runs greedy capped by the window, then
/// shrinks one char at a time until the OTHER kind holds at the end
/// (probed: '\ba{2,4}\B' on 'aaaa' -> (0,3) — greedy 4 ends on the
/// EOS boundary, 3 lands on the interior non-boundary;
/// '\B\w{2,4}\b' on 'hello world' -> (1,5) where greedy held).
fn mixed_anchor_window_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
  lead_nb : Bool,
  trail_nb : Bool,
) -> Array[Span] {
  let n = chars.length()
  let out : Array[Span] = []
  if n == 0 {
    return out
  }
  fn lead_holds(pos : Int) -> Bool {
    if lead_nb {
      !regex_word_boundary_at(chars, pos)
    } else {
      regex_word_boundary_at(chars, pos)
    }
  }
  fn trail_holds(pos : Int) -> Bool {
    if trail_nb {
      !regex_word_boundary_at(chars, pos)
    } else {
      regex_word_boundary_at(chars, pos)
    }
  }
  let mut p = 0
  while p < n {
    if pred(chars[p]) && lead_holds(p) {
      let mut g = p
      while g < n && pred(chars[g]) {
        g = g + 1
      }
      let mut len = if hi < 0 || g - p < hi { g - p } else { hi }
      while len >= lo && !trail_holds(p + len) {
        len = len - 1
      }
      if len >= lo {
        out.push({ start: p, stop: p + len, })
        p = p + len
        continue
      }
    }
    p = p + 1
  }
  out
}

///|
/// General bracket-set replace: the composed per-char predicate over
/// block windows (unquantified == (1,1) per-char, '+': (1,-1) greedy
/// runs, braces exact/ranged — probed 0.22.2).
pub fn replace_bracket_set_runs(
  s : String,
  content : String,
  members : Array[BracketMember],
  negated : Bool,
  lo : Int,
  hi : Int,
  lazy_group? : Bool = false,
) -> String {
  let chars = s.to_array()
  let pred = fn(c) { bracket_set_holds(members, negated, c) }
  let spans = if lazy_group {
    lazy_ranged_or_empty_spans(chars, pred, lo, hi)
  } else if lo == 0 {
    zero_min_match_spans(chars, pred, if hi < 0 { None } else { Some(hi) })
  } else {
    block_match_spans(chars, pred, lo, hi)
  }
  replace_spans(chars, spans, content)
}

///|
/// Mixed-anchor (\\b + \\B) window replace.
pub fn replace_mixed_anchor_window_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  lo : Int,
  hi : Int,
  lead_nb : Bool,
  trail_nb : Bool,
) -> String {
  let chars = s.to_array()
  replace_spans(
    chars,
    mixed_anchor_window_spans(chars, pred, lo, hi, lead_nb, trail_nb),
    content,
  )
}

///|
/// Non-boundary lazy-exact spans (the optional-group walk with the
/// inverted predicate).
fn nonboundary_lazy_exact_spans(
  chars : Array[Char],
  pred : (Char) -> Bool,
  n : Int,
  ws : Bool,
  we : Bool,
) -> Array[Span] {
  // mirror boundary_lazy_exact_spans with inverted boundary checks
  let len = chars.length()
  let out : Array[Span] = []
  if len == 0 {
    return out
  }
  fn start_ok(p : Int) -> Bool {
    !ws || !regex_word_boundary_at(chars, p)
  }
  fn end_ok(q : Int) -> Bool {
    !we || !regex_word_boundary_at(chars, q)
  }
  let mut p = 0
  let mut prev_end = -1
  while p <= len {
    if p == len {
      if start_ok(p) && end_ok(p) && p != prev_end {
        out.push({ start: p, stop: p, })
      }
      break
    }
    let mut fits = p + n <= len
    if fits {
      let mut k = p
      while k < p + n {
        if !pred(chars[k]) {
          fits = false
          break
        }
        k = k + 1
      }
    }
    if fits && start_ok(p) && end_ok(p + n) {
      out.push({ start: p, stop: p + n, })
      prev_end = p + n
      p = p + n
      continue
    }
    if start_ok(p) && end_ok(p) && p != prev_end {
      out.push({ start: p, stop: p, })
      prev_end = p
      p = p + 1
      continue
    }
    p = p + 1
  }
  out
}

///|
/// Non-boundary lazy-exact replace.
pub fn replace_nonboundary_lazy_exact_runs(
  s : String,
  content : String,
  pred : (Char) -> Bool,
  n : Int,
  ws : Bool,
  we : Bool,
) -> String {
  let chars = s.to_array()
  replace_spans(
    chars,
    nonboundary_lazy_exact_spans(chars, pred, n, ws, we),
    content,
  )
}
