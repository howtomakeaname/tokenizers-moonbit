///|
fn whitespace(text : String, base_offset : Int) -> Array[@types.Split] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[@types.Split] = []
  let mut i = 0
  while i < n {
    let c = chars[i]
    if is_space(c) {
      i = i + 1
      continue
    }
    let mut j = i
    if is_word_char(c) {
      while j < n && is_word_char(chars[j]) {
        j = j + 1
      }
    } else {
      while j < n && !is_word_char(chars[j]) && !is_space(chars[j]) {
        j = j + 1
      }
    }
    out.push({
      value: substr(chars, i, j),
      offsets: (base_offset + i, base_offset + j),
    })
    i = j
  }
  out
}

// WhitespaceSplit: split on runs of whitespace only.

///|
fn whitespace_split(text : String, base_offset : Int) -> Array[@types.Split] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[@types.Split] = []
  let mut i = 0
  while i < n {
    if is_space(chars[i]) {
      i = i + 1
      continue
    }
    let mut j = i
    while j < n && !is_space(chars[j]) {
      j = j + 1
    }
    out.push({
      value: substr(chars, i, j),
      offsets: (base_offset + i, base_offset + j),
    })
    i = j
  }
  out
}

// Sequence: run each step, feeding the previous pieces through the next.

///|
fn apply_sequence(
  steps : Array[PreTokenizer],
  text : String,
  base_offset : Int,
) -> Array[@types.Split] {
  let mut current : Array[@types.Split] = [
    { value: text, offsets: (base_offset, base_offset + text.char_length()) },
  ]
  for step in steps {
    let next : Array[@types.Split] = []
    for piece in current {
      for sub in step.pre_tokenize(piece.value, base_offset=piece.offsets.0) {
        next.push(sub)
      }
    }
    current = next
  }
  current
}

///|
fn starts_with_space(s : String) -> Bool {
  match s.iter().next() {
    Some(c) => is_space(c)
    None => false
  }
}

///|
fn is_word_char(c : Char) -> Bool {
  is_letter(c) || is_number(c) || c == '_'
}

// BertPreTokenizer: split on whitespace, isolate punctuation, and split CJK
// characters each into their own piece.

///|
fn bert_pre_tokenize(text : String, base_offset : Int) -> Array[@types.Split] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[@types.Split] = []
  let mut i = 0
  while i < n {
    let c = chars[i]
    if is_space(c) {
      i = i + 1
      continue
    }
    if is_punct(c) || is_cjk(c) {
      // each punctuation / CJK char is its own token
      out.push({
        value: substr(chars, i, i + 1),
        offsets: (base_offset + i, base_offset + i + 1),
      })
      i = i + 1
      continue
    }
    // a run of non-space, non-punct, non-cjk chars
    let mut j = i
    while j < n &&
          !is_space(chars[j]) &&
          !is_punct(chars[j]) &&
          !is_cjk(chars[j]) {
      j = j + 1
    }
    out.push({
      value: substr(chars, i, j),
      offsets: (base_offset + i, base_offset + j),
    })
    i = j
  }
  out
}

// Punctuation pre-tokenizer: split on Unicode punctuation and honor HF's
// SplitBehavior semantics for the matched punctuation spans.

///|
fn punctuation_split(
  text : String,
  behavior : SplitBehavior,
  base_offset : Int,
) -> Array[@types.Split] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[@types.Split] = []
  let mut i = 0
  while i < n {
    if is_punct(chars[i]) {
      let start = i
      while i < n && is_punct(chars[i]) {
        i = i + 1
      }
      match behavior {
        Removed => ()
        Isolated =>
          for k in start..<i {
            out.push({
              value: substr(chars, k, k + 1),
              offsets: (base_offset + k, base_offset + k + 1),
            })
          }
        Contiguous =>
          out.push({
            value: substr(chars, start, i),
            offsets: (base_offset + start, base_offset + i),
          })
        MergedWithPrevious =>
          if out.length() == 0 {
            out.push({
              value: substr(chars, start, i),
              offsets: (base_offset + start, base_offset + i),
            })
          } else {
            let idx = out.length() - 1
            let prev = out[idx]
            out[idx] = {
              value: prev.value + substr(chars, start, i),
              offsets: (prev.offsets.0, base_offset + i),
            }
          }
        MergedWithNext => {
          let start2 = start
          while i < n && is_punct(chars[i]) {
            i = i + 1
          }
          if i < n {
            let mut j = i
            while j < n && !is_punct(chars[j]) {
              j = j + 1
            }
            out.push({
              value: substr(chars, start2, j),
              offsets: (base_offset + start2, base_offset + j),
            })
            i = j
          } else {
            out.push({
              value: substr(chars, start2, i),
              offsets: (base_offset + start2, base_offset + i),
            })
          }
        }
      }
    } else {
      let mut j = i
      while j < n && !is_punct(chars[j]) {
        j = j + 1
      }
      out.push({
        value: substr(chars, i, j),
        offsets: (base_offset + i, base_offset + j),
      })
      i = j
    }
  }
  out
}

