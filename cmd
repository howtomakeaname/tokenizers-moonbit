fn main raise {
  let mk = fn(norm : String, pre : String) -> String {
    "{\"version\":\"1.0\",\"normalizer\":" + norm + ",\"pre_tokenizer\":" + pre + ",\"model\":{\"type\":\"BPE\",\"unk_token\":\"<|eot|>\",\"vocab\":{\"z\":0,\"e\":1,\"é\":2,\"▁\":3,\"h\":4,\"l\":5,\"o\":6,\"中\":7,\"文\":8,\"a\":9,\"b\":10,\"X\":11},\"merges\":[]}}"
  }
  // 1 NFC compose span (HF: é -> (1,2))
  let t1 = @tokenizer.Tokenizer::from_str(mk("{\"type\":\"NFC\"}", "null"))
  println("NFC zé: \{t1.encode("ze\u{301}z").offsets}")
  // 2 Replace Regex a+ -> X on "aa" (HF: X -> (1,2))
  let t2 = @tokenizer.Tokenizer::from_str(mk("{\"type\":\"Replace\",\"pattern\":{\"Regex\":\"a+\"},\"content\":\"X\"}", "null"))
  println("replace aa: \{t2.encode("aa").offsets}")
  // 3 ReplaceString literal "\n" (HF: a(0,1) b(2,3))
  let t3 = @tokenizer.Tokenizer::from_str(mk("{\"type\":\"Replace\",\"pattern\":{\"String\":\"\\\\n\"},\"content\":\"X\"}", "null"))
  println("replacestr newline: \{t3.encode("a\nb").offsets}")
  // 4 Metaspace CJK (HF: ▁中(0,1) 文(1,2))
  let t4 = @tokenizer.Tokenizer::from_str(mk("null", "{\"type\":\"Metaspace\",\"replacement\":\"▁\",\"prepend_scheme\":\"always\"}"))
  println("metaspace cjk: \{t4.encode("中文").offsets}")
}
