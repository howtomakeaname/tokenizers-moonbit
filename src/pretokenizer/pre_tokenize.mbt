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

///|
/// HF Python binding-style helper returning `(value, offsets)` pairs.
pub fn PreTokenizer::pre_tokenize_str(
  self : PreTokenizer,
  text : String,
) -> Array[(String, (Int, Int))] {
  self.pre_tokenize(text, base_offset=0).map(s => (s.value, s.offsets))
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
  @common.is_simple_split_regex_pattern(pattern) ||
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
    @common.simple_split_regex_matches(chars, pattern)
  } else {
    @common.literal_matches(chars, pattern)
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
fn apply_split_matches(
  chars : Array[Char],
  matches : Array[@common.Span],
  behavior : SplitBehavior,
  invert : Bool,
  base_offset : Int,
) -> Array[@types.Split] {
  let out : Array[@types.Split] = []
  let mut cursor = 0
  let mut pending_next : @common.Span? = None
  let mut pending_contiguous : @common.Span? = None
  fn emit_span(span : @common.Span) -> Unit {
    if span.stop <= span.start {
      return
    }
    out.push({
      value: substr(chars, span.start, span.stop),
      offsets: (base_offset + span.start, base_offset + span.stop),
    })
  }
  fn flush_contiguous() -> Unit {
    match pending_contiguous {
      Some(p) => {
        emit_span(p)
        pending_contiguous = None
      }
      None => ()
    }
  }
  fn emit_non_delim(span : @common.Span) -> Unit {
    flush_contiguous()
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
  fn emit_delim(span : @common.Span) -> Unit {
    match behavior {
      Removed => ()
      Isolated => emit_span(span)
      Contiguous =>
        match pending_contiguous {
          Some(p) =>
            if p.stop == span.start {
              pending_contiguous = Some({ start: p.start, stop: span.stop })
            } else {
              emit_span(p)
              pending_contiguous = Some(span)
            }
          None => pending_contiguous = Some(span)
        }
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
      let gap = @common.Span::{ start: cursor, stop: m.start }
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
    let tail = @common.Span::{ start: cursor, stop: chars.length() }
    if invert {
      emit_delim(tail)
    } else {
      emit_non_delim(tail)
    }
  }
  flush_contiguous()
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
