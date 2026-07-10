// Whitebox tests for Normalizer setter aliases (Python binding compatibility).

///|
test "Normalizer::set_left / set_right for Strip" {
  let n = Strip(left=true, right=false)
  @test.assert_eq(n.left(), Some(true))
  @test.assert_eq(n.right(), Some(false))
  let n2 = n.set_left(false)
  @test.assert_eq(n2.left(), Some(false))
  @test.assert_eq(n2.right(), Some(false))
  let n3 = n.set_right(true)
  @test.assert_eq(n3.left(), Some(true))
  @test.assert_eq(n3.right(), Some(true))
  // Original unchanged
  @test.assert_eq(n.left(), Some(true))
}

///|
test "Normalizer::set_left on non-Strip returns self" {
  let n = Normalizer::NFC
  @test.assert_eq(n.left(), None)
  let n2 = n.set_left(true)
  // NFC is unchanged
  @test.assert_eq(n2.kind(), "NFC")
}

///|
test "Normalizer::set_clean_text for BertNormalizer" {
  let n = BertNormalizer(
    clean_text=true, handle_chinese_chars=true,
    strip_accents=Some(false), lowercase=false,
  )
  @test.assert_eq(n.clean_text(), Some(true))
  let n2 = n.set_clean_text(false)
  @test.assert_eq(n2.clean_text(), Some(false))
  @test.assert_eq(n2.handle_chinese_chars(), Some(true))
}

///|
test "Normalizer::set_handle_chinese_chars for BertNormalizer" {
  let n = BertNormalizer(
    clean_text=true, handle_chinese_chars=true,
    strip_accents=None, lowercase=true,
  )
  @test.assert_eq(n.handle_chinese_chars(), Some(true))
  let n2 = n.set_handle_chinese_chars(false)
  @test.assert_eq(n2.handle_chinese_chars(), Some(false))
  @test.assert_eq(n2.clean_text(), Some(true))
}

///|
test "Normalizer::set_strip_accents for BertNormalizer" {
  let n = BertNormalizer(
    clean_text=true, handle_chinese_chars=true,
    strip_accents=None, lowercase=false,
  )
  @test.assert_eq(n.strip_accents(), None)
  let n2 = n.set_strip_accents(Some(true))
  @test.assert_eq(n2.strip_accents(), Some(true))
}

///|
test "Normalizer::set_lowercase for BertNormalizer" {
  let n = BertNormalizer(
    clean_text=true, handle_chinese_chars=false,
    strip_accents=None, lowercase=false,
  )
  @test.assert_eq(n.lowercase(), Some(false))
  let n2 = n.set_lowercase(true)
  @test.assert_eq(n2.lowercase(), Some(true))
  @test.assert_eq(n2.handle_chinese_chars(), Some(false))
}

///|
test "Normalizer::set_prepend for Prepend" {
  let n = Prepend(prepend="▁")
  @test.assert_eq(n.prepend(), Some("▁"))
  let n2 = n.set_prepend("##")
  @test.assert_eq(n2.prepend(), Some("##"))
}

///|
test "Normalizer::set_prepend on non-Prepend returns self" {
  let n = Normalizer::NFC
  @test.assert_eq(n.prepend(), None)
  let n2 = n.set_prepend("##")
  @test.assert_eq(n2.kind(), "NFC")
}

///|
test "Normalizer::set_content for Replace" {
  let n = Replace(pattern="foo", content="bar")
  @test.assert_eq(n.content(), Some("bar"))
  let n2 = n.set_content("baz")
  @test.assert_eq(n2.content(), Some("baz"))
}
