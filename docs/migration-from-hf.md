# Migrating from HuggingFace `tokenizers`

`tokenizers-moonbit` mirrors the HuggingFace `tokenizers` API closely. This guide
maps common Python usage to MoonBit. The same `tokenizer.json` works in both.

Chinese version: [`docs/zh/migration-from-hf.md`](./zh/migration-from-hf.md)

## Loading

| HuggingFace (Python) | MoonBit |
|---|---|
| `Tokenizer.from_file("tokenizer.json")` | `@tokenizer.from_file("tokenizer.json")` |
| `Tokenizer.from_str(s)` | `@tokenizer.Tokenizer::from_str(s)` |
| `Tokenizer.from_pretrained(id, local_files_only=True)` | `@tokenizer.from_pretrained(id)` or `@tokenizer.from_pretrained_cached(id, cache_dir=...)` |

```python
from tokenizers import Tokenizer
tok = Tokenizer.from_file("tokenizer.json")
```

```moonbit
let tok = @tokenizer.from_file("tokenizer.json")
```

`from_str` takes JSON text and does no file IO, so it works on every backend.
`from_file` uses `moonbitlang/x/fs`. `from_pretrained` is offline-only: it can
load a local directory/file or resolve an existing HF Hub cache snapshot via
`$HUGGINGFACE_HUB_CACHE`, `$HF_HOME/hub`, or `$HOME/.cache/huggingface/hub`.

## Encoding

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.encode(text)` | `tok.encode(text)` |
| `tok.encode(text, add_special_tokens=False)` | `tok.encode(text, add_special_tokens=false)` |
| `tok.encode(a, b)` | `tok.encode_pair(a, b)` |

```python
enc = tok.encode("Hello world")
enc.ids            # [15496, 995]
enc.tokens         # ['Hello', 'Ġworld']
enc.attention_mask # [1, 1]
```

```moonbit
let enc = tok.encode("Hello world")
enc.ids            // [15496, 995]
enc.tokens         // ["Hello", "Ġworld"]
enc.attention_mask // [1, 1]
```

### `Encoding` fields

| HuggingFace | MoonBit | Notes |
|---|---|---|
| `enc.ids` | `enc.ids` | `Array[Int]` |
| `enc.tokens` | `enc.tokens` | `Array[String]` |
| `enc.type_ids` | `enc.type_ids` | `Array[Int]` |
| `enc.attention_mask` | `enc.attention_mask` | `Array[Int]` |
| `enc.special_tokens_mask` | `enc.special_tokens_mask` | `Array[Int]` |
| `enc.offsets` | `enc.offsets` | `Array[(Int, Int)]`; currently char offsets |

## Decoding

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.decode(ids)` | `tok.decode(ids)` |
| `tok.decode(ids, skip_special_tokens=True)` | `tok.decode(ids, skip_special_tokens=true)` |

## Vocabulary lookups

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.token_to_id("[CLS]")` | `tok.token_to_id("[CLS]")` → `Int?` |
| `tok.id_to_token(101)` | `tok.id_to_token(101)` → `String?` |
| `tok.get_vocab_size()` | `tok.get_vocab_size()` |

## Differences to be aware of

- **Booleans:** MoonBit uses `true`/`false` and named arguments use `name=value`.
- **Optionals:** lookups return `Int?` / `String?` (`Some`/`None`).
- **Offsets:** HuggingFace returns byte offsets by default; this port currently
  returns char offsets.
- **Configuration style:** HuggingFace mutates via `enable_truncation` /
  `enable_padding`; MoonBit uses chainable `with_truncation` / `with_padding`.
- **Training:** deterministic WordLevel training is supported, including custom
  pre-tokenizers, pre-tokenized token streams, `min_frequency`, `special_tokens`,
  `vocab_size`, and HF-style frequency/lexical vocab ordering. WordPiece, BPE,
  and Unigram trainer MVPs are available for the same input modes with common
  controls such as continuation-prefix, end-of-word suffix,
  `max_input_chars_per_word`, and `byte_fallback`.

## Verified models

With optional fixtures present, output is checked token-for-token against Python
`tokenizers` for 31 real models, covering BPE, byte-level BPE, byte_fallback BPE,
WordPiece, Unigram, WordLevel, Qwen/Llama-3/o200k Split patterns, coder,
multimodal and embedding tokenizers. See [`PROGRESS.md`](../PROGRESS.md).
