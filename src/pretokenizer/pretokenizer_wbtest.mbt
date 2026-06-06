test "punctuation honors split behavior" {
  let isolated = PreTokenizer::Punctuation(behavior=Isolated).pre_tokenize("hi!!!there", base_offset=0)
  @test.assert_eq(isolated.map(x => x.value), ["hi", "!", "!", "!", "there"])
  let contiguous = PreTokenizer::Punctuation(behavior=Contiguous).pre_tokenize("hi!!!there", base_offset=0)
  @test.assert_eq(contiguous.map(x => x.value), ["hi", "!!!", "there"])
  let previous = PreTokenizer::Punctuation(behavior=MergedWithPrevious).pre_tokenize("hi!!!there", base_offset=0)
  @test.assert_eq(previous.map(x => x.value), ["hi!!!", "there"])
  let next = PreTokenizer::Punctuation(behavior=MergedWithNext).pre_tokenize("hi!!!there", base_offset=0)
  @test.assert_eq(next.map(x => x.value), ["hi", "!!!there"])
  let removed = PreTokenizer::Punctuation(behavior=Removed).pre_tokenize("hi!!!there", base_offset=0)
  @test.assert_eq(removed.map(x => x.value), ["hi", "there"])
}

test "unicode scripts splits on script changes like sentencepiece" {
  let basic = PreTokenizer::UnicodeScripts.pre_tokenize("どこで生れ。Yes", base_offset=0)
  @test.assert_eq(basic.map(x => x.value), ["どこで生れ", "。", "Yes"])
  let spaces = PreTokenizer::UnicodeScripts.pre_tokenize("Apples are りんご 林檎", base_offset=0)
  @test.assert_eq(spaces.map(x => x.value), ["Apples are ", "りんご 林檎"])
}
