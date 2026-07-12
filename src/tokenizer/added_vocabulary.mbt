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
/// Public HF-style added token configuration. `Tokenizer::add_tokens` and
/// `Tokenizer::add_special_tokens` convert these into the internal
/// `AddedVocabulary` trie entries used by the encode pipeline.
pub struct AddedToken {
  content : String
  single_word : Bool
  lstrip : Bool
  rstrip : Bool
  normalized : Bool
  special : Bool
} derive(Debug, Eq)

///|
/// Serializable/interoperable snapshot of an added token. This mirrors the
/// fields used by HuggingFace tokenizers and lets Python binding layers pickle
/// or tuple-convert an `AddedToken` without depending on MoonBit record layout.
pub struct AddedTokenState {
  content : String
  single_word : Bool
  lstrip : Bool
  rstrip : Bool
  normalized : Bool
  special : Bool
} derive(Debug, Eq)

///|
pub fn AddedToken::new(
  content : String,
  single_word? : Bool = false,
  lstrip? : Bool = false,
  rstrip? : Bool = false,
  normalized? : Bool? = None,
  special? : Bool = false,
) -> AddedToken {
  let normalized = match normalized {
    Some(v) => v
    None => !special
  }
  { content, single_word, lstrip, rstrip, normalized, special }
}

///|
/// Build an added token from a state snapshot.
pub fn AddedToken::from_state(state : AddedTokenState) -> AddedToken {
  {
    content: state.content,
    single_word: state.single_word,
    lstrip: state.lstrip,
    rstrip: state.rstrip,
    normalized: state.normalized,
    special: state.special,
  }
}

///|
/// Build an added token from the common tuple representation
/// `(content, single_word, lstrip, rstrip, normalized, special)`.
pub fn AddedToken::from_tuple(
  t : (String, Bool, Bool, Bool, Bool, Bool),
) -> AddedToken {
  {
    content: t.0,
    single_word: t.1,
    lstrip: t.2,
    rstrip: t.3,
    normalized: t.4,
    special: t.5,
  }
}

///|
/// Return `(content, single_word, lstrip, rstrip, normalized, special)`.
pub fn AddedToken::as_tuple(
  self : AddedToken,
) -> (String, Bool, Bool, Bool, Bool, Bool) {
  (
    self.content,
    self.single_word,
    self.lstrip,
    self.rstrip,
    self.normalized,
    self.special,
  )
}

