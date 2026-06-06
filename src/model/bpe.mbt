// BPE tokenization: rank-based merging.
//
// A word (one pre-token) is split into initial symbols (one per code point,
// optionally with continuing-subword-prefix / end-of-word-suffix applied), then
// adjacent pairs are merged in order of merge rank (lowest first) until no
// known merge remains. Each surviving symbol is mapped to its vocab id.

// A symbol in the working sequence, modeled as a node in a doubly linked list
// over an array (so merges are O(1) splices).

///|
priv struct Symbol {
  mut value : String
  mut prev : Int
  mut next : Int
  mut alive : Bool
}

// A candidate merge of the pair starting at `pos` with its successor `right`.
// `rank` is the BPE merge rank (lower applied first). Stored in a max-heap, so
// Compare is defined so that a *smaller* rank (and then smaller pos) is "greater"
// and thus pops first. `right` lets us detect stale entries after merges.

///|
priv struct Merge {
  rank : Int
  pos : Int
  right : Int
} derive(Eq)

///|
impl Compare for Merge with fn compare(self, other) {
  // Smaller rank should pop first => it must compare as "greater".
  if self.rank != other.rank {
    other.rank - self.rank
  } else {
    // Tie: smaller pos first => compares greater.
    other.pos - self.pos
  }
}

///|
/// Tokenize a single word with this BPE model.
/// `offset` is the char offset of `word` within the original text.
pub fn BPEModel::tokenize(
  self : BPEModel,
  word : String,
  offset? : Int = 0,
) -> Array[@types.Token] {
  let chars = word.to_array()
  let n = chars.length()
  if n == 0 {
    return []
  }

  match self.cache.get(word) {
    Some(cached) => return shift_tokens(cached, offset)
    None => ()
  }

  // ignore_merges fast path: if the whole word is directly in the vocab, emit
  // it as a single token without running any merges (GPT-4 / tiktoken style).
  if self.ignore_merges {
    match self.vocab.get(word) {
      Some(id) => {
        let rel = [@types.Token::{ id, value: word, offsets: (0, n) }]
        self.cache[word] = rel
        return shift_tokens(rel, offset)
      }
      None => ()
    }
  }

  // Build initial symbols, applying optional prefix/suffix like HF does.
  let symbols : Array[Symbol] = []
  for i, c in chars {
    let mut s = char_str(c)
    if i > 0 {
      match self.continuing_subword_prefix {
        Some(p) => s = p + s
        None => ()
      }
    }
    if i == n - 1 {
      match self.end_of_word_suffix {
        Some(suf) => s = s + suf
        None => ()
      }
    }
    symbols.push({ value: s, prev: i - 1, next: i + 1, alive: true })
  }
  symbols[n - 1].next = -1

  // Seed a priority queue with every adjacent pair that has a merge rank.
  let heap : @pq.PriorityQueue[Merge] = @pq.PriorityQueue([])
  fn try_push(pos : Int) -> Unit {
    if pos < 0 || !symbols[pos].alive {
      return
    }
    let r = symbols[pos].next
    if r < 0 {
      return
    }
    match self.merges.get((symbols[pos].value, symbols[r].value)) {
      Some(rank) => heap.push({ rank, pos, right: r })
      None => ()
    }
  }

  for i in 0..<n {
    try_push(i)
  }

  // Pop the lowest-rank valid pair, merge it, and enqueue the new neighbours.
  while !heap.is_empty() {
    let m = match heap.pop() {
      Some(x) => x
      None => break
    }
    let pos = m.pos
    // Skip stale entries. After merges, a symbol's value can change while its
    // links stay the same, so we must re-validate the *current* pair: the left
    // symbol is alive, still points at the recorded right neighbour, and the
    // pair still has exactly the rank recorded when this entry was pushed.
    if !symbols[pos].alive || symbols[pos].next != m.right {
      continue
    }
    let cur_rank = self.merges.get((symbols[pos].value, symbols[m.right].value))
    match cur_rank {
      Some(r) => if r != m.rank { continue }
      None => continue
    }
    let nx = m.right
    // Merge symbols[nx] into symbols[pos].
    symbols[pos].value = symbols[pos].value + symbols[nx].value
    symbols[pos].next = symbols[nx].next
    symbols[nx].alive = false
    if symbols[nx].next >= 0 {
      symbols[symbols[nx].next].prev = pos
    }
    // The pair (prev,pos) and (pos,next) may now be mergeable.
    try_push(symbols[pos].prev)
    try_push(pos)
  }

  // Collect surviving symbols, mapping each to an id (or the unk token).
  let rel = self.collect_tokens(symbols, chars, 0)
  self.cache[word] = rel
  shift_tokens(rel, offset)
}

