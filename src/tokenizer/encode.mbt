// encode: normalized text -> Encoding.
//
// P3 scope: normalize -> pre_tokenize -> model.tokenize each piece -> assemble
// ids/tokens/offsets. Post-processing (special tokens, type_ids beyond 0) lands
// in P7.

/// Encode a single text into an `Encoding`.
pub fn Tokenizer::encode(
  self : Tokenizer,
  text : String,
  add_special_tokens~ : Bool = true,
) -> @types.Encoding {
  // P7 will use add_special_tokens; silence unused warning for now.
  let _ = add_special_tokens

  // 1) normalize
  let normalized = match self.normalizer {
    Some(nm) => nm.normalize(text)
    None => text
  }

  // 2) pre-tokenize
  let pieces : Array[@types.Split] = match self.pre_tokenizer {
    Some(pt) => pt.pre_tokenize(normalized)
    None => [{ value: normalized, offsets: (0, normalized.char_length()) }]
  }

  // 3) run model on each piece
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
