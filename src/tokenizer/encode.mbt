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
  let raw = self.encode_raw(text)
  if add_special_tokens {
    match self.post_processor {
      Some(pp) => pp.process(raw, None)
      None => raw
    }
  } else {
    raw
  }
}

/// Encode a pair of texts (sequence A and B) into a single `Encoding`.
pub fn Tokenizer::encode_pair(
  self : Tokenizer,
  text_a : String,
  text_b : String,
  add_special_tokens~ : Bool = true,
) -> @types.Encoding {
  let a = self.encode_raw(text_a)
  let b = self.encode_raw(text_b)
  if add_special_tokens {
    match self.post_processor {
      Some(pp) => pp.process(a, Some(b))
      None => concat_encodings(a, b)
    }
  } else {
    concat_encodings(a, b)
  }
}

// Run normalize -> pre_tokenize -> model, producing a raw Encoding (no special
// tokens, all type_ids = 0).
fn Tokenizer::encode_raw(self : Tokenizer, text : String) -> @types.Encoding {
  let normalized = match self.normalizer {
    Some(nm) => nm.normalize(text)
    None => text
  }
  let pieces : Array[@types.Split] = match self.pre_tokenizer {
    Some(pt) => pt.pre_tokenize(normalized)
    None => [{ value: normalized, offsets: (0, normalized.char_length()) }]
  }
  let ids : Array[Int] = []
  let tokens : Array[String] = []
  let type_ids : Array[Int] = []
  let offsets : Array[(Int, Int)] = []
  let special_tokens_mask : Array[Int] = []
  let attention_mask : Array[Int] = []
  for piece in pieces {
    let toks = self.model.tokenize(piece.value, offset=piece.offsets.0)
    for t in toks {
      ids.push(t.id)
      tokens.push(t.value)
      type_ids.push(0)
      offsets.push(t.offsets)
      special_tokens_mask.push(0)
      attention_mask.push(1)
    }
  }
  { ids, type_ids, tokens, offsets, special_tokens_mask, attention_mask }
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
  { ids, type_ids, tokens, offsets, special_tokens_mask, attention_mask }
}
