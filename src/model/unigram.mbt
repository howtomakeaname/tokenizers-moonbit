// Unigram tokenization (SentencePiece-style: T5 / ALBERT).
//
// Viterbi over code points: best[i] is the max total score reachable at char
// position i; for each end we try every start whose substring is in the vocab.
// Backtrack to recover the token sequence. Unmatched single chars fall back to
// the unk token (unk_id) if present.

///|
let neg_inf : Double = -1.0e308

// Per-unknown-character penalty (kept finite so multiple unks can accumulate
// without overflowing to -inf). Mirrors sentencepiece's kUnkPenalty scale.

///|
let unk_penalty : Double = 1.0e4

///|
/// Tokenize a single piece with this Unigram model.
/// When alpha > 0, uses sampling instead of deterministic Viterbi.
pub fn UnigramModel::tokenize(
  self : UnigramModel,
  word : String,
  offset? : Int = 0,
) -> Array[@types.Token] raise @types.TokenizerError {
  // Use sampling when alpha is set and > 0
  match self.alpha {
    Some(a) if a > 0.0 =>
      return self.tokenize_with_sampling(word, a, self.nbest_size, offset)
    _ => ()
  }

  // Deterministic Viterbi path (default)
  let chars = word.to_array()
  let n = chars.length()
  if n == 0 {
    return []
  }
  match self.cache.get(word) {
    Some(cached) => return shift_unigram_tokens(cached, offset)
    None => ()
  }
  // best[i] = best score to reach position i; back[i] = start of last token;
  // best_tok[i] = the token surface used for that last step.
  let best = Array::make(n + 1, neg_inf)
  let back = Array::make(n + 1, -1)
  let best_tok : Array[String] = Array::make(n + 1, "")
  let best_id = Array::make(n + 1, -1)
  best[0] = 0.0
  for end in 1..<=n {
    for start in 0..<end {
      if best[start] == neg_inf {
        continue
      }
      let piece = make_piece(chars, start, end)
      match self.vocab.get(piece) {
        Some((id, score)) => {
          let s = best[start] + score
          if s > best[end] {
            best[end] = s
            back[end] = start
            best_tok[end] = piece
            best_id[end] = id
          }
        }
        None => ()
      }
    }
    // HF allows Unigram without `unk_id`, but tokenization must fail if an
    // unknown fallback is actually required.
    if best[end] == neg_inf && end > 0 {
      let start = end - 1
      if best[start] != neg_inf {
        match self.unk_id {
          Some(uid) => {
            best[end] = best[start] - unk_penalty
            back[end] = start
            best_tok[end] = make_piece(chars, start, end)
            best_id[end] = uid
          }
          None =>
            raise @types.VocabError(
              "Encountered an unknown token but `unk_id` is missing",
            )
        }
      }
    }
  }

  // Backtrack.
  let rev : Array[@types.Token] = []
  let mut pos = n
  while pos > 0 {
    let start = back[pos]
    if start < 0 {
      break
    }
    let is_unk = !self.vocab.contains(best_tok[pos])
    let id = if is_unk {
      match self.unk_id {
        Some(uid) => uid
        None =>
          raise @types.VocabError(
            "Encountered an unknown token but `unk_id` is missing",
          )
      }
    } else {
      best_id[pos]
    }
    rev.push(@types.Token::{ id, value: best_tok[pos], offsets: (start, pos) })
    pos = start
  }
  // reverse into order
  let out : Array[@types.Token] = []
  let mut k = rev.length() - 1
  while k >= 0 {
    out.push(rev[k])
    k = k - 1
  }
  // byte_fallback: replace unknown pieces by their UTF-8 <0xXX> byte tokens
  // when the model vocab contains all required byte tokens.
  let expanded = if self.byte_fallback {
    self.expand_byte_fallback(out)
  } else {
    out
  }
  // fuse_unk: merge runs of adjacent unk tokens into one (HF default). Run this
  // after byte_fallback so successfully expanded bytes are not fused as unk.
  let rel = if self.fuse_unk {
    match self.unk_id {
      Some(uid) => fuse_unigram_unk(expanded, uid)
      None => expanded
    }
  } else {
    expanded
  }
  put_token_cache(self.cache, self.cache_capacity, word, rel)
  shift_unigram_tokens(rel, offset)
}

///|
fn shift_unigram_tokens(
  tokens : Array[@types.Token],
  offset : Int,
) -> Array[@types.Token] {
  if offset == 0 {
    return tokens.copy()
  }
  tokens.map(t => @types.Token::{
    id: t.id,
    value: t.value,
    offsets: (t.offsets.0 + offset, t.offsets.1 + offset),
  })
}

