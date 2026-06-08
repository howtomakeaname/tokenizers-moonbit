// AddedVocabulary: extract added/special tokens from text *before* normalization
// and pre-tokenization, so tokens like "<s>", "[MASK]", "<|endoftext|>" become
// their own tokens even when they appear in the middle of text.
//
// HuggingFace uses an Aho-Corasick automaton (daachorse) with leftmost-longest
// matching. MoonBit has no such library, but the number of added/special tokens
// is small (typically 1..few-hundred), so a hand-written char-trie with a
// leftmost-longest single pass is more than adequate.

// A char-trie node-array. children[node] maps a Char to the next node index;
// terminal[node] is Some(content) when a complete added-token ends there.

///|
priv struct CharTrie {
  children : Array[Map[Char, Int]]
  terminal : Array[String?]
}

///|
fn CharTrie::new() -> CharTrie {
  // node 0 is the root.
  { children: [Map([])], terminal: [None] }
}

///|
fn CharTrie::insert(self : CharTrie, content : String) -> Unit {
  let mut node = 0
  for c in content {
    match self.children[node].get(c) {
      Some(nx) => node = nx
      None => {
        let nx = self.children.length()
        self.children.push(Map([]))
        self.terminal.push(None)
        self.children[node][c] = nx
        node = nx
      }
    }
  }
  self.terminal[node] = Some(content)
}

// Find the longest token that is a prefix of chars[start..]; returns
// (content, end_char_index) or None.

///|
fn CharTrie::longest_match(
  self : CharTrie,
  chars : Array[Char],
  start : Int,
) -> (String, Int)? {
  let mut node = 0
  let mut i = start
  let mut last : (String, Int)? = None
  while i < chars.length() {
    match self.children[node].get(chars[i]) {
      None => break
      Some(nx) => {
        node = nx
        i = i + 1
        match self.terminal[nx] {
          Some(content) => last = Some((content, i))
          None => ()
        }
      }
    }
  }
  last
}

///|
/// Per-token configuration parsed from tokenizer.json "added_tokens".
struct AddedTokenInfo {
  id : Int
  content : String
  single_word : Bool
  lstrip : Bool
  rstrip : Bool
  normalized : Bool
  special : Bool
} derive(Debug, Eq)

///|
/// The added-vocabulary state attached to a Tokenizer.
struct AddedVocabulary {
  by_content : Map[String, AddedTokenInfo]
  id_to_content : Map[Int, String]
  // Tokens matched against the *original* text (normalized == false).
  non_normalized : CharTrie
  // Tokens matched against the *normalized* text (normalized == true).
  normalized : CharTrie
  has_any : Bool
}

///|
/// A segment of the input produced by extraction.
enum Segment {
  // A matched added/special token; emitted directly, bypassing the model.
  Special(info~ : AddedTokenInfo, offsets~ : (Int, Int))
  // Ordinary text to be normalized + pre-tokenized + modeled.
  Normal(text~ : String, base_offset~ : Int)
} derive(Debug, Eq)

///|
/// Build an AddedVocabulary from parsed token infos.
fn AddedVocabulary::new(tokens : Array[AddedTokenInfo]) -> AddedVocabulary {
  let by_content : Map[String, AddedTokenInfo] = {}
  let id_to_content : Map[Int, String] = {}
  let non_normalized = CharTrie::new()
  let normalized = CharTrie::new()
  for t in tokens {
    by_content[t.content] = t
    id_to_content[t.id] = t.content
    if t.normalized {
      normalized.insert(t.content)
    } else {
      non_normalized.insert(t.content)
    }
  }
  {
    by_content,
    id_to_content,
    non_normalized,
    normalized,
    has_any: tokens.length() > 0,
  }
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
        let info = self.by_content.get(content).unwrap()
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
        if info.special && !keep_special {
          // Treat the special token as plain text for this segment.
          for k in lo..<hi {
            out.push(Normal(text=char_str(chars[k]), base_offset=base + k))
          }
        } else {
          out.push(Special(info~, offsets=(base + lo, base + hi)))
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
  if !self.has_any {
    return [Normal(text~, base_offset=0)]
  }
  self.split_with(self.non_normalized, text, 0, keep_special)
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
  @common.is_ascii_whitespace(c)
}

///|
fn char_str(c : Char) -> String {
  @common.char_string(c)
}
