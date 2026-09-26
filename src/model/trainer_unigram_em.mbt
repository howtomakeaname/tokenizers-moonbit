// Real Unigram EM trainer — behavioral port of hf-tokenizers 0.22.2
// `models/unigram/trainer.rs` (+ esaxx-rs 0.1.10 `suffix_rs`, the pure-Rust
// SA-IS + enhanced-suffix-array enumeration). Reference sources read from the
// local checkout (trainer.rs is byte-identical between v0.22.2 and main;
// lattice.rs/model.rs diffs are outside the training path used here).
//
// Pipeline (identical to HF):
//   1. seed pieces = all chars (count desc, char desc) + frequent substrings
//      from the enhanced suffix array of the '\0'-joined distinct words
//      (score = freq*len desc, string desc; no '\0'; len <= max_piece_length;
//      capped at seed_size) — then to_log_prob.
//   2. EM: n_sub_iterations E/M rounds per outer loop (forward-backward
//      marginals; M keeps pieces with expected >= 0.5 and applies the
//      Bayesianified digamma prior), pruning by shrinking_factor until the
//      vocab reaches vocab_size*1.1 (prune computes per-piece removal loss
//      from 2-best segmentations).
//   3. finalize: required chars pinned (min_score+penalty ladder), pieces by
//      score desc capped at vocab_size minus specials, specials first.
//
// HF itself is order-nondeterministic across processes (AHashMap iteration
// feeding float sums flips near-ties); the vocab SET is deterministic. Our
// port is fully deterministic; parity target = vocab-set equality.

///|
/// log(exp(x) + exp(y)); init_mode returns y directly (the 0.0 sentinel in
/// the alpha/beta arrays must not pollute the first accumulation).
fn em_log_sum_exp(x : Double, y : Double, init_mode : Bool) -> Double {
  if init_mode {
    y
  } else {
    let vmin = if x > y { y } else { x }
    let vmax = if x > y { x } else { y }
    let k_minus_log_epsilon = 50.0
    if vmax > vmin + k_minus_log_epsilon {
      vmax
    } else {
      vmax + @math.ln(@math.exp(vmin - vmax) + 1.0)
    }
  }
}

///|
/// digamma as in trainer.rs (asymptotic series after shifting x >= 7).
fn em_digamma(x_in : Double) -> Double {
  let mut x = x_in
  let mut result = 0.0
  while x < 7.0 {
    result -= 1.0 / x
    x += 1.0
  }
  x -= 1.0 / 2.0
  let xx = 1.0 / x
  let xx2 = xx * xx
  let xx4 = xx2 * xx2
  result +
  @math.ln(x) +
  1.0 / 24.0 * xx2 -
  7.0 / 960.0 * xx4 +
  31.0 / 8064.0 * xx4 * xx2 -
  127.0 / 30720.0 * xx4 * xx4
}

///|
/// Suffix array via prefix doubling (O(n log n) comparisons; the
/// corpus for seed generation is the distinct-word flat string).
fn doubling_suffix_array(chars : Array[Int]) -> Array[Int] {
  let n = chars.length()
  let sa : Array[Int] = []
  let rank : Array[Int] = []
  let mut i = 0
  while i < n {
    sa.push(i)
    rank.push(chars[i])
    i += 1
  }
  let tmp : Array[Int] = []
  let mut i = 0
  while i < n {
    tmp.push(0)
    i += 1
  }
  let mut k = 1
  let cmp = fn(a : Int, b : Int) -> Int {
    if rank[a] != rank[b] {
      if rank[a] < rank[b] {
        -1
      } else {
        1
      }
    } else {
      let ra = if a + k < n { rank[a + k] } else { -1 }
      let rb = if b + k < n { rank[b + k] } else { -1 }
      if ra < rb {
        -1
      } else if ra > rb {
        1
      } else {
        0
      }
    }
  }
  let cmp_fn = fn(a : Int, b : Int) -> Int { cmp(a, b) }
  while k < n {
    sa.sort_by(fn(a, b) { cmp_fn(a, b) })
    // recompute ranks
    tmp[sa[0]] = 0
    let mut r = 0
    let mut i = 1
    while i < n {
      if cmp(sa[i - 1], sa[i]) != 0 {
        r += 1
      }
      tmp[sa[i]] = r
      i += 1
    }
    let mut i = 0
    while i < n {
      rank[i] = tmp[i]
      i += 1
    }
    if r == n - 1 {
      break
    }
    k = k * 2
  }
  sa
}

