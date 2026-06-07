// encode: text -> Encoding.
//
// Pipeline: normalize -> pre_tokenize -> model.tokenize each piece -> assemble
// a raw Encoding -> (optional) post-process to add special tokens / type_ids.

///|
/// Encode a single text into an `Encoding`.
pub fn Tokenizer::encode(
  self : Tokenizer,
  text : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  // Special tokens present in the text are always recognized as single tokens;
  // add_special_tokens only controls whether the post-processor template runs.
  let raw = self.encode_raw(text, keep_special=true)
  let raw = self.truncate_single_raw(raw, add_special_tokens~)
  let processed = if add_special_tokens {
    match self.post_processor {
      Some(pp) => pp.process(raw, None)
      None => raw
    }
  } else {
    raw
  }
  self.finalize_padding(processed)
}

///|
/// Encode a single text and return UTF-8 byte offsets, matching HF's default
/// Rust/Python offset convention more closely than MoonBit char offsets.
pub fn Tokenizer::encode_with_byte_offsets(
  self : Tokenizer,
  text : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  encoding_with_byte_offsets(self.encode(text, add_special_tokens~), text)
}

// Apply fixed padding to a single encoding. Truncation is applied before
// post-processing so the behavior matches HF tokenizers.

///|
fn Tokenizer::finalize_padding(
  self : Tokenizer,
  enc : @types.Encoding,
) -> @types.Encoding {
  match self.padding {
    Some(pp) =>
      match pp.strategy {
        // Fixed padding applies per-encoding; BatchLongest only in encode_batch.
        Fixed(n) => pad_encoding(enc, n, pp)
        BatchLongest => enc
      }
    None => enc
  }
}

///|
fn Tokenizer::truncation_for_raw(
  self : Tokenizer,
  pair~ : Bool,
  add_special_tokens~ : Bool,
) -> TruncationParams? {
  match self.truncation {
    None => None
    Some(tp) => {
      let added = if add_special_tokens {
        match self.post_processor {
          Some(pp) => pp.added_tokens(pair~)
          None => 0
        }
      } else {
        0
      }
      let max_length = if tp.max_length > added {
        tp.max_length - added
      } else {
        0
      }
      Some({ ..tp, max_length, })
    }
  }
}

///|
fn Tokenizer::truncate_single_raw(
  self : Tokenizer,
  raw : @types.Encoding,
  add_special_tokens~ : Bool,
) -> @types.Encoding {
  match self.truncation_for_raw(pair=false, add_special_tokens~) {
    Some(tp) => truncate_encoding(raw, tp)
    None => raw
  }
}

///|
/// Encode a batch of texts. Applies truncation per item, then padding across
/// the batch (BatchLongest pads to the longest in the batch).
pub fn Tokenizer::encode_batch(
  self : Tokenizer,
  texts : Array[String],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] {
  if texts.length() == 0 {
    return []
  }
  // Encode + truncate each; defer padding to a batch pass.
  let encs : Array[@types.Encoding] = []
  let cache : Map[String, @types.Encoding] = {}
  for t in texts {
    match cache.get(t) {
      Some(enc) => encs.push(copy_encoding(enc))
      None => {
        let raw = self.encode_raw(t, keep_special=true)
        let raw = self.truncate_single_raw(raw, add_special_tokens~)
        let processed = if add_special_tokens {
          match self.post_processor {
            Some(pp) => pp.process(raw, None)
            None => raw
          }
        } else {
          raw
        }
        cache[t] = copy_encoding(processed)
        encs.push(processed)
      }
    }
  }
  match self.padding {
    Some(pp) => pad_batch(encs, pp)
    None => encs
  }
}

///|
/// Encode a batch with UTF-8 byte offsets. Batch execution remains serial for
/// deterministic cross-backend behavior.
pub fn Tokenizer::encode_batch_with_byte_offsets(
  self : Tokenizer,
  texts : Array[String],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] {
  let encs = self.encode_batch(texts, add_special_tokens~)
  let out : Array[@types.Encoding] = []
  for i in 0..<encs.length() {
    out.push(encoding_with_byte_offsets(encs[i], texts[i]))
  }
  out
}

