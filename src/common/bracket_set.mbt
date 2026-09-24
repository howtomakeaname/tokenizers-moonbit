///|
/// One member of a general bracket character class.
pub(all) enum BracketMember {
  /// Shortcut class member — CLASS-context kinds: `\w` inside brackets
  /// is the quirk-free word table (26, probed: '[a\w]' on 'a²b' ->
  /// '#²#' while bare '\w' matches '²'), `\d` 11, `\s` 1, `\p{...}` 7+
  MKind(Int)
  /// Single literal char (escaped or raw)
  MChar(Char)
  /// Inclusive literal range a-z (reversed ranges reject: onig raises
  /// 'empty range in char class' on '[c-a]')
  MRange(Char, Char)
}

///|
fn bracket_shortcut_kind(spelling : String) -> Int? {
  match spelling {
    "\\w" => Some(26)
    "\\W" => Some(27)
    "\\d" => Some(11)
    "\\D" => Some(14)
    "\\s" => Some(1)
    "\\S" => Some(12)
    "\\p{L}" | "\\p{Letter}" => Some(7)
    "\\P{L}" | "\\P{Letter}" => Some(17)
    "\\p{N}" | "\\p{Number}" => Some(28)
    "\\P{N}" | "\\P{Number}" => Some(29)
    "\\p{P}" | "\\p{Punctuation}" => Some(8)
    "\\P{P}" | "\\P{Punctuation}" => Some(18)
    "\\p{S}" | "\\p{Symbol}" => Some(9)
    "\\P{S}" | "\\P{Symbol}" => Some(19)
    _ => None
  }
}

///|
/// An escaped single char inside a class: control escapes plus the
/// punctuation that must be escaped to be literal; anything else
/// rejects loudly (unknown onig escape semantics).
fn bracket_escaped_literal(c : Char) -> Char? {
  match c {
    'n' => Some('\n')
    't' => Some('\t')
    'r' => Some('\r')
    '-'
    | ']'
    | '['
    | '^'
    | '\\'
    | '.'
    | '*'
    | '+'
    | '?'
    | '('
    | ')'
    | '{'
    | '}'
    | '|'
    | '$'
    | '/'
    | '#'
    | '&'
    | '~' => Some(c)
    _ => None
  }
}

///|
fn member_holds(m : BracketMember, c : Char) -> Bool {
  match m {
    MKind(k) => bounded_regex_kind_pred(k, c)
    MChar(x) => c == x
    MRange(lo, hi) => c >= lo && c <= hi
  }
}

///|
/// The composed per-char predicate of a parsed bracket set.
pub fn bracket_set_holds(
  members : Array[BracketMember],
  negated : Bool,
  c : Char,
) -> Bool {
  let mut any = false
  for m in members {
    if member_holds(m, c) {
      any = true
      break
    }
  }
  if negated {
    !any
  } else {
    any
  }
}

///|
/// Parse the body of `[...]` at [start, close) into members + the
/// negation flag. A leading '-' or a '-' right before ']' is a
/// literal (probed: '[-a]' == '[a-]'); a '-' between two elements is
/// a range operator whose endpoints must be literals (shortcut
/// endpoints are onig load errors — '[\d-a]').
fn bracket_body_members(
  chars : Array[Char],
  start : Int,
  close : Int,
) -> (Array[BracketMember], Bool)? {
  let negated = start < close && chars[start] == '^'
  let mut i = if negated { start + 1 } else { start }
  if i >= close {
    return None // '[]' / '[^]' are not valid classes
  }
  let members : Array[BracketMember] = []
  while i < close {
    // one element: shortcut | escaped char | raw literal
    let first = chars[i]
    if first == '\\' {
      // shortcut spelling: \w \p{L} ... (bounded length scan)
      let mut j = i + 1
      if j >= close {
        return None
      }
      let spelling = StringBuilder()
      spelling.write_char('\\')
      spelling.write_char(chars[j])
      let mut is_shortcut = false
      match chars[j] {
        'w' | 'W' | 'd' | 'D' | 's' | 'S' => is_shortcut = true
        'p' | 'P' =>
          // \p{Name} — copy up to the closing '}'
          if j + 1 < close && chars[j + 1] == '{' {
            spelling.write_char('{')
            let mut k = j + 2
            while k < close && chars[k] != '}' {
              spelling.write_char(chars[k])
              k = k + 1
            }
            if k >= close {
              return None
            }
            spelling.write_char('}')
            is_shortcut = true
            j = k
          } else {
            return None
          }
        _ => ()
      }
      if is_shortcut {
        match bracket_shortcut_kind(spelling.to_string()) {
          Some(kind) => {
            members.push(MKind(kind))
            i = j + 1
            // '[\d-a]': an unescaped '-' right after a shortcut and
            // before another element is a RANGE with a shortcut start
            // — onig load-errors ('unmatched range specifier'); a
            // trailing '-' or an escaped '\-' stays a literal union
            if i < close - 1 && chars[i] == '-' {
              return None
            }
            continue
          }
          None => return None
        }
      }
      match bracket_escaped_literal(chars[j]) {
        Some(c) => {
          members.push(MChar(c))
          i = j + 1
          continue
        }
        None => return None
      }
    }
    if first == ']' || first == '[' {
      return None
    }
    // raw '&&' is onig char-class INTERSECTION ('[a-w&&c-z]' — a
    // different operator, probed: HF computes intersections while a
    // union parse silently diverges) — reject loudly; an escaped '\&'
    // stays a literal member
    if first == '&' && i + 1 < close && chars[i + 1] == '&' {
      return None
    }
    members.push(MChar(first))
    i = i + 1
  }
  // second pass: fold 'lit - lit' triples into ranges
  let out : Array[BracketMember] = []
  let mut k = 0
  while k < members.length() {
    let fold : (Char, Char)? = if k + 2 < members.length() {
      match (members[k], members[k + 1], members[k + 2]) {
        (MChar(lo), MChar('-'), MChar(hi)) => Some((lo, hi))
        // '[a-\d]': range with a shortcut END is an onig load error
        (MChar(_), MChar('-'), MKind(_)) => return None
        _ => None
      }
    } else {
      None
    }
    match fold {
      Some((lo, hi)) => {
        if hi < lo {
          return None // onig: empty range in char class
        }
        out.push(MRange(lo, hi))
        k = k + 3
      }
      None => {
        out.push(members[k])
        k = k + 1
      }
    }
  }
  Some((out, negated))
}

