# 从 HuggingFace 迁移

`tokenizers-moonbit` 尽量保持与 HuggingFace `tokenizers` 相近的调用方式，并复用
同一个 `tokenizer.json`。

英文版：[`../migration-from-hf.md`](../migration-from-hf.md)

## 加载

| HuggingFace (Python) | MoonBit |
|---|---|
| `Tokenizer.from_file("tokenizer.json")` | `@tokenizer.from_file("tokenizer.json")` |
| `Tokenizer.from_str(s)` | `@tokenizer.Tokenizer::from_str(s)` |
| `Tokenizer.from_pretrained(id, local_files_only=True)` | `@tokenizer.from_pretrained(id)` 或 `@tokenizer.from_pretrained_cached(id, cache_dir=...)` |
| `Tokenizer.from_pretrained(id)` | native/js 使用 `@hub.from_pretrained(id)`；wasm 可宿主 fetch 后调用 `@tokenizer.from_pretrained_downloaded(id, json)` |
| `tok.save("dir/tokenizer.json")` / 目录工作流 | `tok.save(path)` 或 `tok.save_pretrained(dir)` |
| `BPE.read_file(vocab, merges)` / 模型文件 | `@model.Model::from_bpe_files(vocab, merges)` 以及 WordPiece/WordLevel/Unigram 文件 loader |

```python
from tokenizers import Tokenizer
tok = Tokenizer.from_file("tokenizer.json")
```

```moonbit
let tok = @tokenizer.from_file("tokenizer.json")
```

核心 `@tokenizer.from_pretrained` 是全后端离线解析：支持本地目录/文件，也可从已有
HF Hub cache snapshot 解析（`$HUGGINGFACE_HUB_CACHE`、`$HF_HUB_CACHE`、
`$HF_HOME/hub`、`$HOME/.cache/huggingface/hub`）。在线下载由可选 `@hub` 包在 native/js 后端提供：
它会下载 `tokenizer.json`、写入相同 cache 布局并复用核心 loader。native 请求使用接近
HuggingFace/tokenizers 客户端的 headers，并支持通过
`HubDownloadOptions::new(endpoint="https://hf-mirror.com")` 配置镜像。wasm/wasm-gc 可由
宿主环境 fetch JSON 后调用 `@tokenizer.from_pretrained_downloaded`。
`save_pretrained(dir)` 会写出 `dir/tokenizer.json`，保存后的目录可直接通过
`from_pretrained(dir)` 重新加载。

## 编码

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.encode(text)` | `tok.encode(text)` |
| `tok.encode(text, add_special_tokens=False)` | `tok.encode(text, add_special_tokens=false)` |
| `tok.encode(a, b)` | `tok.encode_pair(a, b)` |
| `tok.encode_batch([(a, b), ...])` | `tok.encode_pair_batch([(a, b), ...])` |
| `tok.encode(words, is_pretokenized=True)` | `tok.encode_pretokenized(words)` |
| `tok.encode_batch([words, ...], is_pretokenized=True)` | `tok.encode_pretokenized_batch([words, ...])` |
| `tok.encode_batch([(words_a, words_b), ...], is_pretokenized=True)` | `tok.encode_pretokenized_pair_batch([(words_a, words_b), ...])` |

pre-tokenized 迁移保留 HF 的 added-token 抽取语义：输入词内部的 special/added
token 仍会先被切出，普通片段再交给 model；只有 tokenizer 配置里的 pre-tokenizer
阶段会被跳过。

```moonbit
let enc = tok.encode("Hello world")
enc.ids
enc.tokens
enc.attention_mask
```

pre-tokenized API 会跳过 tokenizer 的 pre-tokenizer，但仍执行 normalizer、model、
post-processor、truncation 与 padding；offsets 按“归一化后的词用单个 ASCII 空格连接”
得到的合成文本计算。

## 解码

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.decode(ids)` | `tok.decode(ids)` |
| `tok.decode(ids, skip_special_tokens=True)` | `tok.decode(ids, skip_special_tokens=true)` |
| `tok.decode_batch(batch)` | `tok.decode_batch(batch)` |
| `s = tok.decode_stream(False); s.step(id)` | `tok.decode_stream(skip_special_tokens=false)` 后使用 `let (s2, chunk) = s.step(id)` |

MoonBit 的 `DecodeStream::step` 不做原地 mutating，而是显式返回更新后的 stream；继续喂
下一个 id 前需要重新绑定 stream。

## 词表查询

| HuggingFace (Python) | MoonBit |
|---|---|
| `tok.token_to_id("[CLS]")` | `tok.token_to_id("[CLS]")` → `Int?` |
| `tok.id_to_token(101)` | `tok.id_to_token(101)` → `String?` |
| `tok.get_vocab_size()` | `tok.get_vocab_size()` |

