// HF punctuation classifier coverage (Rust `is_ascii_punctuation || is_punctuation`).
// Verified against Python `tokenizers` 0.22.2 probes.

///|
test "hf punctuation classifier covers ascii symbols and fullwidth punct" {
  @test.assert_eq(is_hf_punctuation('$'), true)
  @test.assert_eq(is_hf_punctuation('+'), true)
  @test.assert_eq(is_hf_punctuation('<'), true)
  @test.assert_eq(is_hf_punctuation('='), true)
  @test.assert_eq(is_hf_punctuation('^'), true)
  @test.assert_eq(is_hf_punctuation('`'), true)
  @test.assert_eq(is_hf_punctuation('|'), true)
  @test.assert_eq(is_hf_punctuation('~'), true)
  @test.assert_eq(is_hf_punctuation('\''), true)
  @test.assert_eq(is_hf_punctuation('＇'), true) // U+FF07 fullwidth apostrophe
  @test.assert_eq(is_hf_punctuation('！'), true) // U+FF01 fullwidth !
  @test.assert_eq(is_hf_punctuation('。'), true) // U+3002 ideographic stop
  @test.assert_eq(is_hf_punctuation('｡'), true) // U+FF61 halfwidth ideographic stop
  @test.assert_eq(is_hf_punctuation('你'), false) // CJK ideograph: not punct
  @test.assert_eq(is_hf_punctuation('a'), false)
  @test.assert_eq(is_hf_punctuation('1'), false)
  @test.assert_eq(is_hf_punctuation(' '), false)
  @test.assert_eq(is_hf_punctuation('Ｌ'), false) // fullwidth letter
}
