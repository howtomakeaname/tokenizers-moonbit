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
  end_of_word_suffix? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
  max_token_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
) -> Model {
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(whitespace_words(text))
  }
  Model::train_wordpiece_from_tokens(
    tokenized,
    unk_token~,
    continuing_subword_prefix~,
    end_of_word_suffix~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
    max_input_chars_per_word~,
    max_token_length~,
    initial_alphabet~,
    limit_alphabet~,
  )
}

///|
/// Train a deterministic WordPiece model from pre-tokenized token streams.
pub fn Model::train_wordpiece_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String = "[UNK]",
  continuing_subword_prefix? : String = "##",
  end_of_word_suffix? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  max_input_chars_per_word? : Int = 100,
  max_token_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
) -> Model {
  let word_counts : Map[String, Int] = {}
  let word_order : Array[String] = []
  let piece_counts : Map[String, Int] = {}
  let piece_order : Array[String] = []
  for tokens in tokenized_texts {
    for tok in tokens {
      bump_count(word_counts, word_order, tok)
      add_wordpiece_alphabet(
        tok, continuing_subword_prefix, end_of_word_suffix, piece_counts, piece_order,
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

  let alphabet = limited_trainer_alphabet(
    piece_order, piece_counts, initial_alphabet, limit_alphabet,
  )
  for item in alphabet {
    add_token(item.0)
  }

  let words = sorted_wordlevel_candidates(
    word_order, word_counts, min_frequency,
  )
  for item in words {
    let tok = wordpiece_word_token(item.0, end_of_word_suffix)
    if wordpiece_train_token_allowed(tok, max_token_length) {
      add_token(tok)
    }
  }

  WordPiece({
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
  suffix : String?,
  counts : Map[String, Int],
  order : Array[String],
) -> Unit {
  let chars = tok.to_array()
  for i, c in chars {
    let piece = if i == 0 { char_string(c) } else { prefix + char_string(c) }
    bump_count(
      counts,
      order,
      if i == chars.length() - 1 {
        wordpiece_word_token(piece, suffix)
      } else {
        piece
      },
    )
  }
}

///|
fn wordpiece_word_token(tok : String, suffix : String?) -> String {
  match suffix {
    Some(suf) => tok + suf
    None => tok
  }
}

///|
fn wordpiece_train_token_allowed(tok : String, max_token_length : Int?) -> Bool {
  match max_token_length {
    None => true
    Some(n) => n <= 0 || tok.char_length() <= n
  }
}

///|
fn char_string(c : Char) -> String {
  @common.char_string(c)
}

///|
/// Train a deterministic BPE model from whitespace-delimited text.
///
/// This implements the core HF BPETrainer loop: reserve special/unk tokens, seed
/// a character alphabet (including optional caller-provided initial alphabet and
/// corpus alphabet cap), repeatedly pick the highest-frequency adjacent pair
/// (frequency desc, lexical tie-break), add the merged token, and rewrite the
/// corpus. Runtime BPE options such as dropout can be supplied when callers need
/// to preserve an existing model configuration across retraining.
pub fn Model::train_bpe(
  texts : Array[String],
  unk_token? : String? = Some("[UNK]"),
  min_frequency? : Int = 2,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
  continuing_subword_prefix? : String? = None,
  end_of_word_suffix? : String? = None,
  fuse_unk? : Bool = false,
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  max_token_length? : Int? = None,
  byte_fallback? : Bool = false,
  ignore_merges? : Bool = false,
  dropout? : Double? = None,
  cache_capacity? : Int? = None,
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
    initial_alphabet~,
    limit_alphabet~,
    max_token_length~,
    byte_fallback~,
    ignore_merges~,
    dropout~,
    cache_capacity~,
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
  initial_alphabet? : Array[String] = [],
  limit_alphabet? : Int? = None,
  max_token_length? : Int? = None,
  byte_fallback? : Bool = false,
  ignore_merges? : Bool = false,
  dropout? : Double? = None,
  cache_capacity? : Int? = None,
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
  let alphabet = limited_trainer_alphabet(
    alphabet_order, alphabet_counts, initial_alphabet, limit_alphabet,
  )
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
    let pair = best_bpe_pair(
      words, freqs, min_frequency, max_token_length, continuing_subword_prefix,
    )
    match pair {
      None => break
      Some(p) => {
        let merged = bpe_merged_token(p, continuing_subword_prefix)
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
    byte_fallback,
    ignore_merges,
    dropout: normalize_bpe_dropout(dropout),
    dropout_rng_state: 1,
    cache: {},
    cache_capacity: normalize_bpe_cache_capacity(cache_capacity),
  })
}

///|
fn normalize_bpe_dropout(dropout : Double?) -> Double? {
  match dropout {
    Some(p) => if p > 0.0 { Some(p) } else { None }
    None => None
  }
}

///|
fn normalize_bpe_cache_capacity(capacity : Int?) -> Int? {
  match capacity {
    Some(n) => Some(if n > 0 { n } else { 0 })
    None => None
  }
}

///|
fn bpe_merged_token(
  pair : (String, String),
  continuing_subword_prefix : String?,
) -> String {
  let right = match continuing_subword_prefix {
    Some(prefix) =>
      if !prefix.is_empty() && pair.1.has_prefix(prefix) {
        string_drop_prefix(pair.1, prefix)
      } else {
        pair.1
      }
    None => pair.1
  }
  pair.0 + right
}

///|
fn string_drop_prefix(s : String, prefix : String) -> String {
  let chars = s.to_array()
  let start = prefix.char_length()
  let sb = StringBuilder::new()
  for i in start..<chars.length() {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn initial_alphabet_piece(s : String) -> String? {
  for c in s {
    return Some(char_string(c))
  }
  None
}

///|
fn limited_trainer_alphabet(
  corpus_order : Array[String],
  corpus_counts : Map[String, Int],
  initial_alphabet : Array[String],
  limit : Int?,
) -> Array[(String, Int)] {
  let counts : Map[String, Int] = {}
  let order : Array[String] = []
  for item in sorted_wordlevel_candidates(corpus_order, corpus_counts, 1) {
    counts[item.0] = item.1
    order.push(item.0)
  }
  for tok in initial_alphabet {
    match initial_alphabet_piece(tok) {
      Some(piece) =>
        if counts.contains(piece) {
          counts[piece] = initial_alphabet_priority()
        } else {
          counts[piece] = initial_alphabet_priority()
          order.push(piece)
        }
      None => ()
    }
  }
  limit_alphabet_candidates(
    sorted_wordlevel_candidates(order, counts, 1),
    limit,
  )
}

///|
fn initial_alphabet_priority() -> Int {
  2147483647
}

///|
fn limit_alphabet_candidates(
  candidates : Array[(String, Int)],
  limit : Int?,
) -> Array[(String, Int)] {
  match limit {
    None => candidates
    Some(n) =>
      if n <= 0 || candidates.length() <= n {
        if n <= 0 {
          []
        } else {
          candidates
        }
      } else {
        let out : Array[(String, Int)] = []
        for i in 0..<n {
          out.push(candidates[i])
        }
        out
      }
  }
}

///|
fn array_contains_string(values : Array[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
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
  max_token_length : Int?,
  continuing_subword_prefix : String?,
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
        if bpe_merged_token_allowed(
            p, max_token_length, continuing_subword_prefix,
          ) &&
          (n > best_count || (n == best_count && bpe_pair_less(p, best))) {
          best = Some(p)
          best_count = n
        }
      None => ()
    }
  }
  best
}

///|
fn bpe_merged_token_allowed(
  pair : (String, String),
  max_token_length : Int?,
  continuing_subword_prefix : String?,
) -> Bool {
  match max_token_length {
    None => true
    Some(n) =>
      n <= 0 || bpe_merged_token(pair, continuing_subword_prefix).length() <= n
  }
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
/// alphabet and ranked whole/subpiece candidates with deterministic scores that
/// make known whole words preferred over character segmentation.
pub fn Model::train_unigram(
  texts : Array[String],
  unk_token? : String = "<unk>",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
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
  unk_token? : String = "<unk>",
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = None,
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
  if !array_contains_string(special_tokens, unk_token) {
    unk_id = add_token(unk_token, 0.0)
  }
  for tok in special_tokens {
    let id = add_token(tok, 0.0)
    if tok == unk_token {
      match id {
        Some(n) => unk_id = Some(n)
        None =>
          match vocab.get(tok) {
            Some(p) => unk_id = Some(p.0)
            None => ()
          }
      }
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
