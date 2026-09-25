// Unicode normalization correctness, cross-checked against Python unicodedata.

///|
test "NFC composes combining marks" {
  // "cafe" + U+0301 (combining acute) -> "café" (composed)
  let s = "cafe\u{301}"
  @test.assert_eq(@normalizer.Normalizer::NFC.normalize(s), "café")
  @test.assert_eq(@normalizer.Normalizer::NFC.normalize_str(s), "café")
}

///|
test "NFD decomposes" {
  // "é" (U+00E9) -> "e" + U+0301
  @test.assert_eq(@normalizer.Normalizer::NFD.normalize("é"), "e\u{301}")
}

///|
test "NFKC folds compatibility chars" {
  // fullwidth AB -> AB ; ﬁ ligature -> fi
  @test.assert_eq(
    @normalizer.Normalizer::NFKC.normalize("\u{ff21}\u{ff22}"),
    "AB",
  )
  @test.assert_eq(@normalizer.Normalizer::NFKC.normalize("\u{fb01}"), "fi")
}

///|
test "NFKC handles canonical ordering + recomposition" {
  // U+1E9B U+0323 -> NFKC U+1E69 (ṩ)
  @test.assert_eq(
    @normalizer.Normalizer::NFKC.normalize("\u{1e9b}\u{323}"),
    "\u{1e69}",
  )
}

///|
test "NFC is identity for plain ASCII" {
  @test.assert_eq(
    @normalizer.Normalizer::NFC.normalize("Hello, world!"),
    "Hello, world!",
  )
}

///|
test "ByteLevel normalizer maps utf8 bytes to visible alphabet" {
  @test.assert_eq(
    @normalizer.Normalizer::ByteLevel.normalize("Hello 我"),
    "HelloĠæĪĳ",
  )
}

///|
test "Precompiled normalizer applies SentencePiece NFKC charmap" {
  @test.assert_eq(
    @normalizer.Normalizer::Precompiled.normalize("ＡＢＣ １２３"),
    "ABC 123",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Precompiled.normalize("Ⅳ ① ㍿"),
    "IV 1 株式会社",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Precompiled.normalize("ﬁ ﬂ Å ㎏"),
    "fi fl Å kg",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Precompiled.normalize("㌀ ㍻ ㈱"),
    "アパート 平成 (株)",
  )
}

///|
test "Precompiled normalizer maps whitespace without collapsing runs" {
  @test.assert_eq(
    @normalizer.Normalizer::Precompiled.normalize("\u{a0}\t a\n\u{3000}b"),
    "   a  b",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Precompiled.normalize(
      "a\u{1680}b\u{2028}c\u{202f}d",
    ),
    "a b c d",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Precompiled.normalize("ascii\tfast\npath"),
    "ascii fast path",
  )
}

///|
test "Precompiled normalizer decodes tokenizer.json binary charsmap" {
  // Minimal SentencePiece double-array charsmap: maps byte key "A" -> "x".
  let charsmap = "DAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQQ0AAAAAAAB4AA=="
  let json = "{\"type\":\"Precompiled\",\"precompiled_charsmap\":\"" +
    charsmap +
    "\"}"
  let normalizer = @normalizer.Normalizer::from_json(@json.parse(json))
  @test.assert_eq(normalizer.normalize("ABC A"), "xBC x")
}

///|
test "Replace normalizer supports common regex whitespace patterns" {
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern=" {2,}", content=" ").normalize(
      "a   b c",
    ),
    "a b c",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\s+", content=" ").normalize(
      "a\t\u{a0}b\n\u{3000}c",
    ),
    "a b c",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\s{2,}", content="_").normalize(
      "a b  c\t\td",
    ),
    "a b_c_d",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\s]{3,}", content="_").normalize(
      "a \tb\n\n\nc    d",
    ),
    "a \tb_c_d",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\s{3}", content="_").normalize(
      "a \t\u{a0}b\n\n\nc    d",
    ),
    "a_b_c_ d",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^\\s+", content="").normalize(
      "\t \u{3000}abc ",
    ),
    "abc ",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\s+$", content="").normalize(
      " abc\u{a0}\n",
    ),
    " abc",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\r\\n]+", content="|").normalize(
      "a\r\nb\nc",
    ),
    "a|b|c",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\r\\n]{2,}", content="|").normalize(
      "a\r\nb\n\nc",
    ),
    "a|b|c",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\r\\n]{3}", content="|").normalize(
      "a\r\n\nb\n\nc",
    ),
    "a|b\n\nc",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^\\S\\r\\n]+", content="_").normalize(
      "a\t  b\n c",
    ),
    "a_b\n_c",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^\\S\\r\\n]{2,}", content="_").normalize(
      "a\t b c  d",
    ),
    "a_b c_d",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^\\S\\r\\n]{3,}", content="_").normalize(
      "a\t\u{a0} b\n  c    d",
    ),
    "a_b\n  c_d",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[ \\t]{3}", content="_").normalize(
      "a \t b\t\t\tc    d",
    ),
    "a_b_c_ d",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\d+", content="#").normalize(
      "a12b003",
    ),
    "a#b#",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\d]+", content="#").normalize(
      "a12b003",
    ),
    "a#b#",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\d]{2,}", content="#").normalize(
      "a1b12c１２3",
    ),
    "a1b#c#",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\d{1,3}", content="#").normalize(
      "a12345b",
    ),
    "a##b",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\d]{1,3}", content="#").normalize(
      "a12345b",
    ),
    "a##b",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\d{2}", content="#").normalize(
      "a12345b",
    ),
    "a##5b",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{Number}+", content="#").normalize(
      "a１２b٣",
    ),
    "a#b#",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\p{Number}]{4}", content="#").normalize(
      "a１２٣٤5b",
    ),
    "a#5b",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^\\d+", content="#").normalize(
      "123abc456",
    ),
    "#abc456",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\d+$", content="#").normalize(
      "123abc456",
    ),
    "123abc#",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\D+", content="_").normalize(
      "a12bc003",
    ),
    "_12_003",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\P{N}+", content="_").normalize(
      "a１２b٣",
    ),
    "_１２_٣",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\w+", content="W").normalize(
      "ab_12,中!cd",
    ),
    "W,W!W",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\w{2,}", content="W").normalize(
      "ab_12,x,cde",
    ),
    "W,x,W",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\w{2}", content="W").normalize(
      "ab_12,cde",
    ),
    "WW2,We",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\w{1,3}", content="W").normalize(
      "ab_12,cde",
    ),
    "WW,W",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\W+", content="-").normalize(
      "ab_12,中!cd",
    ),
    "ab_12-中-cd",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^\\w+", content="W").normalize(
      "ab_12,cd",
    ),
    "W,cd",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\w+$", content="W").normalize(
      "ab,cd_12",
    ),
    "ab,W",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[A-Za-z0-9]+", content="A").normalize(
      "ab_12,CD中",
    ),
    "A_A,A中",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[A-Za-z0-9]{3}", content="A").normalize(
      "ab12_cde中",
    ),
    "A2_A中",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^A-Za-z0-9]+", content="-").normalize(
      "ab_12,CD中",
    ),
    "ab-12-CD-",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^[A-Za-z0-9]+", content="A").normalize(
      "abc12_é",
    ),
    "A_é",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[A-Za-z0-9]+$", content="A").normalize(
      "é_abc12",
    ),
    "é_A",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[A-Za-z]+", content="A").normalize(
      "abé_12,CD中",
    ),
    "Aé_12,A中",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[A-Za-z]{2,}", content="A").normalize(
      "abé_cdef中",
    ),
    "Aé_A中",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[A-Za-z]{1,2}", content="A").normalize(
      "abc123DE",
    ),
    "AA123A",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^A-Za-z]+", content="-").normalize(
      "abé_12,CD中",
    ),
    "ab-CD-",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^[A-Za-z]+", content="A").normalize(
      "abc12é",
    ),
    "A12é",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[A-Za-z]+$", content="A").normalize(
      "12éabc",
    ),
    "12éA",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{L}+", content="L").normalize(
      "abé中12!Ж",
    ),
    "L12!L",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{L}{3}", content="L").normalize(
      "abé中12Жxy",
    ),
    "L中12L",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\P{L}+", content="-").normalize(
      "abé中12!Ж",
    ),
    "abé中-Ж",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^\\p{L}+", content="L").normalize(
      "Жabc12é",
    ),
    "L12é",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{L}+$", content="L").normalize(
      "12Жabc",
    ),
    "12L",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{P}+", content="_").normalize(
      "hi,!$+🙂ok。",
    ),
    "hi_$+🙂ok_",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{P}{2,}", content="_").normalize(
      "hi,!?ok。",
    ),
    "hi_ok。",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{P}{2}", content="_").normalize(
      "hi,!?ok。",
    ),
    "hi_?ok。",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{P}{1,3}", content="_").normalize(
      "hi!!!!ok。?",
    ),
    "hi__ok_",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^\\p{Punctuation}+", content="").normalize(
      "？！hello!",
    ),
    "hello!",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{Symbol}+", content="S").normalize(
      "a$+🙂,b=≤c",
    ),
    "aS,bSc",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{S}{2}", content="S").normalize(
      "a$+🙂,b=≤c",
    ),
    "aS🙂,bSc",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{S}+$", content="").normalize(
      "ok🙂+",
    ),
    "ok",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\p{P}\\p{S}]+", content="_").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab_ cd_42",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\p{P}\\p{S}]{2,}", content="_").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab_ cd。42",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\p{P}\\p{S}]{3}", content="_").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab_🙂 cd。42",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\p{P}\\p{S}]{1,3}", content="_").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab__ cd_42",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^\\s\\p{L}\\p{N}]+", content="#").normalize(
      "ab,$+🙂 cd。42",
    ),
    "ab# cd#42",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^[\\p{P}\\p{S}]+", content="").normalize(
      "?!$ok🙂+",
    ),
    "ok🙂+",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[\\p{P}\\p{S}]+$", content="").normalize(
      "ok🙂+",
    ),
    "ok",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\D{1,3}", content="_").normalize(
      "a12 bc003",
    ),
    "_12_003",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\W{1,2}", content="-").normalize(
      "ab_12,中!cd",
    ),
    "ab_12-中-cd",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^A-Za-z]{1,3}", content="-").normalize(
      "abé_12,CD中",
    ),
    "ab--CD-",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\P{L}{1,4}", content="-").normalize(
      "abé中12!🙂Ж",
    ),
    "abé中-Ж",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^\\p{P}\\p{S}]{1,3}", content="N").normalize(
      "ab,$+🙂 cd。42",
    ),
    "N,$+🙂N。N",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(
      pattern="[^\\s\\p{L}\\p{N}]{1,3}",
      content="#",
    ).normalize("ab,$+🙂 cd。42"),
    "ab## cd#42",
  )
}

///|
test "Replace normalizer supports anchored inverse regex families" {
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^\\S+", content="X").normalize(
      "abc\t tail",
    ),
    "X\t tail",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\D+$", content="_").normalize(
      "123abc中",
    ),
    "123_",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^\\P{Letter}+", content="").normalize(
      "123!?abc",
    ),
    "abc",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\P{Punctuation}+$", content="N").normalize(
      "?!abc🙂",
    ),
    "?!N",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="^[^\\p{P}\\p{S}]+", content="N").normalize(
      "abc12,$",
    ),
    "N,$",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^\\s\\p{L}\\p{N}]+$", content="").normalize(
      "abc42🙂+",
    ),
    "abc42",
  )
}

///|
test "normalizer exposes HF-style configuration getters" {
  let strip = @normalizer.Normalizer::Strip(left=true, right=false)
  @test.assert_eq(strip.kind(), "Strip")
  @test.assert_eq(strip.strip_left(), Some(true))
  @test.assert_eq(strip.get_strip_left(), Some(true))
  @test.assert_eq(strip.left(), Some(true))
  @test.assert_eq(strip.strip_right(), Some(false))
  @test.assert_eq(strip.get_strip_right(), Some(false))
  @test.assert_eq(strip.right(), Some(false))
  @test.assert_eq(@normalizer.Normalizer::NFC.left(), None)
  @test.assert_eq(@normalizer.Normalizer::NFC.right(), None)

  let replace = @normalizer.Normalizer::Replace(pattern="\\s+", content=" ")
  @test.assert_eq(replace.kind(), "Replace")
  @test.assert_eq(replace.pattern(), Some("\\s+"))
  @test.assert_eq(replace.get_pattern(), Some("\\s+"))
  @test.assert_eq(replace.pattern_kind(), Some(@common.RegexPattern))
  @test.assert_eq(replace.get_pattern_kind(), Some(@common.RegexPattern))
  @test.assert_eq(replace.content(), Some(" "))
  @test.assert_eq(replace.get_content(), Some(" "))

  let prepend = @normalizer.Normalizer::Prepend(prepend="▁")
  @test.assert_eq(prepend.kind(), "Prepend")
  @test.assert_eq(prepend.prepend(), Some("▁"))
  @test.assert_eq(prepend.get_prepend(), Some("▁"))

  @test.assert_eq(
    @normalizer.Normalizer::lowercase_normalizer().kind(),
    "Lowercase",
  )
  @test.assert_eq(
    @normalizer.Normalizer::lowercase_normalizer().normalize("ABC"),
    "abc",
  )
  @test.assert_eq(
    @normalizer.Normalizer::strip_accents_normalizer().kind(),
    "StripAccents",
  )
  // HF 0.22.2 standalone StripAccents only removes already-decomposed
  // marks; precomposed café is untouched (NFD "cafe" + U+0301 -> "cafe").
  @test.assert_eq(
    @normalizer.Normalizer::strip_accents_normalizer().normalize("café"),
    "café",
  )
  @test.assert_eq(
    @normalizer.Normalizer::strip_accents_normalizer().normalize("cafe\u{301}"),
    "cafe",
  )
  @test.assert_eq(@normalizer.Normalizer::nmt().kind(), "Nmt")
  @test.assert_eq(
    @normalizer.Normalizer::nmt().to_json(),
    Some("{\"type\":\"Nmt\"}"),
  )
  @test.assert_eq(@normalizer.Normalizer::precompiled().kind(), "Precompiled")
  @test.assert_eq(
    @normalizer.Normalizer::precompiled().to_json(),
    Some("{\"type\":\"Precompiled\"}"),
  )

  let bert = @normalizer.Normalizer::BertNormalizer(
    clean_text=true,
    handle_chinese_chars=false,
    strip_accents=Some(true),
    lowercase=false,
  )
  @test.assert_eq(bert.kind(), "BertNormalizer")
  @test.assert_eq(bert.clean_text(), Some(true))
  @test.assert_eq(bert.get_clean_text(), Some(true))
  @test.assert_eq(bert.handle_chinese_chars(), Some(false))
  @test.assert_eq(bert.get_handle_chinese_chars(), Some(false))
  @test.assert_eq(bert.strip_accents(), Some(true))
  @test.assert_eq(bert.get_strip_accents(), Some(true))
  @test.assert_eq(bert.lowercase(), Some(false))
  @test.assert_eq(bert.get_lowercase(), Some(false))

  let seq = @normalizer.Normalizer::Sequence([
    @normalizer.Normalizer::Lowercase,
    replace,
  ])
  @test.assert_eq(seq.kind(), "Sequence")
  @test.assert_eq(seq.normalizers().map(n => n.kind()), ["Lowercase", "Replace"])
  @test.assert_eq(seq.get_normalizers().map(n => n.kind()), [
    "Lowercase", "Replace",
  ])
  @test.assert_eq(seq.__len__(), 2)
  @test.assert_eq(seq.get_item(0).unwrap().kind(), "Lowercase")
  @test.assert_eq(seq.__getitem__(1).unwrap().kind(), "Replace")
  @test.assert_eq(seq.__getitem__(2) is None, true)
  let steps = seq.normalizers()
  steps.push(@normalizer.Normalizer::NFC)
  @test.assert_eq(seq.normalizers().length(), 2)
  let getter_steps = seq.get_normalizers()
  getter_steps.push(@normalizer.Normalizer::NFC)
  @test.assert_eq(seq.get_normalizers().length(), 2)
  @test.assert_eq(@normalizer.Normalizer::NFC.kind(), "NFC")
  @test.assert_eq(@normalizer.Normalizer::Lowercase.pattern(), None)
}

///|
test "normalizer HF-style factories wrap enum variants" {
  @test.assert_eq(@normalizer.Normalizer::nfc().kind(), "NFC")
  @test.assert_eq(@normalizer.Normalizer::nfd().kind(), "NFD")
  @test.assert_eq(@normalizer.Normalizer::nfkc().normalize("Ａ"), "A")
  @test.assert_eq(@normalizer.Normalizer::nfkd().kind(), "NFKD")
  @test.assert_eq(
    @normalizer.Normalizer::byte_level().normalize("Hi 我"),
    @normalizer.Normalizer::ByteLevel.normalize("Hi 我"),
  )

  let strip = @normalizer.Normalizer::strip(left=false)
  @test.assert_eq(strip.kind(), "Strip")
  @test.assert_eq(strip.strip_left(), Some(false))
  @test.assert_eq(strip.strip_right(), Some(true))
  @test.assert_eq(
    strip.to_json(),
    Some("{\"type\":\"Strip\",\"strip_left\":false,\"strip_right\":true}"),
  )

  let replace = @normalizer.Normalizer::replace("\\s+", " ")
  @test.assert_eq(replace.kind(), "Replace")
  @test.assert_eq(replace.pattern(), Some("\\s+"))
  @test.assert_eq(replace.pattern_kind(), Some(@common.StringPattern))
  @test.assert_eq(replace.content(), Some(" "))
  @test.assert_eq(replace.normalize("a b\tc \\s+"), "a b\tc  ")
  @test.assert_eq(
    replace.to_json(),
    Some(
      "{\"type\":\"Replace\",\"pattern\":{\"String\":\"\\\\s+\"},\"content\":\" \"}",
    ),
  )
  let regex_replace = @normalizer.Normalizer::replace_regex("\\s+", "_")
  @test.assert_eq(regex_replace.pattern_kind(), Some(@common.RegexPattern))
  @test.assert_eq(regex_replace.normalize("a b\tc \\s+"), "a_b_c_\\s+")
  @test.assert_eq(
    regex_replace.to_json(),
    Some(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"\\\\s+\"},\"content\":\"_\"}",
    ),
  )

  let prepend = @normalizer.Normalizer::prepend_normalizer("▁")
  @test.assert_eq(prepend.kind(), "Prepend")
  @test.assert_eq(prepend.prepend(), Some("▁"))
  @test.assert_eq(prepend.normalize("word"), "▁word")

  let bert = @normalizer.Normalizer::bert_normalizer(lowercase=false)
  @test.assert_eq(bert.kind(), "BertNormalizer")
  @test.assert_eq(bert.lowercase(), Some(false))
  @test.assert_eq(bert.strip_accents(), None)
  @test.assert_eq(bert.normalize("café ÀBC"), "café ÀBC")
  let forced_accents = @normalizer.Normalizer::bert_normalizer(
    lowercase=false,
    strip_accents=Some(true),
  )
  @test.assert_eq(forced_accents.strip_accents(), Some(true))
  @test.assert_eq(forced_accents.normalize("café ÀBC"), "cafe ABC")

  let default_accents = @normalizer.Normalizer::bert_normalizer(lowercase=true)
  @test.assert_eq(default_accents.strip_accents(), None)
  @test.assert_eq(default_accents.normalize("café ÀBC"), "cafe abc")
  @test.assert_eq(
    default_accents.to_json(),
    Some(
      "{\"type\":\"BertNormalizer\",\"clean_text\":true,\"handle_chinese_chars\":true,\"strip_accents\":null,\"lowercase\":true}",
    ),
  )

  let seq = @normalizer.Normalizer::sequence([
    @normalizer.Normalizer::nfc(),
    replace,
  ])
  @test.assert_eq(seq.kind(), "Sequence")
  @test.assert_eq(seq.normalizers().map(n => n.kind()), ["NFC", "Replace"])
}

