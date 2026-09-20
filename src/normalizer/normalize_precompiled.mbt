///|
fn precompiled_normalize(s : String) -> String {
  match precompiled_ascii_fast(s) {
    Some(out) => return out
    None => ()
  }
  let sb = StringBuilder()
  let normalized = normalize_unicode(s, compat=true, compose=true)
  for c in normalized {
    if @common.is_unicode_whitespace(c.to_int()) {
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Apply a precompiled charsmap trie. Mirrors HF 0.22.2 (`precompiled.rs` /
/// `spm_precompiled::transform`): text is segmented into grapheme clusters
/// (approximated as a base char plus trailing combining marks); a cluster
/// shorter than 6 UTF-8 bytes is looked up in the trie as a whole — on a
/// hit the replacement replaces the entire cluster (leftover marks are
/// consumed) — and misses fall back to per-character lookups. Clusters of
/// 6+ bytes (e.g. Hangul jamo pairs) also use per-character lookups, which
/// leaves them uncomposed, matching the upstream guard.
fn precompiled_map_normalize(data : PrecompiledCharsMap, s : String) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    // cluster = base char + following combining marks
    let mut j = i + 1
    while j < n && is_combining_mark(chars[j].to_int()) {
      j = j + 1
    }
    if j > i + 1 {
      let cluster = char_slice_to_string(chars, i, j)
      let cluster_bytes = @utf8.encode(cluster).length()
      if cluster_bytes < 6 {
        match precompiled_transform(data, cluster) {
          Some(repl) => {
            sb.write_string(repl)
            i = j
            continue
          }
          None => ()
        }
      }
      // fall back to per-character lookups for the whole cluster
      while i < j {
        match precompiled_transform(data, char_to_string(chars[i])) {
          Some(repl) => sb.write_string(repl)
          None => sb.write_char(chars[i])
        }
        i = i + 1
      }
    } else {
      match precompiled_transform(data, char_to_string(chars[i])) {
        Some(repl) => sb.write_string(repl)
        None => sb.write_char(chars[i])
      }
      i = i + 1
    }
  }
  sb.to_string()
}

///|
fn char_slice_to_string(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder()
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

///|
fn precompiled_transform(data : PrecompiledCharsMap, chunk : String) -> String? {
  let key = @utf8.encode(chunk)
  let results = precompiled_common_prefix_search(data.trie, key)
  if results.length() == 0 {
    return None
  }
  let start = results[0]
  if start < 0 || start >= data.normalized.length() {
    return None
  }
  let bytes = @buffer.Buffer::Buffer()
  let mut i = start
  while i < data.normalized.length() && data.normalized[i] != 0 {
    bytes.write_byte(data.normalized[i].to_byte())
    i = i + 1
  }
  Some(@utf8.decode_lossy(bytes.to_bytes()[:]))
}

///|
fn precompiled_common_prefix_search(
  trie : Array[Int],
  key : Bytes,
) -> Array[Int] {
  let results : Array[Int] = []
  if trie.length() == 0 {
    return results
  }
  let mut node_pos = 0
  let mut unit = trie[node_pos]
  node_pos = node_pos ^ precompiled_offset(unit)
  for i in 0..<key.length() {
    let c = key[i].to_int()
    if c == 0 {
      break
    }
    node_pos = node_pos ^ c
    if node_pos < 0 || node_pos >= trie.length() {
      return results
    }
    unit = trie[node_pos]
    if precompiled_label(unit) != c {
      return results
    }
    node_pos = node_pos ^ precompiled_offset(unit)
    if precompiled_has_leaf(unit) {
      if node_pos < 0 || node_pos >= trie.length() {
        return results
      }
      results.push(precompiled_value(trie[node_pos]))
    }
  }
  results
}

///|
fn precompiled_has_leaf(unit : Int) -> Bool {
  ((unit >> 8) & 1) == 1
}

///|
fn precompiled_value(unit : Int) -> Int {
  unit & 0x7FFFFFFF
}

///|
fn precompiled_label(unit : Int) -> Int {
  unit & 0x800000FF
}

///|
fn precompiled_offset(unit : Int) -> Int {
  unit >> 10 << ((unit & 0x200) >> 6)
}

///|
fn char_to_string(c : Char) -> String {
  let sb = StringBuilder()
  sb.write_char(c)
  sb.to_string()
}

///|
fn precompiled_ascii_fast(s : String) -> String? {
  let sb = StringBuilder()
  let mut changed = false
  for c in s {
    let u = c.to_int()
    if u > 0x7F {
      return None
    }
    if c == '\t' || c == '\n' || c == '\r' {
      sb.write_char(' ')
      changed = true
    } else {
      sb.write_char(c)
    }
  }
  if changed {
    Some(sb.to_string())
  } else {
    Some(s)
  }
}

// strip_accents: remove combining marks via the precomputed NFD-minus-Mn table.

///|

// Aligned variants of the precompiled charsmap paths: replacements map the
// replacement chars onto the consumed original cluster/char span.

///|
pub fn precompiled_normalize_aligned(s : String) -> (String, Array[(Int, Int)]) {
  match precompiled_ascii_fast(s) {
    Some(out) => {
      // ascii fast path: chars map 1:1 (whitespace folding is 1:1)
      let align : Array[(Int, Int)] = []
      for i in 0..<s.char_length() {
        align.push((i, i + 1))
      }
      return (out, align)
    }
    None => ()
  }
  let sb = StringBuilder()
  let normalized = normalize_unicode_aligned(s, compat=true, compose=true)
  let text = normalized.0
  // rebuild whitespace folding with alignment against `s` composed through
  let folded : Array[(Int, Int)] = []
  let inner = normalized.1
  let mut oi = 0
  for c in text {
    if @common.is_unicode_whitespace(c.to_int()) {
      sb.write_char(' ')
      folded.push(inner[oi])
    } else {
      sb.write_char(c)
      folded.push(inner[oi])
    }
    oi = oi + 1
  }
  (sb.to_string(), folded)
}

///|
pub fn precompiled_map_normalize_aligned(
  data : PrecompiledCharsMap,
  s : String,
) -> (String, Array[(Int, Int)]) {
  let chars = s.to_array()
  let n = chars.length()
  let sb = StringBuilder()
  let align : Array[(Int, Int)] = []
  let mut i = 0
  while i < n {
    let mut j = i + 1
    while j < n && is_combining_mark(chars[j].to_int()) {
      j = j + 1
    }
    if j > i + 1 {
      let cluster = char_slice_to_string(chars, i, j)
      let cluster_bytes = @utf8.encode(cluster).length()
      if cluster_bytes < 6 {
        match precompiled_transform(data, cluster) {
          Some(repl) => {
            // HF transform -N contract: the replacement maps to the FIRST
            // consumed char's span; the remaining cluster chars lose
            // coverage (t5 "cafe◌́" -> "café" gives é the span of "e").
            for _ch in repl {
              align.push((i, i + 1))
            }
            sb.write_string(repl)
            i = j
            continue
          }
          None => ()
        }
      }
      while i < j {
        match precompiled_transform(data, char_to_string(chars[i])) {
          Some(repl) => {
            for _ch in repl {
              align.push((i, i + 1))
            }
            sb.write_string(repl)
          }
          None => {
            sb.write_char(chars[i])
            align.push((i, i + 1))
          }
        }
        i = i + 1
      }
    } else {
      match precompiled_transform(data, char_to_string(chars[i])) {
        Some(repl) => {
          for _ch in repl {
            align.push((i, i + 1))
          }
          sb.write_string(repl)
        }
        None => {
          sb.write_char(chars[i])
          align.push((i, i + 1))
        }
      }
      i = i + 1
    }
  }
  (sb.to_string(), align)
}
