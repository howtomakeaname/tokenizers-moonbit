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

/// Split text with CLIP's regex:
///   <\|startoftext\|>|<\|endoftext\|>|'s|'t|'re|'ve|'m|'ll|'d|
///   [\p{L}]+|[\p{N}]|[^\s\p{L}\p{N}]+
///
/// This differs from GPT-2 by not attaching leading spaces to following words
/// and by emitting single digits. Whitespace is removed by the Split stage.
pub fn clip_split(text : String) -> Array[String] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[String] = []
  let mut i = 0
  while i < n {
    if is_space(chars[i]) {
      i = i + 1
      continue
    }
    let special = match_clip_special(chars, i, n)
    if special > 0 {
      out.push(slice(chars, i, i + special))
      i = i + special
      continue
    }
    let contr = match_contraction(chars, i, n)
    if contr > 0 {
      out.push(slice(chars, i, i + contr))
      i = i + contr
      continue
    }
    let c = chars[i]
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
      out.push(slice(chars, i, i + 1))
      i = i + 1
      continue
    }
    let mut j = i
    while j < n && !is_space(chars[j]) && !is_letter(chars[j]) && !is_number(chars[j]) {
      j = j + 1
    }
    out.push(slice(chars, i, j))
    i = j
  }
  out
}

fn match_clip_special(chars : Array[Char], i : Int, n : Int) -> Int {
  if matches_literal(chars, i, n, "<|startoftext|>") {
    return 15
  }
  if matches_literal(chars, i, n, "<|endoftext|>") {
    return 13
  }
  0
}

fn matches_literal(chars : Array[Char], i : Int, n : Int, lit : String) -> Bool {
  let pat = lit.to_array()
  if i + pat.length() > n {
    return false
  }
  for k in 0..<pat.length() {
    if chars[i + k] != pat[k] {
      return false
    }
  }
  true
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
  qwen_split_max_digits(text, max_digits=1)
}

pub fn qwen_split_max_digits(text : String, max_digits~ : Int) -> Array[String] {
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
    // 3) \p{N} / \p{N}{1,3}: one digit or a bounded digit chunk.
    if is_number(c) {
      let mut j = i
      let mut count = 0
      while j < n && is_number(chars[j]) && count < max_digits {
        j = j + 1
        count = count + 1
      }
      out.push(slice(chars, i, j))
      i = j
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

// Split text with the o200k-style pattern used by GPT-OSS / Phi-4-mini:
//   [^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]*
//     [\p{Ll}\p{Lm}\p{Lo}\p{M}]+(?i:'s|'t|'re|'ve|'m|'ll|'d)?
// | [^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]+
//     [\p{Ll}\p{Lm}\p{Lo}\p{M}]*(?i:'s|'t|'re|'ve|'m|'ll|'d)?
// | \p{N}{1,3}
// |  ?[^\s\p{L}\p{N}]+[\r\n/]*
// | \s*[\r\n]+ | \s+(?!\S) | \s+
//
// The important difference from the Qwen/Llama-3 scanner is that contractions
// are an optional suffix of a letter token. For example, HF pre-tokenizes
// "I'm" as one piece, not as "I" + "'m".
pub fn o200k_split(text : String) -> Array[String] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[String] = []
  let mut i = 0
  while i < n {
    let letter_len = match_o200k_letter_piece(chars, i, n)
    if letter_len > 0 {
      out.push(slice(chars, i, i + letter_len))
      i = i + letter_len
      continue
    }
    let c = chars[i]
    if is_number(c) {
      let mut j = i
      let mut count = 0
      while j < n && is_number(chars[j]) && count < 3 {
        j = j + 1
        count = count + 1
      }
      out.push(slice(chars, i, j))
      i = j
      continue
    }
    // Optional leading space + punctuation run + trailing CR/LF/slash.
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
      while j < n && (chars[j] == '\r' || chars[j] == '\n' || chars[j] == '/') {
        j = j + 1
      }
      out.push(slice(chars, i, j))
      i = j
      continue
    }
    if is_space(c) {
      let mut j = i
      while j < n && is_space(chars[j]) {
        j = j + 1
      }
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
      if j < n && j - i > 1 {
        out.push(slice(chars, i, j - 1))
        i = j - 1
      } else {
        out.push(slice(chars, i, j))
        i = j
      }
      continue
    }
    out.push(slice(chars, i, i + 1))
    i = i + 1
  }
  out
}

