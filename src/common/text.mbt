// Shared text predicates and tiny conversion helpers used across tokenizer
// components. Keep this package dependency-free so model/normalizer/
// pretokenizer/decoder/tokenizer can all import it without introducing cycles.

///|
/// ASCII whitespace used by HF strip/lstrip/rstrip-style helpers.
pub fn is_ascii_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// ASCII decimal digit predicate.
pub fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// ASCII alphabetic predicate for regex classes like `[A-Za-z]+`.
pub fn is_ascii_letter(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
/// ASCII alphanumeric predicate for regex classes like `[A-Za-z0-9]+` that do
/// not include `_` (unlike `\w`).
pub fn is_ascii_alnum(c : Char) -> Bool {
  is_ascii_letter(c) || is_ascii_digit(c)
}

///|
/// Unicode word predicate used by HF/Rust-regex `\w`-style matching and
/// AddedVocabulary `single_word` boundaries. Rust regex treats letters and
/// numbers from Unicode scripts as word characters (plus `_`), so CJK/Greek/etc.
/// neighbors must block single-word added-token extraction just like ASCII
/// letters do.

///|
/// onig's six Latin-1 quirk codepoints (² ³ ¹ ¼ ½ ¾): they match BARE
/// `\w`/`\w+`/`\w{n}` but NOT class-context spellings (`[\w]`, `[^\w]`)
/// or single-word added-token boundaries (probed across all families).
let word_onig_quirks : Array[Int] = [0xB2, 0xB3, 0xB9, 0xBC, 0xBD, 0xBE]

///|
/// Word-char test for BARE `\w` spellings (includes the onig quirks).
pub fn is_word_char(c : Char) -> Bool {
  if c == '_' {
    return true
  }
  let u = c.to_int()
  for q in word_onig_quirks {
    if u == q {
      return true
    }
  }
  is_word_char_class(c)
}

///|
/// Word-char test for CLASS-CONTEXT spellings (`[\w]`, `[a\w]`, `[^\w]`)
/// and single-word boundaries: the table WITHOUT the onig quirks.
pub fn is_word_char_class(c : Char) -> Bool {
  if c == '_' {
    return true
  }
  let u = c.to_int()
  // the empirically generated table was probed with BARE \w and therefore
  // contains the onig quirks; class-context semantics must exclude them
  for q in word_onig_quirks {
    if u == q {
      return false
    }
  }
  let mut lo = 0
  let mut hi = word_ranges.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let (start, stop) = word_ranges[mid]
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
/// Unicode `\p{N}` / `\p{Number}` test (General Category N = Nd + Nl +
/// No): binary search over the empirically generated `number_ranges`.
/// Probed against 0.22.2: `²` (No) and `Ⅰ` (Nl) match `\p{N}` but NOT
/// `\d` (which stays Nd-only via `is_decimal_number`) — the spellings
/// are distinct kinds and must not share this predicate.
pub fn is_unicode_number(c : Char) -> Bool {
  let u = c.to_int()
  let mut lo = 0
  let mut hi = number_ranges.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let (start, stop) = number_ranges[mid]
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
/// Unicode `\p{L}` approximation used by hand-written GPT/Qwen scanners and
/// the common simple-regex fallback. It intentionally covers the script ranges
/// that appear in the fixture matrix and common multilingual tokenizers without
/// pulling in a full Unicode property table.
pub fn is_unicode_letter(c : Char) -> Bool {
  let u = c.to_int()
  // Basic Latin + Latin Extended (covers most European scripts)
  if (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) {
    return true
  }
  if (u >= 0xC0 && u <= 0x24F) && u != 0xD7 && u != 0xF7 {
    return true
  }
  // Greek and Coptic
  if u >= 0x370 && u <= 0x3FF {
    return true
  }
  // Cyrillic
  if u >= 0x400 && u <= 0x4FF {
    return true
  }
  // Armenian
  if u >= 0x530 && u <= 0x58F {
    return true
  }
  // Hebrew
  if u >= 0x590 && u <= 0x5FF {
    return true
  }
  // Arabic
  if u >= 0x620 && u <= 0x64A {
    return true
  }
  // Devanagari (Hindi, Sanskrit)
  if u >= 0x0900 && u <= 0x097F {
    return true
  }
  // Bengali
  if u >= 0x0980 && u <= 0x09FF {
    return true
  }
  // Gurmukhi (Punjabi)
  if u >= 0x0A00 && u <= 0x0A7F {
    return true
  }
  // Gujarati
  if u >= 0x0A80 && u <= 0x0AFF {
    return true
  }
  // Oriya
  if u >= 0x0B00 && u <= 0x0B7F {
    return true
  }
  // Tamil
  if u >= 0x0B80 && u <= 0x0BFF {
    return true
  }
  // Telugu
  if u >= 0x0C00 && u <= 0x0C7F {
    return true
  }
  // Kannada
  if u >= 0x0C80 && u <= 0x0CFF {
    return true
  }
  // Malayalam
  if u >= 0x0D00 && u <= 0x0D7F {
    return true
  }
  // Sinhala
  if u >= 0x0D80 && u <= 0x0DFF {
    return true
  }
  // Thai
  if u >= 0x0E00 && u <= 0x0E7F {
    return true
  }
  // Lao
  if u >= 0x0E80 && u <= 0x0EFF {
    return true
  }
  // Tibetan
  if u >= 0x0F00 && u <= 0x0FFF {
    return true
  }
  // Myanmar
  if u >= 0x1000 && u <= 0x109F {
    return true
  }
  // Georgian
  if u >= 0x10A0 && u <= 0x10FF {
    return true
  }
  // Khmer
  if u >= 0x1780 && u <= 0x17FF {
    return true
  }
  // Hiragana + Katakana (Japanese)
  if u >= 0x3040 && u <= 0x30FF {
    return true
  }
  // CJK Unified Ideographs (Extension A + Main)
  if u >= 0x3400 && u <= 0x4DBF {
    return true
  }
  if u >= 0x4E00 && u <= 0x9FFF {
    return true
  }
  // Hangul Syllables (Korean)
  if u >= 0xAC00 && u <= 0xD7A3 {
    return true
  }
  // Ethiopic (Amharic, Tigrinya)
  if u >= 0x1200 && u <= 0x137F {
    return true
  }
  // Ethiopic Supplement
  if u >= 0x1380 && u <= 0x139F {
    return true
  }
  // Cherokee
  if u >= 0x13A0 && u <= 0x13FF {
    return true
  }
  // Canadian Aboriginal Syllabics
  if u >= 0x1400 && u <= 0x167F {
    return true
  }
  // Ogham (Old Irish)
  if u >= 0x1680 && u <= 0x169F {
    return true
  }
  // Runic (Norse, Germanic)
  if u >= 0x16A0 && u <= 0x16FF {
    return true
  }
  // Latin Extended Additional (Vietnamese, etc.)
  if u >= 0x1E00 && u <= 0x1EFF {
    return true
  }
  // Greek Extended
  if u >= 0x1F00 && u <= 0x1FFF {
    return true
  }
  // CJK Unified Ideographs Extension B
  if u >= 0x20000 && u <= 0x2A6DF {
    return true
  }
  // CJK Unified Ideographs Extension C + D
  if u >= 0x2A700 && u <= 0x2B73F {
    return true
  }
  // CJK Compatibility Ideographs
  if u >= 0xF900 && u <= 0xFAFF {
    return true
  }
  // Hangul Jamo (Korean consonants/vowels)
  if u >= 0x1100 && u <= 0x11FF {
    return true
  }
  // Hangul Jamo Extended-A
  if u >= 0xA960 && u <= 0xA97F {
    return true
  }
  // Hangul Jamo Extended-B
  if u >= 0xD7B0 && u <= 0xD7FF {
    return true
  }
  false
}

///|
/// Unicode `\p{P}` / `\p{Punctuation}` over the complete generated range
/// table (planes 0-2; see `unicode_punct_data.mbt`, regenerated by
/// `scripts/gen_unicode_punct.py` and validated against Python `tokenizers`
/// 0.22.2 probes). ASCII punctuation is separated from ASCII symbols
/// (`$`, `+`, `<`, `=`, `>`, `^`, `` ` ``, `|`, `~`) so `\p{P}` and `\p{S}`
/// match the regex semantics HF's Rust engine uses.
pub fn is_unicode_punctuation(c : Char) -> Bool {
  let u = c.to_int()
  let ranges = unicode_punct_ranges()
  let mut lo = 0
  let mut hi = ranges.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let (start, stop) = ranges[mid]
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
/// Unicode `\p{S}` / `\p{Symbol}` approximation for common tokenizer regexes.
/// Covers ASCII math/currency/modifier symbols plus currency, math, technical,
/// dingbat and emoji blocks frequently seen in LLM tokenizers.
pub fn is_unicode_symbol(c : Char) -> Bool {
  let u = c.to_int()
  u == 0x24 ||
  u == 0x2B ||
  (u >= 0x3C && u <= 0x3E) ||
  u == 0x5E ||
  u == 0x60 ||
  u == 0x7C ||
  u == 0x7E ||
  (u >= 0x20A0 && u <= 0x20CF) ||
  (u >= 0x2100 && u <= 0x214F) ||
  (u >= 0x2190 && u <= 0x21FF) ||
  (u >= 0x2200 && u <= 0x22FF) ||
  (u >= 0x2300 && u <= 0x23FF) ||
  (u >= 0x2460 && u <= 0x24FF) ||
  (u >= 0x2500 && u <= 0x25FF) ||
  (u >= 0x2600 && u <= 0x27BF) ||
  (u >= 0x27C0 && u <= 0x27EF) ||
  (u >= 0x2980 && u <= 0x29FF) ||
  (u >= 0x2B00 && u <= 0x2BFF) ||
  (u >= 0x1F000 && u <= 0x1FAFF) ||
  (u >= 0xFFE0 && u <= 0xFFE6)
}

///|
/// Combined Unicode punctuation/symbol predicate for regex classes such as
/// `[\p{P}\p{S}]+`, which are common in tokenizer Split rules for non-word
/// runs.
pub fn is_unicode_punctuation_or_symbol(c : Char) -> Bool {
  is_unicode_punctuation(c) || is_unicode_symbol(c)
}

///|
/// Approximation for `[^\s\p{L}\p{N}]`: match visible non-space separators such
/// as punctuation, symbols and other non-letter/non-number marks.
pub fn is_not_whitespace_letter_or_number(c : Char) -> Bool {
  !is_unicode_whitespace(c.to_int()) &&
  !is_unicode_letter(c) &&
  !is_unicode_number(c)
}

///|
/// Common bounded `{1,n}` regex class families used by HF tokenizer Split and
/// Replace configs. Return `(kind, max_run)`, where `kind` is consumed by
/// `bounded_regex_kind_pred`. Keeping this table shared prevents the Split
/// scanner, Normalizer Replace and Decoder Replace from drifting apart.

///|
/// Whether the shared replace chain (Split/Normalizer/Decoder) handles
/// `pattern` through a deterministic scanner family or as a
/// regex-literal (where literal replacement is the correct regex
/// behavior). Exact against Python 0.22.2 for the audited corpus
/// (real models use only `\s+`, ` {2,}` and String literals); known
/// family-level divergences on adversarial input are tracked in
/// PROGRESS §5 (per-line anchors, `[0-9]`/`[A-Za-z0-9_]` mapping to
/// Unicode kinds, bare `[\r\n]` run semantics). A literal brace used
/// as text (`a{b`) is treated as an operator and rejected — exotic,
/// accepted under the fail-explicitly policy. Used by load-time gates
/// to reject unsupported regex patterns explicitly instead of silently
/// falling back to a literal replace (which could silently mis-replace
/// text containing the literal pattern).
pub fn is_supported_replace_regex(pattern : String) -> Bool {
  // lazy suffixes collapse to greedy equivalents before family checks;
  // the lazy-exact family (`a{n}?`) is its own engine and claims the
  // raw spelling
  if lazy_exact_spec(pattern) is Some(_) {
    return true
  }
  // double-anchored whole-line family (`^X+$` etc.)
  if double_anchored_spec(pattern) is Some(_) {
    return true
  }
  let pattern = match lazy_normalize(pattern) {
    Some(p) => p
    None => pattern
  }
  if pattern.is_empty() {
    // Degenerate: the chain returns the input unchanged (documented
    // divergence from HF's insert-between-chars); keep loadable.
    return true
  }
  // quantifier-zoo kinds (the `{`-containing branch of the chain)
  if pattern.contains("{") {
    if replace_bounded_simple_regex_probe(pattern) {
      return true
    }
    if replace_ranged_simple_regex_probe(pattern) {
      return true
    }
    if exact_regex_kind(pattern) is Some(_) {
      return true
    }
    if min_regex_kind(pattern) is Some(_) {
      return true
    }
  }
  // scanner families (literal / alternation / class runs / anchored)
  if simple_split_regex_matches("a".to_array(), pattern) is Some(_) {
    return true
  }
  if anchored_regex_kind(pattern) is Some(_) {
    return true
  }
  // bare single-character class spellings: exact run of 1
  if bare_class_kind(pattern) is Some(_) {
    return true
  }
  // bracket \s per-run spelling (issue #47)
  if pattern == "[\\s]+" {
    return true
  }
  // single-char literal bounded quantifiers within the onig 100000 bound
  if char_bounded_spec(pattern) is Some(_) {
    return true
  }
  // generic class windows (\w{5} ...) up to the same bound
  if class_bounded_spec(pattern) is Some(_) {
    return true
  }
  // boundary-windowed quantifiers (\b\w{5}, \w{5}\b ...)
  if boundary_window_spec(pattern) is Some(_) {
    return true
  }
  // single-anchor windows (^\w{1,2}, \w{1,2}$)
  if single_anchor_window_spec(pattern) is Some(_) {
    return true
  }
  // lazy-exact anchored (\ba{2}?, \w{2}?\b ...)
  if boundary_lazy_exact_spec(pattern) is Some(_) {
    return true
  }
  // non-boundary (\B) windows and lazy-exact
  if nonboundary_window_spec(pattern) is Some(_) {
    return true
  }
  if nonboundary_lazy_exact_spec(pattern) is Some(_) {
    return true
  }
  // mixed-anchor (\b + \B) windows and their plus spellings
  if mixed_anchor_window_spec(pattern) is Some(_) {
    return true
  }
  // zero-minimum quantifiers: a{0} / a{0,m} / a{0,} and class bases
  if zero_min_quantifier_spec(pattern) is Some(_) {
    return true
  }
  // everything the chain would handle via its hardcoded literal cases is
  // covered by the kinds/scanners above; a remaining pure literal is
  // correctly handled by the literal fallback
  is_regex_literal_pattern(pattern)
}

///|
/// Probe the bounded/ranged families without caring about the output.
fn replace_bounded_simple_regex_probe(pattern : String) -> Bool {
  replace_bounded_simple_regex("a", pattern, "x") is Some(_)
}

///|
fn replace_ranged_simple_regex_probe(pattern : String) -> Bool {
  replace_ranged_simple_regex("a", pattern, "x") is Some(_)
}

///|
/// A pattern with no regex metacharacters (so literal replacement is the
/// correct regex semantics). Escaped literals (e.g. `a\\.b`) count: the
/// escape removes the metachar meaning.
fn is_regex_literal_pattern(pattern : String) -> Bool {
  regex_literal_spec(pattern) is Some(_)
}

///|
/// Bare single-character class spellings (no quantifier) map to their
/// class kind with an implied exact run of 1 — HF replaces each matching
/// character individually (probed: Replace(Regex "[0-9]", "#") on "a5b7"
/// -> "a#b#"). Returns the class kind.
pub fn bare_class_kind(pattern : String) -> Int? {
  match pattern {
    "\\s" | "[\\s]" => Some(1)
    "\\S" | "[^\\s]" => Some(12)
    "[0-9]" => Some(22)
    "\\d" | "[\\d]" => Some(11)
    // \p{N} spellings are FULL N (Nd + Nl + No; probed 0.22.2: ² matches)
    "\\p{N}" | "\\p{Number}" | "[\\p{N}]" | "[\\p{Number}]" => Some(28)
    "[^0-9]" => Some(23)
    "\\D" | "[\\D]" | "[^\\d]" => Some(14)
    "\\P{N}" | "\\P{Number}" | "[^\\p{N}]" | "[^\\p{Number}]" => Some(29)
    "[A-Za-z0-9_]" => Some(24)
    "\\w" => Some(4)
    "[^A-Za-z0-9_]" => Some(25)
    "\\W" => Some(13)
    "[\\w]" => Some(26) // bracket: word WITHOUT onig quirks
    "[^\\w]" => Some(27)
    "[\\W]" => Some(27)
    "[^\\W]" => Some(26)
    "[A-Za-z]" => Some(6)
    "\\p{L}" | "\\p{Letter}" | "[\\p{L}]" | "[\\p{Letter}]" => Some(7)
    "[^A-Za-z]" => Some(16)
    "\\P{L}" | "\\P{Letter}" | "[^\\p{L}]" => Some(17)
    "\\p{P}" | "\\p{Punctuation}" | "[\\p{P}]" => Some(8)
    "\\P{P}" | "\\P{Punctuation}" => Some(18)
    "\\p{S}" | "\\p{Symbol}" | "[\\p{S}]" => Some(9)
    "\\P{S}" | "\\P{Symbol}" => Some(19)
    "[\\r\\n]" => Some(3)
    _ => None
  }
}

///|
/// Digit run at [k, until) capped at the onig 100000 bound; returns
/// (value, next_index).
fn parse_capped_digits(arr : Array[Char], k : Int, until : Int) -> (Int, Int)? {
  let mut v = 0
  let mut j = k
  while j < until && arr[j] >= '0' && arr[j] <= '9' {
    v = v * 10 + (arr[j].to_int() - '0'.to_int())
    if v > 100000 {
      return None
    }
    j = j + 1
  }
  if j == k {
    return None
  }
  Some((v, j))
}

///|
/// Normalize a LAZY-quantifier suffix for global replace (probed 0.22.2):
///   `{0-族}?`  (`{0}?`, `{,n}?`, `{0,n}?`, `{0,}?`) == `{0}`
///   `{n}?`   (exact, n >= 1)                 == `{0,n}`
///   `{n,m}?` / `{n,}?` (n >= 1)               == `{n}`
/// Returns the equivalent greedy pattern for the downstream families,
/// or None when the pattern has no lazy suffix / the bound is out of
/// the onig 100000 window (the gate then rejects).
pub fn lazy_normalize(pattern : String) -> String? {
  let chars = pattern.to_array()
  let n = chars.length()
  if n < 5 || chars[n - 1] != '?' || chars[n - 2] != '}' {
    return None
  }
  let stop = n - 2 // index of the '}'
  let mut open = -1
  let mut i = 0
  while i < stop {
    if chars[i] == '{' {
      open = i
    }
    i = i + 1
  }
  if open < 1 {
    return None
  }
  // an ODD backslash run before `{` escapes the brace (e.g. `\{0,2}?`
  // is a literal pattern — leave it to the literal path); an EVEN run
  // is an escaped-backslash base (`\\{0,2}?`) with a real quantifier
  // (probed 0.22.2: HF computes the full lazy families on it)
  let mut bs = 0
  let mut k = open - 1
  while k >= 0 && chars[k] == '\\' {
    bs = bs + 1
    k = k - 1
  }
  if bs % 2 == 1 {
    return None
  }
  let inner : Array[Char] = []
  let mut q = open + 1
  while q < stop {
    inner.push(chars[q])
    q = q + 1
  }
  let base_sb = StringBuilder()
  for i in 0..<open {
    base_sb.write_char(chars[i])
  }
  let base = base_sb.to_string()
  let m = inner.length()
  if m == 0 {
    return None
  }
  // parse the first number (leading zeros allowed; value-routed below)
  let first = parse_capped_digits(inner, 0, m)
  // {,n}? — comma-open: {,digits}? == {0}; {,}? is not a quantifier
  if inner[0] == ',' {
    match parse_capped_digits(inner, 1, m) {
      Some((_, j)) => if j == m { return Some(base + "{0}") }
      None => ()
    }
    return None
  }
  match first {
    Some((v, j)) => {
      if v == 0 {
        // zero-min lazy: {0} / {00} / {0,} / {0,digits} all == {0},
        // but the tail must be a VALID quantifier tail (digit-only,
        // capped) — probed: {0,2x}? is a literal in HF
        if j == m {
          return Some(base + "{0}")
        }
        if inner[j] == ',' {
          if j + 1 == m {
            return Some(base + "{0}") // {0,}?
          }
          match parse_capped_digits(inner, j + 1, m) {
            Some((_, k2)) =>
              if k2 == m {
                return Some(base + "{0}") // {0,digits}?
              }
            None => ()
          }
        }
        return None // invalid tail: literal, not a quantifier
      }
      // v >= 1 (leading zeros already folded into the value)
      if j == m {
        // exact {n}? is the lazy-exact family, not ours
        return None
      }
      if inner[j] == ',' {
        if j + 1 == m {
          return Some(base + "{" + v.to_string() + "}") // {n,}? == {n}
        }
        match parse_capped_digits(inner, j + 1, m) {
          Some((hi, k2)) =>
            if k2 == m {
              if hi < v {
                return None // reversed range: HF swaps; we fail explicitly
              }
              return Some(base + "{" + v.to_string() + "}") // {n,m}? == {n}
            }
          None => ()
        }
      }
      None
    }
    None => None
  }
}

///|
/// Parse a zero-minimum quantifier pattern into (kind, literal, max)
/// when the pattern is `base{0}`, `base{0,m}` or `base{0,}` where `base`
/// is a bare single-char class spelling (via bare_class_kind) or an
/// ordinary literal char. `kind` = -1 signals a literal base (the char is
/// carried in `literal`); `max` = -1 signals the unbounded `{0,}` form.
pub fn zero_min_quantifier_spec(pattern : String) -> (Int, Char?, Int)? {
  let chars = pattern.to_array()
  let n = chars.length()
  // find the LAST '{' — base is everything before it
  let mut open = -1
  for i in 0..<n {
    if chars[i] == '{' {
      open = i
    }
  }
  if open < 1 || open + 3 > n || chars[n - 1] != '}' {
    return None
  }
  // inner: `{0...}` (leading zeros allowed: {0}/{00}/{0,}/{00,2}/{0,02})
  // or `{,m}` — onig treats a comma-open bound as min 0 (probed 0.22.2:
  // `a{,2}` on 'zaaz' -> '#z#z#', `a{,0}` == `a{0}`); the empty `{,}` is
  // NOT a quantifier (literal — probed: 'zaaz' unchanged) and falls to
  // the literal path. `{n,0}` also lands here — onig swaps it to
  // `{0,n}` (probed: `a{2,0}` on 'zaaaz' -> '#z##z#' == `a{0,2}`),
  // handled by the n-comma-zero branch below.
  let n_zero : Int? = if chars[open + 1] >= '0' && chars[open + 1] <= '9' {
    // `{n,0}` shape: digits, ',', '0', '}' — parse v then require ,0)
    let mut v = 0
    let mut k = open + 1
    while k < n - 1 && chars[k] >= '0' && chars[k] <= '9' {
      v = v * 10 + (chars[k].to_int() - '0'.to_int())
      if v > 100000 {
        return None
      }
      k = k + 1
    }
    // after ',': zeros only (probed: a{2,00} == a{2,0} in HF)
    if k < n - 1 && chars[k] == ',' {
      let mut z = k + 1
      while z < n - 1 && chars[z] == '0' {
        z = z + 1
      }
      if z == n - 1 && z > k + 1 {
        Some(v)
      } else {
        None
      }
    } else {
      None
    }
  } else {
    None
  }
  match n_zero {
    Some(v) =>
      return match zero_min_base(open, chars, v) {
        Some((kk, lit, _)) => Some((kk, lit, v))
        None => None
      }
    None => ()
  }
  let max : Int = if chars[open + 1] == ',' {
    if open + 2 == n - 1 {
      return None // {,}
    }
    // {,m}: onig rejects repeat bounds above 100000 ("too big number for
    // repeat range", probed 0.22.2), so the spec stops matching there.
    let mut v = 0
    let mut k = open + 2
    while k < n - 1 {
      let c = chars[k]
      if c < '0' || c > '9' {
        return None
      }
      v = v * 10 + (c.to_int() - '0'.to_int())
      if v > 100000 {
        return None
      }
      k = k + 1
    }
    v
  } else if chars[open + 1] != '0' {
    return None
  } else {
    let mut z = open + 1
    while z < n - 1 && chars[z] == '0' {
      z = z + 1
    }
    if z == n - 1 {
      0 // {0...} exact-zero (leading zeros equivalent, probed: a{00} == a{0})
    } else if chars[z] != ',' {
      return None
    } else if z + 1 == n - 1 {
      -1 // {0...,} unbounded
    } else {
      let mut v = 0
      let mut k = z + 1
      while k < n - 1 {
        let c = chars[k]
        if c < '0' || c > '9' {
          return None
        }
        v = v * 10 + (c.to_int() - '0'.to_int())
        if v > 100000 {
          return None
        }
        k = k + 1
      }
      v
    }
  }
  // base spelling
  let base_sb = StringBuilder()
  for i in 0..<open {
    base_sb.write_char(chars[i])
  }
  let base = base_sb.to_string()
  match bare_class_kind(base) {
    Some(kind) => Some((kind, None, max))
    None => {
      let bc = base.to_array()
      if bc.length() == 2 && bc[0] == '\\' {
        // escaped literal base (probed 0.22.2: `\\n{0,2}` on "z\n\nz"
        // -> '#z#z#', `\\t{2}`/`\\\\{2}`/`\\.{2}` all compute)
        match bc[1] {
          'n' => Some((-1, Some('\n'), max))
          't' => Some((-1, Some('\t'), max))
          'r' => Some((-1, Some('\r'), max))
          '\\' => Some((-1, Some('\\'), max))
          '.' => Some((-1, Some('.'), max))
          _ => None
        }
      } else if bc.length() == 1 && !is_regex_operator(bc[0]) && bc[0] != '\\' {
        Some((-1, Some(bc[0]), max))
      } else {
        None
      }
    }
  }
}

///|
/// LAZY exact form `base{n}?` (probed 0.22.2): an exact-n block when the
/// run reaches n, otherwise the zero-min empty-match walk — so `a{2}?`
/// gives '#z#z#' on 'zaaz' (block + boundary empties) but '#z#a#' on
/// 'za' (no 2-run, pure empties). Base is a class kind or an escaped /
/// ordinary literal char (same resolution as the zero-min spec).
pub fn lazy_exact_spec(pattern : String) -> (Int, Char?, Int, Int)? {
  let chars = pattern.to_array()
  let n = chars.length()
  if n < 5 || chars[n - 1] != '?' || chars[n - 2] != '}' {
    return None
  }
  let stop = n - 2
  let mut open = -1
  let mut i = 0
  while i < stop {
    if chars[i] == '{' {
      open = i
    }
    i = i + 1
  }
  if open < 1 {
    return None
  }
  let inner : Array[Char] = []
  let mut q = open + 1
  while q < stop {
    inner.push(chars[q])
    q = q + 1
  }
  let m = inner.length()
  if m == 0 || inner[0] == ',' {
    return None // comma-open belongs to lazy_normalize
  }
  // route by VALUE: {02}? is exact-2 lazy (probed), {00}? is {0} (not ours)
  match parse_capped_digits(inner, 0, m) {
    Some((v, j)) =>
      if j == m && v >= 1 {
        match zero_min_base(open, chars, v) {
          Some((k, lit, _)) => return Some((k, lit, v, v))
          None => return None
        }
      }
    None => ()
  }
  // reversed range {n,m}? with n > m: onig swaps to (?:X{m,n})? —
  // greedy ranged blocks PLUS the empty-match walk (probed: a{3,2}?
  // 'zaaz' -> '#z#z#', 'zaaaaz' -> '#z#a#z#', 'aaaaa' -> '##')
  match parse_capped_digits(inner, 0, m) {
    Some((lo, j)) =>
      if j < m && inner[j] == ',' && j + 1 < m {
        match parse_capped_digits(inner, j + 1, m) {
          Some((hi, k2)) =>
            if k2 == m && hi < lo {
              match zero_min_base(open, chars, hi) {
                Some((k, lit, _)) => return Some((k, lit, hi, lo))
                None => return None
              }
            }
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
/// Shared base resolution for zero-min/lazy specs (class kind or an
/// escaped / ordinary literal char); `max` is the already-normalized
/// bound.
fn zero_min_base(
  open : Int,
  chars : Array[Char],
  max : Int,
) -> (Int, Char?, Int)? {
  let base_sb = StringBuilder()
  for i in 0..<open {
    base_sb.write_char(chars[i])
  }
  let base = base_sb.to_string()
  match bare_class_kind(base) {
    Some(kind) => Some((kind, None, max))
    None => {
      let bc = base.to_array()
      if bc.length() == 2 && bc[0] == '\\' {
        match bc[1] {
          'n' => Some((-1, Some('\n'), max))
          't' => Some((-1, Some('\t'), max))
          'r' => Some((-1, Some('\r'), max))
          '\\' => Some((-1, Some('\\'), max))
          '.' => Some((-1, Some('.'), max))
          _ => None
        }
      } else if bc.length() == 1 && !is_regex_operator(bc[0]) && bc[0] != '\\' {
        Some((-1, Some(bc[0]), max))
      } else {
        None
      }
    }
  }
}

///|
/// DOUBLE-anchored `^BASE QUANT $` spec (probed 0.22.2): under the
/// multiline option HF's Replace uses, `^...$` matches EACH LINE whose
/// entire content satisfies the class and length window — '!!' -> '#',
/// '!!x!!' unchanged, '!!\n!!' -> '#\n#', 'a\n!!\nb' -> 'a\n#\nb'
/// (lines split on '\n'; '\r' belongs to the line content, so '!!\r\n!!'
/// leaves the '\r'-bearing first line unmatched). QUANT is `+`, `{n}`,
/// `{n,}`, `{n,m}` (window 1..4); BASE is a bare class spelling, one of
/// the twelve mixed-complement orderings, a single literal char, or an
/// escaped literal. Returns (kind, literal, lo, hi); hi = -1 unbounded;
/// kind -1 signals the literal base.
pub fn double_anchored_spec(pattern : String) -> (Int, Char?, Int, Int)? {
  let chars = pattern.to_array()
  let n = chars.length()
  if n < 3 || chars[0] != '^' || chars[n - 1] != '$' {
    return None
  }
  // A lazy '?' before the '$' is NOT supported: HF parses X{n,m}? as
  // (?:X{m,n})? whose whole-line form adds empty matches at ^-and-$
  // positions and shortest-line-end selection for \n-spanning classes
  // — a different engine capability. Fail explicitly (probed:
  // ^a{3,2}?$ on '\n\n' -> '#\n#\n' in HF).
  let mut q_is_lazy = chars[n - 2] == '?'
  if q_is_lazy && n >= 4 {
    let mut bs = 0
    let mut k = n - 3
    while k >= 1 && chars[k] == '\\' {
      bs = bs + 1
      k = k - 1
    }
    if bs % 2 == 1 {
      q_is_lazy = false // escaped literal '?' base (probed: ^\?$)
    }
  }
  if q_is_lazy {
    return None
  }
  double_anchored_brace(chars, n)
}

///|
fn double_anchored_brace(
  chars : Array[Char],
  n : Int,
) -> (Int, Char?, Int, Int)? {
  if n < 3 || chars[0] != '^' || chars[n - 1] != '$' {
    return None
  }
  // locate a trailing quantifier inside the anchors: '+' at n-2, or a
  // '{...}' block ending at n-2
  let mut lo = 0
  let mut hi = 0
  let mut swapped = false
  let mut braced = false // a {n}/{n,m} window (vs `+` / quantifier-less)
  let mut base_end : Int = 0 // exclusive end of the base inside chars
  // '+' is the quantifier unless it is itself escaped (odd backslash
  // run before it: `^\+$` is the literal-plus base, `^\\+$` is an
  // escaped backslash base followed by the + quantifier)
  let mut plus_is_quantifier = chars[n - 2] == '+'
  if plus_is_quantifier && n >= 4 {
    let mut bs = 0
    let mut k = n - 3
    while k >= 1 && chars[k] == '\\' {
      bs = bs + 1
      k = k - 1
    }
    if bs % 2 == 1 {
      plus_is_quantifier = false
    }
  }
  if plus_is_quantifier {
    lo = 1
    hi = -1
    base_end = n - 2
  } else if chars[n - 2] == '}' {
    braced = true
    // find the matching '{' scanning back from n-2
    let mut open = -1
    let mut i = n - 3
    while i >= 1 {
      if chars[i] == '{' {
        open = i
        break
      }
      i = i - 1
    }
    if open < 2 {
      return None
    }
    let inner : Array[Char] = []
    let mut k = open + 1
    while k < n - 2 {
      inner.push(chars[k])
      k = k + 1
    }
    let m = inner.length()
    // comma-open {,m} == {0,m} (probed onig): route as lo=0, hi=m
    if inner.length() > 1 && inner[0] == ',' {
      match parse_capped_digits(inner, 1, inner.length()) {
        Some((w, k2)) =>
          if k2 == inner.length() && w <= 100000 {
            lo = 0
            hi = w
            base_end = open
          } else {
            return None
          }
        None => return None
      }
      if base_end == open {
        // skip the normal quantifier parse below — already set
        let sb0 = StringBuilder()
        let mut q0 = 1
        while q0 < base_end {
          sb0.write_char(chars[q0])
          q0 = q0 + 1
        }
        return double_anchored_base(sb0.to_string(), lo, hi, swapped~, braced~)
      }
    }
    match parse_capped_digits(inner, 0, m) {
      Some((v, j)) =>
        if j == m {
          if v > 100000 {
            return None
          }
          lo = v
          hi = v
        } else if inner[j] == ',' {
          if j + 1 == m {
            if v > 100000 {
              return None
            }
            lo = v
            hi = -1
          } else {
            match parse_capped_digits(inner, j + 1, m) {
              Some((w, k2)) =>
                if k2 == m && v <= 100000 && w <= 100000 {
                  // reversed {n,m} with n > m: onig swaps to an ATOMIC
                  // {m,n} window (probed: ^a{3,2}$ on 'aa'/'aaa' ->
                  // '#', 'aaaa' unchanged == the {2,3} window; ^a{2,0}$
                  // stays rejected — its {0,2} swap has empty-line
                  // semantics this engine lacks). Claimed only for
                  // \n-free classes: \s/[\r\n]/\n spans make atomicity
                  // vs backtracking diverge (probed: ^\s{4,2}$ on
                  // '   \nx' unchanged in HF) — those fail explicitly.
                  if w < v {
                    if w < 1 {
                      return None // a {0,n} swap has empty-line semantics
                    }
                    lo = w
                    hi = v
                    swapped = true
                  } else {
                    lo = v
                    hi = w
                  }
                } else {
                  return None
                }
              None => return None
            }
          }
        } else {
          return None
        }
      None => return None
    }
    base_end = open
  } else {
    // quantifier-less `^BASE$` == `^BASE{1}$` (probed 0.22.2: 'a\na'
    // with ^a$ -> '#\n#'; a single-char window never crosses lines).
    // Also reached for escaped-operator bases (`^\+$`): the '+'
    // belongs to the base, window is the single char.
    lo = 1
    hi = 1
    base_end = n - 1
  }
  let sb = StringBuilder()
  let mut q2 = 1
  while q2 < base_end {
    sb.write_char(chars[q2])
    q2 = q2 + 1
  }
  double_anchored_base(sb.to_string(), lo, hi, swapped~, braced~)
}

///|
fn double_anchored_base(
  base : String,
  lo : Int,
  hi : Int,
  swapped~ : Bool,
  braced~ : Bool,
) -> (Int, Char?, Int, Int)? {
  // dot-sequence base (`^..$` = a 2-char line, `^...$` = 3-char) —
  // `.` matches any char EXCEPT newline (onig default; the quantified
  // spelling `^.{2}$` arrives as a single-dot base with lo/hi set)
  if base.length() >= 1 {
    let bc = base.to_array()
    let mut all_dots = true
    for c in bc {
      if c != '.' {
        all_dots = false
        break
      }
    }
    if all_dots && bc.length() > 1 {
      // a trailing quantifier binds to the LAST dot only (probed:
      // ^..+$ is >=2 chars/line), so quantified multi-dot windows are
      // out of scope here — fail explicitly rather than mis-window
      if lo != 1 || hi != 1 {
        return None
      }
      return Some((30, None, bc.length(), bc.length()))
    }
    if all_dots && bc.length() == 1 {
      return Some((30, None, lo, hi))
    }
  }
  match bare_class_kind(base) {
    Some(kind) =>
      if braced && bounded_regex_kind_pred(kind, '\n') {
        // BRACE windows over a \n-matching predicate (\s, [\r\n],
        // \D, \W, [^0-9], ...) reject: consecutive-newline inputs
        // have idiosyncratic anchor/line-end behavior on every bound
        // (probed 0.22.2: ^\s{1,2}$ on 'a\n\nb' matches nothing
        // while a greedy-backtracking model matches [1,2)). The `+`
        // and quantifier-less forms keep their probed PR#34/#36
        // behavior.
        None
      } else {
        Some((kind, None, lo, hi))
      }
    None => {
      if mixed_complement_ordering_kind(base) is Some(kind) {
        return Some((kind, None, lo, hi))
      }
      let bsc = base.to_array()
      if bsc.length() == 2 && bsc[0] == '\\' {
        let lit : Char? = match bsc[1] {
          'n' =>
            if braced {
              None // '\n' base brace windows share the nl-pred rejection
            } else {
              Some('\n')
            }
          't' => Some('\t')
          'r' => Some('\r')
          '+'
          | '.'
          | '*'
          | '?'
          | '('
          | ')'
          | '['
          | ']'
          | '{'
          | '}'
          | '|'
          | '^'
          | '$'
          | '-'
          | '\\' => Some(bsc[1])
          _ => None
        }
        match lit {
          Some(c) => return Some((-1, Some(c), lo, hi))
          None => return None
        }
      }
      if bsc.length() == 1 &&
        !is_regex_operator(bsc[0]) &&
        bsc[0] != '\\' &&
        bsc[0] != '$' {
        if swapped && bsc[0] == '\n' {
          return None // raw-newline literal spans lines under a swap
        }
        return Some((-1, Some(bsc[0]), lo, hi))
      }
      None
    }
  }
}

///|
/// The twelve mixed-complement orderings (`[^\s\p{L}\p{N}]` family,
/// short and long property names) resolve to kind 21.
fn mixed_complement_ordering_kind(base : String) -> Int? {
  match base {
    "[^\\s\\p{L}\\p{N}]"
    | "[^\\s\\p{N}\\p{L}]"
    | "[^\\p{L}\\s\\p{N}]"
    | "[^\\p{L}\\p{N}\\s]"
    | "[^\\p{N}\\s\\p{L}]"
    | "[^\\p{N}\\p{L}\\s]"
    | "[^\\s\\p{Letter}\\p{Number}]"
    | "[^\\s\\p{Number}\\p{Letter}]"
    | "[^\\p{Letter}\\s\\p{Number}]"
    | "[^\\p{Letter}\\p{Number}\\s]"
    | "[^\\p{Number}\\s\\p{Letter}]"
    | "[^\\p{Number}\\p{Letter}\\s]" => Some(21)
    _ => None
  }
}

///|
/// Word-boundary-windowed quantifiers: `[\b]BASE{n|n,m|n,|0-m}[\b]`
/// with at least one `\b` (probed 0.22.2: '\b\w{5}' on 'zaaaaaz' ->
/// '#az' — greedy block from a word start; '\w{5}\b' on 'zaaaaaaz'
/// (6-word run) -> 'zaa#' — the block backtracks to END on the run's
/// boundary, i.e. it spans the last window of the run; both anchors
/// whole words only, '\ba{2}\b' on 'aaa aa' -> 'aaa #'). BASE is a
/// bare class or a single literal/escaped char; window 1..100000 or
/// zero-min {0,m}/{n,0}. Returns (kind, literal, lo, hi, wb_start,
/// wb_end); hi = -1 unbounded.
pub fn boundary_window_spec(
  pattern : String,
) -> (Int, Char?, Int, Int, Bool, Bool)? {
  match boundary_window_parse(pattern, true) {
    Some((kind, literal, lo, hi, ws, we)) => {
      // any-anchor zero-min ranges reject (round-2: ws-only also
      // diverges — HF backtracks per position and emits the empty at
      // boundaries the pre-filtered walk suppressed, '\b\w{0,2}' on
      // 'zaaz' -> '#az#'); only exact {0} stays. The \B family
      // bypasses this — its inverted probes match the walk+filter
      // model ('\B\w{0,2}' on 'zaaaz' -> 'z##').
      if (ws || we) && lo == 0 && hi != 0 {
        return None
      }
      Some((kind, literal, lo, hi, ws, we))
    }
    None => None
  }
}

///|
/// The raw parse shared by the \b and \B families (narrowing guards
/// live in the callers). `b_trail` says a trailing anchor in the
/// ORIGINAL spelling is a genuine \b (not a \B rewritten to \b by the
/// non-boundary/mixed callers) — the lazy plus picks its window by
/// trail kind: an end \b needs the run-end form ('\ba+?\b' on 'aaa'
/// -> '#', lazy ascends to the run end where \b first holds), an end
/// \B or no trail pins one char ('\ba+?\B' on 'aaaa' -> '#aaa').
fn boundary_window_parse(
  pattern : String,
  b_trail : Bool,
) -> (Int, Char?, Int, Int, Bool, Bool)? {
  let chars = pattern.to_array()
  let n = chars.length()
  // leading \b
  let ws = n >= 2 && chars[0] == '\\' && chars[1] == 'b'
  let body_lo = if ws { 2 } else { 0 }
  // trailing \b
  let we = n - body_lo >= 2 &&
    chars[n - 1] == 'b' &&
    chars[n - 2] == '\\' &&
    !is_escaped_at(chars, n - 2)
  let body_hi = if we { n - 2 } else { n }
  if body_lo >= body_hi {
    return None
  }
  if !ws && !we {
    return None
  }
  // BODY = BASE + quantifier: a brace (last '{' closing at body end)
  // or a plus — probed 0.22.2: '\b\w+' == '\b\w{1,}' and the lazy
  // '\b\w+?' == '\b\w{1}' (the empty continuation stops the lazy group
  // at its minimum, one char per boundary start)
  let base_sb = StringBuilder()
  let mut lo : Int = 0
  let mut hi : Int = 0
  if chars[body_hi - 1] != '}' {
    // plus spelling: 'X+?' lazy (ends '?', preceded by '+') or 'X+'
    // greedy — any other tail ('a*', 'a?', 'ab' ...) is not this
    // family; a BARE '+*?' base is rejected too — those spellings are
    // possessive quantifiers in onig, not a literal base
    let lazy_plus = chars[body_hi - 1] == '?' &&
      body_hi - 2 >= body_lo &&
      chars[body_hi - 2] == '+'
    let greedy_plus = chars[body_hi - 1] == '+'
    if !lazy_plus && !greedy_plus {
      return None
    }
    let base_end = if lazy_plus { body_hi - 2 } else { body_hi - 1 }
    if base_end <= body_lo {
      return None
    }
    if base_end - body_lo == 1 {
      let c = chars[base_end - 1]
      if c == '+' || c == '*' || c == '?' {
        return None
      }
    }
    let mut k = body_lo
    while k < base_end {
      base_sb.write_char(chars[k])
      k = k + 1
    }
    if lazy_plus {
      lo = 1
      hi = if we && b_trail { -1 } else { 1 }
    } else {
      lo = 1
      hi = -1
    }
  } else {
    let mut open = -1
    let mut i = body_lo
    while i < body_hi {
      if chars[i] == '{' {
        open = i
      }
      i = i + 1
    }
    if open < body_lo + 1 {
      return None
    }
    let mut k = body_lo
    while k < open {
      base_sb.write_char(chars[k])
      k = k + 1
    }
    let inner : Array[Char] = []
    let mut j = open + 1
    while j < body_hi - 1 {
      inner.push(chars[j])
      j = j + 1
    }
    let m = inner.length()
    // window: {n} | {n,m} | {n,} | {n,0} (== {0,n}) | {0,m} | {,m}
    match parse_capped_digits(inner, 0, m) {
      Some((v, dz)) =>
        if dz == m {
          if v > 100000 {
            return None
          }
          // v == 0 (exact {0}) is the zero-min empty walk — the boundary
          // filter gates the empty positions (probed: '\ba{0}\b' on
          // 'ab cd' -> '#ab# #cd#')
          lo = v
          hi = v
        } else if inner[dz] == ',' && dz + 1 == m {
          if v > 100000 {
            return None
          }
          lo = v
          hi = -1
        } else if inner[dz] == ',' {
          match parse_capped_digits(inner, dz + 1, m) {
            Some((w, dw)) =>
              if dw == m && v <= 100000 && w <= 100000 {
                if w < v {
                  // {n,0}: swap to {0,n} (probed); under ANY anchor the
                  // empty fallback is suppressed ('a{2,0}' on 'aaa' ->
                  // '#a#') — reject loudly (nonzero swaps unaffected)
                  if w == 0 {
                    if ws || we {
                      return None
                    }
                    lo = 0
                    hi = v
                  } else {
                    lo = w
                    hi = v
                  }
                } else if v == 0 {
                  lo = 0
                  hi = w
                } else {
                  lo = v
                  hi = w
                }
              } else {
                return None
              }
            None => return None
          }
        } else {
          return None
        }
      None =>
        // comma-open {,m} == {0,m}
        if m > 1 && inner[0] == ',' {
          match parse_capped_digits(inner, 1, m) {
            Some((w, dw)) =>
              if dw == m && w <= 100000 {
                lo = 0
                hi = w
              } else {
                return None
              }
            None => return None
          }
        } else {
          return None
        }
    }
  }
  // zero-min windows with an END anchor diverge from the empty-walk
  // model (HF backtracks greedy-then-empty per position: '\ba{0,2}\b'
  // on 'aab' -> '#aab#'; runs longer than the cap keep both edge
  // empties) and anchored {n,0} suppresses the empty fallback — both
  // are engine capabilities this family lacks, so reject them loudly
  // (probed 0.22.2; lo >= 1 windows and ws-only zero-min stay)
  // base resolution (class / literal / escaped)
  let base = base_sb.to_string()
  match bare_class_kind(base) {
    Some(kind) => Some((kind, None, lo, hi, ws, we))
    None => {
      let bc = base.to_array()
      if bc.length() == 2 && bc[0] == '\\' {
        let lit : Char? = match bc[1] {
          'n' => Some('\n')
          't' => Some('\t')
          'r' => Some('\r')
          _ => None
        }
        match lit {
          Some(c) => return Some((-1, Some(c), lo, hi, ws, we))
          None => return None
        }
      }
      if bc.length() == 1 && !is_regex_operator(bc[0]) && bc[0] != '\\' {
        return Some((-1, Some(bc[0]), lo, hi, ws, we))
      }
      None
    }
  }
}

///|
/// SINGLE-anchor windows `^BASE{n|n,m|n,}` / `BASE{...}$` (probed
/// 0.22.2): at each LINE start (or end) a block within the window,
/// greedy from the anchor — `^\w{1,2}` on 'abcdef\nabcdef' ->
/// '#cdef\n#cdef'; `\w{1,2}$` -> 'abcd#\nabcd#'; `{n,m}` blocks
/// greedily from the anchor (`^a{2,4}` on 'zaaaa' run of 4 mid-word:
/// no match — the anchor pins the block start to the line start, and
/// 'z' fails the pred). Zero-min forms reject (their empty-walk is
/// position-global, not anchor-pinned: '^a{0,2}' on 'zaaaz' ->
/// '#zaaaz' — an empty at EVERY non-adjacent position).
pub fn single_anchor_window_spec(
  pattern : String,
) -> (Int, Char?, Int, Int, Bool)? {
  let chars = pattern.to_array()
  let n = chars.length()
  if n < 5 || (chars[0] != '^' && chars[n - 1] != '$') {
    return None
  }
  let leading = chars[0] == '^' && chars[n - 1] != '$'
  let trailing = !leading && chars[n - 1] == '$'
  if !leading && !trailing {
    return None
  }
  let body_lo = if leading { 1 } else { 0 }
  let body_hi = if trailing { n - 1 } else { n }
  // BASE + brace at the end of the body
  let mut open = -1
  let mut i = body_lo
  while i < body_hi {
    if chars[i] == '{' {
      open = i
    }
    i = i + 1
  }
  if open < body_lo + 1 || chars[body_hi - 1] != '}' {
    return None
  }
  let base_sb = StringBuilder()
  let mut k = body_lo
  while k < open {
    base_sb.write_char(chars[k])
    k = k + 1
  }
  let base = base_sb.to_string()
  let inner : Array[Char] = []
  let mut j = open + 1
  while j < body_hi - 1 {
    inner.push(chars[j])
    j = j + 1
  }
  let m = inner.length()
  let mut lo : Int = 0
  let mut hi : Int = 0
  match parse_capped_digits(inner, 0, m) {
    Some((v, dz)) =>
      if dz == m {
        if v < 1 || v > 100000 {
          return None
        }
        lo = v
        hi = v
      } else if inner[dz] == ',' && dz + 1 == m {
        if v < 1 || v > 100000 {
          return None
        }
        lo = v
        hi = -1
      } else if inner[dz] == ',' {
        match parse_capped_digits(inner, dz + 1, m) {
          Some((w, dw)) =>
            if dw == m && v >= 1 && v <= 100000 && w <= 100000 {
              if w < v {
                if w == 0 {
                  return None // {n,0}: empty semantics, reject
                }
                lo = w
                hi = v
              } else {
                lo = v
                hi = w
              }
            } else {
              return None
            }
          None => return None
        }
      } else {
        return None
      }
    None => return None
  }
  match bare_class_kind(base) {
    Some(kind) =>
      if !leading && bounded_regex_kind_pred(kind, '\n') {
        // TRAILING nl-pred bases reject: line-end-anchored blocks over
        // newline-matching predicates diverge on consecutive-newline
        // inputs (probed: '\s{2}$' on 'a \n' -> 'a#' in HF, our
        // line-end model no-ops) — the double-anchor family's rule.
        // LEADING nl-pred bases stay (probed correct incl. runs
        // spanning newlines: '^\D{2}' on 'a\n\nb' -> '##').
        None
      } else {
        Some((kind, None, lo, hi, leading))
      }
    None => {
      let bc = base.to_array()
      if bc.length() == 2 && bc[0] == '\\' {
        let lit : Char? = match bc[1] {
          'n' =>
            if !leading {
              None // trailing '\n' base shares the nl-pred rejection
            } else {
              Some('\n')
            }
          't' => Some('\t')
          'r' => Some('\r')
          _ => None
        }
        match lit {
          Some(c) => return Some((-1, Some(c), lo, hi, leading))
          None => return None
        }
      }
      if bc.length() == 1 && !is_regex_operator(bc[0]) && bc[0] != '\\' {
        return Some((-1, Some(bc[0]), lo, hi, leading))
      }
      None
    }
  }
}

///|
/// Lazy-exact anchored spellings `[\b]BASE{n}?[\b]` (probed 0.22.2):
/// onig parses `X{n}?` as the OPTIONAL group `(X{n})?` — an exact-n
/// block when it fits the anchors, an EMPTY at anchor positions when
/// it does not ('\ba{2}?' on 'aaa' -> '#a#'; '\ba{2}?\b' on 'aaaa' ->
/// '#aaaa#' — the block fails the end anchor, both boundary empties
/// fire). Only EXACT {n}? — the range lazy forms ({n,m}?, {n,}?) are
/// plain lazy quantifiers without the empty fallback and reject.
pub fn boundary_lazy_exact_spec(
  pattern : String,
) -> (Int, Char?, Int, Bool, Bool)? {
  let chars = pattern.to_array()
  let n = chars.length()
  if n < 6 {
    return None
  }
  // the '?' sits right after the closing '}' — a trailing \b may
  // follow it ('\w{2}?\b'); strip the optional trailing \b first
  let has_trailing_b = chars[n - 1] == 'b' &&
    chars[n - 2] == '\\' &&
    !is_escaped_at(chars, n - 2)
  let cut = if has_trailing_b { n - 2 } else { n }
  if cut < 5 || chars[cut - 1] != '?' || chars[cut - 2] != '}' {
    return None
  }
  // reuse boundary_window_spec on the '?'-REMOVED pattern (keeping a
  // trailing \b so the we flag survives), then require the exact
  let stripped : Array[Char] = []
  let mut si = 0
  while si < cut - 1 {
    stripped.push(chars[si])
    si = si + 1
  }
  let mut ti = cut
  while ti < n {
    stripped.push(chars[ti])
    ti = ti + 1
  }
  let sb = StringBuilder()
  for c in stripped {
    sb.write_char(c)
  }
  match boundary_window_spec(sb.to_string()) {
    Some((kind, literal, lo, hi, ws, we)) =>
      if lo >= 1 && hi == lo {
        Some((kind, literal, lo, ws, we))
      } else {
        None // ranges: lazy quantifier, not the optional group
      }
    None => None
  }
}

///|
/// Non-boundary (\\B) windows: substitute \\B -> \\b and delegate to
/// boundary_window_spec for the parse (anchor flags carry the same
/// positions); the engine inverts every boundary test. Zero-min
/// RANGE rejection mirrors the \\b family.
pub fn nonboundary_window_spec(
  pattern : String,
) -> (Int, Char?, Int, Int, Bool, Bool)? {
  let chars = pattern.to_array()
  let n = chars.length()
  // 4 chars is the shortest live spelling ('\Ba+' since the plus
  // quantifier landed)
  if n < 4 {
    return None
  }
  // require at least one \\B anchor (backslash + 'B'); reject any bare \b
  let mut has_nb = false
  let mut i = 0
  while i < n {
    if chars[i] == '\\' && i + 1 < n && chars[i + 1] == 'B' {
      has_nb = true
    }
    if chars[i] == '\\' && i + 1 < n && chars[i + 1] == 'b' {
      return None
    }
    i = i + 1
  }
  if !has_nb {
    return None
  }
  // rewrite \\B -> \\b and delegate
  let sb = StringBuilder()
  let mut k = 0
  while k < n {
    if chars[k] == '\\' && k + 1 < n && chars[k + 1] == 'B' {
      sb.write_char('\\')
      sb.write_char('b')
      k = k + 2
    } else {
      sb.write_char(chars[k])
      k = k + 1
    }
  }
  match boundary_window_parse(sb.to_string(), false) {
    Some((kind, literal, lo, hi, ws, we)) => {
      // zero-min RANGES reject — the same walk-vs-scan divergence as
      // the \b family round-2 (HF restarts the greedy scan at each
      // anchor-failing position, the pre-filtered walk cannot:
      // '\B\w{0,2}' on 'zaaaz' -> 'z##' vs our 'za##'); exact {0}
      // stays (walk+filter verified: '\B\w{0}' on 'zaaz' ->
      // 'z#a#a#z', empties at every interior non-boundary)
      if (ws || we) && lo == 0 && hi != 0 {
        return None
      }
      Some((kind, literal, lo, hi, ws, we))
    }
    None => None
  }
}

///|
/// Non-boundary lazy-exact `\\Ba{2}?` / `a{2}?\\B` (probed: same
/// optional-group semantics with the inverted predicate).
pub fn nonboundary_lazy_exact_spec(
  pattern : String,
) -> (Int, Char?, Int, Bool, Bool)? {
  let chars = pattern.to_array()
  let n = chars.length()
  if n < 6 {
    return None
  }
  let mut has_nb = false
  let mut i = 0
  while i < n {
    if chars[i] == '\\' && i + 1 < n && chars[i + 1] == 'B' {
      has_nb = true
    }
    if chars[i] == '\\' && i + 1 < n && chars[i + 1] == 'b' {
      return None
    }
    i = i + 1
  }
  if !has_nb {
    return None
  }
  let sb = StringBuilder()
  let mut k = 0
  while k < n {
    if chars[k] == '\\' && k + 1 < n && chars[k + 1] == 'B' {
      sb.write_char('\\')
      sb.write_char('b')
      k = k + 2
    } else {
      sb.write_char(chars[k])
      k = k + 1
    }
  }
  boundary_lazy_exact_spec(sb.to_string())
}

///|
/// Mixed-anchor windows `\\bX{n|n,m|n,|+}\\B` / `\\BX{...}\\b` (probed
/// 0.22.2): the start is gated by one anchor kind, the block runs
/// greedy within the window, then shrinks one char at a time until the
/// OTHER kind holds at the end ('\\ba{2,4}\\B' on 'aaaa' -> '#a':
/// greedy 4 ends on the EOS boundary, 3 lands on the interior
/// non-boundary). Same-kind pairs stay with the \\b / \\B families;
/// zero-min rejects (the walk-vs-scan divergence — and a mixed {0}
/// asserts \\b and \\B at one position, which never holds).
pub fn mixed_anchor_window_spec(
  pattern : String,
) -> (Int, Char?, Int, Int, Bool, Bool)? {
  let chars = pattern.to_array()
  let n = chars.length()
  if n < 6 {
    return None
  }
  if chars[0] != '\\' || (chars[1] != 'b' && chars[1] != 'B') {
    return None
  }
  let trail_ok = chars[n - 2] == '\\' &&
    (chars[n - 1] == 'b' || chars[n - 1] == 'B') &&
    !is_escaped_at(chars, n - 2)
  if !trail_ok {
    return None
  }
  let lead_nb = chars[1] == 'B'
  let trail_nb = chars[n - 1] == 'B'
  if lead_nb == trail_nb {
    return None
  }
  // no stray anchor inside the body (the rewrite below would corrupt
  // it into a leading/trailing marker)
  let mut i = 2
  while i < n - 2 {
    if chars[i] == '\\' &&
      i + 1 < n - 2 &&
      (chars[i + 1] == 'b' || chars[i + 1] == 'B') {
      return None
    }
    i = i + 1
  }
  // rewrite \B -> \b and delegate for the base/quantifier parse
  let sb = StringBuilder()
  let mut k = 0
  while k < n {
    if chars[k] == '\\' && k + 1 < n && chars[k + 1] == 'B' {
      sb.write_char('\\')
      sb.write_char('b')
      k = k + 2
    } else {
      sb.write_char(chars[k])
      k = k + 1
    }
  }
  match boundary_window_parse(sb.to_string(), !trail_nb) {
    Some((kind, literal, lo, hi, _ws, _we)) =>
      if lo == 0 {
        None
      } else {
        Some((kind, literal, lo, hi, lead_nb, trail_nb))
      }
    None => None
  }
}
