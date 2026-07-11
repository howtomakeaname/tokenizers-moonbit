///|
pub fn Model::train_unigram(
  texts : Array[String],
  unk_token? : String? = None,
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = Some(8000),
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
  max_piece_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  shrinking_factor? : Double = 0.75,
  n_sub_iterations? : Int = 2,
  show_progress? : Bool = true,
  seed_size? : Int = 1000000,
) -> Model {
  ignore(shrinking_factor)
  ignore(n_sub_iterations)
  ignore(show_progress)
  let unk_token = match unk_piece {
    Some(piece) => Some(piece)
    None => unk_token
  }
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
    max_piece_length~,
    initial_alphabet~,
    shrinking_factor~,
    n_sub_iterations~,
    show_progress~,
    seed_size~,
  )
}

///|
/// Train a deterministic Unigram model from pre-tokenized token streams.
pub fn Model::train_unigram_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String? = None,
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = Some(8000),
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
  max_piece_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  shrinking_factor? : Double = 0.75,
  n_sub_iterations? : Int = 2,
  show_progress? : Bool = true,
  seed_size? : Int = 1000000,
) -> Model {
  ignore(show_progress)
  let unk_token = match unk_piece {
    Some(piece) => Some(piece)
    None => unk_token
  }
  let word_counts : Map[String, Int] = {}
  let word_order : Array[String] = []
  let char_counts : Map[String, Int] = {}
  let char_order : Array[String] = []
  let piece_counts : Map[String, Int] = {}
  let piece_order : Array[String] = []
  for tokens in tokenized_texts {
    for tok in tokens {
      bump_count(word_counts, word_order, tok)
      for c in tok.to_array() {
        bump_count(char_counts, char_order, char_string(c))
      }
      add_unigram_subpieces(tok, max_piece_length, piece_counts, piece_order)
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
  match unk_token {
    Some(unk) =>
      if !array_contains_string(special_tokens, unk) {
        unk_id = add_token(unk, 0.0)
      }
    None => ()
  }
  for tok in special_tokens {
    let id = add_token(tok, 0.0)
    match unk_token {
      Some(unk) =>
        if tok == unk {
          match id {
            Some(n) => unk_id = Some(n)
            None =>
              match vocab.get(tok) {
                Some(p) => unk_id = Some(p.0)
                None => ()
              }
          }
        }
      None => ()
    }
  }

  let char_seed_start = vocab_r.length()
  for tok in initial_alphabet {
    match initial_alphabet_piece(tok) {
      Some(piece) => ignore(add_token(piece, -10.0))
      None => ()
    }
  }
  let chars = sorted_wordlevel_candidates(char_order, char_counts, 1)
  for item in chars {
    ignore(add_token(item.0, -10.0))
  }
  let char_seed_count = vocab_r.length() - char_seed_start

  let candidates = select_unigram_candidates(
    piece_order,
    piece_counts,
    word_order,
    word_counts,
    min_frequency,
    max_piece_length,
    current_size=vocab_r.length(),
    vocab_size~,
    shrinking_factor~,
    n_sub_iterations~,
    seed_size~,
    char_seed_count~,
  )
  for item in candidates {
    ignore(add_token(item.token, item.score))
  }

  Unigram({
    vocab,
    vocab_r,
    unk_id,
    byte_fallback,
    fuse_unk,
    alpha: None,
    nbest_size: None,
    cache: {},
    cache_capacity: None,
  })
}

///|
priv struct UnigramTrainCandidate {
  token : String
  freq : Int
  score : Double
  length : Int
  kind_rank : Int
}

///|
fn select_unigram_candidates(
  piece_order : Array[String],
  piece_counts : Map[String, Int],
  word_order : Array[String],
  word_counts : Map[String, Int],
  min_frequency : Int,
  max_piece_length : Int?,
  current_size~ : Int,
  vocab_size~ : Int?,
  shrinking_factor~ : Double,
  n_sub_iterations~ : Int,
  seed_size~ : Int,
  char_seed_count~ : Int,
) -> Array[UnigramTrainCandidate] {
  let candidates : Array[UnigramTrainCandidate] = []
  for
    item in sorted_wordlevel_candidates(
      piece_order, piece_counts, min_frequency,
    ) {
    candidates.push({
      token: item.0,
      freq: item.1,
      score: unigram_piece_score(item.1),
      length: item.0.char_length(),
      kind_rank: 1,
    })
  }
  for
    item in sorted_wordlevel_candidates(word_order, word_counts, min_frequency) {
    if unigram_piece_within_limit(item.0, max_piece_length) {
      candidates.push({
        token: item.0,
        freq: item.1,
        score: unigram_word_score(item.1),
        length: item.0.char_length(),
        kind_rank: 0,
      })
    }
  }
  candidates.sort_by(unigram_candidate_compare)
  let seed_target = unigram_seed_candidate_target(
    seed_size,
    char_seed_count,
    candidates.length(),
  )
  let target = unigram_candidate_target(current_size, vocab_size, seed_target)
  unigram_shrink_candidates(
    candidates, target, shrinking_factor, n_sub_iterations,
  )
}

///|
fn unigram_seed_candidate_target(
  seed_size : Int,
  char_seed_count : Int,
  available : Int,
) -> Int {
  let remaining = seed_size - char_seed_count
  if remaining <= 0 {
    0
  } else if remaining < available {
    remaining
  } else {
    available
  }
}

///|
fn unigram_candidate_target(
  current_size : Int,
  vocab_size : Int?,
  available : Int,
) -> Int {
  match vocab_size {
    None => available
    Some(limit) =>
      if limit <= 0 {
        available
      } else if limit <= current_size {
        0
      } else {
        let remaining = limit - current_size
        if remaining < available {
          remaining
        } else {
          available
        }
      }
  }
}

///|
fn unigram_shrink_candidates(
  ranked : Array[UnigramTrainCandidate],
  target : Int,
  shrinking_factor : Double,
  n_sub_iterations : Int,
) -> Array[UnigramTrainCandidate] {
  if target <= 0 || ranked.length() == 0 {
    return []
  }
  let factor = normalize_shrinking_factor(shrinking_factor)
  let rounds = if n_sub_iterations < 0 { 0 } else { n_sub_iterations }
  let mut keep = ranked.length()
  for _ in 0..<rounds {
    if keep <= target {
      break
    }
    let next = (keep.to_double() * factor).to_int()
    keep = if next < target {
      target
    } else if next >= keep {
      keep - 1
    } else {
      next
    }
  }
  if keep > target {
    keep = target
  }
  let out : Array[UnigramTrainCandidate] = []
  for i in 0..<keep {
    out.push(ranked[i])
  }
  out
}

///|
fn normalize_shrinking_factor(factor : Double) -> Double {
  if factor > 0.0 && factor < 1.0 {
    factor
  } else {
    0.75
  }
}

///|
fn unigram_candidate_compare(
  a : UnigramTrainCandidate,
  b : UnigramTrainCandidate,
) -> Int {
  if a.score > b.score {
    -1
  } else if a.score < b.score {
    1
  } else if a.freq != b.freq {
    b.freq.compare(a.freq)
  } else if a.kind_rank != b.kind_rank {
    a.kind_rank.compare(b.kind_rank)
  } else if a.length != b.length {
    b.length.compare(a.length)
  } else {
    a.token.compare(b.token)
  }
}

///|
fn unigram_word_score(freq : Int) -> Double {
  // Keep scores deterministic and simple: frequent words get slightly better
  // scores, and all whole words beat character-piece paths.
  freq.to_double()
}

///|
fn unigram_piece_score(freq : Int) -> Double {
  -5.0 + freq.to_double() / 1000.0
}

///|
fn unigram_piece_within_limit(piece : String, max_piece_length : Int?) -> Bool {
  match max_piece_length {
    None => true
    Some(n) => n <= 0 || piece.char_length() <= n
  }
}

///|
fn add_unigram_subpieces(
  tok : String,
  max_piece_length : Int?,
  counts : Map[String, Int],
  order : Array[String],
) -> Unit {
  let chars = tok.to_array()
  let n = chars.length()
  if n <= 2 {
    return
  }
  let max_len = match max_piece_length {
    Some(limit) => if limit <= 0 { n - 1 } else { limit }
    None => 16
  }
  let hi = if max_len >= n { n - 1 } else { max_len }
  if hi < 2 {
    return
  }
  for start in 0..<n {
    for len in 2..<=hi {
      let stop = start + len
      if stop <= n {
        bump_count(counts, order, slice_train(chars, start, stop))
      }
    }
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
