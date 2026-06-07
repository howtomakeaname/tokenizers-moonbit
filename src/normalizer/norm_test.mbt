// Unicode normalization correctness, cross-checked against Python unicodedata.

///|
test "NFC composes combining marks" {
  // "cafe" + U+0301 (combining acute) -> "café" (composed)
  let s = "cafe\u{301}"
  @test.assert_eq(Normalizer::NFC.normalize(s), "café")
}

///|
test "NFD decomposes" {
  // "é" (U+00E9) -> "e" + U+0301
  @test.assert_eq(Normalizer::NFD.normalize("é"), "e\u{301}")
}

///|
test "NFKC folds compatibility chars" {
  // fullwidth AB -> AB ; ﬁ ligature -> fi
  @test.assert_eq(Normalizer::NFKC.normalize("\u{ff21}\u{ff22}"), "AB")
  @test.assert_eq(Normalizer::NFKC.normalize("\u{fb01}"), "fi")
}

///|
test "NFKC handles canonical ordering + recomposition" {
  // U+1E9B U+0323 -> NFKC U+1E69 (ṩ)
  @test.assert_eq(Normalizer::NFKC.normalize("\u{1e9b}\u{323}"), "\u{1e69}")
}

///|
test "NFC is identity for plain ASCII" {
  @test.assert_eq(Normalizer::NFC.normalize("Hello, world!"), "Hello, world!")
}

///|
test "ByteLevel normalizer maps utf8 bytes to visible alphabet" {
  @test.assert_eq(Normalizer::ByteLevel.normalize("Hello 我"), "HelloĠæĪĳ")
}

///|
test "Precompiled normalizer applies SentencePiece NFKC charmap" {
  @test.assert_eq(
    Normalizer::Precompiled.normalize("ＡＢＣ １２３"),
    "ABC 123",
  )
  @test.assert_eq(
    Normalizer::Precompiled.normalize("Ⅳ ① ㍿"),
    "IV 1 株式会社",
  )
  @test.assert_eq(
    Normalizer::Precompiled.normalize("ﬁ ﬂ Å ㎏"),
    "fi fl Å kg",
  )
  @test.assert_eq(
    Normalizer::Precompiled.normalize("㌀ ㍻ ㈱"),
    "アパート 平成 (株)",
  )
}

///|
test "Precompiled normalizer maps whitespace without collapsing runs" {
  @test.assert_eq(
    Normalizer::Precompiled.normalize("\u{a0}\t a\n\u{3000}b"),
    "   a  b",
  )
}

///|
test "Replace normalizer supports common regex whitespace patterns" {
  @test.assert_eq(
    Normalizer::Replace(pattern=" {2,}", content=" ").normalize("a   b c"),
    "a b c",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\s+", content=" ").normalize(
      "a\t\u{a0}b\n\u{3000}c",
    ),
    "a b c",
  )
}
