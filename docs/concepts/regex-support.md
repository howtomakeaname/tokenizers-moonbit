---
title: Regex Strategy
createTime: 2026/07/10 00:00:00
---

# Regex Strategy

`tokenizers-moonbit` does not embed a full backtracking or fully general Unicode
regex engine. Instead it implements deterministic scanners for common
HuggingFace tokenizer regex families and fails explicitly for unsupported
patterns.

## Policy

| Pattern class | Behavior |
|---|---|
| GPT-2 / Qwen / o200k / CLIP split patterns | Implemented |
| Common whitespace, digit, punctuation and CJK spans | Implemented |
| Simple literal alternatives | Implemented |
| Look-around, backreferences, complex grouping | Unsupported |
| Unknown tokenizer.json regex | Raises `UnsupportedComponent` |

This policy avoids silent tokenizer drift on wasm/js targets while covering the
patterns used by mainstream tokenizer configurations.

## Migration Advice

If a custom tokenizer depends on a complex regex:

1. Try loading it with `Tokenizer::from_str`.
2. If loading raises `UnsupportedComponent`, reduce the pattern to a supported
   deterministic family or pre-tokenize in host code.
3. Add a fixture test that compares token ids with Python `tokenizers`.

The component reference keeps the exhaustive pattern list:
[Supported Components & Limitations](/tokenizers-moonbit/components/).
