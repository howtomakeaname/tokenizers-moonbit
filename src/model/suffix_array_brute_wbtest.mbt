///|
fn sa_brute_force(chars : Array[Int]) -> Array[Int] {
  let n = chars.length()
  let idx : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    idx[i] = i
  }
  idx.sort_by(fn(a, b) {
    let la = n - a
    let lb = n - b
    let m = if la < lb { la } else { lb }
    for k in 0..<m {
      if chars[a + k] != chars[b + k] {
        return chars[a + k] - chars[b + k]
      }
    }
    la - lb
  })
  idx
}

///|
fn sa_check(name : String, s : String) -> Bool {
  let chars : Array[Int] = []
  for ch in s {
    chars.push(ch.to_int())
  }
  let got = doubling_suffix_array(chars)
  let want = sa_brute_force(chars)
  if got != want {
    println(
      name +
      " MISMATCH got=" +
      debug_string(got) +
      " want=" +
      debug_string(want),
    )
    return false
  }
  true
}

///|
fn debug_string(a : Array[Int]) -> String {
  let mut b = ""
  for v in a {
    b = b + v.to_string() + ","
  }
  b
}

///|
test "doubling_suffix_array matches brute force" {
  let cases = [
    ("banana", true),
    ("abracadabra", true),
    ("mississippi", true),
    ("aaaa", true),
    ("a", true),
    ("ab", true),
    ("ba", true),
    ("abcabcabc", true),
    ("cba", true),
    ("aabxaaaz", true),
    ("Hello, 世界世界 world! 123", true),
    ("aaaaaaaaab", true),
    ("baaaaaaaaa", true),
    ("z y x w v u t s r q p o n", true),
  ]
  for i, item in cases {
    let (s, _) = item
    inspect(sa_check("case" + i.to_string(), s), content="true")
  }
}
