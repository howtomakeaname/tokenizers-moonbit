// Decoding behaviour: token surfaces -> reconstructed text.

/// Decode a list of token surface strings back into text.
pub fn Decoder::decode(self : Decoder, tokens : Array[String]) -> String {
  match self {
    ByteLevel(..) => {
      // Concatenate all token surfaces, then map byte-level chars back to bytes
      // and decode as UTF-8.
      let sb = StringBuilder::new()
      for t in tokens {
        sb.write_string(t)
      }
      @pretokenizer.byte_level_decode_str(sb.to_string())
    }
    WordPiece(prefix~, cleanup~) => decode_wordpiece(tokens, prefix, cleanup)
    BPEDecoder(suffix~) => decode_bpe(tokens, suffix)
    Metaspace(replacement~, ..) => decode_metaspace(tokens, replacement)
    Fuse => {
      let sb = StringBuilder::new()
      for t in tokens {
        sb.write_string(t)
      }
      sb.to_string()
    }
    Replace(pattern~, content~) => {
      let sb = StringBuilder::new()
      for t in tokens {
        sb.write_string(t)
      }
      replace_all(sb.to_string(), pattern, content)
    }
    Strip(content~, start~, stop~) => {
      // Apply per-token strip of up to `start`/`stop` leading/trailing `content`.
      let out = StringBuilder::new()
      for t in tokens {
        out.write_string(strip_token(t, content, start, stop))
      }
      out.to_string()
    }
    Sequence(decoders) => {
      // Run a decoder sequence: each step transforms the token list. For the
      // simple text-producing steps we fold into one string progressively.
      // Most real configs are Sequence of [Replace, ByteLevel, Fuse]; we apply
      // them by decoding to a single string then re-wrapping as one token.
      let mut toks = tokens
      for d in decoders {
        toks = [d.decode(toks)]
      }
      toks[0]
    }
  }
}

fn decode_wordpiece(
  tokens : Array[String],
  prefix : String,
  cleanup : Bool,
) -> String {
  let sb = StringBuilder::new()
  for i, t in tokens {
    if i == 0 {
      sb.write_string(t)
    } else if t.has_prefix(prefix) {
      // continuation subword: drop prefix, no space
      sb.write_string(drop_prefix(t, prefix))
    } else {
      sb.write_char(' ')
      sb.write_string(t)
    }
  }
  let s = sb.to_string()
  if cleanup {
    cleanup_text(s)
  } else {
    s
  }
}

fn decode_bpe(tokens : Array[String], suffix : String) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    let piece = if t.has_suffix(suffix) {
      drop_suffix(t, suffix) + " "
    } else {
      t
    }
    sb.write_string(piece)
  }
  sb.to_string()
}

fn decode_metaspace(tokens : Array[String], replacement : Char) -> String {
  // Replace the metaspace char with a regular space; the leading metaspace of
  // the first token is dropped (HF prepend behaviour).
  let sb = StringBuilder::new()
  for t in tokens {
    for c in t {
      if c == replacement {
        sb.write_char(' ')
      } else {
        sb.write_char(c)
      }
    }
  }
  let s = sb.to_string()
  // Drop a single leading space introduced by the prepended metaspace.
  if s.has_prefix(" ") {
    drop_prefix(s, " ")
  } else {
    s
  }
}

// --- small string helpers ---

fn drop_prefix(s : String, prefix : String) -> String {
  let pc = prefix.char_length()
  let chars = s.to_array()
  let sb = StringBuilder::new()
  for i in pc..<chars.length() {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

fn drop_suffix(s : String, suffix : String) -> String {
  let sc = suffix.char_length()
  let chars = s.to_array()
  let sb = StringBuilder::new()
  for i in 0..<(chars.length() - sc) {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

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

fn matches_at(src : Array[Char], at : Int, pat : Array[Char]) -> Bool {
  for k in 0..<pat.length() {
    if src[at + k] != pat[k] {
      return false
    }
  }
  true
}
