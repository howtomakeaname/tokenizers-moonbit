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
    Decoder::Replace(pattern="[\\s]{3,}", content="_").decode([
      "a \tb", "\n\n\nc    d",
    ]),
    "a \tb_c_d",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\s{3}", content="_").decode([
      "a \t\u{a0}b", "\n\n\nc    d",
    ]),
    "a_b_c_ d",
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
    Decoder::Replace(pattern="[\\r\\n]{2,}", content="|").decode([
      "a\r\n", "b\n\nc",
    ]),
    "a|b|c",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\r\\n]{3}", content="|").decode([
      "a\r\n\nb\n\nc",
    ]),
    "a|b\n\nc",
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
    Decoder::Replace(pattern="[^\\S\\r\\n]{3,}", content="_").decode([
      "a\t\u{a0} b\n", "  c    d",
    ]),
    "a_b\n  c_d",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[ \\t]{3}", content="_").decode([
      "a \t b", "\t\t\tc    d",
    ]),
    "a_b_c_ d",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\d+", content="#").decode(["a12", "b003"]),
    "a#b#",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\d]+", content="#").decode(["a12", "b003"]),
    "a#b#",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\d]{2,}", content="#").decode([
      "a1b12", "c１２3",
    ]),
    "a1b#c#",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\d{1,3}", content="#").decode(["a123", "45b"]),
    "a##b",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\d]{1,3}", content="#").decode(["a123", "45b"]),
    "a##b",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\d{2}", content="#").decode(["a123", "45b"]),
    "a#3#b",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{Number}+", content="#").decode([
      "a１２", "b٣",
    ]),
    "a#b#",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\p{Number}]{4}", content="#").decode([
      "a１２٣٤5b",
    ]),
    "a#5b",
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
    Decoder::Replace(pattern="\\D{3,}", content="_").decode(["a12", " bc003"]),
    "a12_003",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\D{4}", content="_").decode(["a12", " bc003"]),
    "a12 bc003",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\P{N}+", content="_").decode(["a１２", "b٣"]),
    "_１２_٣",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\w+", content="W").decode(["ab_12,", "中!cd"]),
    "W,中!W",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\w{2,}", content="W").decode(["ab_12,", "x,cde"]),
    "W,x,W",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\w{2}", content="W").decode(["ab_12,", "cde"]),
    "WW2,We",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\w{1,3}", content="W").decode(["ab_12,cde"]),
    "WW,W",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\W+", content="-").decode(["ab_12,", "中!cd"]),
    "ab_12--cd",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\W{2}", content="-").decode(["ab_12,", "中!cd"]),
    "ab_12,-cd",
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
    Decoder::Replace(pattern="[A-Za-z0-9]+", content="A").decode([
      "ab_12,", "CD中",
    ]),
    "A_A,A中",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[A-Za-z0-9]{3}", content="A").decode([
      "ab12_", "cde中",
    ]),
    "A2_A中",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^A-Za-z0-9]+", content="-").decode([
      "ab_12,", "CD中",
    ]),
    "ab-12-CD-",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="^[A-Za-z0-9]+", content="A").decode([
      "abc12", "_é",
    ]),
    "A_é",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[A-Za-z0-9]+$", content="A").decode([
      "é_", "abc12",
    ]),
    "é_A",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[A-Za-z]+", content="A").decode([
      "abé_12,", "CD中",
    ]),
    "Aé_12,A中",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[A-Za-z]{2,}", content="A").decode([
      "abé_", "cdef中",
    ]),
    "Aé_A中",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[A-Za-z]{1,2}", content="A").decode(["abc123DE"]),
    "AA123A",
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
    Decoder::Replace(pattern="\\p{L}{3}", content="L").decode(["abé中12Жxy"]),
    "L中12L",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\P{L}+", content="-").decode(["abé中", "12!Ж"]),
    "abé中-Ж",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\P{L}{3,}", content="-").decode(["abé中12!🙂", "Ж"]),
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
    Decoder::Replace(pattern="\\p{P}{2,}", content="_").decode([
      "hi,!?", "ok。",
    ]),
    "hi_ok。",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{P}{2}", content="_").decode(["hi,!?", "ok。"]),
    "hi_?ok。",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\p{P}{1,3}", content="_").decode(["hi!!!!ok。?"]),
    "hi__ok_",
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
    Decoder::Replace(pattern="\\p{S}{2}", content="S").decode([
      "a$+🙂", ",b=≤c",
    ]),
    "aS🙂,bSc",
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
    Decoder::Replace(pattern="[\\p{P}\\p{S}]{2,}", content="_").decode([
      "ab,$+🙂", " cd。42",
    ]),
    "ab_ cd。42",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\p{P}\\p{S}]{3}", content="_").decode([
      "ab,$+🙂", " cd。42",
    ]),
    "ab_🙂 cd。42",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\p{P}\\p{S}]{1,3}", content="_").decode([
      "ab,$+🙂 cd。42",
    ]),
    "ab__ cd_42",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[\\p{P}\\p{S}]{2,4}", content="_").decode([
      "ab,$+🙂 cd。42",
    ]),
    "ab_ cd。42",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^\\s\\p{L}\\p{N}]+", content="#").decode([
      "ab,$+🙂", " cd。42",
    ]),
    "ab# cd#42",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^\\p{P}\\p{S}]{3,}", content="N").decode([
      "ab,$+🙂", " cd。42",
    ]),
    "ab,$+🙂N。42",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^\\s\\p{L}\\p{N}]{4}", content="#").decode([
      "ab,$+🙂 cd。42",
    ]),
    "ab# cd。42",
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
  @test.assert_eq(
    Decoder::Replace(pattern="\\D{1,3}", content="_").decode(["a12", " bc003"]),
    "_12_003",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\W{1,2}", content="-").decode([
      "ab_12,中", "!cd",
    ]),
    "ab_12--cd",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\P{L}{1,4}", content="-").decode([
      "abé中12!🙂", "Ж",
    ]),
    "abé中-Ж",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^\\p{P}\\p{S}]{1,3}", content="N").decode([
      "ab,$+🙂", " cd。42",
    ]),
    "N,$+🙂N。N",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^\\s\\p{L}\\p{N}]{1,3}", content="#").decode([
      "ab,$+🙂", " cd。42",
    ]),
    "ab## cd#42",
  )
}

