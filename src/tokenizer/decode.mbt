// decode: token ids -> reconstructed text.

///|
/// Stateful incremental decoder mirroring HuggingFace's `DecodeStream`.
///
/// MoonBit keeps the stream immutable from the caller's perspective: each
/// `step` returns the updated stream together with an optional newly available
/// text chunk.
pub struct DecodeStream {
  tokenizer : Tokenizer
  skip_special_tokens : Bool
  ids : Array[Int]
  prefix : String
  prefix_index : Int
}

///|
/// Decode a list of token ids back into a string.
pub fn Tokenizer::decode(
  self : Tokenizer,
  ids : Array[Int],
  skip_special_tokens? : Bool = true,
) -> String {
  self.decode_with_hooks(
    ids,
    TokenizerComponentHooks::empty(),
    skip_special_tokens~,
  )
}

///|
/// Decode with an explicit custom decoder hook. The hook receives token strings
/// after id lookup and special-token filtering. If no decode hook is supplied,
/// this delegates to the tokenizer's typed decoder or direct token concatenation,
/// matching `decode` exactly.
pub fn Tokenizer::decode_with_hooks(
  self : Tokenizer,
  ids : Array[Int],
  hooks : TokenizerComponentHooks,
  skip_special_tokens? : Bool = true,
) -> String {
  let tokens : Array[String] = []
  for id in ids {
    if skip_special_tokens && self.added_vocabulary.is_special_id(id) {
      continue
    }
    // Added-vocabulary tokens take priority over the model's vocab.
    match self.id_to_token(id) {
      Some(t) => tokens.push(t)
      None => () // unknown id: skip
    }
  }
  match hooks.decode {
    Some(f) => return f(tokens)
    None => ()
  }
  match self.decoder {
    Some(d) => d.decode(tokens)
    None => {
      // No decoder: join token surfaces directly.
      let sb = StringBuilder::new()
      for t in tokens {
        sb.write_string(t)
      }
      sb.to_string()
    }
  }
}

///|
/// Python binding alias for `decode` when exposing ids-specific method names.
pub fn Tokenizer::decode_ids(
  self : Tokenizer,
  ids : Array[Int],
  skip_special_tokens? : Bool = true,
) -> String {
  self.decode(ids, skip_special_tokens~)
}

///|
/// Decode a batch of token id sequences. This mirrors HF's `decode_batch` API;
/// execution is intentionally serial so it works on every MoonBit backend. A
/// small per-call cache avoids repeating decode work for duplicate id sequences,
/// which is common in batch evaluation and mirrors the encode_batch duplicate
/// cache used on the forward path.
pub fn Tokenizer::decode_batch(
  self : Tokenizer,
  batch : Array[Array[Int]],
  skip_special_tokens? : Bool = true,
) -> Array[String] {
  let out : Array[String] = []
  let cache : Map[String, String] = {}
  for ids in batch {
    let key = ids_key(ids)
    match cache.get(key) {
      Some(decoded) => out.push(decoded)
      None => {
        let decoded = self.decode(ids, skip_special_tokens~)
        cache[key] = decoded
        out.push(decoded)
      }
    }
  }
  out
}

///|
/// Python binding alias for `decode_batch`.
pub fn Tokenizer::batch_decode(
  self : Tokenizer,
  batch : Array[Array[Int]],
  skip_special_tokens? : Bool = true,
) -> Array[String] {
  self.decode_batch(batch, skip_special_tokens~)
}

///|
/// Python binding alias for `decode_batch` with explicit ids naming.
pub fn Tokenizer::decode_ids_batch(
  self : Tokenizer,
  batch : Array[Array[Int]],
  skip_special_tokens? : Bool = true,
) -> Array[String] {
  self.decode_batch(batch, skip_special_tokens~)
}

///|
/// Async-compatible naming alias for decode. It delegates to the deterministic
/// synchronous implementation on all MoonBit targets.
pub fn Tokenizer::async_decode(
  self : Tokenizer,
  ids : Array[Int],
  skip_special_tokens? : Bool = true,
) -> String {
  self.decode(ids, skip_special_tokens~)
}

