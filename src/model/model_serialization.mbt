///|
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
  match m.alpha {
    Some(a) => {
      sb.write_string(",\"alpha\":")
      write_unigram_score(sb, a)
    }
    None => ()
  }
  match m.nbest_size {
    Some(n) => {
      sb.write_string(",\"nbest_size\":")
      sb.write_string(n.to_string())
    }
    None => ()
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
) -> Array[@types.Token] raise @types.TokenizerError {
  match self {
    BPE(m) => m.tokenize(word, offset~)
    WordPiece(m) => m.tokenize(word, offset~)
    Unigram(m) => m.tokenize(word, offset~)
    WordLevel(m) => m.tokenize(word, offset~)
  }
}
