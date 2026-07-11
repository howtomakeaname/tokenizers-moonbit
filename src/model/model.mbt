// The `model` stage of the tokenizer pipeline.
//
// A Model maps a pre-tokenized word (a String) to a list of tokens with ids.
// HuggingFace supports BPE, WordPiece and Unigram; we represent all three with
// one enum so the JSON "type" tag maps directly to a variant.
//
// P1 scope: data structures + deserialization from tokenizer.json.
// tokenize/decode for each variant lands in P2 / P5 / P6.

///|
/// BPE model state.
pub struct BPEModel {
  // token surface -> id
  vocab : Map[String, Int]
  // id -> token surface (for decode). Dense array is cheaper to build and
  // faster to query than an Int-keyed map for HF vocabularies.
  vocab_r : Array[String?]
  // merge pair (left, right) -> rank (lower = applied earlier)
  merges : Map[(String, String), Int]
  unk_token : String?
  continuing_subword_prefix : String?
  end_of_word_suffix : String?
  fuse_unk : Bool
  byte_fallback : Bool
  ignore_merges : Bool
  // HF BPE dropout: probability of skipping an available merge during encode.
  // None / <=0 keeps the deterministic no-dropout fast path.
  dropout : Double?
  // Small deterministic PRNG state used only when dropout is enabled. This keeps
  // core tokenization self-contained across MoonBit targets without importing a
  // platform-specific random source.
  mut dropout_rng_state : Int
  // word -> tokens with offsets relative to 0. HF tokenizers caches BPE words;
  // this keeps repeated prompts/corpora competitive while preserving offsets by
  // shifting a fresh copy per call.
  cache : Map[String, Array[@types.Token]]
  // None keeps the historical unbounded cache; Some(0) disables caching.
  mut cache_capacity : Int?
  // Number of unique words seen during BPE training (HF BpeTrainer.get_word_count).
  // None for models loaded from files or constructed directly.
  word_count : Int?
}

///|
/// WordLevel model state: a flat token->id map with an unk fallback.
pub struct WordLevelModel {
  vocab : Map[String, Int]
  vocab_r : Array[String?]
  unk_token : String
}

///|
/// WordPiece model state.
pub struct WordPieceModel {
  vocab : Map[String, Int]
  vocab_r : Array[String?]
  unk_token : String
  continuing_subword_prefix : String
  end_of_word_suffix : String?
  max_input_chars_per_word : Int
  cache : Map[String, Array[@types.Token]]
  mut cache_capacity : Int?
}

///|
/// Unigram model state.
pub struct UnigramModel {
  // token surface -> (id, log-probability score)
  vocab : Map[String, (Int, Double)]
  // id -> token surface
  vocab_r : Array[String?]
  unk_id : Int?
  byte_fallback : Bool
  fuse_unk : Bool
  // Sampling temperature: when set (> 0), use sampling instead of Viterbi.
  // None or 0.0 means deterministic Viterbi (default HF behavior).
  alpha : Double?
  // N-best paths for sampling: when set (> 0) with alpha, sample from top-N paths.
  // None or 0 means sample from full lattice when alpha is set.
  nbest_size : Int?
  cache : Map[String, Array[@types.Token]]
  mut cache_capacity : Int?
}

///|
/// The model variants.
pub enum Model {
  BPE(BPEModel)
  WordPiece(WordPieceModel)
  Unigram(UnigramModel)
  WordLevel(WordLevelModel)
}

///|
/// JSON-backed model state used by thin binding layers.
pub struct ModelState {
  json : String
} derive(Debug, Eq)

///|
pub fn ModelState::new(json : String) -> ModelState {
  { json, }
}

///|
/// Return the model family name used by thin binding layers.
pub fn Model::kind(self : Model) -> String {
  match self {
    BPE(_) => "BPE"
    WordPiece(_) => "WordPiece"
    Unigram(_) => "Unigram"
    WordLevel(_) => "WordLevel"
  }
}

///|
pub fn Model::get_state(self : Model) -> ModelState raise @types.TokenizerError {
  { json: self.state_json() }
}

///|
pub fn Model::from_state(
  state : ModelState,
) -> Model raise @types.TokenizerError {
  let parsed = @json.parse(state.json) catch {
    err => raise @types.ParseError("invalid model state: \{err}")
  }
  Model::from_json(parsed)
}

///|
pub fn Model::__getstate__(
  self : Model,
) -> ModelState raise @types.TokenizerError {
  self.get_state()
}

///|
pub fn Model::__setstate__(
  state : ModelState,
) -> Model raise @types.TokenizerError {
  Model::from_state(state)
}

///|
pub fn Model::__str__(self : Model) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
pub fn Model::__repr__(self : Model) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
fn Model::state_json(self : Model) -> String raise @types.TokenizerError {
  match self.to_json() {
    Some(json) => json
    None => raise @types.UnsupportedComponent("model has no serialized state")
  }
}

