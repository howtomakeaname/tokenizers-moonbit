///|
fn AddedVocabulary::new_with_normalizer(
  tokens : Array[AddedTokenInfo],
  encode_special_tokens : Bool,
  normalizer : @normalizer.Normalizer?,
) -> AddedVocabulary {
  let by_content : Map[String, AddedTokenInfo] = {}
  let id_to_content : Map[Int, String] = {}
  let id_to_token : Map[Int, AddedTokenInfo] = {}
  let match_to_token : Map[String, AddedTokenInfo] = {}
  let non_normalized = CharTrie::new()
  let normalized = CharTrie::new()
  for t in tokens {
    by_content[t.content] = t
    id_to_content[t.id] = t.content
    id_to_token[t.id] = t
    if t.normalized {
      let pattern = match normalizer {
        Some(nm) => nm.normalize(t.content)
        None => t.content
      }
      normalized.insert(pattern)
      match_to_token[pattern] = t
    } else {
      non_normalized.insert(t.content)
      match_to_token[t.content] = t
    }
  }
  {
    by_content,
    id_to_content,
    id_to_token,
    non_normalized,
    normalized,
    match_to_token,
    encode_special_tokens,
    has_any: tokens.length() > 0,
  }
}

///|
fn AddedVocabulary::with_encode_special_tokens(
  self : AddedVocabulary,
  encode_special_tokens : Bool,
) -> AddedVocabulary {
  { ..self, encode_special_tokens, }
}

///|
fn AddedVocabulary::with_normalizer(
  self : AddedVocabulary,
  normalizer : @normalizer.Normalizer?,
) -> AddedVocabulary {
  AddedVocabulary::new_with_normalizer(
    self.to_infos(),
    self.encode_special_tokens,
    normalizer,
  )
}

///|
fn AddedVocabulary::id_to_token(self : AddedVocabulary, id : Int) -> String? {
  self.id_to_content.get(id)
}

///|
fn AddedVocabulary::token_to_id(self : AddedVocabulary, token : String) -> Int? {
  self.by_content.get(token).map(t => t.id)
}

///|
fn AddedVocabulary::get_vocab(self : AddedVocabulary) -> Map[String, Int] {
  let out : Map[String, Int] = {}
  for kv in self.by_content.to_array() {
    out[kv.0] = kv.1.id
  }
  out
}

///|
fn AddedVocabulary::to_infos(self : AddedVocabulary) -> Array[AddedTokenInfo] {
  let out : Array[AddedTokenInfo] = []
  for kv in self.by_content.to_array() {
    out.push(kv.1)
  }
  out
}

///|
fn AddedVocabulary::get_added_tokens_decoder(
  self : AddedVocabulary,
) -> Map[Int, AddedToken] {
  let out : Map[Int, AddedToken] = {}
  for kv in self.id_to_token.to_array() {
    out[kv.0] = kv.1.to_added_token()
  }
  out
}

///|
fn AddedVocabulary::is_special_token(
  self : AddedVocabulary,
  token : String,
) -> Bool {
  match self.by_content.get(token) {
    Some(info) => info.special
    None => false
  }
}

///|
fn AddedVocabulary::get_encode_special_tokens(self : AddedVocabulary) -> Bool {
  self.encode_special_tokens
}

///|
fn AddedTokenInfo::to_added_token(self : AddedTokenInfo) -> AddedToken {
  {
    content: self.content,
    single_word: self.single_word,
    lstrip: self.lstrip,
    rstrip: self.rstrip,
    normalized: self.normalized,
    special: self.special,
  }
}

///|
/// Whether the given id is a special added token.
fn AddedVocabulary::is_special_id(self : AddedVocabulary, id : Int) -> Bool {
  match self.id_to_content.get(id) {
    Some(content) =>
      match self.by_content.get(content) {
        Some(info) => info.special
        None => false
      }
    None => false
  }
}

// Scan `text` with `trie`, splitting out matched added tokens. Unmatched runs
// become Normal segments. `base` is the char offset of `text` in the original.
// `keep_special` controls whether special tokens are emitted as Special (true)
// or folded back into Normal text (false) — used for add_special_tokens=false.