///|
/// Kasai LCP: h[i] = LCP(suffix sa[i-1], suffix sa[i]); h[0] = 0.
fn kasai_lcp(chars : Array[Int], sa : Array[Int]) -> Array[Int] {
  let n = chars.length()
  let h : Array[Int] = []
  let inv : Array[Int] = []
  let mut i = 0
  while i < n {
    h.push(0)
    inv.push(0)
    i += 1
  }
  let mut i = 0
  while i < n {
    inv[sa[i]] = i
    i += 1
  }
  let mut hh = 0
  let mut i = 0
  while i < n {
    if inv[i] > 0 {
      let j = sa[inv[i] - 1]
      while i + hh < n && j + hh < n && chars[i + hh] == chars[j + hh] {
        hh += 1
      }
      h[inv[i]] = hh
      if hh > 0 {
        hh -= 1
      }
    } else {
      hh = 0
    }
    i += 1
  }
  h
}

///|
/// One substring record from the enhanced suffix array tree enumeration.
priv struct EsaNode {
  offset : Int // start position of the substring
  len : Int // substring length
  freq : Int // number of occurrences (suffix interval size)
}

///|
/// Enhanced suffix array enumeration (esaxx-rs suffixtree walk over
/// SA + LCP): yields internal-node substrings in the Rust order.
fn esa_nodes(chars : Array[Int]) -> Array[EsaNode] {
  let n = chars.length()
  if n == 0 {
    return []
  }
  let sa = doubling_suffix_array(chars)
  let lcp = kasai_lcp(chars, sa)
  let out : Array[EsaNode] = []
  // stack of (left_boundary, lcp_depth); walk matches esaxx-rs
  let stack_l : Array[Int] = [-1]
  let stack_d : Array[Int] = [-1]
  let mut node_count = 0
  let mut i = 0
  let mut done = false
  while !done {
    let cur_d = if i == n { -1 } else { lcp[i] }
    let mut cur_l = i
    while stack_d[stack_d.length() - 1] > cur_d {
      let d = stack_d[stack_d.length() - 1]
      let l = stack_l[stack_l.length() - 1]
      if i - l > 1 {
        out.push({ offset: sa[l], len: d, freq: i - l, })
        node_count += 1
        if node_count >= n {
          break
        }
      }
      cur_l = l
      ignore(stack_l.pop())
      ignore(stack_d.pop())
    }
    if stack_d[stack_d.length() - 1] < cur_d {
      stack_l.push(cur_l)
      stack_d.push(cur_d)
    }
    if i == n {
      done = true
    } else {
      stack_l.push(i)
      stack_d.push(n - sa[i] + 1)
      i += 1
    }
  }
  out
}

///|
priv struct EmPiece {
  token : String
  score : Double
}

///|
/// Training lattice over char positions: nodes carry piece ids; built per
/// word on demand (the corpus loop reuses the arrays).
priv struct EmLattice {
  word : Array[Char]
  // flat node storage: id, pos, len, score; index 0 = bos, 1 = eos
  ids : Array[Int]
  poss : Array[Int]
  lens : Array[Int]
  scores : Array[Double]
  begin_nodes : Array[Array[Int]] // per position: node indices
  end_nodes : Array[Array[Int]]
  // viterbi backtrace
  bt1 : Array[Double]
  bt1_prev : Array[Int]
  bt2 : Array[Double]
  bt2_prev : Array[Int]
  // marginal
  alpha : Array[Double]
  beta : Array[Double]
  // k-best validity: node has a DISTINCT second-best path
  has2 : Array[Bool]
}

