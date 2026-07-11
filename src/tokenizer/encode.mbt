// encode: text -> Encoding.
//
// Pipeline: normalize -> pre_tokenize -> model.tokenize each piece -> assemble
// a raw Encoding -> (optional) post-process to add special tokens / type_ids.

///|
/// HF-style text input sequence: either a raw string or an already
/// pre-tokenized word array. This lets callers use one `encode_input` API instead
/// of selecting among raw / pair / pre-tokenized method families manually.
pub enum TextInputSequence {
  Text(String)
  PreTokenized(Array[String])
} derive(Debug, Eq)

///|
/// HF-style unified encode input. `SingleInput` maps to `Tokenizer.encode` or
/// `encode_pretokenized`; `PairInput` maps to the corresponding pair variants.
pub enum EncodeInput {
  SingleInput(TextInputSequence)
  PairInput(TextInputSequence, TextInputSequence)
} derive(Debug, Eq)

///|
pub fn TextInputSequence::text(text : String) -> TextInputSequence {
  Text(text)
}

///|
pub fn TextInputSequence::pretokenized(
  words : Array[String],
) -> TextInputSequence {
  PreTokenized(words.copy())
}

///|
pub fn EncodeInput::single(text : String) -> EncodeInput {
  SingleInput(Text(text))
}

///|
pub fn EncodeInput::single_pretokenized(words : Array[String]) -> EncodeInput {
  SingleInput(PreTokenized(words.copy()))
}

///|
pub fn EncodeInput::pair(text_a : String, text_b : String) -> EncodeInput {
  PairInput(Text(text_a), Text(text_b))
}

///|
pub fn EncodeInput::pair_pretokenized(
  words_a : Array[String],
  words_b : Array[String],
) -> EncodeInput {
  PairInput(PreTokenized(words_a.copy()), PreTokenized(words_b.copy()))
}

///|
pub fn EncodeInput::mixed_pair(
  a : TextInputSequence,
  b : TextInputSequence,
) -> EncodeInput {
  PairInput(a, b)
}

///|
/// Encode a unified HF-style input value.
pub fn Tokenizer::encode_input(
  self : Tokenizer,
  input : EncodeInput,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  match input {
    SingleInput(seq) => self.encode_sequence(seq, add_special_tokens~)
    PairInput(a, b) => self.encode_sequence_pair(a, b, add_special_tokens~)
  }
}

///|
/// Fast counterpart of `encode_input`: metadata matches normal encode, offsets
/// are zeroed recursively.
pub fn Tokenizer::encode_input_fast(
  self : Tokenizer,
  input : EncodeInput,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  match input {
    SingleInput(seq) => self.encode_sequence_fast(seq, add_special_tokens~)
    PairInput(a, b) => self.encode_sequence_pair_fast(a, b, add_special_tokens~)
  }
}

///|
/// Python binding-friendly unified encode entry: pass one `TextInputSequence`
/// plus an optional pair instead of constructing `EncodeInput` manually. This
/// mirrors HF Python's `encode(sequence, pair=..., is_pretokenized=...)` shape in
/// a typed MoonBit form.
pub fn Tokenizer::encode_sequence_input(
  self : Tokenizer,
  sequence : TextInputSequence,
  pair? : TextInputSequence? = None,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  match pair {
    Some(second) =>
      self.encode_input(PairInput(sequence, second), add_special_tokens~)
    None => self.encode_input(SingleInput(sequence), add_special_tokens~)
  }
}

///|
/// Fast counterpart of `encode_sequence_input`; all offsets are zeroed while ids,
/// tokens and other metadata match the non-fast path.
pub fn Tokenizer::encode_sequence_input_fast(
  self : Tokenizer,
  sequence : TextInputSequence,
  pair? : TextInputSequence? = None,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  match pair {
    Some(second) =>
      self.encode_input_fast(PairInput(sequence, second), add_special_tokens~)
    None => self.encode_input_fast(SingleInput(sequence), add_special_tokens~)
  }
}

