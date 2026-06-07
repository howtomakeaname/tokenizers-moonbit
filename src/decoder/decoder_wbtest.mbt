// Decoder white-box compatibility tests.

///|
test "Replace decoder supports common regex whitespace patterns" {
  @test.assert_eq(
    Decoder::Replace(pattern=" {2,}", content=" ").decode(["a   b", " c"]),
    "a b c",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\s+", content=" ").decode([
      "a\t", "\u{a0}b\n", "\u{3000}c",
    ]),
    "a  b  c",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="^\\s+", content="").decode(["\t ", "abc "]),
    "abc ",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\s+$", content="").decode([" abc", "\u{a0}\n"]),
    " abc",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\r\\n]+", content="|").decode(["a\r\n", "b\nc"]),
    "a|b|c",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^\\S\\r\\n]+", content="_").decode([
      "a\t  b\n", " c",
    ]),
    "a_b\n_c",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\d+", content="#").decode(["a12", "b003"]),
    "a#b#",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\D+", content="_").decode(["a12", "bc003"]),
    "_12_003",
  )
}

///|
test "Replace decoder keeps literal fallback" {
  @test.assert_eq(
    Decoder::Replace(pattern="@@", content="-").decode(["a@@b", "@@c"]),
    "a-b-c",
  )
}
