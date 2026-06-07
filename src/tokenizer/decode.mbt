// decode: token ids -> reconstructed text.

///|
/// Decode a list of token ids back into a string.
pub fn Tokenizer::decode(
  self : Tokenizer,
  ids : Array[Int],
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
fn ids_key(ids : Array[Int]) -> String {
  let sb = StringBuilder::new()
  for id in ids {
    sb.write_string(id.to_string())
    sb.write_char(',')
  }
  sb.to_string()
}