///|
fn em_lattice_new(word : Array[Char], bos_id : Int, eos_id : Int) -> EmLattice {
  let n = word.length()
  let begin : Array[Array[Int]] = []
  let end : Array[Array[Int]] = []
  let mut i = 0
  while i < n + 1 {
    begin.push([])
    end.push([])
    i += 1
  }
  begin[n].push(1) // eos at end
  end[0].push(0) // bos at start
  let lat = {
    word,
    ids: [bos_id, eos_id],
    poss: [0, n],
    lens: [0, 0],
    scores: [0.0, 0.0],
    begin_nodes: begin,
    end_nodes: end,
    bt1: [0.0, 0.0],
    bt1_prev: [-1, -1],
    bt2: [0.0, 0.0],
    bt2_prev: [-1, -1],
    alpha: [],
    beta: [],
    has2: [false, false],
  }
  lat
}

///|
fn em_lattice_insert(
  lat : EmLattice,
  pos : Int,
  len : Int,
  score : Double,
  id : Int,
) -> Unit {
  let idx = lat.ids.length()
  lat.ids.push(id)
  lat.poss.push(pos)
  lat.lens.push(len)
  lat.scores.push(score)
  lat.bt1.push(0.0)
  lat.bt1_prev.push(-1)
  lat.bt2.push(0.0)
  lat.bt2_prev.push(-1)
  lat.has2.push(false)
  lat.begin_nodes[pos].push(idx)
  lat.end_nodes[pos + len].push(idx)
}

///|
/// populate_nodes: trie common-prefix search == try every piece length
/// 1..=max_len at each position; unk inserted when no single-char node.
fn em_populate_nodes(
  lat : EmLattice,
  piece_ids : Map[String, Int],
  piece_scores : Array[Double],
  unk_id : Int?,
  unk_score : Double,
  max_len : Int,
) -> Unit {
  let n = lat.word.length()
  let mut pos = 0
  while pos < n {
    let mut has_single = false
    let mut len = 1
    let limit = if max_len < n - pos { max_len } else { n - pos }
    while len <= limit {
      let sb = StringBuilder()
      let mut k = pos
      while k < pos + len {
        sb.write_char(lat.word[k])
        k += 1
      }
      let key = sb.to_string()
      match piece_ids.get(key) {
        Some(id) => {
          em_lattice_insert(lat, pos, len, piece_scores[id], id)
          if !has_single && len == 1 {
            has_single = true
          }
        }
        None => ()
      }
      len += 1
    }
    if !has_single {
      match unk_id {
        Some(uid) => em_lattice_insert(lat, pos, 1, unk_score, uid)
        None => ()
      }
    }
    pos += 1
  }
}

///|
/// Viterbi best path (Rust: strict > keeps the first best on ties).
fn em_viterbi(lat : EmLattice) -> Array[Int]? {
  let n = lat.word.length()
  let mut pos = 0
  while pos <= n {
    if lat.begin_nodes[pos].length() == 0 {
      return None
    }
    for rnode in lat.begin_nodes[pos] {
      lat.bt1_prev[rnode] = -1
      let mut best : Double? = None
      let mut best_prev = -1
      for lnode in lat.end_nodes[pos] {
        let score = lat.bt1[lnode] + lat.scores[rnode]
        match best {
          Some(b) =>
            if score > b {
              best = Some(score)
              best_prev = lnode
            }
          None => {
            best = Some(score)
            best_prev = lnode
          }
        }
      }
      match best {
        Some(_) => {
          lat.bt1[rnode] = best.unwrap_or(0.0)
          lat.bt1_prev[rnode] = best_prev
        }
        None => return None
      }
    }
    pos += 1
  }
  let eos = lat.begin_nodes[n][0]
  if lat.bt1_prev[eos] == -1 {
    return None
  }
  let path : Array[Int] = []
  let mut node = lat.bt1_prev[eos]
  while node != -1 && lat.bt1_prev[node] != -1 {
    path.push(node)
    node = lat.bt1_prev[node]
  }
  // reverse
  let out : Array[Int] = []
  let mut i = path.length() - 1
  while i >= 0 {
    out.push(path[i])
    i -= 1
  }
  Some(out)
}

