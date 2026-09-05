///|
/// HF-style convenience alias for restoring special-token extraction.
pub fn Tokenizer::disable_encode_special_tokens(self : Tokenizer) -> Tokenizer {
  self.set_encode_special_tokens(false)
}

///|
pub fn Tokenizer::get_encode_special_tokens(self : Tokenizer) -> Bool {
  self.added_vocabulary.get_encode_special_tokens()
}

///|
/// Python/property-style alias for `get_encode_special_tokens`.
pub fn Tokenizer::encode_special_tokens(self : Tokenizer) -> Bool {
  self.get_encode_special_tokens()
}

///|
/// Return `id -> AddedToken` for all added/special tokens.
pub fn Tokenizer::get_added_tokens_decoder(
  self : Tokenizer,
) -> Map[Int, AddedToken] {
  self.added_vocabulary.get_added_tokens_decoder()
}

///|
/// Python/property-style alias for `get_added_tokens_decoder`.
pub fn Tokenizer::added_tokens_decoder(
  self : Tokenizer,
) -> Map[Int, AddedToken] {
  self.get_added_tokens_decoder()
}

///|
/// Return added tokens ordered by id. This mirrors Python binding-friendly
/// access to the added-token table without exposing map iteration order.
pub fn Tokenizer::get_added_tokens(self : Tokenizer) -> Array[AddedToken] {
  let pairs = self.get_added_tokens_decoder().to_array()
  pairs.sort_by(fn(a, b) { a.0.compare(b.0) })
  pairs.map(p => p.1)
}

///|
/// Python/property-style alias for `get_added_tokens`.
pub fn Tokenizer::added_tokens(self : Tokenizer) -> Array[AddedToken] {
  self.get_added_tokens()
}

///|
/// Number of added tokens currently registered. When `special_only=true`, count
/// only special added tokens.
pub fn Tokenizer::get_added_tokens_count(
  self : Tokenizer,
  special_only? : Bool = false,
) -> Int {
  let mut count = 0
  for kv in self.get_added_tokens_decoder().to_array() {
    if !special_only || kv.1.special {
      count = count + 1
    }
  }
  count
}

///|
/// Python/property-style alias for `get_added_tokens_count`.
pub fn Tokenizer::added_tokens_count(
  self : Tokenizer,
  special_only? : Bool = false,
) -> Int {
  self.get_added_tokens_count(special_only~)
}

///|
/// Return all special added token strings ordered by id.
pub fn Tokenizer::all_special_tokens(self : Tokenizer) -> Array[String] {
  let pairs = self.get_added_tokens_decoder().to_array()
  pairs.sort_by(fn(a, b) { a.0.compare(b.0) })
  let out : Array[String] = []
  for kv in pairs {
    if kv.1.special {
      out.push(kv.1.content)
    }
  }
  out
}

///|
/// HF/Python getter alias for `all_special_tokens`.
pub fn Tokenizer::get_all_special_tokens(self : Tokenizer) -> Array[String] {
  self.all_special_tokens()
}

///|
/// Return all special added token ids ordered by id.
pub fn Tokenizer::all_special_ids(self : Tokenizer) -> Array[Int] {
  let pairs = self.get_added_tokens_decoder().to_array()
  pairs.sort_by(fn(a, b) { a.0.compare(b.0) })
  let out : Array[Int] = []
  for kv in pairs {
    if kv.1.special {
      out.push(kv.0)
    }
  }
  out
}

///|
/// HF/Python getter alias for `all_special_ids`.
pub fn Tokenizer::get_all_special_ids(self : Tokenizer) -> Array[Int] {
  self.all_special_ids()
}

///|
/// Check whether a token string is registered as a special added token.
pub fn Tokenizer::is_special_token(self : Tokenizer, token : String) -> Bool {
  self.added_vocabulary.is_special_token(token)
}

