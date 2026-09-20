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
        // Normalize this ordinary piece, keeping the normalized->original
        // alignment column (identity when a hook replaces the normalizer).
        let (normalized, align) = self.normalize_with_alignment(raw, hooks)
        // Convert a normalized-coordinate span of this segment back into
        // original-text coordinates (identity alignment keeps the previous
        // scalar arithmetic bit-for-bit).
        fn to_orig(
          base_offset : Int,
          align : Array[(Int, Int)],
          s : Int,
          e : Int,
        ) -> (Int, Int) {
          let (a, b) = @normalizer.expand_align(align, s, e)
          (base_offset + a, base_offset + b)
        }
        // Stage 2: split out normalized added tokens within it.
        for
          seg2 in self.added_vocabulary.extract_stage2(
            normalized,
            base_offset,
            keep_special~,
          ) {
          match seg2 {
            Special(info~, value~, offsets~) => {
              let orig = to_orig(
                base_offset,
                align,
                offsets.0 - base_offset,
                offsets.1 - base_offset,
              )
              emit(info.id, value, orig, 0, None)
            }
            Normal(text=ntext, base_offset=base2) => {
              let pieces = self.pre_tokenize_with_hook(ntext, base2, hooks)
              // ByteLevel and Metaspace rewrite pieces (byte->visible
              // chars, space->▁, prefix inserts); derive the piece origin
              // map so model-token spans land on input char coords. The
              // map MODEL is keyed on the pre-tokenizer kind — ByteLevel
              // expands per UTF-8 byte, Metaspace rewrites 1:1 per char —
              // never on length coincidences.
              let origin_kind : String? = match self.pre_tokenizer {
                Some(@pretokenizer.PreTokenizer::ByteLevel(..)) => Some("byte")
                Some(@pretokenizer.PreTokenizer::Metaspace(..)) => Some("char")
                Some(@pretokenizer.PreTokenizer::Sequence(steps)) => {
                  // a homogeneous Sequence keeps one model; a mix cannot be
                  // represented by a single map
                  let mut model : String? = None
                  for st in steps {
                    match st {
                      @pretokenizer.PreTokenizer::ByteLevel(..) =>
                        if model is None {
                          model = Some("byte")
                        } else if model != Some("byte") {
                          model = Some("mixed")
                        }
                      @pretokenizer.PreTokenizer::Metaspace(..) =>
                        if model is None {
                          model = Some("char")
                        } else if model != Some("char") {
                          model = Some("mixed")
                        }
                      _ => ()
                    }
                  }
                  if model is Some("mixed") {
                    None
                  } else {
                    model
                  }
                }
                _ => None
              }
              for piece in pieces {
                let word_id = next_word_id
                next_word_id = next_word_id + 1
                // Piece offsets are normalized-segment coordinates
                // (base2-included); model tokens are emitted piece-relative
                // and converted through the alignment column here.
                let norm_s = piece.offsets.0 - base_offset
                let norm_e = piece.offsets.1 - base_offset
                // ByteLevel pieces encode bytes as visible chars; map the
                // piece's visible-char indices back to input char indices.
                let bl_map = if origin_kind is Some(_) && track_offsets {
                  piece_origin_map(
                    origin_kind.unwrap(),
                    char_substring(normalized, norm_s, norm_e),
                    piece.value.char_length(),
                  )
                } else {
                  None
                }
                for t in self.model.tokenize(piece.value, offset=0) {
                  let rel = t.offsets
                  let orig = if track_offsets {
                    match bl_map {
                      Some(map) => {
                        // visible coords -> input char coords -> original
                        let n = map.length()
                        if rel.0 < n && rel.1 > rel.0 && rel.1 <= n {
                          let cs = map[rel.0]
                          let ce = map[rel.1 - 1] + 1
                          to_orig(base_offset, align, norm_s + cs, norm_s + ce)
                        } else {
                          to_orig(
                            base_offset,
                            align,
                            norm_s + rel.0,
                            norm_s + rel.1,
                          )
                        }
                      }
                      None =>
                        to_orig(
                          base_offset,
                          align,
                          norm_s + rel.0,
                          norm_s + rel.1,
                        )
                    }
                  } else {
                    (0, 0)
                  }
                  emit(t.id, t.value, orig, 0, Some(word_id))
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

///|
/// Normalize and also return the original-referential alignment column
/// (one [start, stop) char span per normalized char). Hook-supplied
/// normalizers have no alignment; the identity column is used, matching
/// the pre-alignment behavior.

///|
/// For a ByteLevel pre-tokenized piece, `piece.value` is the byte-level
/// visible encoding of the normalized substring it covers. This returns,
/// for each visible char of the value, the index of the input (normalized)
/// char it came from — multi-byte chars expand to several visible chars
/// that all map to the same input char. Returns None when the piece is not
/// a byte-level encoding of the substring (lengths do not add up).
fn piece_origin_map(
  kind : String,
  norm_sub : String,
  value_len : Int,
) -> Array[Int]? {
  // base map: per-UTF-8-byte (ByteLevel) or per-char (Metaspace 1:1
  // rewrite). A single prepended visible char (Ġ prefix space / ▁
  // prepend) attaches to the first input char's index.
  let base : Array[Int]? = if kind == "byte" {
    byte_map_of(norm_sub)
  } else {
    let n = norm_sub.char_length()
    let map : Array[Int] = []
    for i in 0..<n {
      map.push(i)
    }
    Some(map)
  }
  match base {
    Some(map) =>
      if map.length() == value_len {
        Some(map)
      } else if map.length() + 1 == value_len {
        Some([0, ..map])
      } else {
        None
      }
    None => None
  }
}

///|
/// Byte-level visible-char -> input-char map of a substring (one entry per
/// UTF-8 byte). None when the substring is empty.
fn byte_map_of(norm_sub : String) -> Array[Int]? {
  let chars = norm_sub.to_array()
  if chars.is_empty() {
    return None
  }
  let map : Array[Int] = []
  for i, c in chars {
    let b = @utf8.encode(c.to_string()).length()
    for _k in 0..<b {
      map.push(i)
    }
  }
  Some(map)
}

///|
/// Extract the substring of `text` in char range [s, e).
fn char_substring(text : String, s : Int, e : Int) -> String {
  let chars = text.to_array()
  let sb = StringBuilder()
  let stop = if e < chars.length() { e } else { chars.length() }
  let start = if s > 0 { s } else { 0 }
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

///|
fn Tokenizer::normalize_with_alignment(
  self : Tokenizer,
  text : String,
  hooks : TokenizerComponentHooks,
) -> (String, Array[(Int, Int)]) {
  match hooks.normalize {
    Some(f) => {
      let out = f(text)
      let align : Array[(Int, Int)] = []
      for i in 0..<text.char_length() {
        align.push((i, i + 1))
      }
      (out, align)
    }
    None =>
      match self.normalizer {
        Some(nm) => nm.normalize_aligned(text)
        None => {
          let align : Array[(Int, Int)] = []
          for i in 0..<text.char_length() {
            align.push((i, i + 1))
          }
          (text, align)
        }
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
  let sb = StringBuilder()
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
  let sb = StringBuilder()
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