///|
/// General bracket character-class spec `[members]{quant?}` (probed
/// 0.22.2): literals, literal ranges, escaped literals and CLASS-
/// context shortcut classes union into one per-char predicate; `^`
/// complements (the complement INCLUDES '\n': '[^a]' on 'ab\ncd' ->
/// 'a####'). Quantifiers: none == (1,1) per-char, `{n}`/`{n,m}`/
/// `{n,}`/`+` (reversed `{n,m}` swaps like the class windows), the
/// lazy `+?` == (1,1) — one char per position, and the zero-min
/// forms `{0}`/`{0,m}`/`{0,}`/`?`/`*` which ride the empty walk
/// ('[abc]{0}' on 'xay' -> '#x#a#y#'). Lazy brace tails reject.
/// Single-shortcut-only bodies ('[\w]', '[^\s]') stay with the
/// canonical kind spellings and reject here to avoid double-claiming.
pub fn bracket_set_spec(
  pattern : String,
) -> (Array[BracketMember], Bool, Int, Int, Bool)? {
  let chars = pattern.to_array()
  let n = chars.length()
  if n < 3 || chars[0] != '[' {
    return None
  }
  // find the first unescaped ']'
  let mut close = -1
  let mut i = 1
  while i < n {
    if chars[i] == '\\' {
      i = i + 2
      continue
    }
    if chars[i] == ']' {
      close = i
      break
    }
    i = i + 1
  }
  if close < 0 || close == 1 {
    return None
  }
  let (members, negated) = match bracket_body_members(chars, 1, close) {
    Some(v) => v
    None => return None
  }
  // single-shortcut bodies belong to the canonical kind spellings
  if members.length() == 1 && members[0] is MKind(_) {
    return None
  }
  // quantifier after ']'
  let q = close + 1
  let mut lo : Int = 1
  let mut hi : Int = 1
  if q < n {
    // lazy exact '{n}?' == the optional group (X{n})?: the block
    // when it fits, an empty otherwise — the '+??' rewrite lands here
    // at n == 1 (probed == the {0,1} walk). Rides the shared
    // lazy_ranged_or_empty engine with the composed set pred
    if q < n - 3 &&
      chars[q] == '{' &&
      chars[n - 2] == '}' &&
      chars[n - 1] == '?' {
      let inner2 : Array[Char] = []
      let mut t2 = q + 1
      while t2 < n - 2 {
        inner2.push(chars[t2])
        t2 = t2 + 1
      }
      let m2 = inner2.length()
      match parse_capped_digits(inner2, 0, m2) {
        Some((v, dz)) =>
          if dz == m2 && v >= 1 && v <= 100000 {
            return Some((members, negated, v, v, true))
          }
        None => ()
      }
      return None
    }
    if chars[n - 1] == '}' {
      let mut open = -1
      let mut j = q
      while j < n {
        if chars[j] == '{' {
          open = j
        }
        j = j + 1
      }
      if open != q {
        return None
      }
      let inner : Array[Char] = []
      let mut t = open + 1
      while t < n - 1 {
        inner.push(chars[t])
        t = t + 1
      }
      let m = inner.length()
      match parse_capped_digits(inner, 0, m) {
        Some((v, dz)) =>
          if dz == m {
            if v > 100000 {
              return None
            }
            lo = v // {0} rides the empty walk like the class family
            hi = v
          } else if inner[dz] == ',' && dz + 1 == m {
            if v > 100000 {
              return None
            }
            lo = v // {0,} == (0, unbounded) empty walk
            hi = -1
          } else if inner[dz] == ',' {
            match parse_capped_digits(inner, dz + 1, m) {
              Some((w, dw)) =>
                if dw == m && v <= 100000 && w <= 100000 {
                  if w < v {
                    // {n,0} == {0,n} for sets (probed: '[a\w]{2,0}' ==
                    // '[a\w]{,2}' == the {0,2} empty walk); NONZERO
                    // reversed bounds keep the window swap (probed:
                    // '[a\w]{2,1}' == '[a\w]{1,2}' — round-1 review
                    // caught this branch clobbering them)
                    if w == 0 {
                      lo = 0
                    } else {
                      lo = w
                    }
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
        None =>
          // comma-open '{,m}' == {0,m} (probed, the sibling family's
          // rule)
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
    } else if q == n - 1 && chars[q] == '+' {
      lo = 1
      hi = -1
    } else if q == n - 2 && chars[q] == '+' && chars[n - 1] == '?' {
      lo = 1 // lazy plus == one char per position (probed)
      hi = 1
    } else if q == n - 1 && chars[q] == '?' {
      lo = 0 // optional == {0,1} empty walk (probed)
      hi = 1
    } else if q == n - 1 && chars[q] == '*' {
      lo = 0 // star == {0,} empty walk (probed)
      hi = -1
    } else {
      return None
    }
  }
  Some((members, negated, lo, hi, false))
}
