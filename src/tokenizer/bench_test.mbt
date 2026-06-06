// Encode/decode/load throughput benchmarks. Run with `moon bench`.
//
// These load real tokenizer.json fixtures from tests/data (git-ignored); when
// a fixture is absent the bench body is a no-op so `moon bench` still runs.
// Use them to compare backends (native/js/wasm-gc) and to pair with the Python
// baseline in scripts/bench_python.py for the "same correctness, runs in the
// browser" story (see docs/benchmarks).

// A short chat-style input: startup latency / interactive generation path.

///|
fn corpus_short_chat() -> String {
  "I'm fine, thanks. 请用 MoonBit 写一个 tokenizer 示例。"
}

// A representative mixed-language paragraph (~ a few hundred chars), repeated
// to give the tokenizer meaningful work per iteration.

///|
fn corpus_mixed() -> String {
  let unit =
    #|The quick brown fox jumps over the lazy dog. Tokenization 1234 is fun!
    #|MoonBit runs on wasm, js and native. 日本語のテキストも処理できます。
    #|Special tokens like <s> and punctuation: e.g., (a+b)*c == 42? Yes!
    #|
  let sb = StringBuilder::new()
  for _ in 0..<8 {
    sb.write_string(unit)
  }
  sb.to_string()
}

// Code-heavy input: common for StarCoder/Qwen-Coder style models.

///|
fn corpus_code() -> String {
  let unit =
    #|pub fn encode_batch(tok : Tokenizer, xs : Array[String]) -> Array[Encoding] {
    #|  xs.map(fn(x) { tok.encode(x, add_special_tokens=false) })
    #|}
    #|// UTF-8, byte_fallback, snake_case, camelCase, HTTP/2, JSON.parse
    #|
  let sb = StringBuilder::new()
  for _ in 0..<12 {
    sb.write_string(unit)
  }
  sb.to_string()
}

// Long document input: amortizes model/vocab lookup and stresses merge loops.

///|
fn corpus_long_doc() -> String {
  let unit = corpus_mixed() + corpus_code()
  let sb = StringBuilder::new()
  for _ in 0..<8 {
    sb.write_string(unit)
  }
  sb.to_string()
}

///|
fn load_model(name : String) -> Tokenizer? raise {
  match load_text("tests/data/\{name}.full.json") {
    Some(j) => Some(Tokenizer::from_str(j))
    None => None
  }
}

///|
fn bench_encode_case(
  b : @bench.T,
  model : String,
  case_name : String,
  text : String,
  add_special_tokens? : Bool = false,
) -> Unit raise {
  guard load_model(model) is Some(tok) else { return }
  b.bench(name="\{model}-encode-\{case_name}", fn() {
    b.keep(tok.encode(text, add_special_tokens~))
  })
}

///|
fn bench_decode_case(
  b : @bench.T,
  model : String,
  case_name : String,
  text : String,
) -> Unit raise {
  guard load_model(model) is Some(tok) else { return }
  let ids = tok.encode(text, add_special_tokens=false).ids
  b.bench(name="\{model}-decode-\{case_name}", fn() {
    b.keep(tok.decode(ids, skip_special_tokens=false))
  })
}

///|
fn bench_decode_batch_case(
  b : @bench.T,
  model : String,
  case_name : String,
  text : String,
) -> Unit raise {
  guard load_model(model) is Some(tok) else { return }
  let ids = tok.encode(text, add_special_tokens=false).ids
  let batch = [ids, ids, ids, ids, ids, ids, ids, ids]
  b.bench(name="\{model}-decode-batch-\{case_name}", fn() {
    b.keep(tok.decode_batch(batch, skip_special_tokens=false))
  })
}

///|
fn bench_load_case(b : @bench.T, model : String) -> Unit {
  guard load_text("tests/data/\{model}.full.json") is Some(json) else { return }
  b.bench(name="\{model}-from_str", fn() {
    let t = try? Tokenizer::from_str(json)
    b.keep(t)
  })
}

///|
test "bench encode (gpt2)" (b : @bench.T) {
  guard load_model("gpt2") is Some(tok) else { return }
  let text = corpus_mixed()
  b.bench(name="gpt2-encode", fn() {
    b.keep(tok.encode(text, add_special_tokens=false))
  })
}

///|
test "bench encode (bert)" (b : @bench.T) {
  guard load_model("bert") is Some(tok) else { return }
  let text = corpus_mixed()
  b.bench(name="bert-encode", fn() {
    b.keep(tok.encode(text, add_special_tokens=true))
  })
}

///|
test "bench encode (llama byte_fallback)" (b : @bench.T) {
  guard load_model("llama") is Some(tok) else { return }
  let text = corpus_mixed()
  b.bench(name="llama-encode", fn() {
    b.keep(tok.encode(text, add_special_tokens=false))
  })
}

///|
test "bench encode (Qwen2.5)" (b : @bench.T) {
  guard load_model("Qwen2.5") is Some(tok) else { return }
  let text = corpus_mixed()
  b.bench(name="qwen2.5-encode", fn() {
    b.keep(tok.encode(text, add_special_tokens=false))
  })
}

///|
test "bench encode matrix (modern models x corpora)" (b : @bench.T) {
  let short = corpus_short_chat()
  let mixed = corpus_mixed()
  let code = corpus_code()
  let long = corpus_long_doc()
  for
    model in [
      "gpt2", "bert", "roberta", "t5", "llama", "Qwen2.5", "qwen3", "phi3", "mistral",
      "starcoder2", "clip", "llama3_2", "phi4_mini", "gpt_oss", "qwen3_coder", "bge_m3",
      "e5_multilingual",
    ] {
    bench_encode_case(b, model, "short", short, add_special_tokens=false)
    bench_encode_case(b, model, "mixed", mixed, add_special_tokens=false)
    bench_encode_case(b, model, "code", code, add_special_tokens=false)
    bench_encode_case(b, model, "long", long, add_special_tokens=false)
  }
}

///|
test "bench decode (gpt2)" (b : @bench.T) {
  guard load_model("gpt2") is Some(tok) else { return }
  let ids = tok.encode(corpus_mixed(), add_special_tokens=false).ids
  b.bench(name="gpt2-decode", fn() {
    b.keep(tok.decode(ids, skip_special_tokens=false))
  })
}

///|
test "bench decode matrix" (b : @bench.T) {
  let mixed = corpus_mixed()
  for
    model in [
      "gpt2", "bert", "t5", "llama", "Qwen2.5", "phi4_mini", "qwen3_coder",
    ] {
    bench_decode_case(b, model, "mixed", mixed)
  }
}

///|
test "bench decode_batch matrix" (b : @bench.T) {
  let mixed = corpus_mixed()
  for
    model in [
      "gpt2", "bert", "t5", "llama", "Qwen2.5", "phi4_mini", "qwen3_coder",
    ] {
    bench_decode_batch_case(b, model, "mixedx8", mixed)
  }
}

///|
test "bench load from_str (gpt2)" (b : @bench.T) {
  guard load_text("tests/data/gpt2.full.json") is Some(json) else { return }
  b.bench(name="gpt2-from_str", fn() {
    let t = try? Tokenizer::from_str(json)
    b.keep(t)
  })
}

///|
test "bench load from_str matrix" (b : @bench.T) {
  for
    model in [
      "gpt2", "bert", "t5", "llama", "Qwen2.5", "phi4_mini", "qwen3_coder",
    ] {
    bench_load_case(b, model)
  }
}
