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
pub fn Model::continuing_subword_prefix(self : Model) -> String? {
  match self {
    BPE(m) => m.continuing_subword_prefix
    WordPiece(m) => Some(m.continuing_subword_prefix)
    _ => None
  }
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
pub fn Model::max_input_chars_per_word(self : Model) -> Int? {
  match self {
    WordPiece(m) => Some(m.max_input_chars_per_word)
    _ => None
  }
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
pub fn Model::fuse_unk(self : Model) -> Bool? {
  match self {
    BPE(m) => Some(m.fuse_unk)
    Unigram(m) => Some(m.fuse_unk)
    _ => None
  }
}

///|
pub fn Model::ignore_merges(self : Model) -> Bool? {
  match self {
    BPE(m) => Some(m.ignore_merges)
    _ => None
  }
}

///|
pub fn Model::dropout(self : Model) -> Double? {
  match self {
    BPE(m) => m.dropout
    _ => None
  }
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
pub fn Model::to_json(self : Model) -> String? {
  match self {
    BPE(m) => Some(bpe_to_json(m))
    WordLevel(m) => Some(wordlevel_to_json(m))
    WordPiece(m) => Some(wordpiece_to_json(m))
    Unigram(m) => Some(unigram_to_json(m))
  }
}

///|
/// Save model-level HuggingFace artifacts into `folder`, mirroring
/// `tokenizers.models.*.save(folder, prefix=None)`. The directory is created
/// when possible and the concrete artifact paths are returned in write order.
///
/// - BPE: `<prefix>-vocab.json` + `<prefix>-merges.txt`
/// - WordPiece: `<prefix>-vocab.txt`
/// - WordLevel: `<prefix>-vocab.json`
/// - Unigram: `<prefix>-unigram.json` (score-preserving tokenizer JSON fragment)
pub fn Model::save(
  self : Model,
  folder : String,
  prefix? : String = "",
) -> Array[String] raise @types.TokenizerError {
  ensure_dir(folder)
  let p = artifact_prefix(prefix)
  match self {
    BPE(m) => save_bpe_artifacts(m, folder, p)
    WordPiece(m) => save_wordpiece_artifacts(m, folder, p)
    WordLevel(m) => save_wordlevel_artifact(m, folder, p)
    Unigram(m) => save_unigram_artifact(m, folder, p)
  }
}

///|
fn save_bpe_artifacts(
  m : BPEModel,
  folder : String,
  prefix : String,
) -> Array[String] raise @types.TokenizerError {
  let vocab_path = join_path(folder, prefix + "vocab.json")
  let merges_path = join_path(folder, prefix + "merges.txt")
  let sb = StringBuilder::new()
  sb.write_char('{')
  write_vocab_json(sb, m.vocab_r)
  sb.write_char('}')
  write_artifact(vocab_path, sb.to_string())
  write_artifact(merges_path, bpe_merges_txt(m.merges))
  [vocab_path, merges_path]
}

///|
fn save_wordpiece_artifacts(
  m : WordPieceModel,
  folder : String,
  prefix : String,
) -> Array[String] raise @types.TokenizerError {
  let path = join_path(folder, prefix + "vocab.txt")
  write_artifact(path, vocab_txt(m.vocab_r))
  [path]
}

///|
fn save_wordlevel_artifact(
  m : WordLevelModel,
  folder : String,
  prefix : String,
) -> Array[String] raise @types.TokenizerError {
  let path = join_path(folder, prefix + "vocab.json")
  let sb = StringBuilder::new()
  sb.write_char('{')
  write_vocab_json(sb, m.vocab_r)
  sb.write_char('}')
  write_artifact(path, sb.to_string())
  [path]
}

///|
fn save_unigram_artifact(
  m : UnigramModel,
  folder : String,
  prefix : String,
) -> Array[String] raise @types.TokenizerError {
  let path = join_path(folder, prefix + "unigram.json")
  write_artifact(path, unigram_to_json(m))
  [path]
}

///|
fn bpe_merges_txt(merges : Map[(String, String), Int]) -> String {
  let ordered : Array[(String, String)?] = Array::make(merges.length(), None)
  for kv in merges {
    let (pair, rank) = kv
    if rank >= 0 && rank < ordered.length() {
      ordered[rank] = Some(pair)
    }
  }
  let sb = StringBuilder::new()
  sb.write_string("#version: 0.2\n")
  for item in ordered {
    match item {
      Some(pair) => {
        sb.write_string(pair.0)
        sb.write_char(' ')
        sb.write_string(pair.1)
        sb.write_char('\n')
      }
      None => ()
    }
  }
  sb.to_string()
}

///|
fn vocab_txt(vocab_r : Array[String?]) -> String {
  let sb = StringBuilder::new()
  for tok in vocab_r {
    match tok {
      Some(t) => {
        sb.write_string(t)
        sb.write_char('\n')
      }
      None => sb.write_char('\n')
    }
  }
  sb.to_string()
}

///|
fn write_artifact(
  path : String,
  content : String,
) -> Unit raise @types.TokenizerError {
  @fs.write_string_to_file(path, content) catch {
    _ => raise @types.ParseError("cannot write model artifact: \{path}")
  }
}

///|
fn ensure_dir(path : String) -> Unit raise @types.TokenizerError {
  if path.is_empty() || @fs.path_exists(path) {
    return
  }
  ensure_parent_dir(path)
  @fs.create_dir(path) catch {
    _ =>
      if !@fs.path_exists(path) {
        raise @types.ParseError("cannot create directory: \{path}")
      }
  }
}

///|
fn ensure_parent_dir(path : String) -> Unit raise @types.TokenizerError {
  match parent_dir(path) {
    Some(parent) => ensure_dir(parent)
    None => ()
  }
}

///|
fn parent_dir(path : String) -> String? {
  let chars = path.to_array()
  let mut i = chars.length() - 1
  while i >= 0 {
    if chars[i] == '/' {
      if i == 0 {
        return Some("/")
      }
      let sb = StringBuilder::new()
      for j in 0..<i {
        sb.write_char(chars[j])
      }
      let p = sb.to_string()
      return if p.is_empty() { None } else { Some(p) }
    }
    i = i - 1
  }
  None
}

///|
fn join_path(folder : String, name : String) -> String {
  if folder.has_suffix("/") {
    folder + name
  } else {
    folder + "/" + name
  }
}

///|
fn artifact_prefix(prefix : String) -> String {
  if prefix.is_empty() {
    ""
  } else {
    prefix + "-"
  }
}

///|
fn bpe_to_json(m : BPEModel) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"BPE\",\"vocab\":{")
  write_vocab_json(sb, m.vocab_r)
  sb.write_string("},\"merges\":")
  write_merges_json(sb, m.merges)
  match m.unk_token {
    Some(unk) => {
      sb.write_string(",\"unk_token\":")
      write_json_string(sb, unk)
    }
    None => ()
  }
  match m.continuing_subword_prefix {
    Some(p) => {
      sb.write_string(",\"continuing_subword_prefix\":")
      write_json_string(sb, p)
    }
    None => ()
  }
  match m.end_of_word_suffix {
    Some(suf) => {
      sb.write_string(",\"end_of_word_suffix\":")
      write_json_string(sb, suf)
    }
    None => ()
  }
  if m.fuse_unk {
    sb.write_string(",\"fuse_unk\":true")
  }
  if m.byte_fallback {
    sb.write_string(",\"byte_fallback\":true")
  }
  if m.ignore_merges {
    sb.write_string(",\"ignore_merges\":true")
  }
  match m.dropout {
    Some(p) =>
      if p > 0.0 {
        sb.write_string(",\"dropout\":")
        sb.write_string(p.to_string())
      }
    None => ()
  }
  sb.write_char('}')
  sb.to_string()
}

///|
fn wordlevel_to_json(m : WordLevelModel) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"WordLevel\",\"vocab\":{")
  write_vocab_json(sb, m.vocab_r)
  sb.write_string("},\"unk_token\":")
  write_json_string(sb, m.unk_token)
  sb.write_char('}')
  sb.to_string()
}