///|
/// 2-best Viterbi (used by prune as nbest(2)); returns up to two paths,
/// best first. Candidates per node: both slots of every predecessor.
fn em_nbest2(lat : EmLattice) -> Array[Array[Int]] {
  let n = lat.word.length()
  let mut pos = 0
  while pos <= n {
    if lat.begin_nodes[pos].length() == 0 {
      return []
    }
    for rnode in lat.begin_nodes[pos] {
      // gather candidates: (score, prev, slot)
      let c_score : Array[Double] = []
      let c_prev : Array[Int] = []
      for lnode in lat.end_nodes[pos] {
        c_score.push(lat.bt1[lnode] + lat.scores[rnode])
        c_prev.push(lnode)
        if lat.has2[lnode] {
          c_score.push(lat.bt2[lnode] + lat.scores[rnode])
          c_prev.push(lnode)
        }
      }
      // top-2 selection (stable: first encountered wins ties)
      let mut b0 = -1
      let mut b1 = -1
      let mut i = 0
      while i < c_score.length() {
        if b0 < 0 || c_score[i] > c_score[b0] {
          b1 = b0
          b0 = i
        } else if b1 < 0 || c_score[i] > c_score[b1] {
          b1 = i
        }
        i += 1
      }
      lat.bt1[rnode] = if b0 >= 0 { c_score[b0] } else { 0.0 }
      lat.bt1_prev[rnode] = if b0 >= 0 { c_prev[b0] } else { -1 }
      if b1 >= 0 && b1 != b0 {
        lat.bt2[rnode] = c_score[b1]
        lat.bt2_prev[rnode] = c_prev[b1]
        lat.has2[rnode] = true
      } else {
        lat.bt2[rnode] = 0.0
        lat.bt2_prev[rnode] = -1
        lat.has2[rnode] = false
      }
    }
    pos += 1
  }
  let eos = lat.begin_nodes[n][0]
  if lat.bt1_prev[eos] == -1 {
    return []
  }
  let results : Array[Array[Int]] = []
  let mut slot = 0
  while slot < 2 {
    let prev_arr = if slot == 0 { lat.bt1_prev } else { lat.bt2_prev }
    if slot == 1 && !lat.has2[eos] {
      break
    }
    let path : Array[Int] = []
    // mixed-slot walk: follow eos's slot link, then best links below
    // (the second-best path deviates from best at one edge chain)
    let mut node = prev_arr[eos]
    while node != -1 && lat.bt1_prev[node] != -1 {
      path.push(node)
      node = lat.bt1_prev[node]
    }
    let out : Array[Int] = []
    let mut i = path.length() - 1
    while i >= 0 {
      out.push(path[i])
      i -= 1
    }
    results.push(out)
    slot += 1
  }
  results
}

///|
/// Forward-backward marginals (lattice.populate_marginal): adds freq-weighted
/// expected counts per piece id; returns freq * log Z.
fn em_populate_marginal(
  lat : EmLattice,
  freq : Double,
  expected : Array[Double],
) -> Double {
  let n = lat.word.length()
  let nn = lat.ids.length()
  if lat.alpha.length() != nn {
    // reset scratch
    lat.alpha.clear()
    lat.beta.clear()
    let mut i = 0
    while i < nn {
      lat.alpha.push(0.0)
      lat.beta.push(0.0)
      i += 1
    }
  } else {
    let mut i = 0
    while i < nn {
      lat.alpha[i] = 0.0
      lat.beta[i] = 0.0
      i += 1
    }
  }
  let mut pos = 0
  while pos <= n {
    for rnode in lat.begin_nodes[pos] {
      let first_lnode = lat.end_nodes[pos][0]
      for lnode in lat.end_nodes[pos] {
        lat.alpha[rnode] = em_log_sum_exp(
          lat.alpha[rnode],
          lat.scores[lnode] + lat.alpha[lnode],
          lnode == first_lnode,
        )
      }
    }
    pos += 1
  }
  let mut pos = n
  while pos >= 0 {
    for lnode in lat.end_nodes[pos] {
      let first_rnode = lat.begin_nodes[pos][0]
      for rnode in lat.begin_nodes[pos] {
        lat.beta[lnode] = em_log_sum_exp(
          lat.beta[lnode],
          lat.scores[rnode] + lat.beta[rnode],
          rnode == first_rnode,
        )
      }
    }
    if pos == 0 {
      break
    }
    pos -= 1
  }
  let eos = lat.begin_nodes[n][0]
  let z = lat.alpha[eos]
  let mut pos = 0
  while pos < n {
    for node in lat.begin_nodes[pos] {
      let total = lat.alpha[node] + lat.scores[node] + lat.beta[node] - z
      expected[lat.ids[node]] += freq * @math.exp(total)
    }
    pos += 1
  }
  freq * z
}

