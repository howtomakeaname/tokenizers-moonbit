// Split behavior/invert now folds on the HARDCODED scanners too
// (they previously short-circuited straight to pieces_to_splits,
// silently ignoring the configured behavior — probed 0.22.2:
// Split(gpt2-pattern,'removed') -> [], mwp/mwn == isolated when the
// full-coverage match list has no gaps, contiguous -> one whole
// piece; CLIP's real config is Removed + invert=true =
// keep-matches-only, and its scanner skips whitespace so a
// positioned span variant carries the real offsets). The
// digit-triplet/cjk scanners leave regex gaps — their flags are only
// exact under Isolated (the only real-world config; PROGRESS gap)

///|
fn beh_check(
  pat : String,
  beh : SplitBehavior,
  inv : Bool,
  inp : String,
  expect : Array[String],
) -> Unit raise {
  let got = split_pre_tokenize(inp, pat, beh, inv, true, 0)
  let vals : Array[String] = []
  for p in got {
    vals.push(p.value)
  }
  @test.assert_eq(vals, expect)
}

///|
fn dcheck(
  pat : String,
  beh : SplitBehavior,
  inv : Bool,
  inp : String,
  expect : Array[String],
) -> Unit raise {
  let got = split_pre_tokenize(inp, pat, beh, inv, true, 0)
  let vals : Array[String] = []
  for p in got {
    vals.push(p.value)
  }
  @test.assert_eq(vals, expect)
}

///|
test "digit-triplet flags only its digit chunks" {
  // the pattern leaves regex gaps — the non-digit pieces are NOT
  // matches (probed 0.22.2 under every behavior x invert)
  dcheck("\\p{N}{1,3}", Removed, false, "abc12345de", ["abc", "de"])
  dcheck("\\p{N}{1,3}", Isolated, false, "abc12 345", ["abc", "12", " ", "345"])
  dcheck("\\p{N}{1,3}", Removed, true, "abc12345de", ["123", "45"])
  dcheck("\\p{N}{1,3}", Contiguous, false, "12  345", ["12", "  ", "345"])
}

///|
test "scanner split behaviors honor the config" {
  beh_check(
    "'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+",
    Removed,
    false,
    "it's  a  3x!",
    [],
  )
  beh_check(
    "'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+",
    Contiguous,
    false,
    "it's  a  3x!",
    ["it's  a  3x!"],
  )
  beh_check(
    "'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+",
    MergedWithNext,
    false,
    "it's  a  3x!",
    ["it", "'s", " ", " a", " ", " 3", "x", "!"],
  )
  beh_check(
    "<\\|startoftext\\|>|<\\|endoftext\\|>|'s|'t|'re|'ve|'m|'ll|'d|[\\p{L}]+|[\\p{N}]|[^\\s\\p{L}\\p{N}]+",
    Removed,
    true,
    "hello world",
    ["hello", "world"],
  )
  beh_check(
    "<\\|startoftext\\|>|<\\|endoftext\\|>|'s|'t|'re|'ve|'m|'ll|'d|[\\p{L}]+|[\\p{N}]|[^\\s\\p{L}\\p{N}]+",
    Removed,
    true,
    "Hello,  world!",
    ["Hello", ",", "world", "!"],
  )
  beh_check(
    "<\\|startoftext\\|>|<\\|endoftext\\|>|'s|'t|'re|'ve|'m|'ll|'d|[\\p{L}]+|[\\p{N}]|[^\\s\\p{L}\\p{N}]+",
    Isolated,
    false,
    "hello world",
    ["hello", " ", "world"],
  )
  beh_check(
    "(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\\r\\n\\p{L}\\p{N}]?\\p{L}+|\\p{N}| ?[^\\s\\p{L}\\p{N}]+[\\r\\n]*|\\s*[\\r\\n]+|\\s+(?!\\S)|\\s+",
    Removed,
    false,
    "a  b",
    [],
  )
  beh_check(
    "(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\\r\\n\\p{L}\\p{N}]?\\p{L}+|\\p{N}| ?[^\\s\\p{L}\\p{N}]+[\\r\\n]*|\\s*[\\r\\n]+|\\s+(?!\\S)|\\s+",
    Contiguous,
    false,
    "it's  x\ny",
    ["it's  x\ny"],
  )
}