///|
fn AddedVocabulary::split_with(
  self : AddedVocabulary,
  trie : CharTrie,
  text : String,
  base : Int,
  keep_special : Bool,
) -> Array[Segment] {
  let chars = text.to_array()
  let n = chars.length()
  let out : Array[Segment] = []
  // We track the pending normal run as a half-open char range [buf_start, i).
  let mut buf_start = 0
  let mut i = 0
  // Flush the normal run [buf_start, upto) and move buf_start to `from`.
  fn flush(upto : Int, from : Int) -> Unit {
    if upto > buf_start {
      let sb = StringBuilder::new()
      for k in buf_start..<upto {
        sb.write_char(chars[k])
      }
      out.push(Normal(text=sb.to_string(), base_offset=base + buf_start))
    }
    buf_start = from
  }

  while i < n {
    match trie.longest_match(chars, i) {
      Some((content, end)) => {
        let info = self.match_to_token.get(content).unwrap()
        if info.special && self.encode_special_tokens {
          i = i + 1
          continue
        }
        // single_word: require non-word boundaries on both sides.
        let ok = if info.single_word {
          let left_ok = i == 0 || !is_word_char(chars[i - 1])
          let right_ok = end >= n || !is_word_char(chars[end])
          left_ok && right_ok
        } else {
          true
        }
        if !ok {
          // not a valid match here; leave char in the normal run and advance
          i = i + 1
          continue
        }
        // lstrip / rstrip extend the match over surrounding whitespace.
        let mut lo = i
        let mut hi = end
        if info.lstrip {
          while lo > buf_start && is_ws(chars[lo - 1]) {
            lo = lo - 1
          }
        }
        if info.rstrip {
          while hi < n && is_ws(chars[hi]) {
            hi = hi + 1
          }
        }
        // Normal text before `lo`; resume the normal run at `hi`.
        flush(lo, hi)
        let value = char_range_string(chars, lo, hi)
        if info.special && !keep_special {
          // Treat the special token as plain text for this segment.
          for k in lo..<hi {
            out.push(Normal(text=char_str(chars[k]), base_offset=base + k))
          }
        } else {
          out.push(Special(info~, value~, offsets=(base + lo, base + hi)))
        }
        i = hi
      }
      None => i = i + 1
    }
  }
  flush(n, n)
  out
}

///|
/// Extract added tokens from text in two stages (HF order):
/// 1) match non-normalized tokens against the original text;
/// 2) (caller normalizes the Normal pieces, then) match normalized tokens.
/// This function does stage 1 only; stage 2 is applied per Normal piece by the
/// caller after normalization. Returns stage-1 segments.
fn AddedVocabulary::extract_stage1(
  self : AddedVocabulary,
  text : String,
  keep_special~ : Bool,
) -> Array[Segment] {
  self.extract_stage1_at(text, base=0, keep_special~)
}

///|
/// Stage 1 with an explicit base offset. Used by pre-tokenized encode, where
/// each input word is laid out inside a synthetic single-space-joined string.
fn AddedVocabulary::extract_stage1_at(
  self : AddedVocabulary,
  text : String,
  base~ : Int,
  keep_special~ : Bool,
) -> Array[Segment] {
  if !self.has_any {
    return [Normal(text~, base_offset=base)]
  }
  self.split_with(self.non_normalized, text, base, keep_special)
}

///|
/// Stage 2: match normalized added tokens within an already-normalized string.
fn AddedVocabulary::extract_stage2(
  self : AddedVocabulary,
  normalized_text : String,
  base : Int,
  keep_special~ : Bool,
) -> Array[Segment] {
  if !self.has_any {
    return [Normal(text=normalized_text, base_offset=base)]
  }
  self.split_with(self.normalized, normalized_text, base, keep_special)
}

///|
fn is_word_char(c : Char) -> Bool {
  @common.is_word_char(c)
}

///|
fn is_ws(c : Char) -> Bool {
  @common.is_unicode_whitespace(c.to_int())
}

///|
fn char_str(c : Char) -> String {
  @common.char_string(c)
}

///|
fn char_range_string(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}