///|
test "normalizer exposes JSON state and string aliases" {
  let norm = @normalizer.Normalizer::Sequence([
    @normalizer.Normalizer::Lowercase,
    @normalizer.Normalizer::Replace(pattern="\\s+", content=" "),
  ])
  let state = norm.__getstate__()
  @test.assert_eq(norm.__str__(), state.json)
  @test.assert_eq(norm.__repr__(), state.json)
  @test.assert_eq(
    @normalizer.Normalizer::__setstate__(state).to_json(),
    norm.to_json(),
  )

  let parsed = @normalizer.Normalizer::from_state(
    @normalizer.NormalizerState::new(
      "{\"type\":\"Strip\",\"strip_left\":true,\"strip_right\":false}",
    ),
  )
  @test.assert_eq(parsed.kind(), "Strip")
  @test.assert_eq(parsed.strip_right(), Some(false))

  let string_replace = @normalizer.Normalizer::from_state(
    @normalizer.NormalizerState::new(
      "{\"type\":\"Replace\",\"pattern\":{\"String\":\"\\\\s+\"},\"content\":\"_\"}",
    ),
  )
  @test.assert_eq(string_replace.pattern_kind(), Some(@common.StringPattern))
  @test.assert_eq(string_replace.normalize("a b\tc \\s+"), "a b\tc _")
  @test.assert_eq(
    @normalizer.Normalizer::__setstate__(string_replace.__getstate__()).to_json(),
    string_replace.to_json(),
  )

  let regex_replace = @normalizer.Normalizer::from_state(
    @normalizer.NormalizerState::new(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"\\\\s+\"},\"content\":\"_\"}",
    ),
  )
  @test.assert_eq(regex_replace.pattern_kind(), Some(@common.RegexPattern))
  @test.assert_eq(regex_replace.normalize("a b\tc \\s+"), "a_b_c_\\s+")
  @test.assert_eq(
    @normalizer.Normalizer::__setstate__(regex_replace.__getstate__()).to_json(),
    regex_replace.to_json(),
  )

  let parsed_bert = @normalizer.Normalizer::from_state(
    @normalizer.NormalizerState::new(
      "{\"type\":\"BertNormalizer\",\"clean_text\":true,\"handle_chinese_chars\":true,\"strip_accents\":null,\"lowercase\":false}",
    ),
  )
  @test.assert_eq(parsed_bert.kind(), "BertNormalizer")
  @test.assert_eq(parsed_bert.strip_accents(), None)
  @test.assert_eq(parsed_bert.normalize("café ÀBC"), "café ÀBC")
  @test.assert_eq(
    @normalizer.Normalizer::__setstate__(parsed_bert.__getstate__()).to_json(),
    parsed_bert.to_json(),
  )
}

///|
test "normalizer state rejects components without serialized JSON" {
  let json = "{\"type\":\"Precompiled\",\"precompiled_charsmap\":\"" +
    "DAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQQ0AAAAAAAB4AA==" +
    "\"}"
  let norm = @normalizer.Normalizer::from_json(@json.parse(json))
  let mut raised = false
  try norm.__getstate__() |> ignore catch {
    @types.UnsupportedComponent(_) => raised = true
    _ => ()
  }
  @test.assert_eq(raised, true)
}

///|
/// Unsupported regex families in a normalizer Replace must fail at LOAD
/// time (no-silent-mismatch); supported families keep loading. Probed
/// against the fixture inventory: real models only use `\s+`, ` {2,}`,
/// and String literals — all supported.
test "normalizer Replace regex unsupported patterns fail at load" {
  // assert_raise keeps the failure outside any swallowing catch
  let json : Json = @json.parse(
    "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"l+o\"},\"content\":\"X\"}",
  )
  @test.assert_raise(() => @normalizer.Normalizer::from_json(json))
  // supported families load: whitespace runs, min runs, literals
  let ok1 = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"\\\\s+\"},\"content\":\" \"}",
    ),
  )
  @test.assert_eq(ok1.kind(), "Replace")
  let ok2 = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\" {2,}\"},\"content\":\" \"}",
    ),
  )
  @test.assert_eq(ok2.kind(), "Replace")
  let ok3 = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"café\"},\"content\":\"x\"}",
    ),
  )
  @test.assert_eq(ok3.kind(), "Replace")
  let ok4 = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"\\\\p{N}{2,}\"},\"content\":\"N\"}",
    ),
  )
  @test.assert_eq(ok4.kind(), "Replace")
  // String patterns are literal by design — no gate
  let ok5 = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"String\":\"a.b\"},\"content\":\"X\"}",
    ),
  )
  @test.assert_eq(ok5.kind(), "Replace") // String patterns share the kind
}

///|
/// Adversarial regex-family divergences fixed per PR #13 review —
/// expectations probed from Python `tokenizers` 0.22.2 (Regex variants).
test "replace regex anchors are multiline" {
  let ws_tail = @normalizer.Normalizer::Replace(pattern="\\s+$", content="#")
  @test.assert_eq(
    ws_tail.normalize("xy\t\t12\t34\n\n56\r\n78"),
    "xy\t\t12\t34#\n56#\n78",
  )
  @test.assert_eq(ws_tail.normalize("x  \n\n  y"), "x#\n  y")
  let head = @normalizer.Normalizer::Replace(pattern="^\\s+", content="#")
  @test.assert_eq(head.normalize("\tA\n  B\nC"), "#A\n#B\nC")
  // a greedy run from a line head spans newlines: "\n\n  B" -> "#B" in one match
  @test.assert_eq(head.normalize("\n\n  B"), "#B")
  @test.assert_eq(head.normalize("A\n\n  B"), "A\n#B")
}

///|
/// ASCII-only class spellings vs Unicode shortcuts: `[0-9]`/`[A-Za-z0-9_]`
/// never match fullwidth/accented characters while `\d`/`\w` do.
test "replace regex ascii class spellings stay ascii" {
  let ascii_digit = @normalizer.Normalizer::Replace(
    pattern="[0-9]",
    content="#",
  )
  @test.assert_eq(ascii_digit.normalize("a5b7"), "a#b#")
  @test.assert_eq(ascii_digit.normalize("a０b"), "a０b")
  let uni_digit = @normalizer.Normalizer::Replace(pattern="\\d", content="#")
  @test.assert_eq(uni_digit.normalize("a０b"), "a#b")
  let ascii_word = @normalizer.Normalizer::Replace(
    pattern="[A-Za-z0-9_]",
    content="#",
  )
  @test.assert_eq(ascii_word.normalize("aé中b"), "#é中#")
  let uni_word = @normalizer.Normalizer::Replace(pattern="\\w", content="#")
  @test.assert_eq(uni_word.normalize("aé中b"), "####")
  // quantified spellings inherit the ASCII mapping
  let ascii_min = @normalizer.Normalizer::Replace(
    pattern="[0-9]{2,}",
    content="#",
  )
  @test.assert_eq(ascii_min.normalize("x55y"), "x#y")
  @test.assert_eq(ascii_min.normalize("x０１y"), "x０１y")
}

///|
/// A brace that is not part of a valid quantifier is a literal character
/// (onig semantics): `a{b` / `x}y` load and replace literally.
test "replace regex literal braces" {
  let open_brace = @normalizer.Normalizer::Replace(pattern="a{b", content="#")
  @test.assert_eq(open_brace.normalize("za{bz"), "z#z")
  let close_brace = @normalizer.Normalizer::Replace(pattern="x}y", content="#")
  @test.assert_eq(close_brace.normalize("ax}yay"), "a#ay")
  // valid quantifier braces still parse as a quantifier family
  let two = @normalizer.Normalizer::Replace(pattern="[0-9]{2}", content="#")
  @test.assert_eq(two.normalize("x55y"), "x#y")
}

///|
/// Review round 2: plain-`+` ASCII spellings, bare Unicode letter family,
/// `{,n}` explicit rejection, decoder bare classes.
test "replace regex ascii plus spellings and unicode letter bare" {
  // plain + (no anchor) previously bypassed the ASCII override
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[0-9]+", content="#").normalize(
      "a０b",
    ),
    "a０b",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[0-9]+", content="#").normalize(
      "a55b",
    ),
    "a#b",
  )
  // inverse of ASCII class IS Unicode-wide: ０ matches [^0-9]
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^0-9]+", content="#").normalize(
      "a０b",
    ),
    "#",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[A-Za-z0-9_]+", content="#").normalize(
      "aé中b",
    ),
    "#é中#",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="[^A-Za-z0-9_]+", content="#").normalize(
      "１２３",
    ),
    "#",
  )
  // bare \p{L} is the UNICODE letter family (é/中 match), not [A-Za-z]
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{L}", content="#").normalize(
      "aé中b",
    ),
    "####",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\p{L}", content="#").normalize(
      "中5é_0",
    ),
    "#5#_0",
  )
  @test.assert_eq(
    @normalizer.Normalizer::Replace(pattern="\\P{L}", content="#").normalize(
      "a中5",
    ),
    "a中#",
  )
  // `{,n}` is the quantifier {0,n} in onig (probed 0.22.2: 'zaaz' with
  // a{,2} -> '#z#z#'); it loads and behaves as zero-min
  let comma_open = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"a{,3}\"},\"content\":\"X\"}",
    ),
  )
  @test.assert_eq(comma_open.kind(), "Replace")
  @test.assert_eq(comma_open.normalize("zaaaz"), "XzXzX")
}

///|
/// `[\w]`-family bracket spellings are Unicode-wide (HF probes) and
/// accepted across the quantifier/anchored tables via canonicalization to
/// the shortcut forms; anchored newline class and single-char literal
/// bounded quantifiers join the supported set.
test "replace regex w-bracket, anchored newline, literal quantifiers" {
  // kind 26/27 spelling-aware split (PR #17 design, implemented here):
  // bracket [\w] is class-context — onig Latin-1 quirks are NON-word
  // there (HF-probed) while bare \w includes them.
  let w2 = @normalizer.Normalizer::Replace(pattern="[\\w]{2}", content="#")
  @test.assert_eq(w2.normalize("x\u{b2}y"), "x\u{b2}y") // no 2-run without quirks
  @test.assert_eq(w2.normalize("ab\u{b2}"), "#\u{b2}")
  @test.assert_eq(w2.normalize("ab"), "#")
  let wplus = @normalizer.Normalizer::Replace(pattern="[\\w]+", content="#")
  @test.assert_eq(wplus.normalize("x\u{b2}y"), "#\u{b2}#") // run splits at quirk
  let winv = @normalizer.Normalizer::Replace(pattern="[^\\w]+", content="#")
  @test.assert_eq(winv.normalize("x\u{b2}y"), "x#y") // quirk matches inverse
  @test.assert_eq(winv.normalize("\uff11\uff12\uff13"), "\uff11\uff12\uff13") // fullwidth digits are word
  let wmin = @normalizer.Normalizer::Replace(pattern="[\\w]{2,}", content="#")
  @test.assert_eq(wmin.normalize("ab\u{b2}cd"), "#\u{b2}#")
  let wbare = @normalizer.Normalizer::Replace(pattern="\\w", content="#")
  @test.assert_eq(wbare.normalize("\u{b2}"), "#") // bare includes quirks
  let wanch = @normalizer.Normalizer::Replace(pattern="[\\w]+$", content="#")
  @test.assert_eq(wanch.normalize("ab\u{b2}"), "ab\u{b2}") // no trailing word run
  let whead = @normalizer.Normalizer::Replace(pattern="^[\\w]+", content="#")
  @test.assert_eq(whead.normalize("\u{b2}ab"), "\u{b2}ab")
  // anchored newline class
  let nl_head = @normalizer.Normalizer::Replace(
    pattern="^[\\r\\n]+",
    content="#",
  )
  @test.assert_eq(nl_head.normalize("\n\nx"), "#x")
  let nl_tail = @normalizer.Normalizer::Replace(
    pattern="[\\r\\n]+$",
    content="#",
  )
  @test.assert_eq(nl_tail.normalize("x\n\n"), "x#")
  // literal bounded quantifiers
  let lit = @normalizer.Normalizer::Replace(pattern="a{2}", content="#")
  @test.assert_eq(lit.normalize("zaaz"), "z#z")
  let lit_range = @normalizer.Normalizer::Replace(pattern="a{2,3}", content="#")
  @test.assert_eq(lit_range.normalize("zaaaay"), "z#ay")
  let lit_min = @normalizer.Normalizer::Replace(pattern="a{2,}", content="#")
  @test.assert_eq(lit_min.normalize("zaaaaz"), "z#z")
  // {0,m} zero-minimum quantifiers are now supported (onig empty-match
  // semantics, HF-probed: a{0,2} on "zaaz" -> "#z#z#")
  let zm = @normalizer.Normalizer::Replace(pattern="a{0,2}", content="#")
  @test.assert_eq(zm.normalize("zaaz"), "#z#z#")
}

///|
/// End-to-end `\w` families over the PR #16 review's divergent inputs —
/// expectations from direct HF probes (fullwidth letters/digits, halfwidth
/// katakana, µ/ª/Roman numerals all match; circled digits/emoji do not).
test "replace w families over full onig coverage" {
  let w2 = @normalizer.Normalizer::Replace(pattern="\\w{2}", content="#")
  @test.assert_eq(w2.normalize("ａｂ"), "#")
  @test.assert_eq(w2.normalize("ｱｲ"), "#")
  let w1 = @normalizer.Normalizer::Replace(pattern="\\w", content="#")
  @test.assert_eq(w1.normalize("µ"), "#")
  @test.assert_eq(w1.normalize("ª"), "#")
  @test.assert_eq(w1.normalize("Ⅷ"), "#")
  @test.assert_eq(w1.normalize("½"), "#")
  @test.assert_eq(w1.normalize("①"), "①")
  @test.assert_eq(w1.normalize("😀"), "😀")
  let inv = @normalizer.Normalizer::Replace(pattern="[^\\w]+", content="#")
  @test.assert_eq(inv.normalize("，。！"), "#")
}

///|
/// Inverse bracket spellings (`[\W]`/`[^\w]`) ride the same
/// kind-27 rows; expectations HF-probed.
test "replace regex inverse w-bracket spellings" {
  let inv_exact = @normalizer.Normalizer::Replace(
    pattern="[^\\w]{2}",
    content="#",
  )
  @test.assert_eq(inv_exact.normalize("²³"), "#") // quirks match inverse
  let inv_notw = @normalizer.Normalizer::Replace(
    pattern="[^\\W]{2}",
    content="#",
  )
  @test.assert_eq(inv_notw.normalize("ab"), "#")
  let inv_ranged = @normalizer.Normalizer::Replace(
    pattern="[^\\w]{2,3}",
    content="#",
  )
  @test.assert_eq(inv_ranged.normalize("²³a²"), "#a²")
  let inv_head = @normalizer.Normalizer::Replace(
    pattern="^[^\\W]+",
    content="#",
  )
  @test.assert_eq(inv_head.normalize("²ab"), "²ab")
  let inv_tail = @normalizer.Normalizer::Replace(
    pattern="[^\\W]+$",
    content="#",
  )
  @test.assert_eq(inv_tail.normalize("ab²"), "ab²")
  // greedy bounded: HF [\w]{2,3} on 'abcd²' -> '#d²' (abc then d<min)
  let ranged = @normalizer.Normalizer::Replace(
    pattern="[\\w]{2,3}",
    content="#",
  )
  @test.assert_eq(ranged.normalize("abcd²"), "#d²")
}

///|
/// Review fixes: bounded inverse-bracket rows no longer shadowed by kind 13;
/// ranged {3,4} inverse spellings; Split gate accepts the bracket + forms.
test "replace regex bracket review fixes" {
  // F1: [^w]{1,n} must be kind 27 (quirks match the inverse)
  let inv_b = @normalizer.Normalizer::Replace(
    pattern="[^\\w]{1,2}",
    content="#",
  )
  @test.assert_eq(inv_b.normalize("x²³y"), "x#y")
  @test.assert_eq(inv_b.normalize("²"), "#")
  // F2: {3,4} inverses load and behave
  let inv34 = @normalizer.Normalizer::Replace(
    pattern="[^\\w]{3,4}",
    content="#",
  )
  @test.assert_eq(inv34.normalize("²²²²"), "#")
  let pos34 = @normalizer.Normalizer::Replace(
    pattern="[^\\W]{3,4}",
    content="#",
  )
  @test.assert_eq(pos34.normalize("abcd"), "#")
  // bare w bounded is unchanged (quirks still word)
  let bare_b = @normalizer.Normalizer::Replace(pattern="\\w{1,2}", content="#")
  @test.assert_eq(bare_b.normalize("²a"), "#")
}

