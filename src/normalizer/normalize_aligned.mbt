// Original-referential alignment for normalization.
//
// Mirrors HuggingFace's NormalizedString `alignments` column at char
// granularity: for every character of the normalized text, `Align` holds the
// [start, stop) char span of the ORIGINAL text it came from. Inserts attach
// to a neighbor's span, deletions simply have no normalized counterpart, and
// N:1 collapses map the composed char to the whole consumed span (the
// 0 / +1 / -N change contract of HF's `transform`).

///|
pub type Aligned = Array[(Int, Int)]

///|
fn identity_align(n : Int) -> Aligned {
  let align : Array[(Int, Int)] = []
  for i in 0..<n {
    align.push((i, i + 1))
  }
  align
}

///|
/// Compose a second alignment (relative to the intermediate text) onto a
/// first one (intermediate -> original): expand each top span through base.
fn compose_align(
  base : Array[(Int, Int)],
  top : Array[(Int, Int)],
) -> Array[(Int, Int)] {
  top.map(span => {
    let (s, e) = span
    if s >= base.length() {
      // past-the-end attaches to the last base span (or (0,0) when empty)
      if base.length() == 0 {
        (0, 0)
      } else {
        let last = base[base.length() - 1]
        (last.0, last.1)
      }
    } else if e <= 0 {
      span
    } else {
      let stop_idx = if e - 1 < base.length() {
        e - 1
      } else {
        base.length() - 1
      }
      let a = base[s]
      let b = base[stop_idx]
      (a.0, b.1)
    }
  })
}

///|
/// Map a normalized-text span [s, e) back to the original text through the
/// alignment column.
pub fn expand_align(align : Array[(Int, Int)], s : Int, e : Int) -> (Int, Int) {
  let n = align.length()
  if n == 0 || e <= s {
    return (0, 0)
  }
  let lo = if s < 0 { 0 } else { s }
  let si = if lo < n { lo } else { n - 1 }
  let ei = if e - 1 < n { e - 1 } else { n - 1 }
  (align[si].0, align[ei].1)
}

///|
/// Normalize and return the original-referential alignment column.
pub fn Normalizer::normalize_aligned(
  self : Normalizer,
  input : String,
) -> (String, Aligned) {
  match self {
    Lowercase => (to_lowercase(input), lowercase_align(input))
    Strip(left~, right~) => strip_aligned(input, left, right)
    StripAccents => strip_accents_aligned(input)
    ByteLevel => (byte_level_normalize(input), byte_level_align(input))
    Nmt => (nmt_normalize(input), nmt_align(input))
    Prepend(prepend~) => {
      // Inserted chars attach to the first original char's span (HF
      // prepend.rs maps them all to [0, 1)).
      let align : Array[(Int, Int)] = []
      let pl = prepend.char_length()
      let first_span : (Int, Int) = if input.char_length() > 0 {
        (0, 1)
      } else {
        (0, 0)
      }
      for _i in 0..<pl {
        align.push(first_span)
      }
      let rest = identity_align(input.char_length())
      for a in rest {
        align.push(a)
      }
      (prepend + input, align)
    }
    Replace(pattern~, content~) => replace_aligned(input, pattern, content)
    ReplaceString(pattern~, content~) =>
      replace_literal_aligned(input, pattern, content)
    Sequence(steps) => {
      let mut text = input
      let mut align = identity_align(input.char_length())
      for step in steps {
        let (next_text, next_align) = step.normalize_aligned(text)
        text = next_text
        align = compose_align(align, next_align)
      }
      (text, align)
    }
    BertNormalizer(
      clean_text~,
      handle_chinese_chars~,
      strip_accents=sa,
      lowercase~
    ) => {
      let mut text = input
      let mut align = identity_align(input.char_length())
      fn step(
        text : String,
        align : Aligned,
        f : (String) -> (String, Aligned),
      ) -> (String, Aligned) {
        let (t2, a2) = f(text)
        // a2 is relative to `text`; re-base onto the original
        (t2, compose_align(align, a2))
      }
      if clean_text {
        let (t2, a2) = step(text, align, bert_clean_text_aligned)
        text = t2
        align = a2
      }
      if handle_chinese_chars {
        let (t2, a2) = step(text, align, bert_pad_chinese_aligned)
        text = t2
        align = a2
      }
      let should_strip_accents = match sa {
        Some(value) => value
        None => lowercase
      }
      if should_strip_accents {
        let (t2, a2) = step(text, align, bert_strip_accents_aligned)
        text = t2
        align = a2
      }
      if lowercase {
        let (t2, a2) = step(text, align, fn(s) {
          (to_lowercase(s), lowercase_align(s))
        })
        text = t2
        align = a2
      }
      (text, align)
    }
    NFC => normalize_unicode_aligned(input, compat=false, compose=true)
    NFD => normalize_unicode_aligned(input, compat=false, compose=false)
    NFKC => normalize_unicode_aligned(input, compat=true, compose=true)
    NFKD => normalize_unicode_aligned(input, compat=true, compose=false)
    Precompiled => precompiled_normalize_aligned(input)
    PrecompiledMap(data~) => precompiled_map_normalize_aligned(data, input)
  }
}

///|
fn lowercase_align(input : String) -> Aligned {
  // ASCII-only lowercasing is char-for-char.
  identity_align(input.char_length())
}

///|
fn strip_aligned(
  input : String,
  left : Bool,
  right : Bool,
) -> (String, Aligned) {
  let chars = input.to_array()
  let n = chars.length()
  let mut start = 0
  let mut stop = n
  if left {
    while start < stop && @common.is_ascii_whitespace(chars[start]) {
      start = start + 1
    }
  }
  if right {
    while stop > start && @common.is_ascii_whitespace(chars[stop - 1]) {
      stop = stop - 1
    }
  }
  let sb = StringBuilder()
  let align : Array[(Int, Int)] = []
  for k in start..<stop {
    sb.write_char(chars[k])
    align.push((k, k + 1))
  }
  (sb.to_string(), align)
}