///|
/// Number of special tokens the post-processor would add for a single or pair
/// input. Mirrors HF's `num_special_tokens_to_add` helper.
pub fn Tokenizer::num_special_tokens_to_add(
  self : Tokenizer,
  is_pair? : Bool = false,
) -> Int {
  match self.post_processor {
    Some(pp) => pp.added_tokens(pair=is_pair)
    None => 0
  }
}

///|
/// Apply this tokenizer's post-processor to already-built encodings. This is the
/// explicit counterpart of `encode(..., add_special_tokens=true)`.
pub fn Tokenizer::post_process(
  self : Tokenizer,
  encoding : @types.Encoding,
  pair? : @types.Encoding? = None,
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  let is_pair = pair is Some(_)
  let (encoding, pair) = match
    self.truncation_for_raw(pair=is_pair, add_special_tokens~) {
    Some(tp) => truncate_pair_raw(encoding, pair, tp)
    None => (encoding, pair)
  }
  let processed = match self.post_processor {
    Some(pp) => pp.process(encoding, pair, add_special_tokens~)
    None => default_post_process(encoding, pair)
  }
  self.finalize_padding(processed)
}

///|
fn default_post_process(
  encoding : @types.Encoding,
  pair : @types.Encoding?,
) -> @types.Encoding {
  match pair {
    Some(b) => concat_encodings(encoding, b)
    None => encoding
  }
}

///|
/// Add ordinary tokens to the tokenizer's added vocabulary. Existing model or
/// added-vocabulary tokens are not assigned new ids; new ids are allocated after
/// the current maximum vocabulary id. Returns the updated tokenizer.
pub fn Tokenizer::add_tokens(
  self : Tokenizer,
  tokens : Array[AddedToken],
) -> Tokenizer {
  self.add_tokens_with_count(tokens).0
}

///|
/// Add ordinary tokens and return `(tokenizer, number_of_new_registrations)`,
/// matching HF's `Tokenizer.add_tokens` count semantics while keeping MoonBit's
/// builder style convenient. Existing model tokens count the first time they
/// are registered as added tokens, but they keep their original model ids.
pub fn Tokenizer::add_tokens_with_count(
  self : Tokenizer,
  tokens : Array[AddedToken],
) -> (Tokenizer, Int) {
  self.add_tokens_impl(tokens, force_special=false)
}

///|
/// Convenience overload for adding plain string tokens.
pub fn Tokenizer::add_token_strings(
  self : Tokenizer,
  tokens : Array[String],
) -> Tokenizer {
  self.add_token_strings_with_count(tokens).0
}

///|
/// Convenience overload for adding plain string tokens with HF-style count.
pub fn Tokenizer::add_token_strings_with_count(
  self : Tokenizer,
  tokens : Array[String],
) -> (Tokenizer, Int) {
  self.add_tokens_with_count(tokens.map(t => AddedToken::new(t)))
}

///|
/// Add special tokens. They are inserted into the non-normalized trie so they
/// are recognized before normalization/pre-tokenization, like HF special added
/// tokens. Returns the updated tokenizer.
pub fn Tokenizer::add_special_tokens(
  self : Tokenizer,
  tokens : Array[AddedToken],
) -> Tokenizer {
  self.add_special_tokens_with_count(tokens).0
}

///|
/// Add special tokens and return `(tokenizer, number_of_new_registrations)`.
/// Existing model tokens count the first time they become special added tokens.
pub fn Tokenizer::add_special_tokens_with_count(
  self : Tokenizer,
  tokens : Array[AddedToken],
) -> (Tokenizer, Int) {
  self.add_tokens_impl(tokens, force_special=true)
}

///|
/// Convenience overload for adding plain string special tokens.
pub fn Tokenizer::add_special_token_strings(
  self : Tokenizer,
  tokens : Array[String],
) -> Tokenizer {
  self.add_special_token_strings_with_count(tokens).0
}

///|
/// Convenience overload for adding plain string special tokens with HF-style count.
pub fn Tokenizer::add_special_token_strings_with_count(
  self : Tokenizer,
  tokens : Array[String],
) -> (Tokenizer, Int) {
  self.add_special_tokens_with_count(tokens.map(AddedToken::special))
}