///|
/// Async-compatible naming alias for batch decode. Preserves duplicate-sequence
/// caching and output order from `decode_batch`.
pub fn Tokenizer::async_decode_batch(
  self : Tokenizer,
  batch : Array[Array[Int]],
  skip_special_tokens? : Bool = true,
) -> Array[String] {
  self.decode_batch(batch, skip_special_tokens~)
}

///|
/// Create a stateful incremental decoder. This is useful for token-by-token LLM
/// streaming where decoding each id independently would lose decoder context
/// (for example ByteFallback or Strip/ByteLevel decoder state).
pub fn Tokenizer::decode_stream(
  self : Tokenizer,
  skip_special_tokens? : Bool = true,
) -> DecodeStream {
  { tokenizer: self, skip_special_tokens, ids: [], prefix: "", prefix_index: 0 }
}

///|
/// Feed one token id into the stream. Returns `(next_stream, chunk)`, where
/// `chunk` is `None` until the buffered ids decode to a valid text extension.
pub fn DecodeStream::step(
  self : DecodeStream,
  id : Int,
) -> (DecodeStream, String?) {
  let ids = self.ids.copy()
  let mut prefix = self.prefix
  let mut prefix_index = self.prefix_index
  if prefix == "" && ids.length() > 0 {
    let new_prefix = self.tokenizer.decode(
      ids,
      skip_special_tokens=self.skip_special_tokens,
    )
    if !ends_with_replacement_char(new_prefix) {
      prefix = new_prefix
      prefix_index = ids.length()
    }
  }

  ids.push(id)
  let decoded = self.tokenizer.decode(
    ids,
    skip_special_tokens=self.skip_special_tokens,
  )
  if char_len(decoded) > char_len(prefix) &&
    !ends_with_replacement_char(decoded) {
    let new_text = if starts_with_string(decoded, prefix) {
      suffix_after_prefix(decoded, prefix)
    } else {
      // HF returns an InvalidPrefix error here. The rest of this package's
      // decode APIs are non-throwing, so recover by emitting the valid decoded
      // string and resetting the rolling prefix from the retained ids.
      decoded
    }
    let new_prefix_index = ids.length() - prefix_index
    let new_ids = slice_ids(ids, prefix_index, ids.length())
    let new_prefix = self.tokenizer.decode(
      new_ids,
      skip_special_tokens=self.skip_special_tokens,
    )
    (
      {
        tokenizer: self.tokenizer,
        skip_special_tokens: self.skip_special_tokens,
        ids: new_ids,
        prefix: new_prefix,
        prefix_index: new_prefix_index,
      },
      Some(new_text),
    )
  } else {
    (
      {
        tokenizer: self.tokenizer,
        skip_special_tokens: self.skip_special_tokens,
        ids,
        prefix,
        prefix_index,
      },
      None,
    )
  }
}

///|
fn ids_key(ids : Array[Int]) -> String {
  let sb = StringBuilder::new()
  for id in ids {
    sb.write_string(id.to_string())
    sb.write_char(',')
  }
  sb.to_string()
}

///|
fn char_len(s : String) -> Int {
  s.to_array().length()
}

///|
fn ends_with_replacement_char(s : String) -> Bool {
  let chars = s.to_array()
  chars.length() > 0 && chars[chars.length() - 1] == '�'
}

///|
fn starts_with_string(s : String, prefix : String) -> Bool {
  let chars = s.to_array()
  let pre = prefix.to_array()
  if pre.length() > chars.length() {
    return false
  }
  for i in 0..<pre.length() {
    if chars[i] != pre[i] {
      return false
    }
  }
  true
}

///|
fn suffix_after_prefix(s : String, prefix : String) -> String {
  let chars = s.to_array()
  let start = prefix.to_array().length()
  let sb = StringBuilder::new()
  for i in start..<chars.length() {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn slice_ids(ids : Array[Int], start : Int, stop : Int) -> Array[Int] {
  let out : Array[Int] = []
  let lo = if start < 0 { 0 } else { start }
  let hi = if stop > ids.length() { ids.length() } else { stop }
  for i in lo..<hi {
    out.push(ids[i])
  }
  out
}
