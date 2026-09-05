# Usage

`tokenizers-moonbit` loads a HuggingFace `tokenizer.json` and runs encode/decode
on every MoonBit backend. This guide covers the common tasks.

Chinese version: [`docs/zh/usage.md`](./zh/usage.md)

## Loading

```moonbit
// From JSON text (backend-agnostic, no file IO):
let tok = @tokenizer.Tokenizer::from_str(json_text)

// From a file path (uses moonbitlang/x/fs):
let tok = @tokenizer.from_file("tokenizer.json")
```

Both functions may raise `@types.TokenizerError` on malformed JSON or an
unsupported component. Handle it with `try`/`catch` or propagate it with
`raise`.

### HuggingFace Hub

The core `@tokenizer.from_pretrained` stays synchronous and works on all
backends. It loads local files/directories or an already-populated HF Hub cache:

```moonbit
let tok = @tokenizer.from_pretrained("bert-base-uncased")
```

For native/js applications that want online download, use the optional `@hub`
package. It downloads `tokenizer.json`, writes the standard HF-style cache, then
delegates parsing back to the core tokenizer package:

```moonbit
let tok = @hub.from_pretrained("bert-base-uncased")

let opts = @hub.HubDownloadOptions::new(
  revision="main",
  cache_dir=Some(".hf-cache"),
  endpoint="https://hf-mirror.com", // optional mirror URL for mainland China
  token=None, // or set HF_TOKEN in the environment
)
let tok2 = @hub.from_pretrained("org/model", options=opts)
```

The optional Hub downloader is supported on `native` and `js` via
`moonbitlang/async/http`. Its native requests use a HuggingFace/tokenizers-like
User-Agent plus standard `Accept`/`Authorization` headers; browser/JS builds rely
on the runtime-supplied User-Agent because fetch forbids setting it manually. On
wasm/wasm-gc, fetch JSON in the host application and call
`@tokenizer.from_pretrained_downloaded(model_id, json_text, cache_dir=...)` or
`Tokenizer::from_str` directly.

## Encoding

```moonbit
let enc = tok.encode("Hello world")
// enc.ids                 : Array[Int]
// enc.tokens              : Array[String]
// enc.type_ids            : Array[Int]
// enc.attention_mask      : Array[Int]
// enc.special_tokens_mask : Array[Int]
// enc.offsets             : Array[(Int, Int)]   // char offsets
```

`add_special_tokens` defaults to `true` and controls whether the post-processor
template runs. Special tokens that literally appear in the text are still
recognized.

```moonbit
let enc = tok.encode("text", add_special_tokens=false)
```

### Pairs

```moonbit
let enc = tok.encode_pair("question", "context")
// builds e.g. [CLS] question [SEP] context [SEP] with type_ids 0/1
```

### Batches

```moonbit
let batch = tok.encode_batch(["first text", "second"])
```

Batching is single-threaded by design. Combine it with padding for rectangular
outputs.

## Decoding

```moonbit
let text = tok.decode(enc.ids)                          // skips special tokens
let raw  = tok.decode(enc.ids, skip_special_tokens=false)
```

## Truncation

```moonbit
let tok = @tokenizer.Tokenizer::from_str(json)
  .with_truncation(Some(@tokenizer.TruncationParams::new(128)))
let enc = tok.encode(long_text)   // capped to 128 tokens
```

`TruncationParams` fields: `max_length`, `stride`, `direction` (`Left`/`Right`).
With `stride > 0`, trimmed tail windows are placed in `enc.overflowing`.

## Padding

```moonbit
// Fixed length:
let tok = @tokenizer.Tokenizer::from_str(json)
  .with_padding(Some(@tokenizer.PaddingParams::new(Fixed(64))))

// Pad each batch to the longest member:
let tok = @tokenizer.Tokenizer::from_str(json)
  .with_padding(Some(@tokenizer.PaddingParams::new(BatchLongest)))
let batch = tok.encode_batch(texts)   // all rows same length
```

`PaddingParams::new(strategy, pad_id?, pad_token?)`; further fields:
`direction` (`Left`/`Right`), `pad_type_id`, `pad_to_multiple_of`.

Padded positions get `attention_mask = 0` and `special_tokens_mask = 1`.

## Vocabulary lookups

```moonbit
tok.token_to_id("[CLS]")   // Int?
tok.id_to_token(101)       // String?
tok.get_vocab_size()       // Int
```

## Errors

```moonbit
fn load(json : String) -> Unit {
  match (try? @tokenizer.Tokenizer::from_str(json)) {
    Ok(tok) => ...
    Err(@types.ParseError(msg)) => println("bad json: \{msg}")
    Err(@types.UnsupportedComponent(c)) => println("unsupported: \{c}")
    Err(_) => ()
  }
}
```

See also: [API reference](./api.md), [components](./components.md),
[migration from HF](./migration-from-hf.md).