// UnicodeScripts mirrors HF's splitter used by Unigram/SentencePiece: split
// when the Unicode script changes. Spaces are Script::Any and therefore attach
// to the surrounding script span; Hiragana, Katakana and U+30FC are folded into
// Han to keep Japanese text together.

///|
fn unicode_scripts_split(
  text : String,
  base_offset : Int,
) -> Array[@types.Split] {
  let chars = text.to_array()
  let n = chars.length()
  if n == 0 {
    return []
  }
  let out : Array[@types.Split] = []
  let mut start = 0
  let mut last_script = -1
  for i in 0..<n {
    let script = fixed_script(chars[i])
    if script != 0 &&
      last_script != -1 &&
      last_script != 0 &&
      last_script != script {
      out.push({
        value: substr(chars, start, i),
        offsets: (base_offset + start, base_offset + i),
      })
      start = i
    }
    if script != 0 {
      last_script = script
    }
  }
  out.push({
    value: substr(chars, start, n),
    offsets: (base_offset + start, base_offset + n),
  })
  out
}

///|
fn fixed_script(c : Char) -> Int {
  let u = c.to_int()
  if c == ' ' {
    0 // Any
  } else if is_han_script(u) || is_hiragana(u) || is_katakana(u) || u == 0x30FC {
    1 // Han-compatible (HF SentencePiece convention)
  } else if (u >= 0x0041 && u <= 0x005A) ||
    (u >= 0x0061 && u <= 0x007A) ||
    (u >= 0x00C0 && u <= 0x024F) ||
    (u >= 0x1E00 && u <= 0x1EFF) {
    2 // Latin
  } else if u >= 0x0370 && u <= 0x03FF {
    3 // Greek
  } else if u >= 0x0400 && u <= 0x052F {
    4 // Cyrillic
  } else if u >= 0x0600 && u <= 0x06FF {
    5 // Arabic
  } else if u >= 0x0900 && u <= 0x097F {
    6 // Devanagari
  } else if (u >= 0xAC00 && u <= 0xD7AF) ||
    (u >= 0x1100 && u <= 0x11FF) ||
    (u >= 0x3130 && u <= 0x318F) {
    7 // Hangul
  } else if is_number(c) || is_punct(c) || is_space(c) {
    8 // Common
  } else {
    9 // Other
  }
}

///|
fn is_han_script(u : Int) -> Bool {
  (u >= 0x3400 && u <= 0x4DBF) ||
  (u >= 0x4E00 && u <= 0x9FFF) ||
  (u >= 0xF900 && u <= 0xFAFF) ||
  (u >= 0x20000 && u <= 0x2A6DF) ||
  (u >= 0x2A700 && u <= 0x2B73F) ||
  (u >= 0x2B740 && u <= 0x2B81F) ||
  (u >= 0x2B820 && u <= 0x2CEAF)
}

///|
fn is_hiragana(u : Int) -> Bool {
  u >= 0x3040 && u <= 0x309F
}

///|
fn is_katakana(u : Int) -> Bool {
  (u >= 0x30A0 && u <= 0x30FF) || (u >= 0x31F0 && u <= 0x31FF)
}

///|
/// Punctuation per Unicode P* plus ASCII punctuation ranges (approximated).
pub fn is_punct(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x21 && u <= 0x2F) || // ! " # $ % & ' ( ) * + , - . /
  (u >= 0x3A && u <= 0x40) || // : ; < = > ? @
  (u >= 0x5B && u <= 0x60) || // [ \ ] ^ _ `
  (u >= 0x7B && u <= 0x7E) || // { | } ~
  (u >= 0x2000 && u <= 0x206F) || // general punctuation
  (u >= 0x3000 && u <= 0x303F) // CJK symbols and punctuation
}

