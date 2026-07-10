---
title: Verified Models
createTime: 2026/07/10 00:00:00
---

# Verified Models

With optional fixtures present, parity tests compare MoonBit output against
Python `tokenizers` token ids for real `tokenizer.json` files.

| Family | Examples |
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

Fixture files are intentionally git-ignored because full tokenizer JSON files
are large and regenerable.
