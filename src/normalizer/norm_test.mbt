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
  // `{,n}` is a quantifier in onig: unsupported here -> load rejected
  @test.assert_raise(() => {
    @normalizer.Normalizer::from_json(
      @json.parse(
        "{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"a{,3}\"},\"content\":\"X\"}",
      ),
    )
  })
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
