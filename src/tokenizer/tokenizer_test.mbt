test "from_str parses a minimal tokenizer.json" {
  let json =
    #|{"version":"1.0","model":{"type":"BPE","vocab":{},"merges":[]}}
  let tok = Tokenizer::from_str(json)
  guard tok.config is Object(obj)
  assert_true(obj.contains("model"))
}

test "from_str rejects non-object root" {
  let bad = "[1, 2, 3]"
  let mut raised = false
  try {
    Tokenizer::from_str(bad) |> ignore
  } catch {
    @types.ParseError(_) => raised = true
    _ => raised = false
  }
  assert_true(raised)
}
