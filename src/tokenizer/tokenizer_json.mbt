///|
fn truncation_to_json(params : TruncationParams?) -> String {
  match params {
    None => "null"
    Some(tp) => {
      let sb = StringBuilder::new()
      sb.write_string("{\"max_length\":")
      sb.write_string(tp.max_length.to_string())
      sb.write_string(",\"stride\":")
      sb.write_string(tp.stride.to_string())
      sb.write_string(",\"strategy\":")
      write_json_string(sb, truncation_strategy_json(tp.strategy))
      sb.write_string(",\"direction\":")
      write_json_string(sb, truncation_direction_json(tp.direction))
      sb.write_char('}')
      sb.to_string()
    }
  }
}

///|
fn truncation_strategy_json(strategy : TruncationStrategy) -> String {
  match strategy {
    LongestFirst => "LongestFirst"
    OnlyFirst => "OnlyFirst"
    OnlySecond => "OnlySecond"
  }
}

///|
fn truncation_direction_json(direction : TruncationDirection) -> String {
  match direction {
    Left => "Left"
    Right => "Right"
  }
}

///|
fn padding_to_json(params : PaddingParams?) -> String {
  match params {
    None => "null"
    Some(pp) => {
      let sb = StringBuilder::new()
      sb.write_string("{\"strategy\":")
      match pp.strategy {
        BatchLongest => write_json_string(sb, "BatchLongest")
        Fixed(n) => {
          sb.write_string("{\"Fixed\":")
          sb.write_string(n.to_string())
          sb.write_char('}')
        }
      }
      sb.write_string(",\"direction\":")
      write_json_string(sb, padding_direction_json(pp.direction))
      sb.write_string(",\"pad_id\":")
      sb.write_string(pp.pad_id.to_string())
      sb.write_string(",\"pad_type_id\":")
      sb.write_string(pp.pad_type_id.to_string())
      sb.write_string(",\"pad_token\":")
      write_json_string(sb, pp.pad_token)
      match pp.pad_to_multiple_of {
        Some(n) => {
          sb.write_string(",\"pad_to_multiple_of\":")
          sb.write_string(n.to_string())
        }
        None => ()
      }
      sb.write_char('}')
      sb.to_string()
    }
  }
}

///|
fn padding_direction_json(direction : PaddingDirection) -> String {
  match direction {
    Left => "Left"
    Right => "Right"
  }
}

// Decode an optional component: absent key or JSON null -> None.

///|
fn[T] decode_opt(
  root : Map[String, Json],
  key : String,
  decode : (Json) -> T raise @types.TokenizerError,
) -> T? raise @types.TokenizerError {
  match root.get(key) {
    None | Some(Null) => None
    Some(j) => Some(decode(j))
  }
}

///|
fn parse_added_tokens(
  root : Map[String, Json],
) -> Array[AddedTokenInfo] raise @types.TokenizerError {
  let out : Array[AddedTokenInfo] = []
  let arr = match root.get("added_tokens") {
    Some(Array(a)) => a
    _ => return out
  }
  for entry in arr {
    let obj = @types.as_object(entry, "added_token")
    let special = get_added_bool(obj, "special")
    out.push({
      id: get_added_int(obj, "id"),
      content: get_added_string(obj, "content"),
      single_word: get_added_bool(obj, "single_word"),
      lstrip: get_added_bool(obj, "lstrip"),
      rstrip: get_added_bool(obj, "rstrip"),
      normalized: get_added_bool(obj, "normalized"),
      special,
    })
  }
  out
}

///|
fn get_added_int(
  obj : Map[String, Json],
  key : String,
) -> Int raise @types.TokenizerError {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
    _ =>
      raise @types.ParseError(
        "added_token: missing or non-number \"\{key}\" field",
      )
  }
}

///|
fn get_added_string(
  obj : Map[String, Json],
  key : String,
) -> String raise @types.TokenizerError {
  match obj.get(key) {
    Some(String(s)) => s
    _ =>
      raise @types.ParseError(
        "added_token: missing or non-string \"\{key}\" field",
      )
  }
}

///|
fn get_added_bool(
  obj : Map[String, Json],
  key : String,
) -> Bool raise @types.TokenizerError {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    Some(_) =>
      raise @types.ParseError(
        "added_token: missing or non-bool \"\{key}\" field",
      )
    None =>
      raise @types.ParseError(
        "added_token: missing or non-bool \"\{key}\" field",
      )
  }
}

