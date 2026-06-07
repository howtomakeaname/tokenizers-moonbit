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
  // word -> tokens with offsets relative to 0. HF tokenizers caches BPE words;
  // this keeps repeated prompts/corpora competitive while preserving offsets by
  // shifting a fresh copy per call.
  cache : Map[String, Array[@types.Token]]
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
  max_input_chars_per_word : Int
  cache : Map[String, Array[@types.Token]]
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
