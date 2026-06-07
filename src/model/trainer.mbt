// Minimal training API: deterministic WordLevel trainer.
//
// This is intentionally small but useful for inference users that need to build
// a vocabulary from local corpora without depending on HF. It mirrors the common
// WordLevelTrainer behavior: reserve special tokens first, count whitespace
// pre-tokens, then keep tokens meeting min_frequency sorted by frequency
// descending with lexical tie-breaks.

///|
pub fn Model::train_wordlevel(
  texts : Array[String],
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
) -> Model {
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(whitespace_words(text))
  }
  Model::train_wordlevel_from_tokens(
    tokenized,
    unk_token~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
  )
}

///|
/// Train a deterministic WordLevel model from pre-tokenized token streams.
/// Special tokens are assigned first, followed by `unk_token`, then corpus tokens
/// ordered by frequency descending with lexical tie-breaks.
pub fn Model::train_wordlevel_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
) -> Model {
  let counts : Map[String, Int] = {}
  let order : Array[String] = []
  for tokens in tokenized_texts {
    for tok in tokens {
      match counts.get(tok) {
        Some(n) => counts[tok] = n + 1
        None => {
          counts[tok] = 1
          order.push(tok)
        }
      }
    }
  }

  let vocab : Map[String, Int] = {}
  let vocab_r : Array[String?] = []
  fn add_token(tok : String) -> Unit {
    if vocab.contains(tok) {
      return
    }
    let id = vocab.length()
    vocab[tok] = id
    vocab_r.push(Some(tok))
  }

  for tok in special_tokens {
    add_token(tok)
  }
  add_token(unk_token)
  let candidates = sorted_wordlevel_candidates(order, counts, min_frequency)
  for item in candidates {
    if under_vocab_limit(vocab.length(), vocab_size) {
      add_token(item.0)
    }
  }
  WordLevel({ vocab, vocab_r, unk_token })
}

///|
fn sorted_wordlevel_candidates(
  order : Array[String],
  counts : Map[String, Int],
  min_frequency : Int,
) -> Array[(String, Int)] {
  let candidates : Array[(String, Int)] = []
  for tok in order {
    match counts.get(tok) {
      Some(n) => if n >= min_frequency { candidates.push((tok, n)) }
      None => ()
    }
  }
  candidates.sort_by(fn(a, b) {
    if a.1 != b.1 {
      b.1.compare(a.1)
    } else {
      a.0.compare(b.0)
    }
  })
  candidates
}

///|
fn under_vocab_limit(current_size : Int, vocab_size : Int?) -> Bool {
  match vocab_size {
    Some(limit) => limit <= 0 || current_size < limit
    None => true
  }
}

///|
fn whitespace_words(text : String) -> Array[String] {
  let chars = text.to_array()
  let out : Array[String] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    while i < n && is_train_space(chars[i]) {
      i = i + 1
    }
    let start = i
    while i < n && !is_train_space(chars[i]) {
      i = i + 1
    }
    if i > start {
      out.push(slice_train(chars, start, i))
    }
  }
  out
}

///|
fn is_train_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn slice_train(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}
