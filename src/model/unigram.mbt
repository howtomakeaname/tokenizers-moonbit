// Unigram tokenization (SentencePiece-style: T5 / ALBERT).
//
// Viterbi over code points: best[i] is the max total score reachable at char
// position i; for each end we try every start whose substring is in the vocab.
// Backtrack to recover the token sequence. Unmatched single chars fall back to
// the unk token (unk_id) if present.

let neg_inf : Double = -1.0e308

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
        // use unk score (very low) so real tokens are always preferred
        best[end] = best[start] + neg_inf / 2.0
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
  out
}

fn make_piece(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}
