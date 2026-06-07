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
    cache: {},
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
/// Train a deterministic BPE model from whitespace-delimited text.
///
/// This MVP implements the core HF BPETrainer loop: reserve special/unk tokens,
/// seed a character alphabet, repeatedly pick the highest-frequency adjacent
/// pair (frequency desc, lexical tie-break), add the merged token, and rewrite
/// the corpus. It intentionally omits advanced trainer knobs such as dropout,
/// initial alphabet limits, and byte-level alphabet generation.
pub fn Model::train_bpe(
  texts : Array[String],
  unk_token? : String? = Some("[UNK]"),
  min_frequency? : Int = 2,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  continuing_subword_prefix? : String? = None,
  end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false,
) -> Model {
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(whitespace_words(text))
  }
  Model::train_bpe_from_tokens(
    tokenized,
    unk_token~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
    continuing_subword_prefix~,
    end_of_word_suffix~,
    fuse_unk~,
  )
}

///|
/// Train a deterministic BPE model from pre-tokenized token streams.
pub fn Model::train_bpe_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String? = Some("[UNK]"),
  min_frequency? : Int = 2,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  continuing_subword_prefix? : String? = None,
  end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false,
) -> Model {
  let word_counts : Map[String, Int] = {}
  let word_order : Array[String] = []
  let alphabet_counts : Map[String, Int] = {}
  let alphabet_order : Array[String] = []
  for tokens in tokenized_texts {
    for tok in tokens {
      bump_count(word_counts, word_order, tok)
      add_bpe_alphabet(
        tok, continuing_subword_prefix, end_of_word_suffix, alphabet_counts, alphabet_order,
      )
    }
  }

  let vocab : Map[String, Int] = {}
  let vocab_r : Array[String?] = []
  fn add_token(tok : String) -> Bool {
    if vocab.contains(tok) || !under_vocab_limit(vocab.length(), vocab_size) {
      return false
    }
    let id = vocab.length()
    vocab[tok] = id
    vocab_r.push(Some(tok))
    true
  }

  for tok in special_tokens {
    ignore(add_token(tok))
  }
  match unk_token {
    Some(unk) => ignore(add_token(unk))
    None => ()
  }
  let alphabet = sorted_wordlevel_candidates(alphabet_order, alphabet_counts, 1)
  for item in alphabet {
    ignore(add_token(item.0))
  }

  let words : Array[Array[String]] = []
  let freqs : Array[Int] = []
  for word in word_order {
    match word_counts.get(word) {
      Some(n) => {
        words.push(
          bpe_initial_symbols(
            word, continuing_subword_prefix, end_of_word_suffix,
          ),
        )
        freqs.push(n)
      }
      None => ()
    }
  }

  let merges : Map[(String, String), Int] = {}
  while under_vocab_limit(vocab.length(), vocab_size) {
    let pair = best_bpe_pair(words, freqs, min_frequency)
    match pair {
      None => break
      Some(p) => {
        let merged = p.0 + p.1
        if !add_token(merged) {
          break
        }
        merges[p] = merges.length()
        for i in 0..<words.length() {
          words[i] = replace_bpe_pair(words[i], p, merged)
        }
      }
    }
  }

  BPE({
    vocab,
    vocab_r,
    merges,
    unk_token,
    continuing_subword_prefix,
    end_of_word_suffix,
    fuse_unk,
    byte_fallback: false,
    ignore_merges: false,
    cache: {},
  })
}

///|
fn add_bpe_alphabet(
  tok : String,
  prefix : String?,
  suffix : String?,
  counts : Map[String, Int],
  order : Array[String],
) -> Unit {
  let symbols = bpe_initial_symbols(tok, prefix, suffix)
  for sym in symbols {
    bump_count(counts, order, sym)
  }
}

///|
fn bpe_initial_symbols(
  tok : String,
  prefix : String?,
  suffix : String?,
) -> Array[String] {
  let chars = tok.to_array()
  let out : Array[String] = []
  let n = chars.length()
  for i, c in chars {
    let mut s = char_string(c)
    if i > 0 {
      match prefix {
        Some(p) => s = p + s
        None => ()
      }
    }
    if i == n - 1 {
      match suffix {
        Some(x) => s = s + x
        None => ()
      }
    }
    out.push(s)
  }
  out
}

