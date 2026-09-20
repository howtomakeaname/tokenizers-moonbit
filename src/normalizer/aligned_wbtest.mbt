// Direct alignment-column tests for compose/replace semantics
// (expectations probed from Python tokenizers 0.22.2).

///|
/// NFC composition keeps the composed char on the FIRST composed-from
/// char's span (HF transform -N contract): "z"+"e"+U+0301+"z" -> "zéz"
/// with spans (0,1),(1,2),(2,3) — é keeps e's span, not the merged run.
test "nfc compose span keeps the first char span" {
  let (text, align) = Normalizer::NFC.normalize_aligned("ze\u{301}z")
  @test.assert_eq(text, "zéz")
  @test.assert_eq(align, [(0, 1), (1, 2), (3, 4)])
}

///|
/// Replace content chars attach to the span of the LAST char of the
/// match (HF +0 contract on the final matched char): Regex "a+" -> "X"
/// on "zaa" gives X the span of the last a.
test "replace content attaches to last matched char" {
  // multi-char matches attach every content char to the LAST matched
  // char's span: Regex "aa" -> "X" on "zaa" gives X the span (2,3)
  let n = Normalizer::Replace(pattern="aa", content="XY")
  let (text, align) = n.normalize_aligned("zaa")
  @test.assert_eq(text, "zXY")
  @test.assert_eq(align, [(0, 1), (2, 3), (2, 3)])
}

///|
/// ReplaceString patterns are literal: the two-character pattern "\n"
/// (backslash + n) does not match a newline.
test "replacestring patterns stay literal" {
  let n = Normalizer::ReplaceString(pattern="\\n", content="X")
  let (text, align) = n.normalize_aligned("a\nb")
  @test.assert_eq(text, "a\nb")
  @test.assert_eq(align, [(0, 1), (1, 2), (2, 3)])
}