///|
/// Encode a pair of texts (sequence A and B) into a single `Encoding`.
pub fn Tokenizer::encode_pair(
  self : Tokenizer,
  text_a : String,
  text_b : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  let a = self.encode_raw(text_a, keep_special=true)
  let b = self.encode_raw(text_b, keep_special=true)
  let (a, b) = match self.truncation_for_raw(pair=true, add_special_tokens~) {
    Some(tp) => truncate_pair_raw(a, Some(b), tp)
    None => (a, Some(b))
  }
  let processed = if add_special_tokens {
    match self.post_processor {
      Some(pp) => pp.process(a, b)
      None => concat_encodings(a, b.unwrap())
    }
  } else {
    concat_encodings(a, b.unwrap())
  }
  self.finalize_padding(processed)
}

///|
/// Encode a pair and return UTF-8 byte offsets for each sequence. Special and
/// padding tokens keep `(0, 0)` offsets.
pub fn Tokenizer::encode_pair_with_byte_offsets(
  self : Tokenizer,
  text_a : String,
  text_b : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  let enc = self.encode_pair(text_a, text_b, add_special_tokens~)
  encoding_with_pair_byte_offsets(enc, text_a, text_b)
}

///|
/// Convert an existing single-sequence encoding's char offsets to UTF-8 byte
/// offsets using the original input text.
fn encoding_with_byte_offsets(
  enc : @types.Encoding,
  text : String,
) -> @types.Encoding {
  let table = char_to_byte_table(text)
  convert_offsets(enc, table, None)
}

///|
/// Convert a pair encoding's char offsets to UTF-8 byte offsets using the two
/// original input texts and `sequence_ids`.
fn encoding_with_pair_byte_offsets(
  enc : @types.Encoding,
  text_a : String,
  text_b : String,
) -> @types.Encoding {
  let table_a = char_to_byte_table(text_a)
  let table_b = char_to_byte_table(text_b)
  convert_offsets(enc, table_a, Some(table_b))
}

///|
fn convert_offsets(
  enc : @types.Encoding,
  table_a : Array[Int],
  table_b : Array[Int]?,
) -> @types.Encoding {
  let offsets : Array[(Int, Int)] = []
  for i in 0..<enc.offsets.length() {
    let table = match enc.sequence_ids[i] {
      Some(1) => table_b.unwrap_or(table_a)
      Some(_) => table_a
      None => table_a
    }
    offsets.push(
      (
        char_to_byte(enc.offsets[i].0, table),
        char_to_byte(enc.offsets[i].1, table),
      ),
    )
  }
  {
    ids: enc.ids.copy(),
    type_ids: enc.type_ids.copy(),
    tokens: enc.tokens.copy(),
    offsets,
    special_tokens_mask: enc.special_tokens_mask.copy(),
    attention_mask: enc.attention_mask.copy(),
    sequence_ids: enc.sequence_ids.copy(),
    word_ids: enc.word_ids.copy(),
    overflowing: enc.overflowing.map(e => convert_offsets(e, table_a, table_b)),
  }
}

///|
fn char_to_byte_table(text : String) -> Array[Int] {
  let out : Array[Int] = [0]
  let mut pos = 0
  for c in text {
    pos = pos + utf8_len(c)
    out.push(pos)
  }
  out
}

///|
fn char_to_byte(pos : Int, table : Array[Int]) -> Int {
  if pos <= 0 {
    0
  } else if pos >= table.length() {
    table[table.length() - 1]
  } else {
    table[pos]
  }
}

///|
fn utf8_len(c : Char) -> Int {
  let cp = c.to_int()
  if cp <= 0x7F {
    1
  } else if cp <= 0x7FF {
    2
  } else if cp <= 0xFFFF {
    3
  } else {
    4
  }
}

// Run added-vocabulary extraction -> normalize -> pre_tokenize -> model,
// producing a raw Encoding (all type_ids = 0). `keep_special` controls whether
// special added-tokens are emitted as single tokens (true) or folded back into
// text (false), matching HF's add_special_tokens semantics.

