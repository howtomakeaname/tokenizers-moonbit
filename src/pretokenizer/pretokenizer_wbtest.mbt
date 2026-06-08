///|
test "punctuation honors split behavior" {
  let isolated = PreTokenizer::Punctuation(behavior=Isolated).pre_tokenize(
    "hi!!!there",
    base_offset=0,
  )
  @test.assert_eq(isolated.map(x => x.value), ["hi", "!", "!", "!", "there"])
  let contiguous = PreTokenizer::Punctuation(behavior=Contiguous).pre_tokenize(
    "hi!!!there",
    base_offset=0,
  )
  @test.assert_eq(contiguous.map(x => x.value), ["hi", "!!!", "there"])
  let previous = PreTokenizer::Punctuation(behavior=MergedWithPrevious).pre_tokenize(
    "hi!!!there",
    base_offset=0,
  )
  @test.assert_eq(previous.map(x => x.value), ["hi!!!", "there"])
  let next = PreTokenizer::Punctuation(behavior=MergedWithNext).pre_tokenize(
    "hi!!!there",
    base_offset=0,
  )
  @test.assert_eq(next.map(x => x.value), ["hi", "!!!there"])
  let removed = PreTokenizer::Punctuation(behavior=Removed).pre_tokenize(
    "hi!!!there",
    base_offset=0,
  )
  @test.assert_eq(removed.map(x => x.value), ["hi", "there"])
}

///|
test "unicode scripts splits on script changes like sentencepiece" {
  let basic = PreTokenizer::UnicodeScripts.pre_tokenize(
    "どこで生れ。Yes",
    base_offset=0,
  )
  @test.assert_eq(basic.map(x => x.value), ["どこで生れ", "。", "Yes"])
  let spaces = PreTokenizer::UnicodeScripts.pre_tokenize(
    "Apples are りんご 林檎",
    base_offset=0,
  )
  @test.assert_eq(spaces.map(x => x.value), ["Apples are ", "りんご 林檎"])
}

///|
test "split pretokenizer supports literal behavior modes" {
  let removed = PreTokenizer::Split(
    pattern=",",
    behavior=Removed,
    invert=false,
    regex=false,
  ).pre_tokenize("a,b,,c", base_offset=0)
  @test.assert_eq(removed.map(x => x.value), ["a", "b", "c"])

  let isolated = PreTokenizer::Split(
    pattern=",",
    behavior=Isolated,
    invert=false,
    regex=false,
  ).pre_tokenize("a,b", base_offset=0)
  @test.assert_eq(isolated.map(x => x.value), ["a", ",", "b"])
  @test.assert_eq(isolated.map(x => x.offsets), [(0, 1), (1, 2), (2, 3)])

  let next = PreTokenizer::Split(
    pattern=",",
    behavior=MergedWithNext,
    invert=false,
    regex=false,
  ).pre_tokenize("a,b", base_offset=0)
  @test.assert_eq(next.map(x => x.value), ["a", ",b"])
}

