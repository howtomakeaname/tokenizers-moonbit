---
title: Trainer
createTime: 2026/07/10 00:00:00
---

# Trainer

Training APIs provide deterministic MoonBit implementations for common
WordLevel, WordPiece, BPE and Unigram workflows.

## Entry Points

```moonbit
Tokenizer::train(...)
Tokenizer::train_from_iterator(...)
Tokenizer::train_from_files(...)
Trainer::wordlevel_trainer(...)
Trainer::wordpiece_trainer(...)
Trainer::bpe_trainer(...)
Trainer::unigram_trainer(...)
```

## Common Knobs

| Knob | Applies to | Notes |
|---|---|---|
| `vocab_size` | all | Output vocabulary cap |
| `min_frequency` | WordLevel / WordPiece / BPE | Frequency threshold |
| `special_tokens` | all | String specials |
| `special_added_tokens` | all | AddedToken metadata-preserving specials |
| `initial_alphabet` | WordPiece / BPE / Unigram | Required alphabet seed |
| `limit_alphabet` | WordPiece / BPE | Alphabet cap |
| `byte_fallback` | BPE / Unigram | Modern LLM tokenizer support |

Trainer state and getter aliases are exposed for Python binding compatibility.
