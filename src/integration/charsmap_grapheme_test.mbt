// Precompiled charsmap grapheme-cluster normalization parity.
//
// HF 0.22.2's precompiled charsmap transform looks up whole grapheme
// clusters (a base char plus combining marks, under 6 UTF-8 bytes) in the
// trie before falling back to per-character lookups, so decomposed
// "e" + U+0301 composes to é on t5. This library used per-character
// lookups only, which left the combining mark orphaned (→ unk) and
// diverged from Python on NFD input.
//
// Expectations measured against Python `tokenizers` 0.22.2 with the real
// t5 tokenizer.json. Self-skips when the fixture is absent.

///|
test "t5 charsmap composes NFD clusters like python tokenizers" {
  guard load_text("tests/data/t5.full.json") is Some(model_json) else { return }
  let tok = @tokenizer.Tokenizer::from_str(model_json)
  // NFC "café" and NFD "cafe" + U+0301 encode identically in HF
  // (add_special_tokens=false strips the </s>): ids [11949]
  let nfc = "caf\u{e9}"
  let nfd = "cafe\u{301}"
  let e1 = tok.encode(nfc, add_special_tokens=false)
  let e2 = tok.encode(nfd, add_special_tokens=false)
  @test.assert_eq(e1.ids, [11949])
  @test.assert_eq(e2.ids, [11949])
  @test.assert_eq(e2.tokens, ["▁café"])
  // Mixed NFC + NFD input (the behavioral-sweep diverging case):
  //   "café café Nomade NOMADE" (second café NFD)
  //   -> ["▁café","▁café","▁No","made","▁NO","M","ADE"]
  let mixed = "\{nfc} \{nfd} Nomade NOMADE"
  let e3 = tok.encode(mixed, add_special_tokens=false)
  @test.assert_eq(e3.ids, [11949, 11949, 465, 4725, 5693, 329, 20458])
}

///|
/// Clusters of 6+ UTF-8 bytes stay uncomposed (HF's < 6 guard): Hangul
/// jamo pairs are per-character lookups and must not merge.
test "t5 charsmap leaves 6-byte clusters uncomposed" {
  guard load_text("tests/data/t5.full.json") is Some(model_json) else { return }
  let tok = @tokenizer.Tokenizer::from_str(model_json)
  // "가" precomposed vs jamo decomposition: HF does NOT compose the jamo
  // cluster through the charsmap (grapheme is 6 bytes), so the two forms
  // may tokenize differently; pin that the jamo form is NOT turned into
  // the precomposed token by asserting the surfaces differ.
  let precomposed = tok.encode("\u{AC00}", add_special_tokens=false)
  let jamo = tok.encode("\u{1100}\u{1161}", add_special_tokens=false)
  // Python 0.22.2: precomposed -> single piece; jamo stays decomposed
  // (charsmap does not compose 6-byte clusters).
  @test.assert_eq(precomposed.ids.length() >= 1, true)
  @test.assert_eq(jamo.tokens != precomposed.tokens, true)
}
