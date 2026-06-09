// Encode/decode/load throughput benchmarks. Run with `moon bench`.
//
// These load real tokenizer.json fixtures from tests/data (git-ignored); when
// a fixture is absent the bench body is a no-op so `moon bench` still runs.
// Use them to compare backends (native/js/wasm-gc) and to pair with the Python
// baseline in scripts/bench_python.py for the "same correctness, runs in the
// browser" story (see docs/benchmarks).

///|
fn load_text(path : String) -> String? {
  if @fs.path_exists(path) {
    Some(@fs.read_file_to_string(path)) catch {
      _ => None
    }
  } else {
    None
  }
}

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
fn load_model(name : String) -> @tokenizer.Tokenizer? raise {
  match load_text("tests/data/\{name}.full.json") {
    Some(j) => Some(@tokenizer.Tokenizer::from_str(j))
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
fn bench_wordpiece_repeated_case(b : @bench.T) -> Unit raise {
  guard load_model("bert") is Some(tok) else { return }
  let text = "tokenization tokenization tokenization tokenization tokenization"
  ignore(tok.encode(text, add_special_tokens=false))
  b.bench(name="bert-wordpiece-cache-repeat", fn() {
    b.keep(tok.encode(text, add_special_tokens=false))
  })
}

///|
fn bench_precompiled_normalizer_case(b : @bench.T, case_name : String) -> Unit {
  let normalizer = @normalizer.Normalizer::Precompiled
  let ascii = "The\tquick brown\nfox jumps over MoonBit tokenizers. "
  let unicode = "ＡＢＣ\u{1680}１２３\u{2028}Ⅳ ① ㍿ ﬁ ﬂ Å ㎏ "
  let sb = StringBuilder::new()
  for _ in 0..<64 {
    sb.write_string(ascii)
    sb.write_string(unicode)
  }
  let text = sb.to_string()
  b.bench(name="normalizer-precompiled-\{case_name}", fn() {
    b.keep(normalizer.normalize(text))
  })
}

///|
fn bench_precompiled_binary_charsmap_case(b : @bench.T) -> Unit raise {
  let charsmap = "DAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQQ0AAAAAAAB4AA=="
  let json = "{\"type\":\"Precompiled\",\"precompiled_charsmap\":\"" +
    charsmap +
    "\"}"
  let normalizer = @normalizer.Normalizer::from_json(@json.parse(json))
  let text = "A plain ASCII payload with repeated A markers. "
  let sb = StringBuilder::new()
  for _ in 0..<256 {
    sb.write_string(text)
  }
  let input = sb.to_string()
  b.bench(name="normalizer-precompiled-binary-charsmap", fn() {
    b.keep(normalizer.normalize(input))
  })
}

///|
fn bench_load_case(b : @bench.T, model : String) -> Unit {
  guard load_text("tests/data/\{model}.full.json") is Some(json) else { return }
  b.bench(name="\{model}-from_str", fn() {
    let t = try? @tokenizer.Tokenizer::from_str(json)
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
  ignore(try? @tokenizer.Tokenizer::from_pretrained(path))
  b.bench(name="\{model}-from_pretrained-file", fn() {
    let t = try? @tokenizer.Tokenizer::from_pretrained(path)
    b.keep(t)
  })
}

///|
fn bench_ensure_dir(path : String) -> Unit {
  @fs.create_dir(path) catch {
    _ => ()
  }
}

///|
fn bench_save_pretrained_case(b : @bench.T, model : String) -> Unit raise {
  guard load_model(model) is Some(tok) else { return }
  let root = "_build/bench_save_pretrained"
  let dir = root + "/" + model
  bench_ensure_dir(root)
  bench_ensure_dir(dir)
  b.bench(name="\{model}-save_pretrained", fn() {
    let path = try? tok.save_pretrained(dir)
    b.keep(path)
  })
}

///|
fn bench_from_pretrained_hub_cache_case(b : @bench.T, model : String) -> Unit {
  let path = "tests/data/\{model}.full.json"
  guard load_text(path) is Some(content) else { return }
  let root = "_build/bench_hf_cache"
  let repo = root + "/models--bench--" + model
  let refs = repo + "/refs"
  let snapshots = repo + "/snapshots"
  let rev = snapshots + "/benchrev"
  bench_ensure_dir(root)
  bench_ensure_dir(repo)
  bench_ensure_dir(refs)
  bench_ensure_dir(snapshots)
  bench_ensure_dir(rev)
  @fs.write_string_to_file(refs + "/main", "benchrev\n") catch {
    _ => ()
  }
  @fs.write_string_to_file(rev + "/tokenizer.json", content) catch {
    _ => ()
  }
  b.bench(name="\{model}-from_pretrained-hub-cache", fn() {
    let t = try? @tokenizer.Tokenizer::from_pretrained_cached(
      "bench/" + model,
      cache_dir=Some(root),
    )
    b.keep(t)
  })
}

///|
fn bench_from_pretrained_multi_cache_case(b : @bench.T) -> Unit {
  guard load_text("tests/data/gpt2.full.json") is Some(_) else { return }
  guard load_text("tests/data/bert.full.json") is Some(_) else { return }
  ignore(
    try? @tokenizer.Tokenizer::from_pretrained("tests/data/gpt2.full.json"),
  )
  ignore(
    try? @tokenizer.Tokenizer::from_pretrained("tests/data/bert.full.json"),
  )
  b.bench(name="from_pretrained-multi-cache-hit", fn() {
    let a = try? @tokenizer.Tokenizer::from_pretrained(
      "tests/data/gpt2.full.json",
    )
    let b2 = try? @tokenizer.Tokenizer::from_pretrained(
      "tests/data/bert.full.json",
    )
    b.keep(a)
    b.keep(b2)
  })
}

///|
fn bench_from_str_multi_parse_cache_case(b : @bench.T) -> Unit {
  guard load_text("tests/data/gpt2.full.json") is Some(gpt2) else { return }
  guard load_text("tests/data/bert.full.json") is Some(bert) else { return }
  ignore(try? @tokenizer.Tokenizer::from_str(gpt2))
  ignore(try? @tokenizer.Tokenizer::from_str(bert))
  b.bench(name="from_str-multi-parse-cache-hit", fn() {
    let a = try? @tokenizer.Tokenizer::from_str(gpt2)
    let b2 = try? @tokenizer.Tokenizer::from_str(bert)
    b.keep(a)
    b.keep(b2)
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
      @tokenizer.Tokenizer::train_wordlevel(
        corpus,
        unk_token="[UNK]",
        min_frequency=1,
        special_tokens=["[PAD]"],
      ),
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
      @tokenizer.Tokenizer::train_wordlevel_with_pretokenizer(
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
      @tokenizer.Tokenizer::train_wordlevel(
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
  let tok = @tokenizer.Tokenizer::train_wordlevel_with_pretokenizer(
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
      @tokenizer.Tokenizer::train_wordpiece(
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
fn bench_train_wordpiece_alphabet_case(
  b : @bench.T,
  case_name : String,
  text : String,
) -> Unit {
  let corpus = [text, text, text, text]
  b.bench(name="wordpiece-train-alphabet-\{case_name}", fn() {
    b.keep(
      @tokenizer.Tokenizer::train_wordpiece(
        corpus,
        unk_token="[UNK]",
        min_frequency=1,
        special_tokens=["[PAD]"],
        vocab_size=Some(512),
        initial_alphabet=["z", "🙂"],
        limit_alphabet=Some(128),
      ),
    )
  })
}

///|
fn bench_trained_wordpiece_to_json_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let tok = @tokenizer.Tokenizer::train_wordpiece(
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
      @tokenizer.Tokenizer::train_bpe(
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
fn bench_train_bpe_bytelevel_alphabet_case(
  b : @bench.T,
  case_name : String,
  text : String,
) -> Unit {
  let corpus = [text, text, text, text]
  b.bench(name="bpe-train-bytelevel-alphabet-\{case_name}", fn() {
    b.keep(
      @tokenizer.Tokenizer::train_bpe_with_pretokenizer(
        corpus,
        @pretokenizer.PreTokenizer::byte_level(
          add_prefix_space=false,
          use_regex=true,
        ),
        unk_token=Some("[UNK]"),
        min_frequency=2,
        special_tokens=["[PAD]"],
        vocab_size=Some(512),
        initial_alphabet=@pretokenizer.byte_level_alphabet(),
      ),
    )
  })
}

///|
fn bench_train_bpe_max_token_length_case(
  b : @bench.T,
  case_name : String,
  text : String,
) -> Unit {
  let corpus = [text, text, text, text]
  b.bench(name="bpe-train-max-token-length-\{case_name}", fn() {
    b.keep(
      @tokenizer.Tokenizer::train_bpe(
        corpus,
        unk_token=Some("[UNK]"),
        min_frequency=2,
        special_tokens=["[PAD]"],
        vocab_size=Some(512),
        max_token_length=Some(32),
      ),
    )
  })
}

///|
fn bench_trained_bpe_to_json_case(b : @bench.T, case_name : String) -> Unit {
  let tok = @tokenizer.Tokenizer::train_bpe(
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
      @tokenizer.Tokenizer::train_unigram(
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
  let tok = @tokenizer.Tokenizer::train_unigram(
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
fn bench_decoder_replace_min_ws_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("\\s{2,}", " ")
  let tokens = [
    "The quick", "  brown\t\tfox", " jumps", "\u{3000}\u{3000}over the lazy dog.",
  ]
  b.bench(name="decoder-replace-min-ws-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_exact_ws_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("[\\s]{3}", " ")
  let tokens = [
    "The \t\u{a0}quick", "\n\n\nbrown", " fox    jumps", " over\t\t\tthe lazy dog.",
  ]
  b.bench(name="decoder-replace-exact-ws-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_newline_quantifier_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("[\\r\\n]{2,}", "\n")
  let tokens = ["line1\r\n", "line2\n\n", "line3\n", "line4\r\n\n"]
  b.bench(name="decoder-replace-newline-quantifier-regex-\{case_name}", fn() {
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
fn bench_decoder_replace_leading_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("^\\s+", "")
  let tokens = [
    "\t \u{3000}The quick brown fox", " jumps over the lazy dog.", " MoonBit wasm tokenizers.",
  ]
  b.bench(name="decoder-replace-leading-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_anchored_union_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("[\\p{P}\\p{S}]+$", "")
  let tokens = [
    "The quick brown fox", " jumps over MoonBit", " wasm tokenizers🙂+!",
  ]
  b.bench(name="decoder-replace-anchored-union-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_normalizer_replace_anchored_inverse_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let normalizer = @normalizer.Normalizer::Replace(
    pattern="^[^\\p{P}\\p{S}]+",
    content="N",
  )
  let text = corpus_mixed() + ",$+🙂"
  b.bench(name="normalizer-replace-anchored-inverse-regex-\{case_name}", fn() {
    b.keep(normalizer.normalize(text))
  })
}

///|
fn bench_decoder_replace_digit_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("\\d+", "#")
  let tokens = ["abc123", " def4567", " 890xyz", " MoonBit2026"]
  b.bench(name="decoder-replace-digit-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_digit_class_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("[\\d]{2,}", "#")
  let tokens = ["a1b12", " def4567", " 8x90", " MoonBit2026"]
  b.bench(name="decoder-replace-digit-class-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_exact_digit_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("\\d{2}", "#")
  let tokens = ["abc12345", " def4567", " 890xyz", " MoonBit2026"]
  b.bench(name="decoder-replace-exact-digit-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_word_quantifier_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("\\w{2}", "W")
  let tokens = ["ab_12,", "x,cde", " MoonBit2026", " tokenizers"]
  b.bench(name="decoder-replace-word-quantifier-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_bounded_quantifier_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("[\\p{P}\\p{S}]{1,3}", "_")
  let tokens = ["hi,$+🙂", " code(a+b);", " path/to/file.rs", " done!!!"]
  b.bench(name="decoder-replace-bounded-quantifier-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_bounded_inverse_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("[^\\s\\p{L}\\p{N}]{1,3}", "#")
  let tokens = ["ab,$+🙂", " cd。42", " path/to/file.rs", " done!!!"]
  b.bench(name="decoder-replace-bounded-inverse-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_punctuation_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("[\\p{P}\\p{S}]+", "_")
  let tokens = ["hi,!", "$+🙂ok。", " code(a+b);", " path/to/file.rs"]
  b.bench(name="decoder-replace-punct-symbol-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_punct_quantifier_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("\\p{P}{2,}", "_")
  let tokens = ["hi,!", "?ok。", " code(a+b);", " path/to/file.rs"]
  b.bench(name="decoder-replace-punct-quantifier-regex-\{case_name}", fn() {
    b.keep(decoder.decode(tokens))
  })
}

///|
fn bench_decoder_replace_union_quantifier_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let decoder = @decoder.Decoder::replace("[\\p{P}\\p{S}]{2,}", "_")
  let tokens = ["hi,!", "$+🙂ok。", " code(a+b);", " path/to/file.rs"]
  b.bench(name="decoder-replace-union-quantifier-regex-\{case_name}", fn() {
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
fn bench_split_horizontal_ws_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[^\\S\\r\\n]+",
    @pretokenizer.SplitBehavior::removed(),
    false,
    true,
  )
  let text = corpus_mixed() + "\t  more horizontal whitespace\n next line"
  b.bench(name="pretokenizer-split-horizontal-ws-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_exact_ws_regex_case(b : @bench.T, case_name : String) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[\\s]{3}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " \t\u{a0} exact\n\n\n runs    end"
  b.bench(name="pretokenizer-split-exact-ws-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_newline_quantifier_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[\\r\\n]{2,}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + "\r\nparagraph\n\nnext\r\n\nend"
  b.bench(name="pretokenizer-split-newline-quantifier-regex-\{case_name}", fn() {
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
fn bench_split_digit_regex_case(b : @bench.T, case_name : String) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "\\d+",
    @pretokenizer.SplitBehavior::removed(),
    false,
    true,
  )
  let text = corpus_mixed() + " 12345 2026"
  b.bench(name="pretokenizer-split-digit-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_digit_class_regex_case(b : @bench.T, case_name : String) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[\\d]{2,}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " a1b12c１２3 20260608"
  b.bench(name="pretokenizer-split-digit-class-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_exact_digit_regex_case(b : @bench.T, case_name : String) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "\\d{2}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " 123456789 20260608 42"
  b.bench(name="pretokenizer-split-exact-digit-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_word_quantifier_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "\\w{2,}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " snake_case x cde MoonBit2026"
  b.bench(name="pretokenizer-split-word-quantifier-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_bounded_word_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "\\w{1,3}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " snake_case x cde MoonBit2026"
  b.bench(name="pretokenizer-split-bounded-word-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_ascii_letter_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[A-Za-z]+",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " ASCIIonly words_with_digits abc123é中 XYZ"
  b.bench(name="pretokenizer-split-ascii-letter-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_ascii_alnum_regex_case(b : @bench.T, case_name : String) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[A-Za-z0-9]+",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " ASCII123 words_with_digits abc123é中 XYZ_42"
  b.bench(name="pretokenizer-split-ascii-alnum-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_bounded_digit_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "\\d{1,4}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " 123456789 20260608 42"
  b.bench(name="pretokenizer-split-bounded-digit-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_punctuation_regex_case(b : @bench.T, case_name : String) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[\\p{P}\\p{S}]+",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " $+🙂 ok。 code(a+b); path/to/file.rs"
  b.bench(name="pretokenizer-split-punct-symbol-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_punct_quantifier_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "\\p{P}{2,}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " wait!!! ok?! path/to/file.rs"
  b.bench(name="pretokenizer-split-punct-quantifier-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_union_quantifier_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[\\p{P}\\p{S}]{2,}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " $+🙂 wait!!! ok?! path/to/file.rs"
  b.bench(name="pretokenizer-split-union-quantifier-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_bounded_union_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[\\p{P}\\p{S}]{1,3}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " $+🙂 wait!!! ok?! path/to/file.rs"
  b.bench(name="pretokenizer-split-bounded-union-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bench_split_bounded_inverse_regex_case(
  b : @bench.T,
  case_name : String,
) -> Unit {
  let pt = @pretokenizer.PreTokenizer::split(
    "[^\\s\\p{L}\\p{N}]{1,3}",
    @pretokenizer.SplitBehavior::isolated(),
    false,
    true,
  )
  let text = corpus_mixed() + " $+🙂 wait!!! ok?! path/to/file.rs"
  b.bench(name="pretokenizer-split-bounded-inverse-regex-\{case_name}", fn() {
    b.keep(pt.pre_tokenize(text, base_offset=0))
  })
}

///|
fn bytelevel_trim_fixture(trim_offsets : Bool) -> @tokenizer.Tokenizer raise {
  let trim = if trim_offsets { "true" } else { "false" }
  let json =
    #|{"version":"1.0",
    #| "pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false,"use_regex":true},
    #| "model":{"type":"WordLevel","vocab":{"a":0,"Ġ":1,"Ġb":2,"ĠMoonBit":3,"Ġtokenizers":4,"Ġare":5,"Ġfast":6,".":7,"[UNK]":8},"unk_token":"[UNK]"},
    #| "post_processor":{"type":"ByteLevel","trim_offsets":
  @tokenizer.Tokenizer::from_str(json + trim + "}}")
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
test "bench precompiled normalizer" (b : @bench.T) {
  bench_precompiled_normalizer_case(b, "mixed")
}

///|
test "bench precompiled binary charsmap" (b : @bench.T) {
  bench_precompiled_binary_charsmap_case(b)
}

///|
test "bench wordpiece repeated word cache" (b : @bench.T) {
  bench_wordpiece_repeated_case(b)
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
    let t = try? @tokenizer.Tokenizer::from_str(json)
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
test "bench save_pretrained matrix" (b : @bench.T) {
  for model in ["gpt2", "llama"] {
    bench_save_pretrained_case(b, model)
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
test "bench from_pretrained hub cache" (b : @bench.T) {
  bench_from_pretrained_hub_cache_case(b, "gpt2")
}

///|
test "bench from_pretrained multi cache hit" (b : @bench.T) {
  bench_from_pretrained_multi_cache_case(b)
}

///|
test "bench from_str multi parse cache hit" (b : @bench.T) {
  bench_from_str_multi_parse_cache_case(b)
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
test "bench train wordpiece alphabet" (b : @bench.T) {
  bench_train_wordpiece_alphabet_case(b, "mixedx4", corpus_mixed())
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
test "bench train bpe bytelevel alphabet" (b : @bench.T) {
  bench_train_bpe_bytelevel_alphabet_case(b, "mixedx4", corpus_mixed())
}

///|
test "bench train bpe max token length" (b : @bench.T) {
  bench_train_bpe_max_token_length_case(b, "mixedx4", corpus_mixed())
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
test "bench decoder replace min whitespace regex" (b : @bench.T) {
  bench_decoder_replace_min_ws_regex_case(b, "mixed")
}

///|
test "bench decoder replace exact whitespace regex" (b : @bench.T) {
  bench_decoder_replace_exact_ws_regex_case(b, "mixed")
}

///|
test "bench decoder replace newline quantifier regex" (b : @bench.T) {
  bench_decoder_replace_newline_quantifier_regex_case(b, "mixed")
}

///|
test "bench decoder replace trailing regex" (b : @bench.T) {
  bench_decoder_replace_trailing_regex_case(b, "mixed")
}

///|
test "bench decoder replace leading regex" (b : @bench.T) {
  bench_decoder_replace_leading_regex_case(b, "mixed")
}

///|
test "bench decoder replace anchored union regex" (b : @bench.T) {
  bench_decoder_replace_anchored_union_regex_case(b, "mixed")
}

///|
test "bench normalizer replace anchored inverse regex" (b : @bench.T) {
  bench_normalizer_replace_anchored_inverse_regex_case(b, "mixed")
}

///|
test "bench decoder replace digit regex" (b : @bench.T) {
  bench_decoder_replace_digit_regex_case(b, "mixed")
}

///|
test "bench decoder replace digit class regex" (b : @bench.T) {
  bench_decoder_replace_digit_class_regex_case(b, "mixed")
}

///|
test "bench decoder replace exact digit regex" (b : @bench.T) {
  bench_decoder_replace_exact_digit_regex_case(b, "mixed")
}

///|
test "bench decoder replace word quantifier regex" (b : @bench.T) {
  bench_decoder_replace_word_quantifier_regex_case(b, "mixed")
}

///|
test "bench decoder replace bounded quantifier regex" (b : @bench.T) {
  bench_decoder_replace_bounded_quantifier_regex_case(b, "mixed")
}

///|
test "bench decoder replace bounded inverse regex" (b : @bench.T) {
  bench_decoder_replace_bounded_inverse_regex_case(b, "mixed")
}

///|
test "bench decoder replace punct-symbol regex" (b : @bench.T) {
  bench_decoder_replace_punctuation_regex_case(b, "mixed")
}

///|
test "bench decoder replace punct quantifier regex" (b : @bench.T) {
  bench_decoder_replace_punct_quantifier_regex_case(b, "mixed")
}

///|
test "bench decoder replace union quantifier regex" (b : @bench.T) {
  bench_decoder_replace_union_quantifier_regex_case(b, "mixed")
}

///|
test "bench split trailing whitespace regex" (b : @bench.T) {
  bench_split_trailing_ws_regex_case(b, "mixed")
}

///|
test "bench split horizontal whitespace regex" (b : @bench.T) {
  bench_split_horizontal_ws_regex_case(b, "mixed")
}

///|
test "bench split exact whitespace regex" (b : @bench.T) {
  bench_split_exact_ws_regex_case(b, "mixed")
}

///|
test "bench split newline quantifier regex" (b : @bench.T) {
  bench_split_newline_quantifier_regex_case(b, "mixed")
}

///|
test "bench split nonspace regex" (b : @bench.T) {
  bench_split_nonspace_regex_case(b, "mixed")
}

///|
test "bench split digit regex" (b : @bench.T) {
  bench_split_digit_regex_case(b, "mixed")
}

///|
test "bench split digit class regex" (b : @bench.T) {
  bench_split_digit_class_regex_case(b, "mixed")
}

///|
test "bench split exact digit regex" (b : @bench.T) {
  bench_split_exact_digit_regex_case(b, "mixed")
}

///|
test "bench split word quantifier regex" (b : @bench.T) {
  bench_split_word_quantifier_regex_case(b, "mixed")
}

///|
test "bench split bounded word regex" (b : @bench.T) {
  bench_split_bounded_word_regex_case(b, "mixed")
}

///|
test "bench split ascii letter regex" (b : @bench.T) {
  bench_split_ascii_letter_regex_case(b, "mixed")
}

///|
test "bench split ascii alnum regex" (b : @bench.T) {
  bench_split_ascii_alnum_regex_case(b, "mixed")
}

///|
test "bench split bounded digit regex" (b : @bench.T) {
  bench_split_bounded_digit_regex_case(b, "mixed")
}

///|
test "bench split punct-symbol regex" (b : @bench.T) {
  bench_split_punctuation_regex_case(b, "mixed")
}

///|
test "bench split punct quantifier regex" (b : @bench.T) {
  bench_split_punct_quantifier_regex_case(b, "mixed")
}

///|
test "bench split union quantifier regex" (b : @bench.T) {
  bench_split_union_quantifier_regex_case(b, "mixed")
}

///|
test "bench split bounded union regex" (b : @bench.T) {
  bench_split_bounded_union_regex_case(b, "mixed")
}

///|
test "bench split bounded inverse regex" (b : @bench.T) {
  bench_split_bounded_inverse_regex_case(b, "mixed")
}
