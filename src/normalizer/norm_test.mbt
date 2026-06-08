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
  @test.assert_eq(
    Normalizer::Replace(pattern="\\s{2,}", content="_").normalize("a b  c\t\td"),
    "a b_c_d",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\s]{3,}", content="_").normalize(
      "a \tb\n\n\nc    d",
    ),
    "a \tb_c_d",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\s{3}", content="_").normalize(
      "a \t\u{a0}b\n\n\nc    d",
    ),
    "a_b_c_ d",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^\\s+", content="").normalize(
      "\t \u{3000}abc ",
    ),
    "abc ",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\s+$", content="").normalize(" abc\u{a0}\n"),
    " abc",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\r\\n]+", content="|").normalize("a\r\nb\nc"),
    "a|b|c",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\r\\n]{2,}", content="|").normalize(
      "a\r\nb\n\nc",
    ),
    "a|b|c",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\r\\n]{3}", content="|").normalize(
      "a\r\n\nb\n\nc",
    ),
    "a|b\n\nc",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^\\S\\r\\n]+", content="_").normalize(
      "a\t  b\n c",
    ),
    "a_b\n_c",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^\\S\\r\\n]{2,}", content="_").normalize(
      "a\t b c  d",
    ),
    "a_b c_d",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^\\S\\r\\n]{3,}", content="_").normalize(
      "a\t\u{a0} b\n  c    d",
    ),
    "a_b\n  c_d",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[ \\t]{3}", content="_").normalize(
      "a \t b\t\t\tc    d",
    ),
    "a_b_c_ d",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\d+", content="#").normalize("a12b003"),
    "a#b#",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\d]+", content="#").normalize("a12b003"),
    "a#b#",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\d]{2,}", content="#").normalize(
      "a1b12c１２3",
    ),
    "a1b#c#",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\d{1,3}", content="#").normalize("a12345b"),
    "a##b",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\d]{1,3}", content="#").normalize("a12345b"),
    "a##b",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\d{2}", content="#").normalize("a12345b"),
    "a##5b",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{Number}+", content="#").normalize(
      "a１２b٣",
    ),
    "a#b#",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\p{Number}]{4}", content="#").normalize(
      "a１２٣٤5b",
    ),
    "a#5b",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^\\d+", content="#").normalize("123abc456"),
    "#abc456",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\d+$", content="#").normalize("123abc456"),
    "123abc#",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\D+", content="_").normalize("a12bc003"),
    "_12_003",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\P{N}+", content="_").normalize("a１２b٣"),
    "_１２_٣",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\w+", content="W").normalize("ab_12,中!cd"),
    "W,中!W",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\w{2,}", content="W").normalize("ab_12,x,cde"),
    "W,x,W",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\w{2}", content="W").normalize("ab_12,cde"),
    "WW2,We",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\w{1,3}", content="W").normalize("ab_12,cde"),
    "WW,W",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\W+", content="-").normalize("ab_12,中!cd"),
    "ab_12-cd",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^\\w+", content="W").normalize("ab_12,cd"),
    "W,cd",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\w+$", content="W").normalize("ab,cd_12"),
    "ab,W",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[A-Za-z0-9]+", content="A").normalize(
      "ab_12,CD中",
    ),
    "A_A,A中",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[A-Za-z0-9]{3}", content="A").normalize(
      "ab12_cde中",
    ),
    "A2_A中",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^A-Za-z0-9]+", content="-").normalize(
      "ab_12,CD中",
    ),
    "ab-12-CD-",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^[A-Za-z0-9]+", content="A").normalize(
      "abc12_é",
    ),
    "A_é",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[A-Za-z0-9]+$", content="A").normalize(
      "é_abc12",
    ),
    "é_A",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[A-Za-z]+", content="A").normalize(
      "abé_12,CD中",
    ),
    "Aé_12,A中",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[A-Za-z]{2,}", content="A").normalize(
      "abé_cdef中",
    ),
    "Aé_A中",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[A-Za-z]{1,2}", content="A").normalize(
      "abc123DE",
    ),
    "AA123A",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^A-Za-z]+", content="-").normalize(
      "abé_12,CD中",
    ),
    "ab-CD-",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^[A-Za-z]+", content="A").normalize("abc12é"),
    "A12é",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[A-Za-z]+$", content="A").normalize("12éabc"),
    "12éA",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{L}+", content="L").normalize(
      "abé中12!Ж",
    ),
    "L12!L",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{L}{3}", content="L").normalize(
      "abé中12Жxy",
    ),
    "L中12L",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\P{L}+", content="-").normalize(
      "abé中12!Ж",
    ),
    "abé中-Ж",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^\\p{L}+", content="L").normalize("Жabc12é"),
    "L12é",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{L}+$", content="L").normalize("12Жabc"),
    "12L",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{P}+", content="_").normalize(
      "hi,!$+🙂ok。",
    ),
    "hi_$+🙂ok_",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{P}{2,}", content="_").normalize(
      "hi,!?ok。",
    ),
    "hi_ok。",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{P}{2}", content="_").normalize(
      "hi,!?ok。",
    ),
    "hi_?ok。",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{P}{1,3}", content="_").normalize(
      "hi!!!!ok。?",
    ),
    "hi__ok_",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^\\p{Punctuation}+", content="").normalize(
      "？！hello!",
    ),
    "hello!",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{Symbol}+", content="S").normalize(
      "a$+🙂,b=≤c",
    ),
    "aS,bSc",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{S}{2}", content="S").normalize(
      "a$+🙂,b=≤c",
    ),
    "aS🙂,bSc",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\p{S}+$", content="").normalize("ok🙂+"),
    "ok",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\p{P}\\p{S}]+", content="_").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab_ cd_42",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\p{P}\\p{S}]{2,}", content="_").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab_ cd。42",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\p{P}\\p{S}]{3}", content="_").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab_🙂 cd。42",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\p{P}\\p{S}]{1,3}", content="_").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab__ cd_42",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^\\s\\p{L}\\p{N}]+", content="#").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab# cd#42",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^[\\p{P}\\p{S}]+", content="").normalize(
      "?!$ok🙂+",
    ),
    "ok🙂+",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[\\p{P}\\p{S}]+$", content="").normalize(
      "ok🙂+",
    ),
    "ok",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\D{1,3}", content="_").normalize("a12 bc003"),
    "_12_003",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\W{1,2}", content="-").normalize(
      "ab_12,中!cd",
    ),
    "ab_12--cd",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^A-Za-z]{1,3}", content="-").normalize(
      "abé_12,CD中",
    ),
    "ab--CD-",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\P{L}{1,4}", content="-").normalize(
      "abé中12!🙂Ж",
    ),
    "abé中-Ж",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^\\p{P}\\p{S}]{1,3}", content="N").normalize(
      "ab,$+🙂 cd。42",
    ),
    "N,$+🙂N。N",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^\\s\\p{L}\\p{N}]{1,3}", content="#").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab## cd#42",
  )
}
