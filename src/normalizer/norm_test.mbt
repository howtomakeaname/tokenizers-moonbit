// Unicode normalization correctness, cross-checked against Python unicodedata.

///|
test "NFC composes combining marks" {
  // "cafe" + U+0301 (combining acute) -> "café" (composed)
  let s = "cafe\u{301}"
  @test.assert_eq(Normalizer::NFC.normalize(s), "café")
  @test.assert_eq(Normalizer::NFC.normalize_str(s), "café")
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
  @test.assert_eq(
    Normalizer::Precompiled.normalize("a\u{1680}b\u{2028}c\u{202f}d"),
    "a b c d",
  )
  @test.assert_eq(
    Normalizer::Precompiled.normalize("ascii\tfast\npath"),
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
  let normalizer = Normalizer::from_json(@json.parse(json))
  @test.assert_eq(normalizer.normalize("ABC A"), "xBC x")
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
    "W,W!W",
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
    "ab_12-中-cd",
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
    "ab_12-中-cd",
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

///|
test "Replace normalizer supports anchored inverse regex families" {
  @test.assert_eq(
    Normalizer::Replace(pattern="^\\S+", content="X").normalize("abc\t tail"),
    "X\t tail",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\D+$", content="_").normalize("123abc中"),
    "123_",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^\\P{Letter}+", content="").normalize(
      "123!?abc",
    ),
    "abc",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="\\P{Punctuation}+$", content="N").normalize(
      "?!abc🙂",
    ),
    "?!N",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="^[^\\p{P}\\p{S}]+", content="N").normalize(
      "abc12,$",
    ),
    "N,$",
  )
  @test.assert_eq(
    Normalizer::Replace(pattern="[^\\s\\p{L}\\p{N}]+$", content="").normalize(
      "abc42🙂+",
    ),
    "abc42",
  )
}

