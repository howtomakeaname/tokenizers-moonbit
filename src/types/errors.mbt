///|
pub(all) suberror TokenizerError {
  /// The tokenizer.json could not be parsed or had an unexpected shape.
  ParseError(String)
  /// A normalizer/pre_tokenizer/model/decoder type that is not yet implemented.
  UnsupportedComponent(String)
  /// vocab / merges data was malformed.
  VocabError(String)
} derive(Debug)

///|
/// Stable high-level error category for Python binding exception mapping.
pub(all) enum TokenizerErrorKind {
  ParseKind
  UnsupportedComponentKind
  VocabKind
} derive(Debug, Eq)

///|
/// Classify a tokenizer error into a stable category so bindings can map it to
/// dedicated Python exception classes without parsing debug strings.
pub fn TokenizerError::kind(self : TokenizerError) -> TokenizerErrorKind {
  match self {
    ParseError(_) => ParseKind
    UnsupportedComponent(_) => UnsupportedComponentKind
    VocabError(_) => VocabKind
  }
}

///|
/// Extract the human-readable message from a tokenizer error.
pub fn TokenizerError::message(self : TokenizerError) -> String {
  match self {
    ParseError(msg) => msg
    UnsupportedComponent(msg) => msg
    VocabError(msg) => msg
  }
}

///|
/// Build an empty `Encoding`.
pub fn Encoding::empty() -> Encoding {
  {
    ids: [],
    type_ids: [],
    tokens: [],
    offsets: [],
    special_tokens_mask: [],
    attention_mask: [],
    sequence_ids: [],
    word_ids: [],
    overflowing: [],
  }
}

///|
fn encoding_slice(enc : Encoding, start : Int, stop : Int) -> Encoding {
  {
    ids: enc.ids[start:stop].to_owned(),
    type_ids: enc.type_ids[start:stop].to_owned(),
    tokens: enc.tokens[start:stop].to_owned(),
    offsets: enc.offsets[start:stop].to_owned(),
    special_tokens_mask: enc.special_tokens_mask[start:stop].to_owned(),
    attention_mask: enc.attention_mask[start:stop].to_owned(),
    sequence_ids: enc.sequence_ids[start:stop].to_owned(),
    word_ids: enc.word_ids[start:stop].to_owned(),
    overflowing: [],
  }
}

///|
fn concat_ints(a : Array[Int], b : Array[Int]) -> Array[Int] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
}

///|
fn concat_strings(a : Array[String], b : Array[String]) -> Array[String] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
}

///|
fn concat_offsets(
  a : Array[(Int, Int)],
  b : Array[(Int, Int)],
) -> Array[(Int, Int)] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
}

///|
fn concat_opt_ints(a : Array[Int?], b : Array[Int?]) -> Array[Int?] {
  let out = a.copy()
  for x in b {
    out.push(x)
  }
  out
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
fn write_control_escape(sb : StringBuilder, u : Int) -> Unit {
  let hex = "0123456789ABCDEF".to_array()
  sb.write_string("\\u00")
  sb.write_char(hex[u / 16 % 16])
  sb.write_char(hex[u % 16])
}
