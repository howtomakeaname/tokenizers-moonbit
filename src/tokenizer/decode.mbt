// decode: token ids -> reconstructed text.

/// Decode a list of token ids back into a string.
pub fn Tokenizer::decode(
  self : Tokenizer,
  ids : Array[Int],
  skip_special_tokens~ : Bool = true,
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
