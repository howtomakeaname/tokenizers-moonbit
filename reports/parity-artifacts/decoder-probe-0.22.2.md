# HuggingFace tokenizers 0.22.2 — DECODER probe results

- Generated: 2026-09-20 (Python bindings, macOS, python3)
- Method: `decoder.decode(tokens)` called directly, plus full `Tokenizer.decode(ids)` cross-check.
- Outputs are shown as JSON strings so exact whitespace is visible.

## 1. No-decoder behavior (the `tokens.join(" ")` question)

Tokenizer: `models.WordLevel(vocab={{"a":0,"b":1,"c":2,"d":3,"e":4}})`, NO decoder set.

| Probe | Result |
|---|---|
| `decode_[0,1]` | `"a b"` |
| `decode_[1,0]` | `"b a"` |
| `decode_[0]` | `"a"` |
| `decode_[]` | `""` |
| `eot_id` | `5` |
| `decode_[0,eot,1]_skip=True` | `"a b"` |
| `decode_[0,eot,1]_skip=False` | `"a <\|eot\|> b"` |
| `decode_[eot]_skip=True` | `""` |
| `decode_[eot,0]_skip=True` | `"a"` |
| `decode_[0,eot,eot,1]_skip=True` | `"a b"` |
| `foo_id` | `6` |
| `decode_[0,foo,1]_skip=True` | `"a <\|foo\|> b"` |
| `encode_zzz_ids` | `[2]` |
| `encode_zzz_tokens` | `["[UNK]"]` |
| `decode_[unk]_skip=True` | `"[UNK]"` |
| `decode_encode_zzz_skip=True` | `"[UNK]"` |
| `decode_['','a']_ids` | `" a"` |
| `decode_['a','']_ids` | `"a "` |
| `has_no_decoder_method` | `false` |

## 2. Decoder matrix — direct `decoder.decode(tokens)`

Inputs:

| Case | Tokens |
|---|---|
| A | ["hello", "##world"] |
| B | ["▁hello", "▁world"] |
| C | ["h", "\|", "i", "<pad>"] |
| C2 | ["h", "h", "\|", "i"] |
| D | ["Ġhello", "Ġworld"] |
| E | ["ab</w>", "cd</w>"] |
| F | ["  x"] |
| G | ["x", "▁"] |
| G2 | ["▁▁double"] |
| H | ["é", "##cole"] |
| I1 | ["", "a"] |
| I2 | ["a", ""] |
| J | ["hello", "world"] |
| K | ["Ġhello", "!"] |
| K2 | ["Ġ!"] |
| K3 | ["ĠĠx"] |
| K4 | ["Ġhello"] |
| K5 | ["hello"] |
| K6 | ["Ġ"] |
| L | ["Ã©cole", "Ġworld"] |
| M | ["<0x41>", "<0x42>"] |
| M2 | ["<0xC3>", "<0xA9>"] |
| M3 | ["a", "<0x41>", "b"] |

### BPEDecoder(suffix=</w>)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "▁hello▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab cd" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### WordPiece(prefix=##, cleanup=True)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "helloworld" |
| B | ["▁hello", "▁world"] | "▁hello ▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h \| i <pad>" |
| C2 | ["h", "h", "\|", "i"] | "h h \| i" |
| D | ["Ġhello", "Ġworld"] | "Ġhello Ġworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w> cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x ▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "école" |
| I1 | ["", "a"] | " a" |
| I2 | ["a", ""] | "a " |
| J | ["hello", "world"] | "hello world" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©cole Ġworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41> <0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3> <0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a <0x41> b" |

### WordPiece(prefix=##, cleanup=False)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "helloworld" |
| B | ["▁hello", "▁world"] | "▁hello ▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h \| i <pad>" |
| C2 | ["h", "h", "\|", "i"] | "h h \| i" |
| D | ["Ġhello", "Ġworld"] | "Ġhello Ġworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w> cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x ▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "école" |
| I1 | ["", "a"] | " a" |
| I2 | ["a", ""] | "a " |
| J | ["hello", "world"] | "hello world" |
| K | ["Ġhello", "!"] | "Ġhello !" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©cole Ġworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41> <0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3> <0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a <0x41> b" |

