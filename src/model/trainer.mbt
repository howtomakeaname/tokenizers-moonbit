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
/// Train a deterministic WordPiece model from whitespace-delimited text.
///
/// This MVP keeps the HF-compatible WordPiece model shape and common trainer
/// knobs (`special_tokens`, `min_frequency`, `vocab_size`, continuation
/// prefix). It reserves specials/unk first, then the per-character alphabet,
/// then high-frequency whole words so seen corpus words encode compactly while
/// unseen words can still fall back to character pieces when the alphabet fits.
pub fn Model::train_wordpiece(
  texts : Array[String],
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
) -> Model {
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(whitespace_words(text))
  }
  Model::train_wordpiece_from_tokens(
    tokenized,
    unk_token~,
    continuing_subword_prefix~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
    max_input_chars_per_word~,
  )
}

///|
/// Train a deterministic WordPiece model from pre-tokenized token streams.
pub fn Model::train_wordpiece_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
) -> Model {
  let word_counts : Map[String, Int] = {}
  let word_order : Array[String] = []
  let piece_counts : Map[String, Int] = {}
  let piece_order : Array[String] = []
  for tokens in tokenized_texts {
    for tok in tokens {
      bump_count(word_counts, word_order, tok)
      add_wordpiece_alphabet(
        tok, continuing_subword_prefix, piece_counts, piece_order,
      )
    }
  }

  let vocab : Map[String, Int] = {}
  let vocab_r : Array[String?] = []
  fn add_token(tok : String) -> Unit {
    if vocab.contains(tok) || !under_vocab_limit(vocab.length(), vocab_size) {
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

  let alphabet = sorted_wordlevel_candidates(piece_order, piece_counts, 1)
  for item in alphabet {
    add_token(item.0)
  }

  let words = sorted_wordlevel_candidates(
    word_order, word_counts, min_frequency,
  )
  for item in words {
    add_token(item.0)
  }

  WordPiece({
    vocab,
    vocab_r,
    unk_token,
    continuing_subword_prefix,
    max_input_chars_per_word,
  })
}

///|
fn bump_count(
  counts : Map[String, Int],
  order : Array[String],
  tok : String,
) -> Unit {
  match counts.get(tok) {
    Some(n) => counts[tok] = n + 1
    None => {
      counts[tok] = 1
      order.push(tok)
    }
  }
}

///|
fn add_wordpiece_alphabet(
  tok : String,
  prefix : String,
  counts : Map[String, Int],
  order : Array[String],
) -> Unit {
  let chars = tok.to_array()
  for i, c in chars {
    let piece = if i == 0 { char_string(c) } else { prefix + char_string(c) }
    bump_count(counts, order, piece)
  }
}

///|
fn char_string(c : Char) -> String {
  let sb = StringBuilder::new()
  sb.write_char(c)
  sb.to_string()
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
