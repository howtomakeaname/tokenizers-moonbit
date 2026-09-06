# 使用指南

`tokenizers-moonbit` 直接加载 HuggingFace `tokenizer.json`，在 MoonBit 各后端执行
encode/decode。

英文版：[`../usage.md`](../usage.md)

## 安装

```bash
moon add howtomakeaname/tokenizers-moonbit
```

`moon add` 只会写入 `moon.mod`，还需要在使用方包的 `moon.pkg` 里声明子包导入
（例如 `moon new` 项目的 `cmd/main/moon.pkg`）：

```text
import {
  "howtomakeaname/tokenizers-moonbit/tokenizer",
}
```

其他子包按同样方式导入（`.../types` 用于错误模式匹配、`.../hub` 用于 Hub 下载）。

## 加载

```moonbit
let tok = @tokenizer.Tokenizer::from_str(json_text)
let tok = @tokenizer.from_file("tokenizer.json")
```

JSON 非法或组件暂不支持时会抛出 `@types.TokenizerError`。会 raise 的调用必须放在
`try`/`catch` 内（`fn main` 函数体不能直接调用），完整最小程序：

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

核心 `@tokenizer.from_pretrained` 保持同步、全后端可用：它只解析本地文件/目录或
已有 HuggingFace Hub cache。native/js 应用如果需要在线下载，可使用可选 `@hub` 包。
下载入口是 `async` 函数，需要 `async fn main` 和 `moonbitlang/async` 运行时：

```moonbit
// moon.pkg 需额外导入：
//   "howtomakeaname/tokenizers-moonbit/hub"
//   "moonbitlang/async"
// 并声明：supported_targets = "+js+native"
async fn main {
  try {
    let tok = @hub.from_pretrained("bert-base-uncased")
    println(tok.get_vocab_size())

    let opts = @hub.HubDownloadOptions::new(
      revision="main",
      cache_dir=Some(".hf-cache"),
      endpoint="https://hf-mirror.com", // 可选镜像 URL
    )
    let tok2 = @hub.from_pretrained("org/model", options=opts)
    println(tok2.get_vocab_size())
  } catch {
    e => println("download failed: \{e.message()}")
  }
}
```

`moonbitlang/async` 需固定为 `tokenizers-moonbit` 在其 `moon.mod` 里声明的同一
版本（0.3.x 为 `moon add moonbitlang/async@0.19.2`）——裸 `moon add` 拉到的更新
版本与本库类型不一致，无法通过编译。

`@hub` 会下载 `tokenizer.json`、写入 HF 风格 cache，然后复用核心 loader。native 请求会使用
接近 HuggingFace/tokenizers 客户端的 User-Agent 与标准 `Accept`/`Authorization` headers；
JS/browser 因 fetch 禁止手动设置 User-Agent，会使用运行时提供的 UA。wasm/
wasm-gc 场景可由宿主环境 fetch JSON 后调用
`@tokenizer.from_pretrained_downloaded(model_id, json_text, cache_dir=...)`。

## 编码

```moonbit
let enc = tok.encode("Hello world")
// enc.ids                 : Array[Int]
// enc.tokens              : Array[String]
// enc.type_ids            : Array[Int]
// enc.attention_mask      : Array[Int]
// enc.special_tokens_mask : Array[Int]
// enc.offsets             : Array[(Int, Int)]   // 字符偏移
```

`add_special_tokens` 默认值为 `true`，控制是否执行 post-processor 模板。文本中
直接出现的 special token 会照常识别。

```moonbit
let enc = tok.encode("text", add_special_tokens=false)
```

## 句对与批量

```moonbit
let pair = tok.encode_pair("question", "context")
let batch = tok.encode_batch(["first text", "second"])
```

`encode_batch` 为串行实现。需要矩阵形输出时，配合 padding 使用。

## 解码

```moonbit
let text = tok.decode(enc.ids)
let raw = tok.decode(enc.ids, skip_special_tokens=false)
```

## 截断

```moonbit
let tok = @tokenizer.Tokenizer::from_str(json)
  .with_truncation(Some(@tokenizer.TruncationParams::new(128)))
let enc = tok.encode(long_text)
```

`TruncationParams` 包含 `max_length`、`stride`、`direction`。`enc.overflowing`
与 HuggingFace 语义一致（已对拍 Python `tokenizers` 0.22.2）：

- 主编码保留第一个窗口，其余窗口全部写入 `enc.overflowing`：`stride = 0` 时
  为顺序切块，`stride > 0` 时相邻窗口重叠 `stride` 个 token。
- `direction = Left` 时主编码保留末尾 `max_length` 个 token，被移除的头部
  成为溢出窗口。
- 后处理器同样作用于每个窗口：template/BERT 窗口带 `[CLS]`/`[SEP]`，固定
  长度 padding 也会把窗口 pad 到同一目标长度。
- 编码 **pair** 时产生 HuggingFace 0.22.x 的窗口叉积：每侧截断窗口与截断后
  主编码的全组合（除主 pair 本身），先按 a 侧窗口（各配主 b 与每个 b 窗口），
  再按主 a 配每个 b 窗口排列。
- 非法 stride 在配置期即被拒绝：`with_truncation` / `enable_truncation` 在
  `stride > 0` 且 `stride > max_length - num_special_tokens_to_add(单序列)`
  时抛错，消息文本与上游一致（`tokenizer stride set to ... effective max
  length ...`）。`stride = 0` 与 `stride == 有效 max_length` 均被接受，与 HF
  一致。pair 编码会在编码期按每侧预算再次校验（pair 模板注入的 special 更多）。

## Padding

```moonbit
let tok = @tokenizer.Tokenizer::from_str(json)
  .with_padding(Some(@tokenizer.PaddingParams::new(@tokenizer.Fixed(64))))

let tok = @tokenizer.Tokenizer::from_str(json)
  .with_padding(Some(@tokenizer.PaddingParams::new(@tokenizer.BatchLongest)))
let batch = tok.encode_batch(texts)
```

枚举变体跨包使用需要包限定（`@tokenizer.Fixed`、`@tokenizer.BatchLongest`）。
`with_padding` / `with_truncation` 等 `with_*` 方法是**原地修改并返回同一个
对象**，不返回副本，原 tokenizer 也会被改到。

padding 位置的 `attention_mask = 0`，`special_tokens_mask = 1`。

## 词表查询

```moonbit
tok.token_to_id("[CLS]")
tok.id_to_token(101)
tok.get_vocab_size()
```

## 错误处理

加载/编码失败会抛出 `@types.TokenizerError`（`suberror`，含
`ParseError(String)`、`UnsupportedComponent(String)`、`VocabError(String)`
三个变体）。用 `try`/`catch` 处理——`try` 块与每个 `catch` 分支必须产出同一
类型：

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

要对错误变体做模式匹配，需额外导入 types 子包（`moon.pkg` 中加入
`"howtomakeaname/tokenizers-moonbit/types"`）。不导入时可以整体捕获后调用
`.message()` / `.kind()`；错误类型没有实现 `Show`，插值时请用 `e.message()`
而不是 `e` 本身。
