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
| `tok.save("dir/tokenizer.json")` / directory workflows | `tok.save(path)` or `tok.save_pretrained(dir)` |

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
`save_pretrained(dir)` writes `dir/tokenizer.json`, so saved artifacts can be
loaded back with `from_pretrained(dir)`.

## Encoding

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.encode(text)` | `tok.encode(text)` |
| `tok.encode(text, add_special_tokens=False)` | `tok.encode(text, add_special_tokens=false)` |
| `tok.encode(a, b)` | `tok.encode_pair(a, b)` |
| `tok.encode_batch([(a, b), ...])` | `tok.encode_pair_batch([(a, b), ...])` |
| `tok.encode(words, is_pretokenized=True)` | `tok.encode_pretokenized(words)` |
| `tok.encode_batch([words, ...], is_pretokenized=True)` | `tok.encode_pretokenized_batch([words, ...])` |
| `tok.encode_batch([(words_a, words_b), ...], is_pretokenized=True)` | `tok.encode_pretokenized_pair_batch([(words_a, words_b), ...])` |

Pre-tokenized migration keeps HF's added-token extraction semantics: a special
or added token embedded inside an input word is still split out before the
ordinary span is passed to the model, while the configured pre-tokenizer itself
is skipped.

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

Pre-tokenized APIs skip the tokenizer's pre-tokenizer but still apply
normalization, model tokenization, post-processing, truncation and padding.
Offsets are measured against normalized words joined by one ASCII space.

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

## Programmatic construction and added tokens

| HuggingFace (Python) | MoonBit |
|---|---|
| `Tokenizer(model)` | `@tokenizer.Tokenizer::new(model)` |
| `tok.normalizer = normalizer` | `tok.with_normalizer(Some(normalizer))` |
| `tok.pre_tokenizer = pre_tokenizer` | `tok.with_pre_tokenizer(Some(pre_tokenizer))` |
| `tok.model = model` | `tok.with_model(model)` |
| `tok.post_processor = processor` | `tok.with_post_processor(Some(processor))` |
| `tok.decoder = decoder` | `tok.with_decoder(Some(decoder))` |
| `AddedToken("<x>", single_word=True)` | `AddedToken::new("<x>").with_single_word(true)` |
| `tok.add_tokens([...])` | `tok.add_tokens_with_count([...])` or `tok.add_tokens([...])` |
| `tok.add_special_tokens([...])` | `tok.add_special_tokens_with_count([...])` or `tok.add_special_tokens([...])` |

MoonBit builders return updated tokenizer values, so rebind or chain them:

```moonbit
let (tok, count) = @tokenizer.Tokenizer::new(model)
  .with_pre_tokenizer(Some(@pretokenizer.PreTokenizer::whitespace_split()))
  .add_tokens_with_count([
    @tokenizer.AddedToken::new("<tag>").with_single_word(true),
  ])
```

The `*_with_count` variants return HF-style duplicate-aware counts. Ordinary
added tokens keep `special_tokens_mask=0`; `add_special_tokens` registers tokens
as non-normalized special entries and sets mask `1` when they are emitted.

## Differences to be aware of

- **Booleans:** MoonBit uses `true`/`false` and named arguments use `name=value`.
- **Optionals:** lookups return `Int?` / `String?` (`Some`/`None`).
- **Offsets:** HuggingFace returns byte offsets by default; this port currently
  returns char offsets.
- **Configuration style:** HuggingFace mutates via `enable_truncation` /
  `enable_padding`; MoonBit uses chainable `with_truncation` / `with_padding`
  plus `TruncationParams::with_*` and `PaddingParams::with_*` builders for
  strategy, direction, stride, `pad_type_id`, and `pad_to_multiple_of`.
- **Training:** deterministic WordLevel training is supported, including custom
  pre-tokenizers, pre-tokenized token streams, `min_frequency`, `special_tokens`,
  `vocab_size`, and HF-style frequency/lexical vocab ordering. WordPiece, BPE,
  and Unigram trainer MVPs are available for the same input modes with common
  controls such as continuation-prefix, end-of-word suffix,
  `max_input_chars_per_word`, and `byte_fallback`; WordPiece/BPE also support
  `initial_alphabet` and `limit_alphabet`, while BPE additionally supports
  `max_token_length` plus a `byte_level_alphabet()` helper matching HF
  `ByteLevel.alphabet()` workflows.
- **Regex components:** common HF `Split`/`Replace` regex families are handled by
  shared deterministic fast paths across wasm/js/native: `\s`, `\d`, `\w`,
  ASCII classes, Unicode letter/number/punctuation/symbol classes, anchored
  runs, exact `{2..4}` / minimum `{2,}`/`{3,}`/`{4,}` quantifiers across the
  same positive and inverse class families, `{1,n}` bounded runs, and `{2,3}` /
  `{2,4}` / `{3,4}` ranged runs. Arbitrary complex
  regexes are still out of scope; Split rejects unknown patterns explicitly,
  while Replace falls back to literal replacement.

## Verified models

With optional fixtures present, output is checked token-for-token against Python
`tokenizers` for 31 real models, covering BPE, byte-level BPE, byte_fallback BPE,
WordPiece, Unigram, WordLevel, Qwen/Llama-3/o200k Split patterns, coder,
multimodal and embedding tokenizers. See [`PROGRESS.md`](../PROGRESS.md).