///|
test "Replace decoder supports anchored inverse regex families" {
  @test.assert_eq(
    Decoder::Replace(pattern="^\\S+", content="X").decode(["abc", "\t tail"]),
    "X\t tail",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\D+$", content="_").decode(["123", "abc中"]),
    "123_",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="^\\P{Letter}+", content="").decode([
      "123!?", "abc",
    ]),
    "abc",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="\\P{Punctuation}+$", content="N").decode([
      "?!", "abc🙂",
    ]),
    "?!N",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="^[^\\p{P}\\p{S}]+", content="N").decode([
      "abc12", ",$",
    ]),
    "N,$",
  )
  @test.assert_eq(
    Decoder::Replace(pattern="[^\\s\\p{L}\\p{N}]+$", content="").decode([
      "abc42", "🙂+",
    ]),
    "abc42",
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

///|
test "ByteFallback decoder handles valid invalid and interrupted byte runs" {
  @test.assert_eq(
    Decoder::ByteFallback.decode(["a", "<0xE2>", "<0x82>", "<0xAC>", "b"]),
    "a€b",
  )
  @test.assert_eq(Decoder::ByteFallback.decode(["<0xFF>"]), "�")
  @test.assert_eq(
    Decoder::ByteFallback.decode(["<0xE2>", "x", "<0x82>", "<0xAC>"]),
    "�x��",
  )
}

///|
test "Strip and CTC decoders have direct coverage" {
  @test.assert_eq(
    Decoder::Strip(content=' ', start=1, stop=2).decode(["  hi   ", " ok "]),
    " hi ok",
  )
  @test.assert_eq(
    Decoder::CTC(
      pad_token="_",
      word_delimiter_token="|",
      cleanup=false,
    ).decode(["h", "h", "i", "_", "|", "t", "t", "h", "e", "r", "e"]),
    "hi there",
  )
  @test.assert_eq(
    Decoder::CTC(
      pad_token="_",
      word_delimiter_token="|",
      cleanup=true,
    ).decode(["hi", " ?"]),
    "hi?",
  )
}

///|
test "WordPiece decoder cleanup uses BERT punctuation and contraction rules" {
  let decoder = Decoder::wordpiece(prefix="##", cleanup=true)
  @test.assert_eq(
    decoder.decode([
      "they", "'re", "not", "go", "##ing", "?", "i", "'m", "sure", "!",
    ]),
    "they're not going? i'm sure!",
  )
  @test.assert_eq(
    decoder.decode(["do", "n't", "stop", ";", "test", ":", "ok", ",", "yes", "."]),
    "don't stop; test: ok, yes.",
  )
  @test.assert_eq(
    Decoder::wordpiece(prefix="##", cleanup=false).decode(["hi", "?", "there"]),
    "hi ? there",
  )
}