///|
/// Zero-minimum quantifiers (`a{0}`, `a{0,m}`, `a{0,}`, class bases):
/// onig global-replace empty-match semantics, every expectation probed
/// against Python 0.22.2 (empty match adjacent to previous match end is
/// skipped; inserted empty matches copy one char; end-of-string empty
/// inserts only when not adjacent; empty input never matches).
test "replace zero-min quantifiers follow onig empty-match semantics" {
  let zm = @normalizer.Normalizer::Replace(pattern="a{0,2}", content="#")
  @test.assert_eq(zm.normalize("zaaz"), "#z#z#")
  @test.assert_eq(zm.normalize("zzz"), "#z#z#z#")
  @test.assert_eq(zm.normalize("aaa"), "##") // greedy consumes, no trailing empty
  @test.assert_eq(zm.normalize(""), "")
  @test.assert_eq(zm.normalize("ab"), "#b#") // mid empty adjacent-skipped
  @test.assert_eq(zm.normalize("ba"), "#b#")
  let exact0 = @normalizer.Normalizer::Replace(pattern="a{0}", content="#")
  @test.assert_eq(exact0.normalize("zaz"), "#z#a#z#")
  @test.assert_eq(exact0.normalize("aaa"), "#a#a#a#") // even matching chars copied
  let unbounded = @normalizer.Normalizer::Replace(pattern="a{0,}", content="#")
  @test.assert_eq(unbounded.normalize("zaaz"), "#z#z#")
  let digit = @normalizer.Normalizer::Replace(pattern="[0-9]{0,2}", content="#")
  @test.assert_eq(digit.normalize("z55y"), "#z#y#")
  let uni_digit = @normalizer.Normalizer::Replace(
    pattern="\\d{0,2}",
    content="#",
  )
  @test.assert_eq(uni_digit.normalize("z55y"), "#z#y#")
  let word = @normalizer.Normalizer::Replace(pattern="\\w{0,2}", content="#")
  @test.assert_eq(word.normalize("ab!"), "#!#")
  let ws = @normalizer.Normalizer::Replace(pattern="\\s{0,2}", content="#")
  @test.assert_eq(ws.normalize("x  y"), "#x#y#")
  let bracket = @normalizer.Normalizer::Replace(
    pattern="[\\w]{0,2}",
    content="#",
  )
  @test.assert_eq(bracket.normalize("a²b"), "#²#") // quirk is class-non-word
}

///|
/// Onig rejects repeat bounds above 100000 ("too big number for repeat
/// range", probed 0.22.2: `a{0,100000}` loads, `a{0,100001}` errors) —
/// the zero-min spec stops matching there so the load gate raises
/// instead of accepting an overflowed bound.
test "zero-min quantifier max bound follows onig 100000 limit" {
  @test.assert_eq(
    @common.zero_min_quantifier_spec("a{0,100000}"),
    Some((-1, Some('a'), 100000)),
  )
  @test.assert_eq(@common.zero_min_quantifier_spec("a{0,100001}"), None)
  @test.assert_eq(
    @common.zero_min_quantifier_spec("a{0,99999999999999999999}"),
    None,
  )
  @test.assert_raise(() => {
    @normalizer.Normalizer::from_json(
      @json.parse(
        "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"a{0,100001}\"},\"content\":\"#\"}",
      ),
    )
  })
}

///|
/// `\p{N}`/`\p{Number}` spellings are FULL N (Nd + Nl + No) while `\d`
/// stays Nd and `[0-9]` ASCII — every expectation probed against Python
/// 0.22.2 on the battery "a²¼Ⅰ①₃0５\u{1FBF0}" (² ¼ ① ₃ = No, Ⅰ = Nl,
/// 0 = ASCII Nd, ５ = fullwidth Nd, U+1FBF0 = Unicode-14 mathematical
/// digit that the old hard-coded Nd intervals missed).
test "p{N} full-N vs d-Nd split matches onig semantics" {
  let s = "a²¼Ⅰ①₃0５\u{1FBF0}"
  fn n(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\p{N}").normalize(s), "a########")
  @test.assert_eq(n("\\p{Number}").normalize(s), "a########")
  @test.assert_eq(n("[\\p{N}]").normalize(s), "a########")
  @test.assert_eq(n("\\P{N}").normalize(s), "#²¼Ⅰ①₃0５\u{1FBF0}")
  @test.assert_eq(n("[^\\p{N}]").normalize(s), "#²¼Ⅰ①₃0５\u{1FBF0}")
  // \d = Nd incl. fullwidth ５ and U+1FBF0, excluding No/Nl
  @test.assert_eq(n("\\d").normalize(s), "a²¼Ⅰ①₃###")
  @test.assert_eq(n("[0-9]").normalize(s), "a²¼Ⅰ①₃#５\u{1FBF0}")
  @test.assert_eq(n("\\d+").normalize(s), "a²¼Ⅰ①₃#")
  @test.assert_eq(n("\\p{N}+").normalize(s), "a#")
  @test.assert_eq(n("\\P{N}+").normalize(s), "#²¼Ⅰ①₃0５\u{1FBF0}")
  @test.assert_eq(n("\\p{N}{2}").normalize(s), "a####")
  @test.assert_eq(n("\\p{N}{1,3}").normalize(s), "a###")
  @test.assert_eq(n("^\\p{N}+").normalize(s), s)
  @test.assert_eq(n("\\p{N}+$").normalize(s), "a#")
  @test.assert_eq(n("\\p{N}{2,}").normalize(s), "a#")
}

///|
/// Kind split sanity: the `\p{N}` spellings resolve to kind 28/29 and
/// `\d` stays 11 in every entry table.
test "p{N} spellings map to full-N kinds" {
  @test.assert_eq(@common.bare_class_kind("\\p{N}"), Some(28))
  @test.assert_eq(@common.bare_class_kind("\\p{Number}"), Some(28))
  @test.assert_eq(@common.bare_class_kind("[\\p{N}]"), Some(28))
  @test.assert_eq(@common.bare_class_kind("\\P{N}"), Some(29))
  @test.assert_eq(@common.bare_class_kind("[^\\p{Number}]"), Some(29))
  @test.assert_eq(@common.bare_class_kind("\\d"), Some(11))
  @test.assert_eq(@common.bounded_regex_kind("\\p{N}{1,2}"), Some((28, 2)))
  @test.assert_eq(@common.bounded_regex_kind("\\d{1,2}"), Some((11, 2)))
  // the predicate split itself
  @test.assert_eq(@common.is_unicode_number('²'), true)
  @test.assert_eq(@common.is_unicode_number('Ⅰ'), true)
  @test.assert_eq(@common.is_unicode_number('x'), false)
  @test.assert_eq(@common.is_decimal_number('²'), false)
  @test.assert_eq(@common.is_decimal_number('\u{1FBF0}'), true)
}

///|
/// `\P{N}{1,n}` bounded negatives are the complement of FULL N (review
/// fix: they were left on the kind-14 Nd complement). Probed 0.22.2.
test "p{N} bounded negatives complement full N" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\P{N}{1,2}").normalize("aⅠb"), "#Ⅰ#")
  @test.assert_eq(n("\\P{N}{1,2}").normalize("abcⅠde"), "##Ⅰ#")
  @test.assert_eq(n("\\P{N}{1,3}").normalize("aⅠbc"), "#Ⅰ#")
  @test.assert_eq(@common.bounded_regex_kind("\\P{N}{1,2}"), Some((29, 2)))
  @test.assert_eq(@common.bounded_regex_kind("\\D{1,2}"), Some((14, 2)))
  @test.assert_eq(n("\\P{N}{1,2}").normalize_aligned("aⅠb").0, "#Ⅰ#")
}

///|
/// `\b` word boundaries use the UNICODE `\w` definition (bare table
/// incl. onig quirks), distinct from the ASCII class they wrap: a
/// `\b[A-Za-z0-9_]+\b` match requires the run's neighbors to be
/// non-word. Every expectation probed against 0.22.2 — 'a²b' has NO
/// match (² is a word char, no boundary between a|²), '¼ab½'/'²ab'/
/// 'aéb'/'a1²2b' none, while the bare class replaces every ASCII run
/// and `\b\w+\b` merges whole Unicode word runs.
test "word boundaries are unicode-aware for ascii-class spellings" {
  let bats : Array[String] = [
    "a²b", "ab²c", "²ab", "ab²", "aéb", "a中b", "x_1y", "hello world", "a1²2b",
    "¼ab½", "ab", "", "²", "a",
  ]
  let wrapped = @normalizer.Normalizer::Replace(
    pattern="\\b[A-Za-z0-9_]+\\b",
    content="#",
  )
  let want_w : Array[String] = [
    "a²b", "ab²c", "²ab", "ab²", "aéb", "a中b", "#", "# #", "a1²2b", "¼ab½",
    "#", "", "²", "#",
  ]
  let bare = @normalizer.Normalizer::Replace(
    pattern="[A-Za-z0-9_]+",
    content="#",
  )
  let want_b : Array[String] = [
    "#²#", "#²#", "²#", "#²", "#é#", "#中#", "#", "# #", "#²#", "¼#½", "#",
    "", "²", "#",
  ]
  let wordw = @normalizer.Normalizer::Replace(pattern="\\b\\w+\\b", content="#")
  let want_wd : Array[String] = [
    "#", "#", "#", "#", "#", "#", "#", "# #", "#", "#", "#", "", "#", "#",
  ]
  for i, s in bats {
    @test.assert_eq(wrapped.normalize(s), want_w[i])
    @test.assert_eq(wrapped.normalize_aligned(s).0, want_w[i])
    @test.assert_eq(bare.normalize(s), want_b[i])
    @test.assert_eq(wordw.normalize(s), want_wd[i])
  }
}

///|
/// Cheap fail-explicitly extensions, every expectation probed against
/// 0.22.2: `{,n}` is the quantifier `{0,n}` (comma-open bound, min 0);
/// leading zeros are equivalent (`a{00}` == `a{0}`, `a{01}` == `a{1}`,
/// `a{0,02}` == `a{0,2}`); escaped literal bases (`\n` `\t` `\\` `.`)
/// carry their quantifiers. The empty `{,}` stays a literal (unchanged).
test "comma-open bounds, leading zeros, escaped bases compute" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("a{,2}").normalize("za{,2}z"), "#z#{#,#2#}#z#")
  @test.assert_eq(n("a{,2}").normalize("zaaz"), "#z#z#")
  @test.assert_eq(n("a{,2}").normalize("zaaaaz"), "#z##z#")
  @test.assert_eq(n("a{,0}").normalize("zaz"), "#z#a#z#")
  @test.assert_eq(n("\\s{,2}").normalize("x  y"), "#x#y#")
  @test.assert_eq(n("5{,3}").normalize("z555y"), "#z#y#")
  @test.assert_eq(n("a{,}").normalize("zaaz"), "zaaz") // literal, not a quantifier
  @test.assert_eq(n("a{00}").normalize("zaz"), "#z#a#z#")
  @test.assert_eq(n("a{00}").normalize("zaaz"), "#z#a#a#z#")
  @test.assert_eq(n("a{01}").normalize("zaaz"), "z##z")
  @test.assert_eq(n("a{002}").normalize("zaz"), "zaz")
  @test.assert_eq(n("a{02}").normalize("zaaaz"), "z#az")
  @test.assert_eq(n("a{0,02}").normalize("zaaz"), "#z#z#")
  @test.assert_eq(n("a{000,2}").normalize("zaaz"), "#z#z#")
  @test.assert_eq(n("\\n{0,2}").normalize("z\n\nz"), "#z#z#")
  @test.assert_eq(n("\\n{2}").normalize("z\n\nz"), "z#z")
  @test.assert_eq(n("\\t{2}").normalize("a\t\tb"), "a#b")
  @test.assert_eq(n("\\n{0}").normalize("z\nz"), "#z#\n#z#")
  @test.assert_eq(n("\\\\{2}").normalize("a\\\\b"), "a#b")
  @test.assert_eq(n("\\.{2}").normalize("a..b"), "a#b")
  // aligned path agrees on a sample
  @test.assert_eq(n("a{,2}").normalize_aligned("zaaz").0, "#z#z#")
  @test.assert_eq(n("\\n{0,2}").normalize_aligned("z\n\nz").0, "#z#z#")
  // spec-level shape checks
  @test.assert_eq(
    @common.zero_min_quantifier_spec("a{,2}"),
    Some((-1, Some('a'), 2)),
  )
  @test.assert_eq(
    @common.zero_min_quantifier_spec("a{00}"),
    Some((-1, Some('a'), 0)),
  )
  @test.assert_eq(@common.zero_min_quantifier_spec("a{,}"), None)
  @test.assert_eq(@common.char_bounded_spec("\\n{2}"), Some(('\n', 2, 2)))
  @test.assert_eq(@common.char_bounded_spec("\\.{2}"), Some(('.', 2, 2)))
}

///|
/// The mixed-class complement family accepts every ordering of its
/// three members, short and long property names (probed 0.22.2:
/// `[^...]+` on 'a² b' matches nothing — a, ², space are all covered;
/// '!!' matches).
test "mixed-class complement orderings all accepted" {
  let pats : Array[String] = [
    "[^\\p{Number}\\p{Letter}\\s]+", "[^\\p{L}\\s\\p{N}]+", "[^\\p{N}\\s\\p{L}]+",
    "[^\\s\\p{Number}\\p{Letter}]+", "[^\\p{Letter}\\p{Number}\\s]+", "[^\\p{Number}\\s\\p{Letter}]+",
    "[^\\p{Number}\\p{Letter}\\s]{2,3}", "[^\\p{L}\\s\\p{N}]{1,2}",
  ]
  for p in pats {
    let n = @normalizer.Normalizer::Replace(pattern=p, content="#")
    @test.assert_eq(n.normalize("a² b"), "a² b")
    @test.assert_eq(n.normalize("!!"), "#")
    @test.assert_eq(n.normalize_aligned("!!").0, "#")
  }
}

///|
/// Review fixes: escaped-base bounded quantifiers must be reachable from
/// the LOAD path (the gate twin previously rejected them), `a{,}` is a
/// literal that loads, and the mixed-class anchored/exact orderings are
/// accepted. Probed 0.22.2 (`a{,}` on 'xa{,}x' -> 'x#x').
test "escaped bases load; a{,} is a literal that loads" {
  let esc = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"\\\\n{2}\"},\"content\":\"#\"}",
    ),
  )
  @test.assert_eq(esc.normalize("z\n\nz"), "z#z")
  let dot = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"\\\\.{2}\"},\"content\":\"#\"}",
    ),
  )
  @test.assert_eq(dot.normalize("a.b..c"), "a.b#c")
  let comma_empty = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"a{,}\"},\"content\":\"#\"}",
    ),
  )
  @test.assert_eq(comma_empty.normalize("xa{,}x"), "x#x")
  @test.assert_eq(comma_empty.normalize("zaaz"), "zaaz")
  // gate coverage for the escaped bounded/ranged window
  @test.assert_eq(@common.is_supported_replace_regex("\\t{2}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\t{2,3}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\r{2,}"), true)
  // anchored + exact mixed-class orderings load
  @test.assert_eq(
    @common.is_supported_replace_regex("^[^\\p{Number}\\p{Letter}\\s]+"),
    true,
  )
  @test.assert_eq(
    @common.is_supported_replace_regex("[^\\p{L}\\s\\p{N}]{2}"),
    true,
  )
}

///|
/// LAZY quantifier suffixes under global replace (probed 0.22.2, three
/// families):
///   `{0-族}?`  (`{0}?`/`{,n}?`/`{0,n}?`/`{0,}?`/`{00}?) == `{0}`
///   `{n}?`    exact — exact-n block when the run reaches n, otherwise
///             the empty-match walk ('zaaz' -> '#z#z#' but 'za' -> '#z#a#')
///   `{n,m}?`/`{n,}?` == greedy exact `{n}` (block n, remainder kept,
///             NO empty matches)
test "lazy quantifier suffixes collapse per probed families" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  // zero-min lazy == {0}
  @test.assert_eq(n("a{,2}?").normalize("zaaz"), "#z#a#a#z#")
  @test.assert_eq(n("a{0,2}?").normalize("zaaz"), "#z#a#a#z#")
  @test.assert_eq(n("a{0}?").normalize("zaaz"), "#z#a#a#z#")
  @test.assert_eq(n("a{0,}?").normalize("zaaz"), "#z#a#a#z#")
  @test.assert_eq(n("a{,2}?").normalize("zaaaaz"), "#z#a#a#a#a#z#")
  @test.assert_eq(n("\\s{0,2}?").normalize("x  y"), "#x# # #y#")
  @test.assert_eq(n("a{00}?").normalize("zaaz"), "#z#a#a#z#")
  @test.assert_eq(n("\\n{0,2}?").normalize("z\n\nz"), "#z#\n#\n#z#")
  @test.assert_eq(n("a{,2}?").normalize("za{,2}z"), "#z#a#{#,#2#}#z#")
  // lazy exact {n}?
  @test.assert_eq(n("a{2}?").normalize("zaaz"), "#z#z#")
  @test.assert_eq(n("a{2}?").normalize("zaaaaz"), "#z##z#")
  @test.assert_eq(n("a{2}?").normalize("za"), "#z#a#")
  @test.assert_eq(n("a{2}?").normalize("z"), "#z#")
  @test.assert_eq(n("a{2}?").normalize("aa"), "#")
  @test.assert_eq(n("a{2}?").normalize("aab"), "#b#")
  @test.assert_eq(n("a{3}?").normalize("zaaz"), "#z#a#a#z#")
  @test.assert_eq(n("a{3}?").normalize("zaaaz"), "#z#z#")
  @test.assert_eq(n("a{4}?").normalize("aa aa"), "#a#a# #a#a#")
  @test.assert_eq(n("a{1}?").normalize("zaaz"), "#z##z#")
  @test.assert_eq(n("\\n{2}?").normalize("z\n\n\nz"), "#z#\n#z#")
  @test.assert_eq(n("5{2}?").normalize("z5555y"), "#z##y#")
  // lazy ranged {n,m}? / {n,}? == exact {n}, no empty matches
  @test.assert_eq(n("a{2,3}?").normalize("zaaz"), "z#z")
  @test.assert_eq(n("a{2,3}?").normalize("zaaaz"), "z#az")
  @test.assert_eq(n("a{2,3}?").normalize("zaaaaz"), "z##z")
  @test.assert_eq(n("a{2,3}?").normalize("zaaaaaaaaz"), "z####z")
  @test.assert_eq(n("a{2,3}?").normalize("zaz"), "zaz")
  @test.assert_eq(n("a{2,}?").normalize("zaaaz"), "z#az")
  @test.assert_eq(n("a{2,}?").normalize("zaz"), "zaz")
  @test.assert_eq(n("a{3,4}?").normalize("zaaaaaaz"), "z##z")
  @test.assert_eq(n("\\s{2,3}?").normalize("x    y"), "x##y")
  @test.assert_eq(n("\\n{2,}?").normalize("z\n\n\n\nz"), "z##z")
  @test.assert_eq(n("\\t{2,3}?").normalize("a\t\t\tb"), "a#\tb")
  // aligned agrees; load path accepts all three families
  @test.assert_eq(n("a{2}?").normalize_aligned("zaaz").0, "#z#z#")
  @test.assert_eq(n("a{2,3}?").normalize_aligned("zaaaz").0, "z#az")
  let loaded = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"a{2,3}?\"},\"content\":\"#\"}",
    ),
  )
  @test.assert_eq(loaded.normalize("zaaaz"), "z#az")
  let le = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"a{2}?\"},\"content\":\"#\"}",
    ),
  )
  @test.assert_eq(le.normalize("zaaz"), "#z#z#")
  @test.assert_eq(@common.lazy_normalize("a{,2}?"), Some("a{0}"))
  @test.assert_eq(@common.lazy_normalize("a{2,3}?"), Some("a{2}"))
  @test.assert_eq(@common.lazy_normalize("a{2,}?"), Some("a{2}"))
  @test.assert_eq(@common.lazy_normalize("a{2}?"), None) // own family
  @test.assert_eq(@common.lazy_exact_spec("a{2}?"), Some((-1, Some('a'), 2, 2)))
  @test.assert_eq(@common.lazy_exact_spec("a{2}"), None)
}