///|
/// make_seed_sentence_pieces: chars (count desc, char desc) then ESA
/// substrings (freq*len desc, string desc), capped at seed_size; to_log_prob.
fn em_seed_pieces(
  word_order : Array[String],
  word_counts : Map[String, Int],
  max_piece_length : Int,
  seed_size : Int,
) -> Array[EmPiece] {
  // flat string of '\0'-joined distinct words + char counts weighted by freq
  let flat : Array[Int] = []
  let char_counts : Map[Int, Int] = Map([])
  let char_list : Array[Int] = []
  for word in word_order {
    let n = word_counts.get(word).unwrap_or(0)
    let wcs = word.to_array()
    for c in wcs {
      flat.push(c.to_int())
      if c != '\u{0}' {
        match char_counts.get(c.to_int()) {
          Some(v) => char_counts[c.to_int()] = v + n
          None => {
            char_counts[c.to_int()] = n
            char_list.push(c.to_int())
          }
        }
      }
    }
    flat.push(0)
  }
  let pieces : Array[EmPiece] = []
  // chars: Reverse((count, char)) — count desc, char code desc on ties
  let char_items : Array[(Int, Int)] = []
  for cp in char_list {
    char_items.push((char_counts.get(cp).unwrap_or(0), cp))
  }
  char_items.sort_by(fn(a, b) {
    if a.0 != b.0 {
      if a.0 > b.0 {
        -1
      } else {
        1
      }
    } else if a.1 != b.1 {
      if a.1 > b.1 {
        -1
      } else {
        1
      }
    } else {
      0
    }
  })
  for item in char_items {
    pieces.push({
      token: char_string(item.1.unsafe_to_char()),
      score: item.0.to_double(),
    })
  }
  // substrings from the ESA tree
  let nodes = esa_nodes(flat)
  let subs : Array[(Int, String)] = []
  for node in nodes {
    if node.len <= 1 {
      continue
    }
    if node.len > max_piece_length {
      continue
    }
    let contains_nul = {
      let mut bad = false
      let mut k = node.offset
      while k < node.offset + node.len {
        if flat[k] == 0 {
          bad = true
          break
        }
        k += 1
      }
      bad
    }
    if contains_nul {
      continue
    }
    let sb = StringBuilder()
    let mut k = node.offset
    while k < node.offset + node.len {
      sb.write_char(flat[k].unsafe_to_char())
      k += 1
    }
    subs.push((node.freq * node.len, sb.to_string()))
  }
  // Reverse((score, string)): score desc, string desc on ties
  subs.sort_by(fn(a, b) {
    if a.0 != b.0 {
      if a.0 > b.0 {
        -1
      } else {
        1
      }
    } else if a.1 > b.1 {
      -1
    } else if a.1 < b.1 {
      1
    } else {
      0
    }
  })
  for sub in subs {
    if pieces.length() >= seed_size {
      break
    }
    pieces.push({ token: sub.1, score: sub.0.to_double(), })
  }
  // to_log_prob
  let mut sum = 0.0
  for p in pieces {
    sum += p.score
  }
  let logsum = @math.ln(sum)
  let mut i = 0
  while i < pieces.length() {
    pieces[i] = {
      token: pieces[i].token,
      score: @math.ln(pieces[i].score) - logsum,
    }
    i += 1
  }
  pieces
}

///|
/// E-step: expected piece counts over distinct words (deterministic order).
fn em_e_step(
  word_order : Array[String],
  word_counts : Map[String, Int],
  piece_ids : Map[String, Int],
  piece_scores : Array[Double],
  min_score : Double,
  unk_id : Int,
  max_piece_length : Int,
) -> Array[Double] {
  let expected : Array[Double] = []
  let mut i = 0
  while i < piece_scores.length() {
    expected.push(0.0)
    i += 1
  }
  let unk_score = min_score - 10.0
  for word in word_order {
    let freq = word_counts.get(word).unwrap_or(0).to_double()
    let lat = em_lattice_new(
      word.to_array(),
      piece_scores.length() + 1,
      piece_scores.length() + 2,
    )
    em_populate_nodes(
      lat,
      piece_ids,
      piece_scores,
      Some(unk_id),
      unk_score,
      max_piece_length,
    )
    ignore(em_populate_marginal(lat, freq, expected))
  }
  expected
}

