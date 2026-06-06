// GPT-2 pre-tokenization scanner.
//
// HuggingFace's ByteLevel(use_regex=true) splits text with this pattern:
//   's|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+
//
// MoonBit's core regex does not support \p{L}/\p{N}, so we hand-write an
// equivalent scanner over code points. `is_letter`/`is_number` use coarse
// Unicode ranges covering the common scripts (Latin, CJK, Greek, Cyrillic,
// Hiragana/Katakana, Hangul, digits). Rare scripts are TODO.

/// Split text into GPT-2 pre-tokens (as raw substrings, before byte-level map).
pub fn gpt2_split(text : String) -> Array[String] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[String] = []
  let mut i = 0
  while i < n {
    // 1) contraction tokens: 's 't 're 've 'm 'll 'd
    let contr = match_contraction(chars, i, n)
    if contr > 0 {
      out.push(slice(chars, i, i + contr))
      i = i + contr
      continue
    }
    let c = chars[i]
    // 2) optional single leading space + letters:  ?\p{L}+
    // 3) optional single leading space + numbers:  ?\p{N}+
    // 4) optional single leading space + others:   ?[^\s\p{L}\p{N}]+
    if c == ' ' && i + 1 < n && !is_space(chars[i + 1]) {
      let next = chars[i + 1]
      let mut j = i + 1
      if is_letter(next) {
        while j < n && is_letter(chars[j]) {
          j = j + 1
        }
      } else if is_number(next) {
        while j < n && is_number(chars[j]) {
          j = j + 1
        }
      } else {
        // other (non-space, non-letter, non-number)
        while j < n && !is_space(chars[j]) && !is_letter(chars[j]) && !is_number(chars[j]) {
          j = j + 1
        }
      }
      out.push(slice(chars, i, j))
      i = j
      continue
    }
    if is_letter(c) {
      let mut j = i
      while j < n && is_letter(chars[j]) {
        j = j + 1
      }
      out.push(slice(chars, i, j))
      i = j
      continue
    }
    if is_number(c) {
      let mut j = i
      while j < n && is_number(chars[j]) {
        j = j + 1
      }
      out.push(slice(chars, i, j))
      i = j
      continue
    }
    if !is_space(c) {
      // [^\s\p{L}\p{N}]+
      let mut j = i
      while j < n && !is_space(chars[j]) && !is_letter(chars[j]) && !is_number(chars[j]) {
        j = j + 1
      }
      out.push(slice(chars, i, j))
      i = j
      continue
    }
    // 5) whitespace: \s+(?!\S) | \s+
    // Grab a run of spaces; if it is NOT at end-of-text, leave the last space
    // to attach to the following token (the negative-lookahead behaviour).
    let mut j = i
    while j < n && is_space(chars[j]) {
      j = j + 1
    }
    if j < n && j - i > 1 {
      // there is a following non-space token: emit all but the last space
      out.push(slice(chars, i, j - 1))
      i = j - 1
    } else {
      out.push(slice(chars, i, j))
      i = j
    }
  }
  out
}

// Match a contraction at position i; returns its char length or 0.
fn match_contraction(chars : Array[Char], i : Int, n : Int) -> Int {
  if i >= n || chars[i] != '\'' {
    return 0
  }
  fn at(k : Int) -> Char {
    if i + k < n {
      chars[i + k]
    } else {
      '\u{0}'
    }
  }
  let c1 = at(1)
  let c2 = at(2)
  // 's 't 'm 'd
  if c1 == 's' || c1 == 't' || c1 == 'm' || c1 == 'd' {
    return 2
  }
  // 're 've 'll
  if (c1 == 'r' && c2 == 'e') ||
    (c1 == 'v' && c2 == 'e') ||
    (c1 == 'l' && c2 == 'l') {
    return 3
  }
  0
}

fn slice(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

// --- character class predicates ---

/// Whitespace per Unicode \s (common ones).
pub fn is_space(c : Char) -> Bool {
  let u = c.to_int()
  u == 0x20 ||
  (u >= 0x09 && u <= 0x0D) || // tab, LF, VT, FF, CR
  u == 0x85 ||
  u == 0xA0 ||
  u == 0x1680 ||
  (u >= 0x2000 && u <= 0x200A) ||
  u == 0x2028 ||
  u == 0x2029 ||
  u == 0x202F ||
  u == 0x205F ||
  u == 0x3000
}

/// Decimal-number-ish (Unicode \p{N}, approximated by common ranges).
pub fn is_number(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x30 && u <= 0x39) || // ASCII 0-9
  (u >= 0x0660 && u <= 0x0669) || // Arabic-Indic
  (u >= 0x06F0 && u <= 0x06F9) || // Extended Arabic-Indic
  (u >= 0x0966 && u <= 0x096F) || // Devanagari
  (u >= 0xFF10 && u <= 0xFF19) // Fullwidth
}