///|
/// Lazy-bound validation hardening (review fixes): leading-zero values
/// route by VALUE (`a{02}?` is exact-2 lazy, probed: 'zaaz' -> '#z#z#',
/// 'zaaaz' -> '#z#a#z#'), invalid tails stay literals (`a{0,2x}?` gate
/// false), the 100000 cap covers `{0,N}?`, escaped-brace bases and
/// reversed ranges fail explicitly.
test "lazy bound validation follows parsed values" {
  @test.assert_eq(@common.is_supported_replace_regex("a{02}?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a{02,3}?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a{0,2x}?"), false)
  @test.assert_eq(@common.is_supported_replace_regex("a{0,100001}?"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\{0,2}?"), false)
  // reversed range now supported: onig swaps to (?:a{2,3})? — see the
  // dedicated reversed-range lock test below
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("a{02}?").normalize("zaaz"), "#z#z#")
  @test.assert_eq(n("a{02}?").normalize("zaaaz"), "#z#a#z#")
  @test.assert_eq(n("a{0002}?").normalize("zaaz"), "#z#z#")
  @test.assert_eq(n("a{02,3}?").normalize("zaaaz"), "z#az")
  @test.assert_eq(
    @common.lazy_exact_spec("a{02}?"),
    Some((-1, Some('a'), 2, 2)),
  )
  @test.assert_eq(@common.lazy_exact_spec("a{00}?"), None)
  @test.assert_eq(@common.lazy_normalize("a{02,3}?"), Some("a{2}"))
}

///|
/// Escaped-backslash lazy bases (even backslash run before `{` — the
/// brace is a real quantifier; probed 0.22.2) vs escaped-brace bases
/// (odd run — literal pattern). Review fix: the guard counts parity.
test "backslash parity guards escaped-brace vs escaped-backslash lazy" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\\\{0,2}?").normalize("z\\\\z"), "#z#\\#\\#z#")
  @test.assert_eq(n("\\\\{2}?").normalize("z\\\\z"), "#z#z#")
  @test.assert_eq(n("\\\\{2,3}?").normalize("z\\\\\\\\z"), "z##z")
  @test.assert_eq(n("\\\\{0}?").normalize("z\\z"), "#z#\\#z#")
  // odd run: escaped brace — literal, gate rejects
  @test.assert_eq(@common.is_supported_replace_regex("\\{0,2}?"), false)
}

///|
/// REVERSED ranges `base{n,m}?` with n > m: onig swaps to
/// `(?:X{m,n})?` — greedy ranged blocks plus the empty-match walk.
/// Every expectation probed 0.22.2.
test "reversed lazy ranges swap to ranged-blocks-plus-empties" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("a{3,2}?").normalize("zaaz"), "#z#z#")
  @test.assert_eq(n("a{3,2}?").normalize("aaaaa"), "##")
  @test.assert_eq(n("a{3,2}?").normalize("zaaaaaaaaz"), "#z###z#")
  @test.assert_eq(n("a{3,2}?").normalize("zaz"), "#z#a#z#")
  @test.assert_eq(n("a{3,2}?").normalize("za"), "#z#a#")
  @test.assert_eq(n("a{3,2}?").normalize("zaaaaz"), "#z#a#z#")
  @test.assert_eq(n("a{3,2}?").normalize("zaaaaaaz"), "#z##z#")
  @test.assert_eq(n("a{3,2}?").normalize("aabaa"), "#b#")
  @test.assert_eq(n("a{2,1}?").normalize("zaaz"), "#z#z#")
  @test.assert_eq(n("a{4,2}?").normalize("aaaa"), "#")
  @test.assert_eq(n("a{4,2}?").normalize("aaaaaa"), "##")
  @test.assert_eq(n("\\s{3,2}?").normalize("x   y"), "#x#y#")
  @test.assert_eq(n("\\s{4,2}?").normalize("x    y"), "#x#y#")
  @test.assert_eq(n("5{3,2}?").normalize("z555y"), "#z#y#")
  @test.assert_eq(n("a{3,2}?").normalize(""), "")
  @test.assert_eq(n("a{3,2}?").normalize_aligned("zaaaaz").0, "#z#a#z#")
  @test.assert_eq(
    @common.lazy_exact_spec("a{3,2}?"),
    Some((-1, Some('a'), 2, 3)),
  )
  @test.assert_eq(@common.is_supported_replace_regex("a{3,2}?"), true)
  let loaded = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"a{3,2}?\"},\"content\":\"#\"}",
    ),
  )
  @test.assert_eq(loaded.normalize("zaaz"), "#z#z#")
}

///|
/// DOUBLE-anchored `^BASE QUANT $`: whole-line matching under the
/// multiline option — each line whose ENTIRE content satisfies the
/// class and length window; greedy runs may cross newlines when the
/// class includes them. Every expectation probed 0.22.2.
test "double-anchored whole-line matching" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  let mixed = "^[^\\s\\p{L}\\p{N}]+$"
  @test.assert_eq(n(mixed).normalize("!!"), "#")
  @test.assert_eq(n(mixed).normalize("!!x!!"), "!!x!!")
  @test.assert_eq(n(mixed).normalize("x"), "x")
  @test.assert_eq(n(mixed).normalize(""), "")
  @test.assert_eq(n(mixed).normalize("!!\n!!"), "#\n#")
  @test.assert_eq(n(mixed).normalize("!!\nx!!"), "#\nx!!")
  @test.assert_eq(n(mixed).normalize("a\n!!\nb"), "a\n#\nb")
  @test.assert_eq(n(mixed).normalize("!!\r\n!!"), "!!\r\n#")
  @test.assert_eq(n("^\\w+$").normalize("ab"), "#")
  @test.assert_eq(n("^\\w+$").normalize("a b"), "a b")
  @test.assert_eq(n("^\\w+$").normalize("a\nb"), "#\n#")
  @test.assert_eq(n("^\\d+$").normalize("123"), "#")
  @test.assert_eq(n("^\\d+$").normalize("12a"), "12a")
  @test.assert_eq(n("^a+$").normalize("aaa"), "#")
  @test.assert_eq(n("^a+$").normalize("aab"), "aab")
  @test.assert_eq(n("^\\s+$").normalize("  "), "#")
  @test.assert_eq(n("^\\s+$").normalize(" \n "), "#") // \s crosses \n
  @test.assert_eq(n("^\\n+$").normalize("\n\n"), "#")
  @test.assert_eq(n("^[0-9]{2,}$").normalize("1234"), "#")
  @test.assert_eq(n("^[0-9]{2,}$").normalize("1"), "1")
  @test.assert_eq(n("^\\w{1,3}$").normalize("ab"), "#")
  @test.assert_eq(n("^\\w{1,3}$").normalize("abcd"), "abcd")
  @test.assert_eq(n("^\\p{N}+$").normalize("²¼"), "#")
  @test.assert_eq(n("^[^\\w]+$").normalize("!!"), "#")
  @test.assert_eq(n("^[^\\p{Number}\\p{Letter}\\s]+$").normalize("!!"), "#")
  @test.assert_eq(n(mixed).normalize_aligned("a\n!!\nb").0, "a\n#\nb")
  @test.assert_eq(@common.double_anchored_spec(mixed), Some((21, None, 1, -1)))
  @test.assert_eq(
    @common.double_anchored_spec("^\\w{1,3}$"),
    Some((4, None, 1, 3)),
  )
  @test.assert_eq(
    @common.double_anchored_spec("^a+$"),
    Some((-1, Some('a'), 1, -1)),
  )

  @test.assert_eq(@common.is_supported_replace_regex(mixed), true)
}

///|
/// Sub-lo remainder tails walk the empty rules (review fix): after the
/// greedy blocks, every remainder position past the prev_end-adjacent
/// one fires an empty match — `a{3}?` on 'aaaaa' is '#a#a#' (not
/// '#aa#'). Reversed shapes with m >= 3 behave the same.
test "lazy remainder tails keep interior empty matches" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("a{3}?").normalize("aaaaa"), "#a#a#")
  @test.assert_eq(n("a{3}?").normalize("zaaaaaz"), "#z#a#a#z#")
  @test.assert_eq(n("a{4}?").normalize("zaaaaaaz"), "#z#a#a#z#")
  @test.assert_eq(n("a{4}?").normalize("zaaaaaaaz"), "#z#a#a#a#z#")
  @test.assert_eq(n("\\s{3}?").normalize("x     y"), "#x# # #y#")
  @test.assert_eq(n("a{4,3}?").normalize("zaaaaaaz"), "#z#a#a#z#")
  @test.assert_eq(n("a{5,3}?").normalize("zaaaaaaaz"), "#z#a#a#z#")
}

///|
/// Remaining double-anchored spellings (review follow-ups, probed
/// 0.22.2): quantifier-less `^BASE$` == `^BASE{1}$` with multiline
/// whole-line semantics (a single-char window never crosses lines —
/// `^\n$` on "\n\n" gives two matches); reversed `^a{3,2}$` swaps to
/// the {2,3} window like its lazy twin; a lazy tail before the `$` is
/// identical (whole-line windows have no lazy/greedy difference); and
/// escaped-operator bases (`^\+$`) carry the '+' inside the base (odd
/// backslash run), distinct from `^\\+$` (escaped backslash + the
/// quantifier).
test "quantifier-less, reversed, lazy-tail, escaped-operator double anchors" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^a$").normalize("a"), "#")
  @test.assert_eq(n("^a$").normalize("a\na"), "#\n#")
  @test.assert_eq(n("^a$").normalize("ab\na"), "ab\n#")
  @test.assert_eq(n("^a$").normalize("b\na\nb"), "b\n#\nb")
  @test.assert_eq(n("^a$").normalize(""), "")
  @test.assert_eq(n("^\\s$").normalize(" \n "), "#\n#")
  @test.assert_eq(n("^\\s$").normalize("\n \n"), "\n#\n")
  @test.assert_eq(n("^5$").normalize("5\n55"), "#\n55")
  @test.assert_eq(n("^\\w$").normalize("a\nb"), "#\n#")
  @test.assert_eq(n("^\\+$").normalize("+\n+"), "#\n#")
  @test.assert_eq(n("^\\.$").normalize(".\n."), "#\n#")
  @test.assert_eq(n("^\\\\$").normalize("\\\n\\"), "#\n#")
  @test.assert_eq(n("^\\n$").normalize("\n\n"), "##")
  @test.assert_eq(n("^a{3,2}$").normalize("aa"), "#")
  @test.assert_eq(n("^a{3,2}$").normalize("aaaa"), "aaaa")
  @test.assert_eq(n("^a{3,2}$").normalize("aaa"), "#")
  @test.assert_eq(n("^a{3,2}$").normalize("aaaaa"), "aaaaa")
  @test.assert_eq(n("^a{3,2}$").normalize("aa\naaaa"), "#\naaaa")
  @test.assert_eq(n("^5{3,2}$").normalize("555"), "#")
  // lazy tails and \n-spanning reversed windows fail EXPLICITLY: HF's
  // optional/atomic semantics (empty matches at ^-and-$ positions,
  // shortest-line-end, no backtracking after the swap) are a different
  // engine capability — reject beats silently approximating (probed:
  // ^a{3,2}?$ on newline-newline -> hash-nl-hash-nl; ^\s{4,2}$ on
  // "spaces \nx" unchanged)
  @test.assert_eq(@common.is_supported_replace_regex("^a{3,2}?$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^a{2,0}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\s{4,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\n{3,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^[\\r\\n]{3,2}$"), false)
  @test.assert_eq(n("^a$").normalize_aligned("a\na").0, "#\n#")
  @test.assert_eq(
    @common.double_anchored_spec("^a$"),
    Some((-1, Some('a'), 1, 1)),
  )
  @test.assert_eq(
    @common.double_anchored_spec("^a{3,2}$"),
    Some((-1, Some('a'), 2, 3)),
  )
  @test.assert_eq(
    @common.double_anchored_spec("^\\+$"),
    Some((-1, Some('+'), 1, 1)),
  )
  @test.assert_eq(
    @common.double_anchored_spec("^\\\\+$"),
    Some((-1, Some('\\'), 1, -1)),
  )
  @test.assert_eq(@common.is_supported_replace_regex("^a$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^\\+$"), true)
  let loaded = @normalizer.Normalizer::from_json(
    @json.parse(
      "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"^a$\"},\"content\":\"#\"}",
    ),
  )
  @test.assert_eq(loaded.normalize("a\na"), "#\n#")
}

///|
/// Swapped-window guards are SEMANTIC (review fix): any class whose
/// predicate matches '\n' rejects the reversed swap (atomic vs
/// backtracking divergence — \D, \W, [^0-9], raw/escaped newline), and
/// the lazy-'?' rejection is escape-aware so `^\?$` (literal question
/// base) keeps its multiline whole-line semantics.
test "swap guards are semantic; escaped question mark loads" {
  @test.assert_eq(@common.is_supported_replace_regex("^\\D{3,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\W{4,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^[^0-9]{3,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\P{L}{3,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\d{3,2}$"), true) // \n-free pred
  let q = @normalizer.Normalizer::Replace(pattern="^\\?$", content="#")
  @test.assert_eq(q.normalize("\n?\n"), "\n#\n")
  @test.assert_eq(q.normalize("?"), "#")
  @test.assert_eq(q.normalize("??"), "??")
}

///|
/// MULTILINE anchored literal matching (probed 0.22.2): `^lit` at
/// every line start, `lit$` at every line end, `^lit$` when a whole
/// line equals the literal — the anchored wrapper previously matched
/// the whole STRING only, silently no-opping multiline input while the
/// gate claimed support. `\r` belongs to its line (CRLF: only the
/// second line matches `^ab$`).
test "anchored literals match per line" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^ab$").normalize("ab"), "#")
  @test.assert_eq(n("^ab$").normalize("ab\nab"), "#\n#")
  @test.assert_eq(n("^ab$").normalize("ab\na"), "#\na")
  @test.assert_eq(n("^ab$").normalize("a\nab\nb"), "a\n#\nb")
  @test.assert_eq(n("^ab$").normalize("abab"), "abab")
  @test.assert_eq(n("^ab$").normalize("ab\r\nab"), "ab\r\n#")
  @test.assert_eq(n("^ab$").normalize(""), "")
  @test.assert_eq(n("^!!$").normalize("!!\r\n!!"), "!!\r\n#")
  @test.assert_eq(n("^a b$").normalize("a b\na b"), "#\n#")
  @test.assert_eq(n("^\\{2}$").normalize("x\n{2}\ny"), "x\n#\ny")
  @test.assert_eq(n("^\\{1,2}$").normalize("{1,2}\n{"), "#\n{")
  @test.assert_eq(n("^ab").normalize("ab\nab"), "#\n#")
  @test.assert_eq(n("^ab").normalize("abx"), "#x")
  @test.assert_eq(n("ab$").normalize("ab\nab"), "#\n#")
  @test.assert_eq(n("ab$").normalize("xab"), "x#")
  @test.assert_eq(n("^ab").normalize("x\nabx"), "x\n#x")
  @test.assert_eq(n("ab$").normalize("xab\nx"), "x#\nx")
  @test.assert_eq(n("^ab$").normalize_aligned("a\nab\nb").0, "a\n#\nb")
}

///|
/// Review fixes for per-line anchored literals: literals containing
/// newlines span lines under the anchors (`a\nb$` on 'xa\nb' ->
/// 'x#'; `\n\n$` collapses a trailing blank line; `^a\nb$` matches
/// across lines), and `lit$` alternations pick the LEFTMOST start
/// (longest alternative first — `(?:b|ab)$` on 'ab' matches [0,2)).
test "anchored literals span newlines and pick leftmost ends" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\n\\n$").normalize("a\n\n"), "a#")
  @test.assert_eq(n("a\\nb$").normalize("xa\nb"), "x#")
  @test.assert_eq(n("^a\\nb$").normalize("a\nb"), "#")
  @test.assert_eq(n("^\\n\\n$").normalize("\n\n"), "#")
  @test.assert_eq(n("(?:b|ab)$").normalize("ab"), "#")
  @test.assert_eq(n("(?:b|ab)$").normalize("ab\nab"), "#\n#")
  @test.assert_eq(n("(?:b|xb)$").normalize("axb"), "a#")
  @test.assert_eq(n("^a\\na").normalize("a\na\na"), "#\na")
}

///|
/// `lit$` tie-break is DECLARATION order at the leftmost start (not
/// length — probed both declaration orders against 0.22.2:
/// `(?:\n\n|\n)$` on 'a\n\n' -> 'a#' taking the first-listed spanning
/// alternative; the reversed declaration gives 'a##').
test "end-anchored alternation ties break by declaration order" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("(?:\\n\\n|\\n)$").normalize("a\n\n"), "a#")
  @test.assert_eq(n("(?:\\n|\\n\\n)$").normalize("a\n\n"), "a##")
  @test.assert_eq(n("(?:a|aaa\\nb)$").normalize("aaa\nbb"), "aa#\nbb")
  @test.assert_eq(n("(?:b|ab)$").normalize("ab"), "#")
  @test.assert_eq(n("(?:b|xb)$").normalize("axb"), "a#")
}

