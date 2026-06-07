// Minimal training API: deterministic WordLevel trainer.
//
// This is intentionally small but useful for inference users that need to build
// a vocabulary from local corpora without depending on HF. It mirrors the common
// WordLevelTrainer behavior: reserve special tokens first, count whitespace
// pre-tokens, then keep tokens meeting min_frequency in first-seen order.

///|
pub fn Model::train_wordlevel(
  texts : Array[String],
  unk_token? : String = "[UNK]",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
) -> Model {
  let counts : Map[String, Int] = {}
  let order : Array[String] = []
  for text in texts {
    for word in whitespace_words(text) {
      match counts.get(word) {
        Some(n) => counts[word] = n + 1
        None => {
          counts[word] = 1
          order.push(word)
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
  for tok in order {
    match counts.get(tok) {
      Some(n) => if n >= min_frequency { add_token(tok) }
      None => ()
    }
  }
  WordLevel({ vocab, vocab_r, unk_token })
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