///|
fn parse_truncation(j : Json) -> TruncationParams raise @types.TokenizerError {
  let obj = @types.as_object(j, "truncation")
  let direction = match
    get_tokenizer_string(
      obj,
      "direction",
      required=false,
      default="Right",
      "truncation",
    ) {
    "Left" => TruncationDirection::Left
    "Right" => TruncationDirection::Right
    other => raise @types.ParseError("invalid truncation direction: \{other}")
  }
  let strategy = match
    get_tokenizer_string(
      obj,
      "strategy",
      required=true,
      default="",
      "truncation",
    ) {
    "LongestFirst" => TruncationStrategy::LongestFirst
    "OnlyFirst" => TruncationStrategy::OnlyFirst
    "OnlySecond" => TruncationStrategy::OnlySecond
    other => raise @types.ParseError("invalid truncation strategy: \{other}")
  }
  {
    max_length: get_tokenizer_int(
      obj,
      "max_length",
      required=true,
      default=0,
      "truncation",
    ),
    stride: get_tokenizer_int(
      obj,
      "stride",
      required=true,
      default=0,
      "truncation",
    ),
    direction,
    strategy,
  }
}

///|
fn get_tokenizer_string(
  obj : Map[String, Json],
  key : String,
  required~ : Bool,
  default~ : String,
  ctx : String,
) -> String raise @types.TokenizerError {
  match obj.get(key) {
    Some(String(s)) => s
    Some(Null) | None =>
      if required {
        raise @types.ParseError(
          "\{ctx}: missing or non-string \"\{key}\" field",
        )
      } else {
        default
      }
    _ =>
      raise @types.ParseError("\{ctx}: missing or non-string \"\{key}\" field")
  }
}

///|
fn get_tokenizer_int(
  obj : Map[String, Json],
  key : String,
  required~ : Bool,
  default~ : Int,
  ctx : String,
) -> Int raise @types.TokenizerError {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
    Some(Null) | None =>
      if required {
        raise @types.ParseError(
          "\{ctx}: missing or non-number \"\{key}\" field",
        )
      } else {
        default
      }
    _ =>
      raise @types.ParseError("\{ctx}: missing or non-number \"\{key}\" field")
  }
}

///|
fn get_tokenizer_int_opt(
  obj : Map[String, Json],
  key : String,
  ctx : String,
) -> Int? raise @types.TokenizerError {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.to_int())
    Some(Null) | None => None
    _ =>
      raise @types.ParseError("\{ctx}: missing or non-number \"\{key}\" field")
  }
}

///|
fn parse_truncation_direction_hf(
  direction : String,
) -> TruncationDirection raise @types.TokenizerError {
  match direction.to_lower() {
    "left" => TruncationDirection::Left
    "right" => TruncationDirection::Right
    other => raise @types.ParseError("invalid truncation direction: \{other}")
  }
}

///|
fn parse_truncation_strategy_hf(
  strategy : String,
) -> TruncationStrategy raise @types.TokenizerError {
  match strategy.to_lower() {
    "longest_first" => TruncationStrategy::LongestFirst
    "only_first" => TruncationStrategy::OnlyFirst
    "only_second" => TruncationStrategy::OnlySecond
    other => raise @types.ParseError("invalid truncation strategy: \{other}")
  }
}

///|
fn parse_padding_strategy(
  obj : Map[String, Json],
) -> PaddingStrategy raise @types.TokenizerError {
  match obj.get("strategy") {
    Some(String("BatchLongest")) => BatchLongest
    Some(Object(o)) =>
      match o.get("Fixed") {
        Some(Number(n, ..)) => Fixed(n.to_int())
        _ => raise @types.ParseError("padding: invalid strategy")
      }
    _ => raise @types.ParseError("padding: missing or invalid strategy")
  }
}

///|
fn parse_padding_direction_hf(
  direction : String,
) -> PaddingDirection raise @types.TokenizerError {
  match direction.to_lower() {
    "left" => PaddingDirection::Left
    "right" => PaddingDirection::Right
    other => raise @types.ParseError("invalid padding direction: \{other}")
  }
}

