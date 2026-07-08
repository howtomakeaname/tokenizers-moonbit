// Standalone HuggingFace model artifact loaders.

///|
pub fn Model::from_bpe_files(
  vocab_path : String,
  merges_path : String,
  unk_token? : String? = Some("[UNK]"),
  continuing_subword_prefix? : String? = None,
  end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false,
  byte_fallback? : Bool = false,
  ignore_merges? : Bool = false,
  dropout? : Double? = None,
) -> Model raise @types.TokenizerError {
  let obj : Map[String, Json] = {
    "vocab": read_vocab_json(vocab_path, "BPE vocab"),
  }
  let (vocab, vocab_r) = parse_vocab(obj)
  BPE(BPEModel::{
    vocab,
    vocab_r,
    merges: read_bpe_merges_file(merges_path),
    unk_token,
    continuing_subword_prefix,
    end_of_word_suffix,
    fuse_unk,
    byte_fallback,
    ignore_merges,
    dropout,
    dropout_rng_state: 1,
    cache: {},
    cache_capacity: None,
  })
}

///|
pub fn Model::from_wordpiece_file(
  vocab_path : String,
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None,
  max_input_chars_per_word? : Int = 100,
) -> Model raise @types.TokenizerError {
  let (vocab, vocab_r) = read_vocab_txt(vocab_path)
  WordPiece(WordPieceModel::{
    vocab,
    vocab_r,
    unk_token,
    continuing_subword_prefix,
    end_of_word_suffix,
    max_input_chars_per_word,
    cache: {},
    cache_capacity: None,
  })
}

///|
pub fn Model::from_wordlevel_file(
  vocab_path : String,
  unk_token? : String = "[UNK]",
) -> Model raise @types.TokenizerError {
  let obj : Map[String, Json] = {
    "vocab": read_vocab_json(vocab_path, "WordLevel vocab"),
  }
  let (vocab, vocab_r) = parse_vocab(obj)
  WordLevel(WordLevelModel::{ vocab, vocab_r, unk_token })
}

///|
fn read_vocab_json(
  path : String,
  label : String,
) -> Json raise @types.TokenizerError {
  let content = read_model_artifact(path)
  let parsed = @json.parse(content) catch {
    err => raise @types.ParseError("invalid \{label} JSON: \{err}")
  }
  match parsed {
    Object(_) => parsed
    _ => raise @types.VocabError("\{label} must be a JSON object")
  }
}

///|
fn read_bpe_merges_file(
  path : String,
) -> Map[(String, String), Int] raise @types.TokenizerError {
  let merges : Map[(String, String), Int] = {}
  let mut rank = 0
  for line in split_artifact_lines(read_model_artifact(path)) {
    let line = strip_trailing_cr(line)
    if line.is_empty() || line.has_prefix("#version:") {
      continue
    }
    merges[split_legacy_merge(line)] = rank
    rank = rank + 1
  }
  merges
}

///|
fn read_vocab_txt(
  path : String,
) -> (Map[String, Int], Array[String?]) raise @types.TokenizerError {
  let vocab : Map[String, Int] = {}
  let vocab_r : Array[String?] = []
  let mut id = 0
  for line in split_artifact_lines(read_model_artifact(path)) {
    let token = strip_trailing_cr(line)
    vocab[token] = id
    set_vocab_r(vocab_r, id, token)
    id = id + 1
  }
  (vocab, vocab_r)
}

///|
fn read_model_artifact(path : String) -> String raise @types.TokenizerError {
  @fs.read_file_to_string(path) catch {
    _ => raise @types.ParseError("cannot read model artifact: \{path}")
  }
}

///|
fn split_artifact_lines(content : String) -> Array[String] {
  let out : Array[String] = []
  let chars = content.to_array()
  let mut sb = StringBuilder::new()
  for c in chars {
    if c == '\n' {
      out.push(sb.to_string())
      sb = StringBuilder::new()
    } else {
      sb.write_char(c)
    }
  }
  let tail = sb.to_string()
  if !tail.is_empty() || chars.length() == 0 {
    out.push(tail)
  }
  out
}

///|
fn strip_trailing_cr(s : String) -> String {
  let chars = s.to_array()
  if chars.length() > 0 && chars[chars.length() - 1] == '\r' {
    make_sub(chars, 0, chars.length() - 1)
  } else {
    s
  }
}
