// Pre-tokenization behaviour: text -> word-like pieces.
//
// The model then runs on each piece's `value`. Offsets are tracked in code
// points relative to the original normalized string.

/// Apply this pre-tokenizer to a single normalized string starting at char
/// `base_offset`, producing pieces.
pub fn PreTokenizer::pre_tokenize(
  self : PreTokenizer,
  text : String,
  base_offset~ : Int = 0,
) -> Array[@types.Split] {
  match self {
    ByteLevel(add_prefix_space~, use_regex~, ..) =>
      byte_level_pre_tokenize(text, add_prefix_space, use_regex, base_offset)
    Whitespace => whitespace(text, base_offset)
    WhitespaceSplit => whitespace_split(text, base_offset)
    BertPreTokenizer => bert_pre_tokenize(text, base_offset)
    Punctuation => punctuation_split(text, base_offset)
    Metaspace(replacement~, prepend_scheme~, split~) =>
      metaspace_pre_tokenize(text, replacement, prepend_scheme, split, base_offset)
    Split(pattern~, ..) => split_pre_tokenize(text, pattern, base_offset)
    Digits(individual_digits~) =>
      digits_split(text, individual_digits, base_offset)
    Delimiter(delimiter~) => delimiter_split(text, delimiter, base_offset)
    FixedLength(length~) => fixed_length_split(text, length, base_offset)
    Sequence(steps) => apply_sequence(steps, text, base_offset)
    // Other variants are handled in later phases; default to a single piece.
    _ => [{ value: text, offsets: (base_offset, base_offset + text.char_length()) }]
  }
}

// Split pre-tokenizer. We recognize the well-known GPT-2 / Qwen-Llama3 family
// regexes (used verbatim by most modern models) and run a dedicated scanner.
// Each match becomes one piece (HF's Split + Isolated over a full-coverage
// regex). Offsets are tracked over the original char positions.
fn split_pre_tokenize(
  text : String,
  pattern : String,
  base_offset : Int,
) -> Array[@types.Split] {
  let pieces = if is_qwen_pattern(pattern) {
    qwen_split(text)
  } else if is_gpt2_pattern(pattern) {
    gpt2_split(text)
  } else {
    // Unknown pattern: leave the text as a single piece (documented limit).
    [text]
  }
  pieces_to_splits(pieces, base_offset)
}

// Recognize the Qwen2/Qwen3/Llama-3 pattern (single-digit \p{N}, (?i:...)).
fn is_qwen_pattern(p : String) -> Bool {
  p.contains("(?i:'s|'t") || (p.contains("\\p{N}|") && p.contains("[\\r\\n]*"))
}

// Recognize the classic GPT-2 pattern.
fn is_gpt2_pattern(p : String) -> Bool {
  p.contains("'s|'t|'re") && p.contains("?\\p{L}+")
}

// Turn raw piece strings into Splits with running char offsets.
fn pieces_to_splits(
  pieces : Array[String],
  base_offset : Int,
) -> Array[@types.Split] {
  let out : Array[@types.Split] = []
  let mut cursor = base_offset
  for p in pieces {
    let len = p.char_length()
    out.push({ value: p, offsets: (cursor, cursor + len) })
    cursor = cursor + len
  }
  out
}

// ByteLevel: optionally prepend a space, regex-split (GPT-2), byte-map pieces.
fn byte_level_pre_tokenize(
  text : String,
  add_prefix_space : Bool,
  use_regex : Bool,
  base_offset : Int,
) -> Array[@types.Split] {
  let input = if add_prefix_space && !starts_with_space(text) {
    " " + text
  } else {
    text
  }
  // Offset bookkeeping: if we prepended a space, char offsets shift by -1
  // relative to `input`; we report offsets in the *original* text space, so a
  // prepended space maps to base_offset (clamped).
  let prefixed = add_prefix_space && !starts_with_space(text)
  let pieces = if use_regex { gpt2_split(input) } else { [input] }
  let out : Array[@types.Split] = []
  let mut cursor = 0 // char index within `input`
  for p in pieces {
    let plen = p.char_length()
    let start_in_input = cursor
    let orig_start = if prefixed { base_offset + start_in_input - 1 } else { base_offset + start_in_input }
    let orig_end = orig_start + plen
    out.push({
      value: byte_level_encode_str(p),
      offsets: (if orig_start < base_offset { base_offset } else { orig_start }, orig_end),
    })
    cursor = cursor + plen
  }
  out
}

// Whitespace pre-tokenizer: \w+|[^\w\s]+ (ASCII-approximated word runs).
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

fn starts_with_space(s : String) -> Bool {
  match s.iter().next() {
    Some(c) => is_space(c)
    None => false
  }
}

fn is_word_char(c : Char) -> Bool {
  is_letter(c) || is_number(c) || c == '_'
}

// BertPreTokenizer: split on whitespace, isolate punctuation, and split CJK
// characters each into their own piece.
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
    while j < n && !is_space(chars[j]) && !is_punct(chars[j]) && !is_cjk(chars[j]) {
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

// Punctuation pre-tokenizer: isolate each punctuation char, keep other runs.
fn punctuation_split(text : String, base_offset : Int) -> Array[@types.Split] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[@types.Split] = []
  let mut i = 0
  while i < n {
    if is_punct(chars[i]) {
      out.push({
        value: substr(chars, i, i + 1),
        offsets: (base_offset + i, base_offset + i + 1),
      })
      i = i + 1
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

/// CJK ideograph ranges (for Bert per-char splitting).
pub fn is_cjk(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x4E00 && u <= 0x9FFF) ||
  (u >= 0x3400 && u <= 0x4DBF) ||
  (u >= 0xF900 && u <= 0xFAFF) ||
  (u >= 0x20000 && u <= 0x2A6DF)
}

fn substr(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

// CharDelimiterSplit ("Delimiter"): split on a single char, dropping it.
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
      while i < n && not(is_number(chars[i])) {
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
  if not(split) {
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
    let off_end = base_offset + (if i < n { origin[i] } else { origin[n - 1] + 1 })
    out.push({ value, offsets: (off_start, off_end) })
  }
  out
}