///|
fn Tokenizer::encode_raw(
  self : Tokenizer,
  text : String,
  keep_special~ : Bool,
) -> @types.Encoding {
  let ids : Array[Int] = []
  let tokens : Array[String] = []
  let type_ids : Array[Int] = []
  let offsets : Array[(Int, Int)] = []
  let special_tokens_mask : Array[Int] = []
  let attention_mask : Array[Int] = []
  let sequence_ids : Array[Int?] = []
  let word_ids : Array[Int?] = []
  let mut next_word_id = 0
  fn emit(
    id : Int,
    value : String,
    offs : (Int, Int),
    special : Int,
    word_id : Int?,
  ) -> Unit {
    ids.push(id)
    tokens.push(value)
    type_ids.push(0)
    offsets.push(offs)
    special_tokens_mask.push(special)
    attention_mask.push(1)
    sequence_ids.push(Some(0))
    word_ids.push(word_id)
  }

  // Stage 1: split out non-normalized added tokens against the original text.
  for seg1 in self.added_vocabulary.extract_stage1(text, keep_special~) {
    match seg1 {
      Special(info~, offsets~) => emit(info.id, info.content, offsets, 1, None)
      Normal(text=raw, base_offset~) => {
        // Normalize this ordinary piece.
        let normalized = match self.normalizer {
          Some(nm) => nm.normalize(raw)
          None => raw
        }
        // Stage 2: split out normalized added tokens within it.
        for
          seg2 in self.added_vocabulary.extract_stage2(
            normalized,
            base_offset,
            keep_special~,
          ) {
          match seg2 {
            Special(info~, offsets~) =>
              emit(info.id, info.content, offsets, 1, None)
            Normal(text=ntext, base_offset=base2) => {
              let pieces : Array[@types.Split] = match self.pre_tokenizer {
                Some(pt) => pt.pre_tokenize(ntext, base_offset=base2)
                None =>
                  [
                    {
                      value: ntext,
                      offsets: (base2, base2 + ntext.char_length()),
                    },
                  ]
              }
              for piece in pieces {
                let word_id = next_word_id
                next_word_id = next_word_id + 1
                for
                  t in self.model.tokenize(piece.value, offset=piece.offsets.0) {
                  emit(t.id, t.value, t.offsets, 0, Some(word_id))
                }
              }
            }
          }
        }
      }
    }
  }
  {
    ids,
    type_ids,
    tokens,
    offsets,
    special_tokens_mask,
    attention_mask,
    sequence_ids,
    word_ids,
    overflowing: [],
  }
}

// Concatenate two encodings (B gets type_id 1) without special tokens.

///|
fn concat_encodings(
  a : @types.Encoding,
  b : @types.Encoding,
) -> @types.Encoding {
  let ids = a.ids.copy()
  let tokens = a.tokens.copy()
  let type_ids = a.type_ids.copy()
  let offsets = a.offsets.copy()
  let special_tokens_mask = a.special_tokens_mask.copy()
  let attention_mask = a.attention_mask.copy()
  let sequence_ids = a.sequence_ids.copy()
  let word_ids = a.word_ids.copy()
  for i in 0..<b.ids.length() {
    ids.push(b.ids[i])
    tokens.push(b.tokens[i])
    type_ids.push(1)
    offsets.push(b.offsets[i])
    special_tokens_mask.push(b.special_tokens_mask[i])
    attention_mask.push(b.attention_mask[i])
    sequence_ids.push(Some(1))
    word_ids.push(b.word_ids[i])
  }
  {
    ids,
    type_ids,
    tokens,
    offsets,
    special_tokens_mask,
    attention_mask,
    sequence_ids,
    word_ids,
    overflowing: [],
  }
}

///|
fn copy_encoding(enc : @types.Encoding) -> @types.Encoding {
  {
    ids: enc.ids.copy(),
    type_ids: enc.type_ids.copy(),
    tokens: enc.tokens.copy(),
    offsets: enc.offsets.copy(),
    special_tokens_mask: enc.special_tokens_mask.copy(),
    attention_mask: enc.attention_mask.copy(),
    sequence_ids: enc.sequence_ids.copy(),
    word_ids: enc.word_ids.copy(),
    overflowing: enc.overflowing.map(e => copy_encoding(e)),
  }
}
