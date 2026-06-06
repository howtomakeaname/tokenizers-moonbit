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
    StripAccents => strip_accents(input)
    Prepend(prepend~) => prepend + input
    Replace(pattern~, content~) => replace_all(input, pattern, content)
    Sequence(steps) => {
      let mut s = input
      for step in steps {
        s = step.normalize(s)
      }
      s
    }
    BertNormalizer(clean_text~, handle_chinese_chars~, strip_accents=sa, lowercase~) => {
      let mut s = input
      if clean_text {
        s = bert_clean_text(s)
      }
      if handle_chinese_chars {
        s = bert_pad_chinese(s)
      }
      if sa {
        s = strip_accents(s)
      }
      if lowercase {
        s = to_lowercase(s)
      }
      s
    }
    // NFC/NFD/NFKC/NFKD/Precompiled: identity until full tables land (TODO).
    _ => input
  }
}

// strip_accents: remove combining marks via the precomputed NFD-minus-Mn table.
fn strip_accents(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    match accent_map().get(c.to_int()) {
      Some(stripped) => sb.write_string(stripped)
      None => sb.write_char(c)
    }
  }
  sb.to_string()
}

// Lazily-built map: code point -> accent-stripped form.
let accent_map_cache : Ref[Map[Int, String]?] = { val: None }

fn accent_map() -> Map[Int, String] {
  match accent_map_cache.val {
    Some(m) => m
    None => {
      let m : Map[Int, String] = {}
      for e in accent_entries() {
        m[e.0] = e.1
      }
      accent_map_cache.val = Some(m)
      m
    }
  }
}

// BertNormalizer clean_text: drop control chars and 0xFFFD, map whitespace to
// a single space.
fn bert_clean_text(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    let u = c.to_int()
    if u == 0 || u == 0xFFFD || is_control(c) {
      continue
    }
    if is_ws(c) {
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

// BertNormalizer handle_chinese_chars: surround each CJK char with spaces.
fn bert_pad_chinese(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    if is_chinese_char(c) {
      sb.write_char(' ')
      sb.write_char(c)
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

fn is_control(c : Char) -> Bool {
  // \t \n \r are treated as whitespace, not control, by BERT.
  if c == '\t' || c == '\n' || c == '\r' {
    return false
  }
  let u = c.to_int()
  (u >= 0 && u < 0x20) || u == 0x7F
}

fn is_chinese_char(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x4E00 && u <= 0x9FFF) ||
  (u >= 0x3400 && u <= 0x4DBF) ||
  (u >= 0x20000 && u <= 0x2A6DF) ||
  (u >= 0xF900 && u <= 0xFAFF)
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
