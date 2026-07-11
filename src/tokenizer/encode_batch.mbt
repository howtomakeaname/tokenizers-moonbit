///|
pub fn Tokenizer::encode_batch(
  self : Tokenizer,
  texts : Array[String],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
/// Encode a batch of texts without retaining offsets. Repeated inputs are still
/// cached per call and BatchLongest padding is applied once across the batch.
pub fn Tokenizer::encode_batch_fast(
  self : Tokenizer,
  texts : Array[String],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  if texts.length() == 0 {
    return []
  }
  let encs : Array[@types.Encoding] = []
  let cache : Map[String, @types.Encoding] = {}
  for t in texts {
    match cache.get(t) {
      Some(enc) => encs.push(copy_encoding(enc))
      None => {
        let processed = self.process_single_raw(
          self.encode_raw_fast(t, keep_special=true),
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
/// Python binding alias for raw-text batch encoding.
pub fn Tokenizer::encode_text_batch(
  self : Tokenizer,
  texts : Array[String],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_batch(texts, add_special_tokens~)
}

///|
/// Python binding alias for raw-text batch fast encoding.
pub fn Tokenizer::encode_text_batch_fast(
  self : Tokenizer,
  texts : Array[String],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_batch_fast(texts, add_special_tokens~)
}

///|
/// Compatibility entry point for callers that want an explicitly parallelizable
/// batch API. MoonBit targets do not yet expose one stable cross-backend worker
/// runtime, so this currently delegates to the deterministic serial batch path
/// with duplicate-input caching and preserves output order exactly.
pub fn Tokenizer::encode_batch_parallel(
  self : Tokenizer,
  texts : Array[String],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_batch(texts, add_special_tokens~)
}

///|
/// Stable-order counterpart of `encode_batch_parallel` for the no-offset fast
/// path.
pub fn Tokenizer::encode_batch_parallel_fast(
  self : Tokenizer,
  texts : Array[String],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_batch_fast(texts, add_special_tokens~)
}

///|
/// Encode a batch of pre-tokenized word arrays. Repeated word sequences are
/// copied from a per-call cache and BatchLongest padding is applied once across
/// the whole batch.
pub fn Tokenizer::encode_pretokenized_batch(
  self : Tokenizer,
  batch : Array[Array[String]],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
/// Encode a batch of pre-tokenized word arrays without retaining offsets.
pub fn Tokenizer::encode_pretokenized_batch_fast(
  self : Tokenizer,
  batch : Array[Array[String]],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
          self.encode_pretokenized_raw_fast(words),
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
pub fn Tokenizer::encode_pretokenized_batch_parallel(
  self : Tokenizer,
  batch : Array[Array[String]],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_pretokenized_batch(batch, add_special_tokens~)
}

///|
pub fn Tokenizer::encode_pretokenized_batch_parallel_fast(
  self : Tokenizer,
  batch : Array[Array[String]],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_pretokenized_batch_fast(batch, add_special_tokens~)
}

///|
/// Encode a batch of pre-tokenized word arrays with UTF-8 byte offsets.
pub fn Tokenizer::encode_pretokenized_batch_with_byte_offsets(
  self : Tokenizer,
  batch : Array[Array[String]],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
/// Encode a batch of pre-tokenized pairs without retaining offsets.
pub fn Tokenizer::encode_pretokenized_pair_batch_fast(
  self : Tokenizer,
  batch : Array[(Array[String], Array[String])],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
        let enc = self.encode_pretokenized_pair_unpadded_fast(
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
pub fn Tokenizer::encode_pretokenized_pair_batch_parallel(
  self : Tokenizer,
  batch : Array[(Array[String], Array[String])],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_pretokenized_pair_batch(batch, add_special_tokens~)
}

///|
pub fn Tokenizer::encode_pretokenized_pair_batch_parallel_fast(
  self : Tokenizer,
  batch : Array[(Array[String], Array[String])],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_pretokenized_pair_batch_fast(batch, add_special_tokens~)
}

///|
/// Encode a batch of pre-tokenized pairs with UTF-8 byte offsets.
pub fn Tokenizer::encode_pretokenized_pair_batch_with_byte_offsets(
  self : Tokenizer,
  batch : Array[(Array[String], Array[String])],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
/// Encode a batch of text pairs without retaining offsets.
pub fn Tokenizer::encode_pair_batch_fast(
  self : Tokenizer,
  pairs : Array[(String, String)],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  if pairs.length() == 0 {
    return []
  }
  let encs : Array[@types.Encoding] = []
  let cache : Map[(String, String), @types.Encoding] = {}
  for p in pairs {
    match cache.get(p) {
      Some(enc) => encs.push(copy_encoding(enc))
      None => {
        let enc = self.encode_pair_unpadded_fast(p.0, p.1, add_special_tokens~)
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
pub fn Tokenizer::encode_pair_batch_parallel(
  self : Tokenizer,
  pairs : Array[(String, String)],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_pair_batch(pairs, add_special_tokens~)
}

///|
pub fn Tokenizer::encode_pair_batch_parallel_fast(
  self : Tokenizer,
  pairs : Array[(String, String)],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_pair_batch_fast(pairs, add_special_tokens~)
}

///|
/// Encode a batch of text pairs and return UTF-8 byte offsets for each
/// sequence, matching HF's default offset convention for pair inputs.
pub fn Tokenizer::encode_pair_batch_with_byte_offsets(
  self : Tokenizer,
  pairs : Array[(String, String)],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
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
) -> @types.Encoding raise @types.TokenizerError {
  self.finalize_padding(
    self.encode_pair_unpadded(text_a, text_b, add_special_tokens~),
  )
}

///|
/// Encode a pair without retaining offsets.
pub fn Tokenizer::encode_pair_fast(
  self : Tokenizer,
  text_a : String,
  text_b : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  self.finalize_padding(
    self.encode_pair_unpadded_fast(text_a, text_b, add_special_tokens~),
  )
}

///|
/// Python/FFI-friendly alias that accepts an optional pair in one method name.
pub fn Tokenizer::encode_plus(
  self : Tokenizer,
  text : String,
  pair? : String? = None,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  match pair {
    Some(text_b) => self.encode_pair(text, text_b, add_special_tokens~)
    None => self.encode(text, add_special_tokens~)
  }
}

///|
/// Fast counterpart of `encode_plus`.
pub fn Tokenizer::encode_plus_fast(
  self : Tokenizer,
  text : String,
  pair? : String? = None,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  match pair {
    Some(text_b) => self.encode_pair_fast(text, text_b, add_special_tokens~)
    None => self.encode_fast(text, add_special_tokens~)
  }
}

///|
fn Tokenizer::encode_pair_unpadded(
  self : Tokenizer,
  text_a : String,
  text_b : String,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  let a = self.encode_raw(text_a, keep_special=true)
  let b = self.encode_raw(text_b, keep_special=true)
  let (a, b) = match self.truncation_for_raw(pair=true, add_special_tokens~) {
    Some(tp) => truncate_pair_raw(a, Some(b), tp)
    None => (a, Some(b))
  }
  self.apply_post_processor_pair(a, b.unwrap(), add_special_tokens~)
}

///|
fn Tokenizer::encode_pair_unpadded_fast(
  self : Tokenizer,
  text_a : String,
  text_b : String,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  let a = self.encode_raw_fast(text_a, keep_special=true)
  let b = self.encode_raw_fast(text_b, keep_special=true)
  let (a, b) = match self.truncation_for_raw(pair=true, add_special_tokens~) {
    Some(tp) => truncate_pair_raw(a, Some(b), tp)
    None => (a, Some(b))
  }
  self.apply_post_processor_pair(a, b.unwrap(), add_special_tokens~)
}

///|
fn Tokenizer::encode_pretokenized_pair_unpadded(
  self : Tokenizer,
  words_a : Array[String],
  words_b : Array[String],
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  let a = self.encode_pretokenized_raw(words_a)
  let b = self.encode_pretokenized_raw(words_b)
  let (a, b) = match self.truncation_for_raw(pair=true, add_special_tokens~) {
    Some(tp) => truncate_pair_raw(a, Some(b), tp)
    None => (a, Some(b))
  }
  self.apply_post_processor_pair(a, b.unwrap(), add_special_tokens~)
}

///|
fn Tokenizer::encode_pretokenized_pair_unpadded_fast(
  self : Tokenizer,
  words_a : Array[String],
  words_b : Array[String],
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  let a = self.encode_pretokenized_raw_fast(words_a)
  let b = self.encode_pretokenized_raw_fast(words_b)
  let (a, b) = match self.truncation_for_raw(pair=true, add_special_tokens~) {
    Some(tp) => truncate_pair_raw(a, Some(b), tp)
    None => (a, Some(b))
  }
  self.apply_post_processor_pair(a, b.unwrap(), add_special_tokens~)
}

///|
/// Encode a pair and return UTF-8 byte offsets for each sequence. Special and
/// padding tokens keep `(0, 0)` offsets.
pub fn Tokenizer::encode_pair_with_byte_offsets(
  self : Tokenizer,
  text_a : String,
  text_b : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  let enc = self.encode_pair(text_a, text_b, add_special_tokens~)
  encoding_with_pair_byte_offsets(enc, text_a, text_b)
}

///|
/// Convert an existing single-sequence encoding's char offsets to UTF-8 byte
/// offsets using the original input text.
