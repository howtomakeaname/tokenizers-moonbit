// Decoding behaviour: token surfaces -> reconstructed text.
//
// Following HuggingFace, each decoder is a `decode_chain(tokens) -> tokens`
// transform; `Sequence` composes them, and the final text is the join of the
// resulting token list. This token-list model is required for decoders like
// ByteFallback that must group consecutive byte tokens before a later Fuse.

///|
/// Decode a list of token surface strings back into text.
pub fn Decoder::decode(self : Decoder, tokens : Array[String]) -> String {
  match self {
    Replace(pattern~, content~) =>
      return decode_replace_direct(tokens, pattern, content)
    _ => ()
  }
  let out = self.decode_chain(tokens)
  let sb = StringBuilder::new()
  for t in out {
    sb.write_string(t)
  }
  sb.to_string()
}

///|
fn decode_replace_direct(
  tokens : Array[String],
  pattern : String,
  content : String,
) -> String {
  if pattern == "\\s+" {
    return decode_replace_char_runs_direct(tokens, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  if pattern == "\\s+$" {
    return decode_replace_trailing_runs_direct(tokens, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  match @common.anchored_regex_kind(pattern) {
    Some((kind, leading)) =>
      if leading {
        return decode_replace_leading_runs_direct(tokens, content, fn(c) {
          @common.bounded_regex_kind_pred(kind, c)
        })
      } else {
        return decode_replace_trailing_runs_direct(tokens, content, fn(c) {
          @common.bounded_regex_kind_pred(kind, c)
        })
      }
    None => ()
  }
  if pattern == "\\d+" || pattern == "[\\d]+" || pattern == "[0-9]+" {
    return decode_replace_char_runs_direct(tokens, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]+" ||
    pattern == "[\\p{S}\\p{P}]+" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+" {
    return decode_replace_char_runs_direct(tokens, content, fn(c) {
      is_punctuation_or_symbol_fast(c)
    })
  }
  if pattern == "\\D{3,}" ||
    pattern == "[\\D]{3,}" ||
    pattern == "[^\\d]{3,}" ||
    pattern == "[^0-9]{3,}" ||
    pattern == "\\P{N}{3,}" ||
    pattern == "\\P{Number}{3,}" ||
    pattern == "[^\\p{N}]{3,}" ||
    pattern == "[^\\p{Number}]{3,}" {
    return decode_replace_min_non_digit_direct(tokens, content, min_run=3)
  }
  if pattern == "[^\\s\\p{L}\\p{N}]{4}" ||
    pattern == "[^\\s\\p{N}\\p{L}]{4}" ||
    pattern == "[^\\p{L}\\p{N}\\s]{4}" ||
    pattern == "[^\\p{N}\\p{L}\\s]{4}" ||
    pattern == "[^\\s\\p{Letter}\\p{Number}]{4}" {
    return decode_replace_not_whitespace_letter_number_ranged_direct(
      tokens,
      content,
      min_run=4,
      max_run=4,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{1,2}" ||
    pattern == "[\\p{S}\\p{P}]{1,2}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{1,2}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{1,2}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=1,
      max_run=2,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{1,3}" ||
    pattern == "[\\p{S}\\p{P}]{1,3}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{1,3}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{1,3}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=1,
      max_run=3,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{1,4}" ||
    pattern == "[\\p{S}\\p{P}]{1,4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{1,4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{1,4}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=1,
      max_run=4,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{2,3}" ||
    pattern == "[\\p{S}\\p{P}]{2,3}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2,3}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2,3}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=2,
      max_run=3,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{2,4}" ||
    pattern == "[\\p{S}\\p{P}]{2,4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2,4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2,4}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=2,
      max_run=4,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{3,4}" ||
    pattern == "[\\p{S}\\p{P}]{3,4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{3,4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{3,4}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=3,
      max_run=4,
    )
  }
  match @common.bounded_regex_kind(pattern) {
    Some((kind, max_run)) =>
      return decode_replace_ranged_char_runs_direct(
        tokens,
        content,
        fn(c) { @common.bounded_regex_kind_pred(kind, c) },
        min_run=1,
        max_run~,
      )
    None => ()
  }
  match @common.ranged_regex_kind(pattern) {
    Some((kind, min_run, max_run)) =>
      return decode_replace_ranged_char_runs_direct(
        tokens,
        content,
        fn(c) { @common.bounded_regex_kind_pred(kind, c) },
        min_run~,
        max_run~,
      )
    None => ()
  }
  match @common.exact_regex_kind(pattern) {
    Some((kind, exact_run)) =>
      return decode_replace_ranged_char_runs_direct(
        tokens,
        content,
        fn(c) { @common.bounded_regex_kind_pred(kind, c) },
        min_run=exact_run,
        max_run=exact_run,
      )
    None => ()
  }
  match @common.min_regex_kind(pattern) {
    Some((kind, min_run)) =>
      return decode_replace_min_char_runs_direct(
        tokens,
        content,
        fn(c) { @common.bounded_regex_kind_pred(kind, c) },
        min_run~,
      )
    None => ()
  }
  if @common.is_simple_split_regex_pattern(pattern) {
    return decode_replace_simple_regex_direct(tokens, pattern, content)
  }
  let sb = StringBuilder::new()
  for t in tokens {
    sb.write_string(replace_all(t, pattern, content))
  }
  sb.to_string()
}

///|
fn decode_replace_simple_regex_direct(
  tokens : Array[String],
  pattern : String,
  content : String,
) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    match @common.replace_simple_regex(t, pattern, content) {
      Some(out) => sb.write_string(out)
      None => sb.write_string(t)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_char_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    let mut in_run = false
    for c in t {
      if pred(c) {
        if !in_run {
          sb.write_string(content)
          in_run = true
        }
      } else {
        sb.write_char(c)
        in_run = false
      }
    }
  }
  sb.to_string()
}

///|
fn decode_replace_ranged_char_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
  min_run~ : Int,
  max_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if pred(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else {
          c3 = c
        }
        run = run + 1
        if run == max_run {
          sb.write_string(content)
          run = 0
        }
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_min_char_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
  min_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if pred(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else if run == 3 {
          c3 = c
        }
        run = run + 1
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_punct_symbol_ranged_direct(
  tokens : Array[String],
  content : String,
  min_run~ : Int,
  max_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if is_punctuation_or_symbol_fast(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else {
          c3 = c
        }
        run = run + 1
        if run == max_run {
          sb.write_string(content)
          run = 0
        }
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn is_punctuation_or_symbol_fast(c : Char) -> Bool {
  let u = c.to_int()
  if u < 128 {
    return (u >= 0x21 && u <= 0x2F) ||
      (u >= 0x3A && u <= 0x40) ||
      (u >= 0x5B && u <= 0x60) ||
      (u >= 0x7B && u <= 0x7E)
  }
  if u >= 0x1F300 && u <= 0x1FAFF {
    return true
  }
  @common.is_unicode_punctuation_or_symbol(c)
}

///|
fn decode_replace_min_non_digit_direct(
  tokens : Array[String],
  content : String,
  min_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if !@common.is_decimal_number(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else if run == 3 {
          c3 = c
        }
        run = run + 1
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_not_whitespace_letter_number_ranged_direct(
  tokens : Array[String],
  content : String,
  min_run~ : Int,
  max_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if @common.is_not_whitespace_letter_or_number(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else {
          c3 = c
        }
        run = run + 1
        if run == max_run {
          sb.write_string(content)
          run = 0
        }
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn write_ranged_pending_chars(
  sb : StringBuilder,
  run : Int,
  c0 : Char,
  c1 : Char,
  c2 : Char,
  c3 : Char,
) -> Unit {
  if run > 0 {
    sb.write_char(c0)
  }
  if run > 1 {
    sb.write_char(c1)
  }
  if run > 2 {
    sb.write_char(c2)
  }
  if run > 3 {
    sb.write_char(c3)
  }
}

///|
fn decode_replace_leading_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    let chars = t.to_array()
    let n = chars.length()
    let mut start = 0
    while start < n && pred(chars[start]) {
      start = start + 1
    }
    if start > 0 {
      sb.write_string(content)
      for i in start..<n {
        sb.write_char(chars[i])
      }
    } else {
      sb.write_string(t)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_trailing_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    let chars = t.to_array()
    let mut stop = chars.length()
    while stop > 0 && pred(chars[stop - 1]) {
      stop = stop - 1
    }
    for i in 0..<stop {
      sb.write_char(chars[i])
    }
    if stop < chars.length() {
      sb.write_string(content)
    }
  }
  sb.to_string()
}

///|
/// Transform a token list (HF decode_chain semantics).
pub fn Decoder::decode_chain(
  self : Decoder,
  tokens : Array[String],
) -> Array[String] {
  match self {
    ByteLevel(..) =>
      // Map byte-level chars back to bytes across the whole sequence.
      [@pretokenizer.byte_level_decode_str(join(tokens))]
    WordPiece(prefix~, cleanup~) => decode_wordpiece(tokens, prefix, cleanup)
    BPEDecoder(suffix~) => decode_bpe(tokens, suffix)
    Metaspace(replacement~, ..) => decode_metaspace(tokens, replacement)
    Fuse => [join(tokens)]
    Replace(pattern~, content~) =>
      tokens.map(t => replace_all(t, pattern, content))
    Strip(content~, start~, stop~) =>
      tokens.map(t => strip_token(t, content, start, stop))
    ByteFallback => decode_byte_fallback(tokens)
    CTC(pad_token~, word_delimiter_token~, cleanup~) =>
      decode_ctc(tokens, pad_token, word_delimiter_token, cleanup)
    Sequence(decoders) => {
      match decode_sentencepiece_sequence_fast(decoders, tokens) {
        Some(out) => return out
        None => ()
      }
      let mut toks = tokens
      for d in decoders {
        toks = d.decode_chain(toks)
      }
      toks
    }
  }
}

///|
fn join(tokens : Array[String]) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    sb.write_string(t)
  }
  sb.to_string()
}

// ByteFallback: group runs of "<0xXX>" tokens, decode their bytes as UTF-8.
// Non-byte tokens pass through unchanged. Invalid UTF-8 byte runs become the
// replacement char per byte (HF behaviour).

///|
fn decode_byte_fallback(tokens : Array[String]) -> Array[String] {
  let out : Array[String] = []
  let pending : Array[Int] = []
  fn flush() -> Unit {
    if pending.length() > 0 {
      let bytes = @buffer.Buffer::Buffer()
      for b in pending {
        bytes.write_byte(b.to_byte())
      }
      out.push(@utf8.decode_lossy(bytes.to_bytes()[:]))
      pending.clear()
    }
  }

  for t in tokens {
    match parse_byte_token(t) {
      Some(b) => pending.push(b)
      None => {
        flush()
        out.push(t)
      }
    }
  }
  flush()
  out
}

// Fast path for the common Llama/SentencePiece decoder chain:
// Replace("▁", " ") -> ByteFallback -> Fuse -> Strip(" ", 1, 0).
// This avoids materializing three intermediate token arrays and performs the
// single-character replacement while joining tokens.

///|
fn decode_sentencepiece_sequence_fast(
  decoders : Array[Decoder],
  tokens : Array[String],
) -> Array[String]? {
  if decoders.length() != 4 {
    return None
  }
  let (pattern, content) = match decoders[0] {
    Replace(pattern~, content~) => (pattern, content)
    _ => return None
  }
  match decoders[1] {
    ByteFallback => ()
    _ => return None
  }
  match decoders[2] {
    Fuse => ()
    _ => return None
  }
  let (strip_content, start, stop) = match decoders[3] {
    Strip(content~, start~, stop~) => (content, start, stop)
    _ => return None
  }
  let pat = pattern.to_array()
  if pat.length() != 1 {
    return None
  }
  let sb = StringBuilder::new()
  let pending : Array[Int] = []
  fn flush_bytes() -> Unit {
    if pending.length() > 0 {
      let bytes = @buffer.Buffer::Buffer()
      for b in pending {
        bytes.write_byte(b.to_byte())
      }
      sb.write_string(@utf8.decode_lossy(bytes.to_bytes()[:]))
      pending.clear()
    }
  }
  for t in tokens {
    match parse_byte_token(t) {
      Some(b) => pending.push(b)
      None => {
        flush_bytes()
        write_replaced_token(sb, t, pat[0], content)
      }
    }
  }
  flush_bytes()
  Some([strip_token(sb.to_string(), strip_content, start, stop)])
}

///|
fn write_replaced_token(
  sb : StringBuilder,
  token : String,
  pattern : Char,
  content : String,
) -> Unit {
  for c in token {
    if c == pattern {
      sb.write_string(content)
    } else {
      sb.write_char(c)
    }
  }
}

// CTC decoder: collapse consecutive duplicate tokens, drop pad tokens, and map
// the word-delimiter token to a space. Optional cleanup of punctuation spacing.

///|
fn decode_ctc(
  tokens : Array[String],
  pad_token : String,
  word_delimiter_token : String,
  cleanup : Bool,
) -> Array[String] {
  let out : Array[String] = []
  let mut prev = ""
  let mut first = true
  for t in tokens {
    if !first && t == prev {
      continue // collapse consecutive duplicates
    }
    first = false
    prev = t
    if t == pad_token {
      continue
    }
    if t == word_delimiter_token {
      out.push(" ")
    } else {
      out.push(t)
    }
  }
  if cleanup {
    out.map(s => cleanup_text(s))
  } else {
    out
  }
}

// Parse "<0xXX>" -> byte value; None otherwise.

///|
fn parse_byte_token(t : String) -> Int? {
  if t.length() != 6 {
    return None
  }
  if t.unsafe_get(0).to_int() != '<'.to_int() ||
    t.unsafe_get(1).to_int() != '0'.to_int() ||
    t.unsafe_get(2).to_int() != 'x'.to_int() ||
    t.unsafe_get(5).to_int() != '>'.to_int() {
    return None
  }
  let hi = hex_val_int(t.unsafe_get(3).to_int())
  let lo = hex_val_int(t.unsafe_get(4).to_int())
  match (hi, lo) {
    (Some(h), Some(l)) => Some(h * 16 + l)
    _ => None
  }
}

///|
fn hex_val_int(u : Int) -> Int? {
  if u >= '0'.to_int() && u <= '9'.to_int() {
    Some(u - '0'.to_int())
  } else if u >= 'A'.to_int() && u <= 'F'.to_int() {
    Some(u - 'A'.to_int() + 10)
  } else if u >= 'a'.to_int() && u <= 'f'.to_int() {
    Some(u - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn decode_wordpiece(
  tokens : Array[String],
  prefix : String,
  cleanup : Bool,
) -> Array[String] {
  let sb = StringBuilder::new()
  for i, t in tokens {
    if i == 0 {
      sb.write_string(t)
    } else if t.has_prefix(prefix) {
      sb.write_string(drop_prefix(t, prefix))
    } else {
      sb.write_char(' ')
      sb.write_string(t)
    }
  }
  let s = sb.to_string()
  [if cleanup { cleanup_text(s) } else { s }]
}

///|
fn decode_bpe(tokens : Array[String], suffix : String) -> Array[String] {
  tokens.map(t => {
    if t.has_suffix(suffix) {
      drop_suffix(t, suffix) + " "
    } else {
      t
    }
  })
}

///|
fn decode_metaspace(
  tokens : Array[String],
  replacement : Char,
) -> Array[String] {
  let out : Array[String] = []
  for i, t in tokens {
    let sb = StringBuilder::new()
    for c in t {
      sb.write_char(if c == replacement { ' ' } else { c })
    }
    let s = sb.to_string()
    // Drop the leading space introduced by the prepended metaspace on token 0.
    if i == 0 && s.has_prefix(" ") {
      out.push(drop_prefix(s, " "))
    } else {
      out.push(s)
    }
  }
  out
}

// --- small string helpers ---

///|
fn drop_prefix(s : String, prefix : String) -> String {
  let pc = prefix.char_length()
  let chars = s.to_array()
  let sb = StringBuilder::new()
  for i in pc..<chars.length() {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn drop_suffix(s : String, suffix : String) -> String {
  let sc = suffix.char_length()
  let chars = s.to_array()
  let sb = StringBuilder::new()
  for i in 0..<(chars.length() - sc) {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn strip_token(t : String, content : Char, start : Int, stop : Int) -> String {
  let chars = t.to_array()
  let n = chars.length()
  let mut a = 0
  let mut b = n
  let mut removed = 0
  while a < b && removed < start && chars[a] == content {
    a = a + 1
    removed = removed + 1
  }
  removed = 0
  while b > a && removed < stop && chars[b - 1] == content {
    b = b - 1
    removed = removed + 1
  }
  let sb = StringBuilder::new()
  for i in a..<b {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

// BERT-style detokenization cleanup: remove spaces before punctuation, fix
// contractions like " ' s" -> "'s".

///|
fn cleanup_text(s : String) -> String {
  // HF's WordPiece/CTC cleanup is a fixed set of ASCII-space contractions and
  // punctuation rewrites. Implement it as one deterministic pass instead of the
  // old twelve literal replace passes; this is the hot path for BERT decode.
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder::new()
  let mut i = 0
  while i < n {
    if chars[i] == ' ' && i + 1 < n && should_drop_cleanup_space(chars, i) {
      i = i + 1
    } else {
      sb.write_char(chars[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
fn should_drop_cleanup_space(chars : Array[Char], i : Int) -> Bool {
  let next = chars[i + 1]
  if next == '.' ||
    next == ',' ||
    next == '?' ||
    next == '!' ||
    next == ';' ||
    next == ':' ||
    next == '\'' {
    return true
  }
  i + 3 < chars.length() &&
  next == 'n' &&
  chars[i + 2] == '\'' &&
  chars[i + 3] == 't'
}

// Replacement for HF decoder Replace. HF distinguishes literal String patterns
// from Regex patterns in JSON, but this lightweight representation keeps the
// pattern string only. Handle the common Regex forms seen in SentencePiece-style
// decoder configs explicitly, then fall back to literal substring replacement.

///|
fn replace_all(s : String, pattern : String, content : String) -> String {
  if pattern.is_empty() {
    return s
  }
  match @common.replace_simple_regex(s, pattern, content) {
    Some(out) => return out
    None => ()
  }
  match @common.replace_bounded_simple_regex(s, pattern, content) {
    Some(out) => return out
    None => ()
  }
  match @common.replace_anchored_simple_regex(s, pattern, content) {
    Some(out) => return out
    None => ()
  }
  if pattern == "\\s{2,}" || pattern == "[\\s]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=2,
    )
  }
  if pattern == "\\s{3,}" || pattern == "[\\s]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=3,
    )
  }
  if pattern == "\\s{4,}" || pattern == "[\\s]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=4,
    )
  }
  if pattern == "\\s{2}" || pattern == "[\\s]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      exact_run=2,
    )
  }
  if pattern == "\\s{3}" || pattern == "[\\s]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      exact_run=3,
    )
  }
  if pattern == "\\s{4}" || pattern == "[\\s]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      exact_run=4,
    )
  }
  if pattern == "^\\s+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  if pattern == "\\s+" {
    return @common.replace_whitespace_runs(s, content)
  }
  if pattern == "\\s+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  if pattern == "[\\r\\n]+" || pattern == "[\r\n]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      c == '\r' || c == '\n'
    })
  }
  if pattern == "[\\r\\n]{2,}" || pattern == "[\r\n]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      min_run=2,
    )
  }
  if pattern == "[\\r\\n]{3,}" || pattern == "[\r\n]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      min_run=3,
    )
  }
  if pattern == "[\\r\\n]{4,}" || pattern == "[\r\n]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      min_run=4,
    )
  }
  if pattern == "[\\r\\n]{2}" || pattern == "[\r\n]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      exact_run=2,
    )
  }
  if pattern == "[\\r\\n]{3}" || pattern == "[\r\n]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      exact_run=3,
    )
  }
  if pattern == "[\\r\\n]{4}" || pattern == "[\r\n]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      exact_run=4,
    )
  }
  if pattern == "\\d+" ||
    pattern == "[\\d]+" ||
    pattern == "[0-9]+" ||
    pattern == "\\p{N}+" ||
    pattern == "\\p{Number}+" ||
    pattern == "[\\p{N}]+" ||
    pattern == "[\\p{Number}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "^\\d+" ||
    pattern == "^[\\d]+" ||
    pattern == "^[0-9]+" ||
    pattern == "^\\p{N}+" ||
    pattern == "^\\p{Number}+" ||
    pattern == "^[\\p{N}]+" ||
    pattern == "^[\\p{Number}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "\\d+$" ||
    pattern == "[\\d]+$" ||
    pattern == "[0-9]+$" ||
    pattern == "\\p{N}+$" ||
    pattern == "\\p{Number}+$" ||
    pattern == "[\\p{N}]+$" ||
    pattern == "[\\p{Number}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "\\D+" ||
    pattern == "[\\D]+" ||
    pattern == "[^\\d]+" ||
    pattern == "[^0-9]+" ||
    pattern == "\\P{N}+" ||
    pattern == "\\P{Number}+" ||
    pattern == "[^\\p{N}]+" ||
    pattern == "[^\\p{Number}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_decimal_number(c)
    })
  }
  if pattern == "\\d{2,}" ||
    pattern == "[\\d]{2,}" ||
    pattern == "[0-9]{2,}" ||
    pattern == "\\p{N}{2,}" ||
    pattern == "\\p{Number}{2,}" ||
    pattern == "[\\p{N}]{2,}" ||
    pattern == "[\\p{Number}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{N}{2}" ||
    pattern == "\\p{Number}{2}" ||
    pattern == "[\\p{N}]{2}" ||
    pattern == "[\\p{Number}]{2}" ||
    pattern == "\\d{2}" ||
    pattern == "[\\d]{2}" ||
    pattern == "[0-9]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{N}{3}" ||
    pattern == "\\p{Number}{3}" ||
    pattern == "[\\p{N}]{3}" ||
    pattern == "[\\p{Number}]{3}" ||
    pattern == "\\d{3}" ||
    pattern == "[\\d]{3}" ||
    pattern == "[0-9]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{N}{4}" ||
    pattern == "\\p{Number}{4}" ||
    pattern == "[\\p{N}]{4}" ||
    pattern == "[\\p{Number}]{4}" ||
    pattern == "\\d{4}" ||
    pattern == "[\\d]{4}" ||
    pattern == "[0-9]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      exact_run=4,
    )
  }
  if pattern == "\\p{N}{1,3}" ||
    pattern == "\\p{Number}{1,3}" ||
    pattern == "[\\p{N}]{1,3}" ||
    pattern == "[\\p{Number}]{1,3}" ||
    pattern == "\\d{1,3}" ||
    pattern == "[\\d]{1,3}" ||
    pattern == "[0-9]{1,3}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      max_run=3,
    )
  }
  if pattern == "\\d{1,2}" || pattern == "[\\d]{1,2}" || pattern == "[0-9]{1,2}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      max_run=2,
    )
  }
  if pattern == "\\d{1,4}" || pattern == "[\\d]{1,4}" || pattern == "[0-9]{1,4}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      max_run=4,
    )
  }
  if pattern == "[ \\t]+" {
    return @common.replace_char_runs(s, content, fn(c) { c == ' ' || c == '\t' })
  }
  if pattern == "[ \\t]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      min_run=2,
    )
  }
  if pattern == "[ \\t]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      min_run=3,
    )
  }
  if pattern == "[ \\t]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      min_run=4,
    )
  }
  if pattern == "[ \\t]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      exact_run=2,
    )
  }
  if pattern == "[ \\t]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      exact_run=3,
    )
  }
  if pattern == "[ \\t]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      exact_run=4,
    )
  }
  if pattern == "\\w+" ||
    pattern == "[A-Za-z0-9_]+" ||
    pattern == "\\b\\w+\\b" ||
    pattern == "\\b[A-Za-z0-9_]+\\b" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_word_char(c)
    })
  }
  if pattern == "^\\w+" || pattern == "^[A-Za-z0-9_]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_word_char(c)
    })
  }
  if pattern == "\\w+$" || pattern == "[A-Za-z0-9_]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_word_char(c)
    })
  }
  if pattern == "\\W+" || pattern == "[^\\w]+" || pattern == "[^A-Za-z0-9_]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_word_char(c)
    })
  }
  if pattern == "\\w{2,}" || pattern == "[A-Za-z0-9_]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      min_run=2,
    )
  }
  if pattern == "\\w{2}" || pattern == "[A-Za-z0-9_]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      exact_run=2,
    )
  }
  if pattern == "\\w{3}" || pattern == "[A-Za-z0-9_]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      exact_run=3,
    )
  }
  if pattern == "\\w{4}" || pattern == "[A-Za-z0-9_]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      exact_run=4,
    )
  }
  if pattern == "[A-Za-z0-9]+" || pattern == "[a-zA-Z0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
  }
  if pattern == "[A-Za-z0-9]{2,}" || pattern == "[a-zA-Z0-9]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      min_run=2,
    )
  }
  if pattern == "[A-Za-z0-9]{2}" || pattern == "[a-zA-Z0-9]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      exact_run=2,
    )
  }
  if pattern == "[A-Za-z0-9]{3}" || pattern == "[a-zA-Z0-9]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      exact_run=3,
    )
  }
  if pattern == "[A-Za-z0-9]{4}" || pattern == "[a-zA-Z0-9]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      exact_run=4,
    )
  }
  if pattern == "^[A-Za-z0-9]+" || pattern == "^[a-zA-Z0-9]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
  }
  if pattern == "[A-Za-z0-9]+$" || pattern == "[a-zA-Z0-9]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
  }
  if pattern == "[^A-Za-z0-9]+" || pattern == "[^a-zA-Z0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_ascii_alnum(c)
    })
  }
  if pattern == "[A-Za-z]+" || pattern == "[a-zA-Z]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_ascii_letter(c)
    })
  }
  if pattern == "[A-Za-z]{2,}" || pattern == "[a-zA-Z]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      min_run=2,
    )
  }
  if pattern == "[A-Za-z]{2}" || pattern == "[a-zA-Z]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      exact_run=2,
    )
  }
  if pattern == "[A-Za-z]{3}" || pattern == "[a-zA-Z]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      exact_run=3,
    )
  }
  if pattern == "[A-Za-z]{4}" || pattern == "[a-zA-Z]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      exact_run=4,
    )
  }
  if pattern == "^[A-Za-z]+" || pattern == "^[a-zA-Z]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_ascii_letter(c)
    })
  }
  if pattern == "[A-Za-z]+$" || pattern == "[a-zA-Z]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_ascii_letter(c)
    })
  }
  if pattern == "[^A-Za-z]+" || pattern == "[^a-zA-Z]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_ascii_letter(c)
    })
  }
  if pattern == "\\p{L}+" ||
    pattern == "\\p{Letter}+" ||
    pattern == "[\\p{L}]+" ||
    pattern == "[\\p{Letter}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_letter(c)
    })
  }
  if pattern == "\\p{L}{2,}" ||
    pattern == "\\p{Letter}{2,}" ||
    pattern == "[\\p{L}]{2,}" ||
    pattern == "[\\p{Letter}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{L}{2}" ||
    pattern == "\\p{Letter}{2}" ||
    pattern == "[\\p{L}]{2}" ||
    pattern == "[\\p{Letter}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{L}{3}" ||
    pattern == "\\p{Letter}{3}" ||
    pattern == "[\\p{L}]{3}" ||
    pattern == "[\\p{Letter}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{L}{4}" ||
    pattern == "\\p{Letter}{4}" ||
    pattern == "[\\p{L}]{4}" ||
    pattern == "[\\p{Letter}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      exact_run=4,
    )
  }
  if pattern == "^\\p{L}+" ||
    pattern == "^\\p{Letter}+" ||
    pattern == "^[\\p{L}]+" ||
    pattern == "^[\\p{Letter}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_letter(c)
    })
  }
  if pattern == "\\p{L}+$" ||
    pattern == "\\p{Letter}+$" ||
    pattern == "[\\p{L}]+$" ||
    pattern == "[\\p{Letter}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_letter(c)
    })
  }
  if pattern == "\\P{L}+" ||
    pattern == "\\P{Letter}+" ||
    pattern == "[^\\p{L}]+" ||
    pattern == "[^\\p{Letter}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_letter(c)
    })
  }
  if pattern == "\\p{P}+" ||
    pattern == "\\p{Punctuation}+" ||
    pattern == "[\\p{P}]+" ||
    pattern == "[\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\p{P}{2,}" ||
    pattern == "\\p{Punctuation}{2,}" ||
    pattern == "[\\p{P}]{2,}" ||
    pattern == "[\\p{Punctuation}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{P}{2}" ||
    pattern == "\\p{Punctuation}{2}" ||
    pattern == "[\\p{P}]{2}" ||
    pattern == "[\\p{Punctuation}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{P}{3}" ||
    pattern == "\\p{Punctuation}{3}" ||
    pattern == "[\\p{P}]{3}" ||
    pattern == "[\\p{Punctuation}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{P}{4}" ||
    pattern == "\\p{Punctuation}{4}" ||
    pattern == "[\\p{P}]{4}" ||
    pattern == "[\\p{Punctuation}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      exact_run=4,
    )
  }
  if pattern == "^\\p{P}+" ||
    pattern == "^\\p{Punctuation}+" ||
    pattern == "^[\\p{P}]+" ||
    pattern == "^[\\p{Punctuation}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\p{P}+$" ||
    pattern == "\\p{Punctuation}+$" ||
    pattern == "[\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\P{P}+" ||
    pattern == "\\P{Punctuation}+" ||
    pattern == "[^\\p{P}]+" ||
    pattern == "[^\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\p{S}+" ||
    pattern == "\\p{Symbol}+" ||
    pattern == "[\\p{S}]+" ||
    pattern == "[\\p{Symbol}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_symbol(c)
    })
  }
  if pattern == "\\p{S}{2,}" ||
    pattern == "\\p{Symbol}{2,}" ||
    pattern == "[\\p{S}]{2,}" ||
    pattern == "[\\p{Symbol}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{S}{2}" ||
    pattern == "\\p{Symbol}{2}" ||
    pattern == "[\\p{S}]{2}" ||
    pattern == "[\\p{Symbol}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{S}{3}" ||
    pattern == "\\p{Symbol}{3}" ||
    pattern == "[\\p{S}]{3}" ||
    pattern == "[\\p{Symbol}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{S}{4}" ||
    pattern == "\\p{Symbol}{4}" ||
    pattern == "[\\p{S}]{4}" ||
    pattern == "[\\p{Symbol}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      exact_run=4,
    )
  }
  if pattern == "^\\p{S}+" ||
    pattern == "^\\p{Symbol}+" ||
    pattern == "^[\\p{S}]+" ||
    pattern == "^[\\p{Symbol}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_symbol(c)
    })
  }
  if pattern == "\\p{S}+$" ||
    pattern == "\\p{Symbol}+$" ||
    pattern == "[\\p{S}]+$" ||
    pattern == "[\\p{Symbol}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_symbol(c)
    })
  }
  if pattern == "\\P{S}+" ||
    pattern == "\\P{Symbol}+" ||
    pattern == "[^\\p{S}]+" ||
    pattern == "[^\\p{Symbol}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_symbol(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]+" ||
    pattern == "[\\p{S}\\p{P}]+" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]{2,}" ||
    pattern == "[\\p{S}\\p{P}]{2,}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2,}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      min_run=2,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{2}" ||
    pattern == "[\\p{S}\\p{P}]{2}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      exact_run=2,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{3}" ||
    pattern == "[\\p{S}\\p{P}]{3}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{3}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      exact_run=3,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{4}" ||
    pattern == "[\\p{S}\\p{P}]{4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      exact_run=4,
    )
  }
  if pattern == "^[\\p{P}\\p{S}]+" ||
    pattern == "^[\\p{S}\\p{P}]+" ||
    pattern == "^[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "^[\\p{Symbol}\\p{Punctuation}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]+$" ||
    pattern == "[\\p{S}\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+$" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[^\\p{P}\\p{S}]+" ||
    pattern == "[^\\p{S}\\p{P}]+" ||
    pattern == "[^\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[^\\p{Symbol}\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[^\\s\\p{L}\\p{N}]+" ||
    pattern == "[^\\s\\p{N}\\p{L}]+" ||
    pattern == "[^\\p{L}\\p{N}\\s]+" ||
    pattern == "[^\\p{N}\\p{L}\\s]+" ||
    pattern == "[^\\s\\p{Letter}\\p{Number}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_not_whitespace_letter_or_number(c)
    })
  }
  if pattern == "[^\\S\\r\\n]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
    })
  }
  if pattern == "[^\\S\\r\\n]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      min_run=2,
    )
  }
  if pattern == "[^\\S\\r\\n]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      min_run=3,
    )
  }
  if pattern == "[^\\S\\r\\n]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      min_run=4,
    )
  }
  if pattern == "[^\\S\\r\\n]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      exact_run=2,
    )
  }
  if pattern == "[^\\S\\r\\n]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      exact_run=3,
    )
  }
  if pattern == "[^\\S\\r\\n]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      exact_run=4,
    )
  }
  @common.replace_literal(s, pattern, content)
}
