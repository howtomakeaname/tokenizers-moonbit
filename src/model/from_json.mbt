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
) -> (Map[String, Int], Map[Int, String]) raise @types.TokenizerError {
  let vocab : Map[String, Int] = {}
  let vocab_r : Map[Int, String] = {}
  let vobj = match obj.get("vocab") {
    Some(Object(v)) => v
    _ => raise @types.VocabError("model.vocab must be an object")
  }
  for kv in vobj {
    let (token, idj) = kv
    match idj {
      Number(n, ..) => {
        let id = n.to_int()
        vocab[token] = id
        vocab_r[id] = token
      }
      _ => raise @types.VocabError("vocab entry \{token} has non-numeric id")
    }
  }
  (vocab, vocab_r)
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
    None => []
    _ => raise @types.VocabError("model.merges must be an array")
  }
  for i, entry in marr {
    let pair = match entry {
      // New format: ["a", "b"]
      Array([String(a), String(b)]) => (a, b)
      // Legacy format: "a b"
      String(s) => split_once(s, ' ')
      _ => raise @types.VocabError("bad merge entry at index \{i}")
    }
    merges[pair] = i
  }
  merges
}

// Split a string on the first occurrence of `sep`; the remainder (which may
// itself contain `sep`) becomes the right half.

///|
fn split_once(s : String, sep : Char) -> (String, String) {
  let left = StringBuilder::new()
  let right = StringBuilder::new()
  let mut seen = false
  for c in s {
    if !seen && c == sep {
      seen = true
    } else if seen {
      right.write_char(c)
    } else {
      left.write_char(c)
    }
  }
  (left.to_string(), right.to_string())
}

///|
fn parse_bpe(obj : Map[String, Json]) -> BPEModel raise @types.TokenizerError {
  let (vocab, vocab_r) = parse_vocab(obj)
  let merges = parse_merges(obj)
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
    ignore_merges: @types.get_bool(obj, "ignore_merges", default=false),
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
    unk_token: @types.get_str(obj, "unk_token", default="<unk>"),
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
    unk_token: @types.get_str(obj, "unk_token", default="[UNK]"),
    continuing_subword_prefix: @types.get_str(
      obj,
      "continuing_subword_prefix",
      default="##",
    ),
    max_input_chars_per_word: @types.get_int(
      obj,
      "max_input_chars_per_word",
      default=100,
    ),
  }
}

///|
fn parse_unigram(
  obj : Map[String, Json],
) -> UnigramModel raise @types.TokenizerError {
  // Unigram vocab is an array of [token, score] pairs; index is the id.
  let vocab : Map[String, (Int, Double)] = {}
  let vocab_r : Map[Int, String] = {}
  let varr = match obj.get("vocab") {
    Some(Array(a)) => a
    _ => raise @types.VocabError("unigram model.vocab must be an array")
  }
  for i, entry in varr {
    match entry {
      Array([String(token), Number(score, ..)]) => {
        vocab[token] = (i, score)
        vocab_r[i] = token
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
  }
}