///|
/// CJK ideograph ranges (for Bert per-char splitting).
pub fn is_cjk(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x4E00 && u <= 0x9FFF) ||
  (u >= 0x3400 && u <= 0x4DBF) ||
  (u >= 0xF900 && u <= 0xFAFF) ||
  (u >= 0x20000 && u <= 0x2A6DF)
}

///|
fn substr(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

// CharDelimiterSplit ("Delimiter"): split on a single char, dropping it.

///|
fn delimiter_split(
  text : String,
  delim : Char,
  base_offset : Int,
) -> Array[@types.Split] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[@types.Split] = []
  let mut i = 0
  while i < n {
    if chars[i] == delim {
      i = i + 1
      continue
    }
    let start = i
    while i < n && chars[i] != delim {
      i = i + 1
    }
    out.push({
      value: substr(chars, start, i),
      offsets: (base_offset + start, base_offset + i),
    })
  }
  out
}

// FixedLength: split into chunks of `length` code points.

///|
fn fixed_length_split(
  text : String,
  length : Int,
  base_offset : Int,
) -> Array[@types.Split] {
  let chars = text.to_array()
  let n = chars.length()
  let step = if length <= 0 { 1 } else { length }
  let out : Array[@types.Split] = []
  let mut i = 0
  while i < n {
    let stop = if i + step < n { i + step } else { n }
    out.push({
      value: substr(chars, i, stop),
      offsets: (base_offset + i, base_offset + stop),
    })
    i = stop
  }
  out
}

// Digits pre-tokenizer: isolate digit runs. individual_digits=true makes each
// digit its own piece; false keeps a contiguous digit run together.

///|
fn digits_split(
  text : String,
  individual_digits : Bool,
  base_offset : Int,
) -> Array[@types.Split] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[@types.Split] = []
  let mut i = 0
  while i < n {
    if is_number(chars[i]) {
      if individual_digits {
        out.push({
          value: substr(chars, i, i + 1),
          offsets: (base_offset + i, base_offset + i + 1),
        })
        i = i + 1
      } else {
        let start = i
        while i < n && is_number(chars[i]) {
          i = i + 1
        }
        out.push({
          value: substr(chars, start, i),
          offsets: (base_offset + start, base_offset + i),
        })
      }
    } else {
      let start = i
      while i < n && !is_number(chars[i]) {
        i = i + 1
      }
      out.push({
        value: substr(chars, start, i),
        offsets: (base_offset + start, base_offset + i),
      })
    }
  }
  out
}

// Metaspace (SentencePiece): replace spaces with `replacement` (▁) and, when
// prepend_scheme != "never", prepend one to the start. Pieces are split so each
// begins with the replacement char (i.e. on each ▁ boundary).

///|
fn metaspace_pre_tokenize(
  text : String,
  replacement : Char,
  prepend_scheme : String,
  split : Bool,
  base_offset : Int,
) -> Array[@types.Split] {
  // prepend_scheme: "always" -> always prepend; "first" -> only on the very
  // first piece of the whole input (base_offset == 0); "never" -> never.
  let prepend = match prepend_scheme {
    "never" => false
    "first" => base_offset == 0
    _ => true
  }
  let src = text.to_array()
  let mapped : Array[Char] = []
  let origin : Array[Int] = [] // original index for each mapped char
  if prepend && (src.length() == 0 || src[0] != ' ') {
    mapped.push(replacement)
    origin.push(0)
  }
  for i, c in src {
    if c == ' ' {
      mapped.push(replacement)
    } else {
      mapped.push(c)
    }
    origin.push(i)
  }
  let n = mapped.length()
  // split=false: emit the whole transformed string as a single piece (the
  // model's BPE then handles the runs, e.g. Mistral/Llama Metaspace).
  if !split {
    if n == 0 {
      return []
    }
    let value = substr(mapped, 0, n)
    let off_end = base_offset + (origin[n - 1] + 1)
    return [{ value, offsets: (base_offset + origin[0], off_end) }]
  }
  // split=true: each piece starts at a replacement boundary.
  let out : Array[@types.Split] = []
  let mut i = 0
  while i < n {
    let start = i
    i = i + 1
    while i < n && mapped[i] != replacement {
      i = i + 1
    }
    let value = substr(mapped, start, i)
    let off_start = base_offset + origin[start]
    let off_end = base_offset +
      (if i < n { origin[i] } else { origin[n - 1] + 1 })
    out.push({ value, offsets: (off_start, off_end) })
  }
  out
}