///|
/// Dot-base whole-line family (probed 0.22.2): `.` matches any char
/// EXCEPT newline (onig default — `^.{3,2}$` on 'a\nb' is unchanged),
/// dot-sequences are fixed-length windows (`^..$`), quantified forms
/// carry lo/hi (`^.{1,3}$`), reversed windows swap like other \n-free
/// bases.
test "dot-base whole-line windows" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^.$").normalize("a\nab\nb"), "#\nab\n#")
  @test.assert_eq(n("^.$").normalize("\n"), "\n")
  @test.assert_eq(n("^..$").normalize("ab\ncd\nabc"), "#\n#\nabc")
  @test.assert_eq(n("^.{1,3}$").normalize("ab\nabcd\nx"), "#\nabcd\n#")
  @test.assert_eq(n("^.{2,}$").normalize("ab\nabc\na"), "#\n#\na")
  @test.assert_eq(n("^...$").normalize("abc\nab"), "#\nab")
  @test.assert_eq(n("^.{3,2}$").normalize("ab\ncd"), "#\n#")
  @test.assert_eq(n("^.{3,2}$").normalize("a\nb"), "a\nb")
  @test.assert_eq(n("^.{4,2}$").normalize("abc\nd"), "#\nd")
  @test.assert_eq(n("^.{2,3}$").normalize("ab\nabc\nabcd"), "#\n#\nabcd")
  @test.assert_eq(n("^.$").normalize_aligned("a\nab\nb").0, "#\nab\n#")
  @test.assert_eq(@common.double_anchored_spec("^..$"), Some((30, None, 2, 2)))
}

///|
/// PER-BRANCH anchors on alternations (probed 0.22.2): onig binds
/// them per branch — `^foo|bar$` == (^foo)|(bar$), so on
/// 'foo\nfoobar' BOTH line-start foos match AND the trailing bar of
/// foobar ('#\n##'). Branches may be (?:...)-wrapped; ties at the same
/// start follow declaration order; merged matches never overlap.
test "per-branch anchored alternations" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^foo|bar$").normalize("foo\nfoobar"), "#\n##")
  @test.assert_eq(n("^foo|bar$").normalize("bar\nxbar"), "#\nx#")
  @test.assert_eq(n("^foo|^bar").normalize("foo\nbar\nxb"), "#\n#\nxb")
  @test.assert_eq(n("foo$|bar$").normalize("xfoo\nxbar"), "x#\nx#")
  @test.assert_eq(n("^foo|bar").normalize("foox\nxbar"), "#x\nx#")
  @test.assert_eq(n("(?:^foo)|(?:bar$)").normalize("foo\nfoobar"), "#\n##")
  @test.assert_eq(n("^a|^b").normalize("a\nb\nc"), "#\n#\nc")
  @test.assert_eq(
    n("^foo|bar$|baz").normalize("foo\nbar\nbaz\nxbaz"),
    "#\n#\n#\nx#",
  )
  @test.assert_eq(n("^foo|bar$").normalize_aligned("foo\nfoobar").0, "#\n##")
  // grouped global-anchor form keeps its old semantics (whole group)
  @test.assert_eq(
    n("^(?:foo|bar)$").normalize("foo\nbar\nfoobar"),
    "#\n#\nfoobar",
  )
}

///|
/// Branch declaration-order ties at the same start (probed 0.22.2).
test "branch ties follow declaration order" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^ab|a").normalize("ab"), "#")
  @test.assert_eq(n("a|^ab").normalize("ab"), "#b")
}

///|
/// Review fixes: plain branches collect every occurrence (the greedy
/// merge owns overlap suppression — `ax|xxx` on 'axxxx' -> '##'), and
/// quantified multi-dot windows fail explicitly (a trailing quantifier
/// binds to the LAST dot: `^..+$` is >=2 chars/line, out of scope).
test "branch merge owns overlap; quantified multi-dot rejects" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("ax|xxx").normalize("axxxx"), "##")
  @test.assert_eq(n("xxx|ax").normalize("axxxx"), "##")
  @test.assert_eq(n("foo|bar").normalize("foobar"), "##")
  @test.assert_eq(n("ab|b").normalize("abab"), "##")
  @test.assert_eq(n("aa|a").normalize("aaa"), "##")
  @test.assert_eq(@common.is_supported_replace_regex("^..+$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^..{2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^..$"), true)
  @test.assert_eq(n("^..$").normalize("ab\nabc"), "#\nabc")
}

///|
/// `\b` binds PER BRANCH on top-level alternations (probed 0.22.2:
/// `\bfoo|bar\b` == `(\bfoo)|(bar\b)` — on 'foobar' -> '##', since
/// the leading \bfoo matches at the string start AND bar\b at the
/// string end; on 'foo\nfoobar' -> '#\n##'). The grouped global form
/// `\b(?:foo|bar)\b` keeps applying both boundaries to the group.
test "word boundaries bind per branch on alternations" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\bfoo|bar\\b").normalize("foobar"), "##")
  @test.assert_eq(n("\\bfoo|bar\\b").normalize("foo\nfoobar"), "#\n##")
  @test.assert_eq(n("\\bfoo|bar\\b").normalize("foo xbar baz"), "# x# baz")
  @test.assert_eq(n("\\bfoo|bar").normalize("xbar foo"), "x# #")
  @test.assert_eq(n("a|b\\b").normalize("ab"), "##")
  @test.assert_eq(n("\\bfoo\\b|bar").normalize("foo bar foobar"), "# # foo#")
  @test.assert_eq(n("foo\\b|\\bbar").normalize("foobar"), "foobar")
  @test.assert_eq(n("\\ba|\\bb").normalize("a b ab"), "# # #b")
  @test.assert_eq(n("\\bfoo|bar\\b").normalize_aligned("foobar").0, "##")
}

///|
/// `^`-anchored branches keep their per-branch `\b` too (review fix:
/// the b_start loop had been left on the always-false parameters —
/// `^foo\b|bar` on 'foobar' is 'foo#' in HF, not '##').
test "caret branches keep per-branch word boundaries" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^foo\\b|bar").normalize("foobar"), "foo#")
  @test.assert_eq(n("^\\bfoo\\b|bar").normalize("foobar"), "foo#")
  @test.assert_eq(n("^foo\\b|bar").normalize("foobar\n"), "foo#\n")
  @test.assert_eq(n("^\\b foo|zzz").normalize(" foo"), " foo")
}

///|
/// EMPTY branches on top-level alternations (probed 0.22.2): an empty
/// branch is a zero-width assertions-only alternative walked with the
/// zero-min prev_end rules — declaration order wins a position outright
/// (an adjacent empty ABANDONS the whole position, onig does not retry
/// later branches: 'a||b' on 'ab' -> '#b#'), the end-of-string empty
/// fires only when not adjacent, and empty input never matches.
test "empty branches walk the zero-min rules" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^|a").normalize("ba"), "#b#")
  @test.assert_eq(n("^|a").normalize("ab"), "#ab")
  @test.assert_eq(n("^|a").normalize("ba\nab"), "#b#\n#ab")
  @test.assert_eq(n("^|a").normalize(""), "")
  @test.assert_eq(n("a$|").normalize("ab"), "#a#b#")
  @test.assert_eq(n("a$|").normalize("a b"), "#a# #b#")
  @test.assert_eq(n("|^a").normalize("ba"), "#b#a#")
  @test.assert_eq(n("a|").normalize("ab"), "#b#")
  @test.assert_eq(n("a|").normalize("a b"), "# #b#")
  @test.assert_eq(n("|a").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\b|a").normalize("ab"), "#ab#")
  @test.assert_eq(n("\\b|\\b").normalize("ba"), "#ba#")
  @test.assert_eq(n("\\b|\\b").normalize("ba\nab"), "#ba#\n#ab#")
  @test.assert_eq(n("^|$").normalize("ba"), "#ba#")
  @test.assert_eq(n("^|$").normalize("ba\nab"), "#ba#\n#ab#")
  @test.assert_eq(n("^|$").normalize("a b"), "#a b#")
  @test.assert_eq(n("a||b").normalize("ba"), "#b#")
  @test.assert_eq(n("a||b").normalize("ab"), "#b#")
  @test.assert_eq(n("a||b").normalize("a b"), "# #b#")
  @test.assert_eq(n("^|").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\bfoo|").normalize("ba\nab"), "#b#a#\n#a#b#")
  @test.assert_eq(n("^|a|b$").normalize("ab"), "#a#")
  @test.assert_eq(n("^|a|b$").normalize("ba\nab"), "#b#\n#a#")
  @test.assert_eq(n("a||b").normalize_aligned("a b").0, "# #b#")
  @test.assert_eq(@common.is_supported_replace_regex("^|a"), true)
}

///|
/// BARE assertion sequences (`\b$`, `^\b`, `\b\b`, `$\b`, `^\b$`,
/// `^$`, `^`): zero-width at every position where ALL assertions hold,
/// walked with the zero-min rules. Multiline `^` never matches the
/// string-end position (probed: `^$` on 'ab\n' unchanged, `^` on
/// 'ab' -> '#ab' with no end hit). Every want probed 0.22.2.
test "bare assertion sequences walk zero-min positions" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\b$").normalize("ab\ncd"), "ab#\ncd#")
  @test.assert_eq(n("\\b$").normalize("ab"), "ab#")
  @test.assert_eq(n("\\b$").normalize("a b"), "a b#")
  @test.assert_eq(n("\\b$").normalize(""), "")
  @test.assert_eq(n("\\b$").normalize("!!"), "!!")
  @test.assert_eq(n("^\\b").normalize("ab\ncd"), "#ab\n#cd")
  @test.assert_eq(n("^\\b").normalize(" ab"), " ab")
  @test.assert_eq(n("\\b\\b").normalize("ab"), "#ab#")
  @test.assert_eq(n("\\b").normalize("ab"), "#ab#")
  @test.assert_eq(n("^\\b$").normalize("ab"), "ab")
  @test.assert_eq(n("$\\b").normalize("ab"), "ab#")
  @test.assert_eq(n("^$").normalize("a\n"), "a\n")
  @test.assert_eq(n("^$").normalize("a\n\n"), "a\n#\n")
  @test.assert_eq(n("^$").normalize("x\n\ny"), "x\n#\ny")
  @test.assert_eq(n("^").normalize("ab"), "#ab")
  @test.assert_eq(n("a|^$").normalize("ab"), "#b")
  @test.assert_eq(n("^|").normalize("ab"), "#a#b#")
  @test.assert_eq(n("^\\b").normalize("ab"), "#ab")
  @test.assert_eq(n("^$").normalize("\n\n"), "#\n#\n")
  @test.assert_eq(n("\\b$").normalize_aligned("ab\ncd").0, "ab#\ncd#")
}

///|
/// ZERO-MIN double-anchored windows (`^.{0,2}$`, `^a{0}$`, `^.{0,}$`,
/// comma-open `^{,m}$`): empty lines match (probed), the string-end
/// empty line never does (the `^` rule), and literal/class bases carry
/// the window through comma-open bounds.
test "zero-min double-anchored windows match empty lines" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^.{0,2}$").normalize("ab\nabc\n\na"), "#\nabc\n#\n#")
  @test.assert_eq(n("^.{0,2}$").normalize("\n"), "#\n")
  @test.assert_eq(n("^.{0,2}$").normalize(""), "")
  @test.assert_eq(n("^.{0}$").normalize("a\n\nb"), "a\n#\nb")
  @test.assert_eq(n("^.{0}$").normalize("a\n"), "a\n")
  @test.assert_eq(n("^.{0}$").normalize("\n\n\n"), "#\n#\n#\n")
  @test.assert_eq(n("^.{0,}$").normalize("ab\n\na"), "#\n#\n#")
  @test.assert_eq(n("^.{,2}$").normalize("ab\nabc"), "#\nabc")
  @test.assert_eq(n("^.{0,2}$").normalize("ab\n\n"), "#\n#\n")
  @test.assert_eq(n("^a{0}$").normalize("a\n\n"), "a\n#\n")
  @test.assert_eq(n("^a{0}$").normalize("\n\n"), "#\n#\n")
  @test.assert_eq(n("^a{,2}$").normalize("zaaaz"), "zaaaz")
  @test.assert_eq(n("^5{,2}$").normalize("55\n555\n"), "#\n555\n")
  @test.assert_eq(n("^\\s{,2}$").normalize(" x\n  y"), " x\n  y")
  @test.assert_eq(n("^\\d{,3}$").normalize("12\n1234\n"), "#\n1234\n")
  @test.assert_eq(
    n("^.{0,2}$").normalize_aligned("ab\nabc\n\na").0,
    "#\nabc\n#\n#",
  )
}

///|
/// \n-matching predicates under zero-min windows: the greedy scan
/// spans newlines (one whole match, probed `^\s{0,2}$` on `'\n\n'` →
/// `'#'`), except exact-zero (`^\s{0}$` → `'#\n#\n'` per empty line —
/// hi == 0 keeps the empty-line path). Review fix.
test "nl-pred window classes reject explicitly" {
  // ANY window over a \n-matching predicate fails at load — probed
  // 0.22.2 shows idiosyncratic consecutive-newline anchor behavior on
  // every bound (\\s{1,2}$ on 'a\\n\\nb' matches nothing while a
  // greedy-backtracking model matches [1,2)); reject beats silently
  // approximating. \\n-excluding predicates keep their windows.
  @test.assert_eq(@common.is_supported_replace_regex("^\\s{0,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\s{0}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\s{1,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\s{2,4}$"), false)
  //  and quantifier-less nl-pred forms keep their PR#34/#36 behavior
  @test.assert_eq(@common.is_supported_replace_regex("^\\s+$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^\\s$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^\\n+$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^\\n{2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\D{0,}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\s{,2}$"), false)
  // `+` and quantifier-less nl-pred forms keep their PR#34/#36 behavior
  @test.assert_eq(@common.is_supported_replace_regex("^\\s+$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^\\s$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^\\n+$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^\\w{1,3}$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^.{0,2}$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^a{0,2}$"), true)
}

///|
/// Replace-side literal-char spelling `[\r\n]` (raw CR/LF in the
/// pattern string) is per-char like the escaped spelling (review
/// note; HF probed 0.22.2: 'a\r\r\nb' -> 'a###b').
test "replace literal bracket crlf is per char" {
  let n = @normalizer.Normalizer::Replace(pattern="[\r\n]", content="#")
  @test.assert_eq(n.normalize("a\r\r\nb"), "a###b")
  @test.assert_eq(n.normalize("a\n\nb"), "a##b")
}

///|
/// Bare classes were already correct on the replace side (bare_class_kind
/// exact-1); the gap was `[\s]+` (gate-rejected) — now routed through
/// the whitespace-run family (issue #47; all wants probed 0.22.2).
test "replace bare classes and bracket ws spelling" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\s").normalize("a b2²"), "a#b2²")
  @test.assert_eq(n("[\\s]").normalize("a b2²"), "a#b2²")
  @test.assert_eq(n("\\w").normalize("a b2²"), "# ###")
  @test.assert_eq(n("[0-9]").normalize("a b2²"), "a b#²")
  @test.assert_eq(n("[\\p{L}]").normalize("a b2²"), "# #2²")
  @test.assert_eq(n("[^\\w]").normalize("a b2²"), "a#b2#")
  @test.assert_eq(n("\\p{N}").normalize("a b2²"), "a b##")
  @test.assert_eq(n("[\\s]+").normalize("a b  2²"), "a#b#2²")
  @test.assert_eq(n("[\\s]+").normalize_aligned("a b  2²").0, "a#b#2²")
  @test.assert_eq(@common.is_supported_replace_regex("[\\s]+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\s"), true)
}

///|
/// Literal-quantifier windows above 4 (probed 0.22.2): onig's real
/// repeat bound is 100000 — `a{5}`/`^a{5}$`/`^a{4,6}$`/leading-zero
/// `a{05}`/reversed `a{6,4}` (swapped to {4,6} blocks) all compute
/// with the same engines; `{100001}` errors at load on both sides.
/// Unanchored CLASS windows >4 (`\w{5}`) remain rejected — they route
/// through the hardcoded quantifier spelling tables.
test "literal quantifier windows above four compute" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(
    n("^a{5}$").normalize("aaaaa\naaaa\naaaaaa"),
    "#\naaaa\naaaaaa",
  )
  @test.assert_eq(n("^\\w{5}$").normalize("aaaaa\naa"), "#\naa")
  @test.assert_eq(
    n("^a{4,6}$").normalize("aaa\naaaa\naaaaaaa"),
    "aaa\n#\naaaaaaa",
  )
  @test.assert_eq(n("^a{05}$").normalize("aaaaa\naaa"), "#\naaa")
  @test.assert_eq(n("^.{5}$").normalize("abcde\nabcd"), "#\nabcd")
  @test.assert_eq(n("^5{5}$").normalize("55555\n555"), "#\n555")
  @test.assert_eq(n("^a{2,5}$").normalize("aaaa\na"), "#\na")
  @test.assert_eq(n("^a{6,4}$").normalize("aaaa\naaaaaa"), "#\n#")
  @test.assert_eq(n("^a{0,5}$").normalize("aaa\naaaaaa\n\n"), "#\naaaaaa\n#\n")
  @test.assert_eq(n("a{5}").normalize("zaaaaaaz"), "z#az")
  @test.assert_eq(n("a{4,6}").normalize("zaaaaaz"), "z#z")
  @test.assert_eq(n("a{05}").normalize("zaaaaaz"), "z#z")
  @test.assert_eq(n("a{6,4}").normalize("zaaaaaaz"), "z#z")
  @test.assert_eq(n("a{100000,}").normalize("aaa"), "aaa")
  @test.assert_eq(n("^a{5}$").normalize_aligned("aaaaa\naaaa").0, "#\naaaa")
  @test.assert_eq(@common.is_supported_replace_regex("^a{5}$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^\\w{5}$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^a{100001}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("a{100001}"), false)
  // (class windows \w{5} moved to the generic parser in the next
  // batch — supported now)
}

///|
/// Reversed `{n,0}` stays rejected (review fix): its `{0,n}` swap has
/// empty-match insertion semantics the block engine lacks (probed:
/// `a{2,0}` on 'zaaaz' -> '#z##z#' in HF) — fail loud like `^a{2,0}$`.
test "reversed zero swap rejects" {
  // superseded: {n,0} now routes to the zero-min engine (see the
  // n-comma-zero test); only {100001,0} rejects at the cap
  @test.assert_eq(@common.is_supported_replace_regex("a{100001,0}"), false)
}

///|
/// Generic class windows (probed 0.22.2): `\w{5}`/`\s{5}`/`\d{5}`/
/// bracket/property spellings with ANY bound up to onig 100000 parse
/// numerically (`class_bounded_spec` — base via bare_class_kind,
/// window via parse_capped_digits) and run the shared block engine —
/// replacing the hardcoded {1,2}/{1,3}/{1,4} spelling tables for the
/// plain forms. Reversed `{6,4}` swaps; `{n,0}` and `{100001}` reject.
test "generic class windows any bound" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(
    n("\\w{5}").normalize("zz abcdefg 9912345 zz"),
    "zz #fg #45 zz",
  )
  @test.assert_eq(n("\\s{5}").normalize("a     b"), "a#b")
  @test.assert_eq(n("\\d{5}").normalize("z12345z 1234"), "z#z 1234")
  @test.assert_eq(n("[0-9]{5}").normalize("z12345z"), "z#z")
  @test.assert_eq(n("[\\w]{5}").normalize("zz abcdefg"), "zz #fg")
  @test.assert_eq(n("\\w{4,6}").normalize("zz abcdefg zz"), "zz #g zz")
  @test.assert_eq(n("\\w{5,}").normalize("zz abcdefg zz"), "zz # zz")
  @test.assert_eq(n("\\w{05}").normalize("abcdefg"), "#fg")
  @test.assert_eq(n("\\W{5}").normalize("z!!!!!z"), "z#z")
  @test.assert_eq(n("\\p{N}{5}").normalize("z12345z"), "z#z")
  @test.assert_eq(n("[\\p{L}]{5}").normalize("zz abcdefg"), "zz #fg")
  @test.assert_eq(n("\\w{6,4}").normalize("zz abcdefg zz"), "zz #g zz")
  @test.assert_eq(n("\\w{5}").normalize_aligned("zz abcdefg").0, "zz #fg")
  @test.assert_eq(@common.is_supported_replace_regex("\\w{5}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{100001}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{2,100001}"), false)
  // the hardcoded <=4 rows still compute identically
  @test.assert_eq(n("\\w{1,2}").normalize("abcdef"), "###")
}

