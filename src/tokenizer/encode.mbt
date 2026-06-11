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
  self.finalize_padding(
    self.process_single_raw(
      self.encode_raw(text, keep_special=true),
      add_special_tokens~,
    ),
  )
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

///|
/// Encode an already pre-tokenized sequence of words. This mirrors HF's
/// `is_pretokenized=True` flow: normalizer/model/post-processor/truncation/
/// padding still run, but the tokenizer's pre-tokenizer is skipped. Offsets are
/// expressed against a synthetic single-space-joined normalized text.
pub fn Tokenizer::encode_pretokenized(
  self : Tokenizer,
  words : Array[String],
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  self.finalize_padding(
    self.process_single_raw(
      self.encode_pretokenized_raw(words),
      add_special_tokens~,
    ),
  )
}

///|
/// Encode pre-tokenized words and return UTF-8 byte offsets against the same
/// synthetic single-space-joined normalized text used for char offsets.
pub fn Tokenizer::encode_pretokenized_with_byte_offsets(
  self : Tokenizer,
  words : Array[String],
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  encoding_with_byte_offsets(
    self.encode_pretokenized(words, add_special_tokens~),
    self.pretokenized_offset_text(words),
  )
}

///|
/// Encode an already pre-tokenized pair of word sequences. Each side skips the
/// tokenizer's pre-tokenizer and receives its own `sequence_ids` after
/// post-processing, matching `encode_pair` for ordinary strings.
pub fn Tokenizer::encode_pretokenized_pair(
  self : Tokenizer,
  words_a : Array[String],
  words_b : Array[String],
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  self.finalize_padding(
    self.encode_pretokenized_pair_unpadded(
      words_a,
      words_b,
      add_special_tokens~,
    ),
  )
}

///|
/// Encode a pre-tokenized pair and return UTF-8 byte offsets for each synthetic
/// single-space-joined side.
pub fn Tokenizer::encode_pretokenized_pair_with_byte_offsets(
  self : Tokenizer,
  words_a : Array[String],
  words_b : Array[String],
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  encoding_with_pair_byte_offsets(
    self.encode_pretokenized_pair(words_a, words_b, add_special_tokens~),
    self.pretokenized_offset_text(words_a),
    self.pretokenized_offset_text(words_b),
  )
}