### Metaspace(▁, always)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "hello world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x " |
| G2 | ["▁▁double"] | "double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### Metaspace(▁, first)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "hello world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x " |
| G2 | ["▁▁double"] | "double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### Metaspace(▁, never)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | " hello world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x " |
| G2 | ["▁▁double"] | "  double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### CTC(pad=<pad>, delim=|, cleanup=True)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "▁hello▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h i" |
| C2 | ["h", "h", "\|", "i"] | "h i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### CTC(pad=<pad>, delim=|, cleanup=False)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "▁hello▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i" |
| C2 | ["h", "h", "\|", "i"] | "h\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### ByteLevel()

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "▁hello▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | " hello world" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | " hello!" |
| K2 | ["Ġ!"] | " !" |
| K3 | ["ĠĠx"] | "  x" |
| K4 | ["Ġhello"] | " hello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | " " |
| L | ["Ã©cole", "Ġworld"] | "école world" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### ByteFallback()

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "▁hello▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "AB" |
| M2 | ["<0xC3>", "<0xA9>"] | "é" |
| M3 | ["a", "<0x41>", "b"] | "aAb" |

### Strip(content=' ', start=1, stop=0)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "▁hello▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | " x" |
| G | ["x", "▁"] | "x▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### Strip(content='▁', start=1, stop=1)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "helloworld" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "<PanicException: slice index starts at 1 but ends at 0>" |
| G2 | ["▁▁double"] | "▁double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "<PanicException: index out of bounds: the len is 0 but the index is 18446744073709551615>" |
| I2 | ["a", ""] | "<PanicException: index out of bounds: the len is 0 but the index is 18446744073709551615>" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### Replace(str ▁ -> ' ')

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | " hello world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x " |
| G2 | ["▁▁double"] | "  double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### Replace(Regex l+ -> L)

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "heLo##worLd" |
| B | ["▁hello", "▁world"] | "▁heLo▁worLd" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠheLoĠworLd" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x▁" |
| G2 | ["▁▁double"] | "▁▁doubLe" |
| H | ["é", "##cole"] | "é##coLe" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "heLoworLd" |
| K | ["Ġhello", "!"] | "ĠheLo!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "ĠheLo" |
| K5 | ["hello"] | "heLo" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coLeĠworLd" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### Sequence([Replace(▁,' '), Strip(' ',1,0)])

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "helloworld" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | " x" |
| G | ["x", "▁"] | "x" |
| G2 | ["▁▁double"] | " double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### Sequence([Strip('Ġ',1,0), ByteLevel])

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "▁hello▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "helloworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "hello!" |
| K2 | ["Ġ!"] | "!" |
| K3 | ["ĠĠx"] | " x" |
| K4 | ["Ġhello"] | "hello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "" |
| L | ["Ã©cole", "Ġworld"] | "écoleworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### Fuse()

| Case | Input | Output |
|---|---|---|
| A | ["hello", "##world"] | "hello##world" |
| B | ["▁hello", "▁world"] | "▁hello▁world" |
| C | ["h", "\|", "i", "<pad>"] | "h\|i<pad>" |
| C2 | ["h", "h", "\|", "i"] | "hh\|i" |
| D | ["Ġhello", "Ġworld"] | "ĠhelloĠworld" |
| E | ["ab</w>", "cd</w>"] | "ab</w>cd</w>" |
| F | ["  x"] | "  x" |
| G | ["x", "▁"] | "x▁" |
| G2 | ["▁▁double"] | "▁▁double" |
| H | ["é", "##cole"] | "é##cole" |
| I1 | ["", "a"] | "a" |
| I2 | ["a", ""] | "a" |
| J | ["hello", "world"] | "helloworld" |
| K | ["Ġhello", "!"] | "Ġhello!" |
| K2 | ["Ġ!"] | "Ġ!" |
| K3 | ["ĠĠx"] | "ĠĠx" |
| K4 | ["Ġhello"] | "Ġhello" |
| K5 | ["hello"] | "hello" |
| K6 | ["Ġ"] | "Ġ" |
| L | ["Ã©cole", "Ġworld"] | "Ã©coleĠworld" |
| M | ["<0x41>", "<0x42>"] | "<0x41><0x42>" |
| M2 | ["<0xC3>", "<0xA9>"] | "<0xC3><0xA9>" |
| M3 | ["a", "<0x41>", "b"] | "a<0x41>b" |

