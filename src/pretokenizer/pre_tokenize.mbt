// Pre-tokenization behaviour: text -> word-like pieces.
//
// The model then runs on each piece's `value`. Offsets are tracked in code
// points relative to the original normalized string.

///|
/// Apply this pre-tokenizer to a single normalized string starting at char
/// `base_offset`, producing pieces.
pub fn PreTokenizer::pre_tokenize(
  self : PreTokenizer,
  text : String,
  base_offset? : Int = 0,
) -> Array[@types.Split] {
  match self {
    ByteLevel(add_prefix_space~, use_regex~, ..) =>
      byte_level_pre_tokenize(text, add_prefix_space, use_regex, base_offset)
    Whitespace => whitespace(text, base_offset)
    WhitespaceSplit => whitespace_split(text, base_offset)
    BertPreTokenizer => bert_pre_tokenize(text, base_offset)
    Punctuation(behavior~) => punctuation_split(text, behavior, base_offset)
    Metaspace(replacement~, prepend_scheme~, split~) =>
      metaspace_pre_tokenize(
        text, replacement, prepend_scheme, split, base_offset,
      )
    Split(pattern~, behavior~, invert~, regex~) =>
      split_pre_tokenize(text, pattern, behavior, invert, regex, base_offset)
    Digits(individual_digits~) =>
      digits_split(text, individual_digits, base_offset)
    Delimiter(delimiter~) => delimiter_split(text, delimiter, base_offset)
    FixedLength(length~) => fixed_length_split(text, length, base_offset)
    Sequence(steps) => apply_sequence(steps, text, base_offset)
    UnicodeScripts => unicode_scripts_split(text, base_offset)
  }
}

// Split pre-tokenizer. We recognize the well-known GPT-2 / Qwen-Llama3 family
// regexes (used verbatim by most modern models) and run a dedicated scanner.
// Each match becomes one piece (HF's Split + Isolated over a full-coverage
// regex). Offsets are tracked over the original char positions.

///|
fn is_supported_split_regex(pattern : String) -> Bool {
  is_cjk_range_pattern(pattern) ||
  is_digit_triplet_pattern(pattern) ||
  is_o200k_pattern(pattern) ||
  is_qwen_triplet_pattern(pattern) ||
  is_qwen_pattern(pattern) ||
  is_gpt2_pattern(pattern) ||
  is_clip_pattern(pattern) ||
  is_simple_regex_pattern(pattern) ||
  is_known_passthrough_split_regex(pattern)
}

///|
fn split_pre_tokenize(
  text : String,
  pattern : String,
  behavior : SplitBehavior,
  invert : Bool,
  regex : Bool,
  base_offset : Int,
) -> Array[@types.Split] {
  let pieces = if is_cjk_range_pattern(pattern) {
    cjk_range_split(text)
  } else if is_digit_triplet_pattern(pattern) {
    digit_chunk_split(text, max_digits=3)
  } else if is_o200k_pattern(pattern) {
    o200k_split(text)
  } else if is_qwen_triplet_pattern(pattern) {
    qwen_split_max_digits(text, max_digits=3)
  } else if is_qwen_pattern(pattern) {
    qwen_split(text)
  } else if is_gpt2_pattern(pattern) {
    gpt2_split(text)
  } else if is_clip_pattern(pattern) {
    clip_split(text)
  } else {
    return split_with_simple_pattern(
      text, pattern, behavior, invert, regex, base_offset,
    )
  }
  pieces_to_splits(pieces, base_offset)
}

///|
priv struct MatchSpan {
  start : Int
  stop : Int
}

///|
fn split_with_simple_pattern(
  text : String,
  pattern : String,
  behavior : SplitBehavior,
  invert : Bool,
  regex : Bool,
  base_offset : Int,
) -> Array[@types.Split] {
  let chars = text.to_array()
  let matches = if regex {
    simple_regex_matches(chars, pattern)
  } else {
    literal_matches(chars, pattern)
  }
  match matches {
    Some(spans) =>
      apply_split_matches(chars, spans, behavior, invert, base_offset)
    None =>
      [
        @types.Split::{
          value: text,
          offsets: (base_offset, base_offset + chars.length()),
        },
      ]
  }
}

///|
fn simple_regex_matches(
  chars : Array[Char],
  pattern : String,
) -> Array[MatchSpan]? {
  if pattern == "\\s+" {
    Some(run_matches(chars, fn(c) { is_space(c) }))
  } else if pattern == "\\S+" || pattern == "[^\\s]+" {
    Some(run_matches(chars, fn(c) { !is_space(c) }))
  } else if pattern == "\\s+$" {
    Some(trailing_run_match(chars, fn(c) { is_space(c) }))
  } else if pattern == "[\\r\\n]" || pattern == "[\r\n]" {
    Some(run_matches(chars, fn(c) { c == '\r' || c == '\n' }))
  } else if pattern == "\\p{N}{1,3}" || pattern == "[0-9][0-9][0-9]" {
    Some(number_run_matches(chars, max_digits=3))
  } else {
    None
  }
}

