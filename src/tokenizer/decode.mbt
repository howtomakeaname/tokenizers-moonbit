// decode: token ids -> reconstructed text.

/// Decode a list of token ids back into a string.
pub fn Tokenizer::decode(
  self : Tokenizer,
  ids : Array[Int],
  skip_special_tokens~ : Bool = true,
) -> String {
  let special_ids = self.special_id_set()
  let tokens : Array[String] = []
  for id in ids {
    if skip_special_tokens && special_ids.contains(id) {
      continue
    }
    match self.model.id_to_token(id) {
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

// Set of ids that are special/added tokens.
fn Tokenizer::special_id_set(self : Tokenizer) -> @set.Set[Int] {
  let s : @set.Set[Int] = @set.Set::new()
  for at in self.added_tokens {
    if at.special {
      s.add(at.id)
    }
  }
  s
}
