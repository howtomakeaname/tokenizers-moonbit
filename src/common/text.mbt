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
  // single-char literal bounded quantifiers within the 1..4 window
  if char_bounded_quantifier_shape(pattern) {
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
/// Whether `pattern` is `c{n}` / `c{n,}` / `c{n,m}` for an ordinary
/// literal char with 1 <= n <= m <= 4 (the supported bounded window).
pub fn char_bounded_quantifier_shape(pattern : String) -> Bool {
  let chars = pattern.to_array()
  let n = chars.length()
  if n < 4 || chars[1] != '{' || chars[n - 1] != '}' {
    return false
  }
  let c = chars[0]
  // metacharacters are excluded: `.{n}` is any-char in HF and
  // `?{n}`/`+{n}`/etc. are construction errors there — both must not
  // load here as literal runs
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
    return false
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
    return false
  }
  if i < n && chars[i] == ',' {
    i = i + 1
    if i == n - 1 {
      return true // {n,}
    }
    let mut hi = 0
    let mut hi_digits = 0
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      hi = hi * 10 + (chars[i].to_int() - '0'.to_int())
      hi_digits = hi_digits + 1
      i = i + 1
    }
    return hi_digits > 0 && hi >= lo && hi <= 4 && i == n - 1
  }
  i == n - 1
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
  // inner must be "0" or "0," or "0,<digits>"
  if chars[open + 1] != '0' {
    return None
  }
  let max : Int = if open + 2 == n - 1 {
    0 // {0}
  } else if chars[open + 2] != ',' {
    return None
  } else if open + 3 == n - 1 {
    -1 // {0,} unbounded
  } else {
    // {0,m}: onig rejects repeat bounds above 100000 ("too big number for
    // repeat range", probed 0.22.2: `a{0,100000}` loads, `a{0,100001}`
    // errors), so the spec stops matching there and the load gate raises.
    let mut v = 0
    let mut k = open + 3
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
      if bc.length() == 1 && !is_regex_operator(bc[0]) && bc[0] != '\\' {
        Some((-1, Some(bc[0]), max))
      } else {
        None
      }
    }
  }
}