///|
/// M-step: keep expected >= 0.5, digamma sparse prior; unk stays NaN.
fn em_m_step(
  pieces : Array[EmPiece],
  expected : Array[Double],
) -> Array[EmPiece] {
  let out : Array[EmPiece] = []
  let mut sum = 0.0
  let mut i = 0
  while i < pieces.length() {
    if i == 0 {
      out.push({ token: pieces[i].token, score: 0.0 / 0.0, })
      i += 1
      continue
    }
    if expected[i] < 0.5 {
      i += 1
      continue
    }
    out.push({ token: pieces[i].token, score: expected[i], })
    sum += expected[i]
    i += 1
  }
  let logsum = em_digamma(sum)
  let mut i = 0
  while i < out.length() {
    if !out[i].score.is_nan() {
      out[i] = {
        token: out[i].token,
        score: em_digamma(out[i].score) - logsum,
      }
    }
    i += 1
  }
  out
}

///|
/// prune_sentence_pieces: removal-loss ranking from 2-best segmentations.
fn em_prune_pieces(
  pieces : Array[EmPiece],
  word_order : Array[String],
  word_counts : Map[String, Int],
  vocab_size : Int,
  shrinking_factor : Double,
  max_piece_length : Int,
) -> Array[EmPiece] {
  let npieces = pieces.length()
  let bos_id = npieces + 1
  let eos_id = npieces + 2
  let piece_ids : Map[String, Int] = Map([])
  let piece_scores : Array[Double] = []
  let mut i = 0
  while i < npieces {
    piece_ids[pieces[i].token] = i
    piece_scores.push(pieces[i].score)
    i += 1
  }
  let mut min_score = 1.0 / 0.0
  let mut i = 0
  while i < npieces {
    if pieces[i].score < min_score {
      min_score = pieces[i].score
    }
    i += 1
  }
  let unk_score = min_score - 10.0
  let always_keep : Array[Bool] = []
  let alternatives : Array[Array[Int]] = []
  let mut i = 0
  while i < npieces {
    always_keep.push(true)
    alternatives.push([])
    i += 1
  }
  // 1) 2-best segmentation of each piece
  let mut id = 0
  while id < npieces {
    if id == 0 {
      always_keep[id] = false
      id += 1
      continue
    }
    let lat = em_lattice_new(pieces[id].token.to_array(), bos_id, eos_id)
    em_populate_nodes(
      lat,
      piece_ids,
      piece_scores,
      Some(0),
      unk_score,
      max_piece_length,
    )
    let nbests = em_nbest2(lat)
    if nbests.length() == 1 {
      always_keep[id] = true
    } else if nbests[0].length() >= 2 {
      always_keep[id] = false
    } else {
      always_keep[id] = true
      for node in nbests[1] {
        alternatives[id].push(lat.ids[node])
      }
    }
    id += 1
  }
  // 2) viterbi frequencies over the words + inverted sentence lists
  let freq : Array[Double] = []
  let inverted : Array[Array[Int]] = []
  let mut i = 0
  while i < npieces {
    freq.push(0.0)
    inverted.push([])
    i += 1
  }
  let mut vsum = 0.0
  let mut si = 0
  while si < word_order.length() {
    let word = word_order[si]
    let count = word_counts.get(word).unwrap_or(0).to_double()
    let lat = em_lattice_new(word.to_array(), bos_id, eos_id)
    em_populate_nodes(
      lat,
      piece_ids,
      piece_scores,
      Some(0),
      unk_score,
      max_piece_length,
    )
    vsum += count
    match em_viterbi(lat) {
      Some(path) =>
        for node in path {
          freq[lat.ids[node]] += count
          inverted[lat.ids[node]].push(si)
        }
      None => ()
    }
    si += 1
  }
  // 3) loss ranking
  let mut sum = 0.0
  let mut i = 0
  while i < npieces {
    sum += freq[i]
    i += 1
  }
  let logsum = @math.ln(sum)
  let new_pieces : Array[EmPiece] = [
    { token: pieces[0].token, score: pieces[0].score, },
  ]
  let candidates : Array[(Int, Double)] = []
  let mut id = 1
  while id < npieces {
    let token = pieces[id].token
    let score = pieces[id].score
    if freq[id] == 0.0 && !always_keep[id] {
      id += 1
      continue
    } else if alternatives[id].length() == 0 {
      new_pieces.push({ token, score, })
    } else {
      let mut f = 0.0
      for n in inverted[id] {
        f += word_counts.get(word_order[n]).unwrap_or(0).to_double()
      }
      if f == 0.0 || f.is_nan() {
        id += 1
        continue
      }
      f /= vsum
      let logprob_sp = @math.ln(freq[id]) - logsum
      let logsum_alt = @math.ln(
        sum + freq[id] * (alternatives[id].length() - 1).to_double(),
      )
      let mut logprob_alt = 0.0
      for n in alternatives[id] {
        logprob_alt += @math.ln(freq[n] + freq[id]) - logsum_alt
      }
      let loss = f * (logprob_sp - logprob_alt)
      candidates.push((id, loss))
    }
    id += 1
  }
  let desired = vocab_size * 11 / 10
  let pruned = em_double_to_int(npieces.to_double() * shrinking_factor)
  let pruned_size = if desired > pruned { desired } else { pruned }
  // loss desc, stable
  candidates.sort_by(fn(a, b) {
    if a.1 > b.1 {
      -1
    } else if a.1 < b.1 {
      1
    } else {
      0
    }
  })
  for cand in candidates {
    if new_pieces.length() == pruned_size {
      break
    }
    new_pieces.push({
      token: pieces[cand.0].token,
      score: pieces[cand.0].score,
    })
  }
  new_pieces
}