///|
/// `{n,0}` lands in the zero-min engine — onig swaps it to `{0,n}`
/// (probed 0.22.2 side-by-side: `\s{5,0}` == `\s{0,5}`, `\d{5,0}` ==
/// `\d{0,5}`, `\w{5,0}` == `\w{0,5}`, `a{2,0}` == `a{0,2}` on every
/// input; the earlier "reversed zero swap rejects" tests flip to
/// supported).
test "n-comma-zero routes to zero-min engine" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("a{2,0}").normalize("zaaaz"), "#z##z#")
  @test.assert_eq(n("a{2,0}").normalize("abcd"), "#b#c#d#")
  @test.assert_eq(n("\\w{5,0}").normalize("zz abcdefg zz"), "# ## #")
  @test.assert_eq(n("a{3,0}").normalize("zzaaazz"), "#z#z#z#z#")
  @test.assert_eq(n("\\w{5,0}").normalize("aa"), "#")
  @test.assert_eq(n("\\n{2,0}").normalize("z\n\nz"), "#z#z#")
  @test.assert_eq(n("a{100000,0}").normalize("aa"), "#")
  @test.assert_eq(n("5{3,0}").normalize("z555y"), "#z#y#")
  @test.assert_eq(n("\\s{5,0}").normalize("a     b"), "#a#b#")
  @test.assert_eq(n("\\d{5,0}").normalize("z12345z"), "#z#z#")
  @test.assert_eq(n("a{2,0}").normalize_aligned("zaaaz").0, "#z##z#")
  @test.assert_eq(@common.is_supported_replace_regex("a{2,0}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{5,0}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a{100001,0}"), false)
}

///|
/// `{n,0}` zero-tail variants and boundary shapes (probed 0.22.2):
/// `a{2,00}` == `a{2,0}` (trailing zeros), `a{02,0}` == `a{0,2}`
/// (leading zero in n); `a{2,0,}`/`a{2,0x}` are literals; `a{,0}` and
/// `a{0,0}` == `a{0}`; the anchored form is unchanged.
test "n-comma-zero zero variants" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("a{2,00}").normalize("zaaaz"), "#z##z#")
  @test.assert_eq(n("a{02,0}").normalize("zaaaz"), "#z##z#")
  @test.assert_eq(n("a{2,0,}").normalize("zaaaz"), "zaaaz")
  @test.assert_eq(n("a{2,0x}").normalize("zaaaz"), "zaaaz")
  @test.assert_eq(n("a{,0}").normalize("zaaaz"), "#z#a#a#a#z#")
  @test.assert_eq(n("a{0,0}").normalize("zaaaz"), "#z#a#a#a#z#")
  @test.assert_eq(n("^a{2,0}$").normalize("zaaaz"), "zaaaz")
  @test.assert_eq(@common.is_supported_replace_regex("a{2,00}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a{02,0}"), true)
  // pair-equivalence spot checks
  @test.assert_eq(
    n("\\w{5,0}").normalize("zz abcdefg zz"),
    n("\\w{0,5}").normalize("zz abcdefg zz"),
  )
  @test.assert_eq(
    n("\\s{5,0}").normalize("a     b"),
    n("\\s{0,5}").normalize("a     b"),
  )
}

///|
/// Boundary-windowed quantifiers (probed 0.22.2, 24 cells): an end
/// `\b` forces the block to end on a WORD boundary — a literal-'a'
/// run ending on a word char ('aa' inside 'aaz') is not a boundary —
/// so with both anchors only whole words in the window match; with
/// only the start `\b` the block runs greedily from a word start;
/// with only the end `\b` the block spans the run's last window.
/// Zero-min forms ({0}, {0,m}, {n,0}) walk the empty rules with
/// every empty requiring its boundary predicates.
test "boundary-windowed quantifiers" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\ba{2}\\b").normalize("zaaz aaz aa"), "zaaz aaz #")
  // anchored {0,m}/{n,0} with an end \b reject (review F1/F2: HF
  // backtracks greedy-then-empty per position — '\ba{0,2}\\b' on
  // 'aab' -> '#aab#' — a different engine capability)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{0,2}\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("a{0,2}\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{2,0}\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{2,0}"), false)
  @test.assert_eq(n("\\b\\w{5}\\b").normalize("zz abcdefg zz"), "zz abcdefg zz")
  @test.assert_eq(n("\\b\\w{5}").normalize("zaaaaaz"), "#az")
  @test.assert_eq(n("\\w{5}\\b").normalize("zaaaaaz"), "za#")
  @test.assert_eq(n("\\w{5}\\b").normalize("zaaaaaaz"), "zaa#")
  @test.assert_eq(
    n("\\ba{2,4}\\b").normalize("zaaaz aa aaaa zaa"),
    "zaaaz # # zaa",
  )
  @test.assert_eq(n("\\b\\d{5}\\b").normalize("z12345z 12345"), "z12345z #")
  @test.assert_eq(n("\\ba{5}\\b").normalize("zaaaaaz"), "zaaaaaz")
  @test.assert_eq(
    n("\\b\\w{2,4}\\b").normalize("ab abc abcd abcde"),
    "# # # abcde",
  )
  @test.assert_eq(n("\\ba{2,}\\b").normalize("zaaaaz aa"), "zaaaaz #")
  @test.assert_eq(n("\\ba{2}\\b").normalize("aaa aa"), "aaa #")
  @test.assert_eq(n("\\w{2,4}\\b").normalize("zaaaaz ab"), "za# #")
  @test.assert_eq(n("\\ba{2,4}").normalize("zaaaaz"), "zaaaaz")
  @test.assert_eq(n("\\baa\\b").normalize("zaa aa"), "zaa #")
  // round-2: ws-only zero-min ranges also diverge (HF '\\b\\w{0,2}'
  // on 'zaaz' -> '#az#' — per-position backtracking); only exact {0}
  // stays
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{0,2}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\w{0,2}"), false)
  @test.assert_eq(n("\\ba{2,}\\b").normalize("ab abc"), "ab abc")
  @test.assert_eq(
    n("\\ba{2,4}\\b").normalize("a aa aaa aaaa aaaaa"),
    "a # # # aaaaa",
  )
  @test.assert_eq(n("\\b\\w{2,4}\\b").normalize("中a ab abc"), "# # #")
  @test.assert_eq(n("\\ba{2,4}\\b").normalize("²aa aa"), "²aa #")
  @test.assert_eq(n("\\w{2,4}\\b").normalize("ab1 abc12"), "# a#")
  @test.assert_eq(n("\\ba{2,}\\b").normalize("aa aaaa aaaaa"), "# # #")
  @test.assert_eq(n("\\ba{0}\\b").normalize("ab cd"), "#ab# #cd#")
  @test.assert_eq(n("\\b\\w{5}").normalize_aligned("zaaaaaz").0, "#az")
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\w{5}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{2,4}\\b"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\w{100001}"), false)
}

///|
/// Single-anchor windows `^BASE{...}` / `BASE{...}$` (probed 0.22.2,
/// 19 cells): the anchor pins the block to each line start (greedy
/// within the window from the anchor) or line end (the block ENDS at
/// the anchor, greedily the largest len <= min(hi, run)); the pred
/// must hold AT the anchor position ('^\w{1,2}' on '  ab cd'
/// unchanged — the line starts with a space). Zero-min and {n,0}
/// forms reject (empty walks are position-global, not anchor-pinned).
test "single-anchor windows" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^\\w{1,2}").normalize("abcdef\nabcdef"), "#cdef\n#cdef")
  @test.assert_eq(n("\\w{1,2}$").normalize("abcdef\nabcdef"), "abcd#\nabcd#")
  @test.assert_eq(n("^\\w{5}").normalize("abcdefg\nab"), "#fg\nab")
  @test.assert_eq(n("\\w{5}$").normalize("abcdefg\nab"), "ab#\nab")
  @test.assert_eq(n("^\\d{2,4}").normalize("z12345\n123456"), "z12345\n#56")
  @test.assert_eq(n("^a{2}").normalize("zaaz\naa"), "zaaz\n#")
  @test.assert_eq(n("^\\w{5,}").normalize("abcdefg\nab"), "#\nab")
  @test.assert_eq(n("^a{2,4}").normalize("aaa\nzaaaa\naa"), "#\nzaaaa\n#")
  @test.assert_eq(n("a{2,4}$").normalize("aaa\nzaaaa\naa"), "#\nz#\n#")
  @test.assert_eq(n("^\\w{2}").normalize("a\nab\nabc"), "a\n#\n#c")
  @test.assert_eq(n("^5{3}").normalize("5555\n55"), "#5\n55")
  @test.assert_eq(n("^\\w{1,2}").normalize("  ab cd"), "  ab cd")
  @test.assert_eq(n("\\w{1,2}$").normalize("ab cd  "), "ab cd  ")
  @test.assert_eq(n("^\\w{1,2}").normalize(""), "")
  @test.assert_eq(n("a{2}$").normalize("zaa\naa\naaa"), "z#\n#\na#")
  @test.assert_eq(n("\\w{2,4}$").normalize("z abcd"), "z #")
  @test.assert_eq(n("^\\w{2,}").normalize("a\nab\nabc\nabcd"), "a\n#\n#\n#")
  @test.assert_eq(n("^a{100000}").normalize("aa"), "aa")
  @test.assert_eq(n("^\\w{1,2}").normalize_aligned("abcdef").0, "#cdef")
  @test.assert_eq(@common.is_supported_replace_regex("^\\w{1,2}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a{2,4}$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^a{0,2}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("a{0,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^a{2,0}"), false)
}

///|
/// Trailing nl-pred bases reject (review fix); leading nl-pred bases
/// stay — probed 0.22.2.
test "single-anchor nl-pred bases" {
  @test.assert_eq(@common.is_supported_replace_regex("\\s{2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\D{2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\n{2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^\\s{2}"), true)
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^\\D{2}").normalize("a\n\nb"), "##")
  @test.assert_eq(n("^\\s{2,4}").normalize("\n\n\n\n\n\n"), "##")
  @test.assert_eq(n("^\\W{2}").normalize("!\n\na"), "#\na")
  @test.assert_eq(n("^[\\r\\n]{2,}").normalize("\n\n\nb"), "#b")
}

///|
/// Lazy-exact anchored `[\b]BASE{n}?[\b]` (probed 0.22.2): onig
/// parses `X{n}?` as the OPTIONAL group `(X{n})?` — the exact-n block
/// when it fits both anchors, an EMPTY at anchor positions otherwise
/// ('\ba{2}?' on 'aaa' -> '#a#'; '\ba{2}?\b' on 'aaaa' -> '#aaaa#'
/// — the block fails the end anchor, both boundary empties fire).
/// Range-lazy anchored shapes ({n,m}?, {n,}?) collapse via
/// lazy_normalize to the {n} window (no empty fallback, HF-verified).
test "boundary lazy-exact quantifiers" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\b\\w{2}?").normalize("ab cd"), "# #")
  @test.assert_eq(n("\\ba{2}?").normalize("aaa"), "#a#")
  @test.assert_eq(n("\\b\\w{5}?").normalize("zaaaaaz"), "#az#")
  @test.assert_eq(n("\\w{2}?\\b").normalize("ab cd"), "# #")
  @test.assert_eq(n("\\ba{2}?\\b").normalize("aa aaa"), "# #aaa#")
  @test.assert_eq(n("\\ba{2}?").normalize("zaaaz"), "#zaaaz#")
  @test.assert_eq(n("\\w{5}?\\b").normalize("zaaaaaz"), "#za#")
  @test.assert_eq(n("\\ba{2}?").normalize(""), "")
  @test.assert_eq(n("\\ba{2}?\\b").normalize("aaaa"), "#aaaa#")
  @test.assert_eq(n("\\b\\w{2}?").normalize("a b"), "#a# #b#")
  @test.assert_eq(n("\\ba{3}?").normalize("aaaaaa"), "#aaa#")
  @test.assert_eq(n("\\ba{2}?\\b").normalize("a aa aaa"), "#a# # #aaa#")
  @test.assert_eq(n("\\b\\w{2}?").normalize("ab"), "#")
  @test.assert_eq(n("\\ba{2}?").normalize("a"), "#a#")
  @test.assert_eq(n("\\b\\w{2}?").normalize("abcde ab"), "#cde# #")
  @test.assert_eq(n("\\w{2}?\\b").normalize("zz abcd"), "# #ab#")
  @test.assert_eq(n("\\ba{2,4}?").normalize("aaaa"), "#aa")
  @test.assert_eq(n("\\ba{2,}?").normalize("aaa aa"), "#a #")
  @test.assert_eq(n("\\b\\w{2}?").normalize_aligned("ab cd").0, "# #")
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{2}?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{2}?\\b"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{100001}?"), false)
}

///|
/// we-only single-char-base spellings load (review fix: the cut<6
/// guard wrongly rejected `a{2}?\b`); every want probed 0.22.2.
test "boundary lazy-exact we-only single-char base" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("a{2}?\\b").normalize("zaaaz"), "#zaaaz#")
  @test.assert_eq(n("a{2}?\\b").normalize("aaa"), "#a#")
  @test.assert_eq(n("a{2}?\\b").normalize("aa"), "#")
  @test.assert_eq(n("a{2}?\\b").normalize("aaaa"), "#aa#")
  @test.assert_eq(n("a{2}?\\b").normalize("ab"), "#ab#")
  @test.assert_eq(n("a{3}?\\b").normalize("aaa"), "#")
  @test.assert_eq(n("z{2}?\\b").normalize("ab"), "#ab#")
  @test.assert_eq(@common.is_supported_replace_regex("a{2}?\\b"), true)
  // the literal-backslash tail is NOT the anchor — stays rejected
  @test.assert_eq(@common.is_supported_replace_regex("a{2}?\\\\b"), false)
}

///|
/// Non-boundary (`\B`) windows and lazy-exact (probed 0.22.2):
/// leftmost-greedy scan — a start `\B` filters scan positions
/// ('\B\w{5}' on 'zaaaaaz' -> 'z#z', blocks start MID-word); an end
/// `\B` backtracks the block length until the end position is a
/// non-boundary ('\w{5}\B' on 'zaaaaaz' -> (0,5) -> '#az'). Exact
/// {0} walks the empty rules inverted ('\B\w{0}' on 'zaaz' ->
/// 'z#a#a#z', empties at every interior non-boundary); zero-min
/// RANGES reject — the same walk-vs-scan divergence as the \b family.
test "nonboundary windows and lazy-exact" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\B\\w{5}").normalize("zaaaaaz"), "z#z")
  @test.assert_eq(n("\\B\\w{2,4}").normalize("zaaaaz"), "z#z")
  @test.assert_eq(n("\\B\\w{2}").normalize("zaaz"), "z#z")
  @test.assert_eq(n("\\w{5}\\B").normalize("zaaaaaz"), "#az")
  @test.assert_eq(n("\\B\\w{5}\\B").normalize("zaaaaaaz"), "z#az")
  @test.assert_eq(n("\\B\\d{3}").normalize("z12345z"), "z#45z")
  @test.assert_eq(n("\\B\\w{2,}").normalize("zaaaaz"), "z#")
  @test.assert_eq(n("\\Ba{2}").normalize("zaaz aa"), "z#z aa")
  @test.assert_eq(n("\\B\\w{2}\\B").normalize("zaaaaz"), "z##z")
  @test.assert_eq(n("\\B\\w{5}").normalize("abcdef"), "a#")
  @test.assert_eq(n("\\B\\w{5}").normalize("aaaaaa"), "a#")
  @test.assert_eq(n("\\B\\w{0}").normalize("zaaz"), "z#a#a#z")
  @test.assert_eq(n("\\B\\w{1,2}").normalize("zaaaaz"), "z###")
  @test.assert_eq(n("\\B\\w{3}").normalize("ab cde"), "ab cde")
  @test.assert_eq(n("\\B5{2}").normalize("z5555y"), "z##y")
  @test.assert_eq(n("\\B\\w{2}\\B").normalize("zaaz"), "z#z")
  @test.assert_eq(n("\\Ba{2}?").normalize("zaaz"), "z#z")
  @test.assert_eq(n("\\B\\w{5}").normalize_aligned("zaaaaaz").0, "z#z")
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\w{5}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\w{100001}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\w+?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\w{0,2}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{0,2}\\B"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\w{0,2}\\B"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\w{0,}\\B"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\w{2,0}\\B"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\Ba{0,2}\\B"), false)
}

