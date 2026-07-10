---
title: Testing
createTime: 2026/07/10 00:00:00
---

# Testing

## Core Matrix

```bash
moon fmt --check
moon check --deny-warn
moon test --target native --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
```

## Optional Parity Fixtures

```bash
python3 scripts/fetch_models.py
pip install tokenizers
python3 scripts/gen_parity.py
moon test --target native
```

## What to Test for Behavior Changes

| Change area | Required coverage |
|---|---|
| tokenizer.json parsing | Positive fixture plus wrong-type/missing-field negative tests |
| encode pipeline | single, pair, batch, fast and pre-tokenized where shared helpers are touched |
| offsets | char-offset and byte-offset variants for alignment-sensitive fixes |
| Hub logic | local cache helper tests plus HTTP status/metadata decisions |
| Trainers | deterministic input corpus and state round-trip where configuration changes |

## Review Discipline

Run focused tests first to catch local failures quickly, then the full target
matrix before committing user-visible behavior changes.
