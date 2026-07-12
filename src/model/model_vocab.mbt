///|
pub fn Model::id_to_token(self : Model, id : Int) -> String? {
  match self {
    BPE(m) => lookup_id(m.vocab_r, id)
    WordPiece(m) => lookup_id(m.vocab_r, id)
    Unigram(m) => lookup_id(m.vocab_r, id)
    WordLevel(m) => lookup_id(m.vocab_r, id)
  }
}

///|
fn lookup_id(vocab_r : Array[String?], id : Int) -> String? {
  if id < 0 || id >= vocab_r.length() {
    None
  } else {
    vocab_r[id]
  }
}

///|
/// Look up an id by token surface.
pub fn Model::token_to_id(self : Model, token : String) -> Int? {
  match self {
    BPE(m) => m.vocab.get(token)
    WordPiece(m) => m.vocab.get(token)
    Unigram(m) => m.vocab.get(token).map(fn(p) { p.0 })
    WordLevel(m) => m.vocab.get(token)
  }
}

///|
/// Total vocabulary size.
pub fn Model::vocab_size(self : Model) -> Int {
  match self {
    BPE(m) => m.vocab.length()
    WordPiece(m) => m.vocab.length()
    Unigram(m) => m.vocab.length()
    WordLevel(m) => m.vocab.length()
  }
}

///|
/// HF-style getter alias for `vocab_size`.
pub fn Model::get_vocab_size(self : Model) -> Int {
  self.vocab_size()
}

///|
/// Return a copy of the model vocabulary as `token -> id`.
pub fn Model::get_vocab(self : Model) -> Map[String, Int] {
  match self {
    BPE(m) => m.vocab.copy()
    WordPiece(m) => m.vocab.copy()
    Unigram(m) => {
      let out : Map[String, Int] = {}
      for kv in m.vocab.to_array() {
        out[kv.0] = kv.1.0
      }
      out
    }
    WordLevel(m) => m.vocab.copy()
  }
}

///|
/// Python/property-style alias for `get_vocab`.
pub fn Model::vocab(self : Model) -> Map[String, Int] {
  self.get_vocab()
}

///|
/// Construct a WordLevel model directly from an in-memory vocabulary.
/// The vocabulary is copied so later caller mutations do not affect the model.
pub fn Model::wordlevel(
  vocab : Map[String, Int],
  unk_token? : String = "<unk>",
) -> Model {
  let copied = vocab.copy()
  WordLevel(WordLevelModel::{
    vocab: copied,
    vocab_r: build_vocab_r(copied),
    unk_token,
  })
}

///|
/// Construct a WordPiece model directly from an in-memory vocabulary.
/// This mirrors the common HF `models.WordPiece(vocab=...)` migration path.
pub fn Model::wordpiece(
  vocab : Map[String, Int],
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None,
  max_input_chars_per_word? : Int = 100,
) -> Model {
  let copied = vocab.copy()
  WordPiece(WordPieceModel::{
    vocab: copied,
    vocab_r: build_vocab_r(copied),
    unk_token,
    continuing_subword_prefix,
    end_of_word_suffix,
    max_input_chars_per_word,
    cache: {},
    cache_capacity: None,
  })
}

///|
fn build_vocab_r(vocab : Map[String, Int]) -> Array[String?] {
  let vocab_r : Array[String?] = Array::make(vocab.length(), None)
  for kv in vocab.to_array() {
    set_vocab_r(vocab_r, kv.1, kv.0)
  }
  vocab_r
}

///|
/// Clear model-level tokenization caches. This mirrors HF's cache maintenance
/// API and is a no-op for models without an internal word cache.
pub fn Model::clear_cache(self : Model) -> Unit {
  match self {
    BPE(m) => m.cache.clear()
    WordPiece(m) => m.cache.clear()
    Unigram(m) => m.cache.clear()
    WordLevel(_) => ()
  }
}

///|
/// HF Python binding alias for clearing model caches.
pub fn Model::_clear_cache(self : Model) -> Unit {
  self.clear_cache()
}

///|
/// Resize model-level tokenization caches. A capacity of `0` disables future
/// caching; negative values are clamped to zero. The previous unbounded behavior
/// is preserved until callers opt in to a bounded cache.
pub fn Model::resize_cache(self : Model, capacity : Int) -> Unit {
  let capacity = if capacity > 0 { capacity } else { 0 }
  match self {
    BPE(m) =>
      resize_token_cache(m.cache, capacity, cap => m.cache_capacity = cap)
    WordPiece(m) =>
      resize_token_cache(m.cache, capacity, cap => m.cache_capacity = cap)
    Unigram(m) =>
      resize_token_cache(m.cache, capacity, cap => m.cache_capacity = cap)
    WordLevel(_) => ()
  }
}

///|
/// HF Python binding alias for resizing model caches.
pub fn Model::_resize_cache(self : Model, capacity : Int) -> Unit {
  self.resize_cache(capacity)
}

///|
/// Return the current number of cached word tokenizations.
pub fn Model::cache_size(self : Model) -> Int {
  match self {
    BPE(m) => m.cache.length()
    WordPiece(m) => m.cache.length()
    Unigram(m) => m.cache.length()
    WordLevel(_) => 0
  }
}

///|
fn resize_token_cache(
  cache : Map[String, Array[@types.Token]],
  capacity : Int,
  set_capacity : (Int?) -> Unit,
) -> Unit {
  set_capacity(Some(capacity))
  trim_token_cache(cache, capacity)
}

///|
fn trim_token_cache(
  cache : Map[String, Array[@types.Token]],
  capacity : Int,
) -> Unit {
  if capacity <= 0 {
    cache.clear()
    return
  }
  if cache.length() <= capacity {
    return
  }
  let entries = cache.to_array()
  cache.clear()
  let keep_start = entries.length() - capacity
  for i in keep_start..<entries.length() {
    cache[entries[i].0] = entries[i].1
  }
}

///|
fn put_token_cache(
  cache : Map[String, Array[@types.Token]],
  capacity : Int?,
  word : String,
  tokens : Array[@types.Token],
) -> Unit {
  match capacity {
    Some(0) => return
    Some(n) => {
      cache[word] = tokens
      trim_token_cache(cache, n)
    }
    None => cache[word] = tokens
  }
}

///|
/// Serialize supported constructed models to a tokenizer.json `model` object.
/// Loaded HF tokenizers preserve their original JSON at the tokenizer layer;
/// this fallback is mainly for tokenizers created by the training API.
