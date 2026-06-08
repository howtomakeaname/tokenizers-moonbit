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
  let sb = StringBuilder::new()
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
  let sb = StringBuilder::new()
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
  let sb = StringBuilder::new()
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
  let sb = StringBuilder::new()
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
  let sb = StringBuilder::new()
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
  let sb = StringBuilder::new()
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
  let sb = StringBuilder::new()
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
  let sb = StringBuilder::new()
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
pub fn replace_space_runs(
  s : String,
  content : String,
  min_run~ : Int,
) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder::new()
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
