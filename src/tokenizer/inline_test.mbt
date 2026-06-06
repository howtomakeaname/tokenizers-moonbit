// Backend-agnostic end-to-end test using an inline tokenizer.json string.
//
// Unlike the gpt2/bert/t5 tests (which read large fixtures from disk via x/fs),
// this test embeds a tiny tokenizer.json so it runs identically on every
// backend, including wasm / wasm-gc where the large fixtures are absent.

///|
let tiny_bpe : String =
  #|{
  #|  "model": {
  #|    "type": "BPE",
  #|    "vocab": {"a":0,"b":1,"c":2,"ab":3,"abc":4,"<unk>":5},
  #|    "merges": [["a","b"],["ab","c"]],
  #|    "unk_token": "<unk>"
  #|  }
  #|}

///|
test "inline BPE encode/decode runs on all backends" {
  let tok = Tokenizer::from_str(tiny_bpe)
  let enc = tok.encode("abc", add_special_tokens=false)
  // a+b -> ab, ab+c -> abc (id 4)
  @test.assert_eq(enc.ids, [4])
  @test.assert_eq(enc.tokens, ["abc"])
  // partial: "ab" then "c" unmergeable with nothing after
  let enc2 = tok.encode("abca", add_special_tokens=false)
  @test.assert_eq(enc2.tokens, ["abc", "a"])
  @test.assert_eq(enc2.ids, [4, 0])
  // round-trip lookups
  @test.assert_eq(tok.token_to_id("abc"), Some(4))
  @test.assert_eq(tok.id_to_token(3), Some("ab"))
  @test.assert_eq(tok.get_vocab_size(), 6)
}