///|
fn parse_padding(j : Json) -> PaddingParams raise @types.TokenizerError {
  let obj = @types.as_object(j, "padding")
  let direction = match
    get_tokenizer_string(obj, "direction", required=true, default="", "padding") {
    "Left" => PaddingDirection::Left
    "Right" => PaddingDirection::Right
    other => raise @types.ParseError("invalid padding direction: \{other}")
  }
  {
    strategy: parse_padding_strategy(obj),
    direction,
    pad_id: get_tokenizer_int(
      obj,
      "pad_id",
      required=true,
      default=0,
      "padding",
    ),
    pad_type_id: get_tokenizer_int(
      obj,
      "pad_type_id",
      required=true,
      default=0,
      "padding",
    ),
    pad_token: get_tokenizer_string(
      obj,
      "pad_token",
      required=true,
      default="",
      "padding",
    ),
    pad_to_multiple_of: get_tokenizer_int_opt(
      obj, "pad_to_multiple_of", "padding",
    ),
  }
}

///|
/// Vocabulary size of the underlying model.
pub fn Tokenizer::get_vocab_size(
  self : Tokenizer,
  with_added_tokens? : Bool = true,
) -> Int {
  self.get_vocab(with_added_tokens~).length()
}

///|
/// Python/property-style alias for `get_vocab_size`.
pub fn Tokenizer::vocab_size(
  self : Tokenizer,
  with_added_tokens? : Bool = true,
) -> Int {
  self.get_vocab_size(with_added_tokens~)
}

///|
/// Export vocabulary as `token -> id`; includes added tokens by default.
pub fn Tokenizer::get_vocab(
  self : Tokenizer,
  with_added_tokens? : Bool = true,
) -> Map[String, Int] {
  let vocab = self.model.get_vocab()
  if with_added_tokens {
    for kv in self.added_vocabulary.get_vocab().to_array() {
      vocab[kv.0] = kv.1
    }
  }
  vocab
}

///|
/// Python/property-style alias for `get_vocab`.
pub fn Tokenizer::vocab(
  self : Tokenizer,
  with_added_tokens? : Bool = true,
) -> Map[String, Int] {
  self.get_vocab(with_added_tokens~)
}

///|
/// Look up a token id by surface string (added vocabulary first, then model).
pub fn Tokenizer::token_to_id(self : Tokenizer, token : String) -> Int? {
  match self.added_vocabulary.token_to_id(token) {
    Some(id) => Some(id)
    None => self.model.token_to_id(token)
  }
}

///|
/// Look up a token surface by id (added vocabulary first, then model).
pub fn Tokenizer::id_to_token(self : Tokenizer, id : Int) -> String? {
  match self.added_vocabulary.id_to_token(id) {
    Some(t) => Some(t)
    None => self.model.id_to_token(id)
  }
}

///|
/// Python binding-friendly alias for `token_to_id` on a single token.
pub fn Tokenizer::convert_token_to_id(self : Tokenizer, token : String) -> Int? {
  self.token_to_id(token)
}

///|
/// Python binding-friendly alias for `id_to_token` on a single id.
pub fn Tokenizer::convert_id_to_token(self : Tokenizer, id : Int) -> String? {
  self.id_to_token(id)
}

///|
/// Python binding-friendly batch token-to-id conversion. Unknown tokens are kept
/// as `None`, matching the optional return shape of `token_to_id`.
pub fn Tokenizer::convert_tokens_to_ids(
  self : Tokenizer,
  tokens : Array[String],
) -> Array[Int?] {
  tokens.map(tok => self.token_to_id(tok))
}

///|
/// Python binding-friendly batch id-to-token conversion. Unknown ids are kept as
/// `None`, matching the optional return shape of `id_to_token`.
pub fn Tokenizer::convert_ids_to_tokens(
  self : Tokenizer,
  ids : Array[Int],
) -> Array[String?] {
  ids.map(id => self.id_to_token(id))
}

///|
/// Return a default Trainer appropriate for this tokenizer's model type (HF
/// `Model.get_trainer`). The returned trainer has default settings; callers
/// can override specific fields with builder methods before training.
pub fn Tokenizer::get_trainer(self : Tokenizer) -> Trainer {
  match self.model {
    @model.BPE(_) => Trainer::bpe()
    @model.WordPiece(_) => Trainer::wordpiece()
    @model.Unigram(_) => Trainer::unigram()
    @model.WordLevel(_) => Trainer::wordlevel()
  }
}

///|
/// Alias for `Tokenizer::get_trainer` with HF-style naming.
pub fn Tokenizer::default_trainer(self : Tokenizer) -> Trainer {
  self.get_trainer()
}
