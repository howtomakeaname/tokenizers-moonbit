// Text/aligned equivalence sweep: the normalizer's Replace must produce
// the SAME text through `normalize` (the normalize_str path) and
// `normalize_aligned` (the encode path). Both paths share the
// match-span families via `@common.replace_family_spans`; this sweep
// pins that equivalence over every hardcoded SPM spelling in
// `replace_all` plus the generic quantifier/class shapes.

///|
test "replace normalize and normalize_aligned produce identical text" {
  let pats : Array[String] = [
    "\\b[A-Za-z0-9_]+\\b", "\\b\\w+\\b", "\\D+", "\\P{Letter}+", "\\P{L}+", "\\P{Number}+",
    "\\P{N}+", "\\P{Punctuation}+", "\\P{P}+", "\\P{Symbol}+", "\\P{S}+", "\\W+",
    "\\d+", "\\d+$", "\\d{1,2}", "\\d{1,3}", "\\d{1,4}", "\\d{2,}", "\\d{2}", "\\d{3}",
    "\\d{4}", "\\p{Letter}+", "\\p{Letter}+$", "\\p{Letter}{2,}", "\\p{Letter}{2}",
    "\\p{Letter}{3}", "\\p{Letter}{4}", "\\p{L}+", "\\p{L}+$", "\\p{L}{2,}", "\\p{L}{2}",
    "\\p{L}{3}", "\\p{L}{4}", "\\p{Number}+", "\\p{Number}+$", "\\p{Number}{1,3}",
    "\\p{Number}{2,}", "\\p{Number}{2}", "\\p{Number}{3}", "\\p{Number}{4}", "\\s+",
    "\\s+$", "\\s{1,2}", "\\s{2,}", "\\s{2,4}", "\\s{2}", "\\w+", "\\w+$", "\\w{0,2}",
    "\\w{1,3}", "\\w{2,}", "\\w{2}", "\\w{3}", "\\w{4}", "^\\d+", "^\\s+", "^\\w+",
    "a+", "a{0}", "a{0,1}", "a{0,2}", "a{0,}", "a{2}", "a{2,}", "a{2,3}", "[ \\t]+",
    "[ \\t]{2,}", "[ \\t]{2}", "[0-9]{0,2}", "[\\s]{2,}", "[\\w]{0,2}",
  ]
  let inputs : Array[String] = [
    "", "a", "  ", "zaaz", "zaaaaz", "z55y", "z55555y", "a\n\nb", "x  y  ", "  A\n  B\nC",
    "x\t\ny", "ab! 55 ²中", "a²b", "é中 x", "aaaaa bbb", "\n\n  B", "x  \n\n  y",
    " 123 45 ", "zz", "a b c",
  ]
  let mismatches : Array[String] = []
  for p in pats {
    let n = @normalizer.Normalizer::Replace(pattern=p, content="#")
    for s in inputs {
      let want = n.normalize(s)
      let got = n.normalize_aligned(s).0
      if want != got {
        mismatches.push(p + " on " + s + ": " + want + " vs " + got)
      }
    }
  }
  for m in mismatches {
    println(m)
  }
  @test.assert_eq(mismatches.length(), 0)
}