### `<no decoder>` — full `Tokenizer.decode` (join " ")

| Case | Input | Output |
|---|---|---|
| A | [17, 4] | "hello ##world" |
| B | [29, 30] | "▁hello ▁world" |
| C | [16, 21, 18, 9] | "h \| i <pad>" |
| C2 | [16, 16, 21, 18] | "h h \| i" |
| D | [25, 26] | "Ġhello Ġworld" |
| E | [12, 14] | "ab</w> cd</w>" |
| F | [1] | "  x" |
| G | [20, 28] | "x ▁" |
| G2 | [31] | "▁▁double" |
| H | [15, 3] | "é ##cole" |
| I1 | [0, 11] | " a" |
| I2 | [11, 0] | "a " |
| J | [17, 19] | "hello world" |
| K | [25, 2] | "Ġhello !" |
| K2 | [24] | "Ġ!" |
| K3 | [27] | "ĠĠx" |
| K4 | [25] | "Ġhello" |
| K5 | [17] | "hello" |
| K6 | [23] | "Ġ" |
| L | [22, 26] | "Ã©cole Ġworld" |
| M | [5, 6] | "<0x41> <0x42>" |
| M2 | [8, 7] | "<0xC3> <0xA9>" |
| M3 | [11, 5, 13] | "a <0x41> b" |

Full-tokenizer vs direct-decoder mismatches: **0**

## 3. Metaspace `prepend_scheme` semantics

| Scheme | `[▁hello, ▁world]` | `[hello, ▁world]` | `[▁hello, world]` | `[▁▁double]` | `["", ▁world]` | `[x, ▁]` |
|---|---|---|---|---|---|---|
| always | "hello world" | "hello world" | "helloworld" | "double" | " world" | "x " |
| first | "hello world" | "hello world" | "helloworld" | "double" | " world" | "x " |
| never | " hello world" | "hello world" | " helloworld" | "  double" | " world" | "x " |

`split` attribute on Metaspace decoder: `True`
Default `split`: `true`
`always_split=True`: `{"▁hello▁world(1tok)": "helloworld", "▁hello,▁world": "hello world"}`
`always_split=False`: `{"▁hello▁world(1tok)": "helloworld", "▁hello,▁world": "hello world"}`

## 4. ByteLevel decoder — exact rule

| Probe | Input | Output |
|---|---|---|
| single_leading_space_token | ["Ġhello"] | " hello" |
| plain_single | ["hello"] | "hello" |
| two_tokens | ["Ġhello", "Ġworld"] | " hello world" |
| second_plain | ["hello", "Ġworld"] | "hello world" |
| punct_after | ["Ġhello", "!"] | " hello!" |
| punct_only_Ġ! | ["Ġ!"] | " !" |
| punct_only_! | ["!"] | "!" |
| double_space | ["ĠĠx"] | "  x" |
| bare_space_token | ["Ġ"] | " " |
| multibyte_é | ["Ã©cole", "Ġworld"] | "école world" |
| mid_space | ["hello", "Ġworld", "!"] | "hello world!" |
| invalid_char_€ | ["€"] | "€" |
| invalid_char_▁ | ["▁hello"] | "▁hello" |
| ascii_del_ | ["Ā"] | "\u0000" |

