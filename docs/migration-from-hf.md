# Migrating from HuggingFace `tokenizers`

`tokenizer-moonbit` mirrors the HuggingFace `tokenizers` API closely. This guide
maps common Python usage to MoonBit. The same `tokenizer.json` works in both.

## Loading

| HuggingFace (Python) | MoonBit |
|---|---|
| `Tokenizer.from_file("tokenizer.json")` | `@tokenizer.from_file("tokenizer.json")` |
| `Tokenizer.from_str(s)` | `@tokenizer.Tokenizer::from_str(s)` |

```python
# Python
from tokenizers import Tokenizer
tok = Tokenizer.from_file("tokenizer.json")
```

```moonbit
// MoonBit
let tok = @tokenizer.from_file("tokenizer.json")
```

> `from_str` takes the JSON text and does no file IO, so it works on every
> backend (wasm/wasm-gc/js/native). `from_file` uses `moonbitlang/x/fs`.

## Encoding

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.encode(text)` | `tok.encode(text)` |
| `tok.encode(text, add_special_tokens=False)` | `tok.encode(text, add_special_tokens=false)` |
| `tok.encode(a, b)` (pair) | `tok.encode_pair(a, b)` |

```python
# Python
enc = tok.encode("Hello world")
enc.ids            # [15496, 995]
enc.tokens         # ['Hello', 'Ġworld']
enc.attention_mask # [1, 1]
```

```moonbit
// MoonBit
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
| `enc.offsets` | `enc.offsets` | `Array[(Int, Int)]`; currently char offsets (see Differences) |

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

- **Booleans:** MoonBit uses `true`/`false` (lowercase) and named arguments use
  `name=value` (e.g. `add_special_tokens=false`).
- **Optionals:** lookups return `Int?` / `String?` (`Some`/`None`) instead of
  `None`/`int`.
- **Offsets:** HuggingFace's default `encode` returns **byte** offsets relative
  to the original text. This port currently returns **char** offsets. Byte
  offsets are on the roadmap.
- **Not yet available:** `enable_truncation` / `enable_padding` / `encode_batch`
  are planned (see [`PROGRESS.md`](../PROGRESS.md)). Unicode normalization
  (NFC/NFKC) currently acts as identity; `strip_accents` support is on the
  roadmap.
- **Training is out of scope.** This library loads and runs existing
  tokenizers; it does not train new ones.

## Verified models

Output is checked token-for-token against Python `tokenizers` for: GPT-2
(byte-level BPE), BERT (WordPiece), T5 (Unigram), and Llama (byte_fallback BPE).
See [`PROGRESS.md`](../PROGRESS.md) for the up-to-date list.