///|
test "normalizer exposes HF-style configuration getters" {
  let strip = Normalizer::Strip(left=true, right=false)
  @test.assert_eq(strip.kind(), "Strip")
  @test.assert_eq(strip.strip_left(), Some(true))
  @test.assert_eq(strip.get_strip_left(), Some(true))
  @test.assert_eq(strip.left(), Some(true))
  @test.assert_eq(strip.strip_right(), Some(false))
  @test.assert_eq(strip.get_strip_right(), Some(false))
  @test.assert_eq(strip.right(), Some(false))
  @test.assert_eq(Normalizer::NFC.left(), None)
  @test.assert_eq(Normalizer::NFC.right(), None)

  let replace = Normalizer::Replace(pattern="\\s+", content=" ")
  @test.assert_eq(replace.kind(), "Replace")
  @test.assert_eq(replace.pattern(), Some("\\s+"))
  @test.assert_eq(replace.get_pattern(), Some("\\s+"))
  @test.assert_eq(replace.content(), Some(" "))
  @test.assert_eq(replace.get_content(), Some(" "))

  let prepend = Normalizer::Prepend(prepend="▁")
  @test.assert_eq(prepend.kind(), "Prepend")
  @test.assert_eq(prepend.prepend(), Some("▁"))
  @test.assert_eq(prepend.get_prepend(), Some("▁"))

  @test.assert_eq(Normalizer::lowercase_normalizer().kind(), "Lowercase")
  @test.assert_eq(Normalizer::lowercase_normalizer().normalize("ABC"), "abc")
  @test.assert_eq(Normalizer::strip_accents_normalizer().kind(), "StripAccents")
  @test.assert_eq(
    Normalizer::strip_accents_normalizer().normalize("café"),
    "cafe",
  )
  @test.assert_eq(Normalizer::nmt().kind(), "Nmt")
  @test.assert_eq(Normalizer::nmt().to_json(), Some("{\"type\":\"Nmt\"}"))
  @test.assert_eq(Normalizer::precompiled().kind(), "Precompiled")
  @test.assert_eq(
    Normalizer::precompiled().to_json(),
    Some("{\"type\":\"Precompiled\"}"),
  )

  let bert = Normalizer::BertNormalizer(
    clean_text=true,
    handle_chinese_chars=false,
    strip_accents=true,
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

  let seq = Normalizer::Sequence([Normalizer::Lowercase, replace])
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
  steps.push(Normalizer::NFC)
  @test.assert_eq(seq.normalizers().length(), 2)
  let getter_steps = seq.get_normalizers()
  getter_steps.push(Normalizer::NFC)
  @test.assert_eq(seq.get_normalizers().length(), 2)
  @test.assert_eq(Normalizer::NFC.kind(), "NFC")
  @test.assert_eq(Normalizer::Lowercase.pattern(), None)
}

///|
test "normalizer HF-style factories wrap enum variants" {
  @test.assert_eq(Normalizer::nfc().kind(), "NFC")
  @test.assert_eq(Normalizer::nfd().kind(), "NFD")
  @test.assert_eq(Normalizer::nfkc().normalize("Ａ"), "A")
  @test.assert_eq(Normalizer::nfkd().kind(), "NFKD")
  @test.assert_eq(
    Normalizer::byte_level().normalize("Hi 我"),
    Normalizer::ByteLevel.normalize("Hi 我"),
  )

  let strip = Normalizer::strip(left=false)
  @test.assert_eq(strip.kind(), "Strip")
  @test.assert_eq(strip.strip_left(), Some(false))
  @test.assert_eq(strip.strip_right(), Some(true))
  @test.assert_eq(
    strip.to_json(),
    Some("{\"type\":\"Strip\",\"strip_left\":false,\"strip_right\":true}"),
  )

  let replace = Normalizer::replace("\\s+", " ")
  @test.assert_eq(replace.kind(), "Replace")
  @test.assert_eq(replace.pattern(), Some("\\s+"))
  @test.assert_eq(replace.content(), Some(" "))

  let prepend = Normalizer::prepend_normalizer("▁")
  @test.assert_eq(prepend.kind(), "Prepend")
  @test.assert_eq(prepend.prepend(), Some("▁"))
  @test.assert_eq(prepend.normalize("word"), "▁word")

  let bert = Normalizer::bert_normalizer(lowercase=false)
  @test.assert_eq(bert.kind(), "BertNormalizer")
  @test.assert_eq(bert.lowercase(), Some(false))
  @test.assert_eq(bert.strip_accents(), Some(false))
  let forced_accents = Normalizer::bert_normalizer(
    lowercase=false,
    strip_accents=Some(true),
  )
  @test.assert_eq(forced_accents.strip_accents(), Some(true))

  let seq = Normalizer::sequence([Normalizer::nfc(), replace])
  @test.assert_eq(seq.kind(), "Sequence")
  @test.assert_eq(seq.normalizers().map(n => n.kind()), ["NFC", "Replace"])
}

///|
test "normalizer exposes JSON state and string aliases" {
  let norm = Normalizer::Sequence([
    Normalizer::Lowercase,
    Normalizer::Replace(pattern="\\s+", content=" "),
  ])
  let state = norm.__getstate__()
  @test.assert_eq(norm.__str__(), state.json)
  @test.assert_eq(norm.__repr__(), state.json)
  @test.assert_eq(Normalizer::__setstate__(state).to_json(), norm.to_json())

  let parsed = Normalizer::from_state(
    NormalizerState::new(
      "{\"type\":\"Strip\",\"strip_left\":true,\"strip_right\":false}",
    ),
  )
  @test.assert_eq(parsed.kind(), "Strip")
  @test.assert_eq(parsed.strip_right(), Some(false))
}

///|
test "normalizer state rejects components without serialized JSON" {
  let json = "{\"type\":\"Precompiled\",\"precompiled_charsmap\":\"" +
    "DAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQQ0AAAAAAAB4AA==" +
    "\"}"
  let norm = Normalizer::from_json(@json.parse(json))
  let mut raised = false
  try norm.__getstate__() |> ignore catch {
    @types.UnsupportedComponent(_) => raised = true
    _ => ()
  }
  @test.assert_eq(raised, true)
}