///|
/// Anchored plus windows and mixed \b+\B anchors (probed 0.22.2): the
/// greedy '\b\w+' == '\b\w{1,}' (whole words from each boundary); the
/// lazy '\b\w+?' == '\b\w{1}' (one char — the empty continuation stops
/// the lazy group at its minimum), EXCEPT before a genuine \b trail
/// where it ascends to the run end ('\ba+?\b' on 'aaa' -> '#', ==
/// '\ba+\b'); a \B trail keeps the one-char pin ('\ba+?\B' on 'aaaa'
/// -> '#aaa'). Mixed anchors gate the start by one kind, run greedy
/// within the window, then shrink one char at a time until the OTHER
/// kind holds at the end ('\ba{2,4}\B' on 'aaaa' -> '#a': greedy 4
/// ends on the EOS boundary, 3 lands on the interior non-boundary).
test "anchored plus windows and mixed anchors" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  // greedy plus == {1,}
  @test.assert_eq(n("\\b\\w+").normalize("hello world"), "# #")
  @test.assert_eq(n("\\b\\w+").normalize("zaaaaz"), "#")
  @test.assert_eq(n("\\b\\w+").normalize("aaa bbb ccc"), "# # #")
  @test.assert_eq(n("\\ba+").normalize("aaa bbb ccc"), "# bbb ccc")
  @test.assert_eq(n("\\ba+").normalize("ab\ncd"), "#b\ncd")
  @test.assert_eq(n("\\B\\w+").normalize("hello world"), "h# w#")
  @test.assert_eq(n("\\B\\w+").normalize("zaaaaz"), "z#")
  @test.assert_eq(n("\\Ba+").normalize("zaaaaz"), "z#z")
  @test.assert_eq(n("\\Ba+").normalize("abcabc"), "abc#bc")
  // lazy plus == {1} (one char per anchor-valid start)
  @test.assert_eq(n("\\b\\w+?").normalize("hello world"), "#ello #orld")
  @test.assert_eq(n("\\b\\w+?").normalize("aaa"), "#aa")
  @test.assert_eq(n("\\ba+?").normalize("aaa"), "#aa")
  @test.assert_eq(n("\\B\\w+?").normalize("hello world"), "h#### w####")
  @test.assert_eq(n("\\B\\w+?").normalize("zaaaaz"), "z#####")
  @test.assert_eq(n("\\Ba+?").normalize("zaaaaz"), "z####z")
  // both-anchored plus: lazy before a genuine \b trail == run end
  @test.assert_eq(n("\\b\\w+\\b").normalize("hello world"), "# #")
  @test.assert_eq(n("\\B\\w+\\B").normalize("hello world"), "h#o w#d")
  @test.assert_eq(n("\\ba+\\b").normalize("aaa"), "#")
  @test.assert_eq(n("\\ba+?\\b").normalize("aaa"), "#")
  @test.assert_eq(n("\\ba+?\\b").normalize("z aa z"), "z # z")
  @test.assert_eq(n("\\ba+?\\B").normalize("aaaa"), "#aaa")
  // mixed anchors: greedy window, shrink until the other kind holds
  @test.assert_eq(n("\\ba{2}\\B").normalize("aaa"), "#a")
  @test.assert_eq(n("\\ba{2}\\B").normalize("aaa bbb ccc"), "#a bbb ccc")
  @test.assert_eq(n("\\ba{2}\\B").normalize("aa\\bb"), "aa\\bb")
  @test.assert_eq(n("\\b\\w{2}\\B").normalize("hello world"), "#llo #rld")
  @test.assert_eq(n("\\b\\w{2,4}\\B").normalize("hello world"), "#o #d")
  @test.assert_eq(n("\\b\\w{2,4}\\B").normalize("zaaaaz"), "#az")
  @test.assert_eq(n("\\ba{2,4}\\B").normalize("aaaa"), "#a")
  @test.assert_eq(n("\\ba{2,4}\\B").normalize("aaaaa"), "#a")
  @test.assert_eq(n("\\Ba{2,4}\\b").normalize("zaaaa z"), "z# z")
  @test.assert_eq(n("\\B\\w{2,4}\\b").normalize("hello world"), "h# w#")
  @test.assert_eq(n("\\B\\w{2,4}\\b").normalize("zaaaaz"), "za#")
  @test.assert_eq(n("\\B\\w{2,4}\\b").normalize("mIx"), "m#")
  // mixed plus spellings
  @test.assert_eq(n("\\ba+\\B").normalize("aa"), "#a")
  @test.assert_eq(n("\\ba+\\B").normalize("ab cd ef"), "#b cd ef")
  @test.assert_eq(n("\\b\\w+\\B").normalize("ab cd ef"), "#b #d #f")
  @test.assert_eq(n("\\b\\w+\\B").normalize("zaaaaz"), "#z")
  @test.assert_eq(n("\\b\\w+\\B").normalize("12 34"), "#2 #4")
  @test.assert_eq(n("\\b\\w+?\\B").normalize("aaaa"), "#aaa")
  @test.assert_eq(n("\\B\\w+?\\b").normalize("aaaa"), "a#")
  @test.assert_eq(n("\\B\\w+?\\b").normalize("hello world"), "h# w#")
  // aligned path agrees on the new families
  @test.assert_eq(n("\\b\\w+").normalize_aligned("hello world").0, "# #")
  @test.assert_eq(n("\\ba{2}\\B").normalize_aligned("aaa").0, "#a")
  // support gate: plus and mixed claim their spellings; the star and
  // possessive forms stay loud rejects
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\w+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\w+?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\w+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\Ba+?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\w+\\b"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\w+\\B"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba+?\\b"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{2}\\B"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\Ba{2}\\b"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\w{2,4}\\B"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba+\\B"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\w+?\\B"), true)
  // escaped-punctuation bases ('\b\++' etc.) stay outside this
  // family — the parse's escape map is \n/\t/\r only
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\++"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba*"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba*?"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba++"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba?+"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{0,2}\\B"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{0}\\B"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{2}?\\B"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\Ba{2}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba{2}b"), false)
  // lazy plus before a trailing anchor over a MIXED word-ness class:
  // HF's lazy ascent stops at the first interior boundary — loud
  // reject (round-1 review); the no-trail pin and uniform bases stay
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\S+?\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\S+?\\B"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\S+?\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\S+?\\B"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\D+?\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b[^0-9]+?\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\P{N}+?\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\P{L}+?\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\P{P}+?\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\P{S}+?\\b"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\p{P}+?\\b"), false)
  @test.assert_eq(
    @common.is_supported_replace_regex("\\b[^A-Za-z0-9_]+?\\b"),
    false,
  )
  @test.assert_eq(
    @common.is_supported_replace_regex("\\b[^A-Za-z]+?\\b"),
    false,
  )
  // no-trail lazy pin is base-independent ('a,b' -> every \S char sits
  // between boundaries); greedy + stays exact on mixed bases
  @test.assert_eq(@common.is_supported_replace_regex("\\b\\S+?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\B\\S+?"), true)
  @test.assert_eq(n("\\b\\S+?").normalize("a,b"), "###")
  @test.assert_eq(n("\\b\\S+?").normalize("ab cd"), "#b #d")
  @test.assert_eq(n("\\B\\S+?").normalize("a,b"), "a,b")
  @test.assert_eq(n("\\b\\S+").normalize("a,b"), "#")
  // greedy + end-\b over mixed classes: hi-capped greedy, then shrink
  // (the pre-main divergence the round-1 fix closed)
  @test.assert_eq(n("\\b\\S+\\b").normalize("a\nb, c"), "#\n#, #")
  @test.assert_eq(n("\\b\\S{1,2}\\b").normalize("ab,"), "#,")
  // uniform non-word / letter / symbol bases keep the lazy+\b trail
  @test.assert_eq(n("\\b\\W+?\\b").normalize("a,b"), "a#b")
  @test.assert_eq(n("\\b\\p{L}+?\\b").normalize("ab cd"), "# #")
  @test.assert_eq(n("\\b\\p{S}+?\\b").normalize("a+b"), "a#b")
}

///|
/// Dot-base single-anchor windows (probed 0.22.2): '.' matches any
/// char EXCEPT newline, so the window runs to the line end — leading
/// greedy from each line start ('^.{2}' on 'ab\ncd' -> '#\n#'),
/// trailing ends AT the line end ('.{2}$' on 'abc\n' -> 'a#\n';
/// '\r' stays in its line, 'aa\r\nbb' -> 'a#\n#'). Plus spellings
/// follow the anchored-lazy rule: '^.+?' == '^.{1}' (one char per
/// line start) but '.+?$' == '.{1,}$' (the line-end anchor forces the
/// lazy ascent to the line end). Bare all-dots sequences are exact
/// windows ('^..' == '^.{2}'). Zero-min stays the family's loud
/// reject; a bare unanchored '.' is out of scope (kind 30 is only
/// dispatched under a line anchor).
test "dot single-anchor windows" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("^.{2}").normalize("abcdef"), "#cdef")
  @test.assert_eq(n("^.{2}").normalize("ab\ncd"), "#\n#")
  @test.assert_eq(n("^.{2}").normalize("a\nbb\nccc"), "a\n#\n#c")
  @test.assert_eq(n("^.{2}").normalize("x\ny\nz"), "x\ny\nz")
  @test.assert_eq(n("^.{2}").normalize("日本語\nテスト"), "#語\n#ト")
  @test.assert_eq(n("^.{2}").normalize("\n\n"), "\n\n")
  @test.assert_eq(n("^.{2}").normalize("a\n\nb"), "a\n\nb")
  @test.assert_eq(n("^.{2}").normalize("tab\there"), "#b\there")
  @test.assert_eq(n("^.{2}").normalize("  ab  "), "#ab  ")
  @test.assert_eq(n("^.{2}").normalize("a.b\nc,d"), "#b\n#d")
  @test.assert_eq(n("^.{2}").normalize("aa\r\nbb"), "#\r\n#")
  @test.assert_eq(n("^.{2}").normalize("é\nüü"), "é\n#")
  @test.assert_eq(n("^.{1}").normalize("x\ny\nz"), "#\n#\n#")
  @test.assert_eq(n("^.{1}").normalize("a\n\nb"), "#\n\n#")
  @test.assert_eq(n("^.{1,2}").normalize("a\nbb\nccc"), "#\n#\n#c")
  @test.assert_eq(n("^.{2,}").normalize("abcdef"), "#")
  @test.assert_eq(n("^.{2,}").normalize("a\nbb\nccc"), "a\n#\n#")
  @test.assert_eq(n("^.{2,}").normalize("日本語\nテスト"), "#\n#")
  @test.assert_eq(n("^.{2,4}").normalize("abcdef"), "#ef")
  @test.assert_eq(n("^.{2,4}").normalize("tab\there"), "#here")
  @test.assert_eq(n("^.{2,4}").normalize("  ab  "), "#  ")
  @test.assert_eq(n(".{2}$").normalize("abcdef"), "abcd#")
  @test.assert_eq(n(".{2}$").normalize("a\nbb\nccc"), "a\n#\nc#")
  @test.assert_eq(n(".{2}$").normalize("日本語\nテスト"), "日#\nテ#")
  @test.assert_eq(n(".{2}$").normalize("\n\n"), "\n\n")
  @test.assert_eq(n(".{2}$").normalize("tab\there"), "tab\the#")
  @test.assert_eq(n(".{2}$").normalize("abc\n"), "a#\n")
  @test.assert_eq(n(".{2}$").normalize("  ab  "), "  ab#")
  @test.assert_eq(n(".{2}$").normalize("aa\r\nbb"), "a#\n#")
  @test.assert_eq(n(".{1,2}$").normalize("a\n\nb"), "#\n\n#")
  @test.assert_eq(n(".{2,4}$").normalize("abcdef"), "ab#")
  @test.assert_eq(n(".{2,4}$").normalize("tab\there"), "tab\t#")
  @test.assert_eq(n(".{2,}$").normalize("abcdef"), "#")
  @test.assert_eq(n("^.+").normalize("abcdef"), "#")
  @test.assert_eq(n("^.+").normalize("a\n\nb"), "#\n\n#")
  @test.assert_eq(n("^.+").normalize("\n\n"), "\n\n")
  @test.assert_eq(n("^.+").normalize("日本語\nテスト"), "#\n#")
  @test.assert_eq(n(".+$").normalize("ab\ncd"), "#\n#")
  @test.assert_eq(n("^.+?").normalize("ab\ncd"), "#b\n#d")
  @test.assert_eq(n("^.+?").normalize("x\ny\nz"), "#\n#\n#")
  @test.assert_eq(n(".+?$").normalize("abcdef"), "#")
  @test.assert_eq(n(".+?$").normalize("ab\ncd"), "#\n#")
  @test.assert_eq(n("^..").normalize("日本語\nテスト"), "#語\n#ト")
  @test.assert_eq(n("^.").normalize("ab\ncd"), "#b\n#d")
  @test.assert_eq(n("^\\w+?").normalize("ab\ncd"), "#b\n#d")
  @test.assert_eq(@common.is_supported_replace_regex("^.{0,2}"), false)
  @test.assert_eq(@common.is_supported_replace_regex(".{0,2}$"), false)
  @test.assert_eq(@common.is_supported_replace_regex("^.{2}"), true)
  @test.assert_eq(@common.is_supported_replace_regex(".{2}$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^.+"), true)
  @test.assert_eq(@common.is_supported_replace_regex(".+$"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^.+?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("^.."), true)
  @test.assert_eq(@common.is_supported_replace_regex("^."), true)
}

