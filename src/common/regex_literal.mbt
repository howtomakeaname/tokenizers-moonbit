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
      out.push({ start: i, stop: i + m, })
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
  let sb = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    // A brace that is not part of a valid quantifier `{n}` / `{n,}` /
    // `{n,m}` is a literal character (onig semantics); quantified patterns
    // never reach the literal scanner, so raw braces here are literal.
    if c == '{' || c == '}' {
      if !at_quantifier_brace(chars, i) {
        sb.write_char(c)
        i = i + 1
        continue
      }
      return None
    }
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
  let sb = StringBuilder()
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
        out.push({ start: i, stop: i + m, })
        i = i + m
      }
      None => i = i + 1
    }
  }
  out
}

///|
/// MULTILINE anchored literal matching (probed 0.22.2): `^lit` matches
/// at every line start, `lit$` ending at every line end, `^lit$` from a
/// line start to a line end — literals CONTAINING newlines may span
/// lines (a\nb$ on "xa\nb" -> "x#"; \n\n$ collapses a trailing blank
/// line). `lit$` alternations pick the LEFTMOST start (longest
/// alternative first at the leftmost start, declaration order at
/// ties — (?:b|ab)$ on 'ab' matches [0,2)). \r belongs to its line.
/// Matches never overlap
/// (a match shadows the line starts/ends it covers).
fn literal_alternation_matches_anchored(
  chars : Array[Char],
  pats : Array[Array[Char]],
  anchored_start~ : Bool,
  anchored_end~ : Bool,
  word_start~ : Bool,
  word_end~ : Bool,
) -> Array[Span] {
  let n = chars.length()
  let is_line_end = fn(e : Int) -> Bool { e == n || chars[e] == '\n' }
  let out : Array[Span] = []
  if anchored_start && anchored_end {
    // from each line start, the literal must end exactly at A line end
    // — any line end, so literals containing newlines span lines
    let mut last_end = 0
    let mut ls = 0
    let mut i = 0
    while i <= n {
      let at_line_start = i == ls
      if at_line_start && ls >= last_end && ls < n {
        for pat in pats {
          let m = pat.length()
          let le = ls + m
          if m > 0 &&
            le <= n &&
            (le == n || chars[le] == '\n') &&
            chars_match_at(chars, ls, pat) &&
            literal_word_boundaries_match(chars, ls, le, word_start, word_end) {
            out.push({ start: ls, stop: le, })
            last_end = le
            break
          }
        }
      }
      if i == n {
        break
      }
      if chars[i] == '\n' {
        ls = i + 1
      }
      i = i + 1
    }
    return out
  }
  if anchored_start {
    let mut last_end = 0
    let mut ls = 0
    let mut i = 0
    while i <= n {
      let at_line_start = i == ls
      if at_line_start && ls >= last_end && ls < n {
        for pat in pats {
          let m = pat.length()
          if m > 0 &&
            ls + m <= n &&
            chars_match_at(chars, ls, pat) &&
            literal_word_boundaries_match(
              chars,
              ls,
              ls + m,
              word_start,
              word_end,
            ) {
            out.push({ start: ls, stop: ls + m, })
            last_end = ls + m
            break
          }
        }
      }
      if i == n {
        break
      }
      if chars[i] == '\n' {
        ls = i + 1
      }
      i = i + 1
    }
    return out
  }
  // anchored_end: onig picks the LEFTMOST START, ties broken by
  // DECLARATION order (probed both ways: (?:\n\n|\n)$ on 'a\n\n' ->
  // 'a#' taking the first-listed spanning alt; the reversed
  // declaration gives 'a##'). Scan starts ascending, alternatives in
  // declaration order, requiring the end to be a line end.
  let mut last_end = 0
  let mut st = 0
  while st <= n {
    if st >= last_end {
      for pat in pats {
        let m = pat.length()
        let e = st + m
        if m > 0 &&
          e <= n &&
          is_line_end(e) &&
          chars_match_at(chars, st, pat) &&
          literal_word_boundaries_match(chars, st, e, word_start, word_end) {
          out.push({ start: st, stop: e, })
          last_end = e
          break
        }
      }
    }
    st = st + 1
  }
  out
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

///|
/// Unicode `\d` test (Nd): binary search over the empirically generated
/// `decimal_ranges` (probed against 0.22.2 — includes Unicode-14+
/// additions such as U+1FBF0 MATHEMATICAL SANS-SERIF DIGIT ZERO that
/// the previous hard-coded interval list missed; stays Nd-only,
/// distinct from the full-N `is_unicode_number` of `\p{N}` spellings).
pub fn is_decimal_number(c : Char) -> Bool {
  let u = c.to_int()
  let mut lo = 0
  let mut hi = decimal_ranges.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let (start, stop) = decimal_ranges[mid]
    if u < start {
      hi = mid - 1
    } else if u > stop {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
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
      out.push({ start, stop: i, })
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
        out.push({ start, stop: i, })
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
        out.push({ start: j, stop: j + exact_run, })
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
      out.push({ start, stop: i, })
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
        out.push({ start: j, stop: j + take, })
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
fn number_run_matches(
  chars : Array[Char],
  max_digits~ : Int,
  pred~ : (Char) -> Bool,
) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      let mut count = 0
      while i < n && pred(chars[i]) && count < max_digits {
        i = i + 1
        count = count + 1
      }
      out.push({ start, stop: i, })
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
  pred~ : (Char) -> Bool,
) -> Array[Span] {
  let out : Array[Span] = []
  if exact_digits <= 0 {
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
      let full_stop = start + run / exact_digits * exact_digits
      let mut j = start
      while j < full_stop {
        out.push({ start: j, stop: j + exact_digits, })
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

///|
/// Whether the `{` at `i` begins a valid quantifier `{n}` / `{n,}` /
/// `{n,m}` (a `}` alone can never begin one).
fn at_quantifier_brace(chars : Array[Char], i : Int) -> Bool {
  if chars[i] != '{' {
    return false
  }
  let n = chars.length()
  let mut j = i + 1
  let mut digits = 0
  while j < n && chars[j] >= '0' && chars[j] <= '9' {
    j = j + 1
    digits = digits + 1
  }
  if digits == 0 {
    // `{,n}` is a quantifier in onig (== {0,n}); `{,}` with no digits is
    // NOT one — probed 0.22.2: 'a{,}' is a literal ('xa{,}x' -> 'x#x')
    if j < n && chars[j] == ',' {
      let mut m = j + 1
      while m < n && chars[m] >= '0' && chars[m] <= '9' {
        m = m + 1
      }
      if m > j + 1 && m < n && chars[m] == '}' {
        return true
      }
    }
    return false
  }
  if j < n && chars[j] == '}' {
    return true // {n}
  }
  if j < n && chars[j] == ',' {
    j = j + 1
    let mut digits2 = 0
    while j < n && chars[j] >= '0' && chars[j] <= '9' {
      j = j + 1
      digits2 = digits2 + 1
    }
    if j < n && chars[j] == '}' {
      return true // {n,} or {n,m}
    }
  }
  false
}

///|
/// MULTILINE `^` + class-run spans (onig): a match starts at a line head
/// (string start or after any `\n`) and extends greedily over predicate
/// chars, newlines included. HF Split probes: "^\\s+" style on
/// "A\n\nB" splits at the line head after A.
fn leading_run_match_multiline(
  chars : Array[Char],
  pred : (Char) -> Bool,
) -> Array[Span] {
  let out : Array[Span] = []
  let n = chars.length()
  let mut i = 0
  let mut at_line_head = true
  while i < n {
    if at_line_head {
      let start = i
      while i < n && pred(chars[i]) {
        i = i + 1
      }
      if i > start {
        out.push({ start, stop: i, })
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
/// MULTILINE `$` + class-run spans: the match is the longest prefix of a
/// greedy predicate run ending at a line boundary (before any `\n` or at
/// the string end), mirroring replace_line_trailing_runs.
fn trailing_run_match_multiline(
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
      let mut j = -1
      if g == n {
        j = g
      } else {
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
      i = g
      continue
    }
    i = i + 1
  }
  out
}

///|
/// PER-BRANCH anchored alternation `^foo|bar$` (no group wrapper —
/// onig binds anchors to their branch: (^foo)|(bar$); probed 0.22.2:
/// on 'foo\nfoobar' -> '#\n##'). Each branch strips its own unescaped
/// leading '^' / trailing '$' and must be a pure literal. Returns
/// (literal, start_anchor, end_anchor) per branch.
fn regex_literal_branch_alternatives_spec(
  pattern : String,
) -> (Array[(String, Bool, Bool)], Bool, Bool)? {
  let chars = pattern.to_array()
  let n = chars.length()
  if n == 0 {
    return None
  }
  // a TOP-LEVEL pipe selects the per-branch reading (a single outer
  // group wrapper like ^(?:foo|bar)$ has none — it keeps the grouped
  // global-anchor path). Depth tracking so inner groups don't count.
  let mut depth = 0
  let mut has_top_pipe = false
  let mut i = 0
  while i < n {
    if chars[i] == '\\' {
      i = i + 2 // skip the escaped char too (a '\\(' is not a group)
      continue
    }
    if chars[i] == '(' {
      depth = depth + 1
    } else if chars[i] == ')' && depth > 0 {
      depth = depth - 1
    } else if chars[i] == '|' && depth == 0 {
      has_top_pipe = true
      break
    }
    i = i + 1
  }
  if !has_top_pipe {
    return None
  }
  let word_start = n > 2 && chars[0] == '\\' && chars[1] == 'b'
  let word_end = n > 2 && chars[n - 1] == 'b' && chars[n - 2] == '\\'
  let lo = if word_start { 2 } else { 0 }
  let hi = if word_end { n - 2 } else { n }
  if lo >= hi {
    return None
  }
  // split top-level unescaped '|' into segments, then parse each
  let branches : Array[(String, Bool, Bool)] = []
  let mut seg_lo = lo
  let mut i = lo
  while i <= hi {
    if i == hi || (chars[i] == '|' && !is_escaped_at(chars, i)) {
      // segment [seg_lo, i)
      let mut s = seg_lo
      let mut e = i
      if s >= e {
        return None
      }
      // strip an optional (?:...) wrapper around the branch
      if e - s > 4 &&
        chars[s] == '(' &&
        chars[s + 1] == '?' &&
        chars[s + 2] == ':' &&
        chars[e - 1] == ')' {
        s = s + 3
        e = e - 1
      }
      let b_start = chars[s] == '^' && !is_escaped_at(chars, s)
      if b_start {
        s = s + 1
      }
      let b_end = chars[e - 1] == '$' && !is_escaped_at(chars, e - 1)
      if b_end {
        e = e - 1
      }
      if s >= e {
        return None
      }
      // parse the literal body [s, e)
      let lit : Array[Char] = []
      let mut k = s
      while k < e {
        let c = chars[k]
        if c == '\\' {
          if k + 1 >= e {
            return None
          }
          let nx = chars[k + 1]
          if is_regex_escaped_literal(nx) {
            lit.push(nx)
          } else if nx == 'n' {
            lit.push('\n')
          } else if nx == 'r' {
            lit.push('\r')
          } else if nx == 't' {
            lit.push('\t')
          } else {
            return None
          }
          k = k + 2
        } else if is_regex_operator(c) {
          return None
        } else {
          lit.push(c)
          k = k + 1
        }
      }
      if lit.length() == 0 {
        return None
      }
      branches.push((chars_to_string(lit), b_start, b_end))
      seg_lo = i + 1
    }
    i = i + 1
  }
  if branches.length() < 2 {
    return None
  }
  Some((branches, word_start, word_end))
}

///|
/// PER-BRANCH anchored alternation matching: candidates from every
/// branch (line-anchored / plain-occurrence per its flags) merge by
/// (start, branch declaration order) and emit greedily non-overlapping
/// — onig find_iter semantics with alternation declaration-order ties.
fn literal_branch_alternation_matches(
  chars : Array[Char],
  branches : Array[(String, Bool, Bool)],
  word_start : Bool,
  word_end : Bool,
) -> Array[Span] {
  let n = chars.length()
  // candidates: (start, branch_idx, stop)
  let cands : Array[(Int, Int, Int)] = []
  for bi, branch in branches {
    let (lit, b_start, b_end) = branch
    let pat = lit.to_array()
    let m = pat.length()
    if m == 0 || m > n {
      continue
    }
    if b_start && b_end {
      // whole-line equality from a line start to any line end
      let mut ls = 0
      let mut j = 0
      let mut at_line_start = true
      while j <= n {
        if at_line_start && ls < n {
          let le = ls + m
          if le <= n &&
            (le == n || chars[le] == '\n') &&
            chars_match_at(chars, ls, pat) &&
            literal_word_boundaries_match(chars, ls, le, word_start, word_end) {
            cands.push((ls, bi, le))
          }
          at_line_start = false
        }
        if j == n {
          break
        }
        if chars[j] == '\n' {
          ls = j + 1
          at_line_start = true
        }
        j = j + 1
      }
    } else if b_start {
      let mut ls = 0
      let mut j = 0
      let mut at_line_start = true
      while j <= n {
        if at_line_start && ls + m <= n && ls < n {
          if chars_match_at(chars, ls, pat) &&
            literal_word_boundaries_match(
              chars,
              ls,
              ls + m,
              word_start,
              word_end,
            ) {
            cands.push((ls, bi, ls + m))
          }
          at_line_start = false
        }
        if j == n {
          break
        }
        if chars[j] == '\n' {
          ls = j + 1
          at_line_start = true
        }
        j = j + 1
      }
    } else if b_end {
      // ending at a line end; leftmost start for a single literal is
      // the unique position le-m per line end
      let mut j = 0
      while j <= n {
        let is_end = j == n || chars[j] == '\n'
        if is_end && j - m >= 0 {
          let st = j - m
          if chars_match_at(chars, st, pat) &&
            literal_word_boundaries_match(chars, st, j, word_start, word_end) {
            cands.push((st, bi, j))
          }
        }
        if j == n {
          break
        }
        j = j + 1
      }
    } else {
      // plain occurrences: collect EVERY position (the greedy merge
      // owns overlap suppression — a local skip here would lose
      // occurrences an earlier branch's match shadows, probed:
      // `ax|xxx` on "axxxx" must give '##')
      let mut p = 0
      while p + m <= n {
        if chars_match_at(chars, p, pat) &&
          literal_word_boundaries_match(chars, p, p + m, word_start, word_end) {
          cands.push((p, bi, p + m))
        }
        p = p + 1
      }
    }
  }
  cands.sort_by((a, b) => if a.0 != b.0 { a.0 - b.0 } else { a.1 - b.1 })
  let out : Array[Span] = []
  let mut last_end = 0
  for c in cands {
    if c.0 >= last_end {
      out.push({ start: c.0, stop: c.2, })
      last_end = c.2
    }
  }
  out
}
