# Usage

`tokenizers-moonbit` loads a HuggingFace `tokenizer.json` and runs encode/decode
on every MoonBit backend. This guide covers the common tasks.

Chinese version: [`docs/zh/usage.md`](./zh/usage.md)

## Installation

```bash
moon add howtomakeaname/tokenizers-moonbit
```

`moon add` records the dependency in `moon.mod`. You also need to declare the
sub-package your code imports, in the `moon.pkg` file of the package that calls
it (for example `cmd/main/moon.pkg` in a fresh `moon new` project):

```text
import {
  "howtomakeaname/tokenizers-moonbit/tokenizer",
}
```

Importing other sub-packages follows the same pattern
(`.../types` for error pattern matching, `.../hub` for Hub download).

## Loading

```moonbit
// From JSON text (backend-agnostic, no file IO):
let tok = @tokenizer.Tokenizer::from_str(json_text)

// From a file path (uses moonbitlang/x/fs):
let tok = @tokenizer.from_file("tokenizer.json")
```

Both functions raise `@types.TokenizerError` on malformed JSON or an
unsupported component. Raising calls must run inside a `try`/`catch` (a `fn
main` body cannot call them directly), so a complete minimal program looks
like:

```moonbit
fn main {
  try {
    let tok = @tokenizer.from_file("tokenizer.json")
    let enc = tok.encode("Hello world")
    println(enc.ids)
  } catch {
    e => println("failed: \{e.message()}")
  }
}
```

### HuggingFace Hub

The core `@tokenizer.from_pretrained` stays synchronous and works on all
backends. It loads local files/directories or an already-populated HF Hub cache:

```moonbit
let tok = @tokenizer.from_pretrained("bert-base-uncased")
```

For native/js applications that want online download, use the optional `@hub`
package. It downloads `tokenizer.json`, writes the standard HF-style cache, then
delegates parsing back to the core tokenizer package. The download entry points
are `async`, so they need an `async fn main` and the `moonbitlang/async`
runtime:

```moonbit
// moon.pkg imports (in addition to .../tokenizer):
//   "howtomakeaname/tokenizers-moonbit/hub"
//   "moonbitlang/async"
// and the package declares: supported_targets = "+js+native"
async fn main {
  try {
    let tok = @hub.from_pretrained("bert-base-uncased")
    println(tok.get_vocab_size())

    let opts = @hub.HubDownloadOptions::new(
      revision="main",
      cache_dir=Some(".hf-cache"),
      endpoint="https://hf-mirror.com", // optional mirror URL for mainland China
      token=None, // or set HF_TOKEN in the environment
    )
    let tok2 = @hub.from_pretrained("org/model", options=opts)
    println(tok2.get_vocab_size())
  } catch {
    e => println("download failed: \{e.message()}")
  }
}
```

Pin `moonbitlang/async` to the same version that `tokenizers-moonbit` declares
in its `moon.mod` (`moon add moonbitlang/async@0.19.2` for 0.3.x) — a newer
version pulled in by a bare `moon add` will not type-check against this
library.

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

`enc.overflowing` mirrors HuggingFace semantics (verified against Python
`tokenizers` 0.22.2):

- The main encoding keeps the first window; every following window lands in
  `enc.overflowing` — for `stride = 0` these are the consecutive remaining
  chunks, for `stride > 0` they overlap the previous window by `stride`.
- With `direction = Left`, the main encoding keeps the last `max_length`
  tokens and the removed head becomes the windows.
- The post-processor runs on each window too: template/BERT windows carry
  `[CLS]`/`[SEP]`, and fixed padding pads windows to the same target length.
- Encoding a **pair** currently leaves `enc.overflowing` empty; HF produces a
  window cross-product there that is not reproduced yet.
- `stride >= max_length` raises an error when truncation runs, matching HF's
  `stride must be strictly less than the effective max length` check.

## Padding

```moonbit
// Fixed length:
let tok = @tokenizer.Tokenizer::from_str(json)
  .with_padding(Some(@tokenizer.PaddingParams::new(@tokenizer.Fixed(64))))

// Pad each batch to the longest member:
let tok = @tokenizer.Tokenizer::from_str(json)
  .with_padding(Some(@tokenizer.PaddingParams::new(@tokenizer.BatchLongest)))
let batch = tok.encode_batch(texts)   // all rows same length
```

`PaddingParams::new(strategy, pad_id?, pad_token?)`; further fields:
`direction` (`Left`/`Right`), `pad_type_id`, `pad_to_multiple_of`. Note that
enum variants from another package are qualified (`@tokenizer.Fixed`,
`@tokenizer.BatchLongest`).

`with_padding` / `with_truncation` (and the other `with_*` setters) modify the
tokenizer in place and return the same object — they do not return a copy, so
the original tokenizer is affected too.

Padded positions get `attention_mask = 0` and `special_tokens_mask = 1`.

## Vocabulary lookups

```moonbit
tok.token_to_id("[CLS]")   // Int?
tok.id_to_token(101)       // String?
tok.get_vocab_size()       // Int
```

## Errors

Load/encode failures raise `@types.TokenizerError` (a `suberror` with
`ParseError(String)`, `UnsupportedComponent(String)` and `VocabError(String)`
variants). Handle it with `try`/`catch` — the `try` block and every `catch`
arm must produce the same type:

```moonbit
fn load(json : String) -> String {
  try {
    let tok = @tokenizer.Tokenizer::from_str(json)
    "loaded, vocab=\{tok.get_vocab_size()}"
  } catch {
    @types.ParseError(msg) => "bad json: \{msg}"
    @types.UnsupportedComponent(c) => "unsupported: \{c}"
    e => "error: \{e.message()}"
  }
}
```

Pattern-matching the error variants requires importing the types sub-package
(`"howtomakeaname/tokenizers-moonbit/types"` in your `moon.pkg`). Without it,
catch the error as a whole and call `.message()` / `.kind()` — errors do not
implement `Show`, so interpolate `e.message()` rather than `e` itself.

See also: [API reference](./api.md), [components](./components.md),
[migration from HF](./migration-from-hf.md).
