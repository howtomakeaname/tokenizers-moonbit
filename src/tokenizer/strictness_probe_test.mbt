// Lock tokenizer.json field-type strictness against HF 0.22.2 serde behavior.
// HF rejects a wrong JSON type (string where bool is expected, etc.) rather
// than silently using a default; these tests pin the same contract. All JSON
// is inline and single-line so the suite is self-contained in CI (no
// git-ignored fixtures) and the JSON text stays valid.

///|
/// Returns true when loading raises a TokenizerError; false if it loads.
/// Both arms produce a Bool: the success arm yields false, the error arms
/// yield true, so no `not`/abort is needed.
fn raises_tokenizer_error(json_text : String) -> Bool {
  try {
    ignore(@tokenizer.Tokenizer::from_str(json_text))
    false
  } catch {
    @types.ParseError(_)
    | @types.UnsupportedComponent(_)
    | @types.VocabError(_) => true
  }
}

///|
fn expect_parse_error(label : String, json_text : String) -> Unit raise {
  @test.assert_eq((label, raises_tokenizer_error(json_text)), (label, true))
}

///|
/// Wrap a component object in a minimal otherwise-valid tokenizer.json. The
/// optional root slots are omitted entirely (absent == null), so passing
/// "truncation" as `field` does not collide with a hard-coded null override.
fn wrap_json(field : String, value : String) -> String {
  "{\"version\":\"1.0\",\"added_tokens\":[]," +
  field +
  ":" +
  value +
  ",\"model\":{\"type\":\"WordLevel\",\"unk_token\":\"<unk>\",\"vocab\":{}}}"
}

///|
test "BertNormalizer rejects non-bool clean_text like HF" {
  let good = wrap_json(
    "\"normalizer\"",
    "{\"type\":\"BertNormalizer\",\"clean_text\":true," +
    "\"handle_chinese_chars\":true,\"strip_accents\":null,\"lowercase\":true}",
  )
  let _ = @tokenizer.Tokenizer::from_str(good)
  let as_string = wrap_json(
    "\"normalizer\"",
    "{\"type\":\"BertNormalizer\",\"clean_text\":\"yes\"," +
    "\"handle_chinese_chars\":true,\"strip_accents\":null,\"lowercase\":true}",
  )
  expect_parse_error("norm bool as string", as_string)
  let as_number = wrap_json(
    "\"normalizer\"",
    "{\"type\":\"BertNormalizer\",\"clean_text\":1," +
    "\"handle_chinese_chars\":true,\"strip_accents\":null,\"lowercase\":true}",
  )
  expect_parse_error("norm bool as number", as_number)
}

///|
test "Metaspace pre-tokenizer rejects non-bool split like HF" {
  let good = wrap_json(
    "\"pre_tokenizer\"",
    "{\"type\":\"Metaspace\",\"replacement\":\"\\u2581\"," +
    "\"prepend_scheme\":\"always\",\"split\":false}",
  )
  let _ = @tokenizer.Tokenizer::from_str(good)
  let bad = wrap_json(
    "\"pre_tokenizer\"",
    "{\"type\":\"Metaspace\",\"replacement\":\"\\u2581\"," +
    "\"prepend_scheme\":\"always\",\"split\":\"x\"}",
  )
  expect_parse_error("pretok bool as string", bad)
}

///|
test "WordPiece decoder rejects non-bool cleanup like HF" {
  let good = wrap_json(
    "\"decoder\"", "{\"type\":\"WordPiece\",\"prefix\":\"##\",\"cleanup\":true}",
  )
  let _ = @tokenizer.Tokenizer::from_str(good)
  let bad = wrap_json(
    "\"decoder\"", "{\"type\":\"WordPiece\",\"prefix\":\"##\",\"cleanup\":1}",
  )
  expect_parse_error("decoder bool as number", bad)
}

///|
test "Strip decoder rejects non-number start like HF" {
  let as_string = wrap_json(
    "\"decoder\"", "{\"type\":\"Strip\",\"content\":\" \",\"start\":\"1\",\"stop\":1}",
  )
  expect_parse_error("decoder int as string", as_string)
  let as_bool = wrap_json(
    "\"decoder\"", "{\"type\":\"Strip\",\"content\":\" \",\"start\":true,\"stop\":1}",
  )
  expect_parse_error("decoder int as bool", as_bool)
}

///|
test "root truncation rejects non-number max_length like HF" {
  let good = wrap_json(
    "\"truncation\"", "{\"max_length\":128,\"stride\":0,\"strategy\":\"LongestFirst\",\"direction\":\"Right\"}",
  )
  let _ = @tokenizer.Tokenizer::from_str(good)
  let bad = wrap_json(
    "\"truncation\"", "{\"max_length\":\"128\",\"stride\":0,\"strategy\":\"LongestFirst\",\"direction\":\"Right\"}",
  )
  expect_parse_error("root truncation int as string", bad)
}

///|
test "strict helper distinguishes wrong type from absent key" {
  // The strictness change targets wrong JSON types, not missing keys: an
  // absent optional field still resolves to its default rather than raising.
  let empty = @types.as_object(@json.parse("{}"), "probe")
  @test.assert_eq(
    @types.get_bool_strict(empty, "absent", default=true, "probe"),
    true,
  )
  let corrupt = @types.as_object(@json.parse("{\"absent\":\"yes\"}"), "probe")
  let result = @types.get_bool_strict(corrupt, "absent", default=true, "probe") catch {
    @types.ParseError(_)
    | @types.UnsupportedComponent(_)
    | @types.VocabError(_) => false
  }
  @test.assert_eq(result, false)
}