///|
fn is_simple_regex_pattern(pattern : String) -> Bool {
  pattern == "\\s+" ||
  pattern == "\\S+" ||
  pattern == "[^\\s]+" ||
  pattern == "\\s+$" ||
  pattern == "[\\r\\n]" ||
  pattern == "[\r\n]" ||
  pattern == "\\p{N}{1,3}" ||
  pattern == "[0-9][0-9][0-9]"
}

///|
fn is_known_passthrough_split_regex(pattern : String) -> Bool {
  // Some real-world tokenizers use multi-step Split sequences with very large
  // Unicode range patterns. Existing parity relies on passing these steps
  // through unchanged before later ByteLevel/Digits stages; keep those known
  // patterns loadable while still rejecting arbitrary unknown regexes.
  (pattern.contains("\\s?[A-Za-z") && pattern.contains("𞤀-𞥃")) ||
  pattern.contains("\\s?[!-/:-~") ||
  (pattern.contains("一-龥") && pattern.contains("가-")) ||
  (pattern.contains("[!\"") && pattern.contains("\\p{P}\\p{S}"))
}

///|
fn run_matches(chars : Array[Char], pred : (Char) -> Bool) -> Array[MatchSpan] {
  let out : Array[MatchSpan] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    if pred(chars[i]) {
      let start = i
      while i < n && pred(chars[i]) {
        i = i + 1
      }
      out.push({ start, stop: i })
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn trailing_run_match(
  chars : Array[Char],
  pred : (Char) -> Bool,
) -> Array[MatchSpan] {
  let out : Array[MatchSpan] = []
  let mut i = chars.length()
  while i > 0 && pred(chars[i - 1]) {
    i = i - 1
  }
  if i < chars.length() {
    out.push({ start: i, stop: chars.length() })
  }
  out
}

///|
fn number_run_matches(
  chars : Array[Char],
  max_digits~ : Int,
) -> Array[MatchSpan] {
  let out : Array[MatchSpan] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    if is_number(chars[i]) {
      let start = i
      let mut count = 0
      while i < n && is_number(chars[i]) && count < max_digits {
        i = i + 1
        count = count + 1
      }
      out.push({ start, stop: i })
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn literal_matches(chars : Array[Char], pattern : String) -> Array[MatchSpan]? {
  if pattern.is_empty() {
    return None
  }
  let pat = pattern.to_array()
  let out : Array[MatchSpan] = []
  let n = chars.length()
  let m = pat.length()
  let mut i = 0
  while i < n {
    if i + m <= n && chars_match_at(chars, i, pat) {
      out.push({ start: i, stop: i + m })
      i = i + m
    } else {
      i = i + 1
    }
  }
  Some(out)
}

///|
fn chars_match_at(src : Array[Char], at : Int, pat : Array[Char]) -> Bool {
  for k in 0..<pat.length() {
    if src[at + k] != pat[k] {
      return false
    }
  }
  true
}

///|
fn apply_split_matches(
  chars : Array[Char],
  matches : Array[MatchSpan],
  behavior : SplitBehavior,
  invert : Bool,
  base_offset : Int,
) -> Array[@types.Split] {
  let out : Array[@types.Split] = []
  let mut cursor = 0
  let mut pending_next : MatchSpan? = None
  fn emit_span(span : MatchSpan) -> Unit {
    if span.stop <= span.start {
      return
    }
    out.push({
      value: substr(chars, span.start, span.stop),
      offsets: (base_offset + span.start, base_offset + span.stop),
    })
  }
  fn emit_non_delim(span : MatchSpan) -> Unit {
    match pending_next {
      Some(p) => {
        out.push({
          value: substr(chars, p.start, p.stop) +
          substr(chars, span.start, span.stop),
          offsets: (base_offset + p.start, base_offset + span.stop),
        })
        pending_next = None
      }
      None => emit_span(span)
    }
  }
  fn emit_delim(span : MatchSpan) -> Unit {
    match behavior {
      Removed => ()
      Isolated | Contiguous => emit_span(span)
      MergedWithPrevious =>
        if out.length() > 0 {
          let idx = out.length() - 1
          let prev = out[idx]
          out[idx] = {
            value: prev.value + substr(chars, span.start, span.stop),
            offsets: (prev.offsets.0, base_offset + span.stop),
          }
        } else {
          emit_span(span)
        }
      MergedWithNext => pending_next = Some(span)
    }
  }
  for m in matches {
    if cursor < m.start {
      let gap = { start: cursor, stop: m.start }
      if invert {
        emit_delim(gap)
      } else {
        emit_non_delim(gap)
      }
    }
    if invert {
      emit_non_delim(m)
    } else {
      emit_delim(m)
    }
    cursor = m.stop
  }
  if cursor < chars.length() {
    let tail = { start: cursor, stop: chars.length() }
    if invert {
      emit_delim(tail)
    } else {
      emit_non_delim(tail)
    }
  }
  match pending_next {
    Some(p) => emit_span(p)
    None => ()
  }
  out
}

// Recognize the Qwen2/Qwen3/Llama-3 pattern (single-digit \p{N}, (?i:...)).

///|
fn is_qwen_pattern(p : String) -> Bool {
  p.contains("(?i:'s|'t") || (p.contains("\\p{N}|") && p.contains("[\\r\\n]*"))
}

// Llama-3 / GLM style: Qwen/Llama regex but groups numbers as \p{N}{1,3}.

///|
fn is_qwen_triplet_pattern(p : String) -> Bool {
  p.contains("(?i:'s|'t") &&
  p.contains("\\p{N}{1,3}") &&
  p.contains("[\\r\\n]*")
}

// o200k-style regex used by GPT-OSS / Phi-4-mini: case-aware letter branches,
// optional contractions, number chunks of up to 3, punctuation, whitespace.

///|
fn is_o200k_pattern(p : String) -> Bool {
  p.contains("\\p{Lu}") && p.contains("\\p{Ll}") && p.contains("\\p{N}{1,3}")
}

///|
fn is_digit_triplet_pattern(p : String) -> Bool {
  p == "\\p{N}{1,3}" || (p.contains("\\p{N}{1,3}") && !p.contains("|"))
}

///|
fn is_cjk_range_pattern(p : String) -> Bool {
  p.contains("一-龥") && p.contains("぀-ゟ") && p.contains("゠-ヿ")
}

// Recognize the classic GPT-2 pattern.

///|
fn is_gpt2_pattern(p : String) -> Bool {
  p.contains("'s|'t|'re") && p.contains("?\\p{L}+")
}

// CLIP uses a GPT-2-like Split regex but without optional leading spaces:
// specials | contractions | [\p{L}]+ | [\p{N}] | [^\s\p{L}\p{N}]+.
// This removes whitespace before ByteLevel maps the remaining pieces.

///|
fn is_clip_pattern(p : String) -> Bool {
  p.contains("<\\|startoftext\\|>") &&
  p.contains("[\\p{L}]+") &&
  p.contains("[\\p{N}]")
}

// Turn raw piece strings into Splits with running char offsets.

///|
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

///|
fn digit_chunk_split(text : String, max_digits~ : Int) -> Array[String] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[String] = []
  let mut i = 0
  while i < n {
    if is_number(chars[i]) {
      let mut j = i
      let mut count = 0
      while j < n && is_number(chars[j]) && count < max_digits {
        j = j + 1
        count = count + 1
      }
      out.push(substr(chars, i, j))
      i = j
    } else {
      let start = i
      while i < n && !is_number(chars[i]) {
        i = i + 1
      }
      out.push(substr(chars, start, i))
    }
  }
  out
}

///|
fn cjk_range_split(text : String) -> Array[String] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[String] = []
  let mut i = 0
  while i < n {
    let cjk = is_cjk_range_char(chars[i])
    let start = i
    while i < n && is_cjk_range_char(chars[i]) == cjk {
      i = i + 1
    }
    out.push(substr(chars, start, i))
  }
  out
}

///|
fn is_cjk_range_char(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x4E00 && u <= 0x9FA5) ||
  (u >= 0x3040 && u <= 0x309F) ||
  (u >= 0x30A0 && u <= 0x30FF)
}

// ByteLevel: optionally prepend a space, regex-split (GPT-2), byte-map pieces.

///|
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
    let orig_start = if prefixed {
      base_offset + start_in_input - 1
    } else {
      base_offset + start_in_input
    }
    let orig_end = orig_start + plen
    out.push({
      value: byte_level_encode_str(p),
      offsets: (
        if orig_start < base_offset {
          base_offset
        } else {
          orig_start
        },
        orig_end,
      ),
    })
    cursor = cursor + plen
  }
  out
}

// Whitespace pre-tokenizer: \w+|[^\w\s]+ (ASCII-approximated word runs).

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
