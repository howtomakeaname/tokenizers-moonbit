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

///|
/// BPEDecoder replaces ALL suffix occurrences per token (mid-token
/// included), space for non-last tokens and "" for the last.
test "bpe decoder replaces mid-token suffix occurrences" {
  let d = Decoder::BPEDecoder(suffix="</w>")
  @test.assert_eq(d.decode(["a</w>b", "cd"]), "a bcd")
  @test.assert_eq(d.decode(["a</w>b</w>", "cd"]), "a b cd")
  @test.assert_eq(d.decode(["cd", "a</w>b"]), "cdab")
}

///|
/// CTC cleanup runs per token, so a token with a trailing space keeps it.
test "ctc cleanup is per token" {
  let d = Decoder::CTC(
    pad_token="<pad>",
    word_delimiter_token="|",
    cleanup=true,
  )
  @test.assert_eq(d.decode(["hi ", "!"]), "hi !")
}

///|
/// wordpiece cleanup exact rule list: no ";" / ":" rules (spaces stay),
/// " ' " contracts fully, " do not" -> " don't".
test "wordpiece cleanup rule list matches 0.22.2 exactly" {
  let d = Decoder::wordpiece(prefix="##", cleanup=true)
  @test.assert_eq(
    d.decode(["do", "n't", "stop", ";", "test", ":", "ok", ",", "yes", "."]),
    "don't stop ; test : ok, yes.",
  )
  // apostrophe as its own token keeps its prepended space (" ' " rule
  // needs the trailing space inside one token)
  @test.assert_eq(d.decode(["a", "'", "b"]), "a ' b")
  // the " do not" rule fires within one token surface only
  @test.assert_eq(d.decode(["a", "do", "not"]), "a do not")
  @test.assert_eq(d.decode(["a", " do not"]), "a  don't")
}

///|
/// The public Decoder::decode standalone Replace path agrees with the
/// decode_chain gate: supported patterns decode, unsupported ones are
/// rejected by replace_pattern_supported (the decode path aborts).
test "standalone replace decode uses supported patterns" {
  let d = Decoder::Replace(pattern="\\s+", content=" ")
  @test.assert_eq(d.decode(["a b", "  c"]), "a b c")
  @test.assert_eq(replace_pattern_supported("l+o"), false)
}

///|
/// Decoder Replace: bare single-character classes replace per character
/// and plain-`+` ASCII spellings keep fullwidth digits (review round 2).
test "decoder replace bare classes and ascii plus" {
  let bare = Decoder::Replace(pattern="[0-9]", content="#")
  @test.assert_eq(bare.decode(["a", "5", "b"]), "a#b")
  let plus = Decoder::Replace(pattern="[0-9]+", content="#")
  @test.assert_eq(plus.decode(["a", "５", "b"]), "a５b")
  // decoder Replace is per-token: each "5" is its own token -> "#"
  @test.assert_eq(plus.decode(["a", "5", "5", "b"]), "a##b")
  let word = Decoder::Replace(pattern="[A-Za-z0-9_]+", content="#")
  @test.assert_eq(word.decode(["a", "é", "b"]), "#é#")
}

///|
/// Single-char literal bounded quantifiers through both decoder paths
/// (HF decoders are per-token: a{2} only replaces within one surface).
test "decoder literal bounded quantifiers" {
  let d = Decoder::Replace(pattern="a{2}", content="#")
  @test.assert_eq(d.decode(["xaa", "y"]), "x#y")
  @test.assert_eq(d.decode(["x", "a", "a", "y"]), "xaay")
  let d2 = Decoder::Replace(pattern="a{2,3}", content="#")
  @test.assert_eq(d2.decode(["zaaaay"]), "z#ay")
}

///|
/// Zero-minimum quantifier patterns go through the same onig
/// empty-match semantics as the normalizer (probed 0.22.2:
/// `a{0,2}` on "zaaz" -> "#z#z#", `a{0}` on "aaa" -> "#a#a#a#",
/// `\s{0,}` on "x  " -> "#x#"); decoding stays per-token.
test "replace decoder handles zero-min quantifiers per onig semantics" {
  let d = Decoder::Replace(pattern="a{0,2}", content="#")
  @test.assert_eq(d.decode(["zaaz", "zz"]), "#z#z##z#z#")
  let exact0 = Decoder::Replace(pattern="a{0}", content="#")
  @test.assert_eq(exact0.decode(["aaa"]), "#a#a#a#")
  let ws = Decoder::Replace(pattern="\\s{0,}", content="#")
  @test.assert_eq(ws.decode(["x  "]), "#x#")
  // onig rejects repeat bounds above 100000 at load in HF; ours fails
  // at load too (the spec stops matching, the gate raises).
  @test.assert_eq(replace_pattern_supported("a{0,100000}"), true)
  @test.assert_eq(replace_pattern_supported("a{0,100001}"), false)
}

///|
/// Decoder per-token replace keeps the `\p{N}` (full N: Nd + Nl + No)
/// vs `\d` (Nd) split (probed 0.22.2 on "a²¼Ⅰ①₃0５").
test "replace decoder splits p{N} full-N from d-Nd" {
  let pn = Decoder::Replace(pattern="\\p{N}+", content="#")
  @test.assert_eq(pn.decode(["a²¼Ⅰ①₃0５"]), "a#")
  let d = Decoder::Replace(pattern="\\d+", content="#")
  @test.assert_eq(d.decode(["a²¼Ⅰ①₃0５"]), "a²¼Ⅰ①₃#")
  let neg = Decoder::Replace(pattern="\\P{N}+", content="#")
  @test.assert_eq(neg.decode(["a²¼Ⅰ"]), "#²¼Ⅰ")
  let ex = Decoder::Replace(pattern="\\p{N}{2}", content="#")
  @test.assert_eq(ex.decode(["a¼0５"]), "a#５")
}
