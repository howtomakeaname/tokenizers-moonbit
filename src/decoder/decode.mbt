// Decoding behaviour: token surfaces -> reconstructed text.
//
// Following HuggingFace, each decoder is a `decode_chain(tokens) -> tokens`
// transform; `Sequence` composes them, and the final text is the join of the
// resulting token list. This token-list model is required for decoders like
// ByteFallback that must group consecutive byte tokens before a later Fuse.

///|
/// Decode a list of token surface strings back into text.
pub fn Decoder::decode(self : Decoder, tokens : Array[String]) -> String {
  let out = self.decode_chain(tokens)
  let sb = StringBuilder::new()
  for t in out {
    sb.write_string(t)
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
  let replacements = [
    (" .", "."),
    (" ,", ","),
    (" ?", "?"),
    (" !", "!"),
    (" ;", ";"),
    (" :", ":"),
    (" '", "'"),
    (" n't", "n't"),
    (" 'm", "'m"),
    (" 's", "'s"),
    (" 've", "'ve"),
    (" 're", "'re"),
  ]
  let mut out = s
  for r in replacements {
    out = replace_all(out, r.0, r.1)
  }
  out
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
  if pattern == " {2,}" {
    return @common.replace_space_runs(s, content, min_run=2)
  }
  if pattern == "\\s{2,}" || pattern == "[\\s]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=2,
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
  if pattern == "[A-Za-z0-9]+" || pattern == "[a-zA-Z0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
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
  @common.replace_literal(s, pattern, content)
}
