// Decoder parity with Python `tokenizers` 0.22.2, expectations taken from
// the persisted probe matrix (reports/parity-artifacts/decoder-probe-0.22.2.md).

///|
/// BPEDecoder: suffix occurrences become a space in every token except the
/// last, where they are just removed.
test "bpe decoder suffix semantics match 0.22.2" {
  let d = Decoder::BPEDecoder(suffix="</w>")
  @test.assert_eq(d.decode(["ab</w>", "cd</w>"]), "ab cd")
  @test.assert_eq(d.decode(["ab", "cd</w>"]), "abcd")
  @test.assert_eq(d.decode(["ab</w>", "cd"]), "ab cd")
  @test.assert_eq(d.decode(["hello", "##world"]), "hello##world")
}

///|
/// Metaspace always/first: ALL replacement chars in the first token are
/// dropped (including mid-token); later tokens map the replacement to a
/// space. `never` maps the first token's replacement to a space too.
test "metaspace decoder first-token drop matches 0.22.2" {
  let always = Decoder::Metaspace(
    replacement='▁',
    prepend_scheme="always",
    split=true,
  )
  @test.assert_eq(always.decode(["▁hello", "▁world"]), "hello world")
  @test.assert_eq(always.decode(["▁▁double"]), "double")
  @test.assert_eq(always.decode(["▁x▁y"]), "xy")
  @test.assert_eq(always.decode(["x", "▁"]), "x ")
  @test.assert_eq(always.decode(["hello", "##world"]), "hello##world")
  let first = Decoder::Metaspace(
    replacement='▁',
    prepend_scheme="first",
    split=true,
  )
  @test.assert_eq(first.decode(["▁hello", "▁world"]), "hello world")
  @test.assert_eq(first.decode(["▁▁double"]), "double")
  let never = Decoder::Metaspace(
    replacement='▁',
    prepend_scheme="never",
    split=true,
  )
  @test.assert_eq(never.decode(["▁hello", "▁world"]), " hello world")
  @test.assert_eq(never.decode(["▁▁double"]), "  double")
}

///|
/// Replace decoders are per-token replace-all (both the regex and the
/// literal variants); patterns never match across token boundaries.
/// Verified with Regex patterns over split tokens (only whole-token
/// matches apply). Patterns outside the supported deterministic regex
/// families (e.g. `l+o`, a quantified char followed by a literal) fail
/// explicitly instead of silently replacing literally.
test "replace decoder is per-token replace-all with explicit unsupported" {
  let ws = Decoder::Replace(pattern="\\s+", content=" ")
  @test.assert_eq(ws.decode(["a b", "  c\t\td"]), "a b c d")
  let lit = Decoder::ReplaceString(pattern="el", content="EL")
  @test.assert_eq(lit.decode(["hello"]), "hELlo")
  // supported pattern families
  @test.assert_eq(replace_pattern_supported("el"), true)
  @test.assert_eq(replace_pattern_supported("\\s+"), true)
  @test.assert_eq(replace_pattern_supported("\\s{2,}"), true)
  @test.assert_eq(replace_pattern_supported("café"), true)
  // unsupported: quantified single char + literal suffix -> explicit failure
  @test.assert_eq(replace_pattern_supported("l+o"), false)
  @test.assert_eq(replace_pattern_supported("a*b"), false)
}

///|
/// CTC: dedup first, pad_token deleted anywhere (tokens that become empty
/// are dropped); with cleanup the word delimiter maps to a space anywhere
/// (including inside tokens); without cleanup it stays literal.
test "ctc decoder substring semantics match 0.22.2" {
  let clean = Decoder::CTC(
    pad_token="<pad>",
    word_delimiter_token="|",
    cleanup=true,
  )
  @test.assert_eq(clean.decode(["h", "|", "i", "<pad>"]), "h i")
  @test.assert_eq(clean.decode(["h", "<pad>", "h", "i"]), "hhi")
  @test.assert_eq(clean.decode(["a|b"]), "a b")
  @test.assert_eq(clean.decode(["hi", "|", "there"]), "hi there")
  let raw = Decoder::CTC(
    pad_token="<pad>",
    word_delimiter_token="|",
    cleanup=false,
  )
  @test.assert_eq(raw.decode(["h", "|", "i", "<pad>"]), "h|i")
  @test.assert_eq(raw.decode(["hi", "|", "there"]), "hi|there")
  @test.assert_eq(raw.decode(["a", "<pad>x", "b"]), "axb")
}