///|
pub fn Model::unk_token(self : Model) -> String? {
  match self {
    BPE(m) => m.unk_token
    WordPiece(m) => Some(m.unk_token)
    WordLevel(m) => Some(m.unk_token)
    Unigram(m) =>
      match m.unk_id {
        Some(id) => lookup_id(m.vocab_r, id)
        None => None
      }
  }
}

///|
pub fn Model::get_unk_token(self : Model) -> String? {
  self.unk_token()
}

///|
pub fn Model::unk_id(self : Model) -> Int? {
  match self {
    Unigram(m) => m.unk_id
    _ =>
      match self.unk_token() {
        Some(token) => self.token_to_id(token)
        None => None
      }
  }
}

///|
pub fn Model::get_unk_id(self : Model) -> Int? {
  self.unk_id()
}

///|
pub fn Model::continuing_subword_prefix(self : Model) -> String? {
  match self {
    BPE(m) => m.continuing_subword_prefix
    WordPiece(m) => Some(m.continuing_subword_prefix)
    _ => None
  }
}

///|
pub fn Model::get_continuing_subword_prefix(self : Model) -> String? {
  self.continuing_subword_prefix()
}

///|
pub fn Model::end_of_word_suffix(self : Model) -> String? {
  match self {
    BPE(m) => m.end_of_word_suffix
    WordPiece(m) => m.end_of_word_suffix
    _ => None
  }
}

///|
pub fn Model::get_end_of_word_suffix(self : Model) -> String? {
  self.end_of_word_suffix()
}

///|
pub fn Model::max_input_chars_per_word(self : Model) -> Int? {
  match self {
    WordPiece(m) => Some(m.max_input_chars_per_word)
    _ => None
  }
}

///|
pub fn Model::get_max_input_chars_per_word(self : Model) -> Int? {
  self.max_input_chars_per_word()
}

///|
pub fn Model::byte_fallback(self : Model) -> Bool? {
  match self {
    BPE(m) => Some(m.byte_fallback)
    Unigram(m) => Some(m.byte_fallback)
    _ => None
  }
}

///|
pub fn Model::get_byte_fallback(self : Model) -> Bool? {
  self.byte_fallback()
}

///|
pub fn Model::fuse_unk(self : Model) -> Bool? {
  match self {
    BPE(m) => Some(m.fuse_unk)
    Unigram(m) => Some(m.fuse_unk)
    _ => None
  }
}

///|
pub fn Model::get_fuse_unk(self : Model) -> Bool? {
  self.fuse_unk()
}

///|
pub fn Model::ignore_merges(self : Model) -> Bool? {
  match self {
    BPE(m) => Some(m.ignore_merges)
    _ => None
  }
}

///|
pub fn Model::get_ignore_merges(self : Model) -> Bool? {
  self.ignore_merges()
}

///|
pub fn Model::dropout(self : Model) -> Double? {
  match self {
    BPE(m) => m.dropout
    _ => None
  }
}

///|
pub fn Model::get_dropout(self : Model) -> Double? {
  self.dropout()
}

///|
/// Unigram sampling temperature. None or 0.0 means deterministic Viterbi.
pub fn Model::alpha(self : Model) -> Double? {
  match self {
    Unigram(m) => m.alpha
    _ => None
  }
}

///|
pub fn Model::get_alpha(self : Model) -> Double? {
  self.alpha()
}

///|
/// Unigram N-best size for sampling. None or 0 means sample from full lattice.
pub fn Model::nbest_size(self : Model) -> Int? {
  match self {
    Unigram(m) => m.nbest_size
    _ => None
  }
}

///|
pub fn Model::get_nbest_size(self : Model) -> Int? {
  self.nbest_size()
}

///|
/// Return the number of unique words seen during BPE training (HF
/// `BpeTrainer.get_word_count`). Returns `None` for non-BPE models or models
/// loaded from files.
pub fn Model::get_word_count(self : Model) -> Int? {
  match self {
    BPE(m) => m.word_count
    _ => None
  }
}

///|

///|
/// Set the unk_token for models that support it (BPE, WordPiece, WordLevel).
/// Returns a new Model; Unigram models are unchanged (they use unk_id).
pub fn Model::set_unk_token(self : Model, token : String) -> Model {
  match self {
    BPE(m) => BPE({ ..m, unk_token: Some(token) })
    WordPiece(m) => WordPiece({ ..m, unk_token: token })
    WordLevel(m) => WordLevel({ ..m, unk_token: token })
    Unigram(m) => Unigram(m)
  }
}

///|
/// Python/property-style setter alias for unk_token.
pub fn Model::set_unk_token_alias(self : Model, token : String) -> Model {
  self.set_unk_token(token)
}