/// Letter (Unicode \p{L}), approximated by common script ranges.
pub fn is_letter(c : Char) -> Bool {
  let u = c.to_int()
  // ASCII letters
  if (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) {
    return true
  }
  // Latin-1 letters + supplements
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
  // Hebrew
  if u >= 0x590 && u <= 0x5FF {
    return true
  }
  // Arabic letters
  if u >= 0x620 && u <= 0x64A {
    return true
  }
  // Hiragana + Katakana
  if u >= 0x3040 && u <= 0x30FF {
    return true
  }
  // CJK Unified Ideographs
  if u >= 0x4E00 && u <= 0x9FFF {
    return true
  }
  // Hangul syllables
  if u >= 0xAC00 && u <= 0xD7A3 {
    return true
  }
  // CJK Extension A
  if u >= 0x3400 && u <= 0x4DBF {
    return true
  }
  false
}

// The Qwen2/Qwen3/Llama-3 family pre-tokenization pattern (also used by
// DeepSeek-V3 etc.). It differs from GPT-2's in several ways:
//   (?i:'s|'t|'re|'ve|'m|'ll|'d)            -- case-insensitive contractions
//   |[^\r\n\p{L}\p{N}]?\p{L}+               -- letters, optionally prefixed by a
//                                              single non-letter/digit/newline
//   |\p{N}                                  -- a SINGLE digit (not a run)
//   | ?[^\s\p{L}\p{N}]+[\r\n]*              -- punctuation run + trailing newlines
//   |\s*[\r\n]+                             -- blank lines
//   |\s+(?!\S)|\s+                          -- trailing / interior whitespace
//
// As with gpt2_split, each leftmost match becomes one piece (Split + Isolated).
pub fn qwen_split(text : String) -> Array[String] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[String] = []
  let mut i = 0
  while i < n {
    // 1) case-insensitive contraction 's 't 're 've 'm 'll 'd
    let contr = match_contraction_ci(chars, i, n)
    if contr > 0 {
      out.push(slice(chars, i, i + contr))
      i = i + contr
      continue
    }
    let c = chars[i]
    // 2) [^\r\n\p{L}\p{N}]? \p{L}+  : letters with an optional single non-LN
    //    prefix char (that prefix may itself be a space or punctuation, but not
    //    a newline). Try: optional one prefix char if the next char is a letter.
    if !is_letter(c) && c != '\r' && c != '\n' && !is_number(c) {
      if i + 1 < n && is_letter(chars[i + 1]) {
        let mut j = i + 1
        while j < n && is_letter(chars[j]) {
          j = j + 1
        }
        out.push(slice(chars, i, j))
        i = j
        continue
      }
    }
    if is_letter(c) {
      let mut j = i
      while j < n && is_letter(chars[j]) {
        j = j + 1
      }
      out.push(slice(chars, i, j))
      i = j
      continue
    }
    // 3) \p{N} : a single digit
    if is_number(c) {
      out.push(slice(chars, i, i + 1))
      i = i + 1
      continue
    }
    // 4)  ?[^\s\p{L}\p{N}]+[\r\n]*  : optional leading space, punctuation run,
    //    then any trailing \r\n characters.
    let has_sp_prefix = c == ' ' &&
      i + 1 < n &&
      !is_space(chars[i + 1]) &&
      !is_letter(chars[i + 1]) &&
      !is_number(chars[i + 1])
    let punct_start = if has_sp_prefix { i + 1 } else { i }
    if punct_start < n &&
      !is_space(chars[punct_start]) &&
      !is_letter(chars[punct_start]) &&
      !is_number(chars[punct_start]) {
      let mut j = punct_start
      while j < n && !is_space(chars[j]) && !is_letter(chars[j]) && !is_number(chars[j]) {
        j = j + 1
      }
      // [\r\n]*
      while j < n && (chars[j] == '\r' || chars[j] == '\n') {
        j = j + 1
      }
      out.push(slice(chars, i, j))
      i = j
      continue
    }
    // 5) \s*[\r\n]+ : run of whitespace ending in newlines. Gather whitespace;
    //    if it contains a newline, emit through the last newline.
    if is_space(c) {
      let mut j = i
      while j < n && is_space(chars[j]) {
        j = j + 1
      }
      // find last newline in [i, j)
      let mut last_nl = -1
      for k in i..<j {
        if chars[k] == '\r' || chars[k] == '\n' {
          last_nl = k
        }
      }
      if last_nl >= 0 {
        out.push(slice(chars, i, last_nl + 1))
        i = last_nl + 1
        continue
      }
      // 6) \s+(?!\S) | \s+ : trailing-aware whitespace (same as GPT-2).
      if j < n && j - i > 1 {
        out.push(slice(chars, i, j - 1))
        i = j - 1
      } else {
        out.push(slice(chars, i, j))
        i = j
      }
      continue
    }
    // Fallback (should not happen): consume one char.
    out.push(slice(chars, i, i + 1))
    i = i + 1
  }
  out
}

// Case-insensitive contraction match (Qwen uses (?i:...)).
fn match_contraction_ci(chars : Array[Char], i : Int, n : Int) -> Int {
  if i >= n || chars[i] != '\'' {
    return 0
  }
  fn lower(k : Int) -> Char {
    if i + k < n {
      chars[i + k].to_ascii_lowercase()
    } else {
      '\u{0}'
    }
  }
  let c1 = lower(1)
  let c2 = lower(2)
  if c1 == 's' || c1 == 't' || c1 == 'm' || c1 == 'd' {
    return 2
  }
  if (c1 == 'r' && c2 == 'e') ||
    (c1 == 'v' && c2 == 'e') ||
    (c1 == 'l' && c2 == 'l') {
    return 3
  }
  0
}
