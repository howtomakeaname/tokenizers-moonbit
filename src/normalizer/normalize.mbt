// Normalization behaviour: text -> normalized text.
//
// P3 scope: enough to make GPT-2 work (which has a null normalizer). The
// simple variants are implemented here; NFC/NFD/NFKC/NFKD act as identity
// until a Unicode normalization table is added (TODO, see plan P7/risks).

/// Apply this normalizer to a string.
pub fn Normalizer::normalize(self : Normalizer, input : String) -> String {
  match self {
    Lowercase => to_lowercase(input)
    Strip(left~, right~) => strip(input, left, right)
    Prepend(prepend~) => prepend + input
    Replace(pattern~, content~) => replace_all(input, pattern, content)
    Sequence(steps) => {
      let mut s = input
      for step in steps {
        s = step.normalize(s)
      }
      s
    }
    // BertNormalizer: lowercase handled here; clean_text/accents are TODO.
    BertNormalizer(lowercase~, ..) => if lowercase { to_lowercase(input) } else { input }
    // NFC/NFD/NFKC/NFKD/StripAccents: identity until Unicode tables land (TODO).
    _ => input
  }
}

fn to_lowercase(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    sb.write_char(c.to_ascii_lowercase())
  }
  sb.to_string()
}

fn strip(s : String, left : Bool, right : Bool) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let mut start = 0
  let mut stop = n
  if left {
    while start < stop && is_ws(chars[start]) {
      start = start + 1
    }
  }
  if right {
    while stop > start && is_ws(chars[stop - 1]) {
      stop = stop - 1
    }
  }
  let sb = StringBuilder::new()
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

fn is_ws(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

// Literal substring replacement (HF "Replace" with a String pattern).
fn replace_all(s : String, pattern : String, content : String) -> String {
  if pattern.is_empty() {
    return s
  }
  let pat = pattern.to_array()
  let src = s.to_array()
  let n = src.length()
  let m = pat.length()
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

fn matches_at(src : Array[Char], at : Int, pat : Array[Char]) -> Bool {
  for k in 0..<pat.length() {
    if src[at + k] != pat[k] {
      return false
    }
  }
  true
}
