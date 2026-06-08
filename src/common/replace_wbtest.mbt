// White-box tests for shared replacement helpers used by normalizer/decoder.

///|
test "replace helpers cover regex run semantics" {
  @test.assert_eq(replace_literal("a@@b@@", "@@", "-"), "a-b-")
  @test.assert_eq(
    replace_literal("▁hello▁world", "▁", " "),
    " hello world",
  )
  @test.assert_eq(
    replace_leading_runs("\t  abc", "", fn(c) {
      is_unicode_whitespace(c.to_int())
    }),
    "abc",
  )
  @test.assert_eq(
    replace_trailing_runs("abc\u{a0}\n", "", fn(c) {
      is_unicode_whitespace(c.to_int())
    }),
    "abc",
  )
  @test.assert_eq(
    replace_char_runs("a12b003", "#", fn(c) { is_ascii_digit(c) }),
    "a#b#",
  )
  @test.assert_eq(
    replace_bounded_char_runs(
      "a12345b",
      "#",
      fn(c) { is_ascii_digit(c) },
      max_run=3,
    ),
    "a##b",
  )
  @test.assert_eq(replace_space_runs("a  b   c", "_", min_run=2), "a_b_c")
  @test.assert_eq(replace_whitespace_runs("a\t\u{3000}b\n", " "), "a b ")
}

///|
test "split regex helpers cover simple patterns" {
  let chars = "a12 b\u{3000}003".to_array()
  guard simple_split_regex_matches(chars, "\\d+") is Some(digits) else {
    abort("expected digit matches")
  }
  @test.assert_eq(digits.length(), 2)
  @test.assert_eq(digits[0].start, 1)
  @test.assert_eq(digits[0].stop, 3)
  @test.assert_eq(digits[1].start, 6)
  @test.assert_eq(digits[1].stop, 9)
  guard simple_split_regex_matches("a12345b".to_array(), "\\d{1,3}")
    is Some(bounded_digits) else {
    abort("expected bounded digit matches")
  }
  @test.assert_eq(bounded_digits.length(), 2)
  @test.assert_eq(bounded_digits[0].start, 1)
  @test.assert_eq(bounded_digits[0].stop, 4)
  @test.assert_eq(bounded_digits[1].start, 4)
  @test.assert_eq(bounded_digits[1].stop, 6)
  guard simple_split_regex_matches(chars, "\\w+") is Some(words) else {
    abort("expected word matches")
  }
  @test.assert_eq(words.length(), 3)
  @test.assert_eq(words[0].start, 0)
  @test.assert_eq(words[0].stop, 3)
  @test.assert_eq(words[1].start, 4)
  @test.assert_eq(words[1].stop, 5)
  @test.assert_eq(words[2].start, 6)
  @test.assert_eq(words[2].stop, 9)
  guard simple_split_regex_matches(chars, "\\W+") is Some(non_words) else {
    abort("expected non-word matches")
  }
  @test.assert_eq(non_words.length(), 2)
  @test.assert_eq(non_words[0].start, 3)
  @test.assert_eq(non_words[0].stop, 4)
  @test.assert_eq(non_words[1].start, 5)
  @test.assert_eq(non_words[1].stop, 6)
  guard simple_split_regex_matches("abé中12!Ж".to_array(), "\\p{L}+")
    is Some(letters) else {
    abort("expected letter matches")
  }
  @test.assert_eq(letters.length(), 2)
  @test.assert_eq(letters[0].start, 0)
  @test.assert_eq(letters[0].stop, 4)
  @test.assert_eq(letters[1].start, 7)
  @test.assert_eq(letters[1].stop, 8)
  guard simple_split_regex_matches("abé中12!Ж".to_array(), "\\P{L}+")
    is Some(non_letters) else {
    abort("expected non-letter matches")
  }
  @test.assert_eq(non_letters.length(), 1)
  @test.assert_eq(non_letters[0].start, 4)
  @test.assert_eq(non_letters[0].stop, 7)
  guard simple_split_regex_matches(chars, "\\s+") is Some(spaces) else {
    abort("expected whitespace matches")
  }
  @test.assert_eq(spaces.length(), 2)
  guard simple_split_regex_matches("\t abc ".to_array(), "^\\s+")
    is Some(leading_spaces) else {
    abort("expected leading whitespace match")
  }
  @test.assert_eq(leading_spaces.length(), 1)
  @test.assert_eq(leading_spaces[0].start, 0)
  @test.assert_eq(leading_spaces[0].stop, 2)
  guard simple_split_regex_matches("abc123".to_array(), "\\d+$")
    is Some(trailing_digits) else {
    abort("expected trailing digit match")
  }
  @test.assert_eq(trailing_digits.length(), 1)
  @test.assert_eq(trailing_digits[0].start, 3)
  @test.assert_eq(trailing_digits[0].stop, 6)
  guard simple_split_regex_matches("Жabc12!".to_array(), "^\\p{L}+")
    is Some(leading_letters) else {
    abort("expected leading letter match")
  }
  @test.assert_eq(leading_letters.length(), 1)
  @test.assert_eq(leading_letters[0].start, 0)
  @test.assert_eq(leading_letters[0].stop, 4)
  guard literal_matches(chars, "12") is Some(lit) else {
    abort("expected literal matches")
  }
  @test.assert_eq(lit.length(), 1)
  @test.assert_eq(lit[0].start, 1)
  @test.assert_eq(is_simple_split_regex_pattern("\\b\\w+\\b"), true)
  @test.assert_eq(is_simple_split_regex_pattern("^\\p{L}+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\d+$"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Letter}]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{N}{1,3}"), true)
}
