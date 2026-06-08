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
