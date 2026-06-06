// encode: text -> Encoding.
//
// Pipeline: normalize -> pre_tokenize -> model.tokenize each piece -> assemble
// a raw Encoding -> (optional) post-process to add special tokens / type_ids.

/// Encode a single text into an `Encoding`.
pub fn Tokenizer::encode(
  self : Tokenizer,
  text : String,
  add_special_tokens~ : Bool = true,
) -> @types.Encoding {
  // Special tokens present in the text are always recognized as single tokens;
  // add_special_tokens only controls whether the post-processor template runs.
  let raw = self.encode_raw(text, keep_special=true)
  let processed = if add_special_tokens {
    match self.post_processor {
      Some(pp) => pp.process(raw, None)
      None => raw
    }
  } else {
    raw
  }
  self.finalize(processed)
}

// Apply truncation and (fixed) padding to a single encoding.
fn Tokenizer::finalize(self : Tokenizer, enc : @types.Encoding) -> @types.Encoding {
  let truncated = match self.truncation {
    Some(tp) => truncate_encoding(enc, tp)
    None => enc
  }
  match self.padding {
    Some(pp) =>
      match pp.strategy {
        // Fixed padding applies per-encoding; BatchLongest only in encode_batch.
        Fixed(n) => pad_encoding(truncated, n, pp)
        BatchLongest => truncated
      }
    None => truncated
  }
}

/// Encode a batch of texts. Applies truncation per item, then padding across
/// the batch (BatchLongest pads to the longest in the batch).
pub fn Tokenizer::encode_batch(
  self : Tokenizer,
  texts : Array[String],
  add_special_tokens~ : Bool = true,
) -> Array[@types.Encoding] {
  // Encode + truncate each; defer padding to a batch pass.
  let encs = texts.map(t => {
    let raw = self.encode_raw(t, keep_special=true)
    let processed = if add_special_tokens {
      match self.post_processor {
        Some(pp) => pp.process(raw, None)
        None => raw
      }
    } else {
      raw
    }
    match self.truncation {
      Some(tp) => truncate_encoding(processed, tp)
      None => processed
    }
  })
  match self.padding {
    Some(pp) => pad_batch(encs, pp)
    None => encs
  }
}

/// Encode a pair of texts (sequence A and B) into a single `Encoding`.
pub fn Tokenizer::encode_pair(
  self : Tokenizer,
  text_a : String,
  text_b : String,
  add_special_tokens~ : Bool = true,
) -> @types.Encoding {
  let a = self.encode_raw(text_a, keep_special=true)
  let b = self.encode_raw(text_b, keep_special=true)
  if add_special_tokens {
    match self.post_processor {
      Some(pp) => pp.process(a, Some(b))
      None => concat_encodings(a, b)
    }
  } else {
    concat_encodings(a, b)
  }
}

// Run added-vocabulary extraction -> normalize -> pre_tokenize -> model,
// producing a raw Encoding (all type_ids = 0). `keep_special` controls whether
// special added-tokens are emitted as single tokens (true) or folded back into
// text (false), matching HF's add_special_tokens semantics.
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
  fn emit(id : Int, value : String, offs : (Int, Int), special : Int) -> Unit {
    ids.push(id)
    tokens.push(value)
    type_ids.push(0)
    offsets.push(offs)
    special_tokens_mask.push(special)
    attention_mask.push(1)
  }

  // Stage 1: split out non-normalized added tokens against the original text.
  for seg1 in self.added_vocabulary.extract_stage1(text, keep_special~) {
    match seg1 {
      Special(info~, offsets~) => emit(info.id, info.content, offsets, 1)
      Normal(text=raw, base_offset~) => {
        // Normalize this ordinary piece.
        let normalized = match self.normalizer {
          Some(nm) => nm.normalize(raw)
          None => raw
        }
        // Stage 2: split out normalized added tokens within it.
        for seg2 in self.added_vocabulary.extract_stage2(
            normalized,
            base_offset,
            keep_special~,
          ) {
          match seg2 {
            Special(info~, offsets~) => emit(info.id, info.content, offsets, 1)
            Normal(text=ntext, base_offset=base2) => {
              let pieces : Array[@types.Split] = match self.pre_tokenizer {
                Some(pt) => pt.pre_tokenize(ntext, base_offset=base2)
                None =>
                  [{ value: ntext, offsets: (base2, base2 + ntext.char_length()) }]
              }
              for piece in pieces {
                for t in self.model.tokenize(
                    piece.value,
                    offset=piece.offsets.0,
                  ) {
                  emit(t.id, t.value, t.offsets, 0)
                }
              }
            }
          }
        }
      }
    }
  }
  { ids, type_ids, tokens, offsets, special_tokens_mask, attention_mask, overflowing: [] }
}

// Concatenate two encodings (B gets type_id 1) without special tokens.
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
  for i in 0..<b.ids.length() {
    ids.push(b.ids[i])
    tokens.push(b.tokens[i])
    type_ids.push(1)
    offsets.push(b.offsets[i])
    special_tokens_mask.push(b.special_tokens_mask[i])
    attention_mask.push(b.attention_mask[i])
  }
  { ids, type_ids, tokens, offsets, special_tokens_mask, attention_mask, overflowing: [] }
}
