# Benchmark

Benchmark 覆盖 encode、decode 与 `tokenizer.json` 加载时间，并使用相同语料对比
MoonBit 与 Python `tokenizers`（Rust 内核）。

英文版：[`../benchmarks/README.md`](../benchmarks/README.md)

## 复现

```bash
python3 scripts/fetch_models.py

moon bench --target native
moon bench --target js
moon bench --target wasm-gc

pip install tokenizers
python3 scripts/bench_python.py

# 同机对比：MoonBit vs HuggingFace tokenizers
python3 scripts/bench_compare.py --target native --corpus mixed
python3 scripts/bench_compare.py --target native --corpus mixed --quick  # 快速抽样
python3 scripts/bench_compare.py --target native --corpus all            # 全模型×语料矩阵
```

## 语料

- `short`：短对话输入，观察交互场景开销。
- `mixed`：英文、CJK、标点混合文本。
- `code`：MoonBit 风格代码、标识符与注释，面向 coder tokenizer。
- `long`：长文档场景，压测 BPE merge 与词表查询。

MoonBit 语料定义在 `src/tokenizer/bench_test.mbt`，Python 基线在
`scripts/bench_python.py` 使用同名语料。

## 对比口径

性能结论不能只引用 `moon bench`。每轮性能优化都应运行：

```bash
python3 scripts/bench_compare.py --target native --corpus mixed
python3 scripts/bench_compare.py --target native --corpus code
python3 scripts/bench_compare.py --target native --corpus all
```

脚本输出 `Moon/HF` 比值，数值越小越好：

- `< 0.90x`：MoonBit 更快。
- `0.90x .. 1.10x`：同一水平，可按热点决定是否继续优化。
- `> 1.10x`：落后于 HF，应进入 `PROGRESS.md` 优化项。

脚本末尾的 `Optimization focus` 会按差距排序，作为后续性能迭代依据。
默认模型列表来自 `scripts/bench_python.py` 的完整 fixture 矩阵，覆盖 GPT-2/
RoBERTa 字节级 BPE、BERT WordPiece、T5/embedding 类 SentencePiece tokenizer、
Llama/Qwen/Phi/Mistral/StarCoder/CLIP 等现代 tokenizer。`--quick` 仅用于本地
冒烟，不应用作正式性能结论。

## 解读

- **正确性优先。** 31 个真实模型（fixture 存在时）与 Python `tokenizers` 做
  token id 对拍。
- **主要优势是部署形态。** Rust crate 在服务器 native 场景很快；浏览器、边缘端
  和纯 JS runtime 通常需要额外 WASM 或 native addon。MoonBit 版本同源输出
  js/wasm/wasm-gc/native。
- **吞吐保持可用。** native BPE/Split 与 Rust 基线处于同一数量级；JS 后端可覆盖
  浏览器推理前处理。
- **优化以比值驱动。** benchmark 相关改动必须给出 MoonBit/HF 对比表；超过 10%
  的落后项需要沉淀到优化排期。

最近 native / mixed 抽样中，加入 BPE/Unigram word cache 后，gpt2 encode 约
0.43x、llama encode 约 0.28x、bert encode 约 0.53x、t5 encode 约 0.39x、
bge/e5 embedding tokenizer encode 约 0.42x（均为 MoonBit/HF，越小越好）。
当前主要差距转为 tokenizer.json 加载路径，后续优先优化大词表解析与构建。

正式引用数据前应重新运行 benchmark。硬件、后端与语料分布都会影响结果。