///|
fn strip_accents_aligned(input : String) -> (String, Aligned) {
  // Standalone StripAccents removes already-decomposed marks only
  // (precomposed chars untouched — same rule as strip_accents).
  let sb = StringBuilder()
  let align : Array[(Int, Int)] = []
  for i, c in input {
    if is_combining_mark(c.to_int()) {
      continue
    }
    sb.write_char(c)
    align.push((i, i + 1))
  }
  (sb.to_string(), align)
}

///|
fn byte_level_align(input : String) -> Aligned {
  // Every input char expands to its UTF-8 byte count of visible chars; all
  // map back to the char's span.
  let align : Array[(Int, Int)] = []
  for i, c in input {
    let byte_len = @utf8.encode(c.to_string()).length()
    for _k in 0..<byte_len {
      align.push((i, i + 1))
    }
  }
  align
}

///|
fn nmt_align(input : String) -> Aligned {
  // nmt_normalize is a per-char mapping (possibly dropping chars); rebuild
  // alignment by re-running its per-char decisions with spans.
  let align : Array[(Int, Int)] = []
  for i, c in input {
    let cp = c.to_int()
    let out = nmt_char_replacement(cp)
    for _ch in out {
      align.push((i, i + 1))
    }
    ignore(c)
  }
  align
}

///|
fn bert_clean_text_aligned(input : String) -> (String, Aligned) {
  let sb = StringBuilder()
  let align : Array[(Int, Int)] = []
  for i, c in input {
    let u = c.to_int()
    if u == 0 || u == 0xFFFD || is_control(c) {
      continue
    }
    if @common.is_unicode_whitespace(u) {
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
    align.push((i, i + 1))
  }
  (sb.to_string(), align)
}

///|
fn bert_pad_chinese_aligned(input : String) -> (String, Aligned) {
  // HF inserts a space on both sides of a CJK char; inserted spaces attach
  // to the CJK char's span.
  let sb = StringBuilder()
  let align : Array[(Int, Int)] = []
  for i, c in input {
    if is_chinese_char(c) {
      sb.write_char(' ')
      sb.write_char(c)
      sb.write_char(' ')
      align.push((i, i + 1))
      align.push((i, i + 1))
      align.push((i, i + 1))
    } else {
      sb.write_char(c)
      align.push((i, i + 1))
    }
  }
  (sb.to_string(), align)
}

///|
fn replace_aligned(
  input : String,
  pattern : String,
  content : String,
) -> (String, Aligned) {
  let chars = input.to_array()
  let spans : Array[(Int, Int)] = match
    @common.simple_split_regex_matches(chars, pattern) {
    Some(list) => {
      let conv : Array[(Int, Int)] = []
      for sp in list {
        conv.push((sp.start, sp.stop))
      }
      conv
    }
    None => []
  }
  let sb = StringBuilder()
  let align : Array[(Int, Int)] = []
  let mut pos = 0
  let content_len = content.char_length()
  ignore(content_len)
  for span in spans {
    if span.0 < pos {
      continue
    }
    for k in pos..<span.0 {
      sb.write_char(chars[k])
      align.push((k, k + 1))
    }
    // HF attaches every content char to the span of the LAST char of
    // the match (transform +0 contract on the final matched char).
    let last_char_span = (span.1 - 1, span.1)
    for _ch in content {
      align.push(last_char_span)
    }
    sb.write_string(content)
    pos = span.1
  }
  for k in pos..<chars.length() {
    sb.write_char(chars[k])
    align.push((k, k + 1))
  }
  (sb.to_string(), align)
}

///|
/// ReplaceString (literal pattern) alignment: find-all occurrences of the
/// literal pattern; content chars attach to the last matched char.
fn replace_literal_aligned(
  input : String,
  pattern : String,
  content : String,
) -> (String, Aligned) {
  if pattern.is_empty() {
    return (input, identity_align(input.char_length()))
  }
  let chars = input.to_array()
  let pat_chars = pattern.to_array()
  let m = pat_chars.length()
  let sb = StringBuilder()
  let align : Array[(Int, Int)] = []
  let mut i = 0
  let n = chars.length()
  while i < n {
    // match pattern at i?
    let mut matched = true
    if i + m > n {
      matched = false
    } else {
      for k in 0..<m {
        if chars[i + k] != pat_chars[k] {
          matched = false
          break
        }
      }
    }
    if matched {
      let last_char_span = (i + m - 1, i + m)
      for _ch in content {
        align.push(last_char_span)
      }
      sb.write_string(content)
      i = i + m
    } else {
      sb.write_char(chars[i])
      align.push((i, i + 1))
      i = i + 1
    }
  }
  (sb.to_string(), align)
}

///|
/// BertNormalizer strip_accents: NFD-then-drop-marks with span mapping
/// (precomposed é -> e keeps the char's span; expansions map to it too).
fn bert_strip_accents_aligned(input : String) -> (String, Array[(Int, Int)]) {
  let sb = StringBuilder()
  let align : Array[(Int, Int)] = []
  for i, c in input {
    let cp = c.to_int()
    if is_combining_mark(cp) {
      continue
    }
    match accent_map().get(cp) {
      Some(stripped) => {
        for _ch in stripped {
          align.push((i, i + 1))
        }
        sb.write_string(stripped)
      }
      None => {
        sb.write_char(c)
        align.push((i, i + 1))
      }
    }
  }
  (sb.to_string(), align)
}
