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
  // id -> token surface (for decode)
  vocab_r : Map[Int, String]
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
  vocab_r : Map[Int, String]
  unk_token : String
}

///|
/// WordPiece model state.
pub struct WordPieceModel {
  vocab : Map[String, Int]
  vocab_r : Map[Int, String]
  unk_token : String
  continuing_subword_prefix : String
  max_input_chars_per_word : Int
}

///|
/// Unigram model state.
pub struct UnigramModel {
  // token surface -> (id, log-probability score)
  vocab : Map[String, (Int, Double)]
  // id -> token surface
  vocab_r : Map[Int, String]
  unk_id : Int?
  byte_fallback : Bool
  fuse_unk : Bool
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
    BPE(m) => m.vocab_r.get(id)
    WordPiece(m) => m.vocab_r.get(id)
    Unigram(m) => m.vocab_r.get(id)
    WordLevel(m) => m.vocab_r.get(id)
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