///|
/// General bracket character classes (probed 0.22.2): literals,
/// literal ranges, escaped literals and CLASS-context shortcuts
/// ('[a\w]' on 'a²b' -> '#²#' — the class-context \w excludes the
/// onig quirks) union into one per-char predicate; '^' complements
/// INCLUDING '\n' ('[^a]' on 'ab\ncd' -> 'a####'). Leading/trailing
/// '-' are literals; shortcut range endpoints reject (onig load
/// errors). Quantifiers: none/(1,1) per-char, '+'/(1,-1) runs,
/// braces, lazy '+?' == (1,1), and zero-min tails ride the empty
/// walk. Double tails: unanchored 'X+??' == 'X{0,1}' (optional lazy
/// group, EMPTY fallback where the pred fails: '\w+??' on '-ab' ->
/// '#-##'), 'X+?+' == greedy; anchored '+??' rejects (anchor-pinned
/// empties are the rejected zero-min capability).
test "general bracket sets and double tails" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }

  @test.assert_eq(n("[a\\w]").normalize("a-b"), "#-#")
  @test.assert_eq(n("[a\\w]").normalize("a²b"), "#²#")
  @test.assert_eq(n("[a\\w]").normalize("ab cd"), "## ##")
  @test.assert_eq(n("[\\da]").normalize("abcdef"), "#bcdef")
  @test.assert_eq(n("[\\da]").normalize("-ab"), "-#b")
  @test.assert_eq(n("[\\w-]").normalize("a-b"), "###")
  @test.assert_eq(n("[\\w-]").normalize("-"), "#")
  @test.assert_eq(n("[abc]").normalize("abcdef"), "###def")
  @test.assert_eq(n("[abc]").normalize("0a9"), "0#9")
  @test.assert_eq(n("[a-c]").normalize("ab\ncd"), "##\n#d")
  @test.assert_eq(n("[^a]").normalize("ab\ncd"), "a####")
  @test.assert_eq(n("[^a]").normalize("-"), "#")
  @test.assert_eq(n("[-a]").normalize("a-b"), "##b")
  @test.assert_eq(n("[a-]").normalize("ab-"), "#b#")
  @test.assert_eq(n("[a-z]").normalize("x y_z1"), "# #_#1")
  @test.assert_eq(n("[éü]").normalize("aéb"), "a#b")
  @test.assert_eq(n("[^\\w-]").normalize("a,b;c!"), "a#b#c#")
  @test.assert_eq(n("[a\\w]+").normalize("a-b"), "#-#")
  @test.assert_eq(n("[a\\w]+").normalize("ab\ncd"), "#\n#")
  @test.assert_eq(n("[a\\w]{2,4}").normalize("abcdef"), "##")
  @test.assert_eq(n("[a\\w]{2,4}").normalize("a-b"), "a-b")
  @test.assert_eq(n("[a\\w]{2,4}").normalize("x y_z1"), "x #")
  @test.assert_eq(n("[abc]+").normalize("abcdef"), "#def")
  @test.assert_eq(n("[^a]+").normalize("abcdef"), "a#")
  @test.assert_eq(n("[^a]").normalize("abcdef"), "a#####")
  @test.assert_eq(n("[a-z]{2,}").normalize("ab\ncd"), "#\n#")
  @test.assert_eq(n("[abc]+?").normalize("aaa"), "###")
  @test.assert_eq(n("[abc]+?").normalize("abcdef"), "###def")
  @test.assert_eq(n("[^a]+?").normalize("abc"), "a##")
  @test.assert_eq(n("[\\w-]+").normalize("a-b c"), "# #")
  @test.assert_eq(n("[\\w\\d]").normalize("a1"), "##")
  @test.assert_eq(n("[\\w\\d]").normalize("²"), "²")
  @test.assert_eq(n("[^\\w\\s]").normalize("a b,c"), "a b#c")
  // double tails
  @test.assert_eq(n("\\w+??").normalize("a-b"), "#-#")
  @test.assert_eq(n("\\w+??").normalize("abcdef"), "######")
  // bare LITERAL plus forms stay loud rejects (a gap recorded in
  // PROGRESS: HF computes per-char 'a+??' == 'a' replace)
  // the gate fix also claims the bare LITERAL lazy-optional: 'a+??'
  // == 'a{1}?' (block-or-empty == per-char here, probed)
  @test.assert_eq(@common.is_supported_replace_regex("a+??"), true)
  @test.assert_eq(n("a+??").normalize("aaa"), "###")
  @test.assert_eq(@common.is_supported_replace_regex("^.+??"), false)
  @test.assert_eq(n("^.+?+").normalize("ab\ncd"), "#\n#")
  // gates
  @test.assert_eq(@common.is_supported_replace_regex("[abc]"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[^a]"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[abc]+?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[\\w]"), true)
  // zero-min set tails ride the empty walk (probed)
  @test.assert_eq(n("[a\\w]?").normalize("-a-"), "#-#-#")
  @test.assert_eq(n("[a\\w]*").normalize("xay"), "#")
  @test.assert_eq(n("[a\\w]{0,2}").normalize("xaay"), "##")
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]*"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]{0,2}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[c-a]"), false)
  @test.assert_eq(@common.is_supported_replace_regex("[\\d-a]"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\+??"), false)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]{2,4}?"), true)
  // round-1 review fixes: gate agrees with the engines on X+??, the
  // \p{...} member parse, and raw '&&' (onig intersection) rejects
  @test.assert_eq(@common.is_supported_replace_regex("\\w+??"), true)
  @test.assert_eq(n("\\w+??").normalize("-ab"), "#-##")
  @test.assert_eq(@common.is_supported_replace_regex("[\\p{L}a]"), true)
  @test.assert_eq(n("[\\p{L}a]").normalize("abcd"), "####")
  @test.assert_eq(n("[a\\p{N}]").normalize("a1b"), "##b")
  @test.assert_eq(@common.is_supported_replace_regex("[a&&b]"), false)
  @test.assert_eq(@common.is_supported_replace_regex("[a-w&&c-z]"), false)
  // PR #59: the declared gaps close — comma-open/{n,0} set forms ==
  // {0,m} empty walk (probed), and the bracket '+??' chain now lands
  // via the '{1}?' == {0,1} acceptance
  @test.assert_eq(n("[a\\w]{,2}").normalize("abcdef"), "###")
  @test.assert_eq(n("[a\\w]{2,0}").normalize("a-b"), "#-#")
  @test.assert_eq(n("[abc]{,3}").normalize("xay"), "#x#y#")
  @test.assert_eq(n("[a\\w]+??").normalize("a-b"), "#-#")
  @test.assert_eq(n("[a\\w]+??").normalize("-ab"), "#-##")
  @test.assert_eq(n("[a\\w]{1}?").normalize("-ab"), "#-##")
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]{,2}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]{2,0}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]+??"), true)
  // bare literal plus (char_bounded family): 'a+' == 'a{1,}', lazy
  // 'a+?' == 'a{1}' per-char (probed)
  @test.assert_eq(n("a+").normalize("aaa"), "#")
  @test.assert_eq(n("a+").normalize("a-b"), "#-b")
  @test.assert_eq(n("a+?").normalize("aaa"), "###")
  @test.assert_eq(n("\\n+").normalize("z\n\nz"), "z#z")
  @test.assert_eq(@common.is_supported_replace_regex("a+"), true)
  // nonzero reversed set bounds keep the WINDOW swap (round-1
  // review: the {n,0} branch briefly clobbered them)
  @test.assert_eq(n("[a\\w]{2,1}").normalize("-a-"), "-#-")
  @test.assert_eq(n("[a\\w]{3,1}").normalize("-abcd-"), "-##-")
  @test.assert_eq(n("[a\\w]{2,1}").normalize("..."), "...")
  @test.assert_eq(@common.is_supported_replace_regex("a+?"), true)
  // still rejected: larger lazy-n optional groups on sets, escaped
  // metachar plus bases, dot/star/quest bases
  // PR #60: set lazy-n optional groups ride the shared engine
  @test.assert_eq(n("[a\\w]{2}?").normalize("-ab-"), "#-#-#")
  @test.assert_eq(n("[a\\w]{2}?").normalize("abab"), "##")
  @test.assert_eq(n("[a\\w]{2}?").normalize("xay"), "#y#")
  @test.assert_eq(n("[a\\w]{11}?").normalize("ab"), "#a#b#")
  @test.assert_eq(n("[a\\w]{1}??").normalize("a-b"), "#a#-#b#")
  @test.assert_eq(n("\\w{2}??").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\w{2,3}??").normalize("abcd"), "##")
  @test.assert_eq(n("a++").normalize("bab"), "b#b")
  @test.assert_eq(n("a+*").normalize("a-b"), "#-#b#")
  @test.assert_eq(n("a+{2}").normalize("bab"), "bab")
  @test.assert_eq(n("\\w+{2}").normalize("abcd"), "#")
  @test.assert_eq(n("a?+").normalize("bab"), "#b#b#")
  @test.assert_eq(n("a*+").normalize("bab"), "#b#b#")
  @test.assert_eq(n(".+{2}").normalize("abc"), "#")
  @test.assert_eq(n("\\ba++").normalize("zaaz"), "zaaz")
  @test.assert_eq(n("\\ba++").normalize("aaa"), "#")
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]{2}?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]{11}?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]{1}??"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a+*"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a+{2}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\w+{2}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a?+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\ba++"), true)
  // still rejected: possessive before a shrink-needing trailing anchor
  @test.assert_eq(@common.is_supported_replace_regex("\\ba++\\B"), false)
  // round-1 review fixes: malformed braces stay literal (loud),
  // possessive-then-brace never matches (loud)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{2,3x}??"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{2,x}??"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{0,m}??"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{2,100001}??"), false)
  @test.assert_eq(@common.is_supported_replace_regex("a++{2}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\w++{2}"), false)
  @test.assert_eq(n("\\w{2,3}??").normalize("aaa"), "#a#")
  @test.assert_eq(n("\\w{0,3}??").normalize("aaa"), "#a#a#a#")
  // round-2 review: REVERSED double-lazy bounds walk all-empty
  // ('\\w{3,2}??' == the '{0}' walk, probed), and the pre-existing
  // '{n,0}?' hang is fixed by delegating lo==0 to the {0,n} walk
  @test.assert_eq(n("\\w{2,0}??").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("\\w{3,2}??").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("\\w{2,0}?").normalize("aaa"), "##")
  @test.assert_eq(n("a{2,0}?").normalize("aaa"), "##")
  // PR #60: unanchored dot plus joins the class runs (kind 30)
  @test.assert_eq(n(".+").normalize("a\nb"), "#\n#")
  @test.assert_eq(n(".+").normalize("a"), "#")
  @test.assert_eq(n("\\w++").normalize("a-b"), "#-#")
  @test.assert_eq(@common.is_supported_replace_regex(".+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\w++"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a*"), false)
}

///|
/// Zero-min gap closures (probed 0.22.2): dot windows '.{0,2}'/
/// '.{0}'/'.{,2}' ride the zero-min walk via a '.' base in
/// zero_min_base (kind 30, pred excludes '\n'); '(X+){0}' == the
/// all-empty '{0}' while '(X+){0,m}' == the '{0,}' star walk;
/// comma-open '{,m}??' == all-empty; reversed-zero '{n,0}?' == the
/// '{0,n}' walk; possessive-marked lazy tails collapse
/// ('X+*+' == star, 'X+??+' == one char per rep '{0,1}', 'X??+' ==
/// all-empty, '{n}?+' == '{n}?') instead of dying as dead rewrites.
test "zero-min gap closures" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n(".{0,2}").normalize("aaa"), "##")
  @test.assert_eq(n(".{0,2}").normalize("a\nb"), "#\n#")
  @test.assert_eq(n(".{0}").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n(".{,2}").normalize("aaa"), "##")
  @test.assert_eq(n("a+{0}").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("a+{0}").normalize("bab"), "#b#a#b#")
  @test.assert_eq(n("a+{0,2}").normalize("aaa"), "#")
  @test.assert_eq(n("a+{0,2}").normalize("bab"), "#b#b#")
  @test.assert_eq(n("\\w{,3}??").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("[a\\w]{2,0}?").normalize("aaa"), "##")
  @test.assert_eq(n("[a\\w]{2,0}?").normalize("-ab-"), "#-#-#")
  @test.assert_eq(n("a+*+").normalize("bab"), "#b#b#")
  @test.assert_eq(n("a+*+").normalize("aaa"), "#")
  @test.assert_eq(n("a??+").normalize("bab"), "#b#a#b#")
  @test.assert_eq(n("[a\\w]{2}?+").normalize("xay"), "#y#")
  @test.assert_eq(n("a+??+").normalize("bab"), "#b#b#")
  @test.assert_eq(n("\\w+*+").normalize("a-b"), "#-#")
  @test.assert_eq(@common.is_supported_replace_regex(".{0,2}"), true)
  @test.assert_eq(@common.is_supported_replace_regex(".{0}"), true)
  @test.assert_eq(@common.is_supported_replace_regex(".{,2}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a+{0}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{,3}??"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]{2,0}?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a+*+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a??+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("[a\\w]{2}?+"), true)
  // round-1 review: ranged '?+' stays loud (HF computes n-block
  // chains); malformed '+{0,...}' tails stay literal; '}??+' drops
  // the marker; '.{2,0}' rides the reversed-zero via zero_min_base
  @test.assert_eq(@common.is_supported_replace_regex("\\w{2,3}?+"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{2,}?+"), false)
  @test.assert_eq(@common.is_supported_replace_regex("a+{0,x}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("a+{0,100001}"), false)
  @test.assert_eq(n("\\w{0,3}?+").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("\\w{2}??+").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("\\w{2,3}??+").normalize("aaa"), "#a#")
  @test.assert_eq(n(".{2,0}").normalize("a\nb"), "#\n#")
  // round-2 fixes: '{0,}' star walk restored, '{0,0}' == all-empty,
  // reversed '?+' inners drop again (well-formed ranges stay loud)
  @test.assert_eq(n("a+{0,}").normalize("aaa"), "#")
  @test.assert_eq(n("a+{0,}").normalize("bab"), "#b#b#")
  @test.assert_eq(n(".+{0,}").normalize("a\nb"), "#\n#")
  @test.assert_eq(n("a+{0,0}").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("\\w{2,0}?+").normalize("aaa"), "##")
  @test.assert_eq(n("\\w{3,2}?+").normalize("aaaa"), "#a#")
  @test.assert_eq(@common.is_supported_replace_regex("a+{0,}"), true)
}

///|
/// Final recorded-gap closures (probed 0.22.2): the escaped literal
/// plus base ('\+{0}' all-empty walk; also unblocks '\+??+'/'\+*+'
/// which the possessive-lazy rules then fold), possessive+ZERO brace
/// ('a++{0}' == zero reps == all-empty — nonzero bounds still never
/// match), and the digit-triplet scanner now flags ONLY its digit
/// chunks as matches (the pattern leaves regex gaps — probed
/// Split('\p{N}{1,3}', 'removed') on 'abc12345de' -> ['abc','de']).
/// Equal-bound and ranged '?+' stay loud: fresh-object probing shows
/// they are the n-block CHAIN family ('\w{2,2}?+' on 'abab' -> '#'
/// as ONE match), deliberately unimplemented.
test "final loud-gap closures" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\+{0}").normalize("+"), "#+#")
  @test.assert_eq(n("\\+{0}").normalize("a+b"), "#a#+#b#")
  @test.assert_eq(n("\\+??+").normalize("a+b"), "#a#+#b#")
  @test.assert_eq(n("\\+*+").normalize("a+b"), "#a#b#")
  @test.assert_eq(n("a++{0}").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("a++{0}").normalize("bab"), "#b#a#b#")
  @test.assert_eq(@common.is_supported_replace_regex("\\+{0}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a++{0}"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a++{2}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\w{2,2}?+"), false)
  // possessive+zero edges (self-caught before review): leading-zero
  // '{00}', comma '{0,m}' == the star walk, escaped-plus greedy
  @test.assert_eq(n("a++{00}").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("a++{0,2}").normalize("bab"), "#b#b#")
  @test.assert_eq(n("\\w++{0}").normalize("aaa"), "#a#a#a#")
  @test.assert_eq(n("\\+{2}").normalize("+ ++ "), "+ # ")
  @test.assert_eq(n("\\+").normalize("+"), "#")
  @test.assert_eq(@common.is_supported_replace_regex("a++{0,2}"), true)
  // round-1 review: '{0,0}' == zero reps; malformed/oversized tails
  // stay literal/error; '{1}'/'{01}'/'{1,m}' == plain greedy 'X+';
  // exact n >= 2 never matches (loud)
  @test.assert_eq(n("a++{0,0}").normalize("bab"), "#b#a#b#")
  @test.assert_eq(n("a++{1}").normalize("bab"), "b#b")
  @test.assert_eq(n("a++{1,2}").normalize("bab"), "b#b")
  @test.assert_eq(n("\\w++{1}").normalize("aaa"), "#")
  @test.assert_eq(@common.is_supported_replace_regex("a++{0,x}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("a++{0,100001}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("a++{2,3}"), false)
  // round-2 review: REVERSED possessive and kin bounds — upper==0
  // is the star walk, nonzero reversed is the swapped 1-or-more
  // greedy ('a++{2,1}'/'a+{2,1}' on 'bab' -> 'b#b'); the kin
  // ('a+{1,0}') was a SILENT-WRONG on main
  @test.assert_eq(n("a++{1,0}").normalize("bab"), "#b#b#")
  @test.assert_eq(n("a++{2,1}").normalize("bab"), "b#b")
  @test.assert_eq(n("a+{1,0}").normalize("bab"), "#b#b#")
  @test.assert_eq(n("a+{2,1}").normalize("bab"), "b#b")
  @test.assert_eq(n("\\w+{1,0}").normalize("aaa"), "#")
  // round-3: upper >= 2 reversed — possessive NEVER matches (loud);
  // kin == the swapped-minimum window 'X{up,}'
  @test.assert_eq(@common.is_supported_replace_regex("a++{3,2}"), false)
  @test.assert_eq(n("a+{3,2}").normalize("bab"), "bab")
  @test.assert_eq(n("a+{3,2}").normalize("aabaa"), "#b#")
  @test.assert_eq(n("\\w+{3,2}").normalize("ab"), "#")
}

///|
/// Unknown-escape literal family (probed 0.22.2, fresh objects, all
/// ASCII letters swept; round-1 review hardened): 15 letters are the
/// letter itself (g i j k l m q E F I J L Q T U V), four are control
/// chars ('\a' BEL, '\e' ESC, '\f' FF, '\v' VT). 'o' is onig's OCTAL
/// escape under braces ('\o{101}' == 'A', '\o{0,2}' errors) —
/// literal-o only via bare/'+'/'?'/'{,m}' spellings. '\x' is a quirk
/// (bare literal-x; '+'/'{n}' never match; '?' walks empty — loud
/// here). '\p'/'\P'/'\u' compute bare (brace forms error); '\c'
/// never-matches; '\h' is a hex-digit class (loud, pre-existing).
/// The optional '?' tail == '{0,1}' for any base.
test "unknown-escape literal family" {
  let n = fn(p : String) -> @normalizer.Normalizer {
    @normalizer.Normalizer::Replace(pattern=p, content="#")
  }
  @test.assert_eq(n("\\q{0}").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\q{2}").normalize("aqqb"), "a#b")
  @test.assert_eq(n("\\q+").normalize("aqqb"), "a#b")
  @test.assert_eq(n("\\q?").normalize("zqz"), "#z#z#")
  @test.assert_eq(n("\\g{0}").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\g{2}").normalize("aggb"), "a#b")
  @test.assert_eq(n("\\g+").normalize("aggb"), "a#b")
  @test.assert_eq(n("\\g?").normalize("zgz"), "#z#z#")
  @test.assert_eq(n("\\i{0}").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\i{2}").normalize("aiib"), "a#b")
  @test.assert_eq(n("\\i+").normalize("aiib"), "a#b")
  @test.assert_eq(n("\\i?").normalize("ziz"), "#z#z#")
  @test.assert_eq(n("\\Q{0}").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\Q{2}").normalize("aQQb"), "a#b")
  @test.assert_eq(n("\\Q+").normalize("aQQb"), "a#b")
  @test.assert_eq(n("\\Q?").normalize("zQz"), "#z#z#")
  @test.assert_eq(n("\\T{0}").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\T{2}").normalize("aTTb"), "a#b")
  @test.assert_eq(n("\\T+").normalize("aTTb"), "a#b")
  @test.assert_eq(n("\\T?").normalize("zTz"), "#z#z#")
  @test.assert_eq(n("\\e{0}").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\e{2}").normalize("x\u{1b}\u{1b}y"), "x#y")
  @test.assert_eq(n("\\e+").normalize("x\u{1b}\u{1b}y"), "x#y")
  @test.assert_eq(n("\\e?").normalize("z\u{1b}z"), "#z#z#")
  @test.assert_eq(n("\\a{0}").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\a{2}").normalize("x\u{7}\u{7}y"), "x#y")
  @test.assert_eq(n("\\a+").normalize("x\u{7}\u{7}y"), "x#y")
  @test.assert_eq(n("\\a?").normalize("z\u{7}z"), "#z#z#")
  @test.assert_eq(n("\\v{0}").normalize("ab"), "#a#b#")
  @test.assert_eq(n("\\v{2}").normalize("x\u{b}\u{b}y"), "x#y")
  @test.assert_eq(n("\\v+").normalize("x\u{b}\u{b}y"), "x#y")
  @test.assert_eq(n("\\v?").normalize("z\u{b}z"), "#z#z#")
  @test.assert_eq(n("\\o").normalize("aoob"), "a##b")
  @test.assert_eq(n("\\o+").normalize("aoob"), "a#b")
  @test.assert_eq(n("\\o?").normalize("zo z"), "#z# #z#")
  @test.assert_eq(n("\\o{,2}").normalize("aoob"), "#a#b#")
  @test.assert_eq(n("\\q").normalize("aqa"), "a#a")
  @test.assert_eq(n("[\\q]").normalize("aqb"), "a#b")
  @test.assert_eq(n("a?").normalize("b"), "#b#")
  @test.assert_eq(n("\\w?").normalize("ab"), "##")
  @test.assert_eq(n("\\g?").normalize("q"), "#q#")
  @test.assert_eq(@common.is_supported_replace_regex("\\q"), true)
  @test.assert_eq(@common.is_supported_replace_regex("a?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\o{0}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\o{101}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\o{0,2}"), false)
  // round-2: malformed comma tails are HF literals — loud
  @test.assert_eq(@common.is_supported_replace_regex("\\o{,}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\o{,2x}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\o{1}"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\o+"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\o?"), true)
  @test.assert_eq(@common.is_supported_replace_regex("\\x+"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\z"), false)
  @test.assert_eq(@common.is_supported_replace_regex("\\c{0}"), false)
}