Byte-level map notes: `{"space_byte_0x20_maps_to": "Ġ", "byte_0x00_maps_to": "Ā", "newline_0x0A_maps_to": "Ċ", "tab_0x09_maps_to": "ĉ", "é_bytes": ["0xc3", "0xa9"]}`

## 5. CTC decoder extras

| Probe | Input | cleanup=True | cleanup=False |
|---|---|---|---|
| word_delim_only | ["\|"] | " " | "\|" |
| pad_between | ["h", "<pad>", "i"] | "hi" | "hi" |
| repeat_h | ["h", "h", "i"] | "hi" | "hi" |
| punct | ["h", "!", "i"] | "h!i" | "h!i" |
| pad_only | ["<pad>", "<pad>"] | "" | "" |
| empty | [""] | "" | "" |

## 6. WordPiece decoder extras

| Probe | Input | cleanup=True | cleanup=False |
|---|---|---|---|
| plain_two | ["hello", "world"] | "hello world" | "hello world" |
| continuation_first | ["##world"] | "##world" | "##world" |
| cleanup_punct | ["hello", "!", "world"] | "hello! world" | "hello ! world" |
| cleanup_underscore | ["a", "_", "b"] | "a _ b" | "a _ b" |
| empty_first | ["", "world"] | " world" | " world" |
| empty_continuation | ["hello", "##"] | "hello" | "hello" |

## 7. Introspection

`dir(tokenizers.decoders)`: `["BPEDecoder", "ByteFallback", "ByteLevel", "CTC", "DecodeStream", "Decoder", "Fuse", "Metaspace", "Replace", "Sequence", "Strip", "WordPiece", "decoders"]`

| Decoder | Public attributes (defaults) |
|---|---|
| BPEDecoder | `{"suffix": "</w>"}` |
| WordPiece | `{"cleanup": true, "prefix": "##"}` |
| Metaspace | `{"prepend_scheme": "always", "replacement": "▁", "split": true}` |
| CTC | `{"cleanup": true, "pad_token": "<pad>", "word_delimiter_token": "\|"}` |
| ByteLevel | `{}` |
| ByteFallback | `{}` |
| Strip | `{"content": " ", "start": 1, "stop": 0}` |
| Fuse | `{}` |


## 8. Round 2 — exact-rule probes

### 8.1 BPE suffix placement

| Probe | Output |
|---|---|
| ['ab','cd'] (no suffix anywhere) | "abcd" |
| ['ab','cd</w>'] (suffix on 2nd) | "abcd" |
| ['ab</w>','cd'] (suffix on 1st) | "ab cd" |
| ['</w>'] single | "" |
| ['ab</w>'] single | "ab" |
| ['ab</w>','</w>'] | "ab " |
| custom suffix '_': ['a_','b'] | "a b" |
| custom suffix '_': ['a','b_'] | "ab" |
| ['ab</w></w>'] double suffix | "ab" |

### 8.2 Metaspace first-token trim depth

| Probe | always | first | never |
|---|---|---|---|
| ['▁▁▁x'] (3 leading) | "x" | "x" | "   x" |
| [' x'] (literal space, no ▁) | " x" | " x" | " x" |
| ['  x'] (2 literal spaces) | "  x" | "  x" | "  x" |
| ['▁x▁y'] mid | "xy" | "xy" | " x y" |
| ['▁'] alone | "" | "" | " " |
| ['▁','▁world'] | " world" | " world" | "  world" |
| ['x',' y'] (2nd tok literal space) | "x y" | "x y" | "x y" |
| ['▁a','▁▁b'] mixed depth | "a  b" | "a  b" | " a  b" |

Custom replacement `_` (always): `{"['_hello','_world']": "hello world", "['hello','_world']": "hello world"}`

`split=True` vs `split=False` differences: `{}`

### 8.3 CTC — dedup + cleanup spacing (cleanup=True / cleanup=False)