///|
/// Encode a batch of unified inputs with the same duplicate-cache and padding
/// semantics as the explicit batch APIs.
pub fn Tokenizer::encode_input_batch(
  self : Tokenizer,
  inputs : Array[EncodeInput],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  if inputs.length() == 0 {
    return []
  }
  let encs : Array[@types.Encoding] = []
  let cache : Map[String, @types.Encoding] = {}
  for input in inputs {
    let key = encode_input_cache_key(input)
    match cache.get(key) {
      Some(enc) => encs.push(copy_encoding(enc))
      None => {
        let enc = self.encode_input_unpadded(input, add_special_tokens~)
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
/// Python/Transformers-style alias for `encode_input_batch` over typed
/// `EncodeInput` values.
pub fn Tokenizer::batch_encode_plus(
  self : Tokenizer,
  inputs : Array[EncodeInput],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_input_batch(inputs, add_special_tokens~)
}

///|
pub fn Tokenizer::encode_input_batch_fast(
  self : Tokenizer,
  inputs : Array[EncodeInput],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  if inputs.length() == 0 {
    return []
  }
  let encs : Array[@types.Encoding] = []
  let cache : Map[String, @types.Encoding] = {}
  for input in inputs {
    let key = encode_input_cache_key(input)
    match cache.get(key) {
      Some(enc) => encs.push(copy_encoding(enc))
      None => {
        let enc = self.encode_input_unpadded_fast(input, add_special_tokens~)
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
/// Fast counterpart of `batch_encode_plus`.
pub fn Tokenizer::batch_encode_plus_fast(
  self : Tokenizer,
  inputs : Array[EncodeInput],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_input_batch_fast(inputs, add_special_tokens~)
}

///|
/// Async-compatible naming alias. The implementation is intentionally
/// synchronous today so it remains available on native/js/wasm/wasm-gc; callers
/// can migrate from HF async call sites without changing semantics.
pub fn Tokenizer::async_encode(
  self : Tokenizer,
  input : EncodeInput,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  self.encode_input(input, add_special_tokens~)
}

///|
pub fn Tokenizer::async_encode_fast(
  self : Tokenizer,
  input : EncodeInput,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  self.encode_input_fast(input, add_special_tokens~)
}

///|
pub fn Tokenizer::async_encode_batch(
  self : Tokenizer,
  inputs : Array[EncodeInput],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_input_batch(inputs, add_special_tokens~)
}

///|
pub fn Tokenizer::async_encode_batch_fast(
  self : Tokenizer,
  inputs : Array[EncodeInput],
  add_special_tokens? : Bool = true,
) -> Array[@types.Encoding] raise @types.TokenizerError {
  self.encode_input_batch_fast(inputs, add_special_tokens~)
}

///|
fn Tokenizer::encode_sequence(
  self : Tokenizer,
  seq : TextInputSequence,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  match seq {
    Text(text) => self.encode(text, add_special_tokens~)
    PreTokenized(words) => self.encode_pretokenized(words, add_special_tokens~)
  }
}

///|
fn Tokenizer::encode_sequence_fast(
  self : Tokenizer,
  seq : TextInputSequence,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  match seq {
    Text(text) => self.encode_fast(text, add_special_tokens~)
    PreTokenized(words) =>
      self.encode_pretokenized_fast(words, add_special_tokens~)
  }
}

///|
fn Tokenizer::encode_sequence_pair(
  self : Tokenizer,
  a : TextInputSequence,
  b : TextInputSequence,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  self.finalize_padding(
    self.encode_sequence_pair_unpadded(a, b, add_special_tokens~),
  )
}

///|
fn Tokenizer::encode_sequence_pair_fast(
  self : Tokenizer,
  a : TextInputSequence,
  b : TextInputSequence,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  self.finalize_padding(
    self.encode_sequence_pair_unpadded_fast(a, b, add_special_tokens~),
  )
}

///|
fn Tokenizer::encode_input_unpadded(
  self : Tokenizer,
  input : EncodeInput,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  match input {
    SingleInput(seq) =>
      self.process_single_input_unpadded(seq, add_special_tokens~)
    PairInput(a, b) =>
      self.encode_sequence_pair_unpadded(a, b, add_special_tokens~)
  }
}

///|
fn Tokenizer::encode_input_unpadded_fast(
  self : Tokenizer,
  input : EncodeInput,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  match input {
    SingleInput(seq) =>
      self.process_single_input_unpadded_fast(seq, add_special_tokens~)
    PairInput(a, b) =>
      self.encode_sequence_pair_unpadded_fast(a, b, add_special_tokens~)
  }
}

///|
fn Tokenizer::process_single_input_unpadded(
  self : Tokenizer,
  seq : TextInputSequence,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  match seq {
    Text(text) =>
      self.process_single_raw(
        self.encode_raw(text, keep_special=true),
        add_special_tokens~,
      )
    PreTokenized(words) =>
      self.process_single_raw(
        self.encode_pretokenized_raw(words),
        add_special_tokens~,
      )
  }
}

///|
fn Tokenizer::process_single_input_unpadded_fast(
  self : Tokenizer,
  seq : TextInputSequence,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  match seq {
    Text(text) =>
      self.process_single_raw(
        self.encode_raw_fast(text, keep_special=true),
        add_special_tokens~,
      )
    PreTokenized(words) =>
      self.process_single_raw(
        self.encode_pretokenized_raw_fast(words),
        add_special_tokens~,
      )
  }
}

///|
fn Tokenizer::encode_sequence_pair_unpadded(
  self : Tokenizer,
  a : TextInputSequence,
  b : TextInputSequence,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  match (a, b) {
    (Text(ta), Text(tb)) =>
      self.encode_pair_unpadded(ta, tb, add_special_tokens~)
    (PreTokenized(wa), PreTokenized(wb)) =>
      self.encode_pretokenized_pair_unpadded(wa, wb, add_special_tokens~)
    _ => {
      let raw_a = self.raw_from_sequence(a, track_offsets=true)
      let raw_b = self.raw_from_sequence(b, track_offsets=true)
      self.process_pair_raw(raw_a, raw_b, add_special_tokens~)
    }
  }
}

///|
fn Tokenizer::encode_sequence_pair_unpadded_fast(
  self : Tokenizer,
  a : TextInputSequence,
  b : TextInputSequence,
  add_special_tokens~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  match (a, b) {
    (Text(ta), Text(tb)) =>
      self.encode_pair_unpadded_fast(ta, tb, add_special_tokens~)
    (PreTokenized(wa), PreTokenized(wb)) =>
      self.encode_pretokenized_pair_unpadded_fast(wa, wb, add_special_tokens~)
    _ => {
      let raw_a = self.raw_from_sequence(a, track_offsets=false)
      let raw_b = self.raw_from_sequence(b, track_offsets=false)
      self.process_pair_raw(raw_a, raw_b, add_special_tokens~)
    }
  }
}

///|
fn Tokenizer::raw_from_sequence(
  self : Tokenizer,
  seq : TextInputSequence,
  track_offsets~ : Bool,
) -> @types.Encoding raise @types.TokenizerError {
  match seq {
    Text(text) => self.encode_raw_impl(text, keep_special=true, track_offsets~)
    PreTokenized(words) =>
      self.encode_pretokenized_raw_impl(words, track_offsets~)
  }
}

///|
fn Tokenizer::process_pair_raw(
  self : Tokenizer,
  a : @types.Encoding,
  b : @types.Encoding,
  add_special_tokens~ : Bool,
) -> @types.Encoding {
  let (a, b) = match self.truncation_for_raw(pair=true, add_special_tokens~) {
    Some(tp) => truncate_pair_raw(a, Some(b), tp)
    None => (a, Some(b))
  }
  self.apply_post_processor_pair(a, b.unwrap(), add_special_tokens~)
}

///|
fn encode_input_cache_key(input : EncodeInput) -> String {
  match input {
    SingleInput(seq) => "S:" + text_sequence_cache_key(seq)
    PairInput(a, b) =>
      "P:" + text_sequence_cache_key(a) + "\u{1F}" + text_sequence_cache_key(b)
  }
}

///|
fn text_sequence_cache_key(seq : TextInputSequence) -> String {
  match seq {
    Text(text) => "T:" + text
    PreTokenized(words) => "W:" + pretokenized_cache_key(words)
  }
}

///|
/// Encode a single text into an `Encoding`.
pub fn Tokenizer::encode(
  self : Tokenizer,
  text : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  // Special tokens present in the text are always recognized as single tokens;
  // add_special_tokens only controls whether post-processors inject new
  // specials. Non-special post-processing effects still run, matching HF.
  self.finalize_padding(
    self.process_single_raw(
      self.encode_raw(text, keep_special=true),
      add_special_tokens~,
    ),
  )
}

///|
/// Encode a single text without retaining offset information, mirroring HF's
/// fast encode path. Token ids, token values, masks, type ids, sequence ids and
/// word ids are identical to `encode`; offsets are zeroed recursively, including
/// overflow windows. This avoids model offset shifting on the hot path while
/// preserving the rest of the pipeline.
pub fn Tokenizer::encode_fast(
  self : Tokenizer,
  text : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  self.finalize_padding(
    self.process_single_raw(
      self.encode_raw_fast(text, keep_special=true),
      add_special_tokens~,
    ),
  )
}

///|
/// Encode with explicit custom component hooks. Supplied hooks are overlaid on
/// top of any hooks persisted with `with_component_hooks`; present callbacks
/// override the tokenizer's typed normalizer/pre-tokenizer for this call. Model,
/// added-vocabulary extraction, truncation, post-processing and padding remain
/// the tokenizer's normal pipeline.
pub fn Tokenizer::encode_with_hooks(
  self : Tokenizer,
  text : String,
  hooks : TokenizerComponentHooks,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  let effective_hooks = self.component_hooks.overlay(hooks)
  self.finalize_padding(
    self.process_single_raw(
      self.encode_raw_with_hooks_impl(
        text,
        effective_hooks,
        keep_special=true,
        track_offsets=true,
      ),
      add_special_tokens~,
    ),
  )
}

///|
/// Fast no-offset counterpart of `encode_with_hooks`.
pub fn Tokenizer::encode_with_hooks_fast(
  self : Tokenizer,
  text : String,
  hooks : TokenizerComponentHooks,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  let effective_hooks = self.component_hooks.overlay(hooks)
  self.finalize_padding(
    self.process_single_raw(
      self.encode_raw_with_hooks_impl(
        text,
        effective_hooks,
        keep_special=true,
        track_offsets=false,
      ),
      add_special_tokens~,
    ),
  )
}

///|
/// Python binding alias for `encode`; useful when exposing both raw-text and
/// unified `EncodeInput` entry points without overloading in the target FFI.
pub fn Tokenizer::encode_text(
  self : Tokenizer,
  text : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  self.encode(text, add_special_tokens~)
}

///|
/// Python binding alias for `encode_fast`.
pub fn Tokenizer::encode_text_fast(
  self : Tokenizer,
  text : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  self.encode_fast(text, add_special_tokens~)
}

///|
/// Encode a single text and return UTF-8 byte offsets, matching HF's default
/// Rust/Python offset convention more closely than MoonBit char offsets.
pub fn Tokenizer::encode_with_byte_offsets(
  self : Tokenizer,
  text : String,
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
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
) -> @types.Encoding raise @types.TokenizerError {
  self.finalize_padding(
    self.process_single_raw(
      self.encode_pretokenized_raw(words),
      add_special_tokens~,
    ),
  )
}

///|
/// Encode pre-tokenized words without retaining offsets. Mirrors
/// `encode_pretokenized` except every offset is `(0, 0)`.
pub fn Tokenizer::encode_pretokenized_fast(
  self : Tokenizer,
  words : Array[String],
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  self.finalize_padding(
    self.process_single_raw(
      self.encode_pretokenized_raw_fast(words),
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
) -> @types.Encoding raise @types.TokenizerError {
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
) -> @types.Encoding raise @types.TokenizerError {
  self.finalize_padding(
    self.encode_pretokenized_pair_unpadded(
      words_a,
      words_b,
      add_special_tokens~,
    ),
  )
}

///|
/// Encode a pre-tokenized pair without retaining offsets.
pub fn Tokenizer::encode_pretokenized_pair_fast(
  self : Tokenizer,
  words_a : Array[String],
  words_b : Array[String],
  add_special_tokens? : Bool = true,
) -> @types.Encoding raise @types.TokenizerError {
  self.finalize_padding(
    self.encode_pretokenized_pair_unpadded_fast(
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
) -> @types.Encoding raise @types.TokenizerError {
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
  self.apply_post_processor_single(raw, add_special_tokens~)
}

///|
fn Tokenizer::apply_post_processor_single(
  self : Tokenizer,
  raw : @types.Encoding,
  add_special_tokens~ : Bool,
) -> @types.Encoding {
  match self.post_processor {
    Some(pp) => pp.process(raw, None, add_special_tokens~)
    None => raw
  }
}

///|
fn Tokenizer::apply_post_processor_pair(
  self : Tokenizer,
  a : @types.Encoding,
  b : @types.Encoding,
  add_special_tokens~ : Bool,
) -> @types.Encoding {
  match self.post_processor {
    Some(pp) => pp.process(a, Some(b), add_special_tokens~)
    None => concat_encodings(a, b)
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
