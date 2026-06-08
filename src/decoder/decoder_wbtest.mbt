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
    Decoder::Replace(pattern="\\s{2,}", content="_").decode(["a b", "  c\t\td"]),
    "a b_c_d",
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
    Decoder::Replace(pattern="[^\\S\\r\\n]{2,}", content="_").decode([
      "a\t b", " c  d",
    ]),
    "a_b c_d",
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
    Decoder::Replace(pattern="^\\d+", content="#").decode(["123", "abc456"]),
    "#abc456",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\d+$", content="#").decode(["123abc", "456"]),
    "123abc#",
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
    Decoder::Replace(pattern="^\\w+", content="W").decode(["ab_12,", "cd"]),
    "W,W",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\w+$", content="W").decode(["ab,", "cd_12"]),
    "ab,W",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[A-Za-z]+", content="A").decode([
      "abé_12,", "CD中",
    ]),
    "Aé_12,A中",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^A-Za-z]+", content="-").decode([
      "abé_12,", "CD中",
    ]),
    "ab-CD-",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="^[A-Za-z]+", content="A").decode(["abc", "12é"]),
    "A12é",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[A-Za-z]+$", content="A").decode(["12é", "abc"]),
    "12éA",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{L}+", content="L").decode(["abé中", "12!Ж"]),
    "L12!L",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\P{L}+", content="-").decode(["abé中", "12!Ж"]),
    "abé中-Ж",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="^\\p{L}+", content="L").decode(["Жabc", "12é"]),
    "L12é",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{L}+$", content="L").decode(["12", "Жabc"]),
    "12L",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{P}+", content="_").decode([
      "hi,!", "$+🙂ok。",
    ]),
    "hi_$+🙂ok_",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="^\\p{Punctuation}+", content="").decode([
      "？！", "hello!",
    ]),
    "hello!",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{Symbol}+", content="S").decode([
      "a$+🙂", ",b=≤c",
    ]),
    "aS,bSc",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{S}+$", content="").decode(["ok", "🙂+"]),
    "ok",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\p{P}\\p{S}]+", content="_").decode([
      "ab,$+🙂", " cd。42",
    ]),
    "ab_ cd_42",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^\\s\\p{L}\\p{N}]+", content="#").decode([
      "ab,$+🙂", " cd。42",
    ]),
    "ab# cd#42",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="^[\\p{P}\\p{S}]+", content="").decode([
      "?!$", "ok🙂+",
    ]),
    "ok🙂+",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\p{P}\\p{S}]+$", content="").decode([
      "ok", "🙂+",
    ]),
    "ok",
  )
}

///|
test "Replace decoder keeps literal fallback" {
  @test.assert_eq(
    Decoder::Replace(pattern="@@", content="-").decode(["a@@b", "@@c"]),
    "a-b-c",
  )
}

///|
test "SentencePiece decoder sequence handles replace byte fallback fuse strip" {
  let decoder = Decoder::Sequence([
    Decoder::Replace(pattern="▁", content=" "),
    Decoder::ByteFallback,
    Decoder::Fuse,
    Decoder::Strip(content=' ', start=1, stop=0),
  ])
  @test.assert_eq(
    decoder.decode(["▁Hello", "▁", "<0xF0>", "<0x9F>", "<0x99>", "<0x82>"]),
    "Hello 🙂",
  )
}
