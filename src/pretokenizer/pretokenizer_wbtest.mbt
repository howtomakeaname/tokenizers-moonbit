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

  let digits = PreTokenizer::Split(
    pattern="\\p{N}{1,3}",
    behavior=Isolated,
    invert=false,
    regex=true,
  ).pre_tokenize("abc12345de", base_offset=0)
  @test.assert_eq(digits.map(x => x.value), ["abc", "123", "45", "de"])

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
}

///|
test "split pretokenizer supports trailing whitespace regex" {
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
