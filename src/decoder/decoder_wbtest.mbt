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
    Decoder::Replace(pattern="\\d{1,3}", content="#").decode(["a123", "45b"]),
    "a##b",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{Number}+", content="#").decode([
      "a１２", "b٣",
    ]),
    "a#b#",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\D+", content="_").decode(["a12", "bc003"]),
    "_12_003",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\w+", content="W").decode(["ab_12,", "中!cd"]),
    "W,中!W",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\W+", content="-").decode(["ab_12,", "中!cd"]),
    "ab_12--cd",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{L}+", content="L").decode(["abé中", "12!Ж"]),
    "L12!L",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\P{L}+", content="-").decode(["abé中", "12!Ж"]),
    "abé中-Ж",
  )
}

///|
test "Replace decoder keeps literal fallback" {
  @test.assert_eq(
    Decoder::Replace(pattern="@@", content="-").decode(["a@@b", "@@c"]),
    "a-b-c",
  )
}
