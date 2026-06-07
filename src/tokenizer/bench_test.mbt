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
fn bench_encode_byte_offsets_case(
  b : @bench.T,
  model : String,
  case_name : String,
  text : String,
) -> Unit raise {
  guard load_model(model) is Some(tok) else { return }
  b.bench(name="\{model}-encode-byte-offsets-\{case_name}", fn() {
    b.keep(tok.encode_with_byte_offsets(text, add_special_tokens=false))
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
fn bench_encode_batch_case(
  b : @bench.T,
  model : String,
  case_name : String,
  text : String,
) -> Unit raise {
  guard load_model(model) is Some(tok) else { return }
  let batch = [text, text, text, text, text, text, text, text]
  b.bench(name="\{model}-encode-batch-\{case_name}", fn() {
    b.keep(tok.encode_batch(batch, add_special_tokens=false))
  })
}

///|
fn bench_offset_lookup_case(
  b : @bench.T,
  model : String,
  case_name : String,
  text : String,
) -> Unit raise {
  guard load_model(model) is Some(tok) else { return }
  let enc = tok.encode_with_byte_offsets(text, add_special_tokens=false)
  guard enc.ids.length() > 0 else { return }
  let positions = [0, 1, 4, 8, 16, 32, 64, 128, 256, 512, 1024]
  b.bench(name="\{model}-offset-lookup-\{case_name}", fn() {
    let mut acc = 0
    for p in positions {
      match enc.char_to_token(p) {
        Some(i) => acc = acc + i
        None => ()
      }
      match enc.token_to_chars(acc % enc.ids.length()) {
        Some((seq, offs)) => acc = acc + seq + offs.0 + offs.1
        None => ()
      }
      match enc.token_to_word(acc % enc.ids.length()) {
        Some((seq, word)) => acc = acc + seq + word
        None => ()
      }
      match enc.word_to_tokens(acc % enc.ids.length()) {
        Some((s, e)) => acc = acc + s + e
        None => ()
      }
      match enc.char_to_word(p) {
        Some(w) => acc = acc + w
        None => ()
      }
    }
    b.keep(acc)
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
fn bench_to_json_case(b : @bench.T, model : String) -> Unit raise {
  guard load_model(model) is Some(tok) else { return }
  b.bench(name="\{model}-to_json", fn() {
    let j = try? tok.to_json()
    b.keep(j)
  })
}

///|
fn bench_from_pretrained_case(b : @bench.T, model : String) -> Unit {
  let path = "tests/data/\{model}.full.json"
  guard load_text(path) is Some(_) else { return }
  b.bench(name="\{model}-from_pretrained-file", fn() {
    let t = try? Tokenizer::from_pretrained(path)
    b.keep(t)
  })
}

///|
fn bench_train_wordlevel_case(
  b : @bench.T,
  case_name : String,
  text : String,
) -> Unit {
  let corpus = [text, text, text, text]
  b.bench(name="wordlevel-train-\{case_name}", fn() {
    b.keep(
      Tokenizer::train_wordlevel(corpus, unk_token="[UNK]", min_frequency=1, special_tokens=[
        "[PAD]",
      ]),
    )
  })
}

///|
fn bench_train_wordlevel_split_case(
  b : @bench.T,
  case_name : String,
  text : String,
) -> Unit {
  let corpus = [text, text, text, text]
  let pt = @pretokenizer.PreTokenizer::split(
    ",",
    @pretokenizer.SplitBehavior::removed(),
    false,
    false,
  )
  b.bench(name="wordlevel-train-split-\{case_name}", fn() {
    b.keep(
      Tokenizer::train_wordlevel_with_pretokenizer(
        corpus,
        pt,
        unk_token="[UNK]",
        min_frequency=1,
        special_tokens=["[PAD]"],
      ),
    )
  })
}

///|
fn bench_train_wordlevel_capped_case(
  b : @bench.T,
  case_name : String,
  text : String,
) -> Unit {
  let corpus = [text, text, text, text]
  b.bench(name="wordlevel-train-capped-\{case_name}", fn() {
    b.keep(
      Tokenizer::train_wordlevel(
        corpus,
        unk_token="[UNK]",
        min_frequency=1,
        special_tokens=["[PAD]"],
        vocab_size=Some(128),
      ),
    )
  })
}

///|
fn bench_trained_wordlevel_to_json_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let tok = Tokenizer::train_wordlevel_with_pretokenizer(
    [corpus_mixed(), corpus_mixed()],
    @pretokenizer.PreTokenizer::split(
      ",",
      @pretokenizer.SplitBehavior::removed(),
      false,
      false,
    ),
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
  )
  b.bench(name="wordlevel-trained-to_json-\{case_name}", fn() {
    let json = try? tok.to_json()
    b.keep(json)
  })
}

///|
fn bench_train_wordpiece_case(
  b : @bench.T,
  case_name : String,
  text : String,
) -> Unit {
  let corpus = [text, text, text, text]
  b.bench(name="wordpiece-train-\{case_name}", fn() {
    b.keep(
      Tokenizer::train_wordpiece(
        corpus,
        unk_token="[UNK]",
        min_frequency=1,
        special_tokens=["[PAD]"],
        vocab_size=Some(512),
      ),
    )
  })
}

///|
fn bench_trained_wordpiece_to_json_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let tok = Tokenizer::train_wordpiece(
    [corpus_mixed(), corpus_mixed()],
    unk_token="[UNK]",
    special_tokens=["[PAD]"],
    vocab_size=Some(512),
  )
  b.bench(name="wordpiece-trained-to_json-\{case_name}", fn() {
    let json = try? tok.to_json()
    b.keep(json)
  })
}

///|
fn bench_train_bpe_case(
  b : @bench.T,
  case_name : String,
  text : String,
) -> Unit {
  let corpus = [text, text, text, text]
  b.bench(name="bpe-train-\{case_name}", fn() {
    b.keep(
      Tokenizer::train_bpe(
        corpus,
        unk_token=Some("[UNK]"),
        min_frequency=2,
        special_tokens=["[PAD]"],
        vocab_size=Some(512),
      ),
    )
  })
}

///|
fn bench_trained_bpe_to_json_case(b : @bench.T, case_name : String) -> Unit {
  let tok = Tokenizer::train_bpe(
    [corpus_mixed(), corpus_mixed()],
    unk_token=Some("[UNK]"),
    special_tokens=["[PAD]"],
    vocab_size=Some(512),
  )
  b.bench(name="bpe-trained-to_json-\{case_name}", fn() {
    let json = try? tok.to_json()
    b.keep(json)
  })
}

///|
fn bench_train_unigram_case(
  b : @bench.T,
  case_name : String,
  text : String,
) -> Unit {
  let corpus = [text, text, text, text]
  b.bench(name="unigram-train-\{case_name}", fn() {
    b.keep(
      Tokenizer::train_unigram(
        corpus,
        unk_token="<unk>",
        min_frequency=1,
        special_tokens=["<pad>"],
        vocab_size=Some(512),
      ),
    )
  })
}

///|
fn bench_trained_unigram_to_json_case(b : @bench.T, case_name : String) -> Unit {
  let tok = Tokenizer::train_unigram(
    [corpus_mixed(), corpus_mixed()],
    unk_token="<unk>",
    special_tokens=["<pad>"],
    vocab_size=Some(512),
  )
  b.bench(name="unigram-trained-to_json-\{case_name}", fn() {
    let json = try? tok.to_json()
    b.keep(json)
  })
}

///|
fn bench_decoder_replace_regex_case(b : @bench.T, case_name : String) -> Unit {
  let decoder = @decoder.Decoder::replace("\\s+", " ")
  let tokens = [
    "The\tquick", "\u{a0}brown\nfox", "\u{3000}jumps", " over\tthe lazy dog.", " MoonBit\nwasm\u{3000}tokenizers.",
  ]
  b.bench(name="decoder-replace-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_trailing_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("\\s+$", "")
  let tokens = [
    "The quick brown fox", " jumps over the lazy dog.", " MoonBit wasm tokenizers.",
    "\t \n",
  ]
  b.bench(name="decoder-replace-trailing-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_split_trailing_ws_regex_case(b : @bench.T, case_name : String) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "\\s+$",
    @pretokenizer.SplitBehavior::removed(),
    false,
    true,
  )
  let text = corpus_mixed() + "\t \n"
  b.bench(name="pretokenizer-split-trailing-ws-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_nonspace_regex_case(b : @bench.T, case_name : String) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "\\S+",
    @pretokenizer.SplitBehavior::removed(),
    false,
    true,
  )
  let text = corpus_mixed()
  b.bench(name="pretokenizer-split-nonspace-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bytelevel_trim_fixture(trim_offsets : Bool) -> Tokenizer raise {
  let trim = if trim_offsets { "true" } else { "false" }
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"Ġ":1,"Ġb":2,"ĠMoonBit":3,"Ġtokenizers":4,"Ġare":5,"Ġfast":6,".":7,"[UNK]":8},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"ByteLevel","trim_offsets":
  Tokenizer::from_str(json + trim + "}}")
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
test "bench encode byte offsets matrix" (b : @bench.T) {
  let mixed = corpus_mixed()
  for model in ["gpt2", "bert", "llama", "Qwen2.5", "phi4_mini", "qwen3_coder"] {
    bench_encode_byte_offsets_case(b, model, "mixed", mixed)
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
test "bench encode_batch duplicate matrix" (b : @bench.T) {
  let mixed = corpus_mixed()
  for model in ["gpt2", "bert", "t5", "llama", "Qwen2.5", "qwen3_coder"] {
    bench_encode_batch_case(b, model, "mixedx8", mixed)
  }
}

///|
test "bench offset lookup matrix" (b : @bench.T) {
  let mixed = corpus_mixed()
  for model in ["gpt2", "bert", "llama", "Qwen2.5", "phi4_mini", "qwen3_coder"] {
    bench_offset_lookup_case(b, model, "mixed", mixed)
  }
}

///|
test "bench bytelevel trim offsets" (b : @bench.T) {
  let tok = bytelevel_trim_fixture(true)
  let text = "a  b MoonBit tokenizers are fast. a  b MoonBit tokenizers are fast."
  b.bench(name="bytelevel-post-trim-offsets", fn() {
    b.keep(tok.encode(text, add_special_tokens=true))
  })
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
      "gpt2", "bert", "t5", "llama", "Qwen2.5", "llama3_2", "phi4_mini", "gpt_oss",
      "qwen3_coder",
    ] {
    bench_load_case(b, model)
  }
}

///|
test "bench to_json matrix" (b : @bench.T) {
  for model in ["gpt2", "bert", "t5", "llama", "Qwen2.5", "qwen3_coder"] {
    bench_to_json_case(b, model)
  }
}

///|
test "bench from_pretrained file matrix" (b : @bench.T) {
  for
    model in [
      "gpt2", "bert", "t5", "llama", "Qwen2.5", "llama3_2", "gpt_oss", "qwen3_coder",
    ] {
    bench_from_pretrained_case(b, model)
  }
}

///|
test "bench train wordlevel" (b : @bench.T) {
  bench_train_wordlevel_case(b, "mixedx4", corpus_mixed())
}

///|
test "bench train wordlevel split pretokenizer" (b : @bench.T) {
  bench_train_wordlevel_split_case(b, "mixedx4", corpus_mixed())
}

///|
test "bench train wordlevel capped" (b : @bench.T) {
  bench_train_wordlevel_capped_case(b, "mixedx4", corpus_mixed())
}

///|
test "bench trained wordlevel to_json" (b : @bench.T) {
  bench_trained_wordlevel_to_json_case(b, "split")
}

///|
test "bench train wordpiece" (b : @bench.T) {
  bench_train_wordpiece_case(b, "mixedx4", corpus_mixed())
}

///|
test "bench trained wordpiece to_json" (b : @bench.T) {
  bench_trained_wordpiece_to_json_case(b, "mixed")
}

///|
test "bench train bpe" (b : @bench.T) {
  bench_train_bpe_case(b, "mixedx4", corpus_mixed())
}

///|
test "bench trained bpe to_json" (b : @bench.T) {
  bench_trained_bpe_to_json_case(b, "mixed")
}

///|
test "bench train unigram" (b : @bench.T) {
  bench_train_unigram_case(b, "mixedx4", corpus_mixed())
}

///|
test "bench trained unigram to_json" (b : @bench.T) {
  bench_trained_unigram_to_json_case(b, "mixed")
}

///|
test "bench decoder replace regex" (b : @bench.T) {
  bench_decoder_replace_regex_case(b, "mixed")
}

///|
test "bench decoder replace trailing regex" (b : @bench.T) {
  bench_decoder_replace_trailing_regex_case(b, "mixed")
}

///|
test "bench split trailing whitespace regex" (b : @bench.T) {
  bench_split_trailing_ws_regex_case(b, "mixed")
}

///|
test "bench split nonspace regex" (b : @bench.T) {
  bench_split_nonspace_regex_case(b, "mixed")
}
