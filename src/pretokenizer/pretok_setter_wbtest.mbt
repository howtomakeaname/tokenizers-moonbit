// Whitebox tests for PreTokenizer setter aliases (Python binding compatibility).

///|
test "PreTokenizer::set_add_prefix_space for ByteLevel" {
  let p = ByteLevel(add_prefix_space=false, use_regex=true, trim_offsets=true)
  @test.assert_eq(p.add_prefix_space(), Some(false))
  let p2 = p.set_add_prefix_space(true)
  @test.assert_eq(p2.add_prefix_space(), Some(true))
  @test.assert_eq(p2.use_regex(), Some(true))
}

///|
test "PreTokenizer::set_use_regex for ByteLevel" {
  let p = ByteLevel(add_prefix_space=true, use_regex=true, trim_offsets=true)
  @test.assert_eq(p.use_regex(), Some(true))
  let p2 = p.set_use_regex(false)
  @test.assert_eq(p2.use_regex(), Some(false))
  @test.assert_eq(p2.add_prefix_space(), Some(true))
}

///|
test "PreTokenizer::set_trim_offsets for ByteLevel" {
  let p = ByteLevel(add_prefix_space=true, use_regex=true, trim_offsets=true)
  @test.assert_eq(p.trim_offsets(), Some(true))
  let p2 = p.set_trim_offsets(false)
  @test.assert_eq(p2.trim_offsets(), Some(false))
}

///|
test "PreTokenizer::set_replacement for Metaspace" {
  let p = Metaspace(replacement='▁', prepend_scheme="always", split=true)
  @test.assert_eq(p.replacement(), Some('▁'))
  let p2 = p.set_replacement(' ')
  @test.assert_eq(p2.replacement(), Some(' '))
  @test.assert_eq(p2.prepend_scheme(), Some("always"))
}

///|
test "PreTokenizer::set_prepend_scheme for Metaspace" {
  let p = Metaspace(replacement='▁', prepend_scheme="always", split=true)
  @test.assert_eq(p.prepend_scheme(), Some("always"))
  let p2 = p.set_prepend_scheme("never")
  @test.assert_eq(p2.prepend_scheme(), Some("never"))
}

///|
test "PreTokenizer::set_split_enabled for Metaspace" {
  let p = Metaspace(replacement='▁', prepend_scheme="always", split=true)
  @test.assert_eq(p.split_enabled(), Some(true))
  let p2 = p.set_split_enabled(false)
  @test.assert_eq(p2.split_enabled(), Some(false))
}

///|
test "PreTokenizer::set_delimiter for Delimiter" {
  let p = Delimiter(delimiter='|')
  @test.assert_eq(p.delimiter(), Some('|'))
  let p2 = p.set_delimiter(',')
  @test.assert_eq(p2.delimiter(), Some(','))
}

///|
test "PreTokenizer::set_individual_digits for Digits" {
  let p = Digits(individual_digits=false)
  @test.assert_eq(p.individual_digits(), Some(false))
  let p2 = p.set_individual_digits(true)
  @test.assert_eq(p2.individual_digits(), Some(true))
}

///|
test "PreTokenizer::set_length for FixedLength" {
  let p = FixedLength(length=5)
  @test.assert_eq(p.length(), Some(5))
  let p2 = p.set_length(10)
  @test.assert_eq(p2.length(), Some(10))
}

///|
test "PreTokenizer::set_add_prefix_space on non-ByteLevel returns self" {
  let p = Metaspace(replacement='▁', prepend_scheme="always", split=true)
  @test.assert_eq(p.add_prefix_space(), None)
  let p2 = p.set_add_prefix_space(true)
  @test.assert_eq(p2.kind(), "Metaspace")
}