| Probe | cleanup=True | cleanup=False |
|---|---|---|
| ['h','<pad>','h','i'] (dedup across pad?) | "hhi" | "hhi" |
| ['h','\|','h','i'] (dedup across delim?) | "h hi" | "h|hi" |
| ['a','a','a'] | "a" | "a" |
| ['a',' ','b'] (space token) | "a b" | "a b" |
| ['h','i'] (wordish pair) | "hi" | "hi" |
| ['H','i'] (uppercase) | "Hi" | "Hi" |
| ['1','2'] (digits) | "12" | "12" |
| ['h','1'] (word,digit) | "h1" | "h1" |
| ['!','h'] (punct first) | "!h" | "!h" |
| ['h','!'] (punct last) | "h!" | "h!" |
| ['h','!','h'] | "h!h" | "h!h" |
| ['h','.','i'] | "h.i" | "h.i" |
| ['h',',','i'] | "h,i" | "h,i" |
| ['h','?','i'] | "h?i" | "h?i" |
| ['h',';','i'] | "h;i" | "h;i" |
| ['h',':','i'] | "h:i" | "h:i" |
| ['h','\'','i'] | "h'i" | "h'i" |
| ['h','"','i'] | "h\"i" | "h\"i" |
| ['h','(','i'] | "h(i" | "h(i" |
| ['h',')','i'] | "h)i" | "h)i" |
| ['h','-','i'] | "h-i" | "h-i" |
| ['h','_','i'] | "h_i" | "h_i" |
| ['h','/','i'] | "h/i" | "h/i" |
| ['h','%','i'] | "h%i" | "h%i" |
| ['h','#','i'] | "h#i" | "h#i" |
| ['h','&','i'] | "h&i" | "h&i" |
| ['h','+','i'] | "h+i" | "h+i" |
| ['h','=','i'] | "h=i" | "h=i" |
| ['h','<','i'] | "h<i" | "h<i" |
| ['h','>','i'] | "h>i" | "h>i" |
| ['h','[','i'] | "h[i" | "h[i" |
| ['h','{','i'] | "h{i" | "h{i" |
| ['h','\|\*\|','i'] (delim-like but not exact) | "h * i" | "h|*|i" |
| ['ü','ö'] (non-ascii letters) | "üö" | "üö" |
| ['你','好'] (CJK) | "你好" | "你好" |
| ['。','好'] (CJK punct) | "。好" | "。好" |
| ['h','—','i'] (em dash) | "h—i" | "h—i" |
| ['h','…','i'] (ellipsis) | "h…i" | "h…i" |
| ['h','’','i'] (curly quote) | "h’i" | "h’i" |
| custom delim '\|': ['x','\|','y'] cleanup=True | "x y" | (same as True) |

### 8.4 WordPiece cleanup predicate (['a', X] — cleanup=True / cleanup=False)

