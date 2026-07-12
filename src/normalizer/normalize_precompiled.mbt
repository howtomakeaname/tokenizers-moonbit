///|
fn precompiled_normalize(s : String) -> String {
  match precompiled_ascii_fast(s) {
    Some(out) => return out
    None => ()
  }
  let sb = StringBuilder::new()
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
fn precompiled_map_normalize(data : PrecompiledCharsMap, s : String) -> String {
  let chars = s.to_array()
  let sb = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    match precompiled_transform(data, char_to_string(chars[i])) {
      Some(repl) => sb.write_string(repl)
      None => sb.write_char(chars[i])
    }
    i = i + 1
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
  let sb = StringBuilder::new()
  sb.write_char(c)
  sb.to_string()
}

///|
fn precompiled_ascii_fast(s : String) -> String? {
  let sb = StringBuilder::new()
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
