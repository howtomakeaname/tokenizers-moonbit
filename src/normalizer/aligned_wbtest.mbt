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

///|
/// Zero-min quantifier offsets: content from a NON-EMPTY match attaches
/// to the last matched char; content from an EMPTY match at p attaches
/// to the PRECEDING char's span (p-1, p), zero-width (0, 0) at the
/// string start; the copied char after an empty match keeps its own
/// identity span. All expectations probed against Python 0.22.2 via a
/// WordLevel + Split([\s\S]) offset oracle.
test "zero-min replace offsets follow onig empty-match spans" {
  let n = Normalizer::Replace(pattern="a{0,2}", content="#")
  let (text, align) = n.normalize_aligned("zaaz")
  @test.assert_eq(text, "#z#z#")
  @test.assert_eq(align, [(0, 0), (0, 1), (2, 3), (3, 4), (3, 4)])
  let exact0 = Normalizer::Replace(pattern="a{0}", content="#")
  let (t2, a2) = exact0.normalize_aligned("zaz")
  @test.assert_eq(t2, "#z#a#z#")
  @test.assert_eq(a2, [(0, 0), (0, 1), (0, 1), (1, 2), (1, 2), (2, 3), (2, 3)])
  let ws = Normalizer::Replace(pattern="\\s{0,2}", content="#")
  let (t3, a3) = ws.normalize_aligned("x  y")
  @test.assert_eq(t3, "#x#y#")
  @test.assert_eq(a3, [(0, 0), (0, 1), (2, 3), (3, 4), (3, 4)])
}

///|
/// Bounded literal quantifier offsets: `a{2,4}` run replacement attaches
/// content to the last matched char (probed 0.22.2: 'zaaz' -> ['z','#',
/// 'z'] offsets [(0,1),(2,3),(3,4)]). This family previously no-opped on
/// the aligned path used by encode.
test "bounded literal quantifier offsets attach to last matched char" {
  let n = Normalizer::Replace(pattern="a{2,4}", content="#")
  let (text, align) = n.normalize_aligned("zaaz")
  @test.assert_eq(text, "z#z")
  @test.assert_eq(align, [(0, 1), (2, 3), (3, 4)])
  let min = Normalizer::Replace(pattern="a{2,}", content="#")
  let (t2, a2) = min.normalize_aligned("zaaz")
  @test.assert_eq(t2, "z#z")
  @test.assert_eq(a2, [(0, 1), (2, 3), (3, 4)])
}

///|
/// MULTILINE anchored replacement offsets: `^\s+` matches at every line
/// head, newlines included in the greedy run (probed 0.22.2: "^\s+" on
/// "\tA\n  B\nC" -> "#A\n#B\nC"). The aligned path previously used the
/// single-line leading run only.
test "anchored replace offsets are multiline" {
  let n = Normalizer::Replace(pattern="^\\s+", content="#")
  let (text, align) = n.normalize_aligned("\tA\n  B\nC")
  @test.assert_eq(text, "#A\n#B\nC")
  // '\t' covered by (0,1); '\n' after A is identity; the "  " run before
  // B attaches content to its last space (4,5); the untouched final line
  // 'C' keeps its identity span.
  @test.assert_eq(align, [
    (0, 1),
    (1, 2),
    (2, 3),
    (4, 5),
    (5, 6),
    (6, 7),
    (7, 8),
  ])
}