///|
/// finalize: required chars pinned, model pieces capped, sorted by score.
fn em_finalize(
  pieces : Array[EmPiece],
  required_chars : Array[String],
  vocab_size : Int?,
  special_tokens : Array[String],
  unk_token : String?,
) -> (Array[EmPiece], Int?) {
  let min_score_penalty_delta = 0.0001
  let mut min_score_penalty = 0.0
  let out : Array[EmPiece] = []
  let inserted : Map[String, Bool] = Map([])
  inserted["<UNK>"] = true
  // model min_score
  let mut min_score = 1.0 / 0.0
  let mut i = 0
  while i < pieces.length() {
    if pieces[i].score < min_score {
      min_score = pieces[i].score
    }
    i += 1
  }
  let existing : Map[String, Double] = Map([])
  for p in pieces {
    existing[p.token] = p.score
  }
  for c in required_chars {
    match existing.get(c) {
      Some(t) => {
        inserted[c] = true
        out.push({ token: c, score: t, })
      }
      None => {
        let score = min_score + min_score_penalty
        inserted[c] = true
        out.push({ token: c, score, })
        min_score_penalty += min_score_penalty_delta
      }
    }
  }
  // unk placement
  let (unk_id, need_add_unk) : (Int?, Bool) = match unk_token {
    Some(unk) => {
      let mut found : Int? = None
      let mut i = 0
      while i < special_tokens.length() {
        if special_tokens[i] == unk {
          found = Some(i)
          break
        }
        i += 1
      }
      match found {
        Some(id) => (Some(id), false)
        None => (Some(0), true)
      }
    }
    None => (None, false)
  }
  let cap = match vocab_size {
    Some(vs) => {
      let base = vs - special_tokens.length()
      if need_add_unk {
        base - 1
      } else {
        base
      }
    }
    None => out.length() + pieces.length() + special_tokens.length()
  }
  for p in pieces {
    if inserted.get(p.token) is Some(true) {
      continue
    }
    inserted[p.token] = true
    out.push({
      token: p.token,
      score: if p.score.is_nan() {
        0.0
      } else {
        p.score
      },
    })
    if out.length() == cap {
      break
    }
  }
  // score desc, stable (Rust partial_cmp unwrap; NaN cannot occur here)
  out.sort_by(fn(a, b) {
    if a.score > b.score {
      -1
    } else if a.score < b.score {
      1
    } else {
      0
    }
  })
  // specials first
  let final_pieces : Array[EmPiece] = []
  if need_add_unk {
    final_pieces.push({ token: unk_token.unwrap_or("<unk>"), score: 0.0, })
  }
  for tok in special_tokens {
    final_pieces.push({ token: tok, score: 0.0, })
  }
  for p in out {
    final_pieces.push(p)
  }
  (final_pieces, unk_id)
}