///|
/// Return a Python-binding-friendly state snapshot.
pub fn AddedToken::get_state(self : AddedToken) -> AddedTokenState {
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
/// Python pickle compatibility alias for `get_state`.
pub fn AddedToken::__getstate__(self : AddedToken) -> AddedTokenState {
  self.get_state()
}

///|
/// Python pickle compatibility alias for restoring added-token state.
pub fn AddedToken::__setstate__(state : AddedTokenState) -> AddedToken {
  AddedToken::from_state(state)
}

///|
/// Python binding alias for `str(added_token)`.
pub fn AddedToken::__str__(self : AddedToken) -> String {
  self.content
}

///|
/// Python binding alias for `repr(added_token)`.
pub fn AddedToken::__repr__(self : AddedToken) -> String {
  let sb = StringBuilder::new()
  sb.write_string("AddedToken(")
  write_repr_string(sb, self.content)
  sb.write_string(", rstrip=")
  sb.write_string(bool_repr(self.rstrip))
  sb.write_string(", lstrip=")
  sb.write_string(bool_repr(self.lstrip))
  sb.write_string(", single_word=")
  sb.write_string(bool_repr(self.single_word))
  sb.write_string(", normalized=")
  sb.write_string(bool_repr(self.normalized))
  sb.write_string(", special=")
  sb.write_string(bool_repr(self.special))
  sb.write_char(')')
  sb.to_string()
}

///|
pub fn AddedToken::get_content(self : AddedToken) -> String {
  self.content
}

///|
/// Python/property-style alias for `get_content`.
pub fn AddedToken::content(self : AddedToken) -> String {
  self.get_content()
}

///|
pub fn AddedToken::get_single_word(self : AddedToken) -> Bool {
  self.single_word
}

///|
/// Python/property-style alias for `get_single_word`.
pub fn AddedToken::single_word(self : AddedToken) -> Bool {
  self.get_single_word()
}

///|
pub fn AddedToken::get_lstrip(self : AddedToken) -> Bool {
  self.lstrip
}

///|
/// Python/property-style alias for `get_lstrip`.
pub fn AddedToken::lstrip(self : AddedToken) -> Bool {
  self.get_lstrip()
}

///|
pub fn AddedToken::get_rstrip(self : AddedToken) -> Bool {
  self.rstrip
}

///|
/// Python/property-style alias for `get_rstrip`.
pub fn AddedToken::rstrip(self : AddedToken) -> Bool {
  self.get_rstrip()
}

///|
pub fn AddedToken::get_normalized(self : AddedToken) -> Bool {
  self.normalized
}

///|
/// Python/property-style alias for `get_normalized`.
pub fn AddedToken::normalized(self : AddedToken) -> Bool {
  self.get_normalized()
}

///|
pub fn AddedToken::get_special(self : AddedToken) -> Bool {
  self.special
}

///|
/// Predicate alias for `get_special`. `AddedToken::special(String)` remains
/// the constructor for special tokens, so this avoids overloading that name.
pub fn AddedToken::is_special(self : AddedToken) -> Bool {
  self.get_special()
}

///|
pub fn AddedToken::special(content : String) -> AddedToken {
  AddedToken::new(content, special=true)
}

///|
pub fn AddedToken::with_single_word(
  self : AddedToken,
  single_word : Bool,
) -> AddedToken {
  { ..self, single_word, }
}

///|
pub fn AddedToken::with_lstrip(self : AddedToken, lstrip : Bool) -> AddedToken {
  { ..self, lstrip, }
}

///|
pub fn AddedToken::with_rstrip(self : AddedToken, rstrip : Bool) -> AddedToken {
  { ..self, rstrip, }
}

///|
pub fn AddedToken::with_normalized(
  self : AddedToken,
  normalized : Bool,
) -> AddedToken {
  { ..self, normalized, }
}

///|
pub fn AddedToken::with_special(
  self : AddedToken,
  special : Bool,
) -> AddedToken {
  { ..self, special, }
}

///|
/// Set content. Returns a new AddedToken.
pub fn AddedToken::set_content(
  self : AddedToken,
  content : String,
) -> AddedToken {
  { ..self, content, }
}

///|
/// Python/property-style setter alias for content.
pub fn AddedToken::set_content_alias(
  self : AddedToken,
  content : String,
) -> AddedToken {
  self.set_content(content)
}

///|
/// Set special flag. Returns a new AddedToken.
pub fn AddedToken::set_special(self : AddedToken, special : Bool) -> AddedToken {
  { ..self, special, }
}

///|
/// Python/property-style setter alias for special.
pub fn AddedToken::set_special_alias(
  self : AddedToken,
  special : Bool,
) -> AddedToken {
  self.set_special(special)
}

///|
/// Python binding alias for `with_single_word`. Returns a new AddedToken with
/// the updated single_word flag, preserving immutability.
pub fn AddedToken::set_single_word(
  self : AddedToken,
  single_word : Bool,
) -> AddedToken {
  self.with_single_word(single_word)
}

///|
/// Python binding alias for `set_single_word`.
pub fn AddedToken::set_single_word_alias(
  self : AddedToken,
  single_word : Bool,
) -> AddedToken {
  self.set_single_word(single_word)
}

///|
/// Python binding alias for `with_lstrip`. Returns a new AddedToken with the
/// updated lstrip flag, preserving immutability.
pub fn AddedToken::set_lstrip(self : AddedToken, lstrip : Bool) -> AddedToken {
  self.with_lstrip(lstrip)
}

///|
/// Python binding alias for `set_lstrip`.
pub fn AddedToken::set_lstrip_alias(
  self : AddedToken,
  lstrip : Bool,
) -> AddedToken {
  self.set_lstrip(lstrip)
}

///|
/// Python binding alias for `with_rstrip`. Returns a new AddedToken with the
/// updated rstrip flag, preserving immutability.
pub fn AddedToken::set_rstrip(self : AddedToken, rstrip : Bool) -> AddedToken {
  self.with_rstrip(rstrip)
}

///|
/// Python binding alias for `set_rstrip`.
pub fn AddedToken::set_rstrip_alias(
  self : AddedToken,
  rstrip : Bool,
) -> AddedToken {
  self.set_rstrip(rstrip)
}

///|
/// Python binding alias for `with_normalized`. Returns a new AddedToken with
/// the updated normalized flag, preserving immutability.
pub fn AddedToken::set_normalized(
  self : AddedToken,
  normalized : Bool,
) -> AddedToken {
  self.with_normalized(normalized)
}

///|
/// Python binding alias for `set_normalized`.
pub fn AddedToken::set_normalized_alias(
  self : AddedToken,
  normalized : Bool,
) -> AddedToken {
  self.set_normalized(normalized)
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
  id_to_token : Map[Int, AddedTokenInfo]
  // Tokens matched against the *original* text (normalized == false).
  non_normalized : CharTrie
  // Tokens matched against the *normalized* text (normalized == true).  HF
  // stores the post-normalizer surface in this trie, e.g. Llama's "</s>"
  // becomes "▁</s>" after the Metaspace-style normalizer.
  normalized : CharTrie
  // Matched trie pattern -> original token info.  Normalized added tokens may be
  // inserted under a pattern that differs from their original `content`.
  match_to_token : Map[String, AddedTokenInfo]
  // HF `encode_special_tokens`: when true, special added tokens are left in the
  // ordinary text path instead of being extracted as special tokens.
  encode_special_tokens : Bool
  has_any : Bool
}

///|
/// A segment of the input produced by extraction.
enum Segment {
  // A matched added/special token; emitted directly, bypassing the model.  The
  // value is the matched surface after lstrip/rstrip/normalization, matching HF's
  // `Token.value` for inline added tokens.
  Special(info~ : AddedTokenInfo, value~ : String, offsets~ : (Int, Int))
  // Ordinary text to be normalized + pre-tokenized + modeled.
  Normal(text~ : String, base_offset~ : Int)
} derive(Debug, Eq)

///|
/// Build an AddedVocabulary from parsed token infos.
fn AddedVocabulary::new(tokens : Array[AddedTokenInfo]) -> AddedVocabulary {
  AddedVocabulary::new_with_encode_special_tokens(tokens, false)
}

///|
fn AddedVocabulary::new_with_encode_special_tokens(
  tokens : Array[AddedTokenInfo],
  encode_special_tokens : Bool,
) -> AddedVocabulary {
  AddedVocabulary::new_with_normalizer(tokens, encode_special_tokens, None)
}

///|
