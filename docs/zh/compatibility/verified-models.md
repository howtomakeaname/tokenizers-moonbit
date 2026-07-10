---
title: Verified Models
createTime: 2026/07/10 00:00:00
---

# Verified Models

当可选 fixture 存在时，parity 测试会用真实 `tokenizer.json` 文件比较
MoonBit 输出与 Python `tokenizers` token id。

| Family | 示例 |
|---|---|
| Classic encoder/tokenizer models | GPT-2, RoBERTa, BERT, BERT-cased, DistilBERT, T5, ALBERT, XLM-RoBERTa |
| Modern LLM tokenizers | Llama, Llama-3.2, Qwen2.5, Qwen3, Qwen3-Coder, Qwen3-VL, DeepSeek, Mistral, Falcon |
| Code and multimodal | StarCoder2, GPT-NeoX, CLIP, GLM, Granite |
| Embedding tokenizers | BGE-M3, BGE-large-en, multilingual-E5, E5-small, MiniLM, Jina, Nomic, MixedBread |
| Newer encoder families | ModernBERT, GTE-ModernBERT, SmolLM2 |

## Reproducing Fixture Tests

```bash
python3 scripts/fetch_models.py
pip install tokenizers
python3 scripts/gen_parity.py
moon test --target native
```

完整 tokenizer JSON 文件较大且可再生成，因此 fixture 文件会有意被 git ignore。