///|
fn wordpiece_to_json(m : WordPieceModel) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"WordPiece\",\"unk_token\":")
  write_json_string(sb, m.unk_token)
  sb.write_string(",\"continuing_subword_prefix\":")
  write_json_string(sb, m.continuing_subword_prefix)
  match m.end_of_word_suffix {
    Some(suf) => {
      sb.write_string(",\"end_of_word_suffix\":")
      write_json_string(sb, suf)
    }
    None => ()
  }
  sb.write_string(",\"max_input_chars_per_word\":")
  sb.write_string(m.max_input_chars_per_word.to_string())
  sb.write_string(",\"vocab\":{")
  write_vocab_json(sb, m.vocab_r)
  sb.write_string("}}")
  sb.to_string()
}

///|
fn unigram_to_json(m : UnigramModel) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Unigram\",\"vocab\":")
  write_unigram_vocab_json(sb, m)
  match m.unk_id {
    Some(id) => {
      sb.write_string(",\"unk_id\":")
      sb.write_string(id.to_string())
    }
    None => ()
  }
  if m.byte_fallback {
    sb.write_string(",\"byte_fallback\":true")
  }
  if !m.fuse_unk {
    sb.write_string(",\"fuse_unk\":false")
  }
  sb.write_char('}')
  sb.to_string()
}