///|
/// The full do_train pipeline over counted words.
fn unigram_do_train(
  word_order : Array[String],
  word_counts : Map[String, Int],
  vocab_size : Int?,
  shrinking_factor : Double,
  n_sub_iterations : Int,
  max_piece_length : Int,
  seed_size : Int,
  special_tokens : Array[String],
  unk_token : String?,
  initial_alphabet : Array[String],
) -> (Array[EmPiece], Int?) {
  // seed
  let mut pieces : Array[EmPiece] = [{ token: "<UNK>", score: 0.0 / 0.0, }]
  let seed = em_seed_pieces(
    word_order, word_counts, max_piece_length, seed_size,
  )
  for p in seed {
    pieces.push(p)
  }
  // HF prunes relative to vocab_size; when unlimited use the seed size
  let eff_vocab_size = match vocab_size {
    Some(vs) => vs
    None => pieces.length()
  }
  // DIVERGENCE (documented, round-1 review): Rust errors when
  // required_chars exceeds vocab_size ('The vocabulary is not large
  // enough to contain all chars'); the MoonBit training API has no
  // error channel, so the port trains on and finalize keeps the
  // chars beyond the cap (probed: wikitext 5K/vocab300 -> 535-piece
  // vocab where HF raises)
  let desired = eff_vocab_size * 11 / 10
  // required chars: first-seen order (HF: HashSet order — its own runs vary)
  let required_chars : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for word in word_order {
    for c in word.to_array() {
      let cs = char_string(c)
      if seen.get(cs) is None {
        seen[cs] = true
        required_chars.push(cs)
      }
    }
  }
  for tok in initial_alphabet {
    match initial_alphabet_piece(tok) {
      Some(piece) =>
        if seen.get(piece) is None {
          seen[piece] = true
          required_chars.push(piece)
        }
      None => ()
    }
  }
  // EM loop — Rust do_train ALWAYS runs n_sub_iterations E/M rounds
  // BEFORE the first size check (round-1 review: an early exit here
  // shipped raw to_log_prob seed scores where HF ships post-EM
  // digamma scores — up to 4.5 nats off on small corpora)
  let mut iter_guard = 0
  while iter_guard < 512 {
    iter_guard += 1
    // n_sub_iterations E/M rounds
    let mut sub = 0
    while sub < n_sub_iterations {
      sub += 1
      let piece_ids : Map[String, Int] = Map([])
      let piece_scores : Array[Double] = []
      let mut min_score = 1.0 / 0.0
      let mut i = 0
      while i < pieces.length() {
        piece_ids[pieces[i].token] = i
        piece_scores.push(pieces[i].score)
        if pieces[i].score < min_score {
          min_score = pieces[i].score
        }
        i += 1
      }
      let expected = em_e_step(
        word_order, word_counts, piece_ids, piece_scores, min_score, 0, max_piece_length,
      )
      pieces = em_m_step(pieces, expected)
    }
    if pieces.length() <= desired {
      break
    }
    pieces = em_prune_pieces(
      pieces, word_order, word_counts, eff_vocab_size, shrinking_factor, max_piece_length,
    )
  }
  em_finalize(pieces, required_chars, vocab_size, special_tokens, unk_token)
}

///|
fn em_double_to_int(x : Double) -> Int {
  // Rust `as usize` truncates toward zero
  if x >= 2147483647.0 {
    2147483647
  } else if x <= 0.0 {
    0
  } else {
    let r = @math.floor(x)
    if r >= 2147483647.0 {
      2147483647
    } else {
      r.to_int()
    }
  }
}
