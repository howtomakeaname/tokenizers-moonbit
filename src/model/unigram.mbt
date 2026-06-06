// Unigram tokenization (SentencePiece-style: T5 / ALBERT).
//
// Viterbi over code points: best[i] is the max total score reachable at char
// position i; for each end we try every start whose substring is in the vocab.
// Backtrack to recover the token sequence. Unmatched single chars fall back to
// the unk token (unk_id) if present.

let neg_inf : Double = -1.0e308

// Per-unknown-character penalty (kept finite so multiple unks can accumulate
// without overflowing to -inf). Mirrors sentencepiece's kUnkPenalty scale.
let unk_penalty : Double = 1.0e4

/// Tokenize a single piece with this Unigram model.
pub fn UnigramModel::tokenize(
  self : UnigramModel,
  word : String,
  offset~ : Int = 0,
) -> Array[@types.Token] {
  let chars = word.to_array()
  let n = chars.length()
  if n == 0 {
    return []
  }
  // best[i] = best score to reach position i; back[i] = start of last token;
  // best_tok[i] = the token surface used for that last step.
  let best = Array::make(n + 1, neg_inf)
  let back = Array::make(n + 1, -1)
  let best_tok : Array[String] = Array::make(n + 1, "")
  let best_id = Array::make(n + 1, -1)
  best[0] = 0.0
  for end in 1..=n {
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
    // Fallback: a single unknown char as unk (so we always reach the end).
    if best[end] == neg_inf && end > 0 {
      let start = end - 1
      if best[start] != neg_inf {
        best[end] = best[start] - unk_penalty
        back[end] = start
        best_tok[end] = make_piece(chars, start, end)
        best_id[end] = self.unk_id.unwrap_or(-1)
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
    let is_unk = not(self.vocab.contains(best_tok[pos]))
    let id = if is_unk { self.unk_id.unwrap_or(-1) } else { best_id[pos] }
    rev.push(@types.Token::{
      id,
      value: best_tok[pos],
      offsets: (offset + start, offset + pos),
    })
    pos = start
  }
  // reverse into order
  let out : Array[@types.Token] = []
  let mut k = rev.length() - 1
  while k >= 0 {
    out.push(rev[k])
    k = k - 1
  }
  // fuse_unk: merge runs of adjacent unk tokens into one (HF default).
  if self.fuse_unk {
    match self.unk_id {
      Some(uid) => fuse_unigram_unk(out, uid)
      None => out
    }
  } else {
    out
  }
}

// Merge adjacent unk tokens (id == uid) into a single spanning token.
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

fn make_piece(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}