///|
test "split pretokenizer supports common regex spans" {
  let spaces = PreTokenizer::Split(
    pattern="\\s+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("a\t b\n\u{3000}c", base_offset=0)
  @test.assert_eq(spaces.map(x => x.value), ["a", "b", "c"])

  let wide_spaces = PreTokenizer::Split(
    pattern="\\s{2,}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("a b  c\t\td", base_offset=2)
  @test.assert_eq(wide_spaces.map(x => x.value), ["a b", "  ", "c", "\t\t", "d"])
  @test.assert_eq(wide_spaces.map(x => x.offsets), [
    (2, 5),
    (5, 7),
    (7, 8),
    (8, 10),
    (10, 11),
  ])

  let horizontal_spaces = PreTokenizer::Split(
    pattern="[^\\S\\r\\n]+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("a\t b\n c", base_offset=0)
  @test.assert_eq(horizontal_spaces.map(x => x.value), ["a", "b\n", "c"])

  let newlines = PreTokenizer::Split(
    pattern="[\\r\\n]+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("a\r\nb\n\nc", base_offset=1)
  @test.assert_eq(newlines.map(x => x.value), ["a", "\r\n", "b", "\n\n", "c"])

  let digits = PreTokenizer::Split(
    pattern="\\p{N}{1,3}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("abc12345de", base_offset=0)
  @test.assert_eq(digits.map(x => x.value), ["abc", "123", "45", "de"])

  let bounded_ascii_digits = PreTokenizer::Split(
    pattern="\\d{1,3}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("x12345y", base_offset=10)
  @test.assert_eq(bounded_ascii_digits.map(x => x.value), [
    "x", "123", "45", "y",
  ])
  @test.assert_eq(bounded_ascii_digits.map(x => x.offsets), [
    (10, 11),
    (11, 14),
    (14, 16),
    (16, 17),
  ])

  let bounded_ascii_digits_2 = PreTokenizer::Split(
    pattern="\\d{1,2}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("x12345y", base_offset=0)
  @test.assert_eq(bounded_ascii_digits_2.map(x => x.value), [
    "x", "12", "34", "5", "y",
  ])

  let bounded_unicode_digits_4 = PreTokenizer::Split(
    pattern="\\p{N}{1,4}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("x１２٣٤5y", base_offset=1)
  @test.assert_eq(bounded_unicode_digits_4.map(x => x.value), [
    "x", "１２٣٤", "5", "y",
  ])
  @test.assert_eq(bounded_unicode_digits_4.map(x => x.offsets), [
    (1, 2),
    (2, 6),
    (6, 7),
    (7, 8),
  ])

  let nonspace = PreTokenizer::Split(
    pattern="\\S+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("a b\t中", base_offset=5)
  @test.assert_eq(nonspace.map(x => x.value), ["a", " ", "b", "\t", "中"])
  @test.assert_eq(nonspace.map(x => x.offsets), [
    (5, 6),
    (6, 7),
    (7, 8),
    (8, 9),
    (9, 10),
  ])

  let digit_runs = PreTokenizer::Split(
    pattern="\\d+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab123cd45", base_offset=2)
  @test.assert_eq(digit_runs.map(x => x.value), ["ab", "123", "cd", "45"])
  @test.assert_eq(digit_runs.map(x => x.offsets), [
    (2, 4),
    (4, 7),
    (7, 9),
    (9, 11),
  ])

  let digit_class_runs = PreTokenizer::Split(
    pattern="[\\d]+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab123cd45", base_offset=2)
  @test.assert_eq(digit_class_runs.map(x => x.value), ["ab", "123", "cd", "45"])

  let min_digit_class_runs = PreTokenizer::Split(
    pattern="[\\d]{2,}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("a1b12c１２3", base_offset=4)
  @test.assert_eq(min_digit_class_runs.map(x => x.value), [
    "a1b", "12", "c", "１２3",
  ])
  @test.assert_eq(min_digit_class_runs.map(x => x.offsets), [
    (4, 7),
    (7, 9),
    (9, 10),
    (10, 13),
  ])

  let exact_digit_runs = PreTokenizer::Split(
    pattern="\\d{2}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("a12345b", base_offset=1)
  @test.assert_eq(exact_digit_runs.map(x => x.value), ["a", "12", "34", "5b"])
  @test.assert_eq(exact_digit_runs.map(x => x.offsets), [
    (1, 2),
    (2, 4),
    (4, 6),
    (6, 8),
  ])

  let exact_unicode_digit_runs = PreTokenizer::Split(
    pattern="[\\p{Number}]{4}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("a１２٣٤5b", base_offset=0)
  @test.assert_eq(exact_unicode_digit_runs.map(x => x.value), [
    "a", "１２٣٤", "5b",
  ])

  let nondigit_runs = PreTokenizer::Split(
    pattern="\\D+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("ab123cd45", base_offset=0)
  @test.assert_eq(nondigit_runs.map(x => x.value), ["123", "45"])

  let inverse_unicode_number_runs = PreTokenizer::Split(
    pattern="\\P{N}+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("a１２b٣", base_offset=0)
  @test.assert_eq(inverse_unicode_number_runs.map(x => x.value), [
    "１２", "٣",
  ])

  let word_runs = PreTokenizer::Split(
    pattern="\\w+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab_12,中!cd", base_offset=3)
  @test.assert_eq(word_runs.map(x => x.value), ["ab_12", ",中!", "cd"])
  @test.assert_eq(word_runs.map(x => x.offsets), [(3, 8), (8, 11), (11, 13)])

  let nonword_runs = PreTokenizer::Split(
    pattern="\\W+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("ab_12,中!cd", base_offset=0)
  @test.assert_eq(nonword_runs.map(x => x.value), ["ab_12", "cd"])

  let min_word_runs = PreTokenizer::Split(
    pattern="\\w{2,}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab_12,x,cde", base_offset=1)
  @test.assert_eq(min_word_runs.map(x => x.value), ["ab_12", ",x,", "cde"])

  let exact_word_runs = PreTokenizer::Split(
    pattern="\\w{2}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab_12,cde", base_offset=0)
  @test.assert_eq(exact_word_runs.map(x => x.value), [
    "ab", "_1", "2,", "cd", "e",
  ])

  let ascii_alnum = PreTokenizer::Split(
    pattern="[A-Za-z0-9]+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab_12,CD中", base_offset=2)
  @test.assert_eq(ascii_alnum.map(x => x.value), [
    "ab", "_", "12", ",", "CD", "中",
  ])
  @test.assert_eq(ascii_alnum.map(x => x.offsets), [
    (2, 4),
    (4, 5),
    (5, 7),
    (7, 8),
    (8, 10),
    (10, 11),
  ])

  let non_ascii_alnum = PreTokenizer::Split(
    pattern="[^A-Za-z0-9]+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("ab_12,CD中", base_offset=0)
  @test.assert_eq(non_ascii_alnum.map(x => x.value), ["ab", "12", "CD"])

  let exact_ascii_alnum = PreTokenizer::Split(
    pattern="[A-Za-z0-9]{3}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab12_cde中", base_offset=0)
  @test.assert_eq(exact_ascii_alnum.map(x => x.value), [
    "ab1", "2_", "cde", "中",
  ])

  let bounded_words = PreTokenizer::Split(
    pattern="\\b\\w+\\b",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("hi-there_2", base_offset=0)
  @test.assert_eq(bounded_words.map(x => x.value), ["hi", "-", "there_2"])

  let ascii_letters = PreTokenizer::Split(
    pattern="[A-Za-z]+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("abé_12,CD中", base_offset=3)
  @test.assert_eq(ascii_letters.map(x => x.value), ["ab", "é_12,", "CD", "中"])
  @test.assert_eq(ascii_letters.map(x => x.offsets), [
    (3, 5),
    (5, 10),
    (10, 12),
    (12, 13),
  ])

  let min_ascii_letters = PreTokenizer::Split(
    pattern="[A-Za-z]{2,}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("abé_cdef中", base_offset=0)
  @test.assert_eq(min_ascii_letters.map(x => x.value), [
    "ab", "é_", "cdef", "中",
  ])

  let exact_unicode_letters = PreTokenizer::Split(
    pattern="\\p{L}{3}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("abé中12Жxy", base_offset=0)
  @test.assert_eq(exact_unicode_letters.map(x => x.value), [
    "abé", "中12", "Жxy",
  ])

  let non_ascii_letters = PreTokenizer::Split(
    pattern="[^A-Za-z]+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("abé_12,CD中", base_offset=0)
  @test.assert_eq(non_ascii_letters.map(x => x.value), ["ab", "CD"])

  let letters = PreTokenizer::Split(
    pattern="\\p{L}+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("abé中12!Ж", base_offset=4)
  @test.assert_eq(letters.map(x => x.value), ["abé中", "12!", "Ж"])
  @test.assert_eq(letters.map(x => x.offsets), [(4, 8), (8, 11), (11, 12)])

  let non_letters = PreTokenizer::Split(
    pattern="\\P{L}+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("abé中12!Ж", base_offset=0)
  @test.assert_eq(non_letters.map(x => x.value), ["abé中", "Ж"])

  let punctuation = PreTokenizer::Split(
    pattern="\\p{P}+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("hi,!$+🙂ok。", base_offset=1)
  @test.assert_eq(punctuation.map(x => x.value), ["hi", ",!", "$+🙂ok", "。"])
  @test.assert_eq(punctuation.map(x => x.offsets), [
    (1, 3),
    (3, 5),
    (5, 10),
    (10, 11),
  ])

  let min_punctuation = PreTokenizer::Split(
    pattern="\\p{P}{2,}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("hi,!?ok。", base_offset=0)
  @test.assert_eq(min_punctuation.map(x => x.value), ["hi", ",!?", "ok。"])

  let exact_punctuation = PreTokenizer::Split(
    pattern="\\p{P}{2}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("hi,!?ok。", base_offset=0)
  @test.assert_eq(exact_punctuation.map(x => x.value), ["hi", ",!", "?ok。"])

  let symbols = PreTokenizer::Split(
    pattern="\\p{Symbol}+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("a$+🙂,b=≤c", base_offset=0)
  @test.assert_eq(symbols.map(x => x.value), ["a", ",b", "c"])

  let exact_symbols = PreTokenizer::Split(
    pattern="\\p{S}{2}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("a$+🙂,b=≤c", base_offset=0)
  @test.assert_eq(exact_symbols.map(x => x.value), [
    "a", "$+", "🙂,b", "=≤", "c",
  ])

  let punct_symbols = PreTokenizer::Split(
    pattern="[\\p{P}\\p{S}]+",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab,$+🙂 cd。42", base_offset=1)
  @test.assert_eq(punct_symbols.map(x => x.value), [
    "ab", ",$+🙂", " cd", "。", "42",
  ])
  @test.assert_eq(punct_symbols.map(x => x.offsets), [
    (1, 3),
    (3, 7),
    (7, 10),
    (10, 11),
    (11, 13),
  ])

  let min_punct_symbols = PreTokenizer::Split(
    pattern="[\\p{P}\\p{S}]{2,}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab,$+🙂 cd。42", base_offset=0)
  @test.assert_eq(min_punct_symbols.map(x => x.value), [
    "ab", ",$+🙂", " cd。42",
  ])

  let exact_punct_symbols = PreTokenizer::Split(
    pattern="[\\p{P}\\p{S}]{3}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("ab,$+🙂 cd。42", base_offset=0)
  @test.assert_eq(exact_punct_symbols.map(x => x.value), [
    "ab", ",$+", "🙂 cd。42",
  ])

  let non_alnum_nonspace = PreTokenizer::Split(
    pattern="[^\\s\\p{L}\\p{N}]+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("ab,$+🙂 cd。42", base_offset=0)
  @test.assert_eq(non_alnum_nonspace.map(x => x.value), ["ab", " cd", "42"])
}

///|
test "split pretokenizer supports trailing whitespace regex" {
  let leading = PreTokenizer::Split(
    pattern="^\\s+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("\t  abc  ", base_offset=4)
  @test.assert_eq(leading.map(x => x.value), ["abc  "])
  @test.assert_eq(leading.map(x => x.offsets), [(7, 12)])

  let removed = PreTokenizer::Split(
    pattern="\\s+$",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("abc  def\t\n", base_offset=7)
  @test.assert_eq(removed.map(x => x.value), ["abc  def"])
  @test.assert_eq(removed.map(x => x.offsets), [(7, 15)])

  let isolated = PreTokenizer::Split(
    pattern="\\s+$",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("abc  ", base_offset=0)
  @test.assert_eq(isolated.map(x => x.value), ["abc", "  "])
}

///|
test "split pretokenizer supports anchored digit and letter regex" {
  let trailing_digits = PreTokenizer::Split(
    pattern="\\d+$",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("abc123", base_offset=2)
  @test.assert_eq(trailing_digits.map(x => x.value), ["abc", "123"])
  @test.assert_eq(trailing_digits.map(x => x.offsets), [(2, 5), (5, 8)])

  let leading_letters = PreTokenizer::Split(
    pattern="^\\p{L}+",
    behavior=Removed,
    invert=false,
    regex=true,
  ).pre_tokenize("Жabc12!", base_offset=0)
  @test.assert_eq(leading_letters.map(x => x.value), ["12!"])

  let trailing_word = PreTokenizer::Split(
    pattern="\\w+$",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("hi-abc_12", base_offset=1)
  @test.assert_eq(trailing_word.map(x => x.value), ["hi-", "abc_12"])
  @test.assert_eq(trailing_word.map(x => x.offsets), [(1, 4), (4, 10)])
}

///|
test "pretokenizer to_json covers serializable variants" {
  @test.assert_eq(
    PreTokenizer::ByteLevel(
      add_prefix_space=true,
      use_regex=false,
      trim_offsets=true,
    ).to_json(),
    Some(
      "{\"type\":\"ByteLevel\",\"add_prefix_space\":true,\"use_regex\":false,\"trim_offsets\":true}",
    ),
  )
  @test.assert_eq(
    PreTokenizer::Punctuation(behavior=MergedWithPrevious).to_json(),
    Some("{\"type\":\"Punctuation\",\"behavior\":\"MergedWithPrevious\"}"),
  )
  @test.assert_eq(
    PreTokenizer::Metaspace(
      replacement='▁',
      prepend_scheme="always",
      split=true,
    ).to_json(),
    Some(
      "{\"type\":\"Metaspace\",\"replacement\":\"▁\",\"prepend_scheme\":\"always\",\"split\":true}",
    ),
  )
  @test.assert_eq(
    PreTokenizer::Digits(individual_digits=true).to_json(),
    Some("{\"type\":\"Digits\",\"individual_digits\":true}"),
  )
  @test.assert_eq(
    PreTokenizer::Delimiter(delimiter='\t').to_json(),
    Some("{\"type\":\"Delimiter\",\"delimiter\":\"\\t\"}"),
  )
  @test.assert_eq(
    PreTokenizer::FixedLength(length=4).to_json(),
    Some("{\"type\":\"FixedLength\",\"length\":4}"),
  )
  @test.assert_eq(
    PreTokenizer::Sequence([
      PreTokenizer::WhitespaceSplit,
      PreTokenizer::Digits(individual_digits=false),
    ]).to_json(),
    Some(
      "{\"type\":\"Sequence\",\"pretokenizers\":[{\"type\":\"WhitespaceSplit\"},{\"type\":\"Digits\",\"individual_digits\":false}]}",
    ),
  )
}