| X | cleanup=True | cleanup=False | no-space-before-punct? |
|---|---|---|---|
| ['a','!'] | "a!" | "a !" | YES |
| ['a','?'] | "a?" | "a ?" | YES |
| ['a',','] | "a," | "a ," | YES |
| ['a','.'] | "a." | "a ." | YES |
| ['a',';'] | "a ;" | "a ;" | no |
| ['a',':'] | "a :" | "a :" | no |
| ['a',"'"] | "a '" | "a '" | no |
| ['a','"'] | "a \"" | "a \"" | no |
| ['a','('] | "a (" | "a (" | no |
| ['a',')'] | "a )" | "a )" | no |
| ['a','['] | "a [" | "a [" | no |
| ['a',']'] | "a ]" | "a ]" | no |
| ['a','{'] | "a {" | "a {" | no |
| ['a','}'] | "a }" | "a }" | no |
| ['a','-'] | "a -" | "a -" | no |
| ['a','_'] | "a _" | "a _" | no |
| ['a','/'] | "a /" | "a /" | no |
| ['a','\\'] | "a \\" | "a \\" | no |
| ['a','\|'] | "a |" | "a |" | no |
| ['a','@'] | "a @" | "a @" | no |
| ['a','#'] | "a #" | "a #" | no |
| ['a','$'] | "a $" | "a $" | no |
| ['a','%'] | "a %" | "a %" | no |
| ['a','^'] | "a ^" | "a ^" | no |
| ['a','&'] | "a &" | "a &" | no |
| ['a','*'] | "a *" | "a *" | no |
| ['a','+'] | "a +" | "a +" | no |
| ['a','='] | "a =" | "a =" | no |
| ['a','~'] | "a ~" | "a ~" | no |
| ['a','`'] | "a `" | "a `" | no |
| ['a','<'] | "a <" | "a <" | no |
| ['a','>'] | "a >" | "a >" | no |
| ['a','–'] | "a –" | "a –" | no |
| ['a','—'] | "a —" | "a —" | no |
| ['a','…'] | "a …" | "a …" | no |
| ['a','’'] | "a ’" | "a ’" | no |
| ['a','”'] | "a ”" | "a ”" | no |
| ['a','·'] | "a ·" | "a ·" | no |
| ['a','。'] | "a 。" | "a 。" | no |
| ['a','！'] | "a ！" | "a ！" | no |
| ['a','、'] | "a 、" | "a 、" | no |
| ['a','¡'] | "a ¡" | "a ¡" | no |
| ['a','¿'] | "a ¿" | "a ¿" | no |
| ['a','«'] | "a «" | "a «" | no |
| ['a','»'] | "a »" | "a »" | no |
| ['a','§'] | "a §" | "a §" | no |
| ['a','¶'] | "a ¶" | "a ¶" | no |

Extras:

- ['hello','##!'] (punct continuation) T/F: T="hello!" F="hello!"
- ['!','world'] (punct first) T/F: T="! world" F="! world"
- ['a','!'] T/F: T="a!" F="a !"
- ['a','!!','b'] T/F: T="a!! b" F="a !! b"
- ['a','!b'] (punct-prefixed token) T/F: T="a!b" F="a !b"
- ['a','a!b'] T/F: T="a a!b" F="a a!b"
- custom prefix '@@': ['x','@@y'] T: "xy"

### 8.5 ByteLevel extras

| Probe | Output |
|---|---|
| ['Ġ€'] (valid+invalid) | "Ġ€" |
| ['ĉ'] (tab) | "\t" |
| ['Ċ'] (newline) | "\n" |
| ['ā'] (byte 0x01) | "\u0001" |
| ['ÿ'] (byte 0xFF, invalid utf8 alone) | "�" |
| ['Ā'] (byte 0x00) | "\u0000" |
| ['Ġ','x'] | " x" |
| ['ĊĊ'] two newlines | "\n\n" |
| ['Ã','©'] split multibyte | "é" |
| ['Ð'] lone first byte of 2-byte seq | "�" |

### 8.6 ByteFallback invalid inputs

| Probe | Output |
|---|---|
| ['<0xZZ>'] invalid hex | "<0xZZ>" |
| ['<0xD8>'] surrogate byte | "�" |
| ['<0xFF>'] invalid utf8 byte | "�" |
| ['<0x41'] malformed | "<0x41" |
| ['<0x110>'] 3 hex digits | "<0x110>" |
| ['<0x41><0x42><0x43>'] | "ABC" |
| ['<0xE9>'] single latin1 byte | "�" |

### 8.7 Strip exact behavior

| Probe | Output |
|---|---|
| Strip('▁',1,1) ['x'] (no ▁ present) | "x" |
| Strip('▁',1,1) ['▁x'] | "x" |
| Strip('▁',1,1) ['x▁'] | "x" |
| Strip('a',1,0) ['axb'] (start mismatch) | "xb" |
| Strip('b',0,1) ['axb'] (stop mismatch) | "ax" |
| Strip('a',1,1) ['aba'] | "b" |
| Strip('a',2,0) ['aa'] | "" |
| Strip(' ',2,0) [' x'] (only 1 space) | "x" |
| Strip(' ',2,0) ['  x'] | "x" |
| Strip(' ',0,1) ['x'] (no trailing space) | "x" |
| Strip(' ',1,1) [''] (empty) | "<PanicException: index out of bounds: the len is 0 but the index is 18446744073709551615>" |
| Strip(' ',0,1) [''] (empty, stop only) | "<PanicException: index out of bounds: the len is 0 but the index is 18446744073709551615>" |
| Strip(' ',1,0) [''] (empty, start only) | "" |
| Strip(' ',1,1) ['a b'] | "a b" |
| NOTE: Strip content must be length-1 string in 0.22.2 ('expected a string of length 1') | true |