## 程序化构造与 AddedToken

| HuggingFace (Python) | MoonBit |
|---|---|
| `Tokenizer(model)` | `@tokenizer.Tokenizer::new(model)` |
| `tok.normalizer = normalizer` | `tok.with_normalizer(Some(normalizer))` |
| `tok.pre_tokenizer = pre_tokenizer` | `tok.with_pre_tokenizer(Some(pre_tokenizer))` |
| `tok.model = model` | `tok.with_model(model)` |
| `tok.post_processor = processor` | `tok.with_post_processor(Some(processor))` |
| `tok.decoder = decoder` | `tok.with_decoder(Some(decoder))` |
| `tok.normalizer` / `tok.model` / ... | `tok.get_normalizer()` / `tok.get_model()` / ... |
| `AddedToken("<x>", single_word=True)` | `AddedToken::new("<x>").with_single_word(true)` |
| `tok.add_tokens([...])` | `tok.add_tokens_with_count([...])` 或 `tok.add_tokens([...])` |
| `tok.add_special_tokens([...])` | `tok.add_special_tokens_with_count([...])` 或 `tok.add_special_tokens([...])` |
| `tok.encode_special_tokens = True` | `tok.set_encode_special_tokens(true)` |
| `tok.encode_special_tokens` | `tok.get_encode_special_tokens()` |
| `tok.get_added_tokens_decoder()` | `tok.get_added_tokens_decoder()` |
| `tok.num_special_tokens_to_add(is_pair)` | `tok.num_special_tokens_to_add(is_pair=...)` |
| `tok.post_process(enc, pair, add_special_tokens=True)` | `tok.post_process(enc, pair=Some(pair), add_special_tokens=true)` |

MoonBit builder 返回更新后的 tokenizer，因此需要重新绑定或直接链式调用：

```moonbit
let (tok, count) = @tokenizer.Tokenizer::new(model)
  .with_pre_tokenizer(Some(@pretokenizer.PreTokenizer::whitespace_split()))
  .add_tokens_with_count([
    @tokenizer.AddedToken::new("<tag>").with_single_word(true),
  ])
```

`*_with_count` 返回 HF 风格的“新分配 id 数量”。普通 added token 的
`special_tokens_mask=0`；`add_special_tokens` 会注册为非归一化 special token，发出时
mask 为 `1`。启用 `encode_special_tokens` 后，输入文本中的 special token 字符串会留在
普通 model 路径上，因此 mask 为 `0`，适合模板/对话场景并对齐 HF 的开关语义。

## 差异

- MoonBit 布尔值为 `true` / `false`，命名参数写作 `name=value`。
- 查询接口返回 `Int?` / `String?`。
- 当前 offsets 为字符偏移；HF 默认返回 byte offsets。
- HF 使用 `enable_truncation` / `enable_padding` 修改 tokenizer；MoonBit 使用
  `with_truncation` / `with_padding` 链式配置，并通过 `TruncationParams::with_*`
  与 `PaddingParams::with_*` 设置 strategy、direction、stride、`pad_type_id`、
  `pad_to_multiple_of` 等参数。
- 常见 HF `Split`/`Replace` 正则族已通过 wasm/js/native 一致的确定性 fast path
  覆盖，包括 `\s`、`\d`、`\w`、ASCII class、Unicode letter/number/punctuation/
  symbol class、anchored run、覆盖同一批正向/反向 class family 的精确 `{2..4}` / 最小
  `{2,}`/`{3,}`/`{4,}` 量词、`{1,n}` bounded run 以及 `{2,3}` / `{2,4}` / `{3,4}` ranged run；任意复杂正则
  暂不作为通用引擎实现，未知 Split 会显式 Unsupported，未知 Replace 按字面量替换。
- 已支持确定性 WordLevel 训练（含自定义 pre-tokenizer、已预切分 token 流、
  `min_frequency`、`special_tokens`、`vocab_size` 以及 HF 风格的频次/词典序词表排序）；
  也已提供 WordPiece / BPE / Unigram trainer MVP，支持相同输入模式以及
  continuation prefix、end-of-word suffix、`max_input_chars_per_word`、`byte_fallback`
  等常见参数；WordPiece/BPE 还支持 `initial_alphabet`、`limit_alphabet` 与
  `max_token_length`，并提供对齐 HF `ByteLevel.alphabet()` 工作流的 `byte_level_alphabet()` helper。
  `vocab_size`、`min_frequency`、BPE `unk_token` 与 Unigram `unk_token` 的 trainer
  默认值已对齐 HF；如需旧的 MoonBit 行为，可显式传入 `unk_token=Some(...)` /
  `unk_piece=Some(...)` 或历史阈值。