///|
fn write_unigram_vocab_json(sb : StringBuilder, m : UnigramModel) -> Unit {
  sb.write_char('[')
  let mut first = true
  for id in 0..<m.vocab_r.length() {
    match m.vocab_r[id] {
      Some(tok) => {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_char('[')
        write_json_string(sb, tok)
        sb.write_char(',')
        let score = match m.vocab.get(tok) {
          Some(p) => p.1
          None => 0.0
        }
        write_unigram_score(sb, score)
        sb.write_char(']')
      }
      None => ()
    }
  }
  sb.write_char(']')
}

///|
fn write_unigram_score(sb : StringBuilder, score : Double) -> Unit {
  // Trained MVP scores are intentionally simple; avoid Double::to_string on the
  // hot serialization path for the common values created by the trainer.
  if score == 0.0 {
    sb.write_char('0')
  } else if score == -10.0 {
    sb.write_string("-10")
  } else if score == 1.0 {
    sb.write_char('1')
  } else if score == 2.0 {
    sb.write_char('2')
  } else if score == 3.0 {
    sb.write_char('3')
  } else if score == 4.0 {
    sb.write_char('4')
  } else if score == 5.0 {
    sb.write_char('5')
  } else if score == 6.0 {
    sb.write_char('6')
  } else if score == 7.0 {
    sb.write_char('7')
  } else if score == 8.0 {
    sb.write_char('8')
  } else if score == 9.0 {
    sb.write_char('9')
  } else {
    sb.write_string(score.to_string())
  }
}

///|
fn write_vocab_json(sb : StringBuilder, vocab_r : Array[String?]) -> Unit {
  let mut first = true
  for id in 0..<vocab_r.length() {
    match vocab_r[id] {
      Some(tok) => {
        if !first {
          sb.write_char(',')
        }
        first = false
        write_json_string(sb, tok)
        sb.write_char(':')
        sb.write_string(id.to_string())
      }
      None => ()
    }
  }
}

///|
fn write_merges_json(
  sb : StringBuilder,
  merges : Map[(String, String), Int],
) -> Unit {
  let ordered : Array[(String, String)?] = Array::make(merges.length(), None)
  for kv in merges {
    let (pair, rank) = kv
    if rank >= 0 && rank < ordered.length() {
      ordered[rank] = Some(pair)
    }
  }
  sb.write_char('[')
  let mut first = true
  for item in ordered {
    match item {
      Some(pair) => {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_char('[')
        write_json_string(sb, pair.0)
        sb.write_char(',')
        write_json_string(sb, pair.1)
        sb.write_char(']')
      }
      None => ()
    }
  }
  sb.write_char(']')
}

///|
fn write_json_string(sb : StringBuilder, s : String) -> Unit {
  sb.write_char('"')
  for c in s {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ =>
        if c.to_int() < 0x20 {
          write_control_escape(sb, c.to_int())
        } else {
          sb.write_char(c)
        }
    }
  }
  sb.write_char('"')
}

///|
fn write_control_escape(sb : StringBuilder, u : Int) -> Unit {
  let digits = "0123456789ABCDEF".to_array()
  sb.write_string("\\u00")
  sb.write_char(digits[u / 16 % 16])
  sb.write_char(digits[u % 16])
}

///|
/// Tokenize one pre-token (word) into tokens. `offset` is the char offset of
/// the word within the original text.
pub fn Model::tokenize(
  self : Model,
  word : String,
  offset? : Int = 0,
) -> Array[@types.Token] {
  match self {
    BPE(m) => m.tokenize(word, offset~)
    WordPiece(m) => m.tokenize(word, offset~)
    Unigram(m) => m.tokenize(word, offset~)
    WordLevel(m) => m.tokenize(word, offset~)
  }
}