///|
fn shift_tokens(
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

// Walk the linked list from the head and emit tokens.

///|
fn BPEModel::collect_tokens(
  self : BPEModel,
  symbols : Array[Symbol],
  chars : Array[Char],
  offset : Int,
) -> Array[@types.Token] {
  let raw : Array[@types.Token] = []
  let mut idx = 0
  // find head
  for i in 0..<symbols.length() {
    if symbols[i].alive && symbols[i].prev < 0 {
      idx = i
      break
    }
  }
  let mut char_pos = 0
  while idx >= 0 {
    let sym = symbols[idx]
    let span = symbol_char_span(symbols, idx, chars.length())
    let start = offset + char_pos
    let stop = offset + char_pos + span
    match self.lookup(sym.value) {
      Some(id) =>
        raw.push(@types.Token::{ id, value: sym.value, offsets: (start, stop) })
      None => {
        // Try byte_fallback: encode the surface's bytes as <0xXX> tokens, but
        // only if every byte token exists in the vocab (HF semantics).
        let surface = make_surface(chars, char_pos, char_pos + span)
        let fb = if self.byte_fallback {
          self.try_byte_fallback(surface, start, stop)
        } else {
          None
        }
        match fb {
          Some(toks) =>
            for t in toks {
              raw.push(t)
            }
          None =>
            // unk fallback
            match self.unk_token {
              Some(unk) =>
                match self.vocab.get(unk) {
                  Some(uid) =>
                    raw.push(@types.Token::{
                      id: uid,
                      value: unk,
                      offsets: (start, stop),
                    })
                  None =>
                    raw.push(@types.Token::{
                      id: -1,
                      value: surface,
                      offsets: (start, stop),
                    })
                }
              None =>
                raw.push(@types.Token::{
                  id: -1,
                  value: sym.value,
                  offsets: (start, stop),
                })
            }
        }
      }
    }
    char_pos = char_pos + span
    idx = sym.next
  }
  // fuse_unk: merge adjacent unk tokens into one.
  if self.fuse_unk {
    fuse_unk_tokens(raw, self.unk_id())
  } else {
    raw
  }
}

// The vocab id of the unk token, if any.

///|
fn BPEModel::unk_id(self : BPEModel) -> Int? {
  match self.unk_token {
    Some(unk) => self.vocab.get(unk)
    None => None
  }
}

// Try to represent `surface` as a sequence of <0xXX> byte tokens (uppercase,
// two hex digits). Returns None if any byte token is missing from the vocab.

///|
fn BPEModel::try_byte_fallback(
  self : BPEModel,
  surface : String,
  start : Int,
  stop : Int,
) -> Array[@types.Token]? {
  let bytes = @utf8.encode(surface)
  let toks : Array[@types.Token] = []
  for i in 0..<bytes.length() {
    let tok = byte_hex_token(bytes[i].to_int())
    match self.vocab.get(tok) {
      Some(id) =>
        toks.push(@types.Token::{ id, value: tok, offsets: (start, stop) })
      None => return None
    }
  }
  Some(toks)
}

// "<0xE2>" style token: uppercase, fixed two hex digits.

///|
fn byte_hex_token(b : Int) -> String {
  let digits = "0123456789ABCDEF"
  let hi = digits.to_array()[b / 16]
  let lo = digits.to_array()[b % 16]
  let sb = StringBuilder::new()
  sb.write_string("<0x")
  sb.write_char(hi)
  sb.write_char(lo)
  sb.write_char('>')
  sb.to_string()
}

// Merge runs of adjacent unk tokens (id == unk_id) into a single token whose
// value is the concatenation and whose offsets span the run.

///|
fn fuse_unk_tokens(
  toks : Array[@types.Token],
  unk : Int?,
) -> Array[@types.Token] {
  match unk {
    None => return toks
    Some(_) => ()
  }
  let unk_id = unk.unwrap()
  let out : Array[@types.Token] = []
  for t in toks {
    if t.id == unk_id && out.length() > 0 && out[out.length() - 1].id == unk_id {
      let prev = out[out.length() - 1]
      out[out.length() - 1] = @types.Token::{
        id: unk_id,
        value: prev.value + t.value,
        offsets: (prev.offsets.0, t.offsets.1),
      }
    } else {
      out.push(t)
    }
  }
  out
}

// Count code points covered by the symbol at `idx`, by measuring the gap to the
// next alive node (in original char index space).

///|
fn symbol_char_span(symbols : Array[Symbol], idx : Int, total : Int) -> Int {
  // The initial symbol array index equals the starting char index, and merges
  // keep `next` pointing at the next start. So span = next_index - idx, or
  // total - idx for the last symbol.
  let nx = symbols[idx].next
  if nx >= 0 {
    nx - idx
  } else {
    total - idx
  }
}

///|
fn make_surface(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn BPEModel::lookup(self : BPEModel, value : String) -> Int? {
  self.vocab.get(value)
}

// Build a one-character String.

///|
fn char_str(c : Char) -> String {
  let sb = StringBuilder::new()
  sb.write_char(c)
  sb.to_string()
}
