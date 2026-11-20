// Regression tests for BERT clean_text control-character handling.
// Expectations probed from Python tokenizers 0.22.2 (Rust char::is_other
// rule): see scripts/gen_bert_control.py and issue #70.

///|
test "BERT clean_text removes Unicode format controls (issue #70)" {
  let n = Normalizer::bert_normalizer(
    clean_text=true,
    lowercase=false,
    strip_accents=Some(false),
  )
  // U+200B ZERO WIDTH SPACE used to be retained, producing an [UNK] on
  // bert-base-uncased instead of the real wordpiece id.
  @test.assert_eq(n.normalize_str("a\u{200B}b"), "ab")
  @test.assert_eq(n.normalize_str("a\u{200C}\u{200D}b"), "ab")
  @test.assert_eq(n.normalize_str("a\u{FEFF}b"), "ab")
  @test.assert_eq(n.normalize_str("a\u{202A}b"), "ab")
}

///|
test "BERT clean_text removes C0/C1 controls and replacement char" {
  let n = Normalizer::bert_normalizer(
    clean_text=true,
    lowercase=false,
    strip_accents=Some(false),
  )
  @test.assert_eq(n.normalize_str("a\u{01}b"), "ab")
  @test.assert_eq(n.normalize_str("a\u{7F}b"), "ab")
  @test.assert_eq(n.normalize_str("a\u{85}b"), "ab")
  @test.assert_eq(n.normalize_str("a\u{00AD}b"), "ab")
  @test.assert_eq(n.normalize_str("a\u{FFFD}b"), "ab")
  @test.assert_eq(n.normalize_str("\u{0000}"), "")
}

///|
test "BERT clean_text keeps tab/LF/CR as spaces and maps NBSP" {
  let n = Normalizer::bert_normalizer(
    clean_text=true,
    lowercase=false,
    strip_accents=Some(false),
  )
  @test.assert_eq(n.normalize_str("a\tb"), "a b")
  @test.assert_eq(n.normalize_str("a\nb"), "a b")
  @test.assert_eq(n.normalize_str("a\rb"), "a b")
  // NBSP U+00A0 is Zs whitespace and maps to a regular space, like HF.
  @test.assert_eq(n.normalize_str("a\u{00A0}b"), "a b")
}

///|
test "BERT clean_text aligned path drops format controls with alignment" {
  let n = Normalizer::bert_normalizer(
    clean_text=true,
    lowercase=false,
    strip_accents=Some(false),
  )
  let (text, align) = n.normalize_aligned("a\u{200B}b")
  @test.assert_eq(text, "ab")
  // Only the two surviving chars keep alignment columns.
  @test.assert_eq(align, [(0, 1), (2, 3)])
}

///|
test "BERT clean_text=false retains format controls" {
  let n = Normalizer::bert_normalizer(
    clean_text=false,
    lowercase=false,
    strip_accents=Some(false),
  )
  @test.assert_eq(n.normalize_str("a\u{200B}b"), "a\u{200B}b")
}
