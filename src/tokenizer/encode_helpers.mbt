///|
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
) -> @types.Encoding raise @types.TokenizerError {
  self.encode_raw_impl(text, keep_special~, track_offsets=true)
}

///|
fn Tokenizer::encode_raw_fast(
  self : Tokenizer,
  text : String,
  keep_special~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  self.encode_raw_impl(text, keep_special~, track_offsets=false)
}

///|
fn Tokenizer::encode_raw_impl(
  self : Tokenizer,
  text : String,
  keep_special~ : Bool,
  track_offsets~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  self.encode_raw_with_hooks_impl(
    text,
    self.component_hooks,
    keep_special~,
    track_offsets~,
  )
}

///|
fn Tokenizer::encode_raw_with_hooks_impl(
  self : Tokenizer,
  text : String,
  hooks : TokenizerComponentHooks,
  keep_special~ : Bool,
  track_offsets~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
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
    offsets.push(if track_offsets { offs } else { (0, 0) })
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
        let normalized = self.normalize_with_hook(raw, hooks)
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
              let pieces = self.pre_tokenize_with_hook(ntext, base2, hooks)
              for piece in pieces {
                let word_id = next_word_id
                next_word_id = next_word_id + 1
                let model_offset = if track_offsets {
                  piece.offsets.0
                } else {
                  0
                }
                for t in self.model.tokenize(piece.value, offset=model_offset) {
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
fn Tokenizer::normalize_with_hook(
  self : Tokenizer,
  text : String,
  hooks : TokenizerComponentHooks,
) -> String {
  match hooks.normalize {
    Some(f) => f(text)
    None =>
      match self.normalizer {
        Some(nm) => nm.normalize(text)
        None => text
      }
  }
}

///|
fn Tokenizer::pre_tokenize_with_hook(
  self : Tokenizer,
  text : String,
  base_offset : Int,
  hooks : TokenizerComponentHooks,
) -> Array[@types.Split] {
  match hooks.pre_tokenize {
    Some(f) => f(text, base_offset)
    None =>
      match self.pre_tokenizer {
        Some(pt) => pt.pre_tokenize(text, base_offset~)
        None =>
          [
            {
              value: text,
              offsets: (base_offset, base_offset + text.char_length()),
            },
          ]
      }
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
) -> @types.Encoding raise @types.TokenizerError {
  self.encode_pretokenized_raw_impl(words, track_offsets=true)
}

///|
fn Tokenizer::encode_pretokenized_raw_fast(
  self : Tokenizer,
  words : Array[String],
) -> @types.Encoding raise @types.TokenizerError {
  self.encode_pretokenized_raw_impl(words, track_offsets=false)
}

///|
fn Tokenizer::encode_pretokenized_raw_impl(
  self : Tokenizer,
  words : Array[String],
  track_offsets~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
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
    offsets.push(if track_offsets { offs } else { (0, 0) })
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
              Normal(text=ntext, base_offset=base2) => {
                let model_offset = if track_offsets { base2 } else { 0 }
                for t in self.model.tokenize(ntext, offset=model_offset) {
                  emit(t.id, t.value, t.offsets, 0, word_id)
                }
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
