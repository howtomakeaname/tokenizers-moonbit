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
  let cs = t.to_array()
  if cs.length() != 6 {
    return None
  }
  if cs[0] != '<' || cs[1] != '0' || cs[2] != 'x' || cs[5] != '>' {
    return None
  }
  let hi = hex_val(cs[3])
  let lo = hex_val(cs[4])
  match (hi, lo) {
    (Some(h), Some(l)) => Some(h * 16 + l)
    _ => None
  }
}

///|
fn hex_val(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
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

///|
fn replace_all(s : String, pattern : String, content : String) -> String {
  if pattern.is_empty() {
    return s
  }
  let pat = pattern.to_array()
  let src = s.to_array()
  let n = src.length()
  let m = pat.length()
  let sb = StringBuilder::new()
  let mut i = 0
  while i < n {
    if i + m <= n && matches_at(src, i, pat) {
      sb.write_string(content)
      i = i + m
    } else {
      sb.write_char(src[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
fn matches_at(src : Array[Char], at : Int, pat : Array[Char]) -> Bool {
  for k in 0..<pat.length() {
    if src[at + k] != pat[k] {
      return false
    }
  }
  true
}
