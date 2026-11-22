// Lock tokenizer.json field-type strictness against HF 0.22.2 serde behavior.
// HF rejects a wrong JSON type (string where bool expected, etc.) rather than
// silently using a default; these tests pin the same contract across the
// normalizer/pre-tokenizer/decoder/root config parsers.

///|
fn expect_parse_error(label : String, json_text : String) -> Unit {
  try @tokenizer.Tokenizer::from_str(json_text) catch {
    @types.ParseError(_)
    | @types.UnsupportedComponent(_)
    | @types.VocabError(_) => return
  } noraise {
    _ => abort("expected a parse error for \{label}")
  }
}

///|
test "BertNormalizer rejects non-bool clean_text like HF" {
  let base = @fs.read_file_to_string("tests/data/bert.full.json")
  // Swap the bool field for a string; the exact JSON text edit keeps the rest
  // of the real model intact.
  let bad = base.replace(
    old="\"clean_text\":true",
    new="\"clean_text\":\"yes\"",
  )
  @test.assert_eq(bad != base, true)
  expect_parse_error("norm bool as string", bad)
}

///|
test "Metaspace pre-tokenizer rejects non-bool split like HF" {
  let base = @fs.read_file_to_string("tests/data/mistral.full.json")
  let bad = base.replace(old="\"split\": false", new="\"split\": \"x\"")
  @test.assert_eq(bad != base, true)
  expect_parse_error("pretok bool as string", bad)
}

///|
test "WordPiece decoder rejects non-bool cleanup like HF" {
  let base = @fs.read_file_to_string("tests/data/bert.full.json")
  let bad = base.replace(old="\"cleanup\":true", new="\"cleanup\":1")
  @test.assert_eq(bad != base, true)
  expect_parse_error("decoder bool as number", bad)
}

///|
test "root encode_special_tokens rejects non-bool like HF" {
  let base = @fs.read_file_to_string("tests/data/gpt2.full.json")
  let bad = base.replace(
    old="\"encode_special_tokens\":false",
    new="\"encode_special_tokens\":\"no\"",
  )
  // gpt2 may not carry the field; only assert when the edit actually applied.
  if bad != base {
    expect_parse_error("root bool as string", bad)
  }
}

///|
test "Strip decoder rejects non-number start like HF" {
  // Minimal synthetic tokenizer: only the decoder field matters here.
  let json_text =
    #|{"version":"1.0","added_tokens":[],"normalizer":null,"pre_tokenizer":null,
    #|"post_processor":null,"decoder":{"type":"Strip","content":" ","start":"1","stop":1},
    #|"model":{"type":"WordLevel","vocab":{}},"truncation":null,"padding":null}
  expect_parse_error("decoder int as string", json_text)
}

///|
test "valid models still load after strictness migration (no false reject)" {
  // The 39-model parity suite is the broad guard; here pin two representative
  // configs that rely on field defaults, proving absent keys still work.
  let bert = @fs.read_file_to_string("tests/data/bert.full.json")
  let _ = @tokenizer.Tokenizer::from_str(bert)
  let gpt2 = @fs.read_file_to_string("tests/data/gpt2.full.json")
  let _ = @tokenizer.Tokenizer::from_str(gpt2)
}