///|
fn UnigramModel::expand_byte_fallback(
  self : UnigramModel,
  toks : Array[@types.Token],
) -> Array[@types.Token] {
  let out : Array[@types.Token] = []
  for t in toks {
    if self.vocab.contains(t.value) {
      out.push(t)
      continue
    }
    match self.try_byte_fallback(t.value, t.offsets) {
      Some(bytes) =>
        for b in bytes {
          out.push(b)
        }
      None => out.push(t)
    }
  }
  out
}

///|
fn UnigramModel::try_byte_fallback(
  self : UnigramModel,
  surface : String,
  offsets : (Int, Int),
) -> Array[@types.Token]? {
  let bytes = @utf8.encode(surface)
  let toks : Array[@types.Token] = []
  for i in 0..<bytes.length() {
    let tok = byte_hex_token(bytes[i].to_int())
    match self.vocab.get(tok) {
      Some((id, _)) => toks.push(@types.Token::{ id, value: tok, offsets })
      None => return None
    }
  }
  Some(toks)
}

// Merge adjacent unk tokens (id == uid) into a single spanning token.

///|
fn fuse_unigram_unk(
  toks : Array[@types.Token],
  uid : Int,
) -> Array[@types.Token] {
  let out : Array[@types.Token] = []
  for t in toks {
    if t.id == uid && out.length() > 0 && out[out.length() - 1].id == uid {
      let prev = out[out.length() - 1]
      out[out.length() - 1] = @types.Token::{
        id: uid,
        value: prev.value + t.value,
        offsets: (prev.offsets.0, t.offsets.1),
      }
    } else {
      out.push(t)
    }
  }
  out
}

