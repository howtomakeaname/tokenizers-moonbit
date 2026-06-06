# Usage

`tokenizer-moonbit` loads a HuggingFace `tokenizer.json` and runs encode/decode
on every MoonBit backend. This guide covers the common tasks.

## Loading

```moonbit
// From the JSON text (backend-agnostic, no file IO — works on wasm too):
let tok = @tokenizer.Tokenizer::from_str(json_text)

// From a file path (uses moonbitlang/x/fs, available on all backends):
let tok = @tokenizer.from_file("tokenizer.json")
```

Both may raise `@types.TokenizerError` on malformed JSON or an unsupported
component; handle with `try`/`catch` or propagate with `raise`.

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

`add_special_tokens` (default `true`) controls whether the post-processor
template (e.g. `[CLS]` … `[SEP]`) runs. Special tokens that literally appear in
the text are always recognized regardless:

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

Batching is single-threaded (the target is wasm/js). Combine with padding to get
rectangular output (see below).

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
