// HF 0.22.2 decode-without-decoder semantics: `tokens.join(" ")` in the Rust
// core (tokenizer/mod.rs decode). Expectations verified against Python
// `tokenizers` 0.22.2 probes.

///|
test "decode without decoder joins token surfaces with spaces" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0,"moon":1},"unk_token":"hello"}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  // Python 0.22.2: decode([0,1]) == "hello moon"
  @test.assert_eq(tok.decode([0, 1]), "hello moon")
}

///|
/// Unknown ids are filtered before joining, so they never introduce extra
/// spaces. Python 0.22.2: decode([0, 99, 1]) == "hello moon".
test "decode without decoder skips unknown ids without extra spaces" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0,"moon":1},"unk_token":"hello"}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  @test.assert_eq(tok.decode([0, 99, 1]), "hello moon")
}

///|
/// A vocabulary that literally contains " " keeps it as a token surface, so
/// the join produces consecutive spaces. Python 0.22.2:
/// decode([0,1,2]) with vocab {"hello":0," ":1,"moon":2} == "hello   moon".
test "decode without decoder keeps explicit space tokens in the join" {
  let json =
    #|{"version":"1.0","model":{"type":"WordLevel","vocab":{"hello":0," ":1,"moon":2},"unk_token":"hello"}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  @test.assert_eq(tok.decode([0, 1, 2]), "hello   moon")
}

///|
/// Special tokens kept (skip_special_tokens=false) join with spaces too.
/// Python 0.22.2 equivalent: specials-kept decode joins all surfaces.
test "decode without decoder joins kept specials with spaces" {
  let json =
    #|{"version":"1.0",
    #| "added_tokens":[{"id":5,"content":"<s>","single_word":false,"lstrip":false,"rstrip":false,"normalized":false,"special":true},
    #|                {"id":6,"content":"</s>","single_word":false,"lstrip":false,"rstrip":false,"normalized":false,"special":true}],
    #| "model":{"type":"WordLevel","vocab":{"abc":4,"[UNK]":7},"unk_token":"[UNK]"}}
  let tok = @tokenizer.Tokenizer::from_str(json)
  @test.assert_eq(
    tok.decode([5, 4, 6], skip_special_tokens=false),
    "<s> abc </s>",
  )
  @test.assert_eq(tok.decode([5, 4, 6], skip_special_tokens=true), "abc")
}
