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
  // the literal path.
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
