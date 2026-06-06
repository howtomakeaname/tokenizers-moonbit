# API Reference

All public types live in the `@tokenizer` package, with shared types in
`@types`. Signatures below use MoonBit notation.

Chinese version: [`docs/zh/api.md`](./zh/api.md)

## Loading

```moonbit
fn Tokenizer::from_str(json : String) -> Tokenizer raise TokenizerError
fn from_file(path : String) -> Tokenizer raise TokenizerError
```

- `from_str` parses `tokenizer.json` text; it does no file IO and works on all backends.
- `from_file` reads via `moonbitlang/x/fs` and then calls `from_str`.

## Encoding / decoding

```moonbit
fn Tokenizer::encode(
  self : Tokenizer, text : String, add_special_tokens~ : Bool = true,
) -> Encoding

fn Tokenizer::encode_pair(
  self : Tokenizer, text_a : String, text_b : String,
  add_special_tokens~ : Bool = true,
) -> Encoding

fn Tokenizer::encode_batch(
  self : Tokenizer, texts : Array[String], add_special_tokens~ : Bool = true,
) -> Array[Encoding]

fn Tokenizer::decode(
  self : Tokenizer, ids : Array[Int], skip_special_tokens~ : Bool = true,
) -> String
```

## Configuration builders

```moonbit
fn Tokenizer::with_truncation(self : Tokenizer, params : TruncationParams?) -> Tokenizer
fn Tokenizer::with_padding(self : Tokenizer, params : PaddingParams?) -> Tokenizer
```

Builders mutate and return `self`, so they can be chained:
`from_str(j).with_padding(..)`.

## Vocabulary

```moonbit
fn Tokenizer::token_to_id(self : Tokenizer, token : String) -> Int?
fn Tokenizer::id_to_token(self : Tokenizer, id : Int) -> String?
fn Tokenizer::get_vocab_size(self : Tokenizer) -> Int
```

Lookups consult the added/special vocabulary first, then the model vocabulary.

## Types

### Encoding (`@types`)

```moonbit
pub(all) struct Encoding {
  ids : Array[Int]
  type_ids : Array[Int]
  tokens : Array[String]
  offsets : Array[(Int, Int)]          // char offsets
  special_tokens_mask : Array[Int]
  attention_mask : Array[Int]
  overflowing : Array[Encoding]        // truncation stride windows
}
```

### TruncationParams (`@tokenizer`)

```moonbit
pub(all) enum TruncationDirection { Left; Right }
pub(all) struct TruncationParams {
  max_length : Int
  stride : Int
  direction : TruncationDirection
}
fn TruncationParams::new(max_length : Int) -> TruncationParams  // stride 0, Right
```

### PaddingParams (`@tokenizer`)

```moonbit
pub(all) enum PaddingStrategy { BatchLongest; Fixed(Int) }
pub(all) enum PaddingDirection { Left; Right }
pub(all) struct PaddingParams {
  strategy : PaddingStrategy
  direction : PaddingDirection
  pad_id : Int
  pad_type_id : Int
  pad_token : String
  pad_to_multiple_of : Int?
}
fn PaddingParams::new(
  strategy : PaddingStrategy, pad_id~ : Int = 0, pad_token~ : String = "[PAD]",
) -> PaddingParams
```

### TokenizerError (`@types`)

```moonbit
pub(all) suberror TokenizerError {
  ParseError(String)            // malformed / unexpected tokenizer.json
  UnsupportedComponent(String)  // component type not yet implemented
  VocabError(String)            // malformed vocab / merges
}
```
