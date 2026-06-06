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
    Sequence(steps) => apply_sequence(steps, text, base_offset)
    // Other variants are handled in later phases; default to a single piece.
    _ => [{ value: text, offsets: (base_offset, base_offset + text.char_length()) }]
  }
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

fn substr(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}
