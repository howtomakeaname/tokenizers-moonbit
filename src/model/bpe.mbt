// BPE tokenization: rank-based merging.
//
// A word (one pre-token) is split into initial symbols (one per code point,
// optionally with continuing-subword-prefix / end-of-word-suffix applied), then
// adjacent pairs are merged in order of merge rank (lowest first) until no
// known merge remains. Each surviving symbol is mapped to its vocab id.

// A symbol in the working sequence, modeled as a node in a doubly linked list
// over an array (so merges are O(1) splices).
priv struct Symbol {
  mut value : String
  mut prev : Int
  mut next : Int
  mut alive : Bool
}

/// Tokenize a single word with this BPE model.
/// `offset` is the char offset of `word` within the original text.
pub fn BPEModel::tokenize(
  self : BPEModel,
  word : String,
  offset~ : Int = 0,
) -> Array[@types.Token] {
  let chars = word.to_array()
  let n = chars.length()
  if n == 0 {
    return []
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

  // Repeatedly merge the adjacent pair with the smallest rank.
  while true {
    let mut best_rank = @int.max_value
    let mut best = -1
    let mut i = 0
    while i >= 0 && i < symbols.length() {
      let nx = symbols[i].next
      if nx >= 0 {
        match self.merges.get((symbols[i].value, symbols[nx].value)) {
          Some(r) =>
            if r < best_rank {
              best_rank = r
              best = i
            }
          None => ()
        }
      }
      i = nx
    }
    if best < 0 {
      break
    }
    // Merge symbols[best] with its successor.
    let nx = symbols[best].next
    symbols[best].value = symbols[best].value + symbols[nx].value
    symbols[best].next = symbols[nx].next
    symbols[nx].alive = false
    if symbols[nx].next >= 0 {
      symbols[symbols[nx].next].prev = best
    }
  }

  // Collect surviving symbols, mapping each to an id (or the unk token).
  self.collect_tokens(symbols, chars, offset)
}

// Walk the linked list from the head and emit tokens.
fn BPEModel::collect_tokens(
  self : BPEModel,
  symbols : Array[Symbol],
  chars : Array[Char],
  offset : Int,
) -> Array[@types.Token] {
  let out : Array[@types.Token] = []
  // Track char offsets by counting code points consumed per surviving symbol.
  // The stored symbol values may carry prefix/suffix, so we recompute spans by
  // walking lengths of the original chars covered. Simpler: track via a cursor
  // over the linked list using each symbol's covered char count.
  // We recompute char spans from the surviving order using char counts.
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
    // Number of original code points this symbol covers = (next start - start).
    // We derive it from the contiguous chars; since merges only join adjacent
    // symbols, covered length equals the span between this node and the next.
    let span = symbol_char_span(symbols, idx, chars.length())
    let surface = make_surface(chars, char_pos, char_pos + span)
    let token = match self.lookup(sym.value) {
      Some(id) => @types.Token::{ id, value: sym.value, offsets: (offset + char_pos, offset + char_pos + span) }
      None =>
        match self.unk_token {
          Some(unk) =>
            match self.vocab.get(unk) {
              Some(uid) =>
                @types.Token::{ id: uid, value: unk, offsets: (offset + char_pos, offset + char_pos + span) }
              None =>
                @types.Token::{ id: -1, value: surface, offsets: (offset + char_pos, offset + char_pos + span) }
            }
          None =>
            @types.Token::{ id: -1, value: sym.value, offsets: (offset + char_pos, offset + char_pos + span) }
        }
    }
    out.push(token)
    char_pos = char_pos + span
    idx = sym.next
  }
  out
}

// Count code points covered by the symbol at `idx`, by measuring the gap to the
// next alive node (in original char index space).
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

fn make_surface(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

fn BPEModel::lookup(self : BPEModel, value : String) -> Int? {
  self.vocab.get(value)
}

// Build a one-character String.
fn char_str(c : Char) -> String {
  let sb = StringBuilder::new()
  sb.write_char(c)
  sb.to_string()
}