///|
fn make_piece(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
/// Compute log(sum(exp(a), exp(b))) in a numerically stable way.
fn log_sum_exp(a : Double, b : Double) -> Double {
  if a == neg_inf {
    return b
  }
  if b == neg_inf {
    return a
  }
  let max_val = if a > b { a } else { b }
  let diff = if a > b { b - max_val } else { a - max_val }
  // For very small differences, return max directly
  if diff < -20.0 {
    return max_val
  }
  max_val + @math.ln(1.0 + @math.exp(diff))
}

///|
/// Tokenize with sampling when alpha > 0. Uses forward-backward algorithm
/// to compute probabilities, then samples from the distribution.
/// When nbest_size > 0, enumerates N-best paths via beam search and samples
/// from them (SentencePiece N-best mode). Otherwise uses forward-backward.
fn UnigramModel::tokenize_with_sampling(
  self : UnigramModel,
  word : String,
  alpha : Double,
  nbest_size : Int?,
  offset : Int,
) -> Array[@types.Token] {
  let chars = word.to_array()
  let n = chars.length()
  if n == 0 {
    return []
  }

  // Build lattice: for each position, collect all possible pieces
  // pieces[end] = [(start, id, score, piece)]
  let pieces : Array[Array[(Int, Int, Double, String)]] = Array::make(n + 1, [])
  for end in 1..<=n {
    let row : Array[(Int, Int, Double, String)] = []
    for start in 0..<end {
      let piece = make_piece(chars, start, end)
      match self.vocab.get(piece) {
        Some((id, score)) => row.push((start, id, score, piece))
        None => ()
      }
    }
    // Add unk fallback for single characters if no piece found
    if row.length() == 0 {
      let start = end - 1
      let piece = make_piece(chars, start, end)
      match self.unk_id {
        Some(uid) => row.push((start, uid, -unk_penalty, piece))
        None => () // Skip if no unk_id
      }
    }
    pieces[end] = row
  }

  // Choose sampling strategy based on nbest_size
  let result_rev : Array[(Int, Int, String)] = match nbest_size {
    Some(nb) if nb > 0 =>
      // N-best mode: enumerate top-N paths via beam search, then sample
      sample_nbest(pieces, n, nb, alpha)
    _ =>
      // Forward-backward mode: sample from full distribution
      sample_forward_backward(pieces, n, alpha)
  }

  // Reverse to get correct order
  let out : Array[@types.Token] = []
  let mut k = result_rev.length() - 1
  while k >= 0 {
    let (start, id, piece) = result_rev[k]
    out.push(@types.Token::{
      id,
      value: piece,
      offsets: (start, start + piece.to_array().length()),
    })
    k = k - 1
  }

  // Apply byte_fallback and fuse_unk
  let expanded = if self.byte_fallback {
    self.expand_byte_fallback(out)
  } else {
    out
  }
  let rel = if self.fuse_unk {
    match self.unk_id {
      Some(uid) => fuse_unigram_unk(expanded, uid)
      None => expanded
    }
  } else {
    expanded
  }

  shift_unigram_tokens(rel, offset)
}

///|
/// N-best sampling via beam search over the lattice.
/// Enumerates up to `nbest_size` complete paths, scores them, and samples
/// using softmax with `alpha` as temperature.
fn sample_nbest(
  pieces : Array[Array[(Int, Int, Double, String)]],
  n : Int,
  nbest_size : Int,
  alpha : Double,
) -> Array[(Int, Int, String)] {
  // Beam search: at each position, keep top-N partial paths
  // paths[end] = [(score, path)] where path = [(start, id, piece), ...]
  let beams : Array[Array[(Double, Array[(Int, Int, String)])]] = Array::make(
    n + 1,
    [],
  )
  beams[0] = [(0.0, [])]

  for end in 1..<=n {
    let candidates : Array[(Double, Array[(Int, Int, String)])] = []
    for cand in pieces[end] {
      let start = cand.0
      let id = cand.1
      let score = cand.2
      let piece = cand.3
      for beam_item in beams[start] {
        let prev_score = beam_item.0
        let prev_path = beam_item.1
        let new_score = prev_score + score
        let new_path : Array[(Int, Int, String)] = []
        for item in prev_path {
          new_path.push(item)
        }
        new_path.push((start, id, piece))
        candidates.push((new_score, new_path))
      }
    }
    // Keep top-N candidates by score
    candidates.sort_by(fn(a, b) { b.0.compare(a.0) })
    let keep = if candidates.length() > nbest_size {
      nbest_size
    } else {
      candidates.length()
    }
    let beam : Array[(Double, Array[(Int, Int, String)])] = []
    for i in 0..<keep {
      beam.push(candidates[i])
    }
    beams[end] = beam
  }

  // Sample from the N-best complete paths
  let final_paths = beams[n]
  if final_paths.length() == 0 {
    return []
  }
  if final_paths.length() == 1 {
    return final_paths[0].1
  }

  // Compute softmax probabilities with temperature alpha
  let log_scores : Array[Double] = final_paths.map(fn(p) { p.0 * alpha })
  let idx = sample_from_log_probs(log_scores)
  return final_paths[idx].1
}

///|
/// Forward-backward sampling: sample from the full distribution at each position.
fn sample_forward_backward(
  pieces : Array[Array[(Int, Int, Double, String)]],
  n : Int,
  alpha : Double,
) -> Array[(Int, Int, String)] {
  // Forward pass: compute log partition function at each position
  let forward = Array::make(n + 1, neg_inf)
  forward[0] = 0.0
  for pos in 1..<=n {
    for candidate in pieces[pos] {
      let start = candidate.0
      let score = candidate.2
      if forward[start] != neg_inf {
        forward[pos] = log_sum_exp(forward[pos], forward[start] + alpha * score)
      }
    }
  }

  // Backward pass: sample tokens from right to left
  let result_rev : Array[(Int, Int, String)] = []
  let mut pos = n
  while pos > 0 {
    if forward[pos] == neg_inf {
      break
    }

    let candidates = pieces[pos]
    if candidates.length() == 0 {
      break
    }

    let log_probs : Array[Double] = candidates.map(fn(c) {
      let (start, _, score, _) = c
      if forward[start] == neg_inf {
        neg_inf
      } else {
        forward[start] + alpha * score - forward[pos]
      }
    })

    let sampled_idx = sample_from_log_probs(log_probs)
    let (start, id, _, piece) = candidates[sampled_idx]
    result_rev.push((start, id, piece))
    pos = start
  }

  result_rev
}

///|
/// Sample an index from log probabilities using softmax sampling.
fn sample_from_log_probs(log_probs : Array[Double]) -> Int {
  let n = log_probs.length()
  if n == 0 {
    return 0
  }
  if n == 1 {
    return 0
  }

  // Find max for numerical stability
  let mut max_log = neg_inf
  for lp in log_probs {
    if lp > max_log {
      max_log = lp
    }
  }

  // Compute softmax probabilities
  let probs : Array[Double] = []
  let mut sum = 0.0
  for lp in log_probs {
    let p = if lp == neg_inf { 0.0 } else { @math.exp(lp - max_log) }
    probs.push(p)
    sum = sum + p
  }

  // Normalize
  if sum > 0.0 {
    for i in 0..<n {
      probs[i] = probs[i] / sum
    }
  }

  // Sample using cumulative distribution
  // Use a simple deterministic seed based on log_probs for reproducibility
  let mut seed = 0.0
  for lp in log_probs {
    seed = seed + lp
  }
  let r = (seed.abs() * 1000.0).floor() % 1.0
  let mut cumsum = 0.0
  for i in 0..<n {
    cumsum = cumsum + probs[i]
    if r < cumsum {
      return i
    }
  }

  // Fallback to last index
  n - 1
}