///|
/// Set the BPE dropout probability. Returns a new Model; non-BPE models unchanged.
pub fn Model::set_dropout(self : Model, dropout : Double?) -> Model {
  match self {
    BPE(m) => BPE({ ..m, dropout, })
    _ => self
  }
}

///|
/// Python/property-style setter alias for dropout.
pub fn Model::set_dropout_alias(self : Model, dropout : Double?) -> Model {
  self.set_dropout(dropout)
}

///|
/// Set the continuing_subword_prefix. Returns a new Model; only BPE/WordPiece support it.
pub fn Model::set_continuing_subword_prefix(
  self : Model,
  prefix : String?,
) -> Model {
  match self {
    BPE(m) => BPE({ ..m, continuing_subword_prefix: prefix })
    WordPiece(m) =>
      WordPiece({
        ..m,
        continuing_subword_prefix: prefix.unwrap_or(m.continuing_subword_prefix),
      })
    _ => self
  }
}

///|
/// Python/property-style setter alias for continuing_subword_prefix.
pub fn Model::set_continuing_subword_prefix_alias(
  self : Model,
  prefix : String?,
) -> Model {
  self.set_continuing_subword_prefix(prefix)
}

///|
/// Set the end_of_word_suffix. Returns a new Model; only BPE/WordPiece support it.
pub fn Model::set_end_of_word_suffix(self : Model, suffix : String?) -> Model {
  match self {
    BPE(m) => BPE({ ..m, end_of_word_suffix: suffix })
    WordPiece(m) => WordPiece({ ..m, end_of_word_suffix: suffix })
    _ => self
  }
}

///|
/// Python/property-style setter alias for end_of_word_suffix.
pub fn Model::set_end_of_word_suffix_alias(
  self : Model,
  suffix : String?,
) -> Model {
  self.set_end_of_word_suffix(suffix)
}

///|
/// Set byte_fallback. Returns a new Model; only BPE/Unigram support it.
pub fn Model::set_byte_fallback(self : Model, val : Bool) -> Model {
  match self {
    BPE(m) => BPE({ ..m, byte_fallback: val })
    Unigram(m) => Unigram({ ..m, byte_fallback: val })
    _ => self
  }
}

///|
/// Python/property-style setter alias for byte_fallback.
pub fn Model::set_byte_fallback_alias(self : Model, val : Bool) -> Model {
  self.set_byte_fallback(val)
}

///|
/// Set fuse_unk. Returns a new Model; only BPE/Unigram support it.
pub fn Model::set_fuse_unk(self : Model, val : Bool) -> Model {
  match self {
    BPE(m) => BPE({ ..m, fuse_unk: val })
    Unigram(m) => Unigram({ ..m, fuse_unk: val })
    _ => self
  }
}

///|
/// Python/property-style setter alias for fuse_unk.
pub fn Model::set_fuse_unk_alias(self : Model, val : Bool) -> Model {
  self.set_fuse_unk(val)
}

///|
/// Set ignore_merges. Returns a new Model; only BPE supports it.
pub fn Model::set_ignore_merges(self : Model, val : Bool) -> Model {
  match self {
    BPE(m) => BPE({ ..m, ignore_merges: val })
    _ => self
  }
}

///|
/// Python/property-style setter alias for ignore_merges.
pub fn Model::set_ignore_merges_alias(self : Model, val : Bool) -> Model {
  self.set_ignore_merges(val)
}

///|
/// Set max_input_chars_per_word. Returns a new Model; only WordPiece supports it.
pub fn Model::set_max_input_chars_per_word(self : Model, val : Int) -> Model {
  match self {
    WordPiece(m) => WordPiece({ ..m, max_input_chars_per_word: val })
    _ => self
  }
}

///|
/// Python/property-style setter alias for max_input_chars_per_word.
pub fn Model::set_max_input_chars_per_word_alias(
  self : Model,
  val : Int,
) -> Model {
  self.set_max_input_chars_per_word(val)
}

///|
/// Set alpha (sampling temperature) for Unigram models. Returns a new Model; non-Unigram unchanged.
pub fn Model::set_alpha(self : Model, alpha : Double?) -> Model {
  match self {
    Unigram(m) => Unigram({ ..m, alpha, })
    _ => self
  }
}

///|
/// Python/property-style setter alias for alpha.
pub fn Model::set_alpha_alias(self : Model, alpha : Double?) -> Model {
  self.set_alpha(alpha)
}

///|
/// Set nbest_size for Unigram models. Returns a new Model; non-Unigram unchanged.
pub fn Model::set_nbest_size(self : Model, nbest_size : Int?) -> Model {
  match self {
    Unigram(m) => Unigram({ ..m, nbest_size, })
    _ => self
  }
}

///|
/// Python/property-style setter alias for nbest_size.
pub fn Model::set_nbest_size_alias(self : Model, nbest_size : Int?) -> Model {
  self.set_nbest_size(nbest_size)
}

///|
/// Look up a token surface by id (decode direction).
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
