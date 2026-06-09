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
    replace_min_char_runs(
      "a \tbc\n\n\nd    e",
      "_",
      fn(c) { is_unicode_whitespace(c.to_int()) },
      min_run=3,
    ),
    "a \tbc_d_e",
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
  @test.assert_eq(
    replace_exact_char_runs(
      "a12345b",
      "#",
      fn(c) { is_ascii_digit(c) },
      exact_run=2,
    ),
    "a##5b",
  )
  @test.assert_eq(
    replace_exact_char_runs(
      "a \t\u{a0}b\n\n\nc    d",
      "_",
      fn(c) { is_unicode_whitespace(c.to_int()) },
      exact_run=3,
    ),
    "a_b_c_ d",
  )
  @test.assert_eq(
    replace_bounded_simple_regex("ab_12,cde", "\\w{1,3}", "W"),
    Some("WW,W"),
  )
  @test.assert_eq(
    replace_bounded_simple_regex("abc123DE", "[A-Za-z]{1,2}", "L"),
    Some("LL123L"),
  )
  @test.assert_eq(
    replace_bounded_simple_regex("hi!!!!ok。?", "\\p{P}{1,3}", "P"),
    Some("hiPPokP"),
  )
  @test.assert_eq(
    replace_bounded_simple_regex("a,$+🙂b", "[\\p{P}\\p{S}]{1,3}", "_"),
    Some("a__b"),
  )
  @test.assert_eq(
    replace_bounded_simple_regex("a12 bc003", "\\D{1,3}", "_"),
    Some("_12_003"),
  )
  @test.assert_eq(
    replace_bounded_simple_regex("ab_12,中!cd", "\\W{1,2}", "-"),
    Some("ab_12--cd"),
  )
  @test.assert_eq(
    replace_bounded_simple_regex(
      "ab,$+🙂 cd。42", "[^\\s\\p{L}\\p{N}]{1,3}", "#",
    ),
    Some("ab## cd#42"),
  )
  @test.assert_eq(
    replace_simple_regex("ab_12,中!cd", "\\w+", "W"),
    Some("W,中!W"),
  )
  @test.assert_eq(
    replace_simple_regex("abé中12!Ж", "\\p{L}+", "L"),
    Some("L12!L"),
  )
  @test.assert_eq(
    replace_simple_regex("hi,$+🙂ok。", "[\\p{P}\\p{S}]+", "_"),
    Some("hi_ok_"),
  )
  @test.assert_eq(
    replace_simple_regex("a1b12c１２3", "[\\d]{2,}", "#"),
    Some("a1b#c#"),
  )
  @test.assert_eq(
    replace_simple_regex("abc123DE", "[A-Za-z]{1,2}", "L"),
    Some("LL123L"),
  )
  @test.assert_eq(
    replace_simple_regex("no-match", "^\\d+", "#"),
    Some("no-match"),
  )
  @test.assert_eq(replace_simple_regex("a1234567b", "\\d{2,4}", "#"), Some("a##b"))
  @test.assert_eq(replace_simple_regex("hi!!!!?ok", "\\p{P}{2,4}", "_"), Some("hi_?ok"))
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
  guard simple_split_regex_matches(
      "a \t\u{a0}b\n\n\nc    d".to_array(),
      "[\\s]{3}",
    )
    is Some(exact_ws) else {
    abort("expected exact whitespace matches")
  }
  @test.assert_eq(exact_ws.length(), 3)
  @test.assert_eq(exact_ws[0].start, 1)
  @test.assert_eq(exact_ws[0].stop, 4)
  @test.assert_eq(exact_ws[1].start, 5)
  @test.assert_eq(exact_ws[1].stop, 8)
  @test.assert_eq(exact_ws[2].start, 9)
  @test.assert_eq(exact_ws[2].stop, 12)
  guard simple_split_regex_matches(
      "a \t\u{a0}b\n  c    d".to_array(),
      "[^\\S\\r\\n]{3,}",
    )
    is Some(min_horizontal_ws) else {
    abort("expected horizontal whitespace min-run matches")
  }
  @test.assert_eq(min_horizontal_ws.length(), 2)
  @test.assert_eq(min_horizontal_ws[0].start, 1)
  @test.assert_eq(min_horizontal_ws[0].stop, 4)
  @test.assert_eq(min_horizontal_ws[1].start, 9)
  @test.assert_eq(min_horizontal_ws[1].stop, 13)
  guard simple_split_regex_matches("a\r\n\nb\n\nc".to_array(), "[\\r\\n]{2,}")
    is Some(min_newlines) else {
    abort("expected newline min-run matches")
  }
  @test.assert_eq(min_newlines.length(), 2)
  @test.assert_eq(min_newlines[0].start, 1)
  @test.assert_eq(min_newlines[0].stop, 4)
  @test.assert_eq(min_newlines[1].start, 5)
  @test.assert_eq(min_newlines[1].stop, 7)
  guard simple_split_regex_matches(chars, "[\\d]+") is Some(class_digits) else {
    abort("expected digit class matches")
  }
  @test.assert_eq(class_digits.length(), 2)
  @test.assert_eq(class_digits[0].start, 1)
  @test.assert_eq(class_digits[0].stop, 3)
  @test.assert_eq(class_digits[1].start, 6)
  @test.assert_eq(class_digits[1].stop, 9)
  guard simple_split_regex_matches("a1b12c１２3".to_array(), "[\\d]{2,}")
    is Some(min_digits) else {
    abort("expected min digit class matches")
  }
  @test.assert_eq(min_digits.length(), 2)
  @test.assert_eq(min_digits[0].start, 3)
  @test.assert_eq(min_digits[0].stop, 5)
  @test.assert_eq(min_digits[1].start, 6)
  @test.assert_eq(min_digits[1].stop, 9)
  guard simple_split_regex_matches("a12345b".to_array(), "\\d{2}")
    is Some(exact_digits) else {
    abort("expected exact digit matches")
  }
  @test.assert_eq(exact_digits.length(), 2)
  @test.assert_eq(exact_digits[0].start, 1)
  @test.assert_eq(exact_digits[0].stop, 3)
  @test.assert_eq(exact_digits[1].start, 3)
  @test.assert_eq(exact_digits[1].stop, 5)
  guard simple_split_regex_matches(
      "a１２٣٤5b".to_array(),
      "[\\p{Number}]{4}",
    )
    is Some(exact_unicode_digits) else {
    abort("expected exact Unicode digit matches")
  }
  @test.assert_eq(exact_unicode_digits.length(), 1)
  @test.assert_eq(exact_unicode_digits[0].start, 1)
  @test.assert_eq(exact_unicode_digits[0].stop, 5)
  guard simple_split_regex_matches("a１２b٣".to_array(), "\\P{N}+")
    is Some(non_numbers) else {
    abort("expected inverse number matches")
  }
  @test.assert_eq(non_numbers.length(), 2)
  @test.assert_eq(non_numbers[0].start, 0)
  @test.assert_eq(non_numbers[0].stop, 1)
  @test.assert_eq(non_numbers[1].start, 3)
  @test.assert_eq(non_numbers[1].stop, 4)
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
  guard simple_split_regex_matches("a1234567b".to_array(), "\\d{2,4}")
    is Some(ranged_digits) else {
    abort("expected ranged digit matches")
  }
  @test.assert_eq(ranged_digits.length(), 2)
  @test.assert_eq(ranged_digits[0].start, 1)
  @test.assert_eq(ranged_digits[0].stop, 5)
  @test.assert_eq(ranged_digits[1].start, 5)
  @test.assert_eq(ranged_digits[1].stop, 8)
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
  guard simple_split_regex_matches("ab_12,cde".to_array(), "\\w{1,3}")
    is Some(bounded_words) else {
    abort("expected bounded word matches")
  }
  @test.assert_eq(bounded_words.length(), 3)
  @test.assert_eq(bounded_words[0].start, 0)
  @test.assert_eq(bounded_words[0].stop, 3)
  @test.assert_eq(bounded_words[1].start, 3)
  @test.assert_eq(bounded_words[1].stop, 5)
  @test.assert_eq(bounded_words[2].start, 6)
  @test.assert_eq(bounded_words[2].stop, 9)
  guard simple_split_regex_matches("ab_12,cde!".to_array(), "\\w{2,}")
    is Some(min_words) else {
    abort("expected min word matches")
  }
  @test.assert_eq(min_words.length(), 2)
  @test.assert_eq(min_words[0].start, 0)
  @test.assert_eq(min_words[0].stop, 5)
  @test.assert_eq(min_words[1].start, 6)
  @test.assert_eq(min_words[1].stop, 9)
  guard simple_split_regex_matches("ab_12,cde!".to_array(), "\\w{2}")
    is Some(exact_words) else {
    abort("expected exact word matches")
  }
  @test.assert_eq(exact_words.length(), 3)
  @test.assert_eq(exact_words[0].start, 0)
  @test.assert_eq(exact_words[0].stop, 2)
  @test.assert_eq(exact_words[1].start, 2)
  @test.assert_eq(exact_words[1].stop, 4)
  @test.assert_eq(exact_words[2].start, 6)
  @test.assert_eq(exact_words[2].stop, 8)
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
  guard simple_split_regex_matches("ab12_cde中".to_array(), "[A-Za-z0-9]{3}")
    is Some(exact_ascii_alnum) else {
    abort("expected exact ASCII alnum matches")
  }
  @test.assert_eq(exact_ascii_alnum.length(), 2)
  @test.assert_eq(exact_ascii_alnum[0].start, 0)
  @test.assert_eq(exact_ascii_alnum[0].stop, 3)
  @test.assert_eq(exact_ascii_alnum[1].start, 5)
  @test.assert_eq(exact_ascii_alnum[1].stop, 8)
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
  guard simple_split_regex_matches("abc123DE".to_array(), "[A-Za-z]{1,2}")
    is Some(bounded_ascii_letters) else {
    abort("expected bounded ASCII letter matches")
  }
  @test.assert_eq(bounded_ascii_letters.length(), 3)
  @test.assert_eq(bounded_ascii_letters[0].start, 0)
  @test.assert_eq(bounded_ascii_letters[0].stop, 2)
  @test.assert_eq(bounded_ascii_letters[1].start, 2)
  @test.assert_eq(bounded_ascii_letters[1].stop, 3)
  @test.assert_eq(bounded_ascii_letters[2].start, 6)
  @test.assert_eq(bounded_ascii_letters[2].stop, 8)
  guard simple_split_regex_matches("abé_cdef中".to_array(), "[A-Za-z]{2,}")
    is Some(min_ascii_letters) else {
    abort("expected min ASCII letter matches")
  }
  @test.assert_eq(min_ascii_letters.length(), 2)
  @test.assert_eq(min_ascii_letters[0].start, 0)
  @test.assert_eq(min_ascii_letters[0].stop, 2)
  @test.assert_eq(min_ascii_letters[1].start, 4)
  @test.assert_eq(min_ascii_letters[1].stop, 8)
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
  guard simple_split_regex_matches("abé中12Жxy".to_array(), "\\p{L}{3}")
    is Some(exact_letters) else {
    abort("expected exact Unicode letter matches")
  }
  @test.assert_eq(exact_letters.length(), 2)
  @test.assert_eq(exact_letters[0].start, 0)
  @test.assert_eq(exact_letters[0].stop, 3)
  @test.assert_eq(exact_letters[1].start, 6)
  @test.assert_eq(exact_letters[1].stop, 9)
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
  guard simple_split_regex_matches("hi,!?ok。".to_array(), "\\p{P}{2,}")
    is Some(min_punctuation) else {
    abort("expected min punctuation matches")
  }
  @test.assert_eq(min_punctuation.length(), 1)
  @test.assert_eq(min_punctuation[0].start, 2)
  @test.assert_eq(min_punctuation[0].stop, 5)
  guard simple_split_regex_matches("hi,!?ok。".to_array(), "\\p{P}{2}")
    is Some(exact_punctuation) else {
    abort("expected exact punctuation matches")
  }
  @test.assert_eq(exact_punctuation.length(), 1)
  @test.assert_eq(exact_punctuation[0].start, 2)
  @test.assert_eq(exact_punctuation[0].stop, 4)
  guard simple_split_regex_matches("hi!!!!ok。?".to_array(), "\\p{P}{1,3}")
    is Some(bounded_punctuation) else {
    abort("expected bounded punctuation matches")
  }
  @test.assert_eq(bounded_punctuation.length(), 3)
  @test.assert_eq(bounded_punctuation[0].start, 2)
  @test.assert_eq(bounded_punctuation[0].stop, 5)
  @test.assert_eq(bounded_punctuation[1].start, 5)
  @test.assert_eq(bounded_punctuation[1].stop, 6)
  @test.assert_eq(bounded_punctuation[2].start, 8)
  @test.assert_eq(bounded_punctuation[2].stop, 10)
  guard simple_split_regex_matches("hi!!!!?ok。".to_array(), "\\p{P}{2,4}")
    is Some(ranged_punctuation) else {
    abort("expected ranged punctuation matches")
  }
  @test.assert_eq(ranged_punctuation.length(), 1)
  @test.assert_eq(ranged_punctuation[0].start, 2)
  @test.assert_eq(ranged_punctuation[0].stop, 6)
  guard simple_split_regex_matches("a$+🙂,b=≤c".to_array(), "\\p{S}+")
    is Some(symbols) else {
    abort("expected symbol matches")
  }
  @test.assert_eq(symbols.length(), 2)
  @test.assert_eq(symbols[0].start, 1)
  @test.assert_eq(symbols[0].stop, 4)
  @test.assert_eq(symbols[1].start, 6)
  @test.assert_eq(symbols[1].stop, 8)
  guard simple_split_regex_matches("a$+🙂,b=≤c".to_array(), "\\p{S}{2}")
    is Some(exact_symbols) else {
    abort("expected exact symbol matches")
  }
  @test.assert_eq(exact_symbols.length(), 2)
  @test.assert_eq(exact_symbols[0].start, 1)
  @test.assert_eq(exact_symbols[0].stop, 3)
  @test.assert_eq(exact_symbols[1].start, 6)
  @test.assert_eq(exact_symbols[1].stop, 8)
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
      "[\\p{P}\\p{S}]{1,3}",
    )
    is Some(bounded_punct_symbols) else {
    abort("expected bounded punctuation-or-symbol matches")
  }
  @test.assert_eq(bounded_punct_symbols.length(), 3)
  @test.assert_eq(bounded_punct_symbols[0].start, 2)
  @test.assert_eq(bounded_punct_symbols[0].stop, 5)
  @test.assert_eq(bounded_punct_symbols[1].start, 5)
  @test.assert_eq(bounded_punct_symbols[1].stop, 6)
  @test.assert_eq(bounded_punct_symbols[2].start, 9)
  @test.assert_eq(bounded_punct_symbols[2].stop, 10)
  guard simple_split_regex_matches(
      "ab,$+🙂 cd。42".to_array(),
      "[\\p{P}\\p{S}]{2,}",
    )
    is Some(min_punct_symbols) else {
    abort("expected min punctuation-or-symbol matches")
  }
  @test.assert_eq(min_punct_symbols.length(), 1)
  @test.assert_eq(min_punct_symbols[0].start, 2)
  @test.assert_eq(min_punct_symbols[0].stop, 6)
  guard simple_split_regex_matches(
      "ab,$+🙂 cd。42".to_array(),
      "[\\p{P}\\p{S}]{3}",
    )
    is Some(exact_punct_symbols) else {
    abort("expected exact punctuation-or-symbol matches")
  }
  @test.assert_eq(exact_punct_symbols.length(), 1)
  @test.assert_eq(exact_punct_symbols[0].start, 2)
  @test.assert_eq(exact_punct_symbols[0].stop, 5)
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
  guard simple_split_regex_matches("a12 bc003".to_array(), "\\D{1,3}")
    is Some(bounded_non_digits) else {
    abort("expected bounded non-digit matches")
  }
  @test.assert_eq(bounded_non_digits.length(), 2)
  @test.assert_eq(bounded_non_digits[0].start, 0)
  @test.assert_eq(bounded_non_digits[0].stop, 1)
  @test.assert_eq(bounded_non_digits[1].start, 3)
  @test.assert_eq(bounded_non_digits[1].stop, 6)
  guard simple_split_regex_matches("ab_12,中!cd".to_array(), "\\W{1,2}")
    is Some(bounded_non_words) else {
    abort("expected bounded non-word matches")
  }
  @test.assert_eq(bounded_non_words.length(), 2)
  @test.assert_eq(bounded_non_words[0].start, 5)
  @test.assert_eq(bounded_non_words[0].stop, 7)
  @test.assert_eq(bounded_non_words[1].start, 7)
  @test.assert_eq(bounded_non_words[1].stop, 8)
  guard simple_split_regex_matches(
      "ab,$+🙂 cd。42".to_array(),
      "[^\\s\\p{L}\\p{N}]{1,3}",
    )
    is Some(bounded_non_alnum_nonspace) else {
    abort("expected bounded inverse non-space/letter/number matches")
  }
  @test.assert_eq(bounded_non_alnum_nonspace.length(), 3)
  @test.assert_eq(bounded_non_alnum_nonspace[0].start, 2)
  @test.assert_eq(bounded_non_alnum_nonspace[0].stop, 5)
  @test.assert_eq(bounded_non_alnum_nonspace[1].start, 5)
  @test.assert_eq(bounded_non_alnum_nonspace[1].stop, 6)
  @test.assert_eq(bounded_non_alnum_nonspace[2].start, 9)
  @test.assert_eq(bounded_non_alnum_nonspace[2].stop, 10)
  guard simple_split_regex_matches(
      "ab,$+🙂 cd。42".to_array(),
      "[^\\s\\p{L}\\p{N}]{2,4}",
    )
    is Some(ranged_non_alnum_nonspace) else {
    abort("expected ranged inverse non-space/letter/number matches")
  }
  @test.assert_eq(ranged_non_alnum_nonspace.length(), 1)
  @test.assert_eq(ranged_non_alnum_nonspace[0].start, 2)
  @test.assert_eq(ranged_non_alnum_nonspace[0].stop, 6)
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
  @test.assert_eq(is_simple_split_regex_pattern("\\w{2,}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\w{2}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\w{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[A-Za-z0-9]{3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[A-Za-z0-9]{1,4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[A-Za-z]{2,}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[A-Za-z]{1,2}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[A-Za-z]{2,4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{L}{3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{L}{2,4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Letter}]{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\d]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^\\d]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\d]{2,}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\d{2}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Number}]{4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Number}]{2,4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[A-Za-z0-9]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^a-zA-Z0-9]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[A-Za-z]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^a-zA-Z]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{Punctuation}+$"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{P}{2,}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{P}{2}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{P}{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{P}{2,4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Symbol}]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Symbol}]{2}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Symbol}]{1,4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{P}\\p{S}]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{P}\\p{S}]{2,}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{P}\\p{S}]{3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{P}\\p{S}]{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^\\s\\p{L}\\p{N}]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\s{2,}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^\\S\\r\\n]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\r\\n]+"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\d{1,2}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\d]{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\p{N}{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[\\p{Number}]{1,4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\D{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\P{Number}{1,4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\S{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\W{1,2}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^A-Za-z]{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\P{L}{1,4}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\P{Punctuation}{1,3}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("\\P{Symbol}{1,2}"), true)
  @test.assert_eq(is_simple_split_regex_pattern("[^\\p{P}\\p{S}]{1,3}"), true)
  @test.assert_eq(
    is_simple_split_regex_pattern("[^\\s\\p{L}\\p{N}]{1,3}"),
    true,
  )
}
