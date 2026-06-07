// Decoder white-box compatibility tests.

///|
test "Replace decoder supports common regex whitespace patterns" {
  @test.assert_eq(
    Decoder::Replace(pattern=" {2,}", content=" ").decode(["a   b", " c"]),
    "a b c",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\s+", content=" ").decode([
      "a\t",
      "\u{a0}b\n",
      "\u{3000}c",
    ]),
    "a  b  c",
  )
}

///|
test "Replace decoder keeps literal fallback" {
  @test.assert_eq(
    Decoder::Replace(pattern="@@", content="-").decode(["a@@b", "@@c"]),
    "a-b-c",
  )
}
