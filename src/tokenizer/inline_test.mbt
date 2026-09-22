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
  let tok = @tokenizer.Tokenizer::from_str(tiny_bpe)
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

///|
/// Assertion/window Split patterns (probed 0.22.2 via
/// pre_tokenize_str; piece contents derived from offsets): the bare
/// assertion sequences and double-anchored whole-line windows now
/// claim the Split path instead of passing through unchanged.
test "split assertion and window patterns" {
  fn go() -> Unit raise {
    fn mk_split(pattern : String) -> @tokenizer.Tokenizer raise {
      @tokenizer.Tokenizer::from_str(
        "{\"version\":\"1.0\",\"pre_tokenizer\":{\"type\":\"Split\",\"pattern\":{\"Regex\":\"" +
        pattern +
        "\"},\"behavior\":\"Isolated\",\"invert\":false},\"model\":{\"type\":\"WordLevel\",\"vocab\":{\"<unk>\":0,\"ab\":1,\"a\":2},\"unk_token\":\"<unk>\"}}",
      )
    }
    fn pieces(t : @tokenizer.Tokenizer, text : String) -> Array[String] raise {
      let enc = t.encode(text)
      let src = text.to_array()
      let out : Array[String] = []
      for o in enc.get_offsets() {
        let sb = StringBuilder()
        for k in o.0..<o.1 {
          sb.write_char(src[k])
        }
        out.push(sb.to_string())
      }
      out
    }
    // ^.{0,2}$ Isolated on "ab\nabc\n\na" -> 4 pieces incl. empty line
    let ps = pieces(mk_split("^.{0,2}$"), "ab\nabc\n\na")
    @test.assert_eq(ps.length(), 4)
    @test.assert_eq(ps[0], "ab")
    @test.assert_eq(ps[1], "\nabc\n")
    @test.assert_eq(ps[2], "\n")
    @test.assert_eq(ps[3], "a")
    // \b$ on "ab\ncd" -> ab / \ncd
    let bp = pieces(mk_split("\\\\b$"), "ab\ncd")
    @test.assert_eq(bp.length(), 2)
    @test.assert_eq(bp[0], "ab")
    @test.assert_eq(bp[1], "\ncd")
    // ^ per-line pieces
    @test.assert_eq(pieces(mk_split("^"), "ab\nabc\n\na").length(), 4)
    // ^$ -> ab\nabc\n / \na
    let dp = pieces(mk_split("^$"), "ab\nabc\n\na")
    @test.assert_eq(dp.length(), 2)
    @test.assert_eq(dp[0], "ab\nabc\n")
    @test.assert_eq(dp[1], "\na")
  }
  go()
}

///|
/// Word-anchored Split merging (review B1 fix, all wants probed 0.22.2
/// via pre_tokenize_str): behavior applies to the MATCHED parts
/// uniformly (invert only swaps which spans are matched); a matched
/// part under MergedWithPrevious attaches to the immediately
/// preceding word — an EMPTY word still anchors, so the part becomes
/// a fresh piece; consecutive matches never merge into one another.
test "split word-anchored merging matches hf" {
  fn go() -> Unit raise {
    fn mk(
      pat : String,
      beh : String,
      inv : Bool,
    ) -> @tokenizer.Tokenizer raise {
      @tokenizer.Tokenizer::from_str(
        "{\"version\":\"1.0\",\"pre_tokenizer\":{\"type\":\"Split\",\"pattern\":{\"Regex\":\"" +
        pat +
        "\"},\"behavior\":\"" +
        beh +
        "\",\"invert\":" +
        (if inv { "true" } else { "false" }) +
        "},\"model\":{\"type\":\"WordLevel\",\"vocab\":{\"<unk>\":0},\"unk_token\":\"<unk>\"}}",
      )
    }
    fn pieces(t : @tokenizer.Tokenizer, text : String) -> Array[String] raise {
      let enc = t.encode(text)
      let src = text.to_array()
      let out : Array[String] = []
      for o in enc.get_offsets() {
        let sb = StringBuilder()
        for k in o.0..<o.1 {
          sb.write_char(src[k])
        }
        out.push(sb.to_string())
      }
      out
    }
    fn eq(a : Array[String], b : Array[String]) -> Bool {
      if a.length() != b.length() {
        return false
      }
      for i in 0..<a.length() {
        if a[i] != b[i] {
          return false
        }
      }
      true
    }
    // empty words anchor mwp under invert
    @test.assert_eq(
      eq(pieces(mk("\\\\b$", "MergedWithPrevious", true), "ab\ncd"), [
        "ab", "\ncd",
      ]),
      true,
    )
    @test.assert_eq(
      eq(pieces(mk("^", "MergedWithPrevious", true), "ab\ncd"), ["ab\n", "cd"]),
      true,
    )
    // word-anchored merging + consecutive matches stand alone
    @test.assert_eq(
      eq(pieces(mk("^foo|bar$", "MergedWithPrevious", false), "foo\nfoobar"), [
        "foo", "\nfoo", "bar",
      ]),
      true,
    )
    @test.assert_eq(
      eq(pieces(mk("^foo|bar$", "MergedWithNext", false), "foo\nfoobar"), [
        "foo\n", "foo", "bar",
      ]),
      true,
    )
    @test.assert_eq(
      eq(pieces(mk("^foo|bar$", "Contiguous", true), "foo\nfoobar"), [
        "foo", "\n", "foobar",
      ]),
      true,
    )
    // window patterns under every behavior
    @test.assert_eq(
      eq(pieces(mk("^.{0,2}$", "MergedWithPrevious", false), "ab\nabc\n\na"), [
        "ab", "\nabc\n", "\na",
      ]),
      true,
    )
    @test.assert_eq(
      eq(pieces(mk("^.{0,2}$", "MergedWithNext", false), "ab\nabc\n\na"), [
        "ab\nabc\n", "\n", "a",
      ]),
      true,
    )
    @test.assert_eq(
      eq(pieces(mk("^.{0,2}$", "Removed", false), "ab\nabc\n\na"), [
        "\nabc\n", "\n",
      ]),
      true,
    )
  }
  go()
}
