// WordPiece tokenization (BERT-style).
//
// Greedy longest-prefix matching: for each word, repeatedly take the longest
// vocab entry that is a prefix of the remaining chars (continuation pieces get
// the `##` prefix). If any segment fails to match, the whole word becomes the
// unk token. Words longer than `max_input_chars_per_word` are unk.

///|
/// Tokenize a single word with this WordPiece model.
pub fn WordPieceModel::tokenize(
  self : WordPieceModel,
  word : String,
  offset? : Int = 0,
) -> Array[@types.Token] {
  let chars = word.to_array()
  let n = chars.length()
  if n == 0 {
    return []
  }
  match self.cache.get(word) {
    Some(cached) => return shift_wordpiece_tokens(cached, offset)
    None => ()
  }
  let unk_id = self.vocab.get(self.unk_token).unwrap_or(-1)
  if n > self.max_input_chars_per_word {
    let rel = [
      @types.Token::{ id: unk_id, value: self.unk_token, offsets: (0, n) },
    ]
    put_token_cache(self.cache, self.cache_capacity, word, rel)
    return shift_wordpiece_tokens(rel, offset)
  }
  let out : Array[@types.Token] = []
  let mut start = 0
  let mut is_bad = false
  while start < n {
    let mut end = n
    let mut cur : String? = None
    let mut cur_end = start
    while start < end {
      let mut sub = make_sub(chars, start, end)
      if start > 0 {
        sub = self.continuing_subword_prefix + sub
      }
      if self.vocab.contains(sub) {
        cur = Some(sub)
        cur_end = end
        break
      }
      end = end - 1
    }
    match cur {
      None => {
        is_bad = true
        break
      }
      Some(tok) => {
        out.push(@types.Token::{
          id: self.vocab.get(tok).unwrap_or(unk_id),
          value: tok,
          offsets: (start, cur_end),
        })
        start = cur_end
      }
    }
  }
  if is_bad {
    let rel = [
      @types.Token::{ id: unk_id, value: self.unk_token, offsets: (0, n) },
    ]
    put_token_cache(self.cache, self.cache_capacity, word, rel)
    shift_wordpiece_tokens(rel, offset)
  } else {
    put_token_cache(self.cache, self.cache_capacity, word, out)
    shift_wordpiece_tokens(out, offset)
  }
}

///|
fn shift_wordpiece_tokens(
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
fn make_sub(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}
