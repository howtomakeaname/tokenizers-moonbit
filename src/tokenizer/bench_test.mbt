// Encode/decode/load throughput benchmarks. Run with `moon bench`.
//
// These load real tokenizer.json fixtures from tests/data (git-ignored); when
// a fixture is absent the bench body is a no-op so `moon bench` still runs.
// Use them to compare backends (native/js/wasm-gc) and to pair with the Python
// baseline in scripts/bench_python.py for the "same correctness, runs in the
// browser" story (see docs/benchmarks).

// A representative mixed-language paragraph (~ a few hundred chars), repeated
// to give the tokenizer meaningful work per iteration.
fn bench_corpus() -> String {
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

fn load_model(name : String) -> Tokenizer? raise {
  match load_text("tests/data/\{name}.full.json") {
    Some(j) => Some(Tokenizer::from_str(j))
    None => None
  }
}

test "bench encode (gpt2)" (b : @bench.T) {
  guard load_model("gpt2") is Some(tok) else { return }
  let text = bench_corpus()
  b.bench(name="gpt2-encode", fn() {
    b.keep(tok.encode(text, add_special_tokens=false))
  })
}

test "bench encode (bert)" (b : @bench.T) {
  guard load_model("bert") is Some(tok) else { return }
  let text = bench_corpus()
  b.bench(name="bert-encode", fn() {
    b.keep(tok.encode(text, add_special_tokens=true))
  })
}

test "bench encode (llama byte_fallback)" (b : @bench.T) {
  guard load_model("llama") is Some(tok) else { return }
  let text = bench_corpus()
  b.bench(name="llama-encode", fn() {
    b.keep(tok.encode(text, add_special_tokens=false))
  })
}

test "bench encode (Qwen2.5)" (b : @bench.T) {
  guard load_model("Qwen2.5") is Some(tok) else { return }
  let text = bench_corpus()
  b.bench(name="qwen2.5-encode", fn() {
    b.keep(tok.encode(text, add_special_tokens=false))
  })
}

test "bench decode (gpt2)" (b : @bench.T) {
  guard load_model("gpt2") is Some(tok) else { return }
  let ids = tok.encode(bench_corpus(), add_special_tokens=false).ids
  b.bench(name="gpt2-decode", fn() {
    b.keep(tok.decode(ids, skip_special_tokens=false))
  })
}

test "bench load from_str (gpt2)" (b : @bench.T) {
  guard load_text("tests/data/gpt2.full.json") is Some(json) else { return }
  b.bench(name="gpt2-from_str", fn() {
    let t = try? Tokenizer::from_str(json)
    b.keep(t)
  })
}
