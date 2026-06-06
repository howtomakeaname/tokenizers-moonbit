// Unicode normalization (NFC / NFD / NFKC / NFKD).
//
// Algorithm (per UAX #15):
//   1. Decompose: replace each char by its full canonical (or compatibility)
//      decomposition from the generated tables.
//   2. Canonical ordering: stably sort runs of combining marks by CCC.
//   3. (NFC/NFKC only) Canonical composition: greedily recombine starter +
//      combining mark pairs using the composition table.
//
// Tables come from scripts/gen_unicode_norm.py (unicode_norm_data.mbt), parsed
// lazily on first use.

// cp -> decomposition (fully recursive)
let canon_decomp : Ref[Map[Int, Array[Int]]?] = { val: None }

let compat_decomp : Ref[Map[Int, Array[Int]]?] = { val: None }

// cp -> combining class (absent => 0)
let ccc_table : Ref[Map[Int, Int]?] = { val: None }

// (a,b) packed as a*0x110000+b -> composed cp
let comp_table : Ref[Map[Int, Int]?] = { val: None }

fn parse_decomp(raw : String) -> Map[Int, Array[Int]] {
  let m : Map[Int, Array[Int]] = {}
  for line in raw.split("\n") {
    let s = line.to_string()
    if s == "" {
      continue
    }
    // "cp:hex hex ..."
    let parts = s.split(":")
    let key_view = parts.next().unwrap()
    let rest = match parts.next() {
      Some(r) => r.to_string()
      None => continue
    }
    let cp = hex_to_int(key_view.to_string())
    let seq : Array[Int] = []
    for tok in rest.split(" ") {
      let t = tok.to_string()
      if t != "" {
        seq.push(hex_to_int(t))
      }
    }
    m[cp] = seq
  }
  m
}

fn canon_map() -> Map[Int, Array[Int]] {
  match canon_decomp.val {
    Some(m) => m
    None => {
      let m = parse_decomp(canonical_decomp_raw())
      canon_decomp.val = Some(m)
      m
    }
  }
}

fn compat_map() -> Map[Int, Array[Int]] {
  match compat_decomp.val {
    Some(m) => m
    None => {
      let m = parse_decomp(compat_decomp_raw())
      compat_decomp.val = Some(m)
      m
    }
  }
}

fn ccc_map() -> Map[Int, Int] {
  match ccc_table.val {
    Some(m) => m
    None => {
      let m : Map[Int, Int] = {}
      for line in ccc_raw().split("\n") {
        let s = line.to_string()
        if s == "" {
          continue
        }
        let parts = s.split(":")
        let k = parts.next().unwrap().to_string()
        match parts.next() {
          Some(v) => m[hex_to_int(k)] = str_to_int(v.to_string())
          None => ()
        }
      }
      ccc_table.val = Some(m)
      m
    }
  }
}

fn comp_map() -> Map[Int, Int] {
  match comp_table.val {
    Some(m) => m
    None => {
      let m : Map[Int, Int] = {}
      for line in composition_raw().split("\n") {
        let s = line.to_string()
        if s == "" {
          continue
        }
        // "a b cp"
        let toks : Array[Int] = []
        for tok in s.split(" ") {
          let t = tok.to_string()
          if t != "" {
            toks.push(hex_to_int(t))
          }
        }
        if toks.length() == 3 {
          m[toks[0] * 0x110000 + toks[1]] = toks[2]
        }
      }
      comp_table.val = Some(m)
      m
    }
  }
}

fn ccc_of(cp : Int) -> Int {
  ccc_map().get(cp).unwrap_or(0)
}

/// Normalize a string. `compat` selects NFKC/NFKD; `compose` selects the C
/// forms (recompose after decomposition).
pub fn normalize_unicode(
  input : String,
  compat~ : Bool,
  compose~ : Bool,
) -> String {
  // 1. Decompose into a flat list of code points.
  let table = if compat { compat_map() } else { canon_map() }
  let cm = canon_map()
  let decomposed : Array[Int] = []
  for c in input {
    decompose_cp(c.to_int(), table, cm, compat, decomposed)
  }
  // 2. Canonical ordering of combining marks (stable insertion sort by CCC).
  canonical_order(decomposed)
  // 3. Optional composition.
  let result = if compose { canonical_compose(decomposed) } else { decomposed }
  let sb = StringBuilder::new()
  for cp in result {
    sb.write_char(Char::from_int(cp))
  }
  sb.to_string()
}

// Append the full decomposition of `cp` to `out`. `compat_table` is the chosen
// decomposition table; `cm` is the canonical table used to recurse into the
// canonical part of a compatibility mapping. Both tables are already fully
// recursive, so a single lookup suffices.
fn decompose_cp(
  cp : Int,
  table : Map[Int, Array[Int]],
  cm : Map[Int, Array[Int]],
  compat : Bool,
  out : Array[Int],
) -> Unit {
  ignore(cm)
  ignore(compat)
  match table.get(cp) {
    Some(seq) => for x in seq {
        out.push(x)
      }
    None =>
      // For compatibility form, also fall back to canonical decomposition.
      if compat {
        match cm.get(cp) {
          Some(seq) => for x in seq {
              out.push(x)
            }
          None => out.push(cp)
        }
      } else {
        out.push(cp)
      }
  }
}

// Stable canonical ordering: reorder combining marks so CCC is non-decreasing
// within each run, preserving order of equal-CCC marks.
fn canonical_order(cps : Array[Int]) -> Unit {
  let n = cps.length()
  let mut i = 1
  while i < n {
    let cc = ccc_of(cps[i])
    if cc == 0 {
      i = i + 1
      continue
    }
    // bubble cps[i] left past higher-CCC marks
    let mut j = i
    while j > 0 {
      let prev_cc = ccc_of(cps[j - 1])
      if prev_cc == 0 || prev_cc <= cc {
        break
      }
      let tmp = cps[j]
      cps[j] = cps[j - 1]
      cps[j - 1] = tmp
      j = j - 1
    }
    i = i + 1
  }
}

// Canonical composition (UAX #15): walk left-to-right keeping a "last starter",
// and try to compose it with each following combining mark / starter.
fn canonical_compose(cps : Array[Int]) -> Array[Int] {
  let n = cps.length()
  if n == 0 {
    return []
  }
  let cmp = comp_map()
  let out : Array[Int] = []
  let mut starter = cps[0]
  let mut starter_idx = 0
  out.push(starter)
  let mut last_cc = -1
  let mut i = 1
  while i < n {
    let ch = cps[i]
    let cc = ccc_of(ch)
    let key = starter * 0x110000 + ch
    let composed = cmp.get(key)
    let blocked = last_cc >= cc && last_cc != -1 && cc != 0
    match composed {
      Some(x) if not(blocked) && last_cc < cc => {
        // compose into the starter
        out[starter_idx] = x
        starter = x
      }
      _ =>
        if cc == 0 {
          // new starter
          out.push(ch)
          starter = ch
          starter_idx = out.length() - 1
          last_cc = -1
        } else {
          out.push(ch)
          last_cc = cc
        }
    }
    i = i + 1
  }
  out
}

fn hex_to_int(s : String) -> Int {
  let mut v = 0
  for c in s {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 'a'.to_int() + 10
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 'A'.to_int() + 10
    } else {
      0
    }
    v = v * 16 + d
  }
  v
}

fn str_to_int(s : String) -> Int {
  let mut v = 0
  for c in s {
    if c >= '0' && c <= '9' {
      v = v * 10 + (c.to_int() - '0'.to_int())
    }
  }
  v
}