///|
fn Tokenizer::add_tokens_impl(
  self : Tokenizer,
  tokens : Array[AddedToken],
  force_special~ : Bool,
) -> (Tokenizer, Int) {
  if tokens.length() == 0 {
    return (self, 0)
  }
  let infos = self.added_vocabulary.to_infos()
  let existing = self.get_vocab(with_added_tokens=true)
  let seen : Map[String, Bool] = {}
  for kv in self.added_vocabulary.get_vocab().to_array() {
    seen[kv.0] = true
  }
  let mut next_id = max_vocab_id(existing) + 1
  let mut new_count = 0
  for tok in tokens {
    if tok.content.is_empty() {
      continue
    }
    match seen.get(tok.content) {
      Some(true) => continue
      _ => ()
    }
    let id = match self.model.token_to_id(tok.content) {
      Some(id) => id
      None => {
        let id = next_id
        next_id = next_id + 1
        id
      }
    }
    new_count = new_count + 1
    infos.push({
      id,
      content: tok.content,
      single_word: tok.single_word,
      lstrip: tok.lstrip,
      rstrip: tok.rstrip,
      normalized: if force_special {
        false
      } else {
        tok.normalized
      },
      special: tok.special || force_special,
    })
    seen[tok.content] = true
  }
  (
    {
      ..self,
      added_vocabulary: AddedVocabulary::new_with_encode_special_tokens(
        infos,
        self.added_vocabulary.get_encode_special_tokens(),
      ).with_normalizer(self.normalizer),
      source_json: None,
    },
    new_count,
  )
}

///|
fn max_vocab_id(vocab : Map[String, Int]) -> Int {
  let mut out = -1
  for kv in vocab.to_array() {
    if kv.1 > out {
      out = kv.1
    }
  }
  out
}

///|
fn added_tokens_to_json(tokens : Array[AddedTokenInfo]) -> String {
  let sb = StringBuilder::new()
  sb.write_char('[')
  for i in 0..<tokens.length() {
    if i > 0 {
      sb.write_char(',')
    }
    let t = tokens[i]
    sb.write_string("{\"id\":")
    sb.write_string(t.id.to_string())
    sb.write_string(",\"content\":")
    write_json_string(sb, t.content)
    sb.write_string(",\"single_word\":")
    sb.write_string(if t.single_word { "true" } else { "false" })
    sb.write_string(",\"lstrip\":")
    sb.write_string(if t.lstrip { "true" } else { "false" })
    sb.write_string(",\"rstrip\":")
    sb.write_string(if t.rstrip { "true" } else { "false" })
    sb.write_string(",\"normalized\":")
    sb.write_string(if t.normalized { "true" } else { "false" })
    sb.write_string(",\"special\":")
    sb.write_string(if t.special { "true" } else { "false" })
    sb.write_char('}')
  }
  sb.write_char(']')
  sb.to_string()
}

///|
fn write_json_string(sb : StringBuilder, s : String) -> Unit {
  sb.write_char('"')
  for c in s {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.write_char('"')
}

///|
fn write_repr_string(sb : StringBuilder, s : String) -> Unit {
  sb.write_char('"')
  for c in s {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ =>
        if c.to_int() < 0x20 {
          write_control_escape(sb, c.to_int())
        } else {
          sb.write_char(c)
        }
    }
  }
  sb.write_char('"')
}

///|
fn bool_json(v : Bool) -> String {
  if v {
    "true"
  } else {
    "false"
  }
}

///|
fn bool_repr(v : Bool) -> String {
  if v {
    "True"
  } else {
    "False"
  }
}

///|
fn write_control_escape(sb : StringBuilder, u : Int) -> Unit {
  let digits = "0123456789ABCDEF".to_array()
  sb.write_string("\\u00")
  sb.write_char(digits[u / 16 % 16])
  sb.write_char(digits[u % 16])
}