fn match_o200k_letter_piece(chars : Array[Char], i : Int, n : Int) -> Int {
  let has_prefix = !is_letter(chars[i]) &&
    chars[i] != '\r' &&
    chars[i] != '\n' &&
    !is_number(chars[i]) &&
    i + 1 < n &&
    is_o200k_letter_class(chars[i + 1])
  let start = if has_prefix { i + 1 } else { i }
  if start >= n || !is_o200k_letter_class(chars[start]) {
    return 0
  }

  // First alternative: upper/title/modifier/other/mark* then lower/modifier/
  // other/mark+. This groups TitleCase/camel-case words like "Hello".
  let mut j = start
  while j < n && is_o200k_upper_prefix_class(chars[j]) {
    j = j + 1
  }
  let lower_start = j
  while j < n && is_o200k_lower_tail_class(chars[j]) {
    j = j + 1
  }
  if j > lower_start {
    let c = match_contraction_ci(chars, j, n)
    return (j + c) - i
  }

  // Second alternative: upper/title/modifier/other/mark+ then lower/modifier/
  // other/mark*. This covers all-caps words and single uppercase pronouns,
  // including optional contraction suffixes such as "I'm".
  j = start
  while j < n && is_o200k_upper_prefix_class(chars[j]) {
    j = j + 1
  }
  if j == start {
    return 0
  }
  while j < n && is_o200k_lower_tail_class(chars[j]) {
    j = j + 1
  }
  let c = match_contraction_ci(chars, j, n)
  (j + c) - i
}

fn is_o200k_letter_class(c : Char) -> Bool {
  is_letter(c) || is_combining_mark_approx(c)
}

fn is_o200k_upper_prefix_class(c : Char) -> Bool {
  is_uppercase_letter_approx(c) || is_o200k_uncased_or_mark(c)
}

fn is_o200k_lower_tail_class(c : Char) -> Bool {
  is_lowercase_letter_approx(c) || is_o200k_uncased_or_mark(c)
}

fn is_o200k_uncased_or_mark(c : Char) -> Bool {
  is_uncased_letter_approx(c) || is_combining_mark_approx(c)
}

fn is_uppercase_letter_approx(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x41 && u <= 0x5A) || (u >= 0xC0 && u <= 0xDE && u != 0xD7)
}

fn is_lowercase_letter_approx(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x61 && u <= 0x7A) || (u >= 0xDF && u <= 0xFF && u != 0xF7)
}

fn is_uncased_letter_approx(c : Char) -> Bool {
  let u = c.to_int()
  // Scripts without case in our approximation map to Lo/Lm-like classes.
  (u >= 0x590 && u <= 0x5FF) ||
  (u >= 0x620 && u <= 0x64A) ||
  (u >= 0x3040 && u <= 0x30FF) ||
  (u >= 0x3400 && u <= 0x4DBF) ||
  (u >= 0x4E00 && u <= 0x9FFF) ||
  (u >= 0xAC00 && u <= 0xD7A3)
}

fn is_combining_mark_approx(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x0300 && u <= 0x036F) ||
  (u >= 0x1AB0 && u <= 0x1AFF) ||
  (u >= 0x1DC0 && u <= 0x1DFF) ||
  (u >= 0x20D0 && u <= 0x20FF) ||
  (u >= 0xFE20 && u <= 0xFE2F)
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
