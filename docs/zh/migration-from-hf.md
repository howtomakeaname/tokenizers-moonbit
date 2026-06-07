# 从 HuggingFace 迁移

`tokenizer-moonbit` 尽量保持与 HuggingFace `tokenizers` 相近的调用方式，并复用
同一个 `tokenizer.json`。

英文版：[`../migration-from-hf.md`](../migration-from-hf.md)

## 加载

| HuggingFace (Python) | MoonBit |
|---|---|
| `Tokenizer.from_file("tokenizer.json")` | `@tokenizer.from_file("tokenizer.json")` |
| `Tokenizer.from_str(s)` | `@tokenizer.Tokenizer::from_str(s)` |

```python
from tokenizers import Tokenizer
tok = Tokenizer.from_file("tokenizer.json")
```

```moonbit
let tok = @tokenizer.from_file("tokenizer.json")
```

## 编码

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.encode(text)` | `tok.encode(text)` |
| `tok.encode(text, add_special_tokens=False)` | `tok.encode(text, add_special_tokens=false)` |
| `tok.encode(a, b)` | `tok.encode_pair(a, b)` |

```moonbit
let enc = tok.encode("Hello world")
enc.ids
enc.tokens
enc.attention_mask
```

## 解码

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.decode(ids)` | `tok.decode(ids)` |
| `tok.decode(ids, skip_special_tokens=True)` | `tok.decode(ids, skip_special_tokens=true)` |

## 词表查询

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.token_to_id("[CLS]")` | `tok.token_to_id("[CLS]")` → `Int?` |
| `tok.id_to_token(101)` | `tok.id_to_token(101)` → `String?` |
| `tok.get_vocab_size()` | `tok.get_vocab_size()` |

## 差异

- MoonBit 布尔值为 `true` / `false`，命名参数写作 `name=value`。
- 查询接口返回 `Int?` / `String?`。
- 当前 offsets 为字符偏移；HF 默认返回 byte offsets。
- HF 使用 `enable_truncation` / `enable_padding` 修改 tokenizer；MoonBit 使用
  `with_truncation` / `with_padding` 链式配置。
- 已支持确定性 WordLevel 训练（含自定义 pre-tokenizer、已预切分 token 流、
  `min_frequency`、`special_tokens`、`vocab_size` 以及 HF 风格的频次/词典序词表排序）；
  也已提供 WordPiece trainer MVP，支持相同输入模式以及 continuation prefix、
  `max_input_chars_per_word` 等参数；BPE / Unigram trainer 尚未实现。
