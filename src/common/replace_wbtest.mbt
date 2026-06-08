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
    replace_min_char_runs(
      "a b  c\t\td",
      "_",
      fn(c) { is_unicode_whitespace(c.to_int()) },
      min_run=2,
    ),
    "a b_c_d",
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
  guard simple_split_regex_matches("a12345b".to_array(), "\\d{1,2}")
    is Some(bounded_digits_2) else {
    abort("expected bounded digit max-2 matches")
  }
  @test.assert_eq(bounded_digits_2.length(), 3)
  @test.assert_eq(bounded_digits_2[0].start, 1)
  @test.assert_eq(bounded_digits_2[0].stop, 3)
  @test.assert_eq(bounded_digits_2[1].start, 3)
  @test.assert_eq(bounded_digits_2[1].stop, 5)
  @test.assert_eq(bounded_digits_2[2].start, 5)
  @test.assert_eq(bounded_digits_2[2].stop, 6)
  guard simple_split_regex_matches("a12345b".to_array(), "\\p{N}{1,4}")
    is Some(bounded_digits_4) else {
    abort("expected bounded digit max-4 matches")
  }
  @test.assert_eq(bounded_digits_4.length(), 2)
  @test.assert_eq(bounded_digits_4[0].start, 1)
  @test.assert_eq(bounded_digits_4[0].stop, 5)
  @test.assert_eq(bounded_digits_4[1].start, 5)
  @test.assert_eq(bounded_digits_4[1].stop, 6)
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
  guard simple_split_regex_matches("ab_12,CD中".to_array(), "[A-Za-z0-9]+")
    is Some(ascii_alnum) else {
    abort("expected ASCII alnum matches")
  }
  @test.assert_eq(ascii_alnum.length(), 3)
  @test.assert_eq(ascii_alnum[0].start, 0)
  @test.assert_eq(ascii_alnum[0].stop, 2)
  @test.assert_eq(ascii_alnum[1].start, 3)
  @test.assert_eq(ascii_alnum[1].stop, 5)
  @test.assert_eq(ascii_alnum[2].start, 6)
  @test.assert_eq(ascii_alnum[2].stop, 8)
  guard simple_split_regex_matches("ab_12,CD中".to_array(), "[^A-Za-z0-9]+")
    is Some(non_ascii_alnum) else {
    abort("expected non-ASCII-alnum matches")
  }
  @test.assert_eq(non_ascii_alnum.length(), 3)
  @test.assert_eq(non_ascii_alnum[0].start, 2)
  @test.assert_eq(non_ascii_alnum[0].stop, 3)
  @test.assert_eq(non_ascii_alnum[1].start, 5)
  @test.assert_eq(non_ascii_alnum[1].stop, 6)
  @test.assert_eq(non_ascii_alnum[2].start, 8)
  @test.assert_eq(non_ascii_alnum[2].stop, 9)
  guard simple_split_regex_matches("abé_12,CD中".to_array(), "[A-Za-z]+")
    is Some(ascii_letters) else {
    abort("expected ASCII letter matches")
  }
  @test.assert_eq(ascii_letters.length(), 2)
  @test.assert_eq(ascii_letters[0].start, 0)
  @test.assert_eq(ascii_letters[0].stop, 2)
  @test.assert_eq(ascii_letters[1].start, 7)
  @test.assert_eq(ascii_letters[1].stop, 9)
  guard simple_split_regex_matches("abé_12,CD中".to_array(), "[^A-Za-z]+")
    is Some(non_ascii_letters) else {
    abort("expected non-ASCII-letter matches")
  }
  @test.assert_eq(non_ascii_letters.length(), 2)
  @test.assert_eq(non_ascii_letters[0].start, 2)
  @test.assert_eq(non_ascii_letters[0].stop, 7)
  @test.assert_eq(non_ascii_letters[1].start, 9)
  @test.assert_eq(non_ascii_letters[1].stop, 10)
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
  guard simple_split_regex_matches("hi,!$+🙂ok。".to_array(), "\\p{P}+")
    is Some(punctuation) else {
    abort("expected punctuation matches")
  }
  @test.assert_eq(punctuation.length(), 2)
  @test.assert_eq(punctuation[0].start, 2)
  @test.assert_eq(punctuation[0].stop, 4)
  @test.assert_eq(punctuation[1].start, 9)
  @test.assert_eq(punctuation[1].stop, 10)
  guard simple_split_regex_matches("a$+🙂,b=≤c".to_array(), "\\p{S}+")
    is Some(symbols) else {
    abort("expected symbol matches")
  }
  @test.assert_eq(symbols.length(), 2)
  @test.assert_eq(symbols[0].start, 1)
  @test.assert_eq(symbols[0].stop, 4)
  @test.assert_eq(symbols[1].start, 6)
  @test.assert_eq(symbols[1].stop, 8)
  guard simple_split_regex_matches(
      "ab,$+🙂 cd。42".to_array(),
      "[\\p{P}\\p{S}]+",
    )
    is Some(punct_symbols) else {
    abort("expected punctuation-or-symbol matches")
  }
  @test.assert_eq(punct_symbols.length(), 2)
  @test.assert_eq(punct_symbols[0].start, 2)
  @test.assert_eq(punct_symbols[0].stop, 6)
  @test.assert_eq(punct_symbols[1].start, 9)
  @test.assert_eq(punct_symbols[1].stop, 10)
  guard simple_split_regex_matches(
      "ab,$+🙂 cd。42".to_array(),
      "[^\\s\\p{L}\\p{N}]+",
    )
    is Some(non_alnum_nonspace) else {
    abort("expected non-space letter/number inverse matches")
  }
  @test.assert_eq(non_alnum_nonspace.length(), 2)
  @test.assert_eq(non_alnum_nonspace[0].start, 2)
  @test.assert_eq(non_alnum_nonspace[0].stop, 6)
  @test.assert_eq(non_alnum_nonspace[1].start, 9)
  @test.assert_eq(non_alnum_nonspace[1].stop, 10)
  guard simple_split_regex_matches(chars, "\\s+") is Some(spaces) else {
    abort("expected whitespace matches")
  }
  @test.assert_eq(spaces.length(), 2)
  guard simple_split_regex_matches("a b  c\t\td".to_array(), "\\s{2,}")
    is Some(wide_spaces) else {
    abort("expected min whitespace matches")
  }
  @test.assert_eq(wide_spaces.length(), 2)
  @test.assert_eq(wide_spaces[0].start, 3)
  @test.assert_eq(wide_spaces[0].stop, 5)
  @test.assert_eq(wide_spaces[1].start, 6)
  @test.assert_eq(wide_spaces[1].stop, 8)
  guard simple_split_regex_matches("a\t b \n\rc".to_array(), "[^\\S\\r\\n]+")
    is Some(horizontal_spaces) else {
    abort("expected horizontal whitespace matches")
  }
  @test.assert_eq(horizontal_spaces.length(), 2)
  @test.assert_eq(horizontal_spaces[0].start, 1)
  @test.assert_eq(horizontal_spaces[0].stop, 3)
  @test.assert_eq(horizontal_spaces[1].start, 4)
  @test.assert_eq(horizontal_spaces[1].stop, 5)
  guard simple_split_regex_matches("a\r\nb\n\nc".to_array(), "[\\r\\n]+")
    is Some(newlines) else {
    abort("expected newline run matches")
  }
  @test.assert_eq(newlines.length(), 2)
  @test.assert_eq(newlines[0].start, 1)
  @test.assert_eq(newlines[0].stop, 3)
  @test.assert_eq(newlines[1].start, 4)
  @test.assert_eq(newlines[1].stop, 6)
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
  @test.assert_eq(is_simple_split_regex_pattern("[A-Za-z0-9]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^a-zA-Z0-9]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[A-Za-z]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^a-zA-Z]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{Punctuation}+$"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Symbol}]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{P}\\p{S}]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^\\s\\p{L}\\p{N}]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\s{2,}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^\\S\\r\\n]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\r\\n]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\d{1,2}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{N}{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Number}]{1,4}"), true)
}