### 8.8 Replace exact behavior

| Probe | Output |
|---|---|
| Replace('.','X') ['a.b'] (literal vs regex?) | "aXb" |
| Replace('l','') ['hello'] (empty content) | "heo" |
| Regex('l+o') ['hel','lo'] (cross-token match?) | "helL" |
| Regex('o w') ['hello','world'] | "helloworld" |
| Replace('##','') ['hello','##world'] | "helloworld" |


## 9. Round 3 — edge cases (empty inputs, in-token ops, contraction cleanup, specials-before-decoder)

### 9.1 decode([]) for every decoder

| Decoder | Output |
|---|---|
| BPEDecoder | "" |
| WordPiece | "" |
| Metaspace | "" |
| CTC | "" |
| ByteLevel | "" |
| ByteFallback | "" |
| Strip | "" |
| Fuse | "" |
| Replace | "" |
| Sequence | "" |

### 9.2 BPE suffix replace-all semantics

| Probe | Output |
|---|---|
| `['a</w>b','c']` (mid-token suffix) | "a bc" |
| `['x','a</w>b</w>']` (all occurrences in last token) | "xab" |
| Full Tokenizer with BPEDecoder, `decode([])` | "" |

### 9.3 CTC in-token operations

| Probe | Output |
|---|---|
| ['a<pad>b'] T | "ab" |
| ['a<pad>b'] F | "ab" |
| ['a|b'] T (in-token delim) | "a b" |
| ['a|b'] F | "a|b" |
| ['h','h'] adjacent dup T | "h" |
| ['h','h'] F | "h" |
| ['<pad>','<pad>'] T | "" |

### 9.4 WordPiece/CTC contraction cleanup (cleanup=True / cleanup=False)

| Tokens | WordPiece T | WordPiece F | CTC T | CTC F |
|---|---|---|---|---|
| ['a', "'m"] | "a'm" | "a 'm" | "a'm" | "a'm" |
| ['a', "'ve"] | "a've" | "a 've" | "" | "" |
| ['a', "'s"] | "a's" | "a 's" | "" | "" |
| ['a', "'re"] | "a're" | "a 're" | "" | "" |
| ['a', "n't"] | "an't" | "a n't" | "" | "" |
| ['a', 'do not'] | "a don't" | "a do not" | "ado not" | "ado not" |
| ['a', "'hello"] | "a 'hello" | "a 'hello" | "" | "" |
| ['a', " ' "] | "a '" | "a  ' " | "" | "" |
| ['a', "don't"] | "a don't" | "a don't" | "" | "" |
| [' .', 'world'] | ". world" | " . world" | "" | "" |
| ['a', ' .'] | "a ." | "a  ." | "a." | "a ." |
| ['hello', 'world', '.'] | "hello world." | "hello world ." | "helloworld." | "helloworld." |

### 9.5 Misc construction rules

| Probe | Result |
|---|---|
| Metaspace(replacement="ab") | "<ValueError: expected a string of length 1>" |
| Metaspace(replacement="") | "<ValueError: expected a string of length 1>" |
| Replace('a',' ') ['lala'] | "l l " |
| Replace('.','X') ['aXb.c'] | "aXbXc" |

### 9.6 Special tokens are filtered BEFORE the decoder runs (full tokenizer)

| Probe | Output |
|---|---|
| decode([a,eot,b]) skip=True | "a b" |
| decode([a,eot,b]) skip=False | "a <|eot|> b" |