///|
fn Tokenizer::process_single_raw(
  self : Tokenizer,
  raw : @types.Encoding,
  add_special_tokens~ : Bool,
) -> @types.Encoding {
  let raw = self.truncate_single_raw(raw, add_special_tokens~)
  if add_special_tokens {
    match self.post_processor {
      Some(pp) => pp.process(raw, None)
      None => raw
    }
  } else {
    raw
  }
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
        let processed = self.process_single_raw(
          self.encode_raw(t, keep_special=true),
          add_special_tokens~,
        )
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
/// Encode a batch of pre-tokenized word arrays. Repeated word sequences are
/// copied from a per-call cache and BatchLongest padding is applied once across
/// the whole batch.
pub fn Tokenizer::encode_pretokenized_batch(
  self : Tokenizer,
  batch : Array[Array[String]],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] {
  if batch.length() == 0 {
    return []
  }
  let encs : Array[@types.Encoding] = []
  let cache : Map[String, @types.Encoding] = {}
  for words in batch {
    let key = pretokenized_cache_key(words)
    match cache.get(key) {
      Some(enc) => encs.push(copy_encoding(enc))
      None => {
        let processed = self.process_single_raw(
          self.encode_pretokenized_raw(words),
          add_special_tokens~,
        )
        cache[key] = copy_encoding(processed)
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
/// Encode a batch of pre-tokenized word arrays with UTF-8 byte offsets.
pub fn Tokenizer::encode_pretokenized_batch_with_byte_offsets(
  self : Tokenizer,
  batch : Array[Array[String]],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] {
  let encs = self.encode_pretokenized_batch(batch, add_special_tokens~)
  let out : Array[@types.Encoding] = []
  for i in 0..<encs.length() {
    out.push(
      encoding_with_byte_offsets(
        encs[i],
        self.pretokenized_offset_text(batch[i]),
      ),
    )
  }
  out
}

///|
/// Encode a batch of pre-tokenized pairs, with per-call duplicate caching and
/// batch-level padding.
pub fn Tokenizer::encode_pretokenized_pair_batch(
  self : Tokenizer,
  batch : Array[(Array[String], Array[String])],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] {
  if batch.length() == 0 {
    return []
  }
  let encs : Array[@types.Encoding] = []
  let cache : Map[(String, String), @types.Encoding] = {}
  for p in batch {
    let key = (pretokenized_cache_key(p.0), pretokenized_cache_key(p.1))
    match cache.get(key) {
      Some(enc) => encs.push(copy_encoding(enc))
      None => {
        let enc = self.encode_pretokenized_pair_unpadded(
          p.0,
          p.1,
          add_special_tokens~,
        )
        cache[key] = copy_encoding(enc)
        encs.push(enc)
      }
    }
  }
  match self.padding {
    Some(pp) => pad_batch(encs, pp)
    None => encs
  }
}

///|
/// Encode a batch of pre-tokenized pairs with UTF-8 byte offsets.
pub fn Tokenizer::encode_pretokenized_pair_batch_with_byte_offsets(
  self : Tokenizer,
  batch : Array[(Array[String], Array[String])],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] {
  let encs = self.encode_pretokenized_pair_batch(batch, add_special_tokens~)
  let out : Array[@types.Encoding] = []
  for i in 0..<encs.length() {
    out.push(
      encoding_with_pair_byte_offsets(
        encs[i],
        self.pretokenized_offset_text(batch[i].0),
        self.pretokenized_offset_text(batch[i].1),
      ),
    )
  }
  out
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
/// Encode a batch of text pairs. This is the pair-input counterpart of
/// `encode_batch`: each tuple is `(sequence_a, sequence_b)`, truncation is
/// applied per pair, and BatchLongest padding is applied once across the whole
/// batch. Repeated pairs are copied from a small per-call cache.
pub fn Tokenizer::encode_pair_batch(
  self : Tokenizer,
  pairs : Array[(String, String)],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] {
  if pairs.length() == 0 {
    return []
  }
  let encs : Array[@types.Encoding] = []
  let cache : Map[(String, String), @types.Encoding] = {}
  for p in pairs {
    match cache.get(p) {
      Some(enc) => encs.push(copy_encoding(enc))
      None => {
        let enc = self.encode_pair_unpadded(p.0, p.1, add_special_tokens~)
        cache[p] = copy_encoding(enc)
        encs.push(enc)
      }
    }
  }
  match self.padding {
    Some(pp) => pad_batch(encs, pp)
    None => encs
  }
}

///|
/// Encode a batch of text pairs and return UTF-8 byte offsets for each
/// sequence, matching HF's default offset convention for pair inputs.
pub fn Tokenizer::encode_pair_batch_with_byte_offsets(
  self : Tokenizer,
  pairs : Array[(String, String)],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] {
  let encs = self.encode_pair_batch(pairs, add_special_tokens~)
  let out : Array[@types.Encoding] = []
  for i in 0..<encs.length() {
    out.push(encoding_with_pair_byte_offsets(encs[i], pairs[i].0, pairs[i].1))
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
  self.finalize_padding(
    self.encode_pair_unpadded(text_a, text_b, add_special_tokens~),
  )
}

///|
fn Tokenizer::encode_pair_unpadded(
  self : Tokenizer,
  text_a : String,
  text_b : String,
  add_special_tokens~ : Bool,
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
  processed
}

///|
fn Tokenizer::encode_pretokenized_pair_unpadded(
  self : Tokenizer,
  words_a : Array[String],
  words_b : Array[String],
  add_special_tokens~ : Bool,
) -> @types.Encoding {
  let a = self.encode_pretokenized_raw(words_a)
  let b = self.encode_pretokenized_raw(words_b)
  let (a, b) = match self.truncation_for_raw(pair=true, add_special_tokens~) {
    Some(tp) => truncate_pair_raw(a, Some(b), tp)
    None => (a, Some(b))
  }
  if add_special_tokens {
    match self.post_processor {
      Some(pp) => pp.process(a, b)
      None => concat_encodings(a, b.unwrap())
    }
  } else {
    concat_encodings(a, b.unwrap())
  }
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
// text (false). Public encode paths keep inline specials enabled; HF's
// `add_special_tokens` only controls post-processing.

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
      Special(info~, value~, offsets~) => emit(info.id, value, offsets, 0, None)
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
            Special(info~, value~, offsets~) =>
              emit(info.id, value, offsets, 0, None)
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

///|
/// Raw encoding for pre-tokenized input. Added/special tokens are still
/// extracted inside each provided word, but the tokenizer's pre-tokenizer stage
/// is skipped; each input word receives one word id before the model may split
/// ordinary spans into subword tokens.
fn Tokenizer::encode_pretokenized_raw(
  self : Tokenizer,
  words : Array[String],
) -> @types.Encoding {
  let ids : Array[Int] = []
  let tokens : Array[String] = []
  let type_ids : Array[Int] = []
  let offsets : Array[(Int, Int)] = []
  let special_tokens_mask : Array[Int] = []
  let attention_mask : Array[Int] = []
  let sequence_ids : Array[Int?] = []
  let word_ids : Array[Int?] = []
  let mut base = 0
  fn emit(
    id : Int,
    value : String,
    offs : (Int, Int),
    special : Int,
    word_id : Int,
  ) -> Unit {
    ids.push(id)
    tokens.push(value)
    type_ids.push(0)
    offsets.push(offs)
    special_tokens_mask.push(special)
    attention_mask.push(1)
    sequence_ids.push(Some(0))
    word_ids.push(Some(word_id))
  }
  for word_id, word in words {
    // Stage 1 mirrors normal encode: non-normalized added tokens are matched
    // before normalization, but offsets are relative to the synthetic joined
    // pre-tokenized string.
    for
      seg1 in self.added_vocabulary.extract_stage1_at(
        word,
        base~,
        keep_special=true,
      ) {
      match seg1 {
        Special(info~, value~, offsets~) =>
          emit(info.id, value, offsets, 0, word_id)
        Normal(text=raw, base_offset~) => {
          let normalized = self.normalize_pretokenized_word(raw)
          // Stage 2 mirrors normal encode for `normalized=true` added tokens.
          for
            seg2 in self.added_vocabulary.extract_stage2(
              normalized,
              base_offset,
              keep_special=true,
            ) {
            match seg2 {
              Special(info~, value~, offsets~) =>
                emit(info.id, value, offsets, 0, word_id)
              Normal(text=ntext, base_offset=base2) =>
                for t in self.model.tokenize(ntext, offset=base2) {
                  emit(t.id, t.value, t.offsets, 0, word_id)
                }
            }
          }
        }
      }
    }
    base = base + self.normalize_pretokenized_word(word).char_length()
    if word_id + 1 < words.length() {
      base = base + 1
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

///|
fn Tokenizer::normalize_pretokenized_word(
  self : Tokenizer,
  word : String,
) -> String {
  match self.normalizer {
    Some(nm) => nm.normalize(word)
    None => word
  }
}

///|
fn Tokenizer::pretokenized_offset_text(
  self : Tokenizer,
  words : Array[String],
) -> String {
  let sb = StringBuilder::new()
  for i, w in words {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string(self.normalize_pretokenized_word(w))
  }
  sb.to_string()
}

///|
fn pretokenized_cache_key(words : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i, w in words {
    if i > 0 {
      sb.write_char('\u{0}')
    }
    sb.write_string(w)
  }
  sb.to_string()
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
