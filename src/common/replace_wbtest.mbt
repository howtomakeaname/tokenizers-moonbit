// White-box tests for shared replacement helpers used by normalizer/decoder.

///|
test "replace helpers cover regex run semantics" {
  @test.assert_eq(replace_literal("a@@b@@", "@@", "-"), "a-b-")
  @test.assert_eq(
    replace_leading_runs("\t  abc", "", fn(c) { is_unicode_whitespace(c.to_int()) }),
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
  guard simple_split_regex_matches(chars, "\\s+") is Some(spaces) else {
    abort("expected whitespace matches")
  }
  @test.assert_eq(spaces.length(), 2)
  guard literal_matches(chars, "12") is Some(lit) else {
    abort("expected literal matches")
  }
  @test.assert_eq(lit.length(), 1)
  @test.assert_eq(lit[0].start, 1)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{N}{1,3}"), true)
}