///|
fn best_bpe_pair(
  words : Array[Array[String]],
  freqs : Array[Int],
  min_frequency : Int,
) -> (String, String)? {
  let counts : Map[(String, String), Int] = {}
  let order : Array[(String, String)] = []
  for i, parts in words {
    if parts.length() < 2 {
      continue
    }
    for j in 0..<(parts.length() - 1) {
      let p = (parts[j], parts[j + 1])
      match counts.get(p) {
        Some(n) => counts[p] = n + freqs[i]
        None => {
          counts[p] = freqs[i]
          order.push(p)
        }
      }
    }
  }
  let mut best : (String, String)? = None
  let mut best_count = min_frequency - 1
  for p in order {
    match counts.get(p) {
      Some(n) =>
        if n > best_count || (n == best_count && bpe_pair_less(p, best)) {
          best = Some(p)
          best_count = n
        }
      None => ()
    }
  }
  best
}

///|
fn bpe_pair_less(p : (String, String), best : (String, String)?) -> Bool {
  match best {
    None => true
    Some(b) =>
      if p.0 != b.0 {
        p.0.compare(b.0) < 0
      } else {
        p.1.compare(b.1) < 0
      }
  }
}

///|
fn replace_bpe_pair(
  parts : Array[String],
  pair : (String, String),
  merged : String,
) -> Array[String] {
  let out : Array[String] = []
  let mut i = 0
  while i < parts.length() {
    if i + 1 < parts.length() && parts[i] == pair.0 && parts[i + 1] == pair.1 {
      out.push(merged)
      i = i + 2
    } else {
      out.push(parts[i])
      i = i + 1
    }
  }
  out
}

///|
/// Train a deterministic Unigram model from whitespace-delimited text.
///
/// This MVP provides a compact, serializable Unigram vocabulary suitable for
/// local migration workflows. It reserves the unk token, then adds a character
/// alphabet and high-frequency whole pre-tokens with deterministic scores that
/// make known whole words preferred over character segmentation.
pub fn Model::train_unigram(
  texts : Array[String],
  unk_token? : String = "<unk>",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
) -> Model {
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(whitespace_words(text))
  }
  Model::train_unigram_from_tokens(
    tokenized,
    unk_token~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
    byte_fallback~,
    fuse_unk~,
  )
}

///|
/// Train a deterministic Unigram model from pre-tokenized token streams.
pub fn Model::train_unigram_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String = "<unk>",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
) -> Model {
  let word_counts : Map[String, Int] = {}
  let word_order : Array[String] = []
  let char_counts : Map[String, Int] = {}
  let char_order : Array[String] = []
  for tokens in tokenized_texts {
    for tok in tokens {
      bump_count(word_counts, word_order, tok)
      for c in tok.to_array() {
        bump_count(char_counts, char_order, char_string(c))
      }
    }
  }

  let vocab : Map[String, (Int, Double)] = {}
  let vocab_r : Array[String?] = []
  fn add_token(tok : String, score : Double) -> Int? {
    if vocab.contains(tok) || !under_vocab_limit(vocab_r.length(), vocab_size) {
      return None
    }
    let id = vocab_r.length()
    vocab[tok] = (id, score)
    vocab_r.push(Some(tok))
    Some(id)
  }

  let mut unk_id : Int? = None
  for tok in special_tokens {
    let id = add_token(tok, 0.0)
    if tok == unk_token {
      unk_id = id
    }
  }
  if unk_id is None {
    unk_id = add_token(unk_token, 0.0)
  }

  let chars = sorted_wordlevel_candidates(char_order, char_counts, 1)
  for item in chars {
    ignore(add_token(item.0, -10.0))
  }

  let words = sorted_wordlevel_candidates(
    word_order, word_counts, min_frequency,
  )
  for item in words {
    ignore(add_token(item.0, unigram_word_score(item.1)))
  }

  Unigram({ vocab, vocab_r, unk_id, byte_fallback, fuse_unk, cache: {} })
}

///|
fn unigram_word_score(freq : Int) -> Double {
  // Keep scores deterministic and simple: frequent words get slightly better
  // scores, and all whole words beat character-piece paths.
  freq.to_double()
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
