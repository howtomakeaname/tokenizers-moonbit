---
title: Types and Errors
createTime: 2026/07/10 00:00:00
---

# Types and Errors

The `@types` package contains shared runtime values such as `Encoding`, `Token`,
`Split`, `NormalizedString`, `PreTokenizedString` and `TokenizerError`.

## Encoding Fields

| Field | Meaning |
|---|---|
| `ids` | token ids |
| `tokens` | token surface values |
| `type_ids` | segment/template ids |
| `offsets` | character or byte spans, depending on API |
| `special_tokens_mask` | 1 for special/pad tokens |
| `attention_mask` | 0 for padding |
| `sequence_ids` | single/pair sequence ownership |
| `word_ids` | pre-tokenized word ownership |

## Error Variants

| Error | Typical source |
|---|---|
| `ParseError` | malformed tokenizer JSON or wrong field types |
| `UnsupportedComponent` | unsupported tokenizer component or regex |
| `VocabError` | missing unknown token fallback, bad vocab references |
| `IoError` | file/cache operations |

