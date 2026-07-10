// Deserialization of the `model` section of a tokenizer.json.

///|
/// Parse the `model` object into a `Model`.
pub fn Model::from_json(j : Json) -> Model raise @types.TokenizerError {
  let obj = @types.as_object(j, "model")
  // Some older tokenizer.json (e.g. gpt2) omit "type"; infer from fields.
  let ty = match obj.get("type") {
    Some(String(t)) => t
    _ =>
      if obj.contains("merges") {
        "BPE"
      } else if obj.contains("unk_id") {
        "Unigram"
      } else {
        "WordPiece"
      }
  }
  match ty {
    "BPE" => BPE(parse_bpe(obj))
    "WordPiece" => WordPiece(parse_wordpiece(obj))
    "Unigram" => Unigram(parse_unigram(obj))
    "WordLevel" => WordLevel(parse_wordlevel(obj))
    other => raise @types.UnsupportedComponent("model type: \{other}")
  }
}

// Build forward (token->id) and reverse (id->token) maps from a vocab object.

///|
fn parse_vocab(
  obj : Map[String, Json],
) -> (Map[String, Int], Array[String?]) raise @types.TokenizerError {
  let vocab : Map[String, Int] = {}
  let vobj = match obj.get("vocab") {
    Some(Object(v)) => v
    _ => raise @types.VocabError("model.vocab must be an object")
  }
  // HF vocab ids are dense in practice; pre-size the reverse table to avoid
  // repeated growth while loading 50k-150k token BPE/WordPiece vocabularies.
  let vocab_r : Array[String?] = Array::make(vobj.length(), None)
  for kv in vobj {
    let (token, idj) = kv
    match idj {
      Number(n, ..) => {
        let id = n.to_int()
        vocab[token] = id
        if id >= 0 && id < vocab_r.length() {
          vocab_r[id] = Some(token)
        } else {
          set_vocab_r(vocab_r, id, token)
        }
      }
      _ => raise @types.VocabError("vocab entry \{token} has non-numeric id")
    }
  }
  (vocab, vocab_r)
}

///|
fn set_vocab_r(vocab_r : Array[String?], id : Int, token : String) -> Unit {
  if id < 0 {
    return
  }
  while vocab_r.length() <= id {
    vocab_r.push(None)
  }
  vocab_r[id] = Some(token)
}

// Parse merges, supporting both the new [["a","b"], ...] and legacy
// ["a b", ...] formats. The value stored is the rank (array index).

///|
fn parse_merges(
  obj : Map[String, Json],
) -> Map[(String, String), Int] raise @types.TokenizerError {
  let merges : Map[(String, String), Int] = {}
  let marr = match obj.get("merges") {
    Some(Array(a)) => a
    None => raise @types.VocabError("model.merges must be an array")
    _ => raise @types.VocabError("model.merges must be an array")
  }
  for i, entry in marr {
    let pair = match entry {
      // New format: ["a", "b"]
      Array([String(a), String(b)]) => (a, b)
      // Legacy format: "a b"
      String(s) => split_legacy_merge(s)
      _ => raise @types.VocabError("bad merge entry at index \{i}")
    }
    merges[pair] = i
  }
  merges
}

// Split a legacy merge string on the first ASCII space. This path is exercised
// tens of thousands of times when loading GPT/Llama/Qwen-style tokenizer.json
// files, so use code-unit scanning plus substring instead of building both
// sides character-by-character.

///|
fn split_legacy_merge(s : String) -> (String, String) {
  let n = s.length()
  let space = ' '.to_int()
  for i in 0..<n {
    if s.unsafe_get(i).to_int() == space {
      return (
        s.unsafe_substring(start=0, end=i),
        s.unsafe_substring(start=i + 1, end=n),
      )
    }
  }
  (s, "")
}

///|
fn parse_bpe(obj : Map[String, Json]) -> BPEModel raise @types.TokenizerError {
  let (vocab, vocab_r) = parse_vocab(obj)
  let ignore_merges = @types.get_bool(obj, "ignore_merges", default=false)
  let merges = parse_merges(obj)
  let dropout = parse_bpe_dropout(obj)
  {
    vocab,
    vocab_r,
    merges,
    unk_token: @types.get_str_opt(obj, "unk_token"),
    continuing_subword_prefix: @types.get_str_opt(
      obj, "continuing_subword_prefix",
    ),
    end_of_word_suffix: @types.get_str_opt(obj, "end_of_word_suffix"),
    fuse_unk: @types.get_bool(obj, "fuse_unk", default=false),
    byte_fallback: @types.get_bool(obj, "byte_fallback", default=false),
    ignore_merges,
    dropout,
    dropout_rng_state: 1,
    cache: {},
    cache_capacity: None,
  }
}

///|
fn parse_bpe_dropout(obj : Map[String, Json]) -> Double? {
  match obj.get("dropout") {
    Some(Number(n, ..)) => if n > 0.0 { Some(n) } else { None }
    _ => None
  }
}

///|
fn get_required_string(
  obj : Map[String, Json],
  key : String,
  ctx : String,
) -> String raise @types.TokenizerError {
  match obj.get(key) {
    Some(String(s)) => s
    _ =>
      raise @types.ParseError("\{ctx}: missing or non-string \"\{key}\" field")
  }
}

///|
fn get_required_int(
  obj : Map[String, Json],
  key : String,
  ctx : String,
) -> Int raise @types.TokenizerError {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
    _ =>
      raise @types.ParseError("\{ctx}: missing or non-number \"\{key}\" field")
  }
}

///|
fn parse_wordlevel(
  obj : Map[String, Json],
) -> WordLevelModel raise @types.TokenizerError {
  let (vocab, vocab_r) = parse_vocab(obj)
  {
    vocab,
    vocab_r,
    unk_token: get_required_string(obj, "unk_token", "WordLevel model"),
  }
}

///|
fn parse_wordpiece(
  obj : Map[String, Json],
) -> WordPieceModel raise @types.TokenizerError {
  let (vocab, vocab_r) = parse_vocab(obj)
  {
    vocab,
    vocab_r,
    unk_token: get_required_string(obj, "unk_token", "WordPiece model"),
    continuing_subword_prefix: get_required_string(
      obj, "continuing_subword_prefix", "WordPiece model",
    ),
    end_of_word_suffix: @types.get_str_opt(obj, "end_of_word_suffix"),
    max_input_chars_per_word: get_required_int(
      obj, "max_input_chars_per_word", "WordPiece model",
    ),
    cache: {},
    cache_capacity: None,
  }
}

///|
fn parse_unigram(
  obj : Map[String, Json],
) -> UnigramModel raise @types.TokenizerError {
  // Unigram vocab is an array of [token, score] pairs; index is the id.
  let vocab : Map[String, (Int, Double)] = {}
  let varr = match obj.get("vocab") {
    Some(Array(a)) => a
    _ => raise @types.VocabError("unigram model.vocab must be an array")
  }
  let vocab_r : Array[String?] = Array::make(varr.length(), None)
  for i, entry in varr {
    match entry {
      Array([String(token), Number(score, ..)]) => {
        vocab[token] = (i, score)
        set_vocab_r(vocab_r, i, token)
      }
      _ => raise @types.VocabError("bad unigram vocab entry at index \{i}")
    }
  }
  {
    vocab,
    vocab_r,
    unk_id: @types.get_int_opt(obj, "unk_id"),
    byte_fallback: @types.get_bool(obj, "byte_fallback", default=false),
    fuse_unk: @types.get_bool(obj, "fuse_unk", default=true),
    cache: {},
    cache_capacity: None,
  }
}
