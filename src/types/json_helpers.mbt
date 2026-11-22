// JSON access helpers shared across all component packages.
//
// HuggingFace tokenizer.json uses tagged objects like {"type": "BPE", ...}.
// These helpers read typed fields out of the underlying `Map[String, Json]`
// (the payload of `Json::Object`) with sane defaults, raising TokenizerError
// on shape mismatches.

///|
/// Extract the underlying object map, or raise.
pub fn as_object(
  j : Json,
  ctx : String,
) -> Map[String, Json] raise TokenizerError {
  match j {
    Object(obj) => obj
    _ => raise ParseError("\{ctx}: expected JSON object")
  }
}

///|
/// Extract the underlying array, or raise.
pub fn as_array(j : Json, ctx : String) -> Array[Json] raise TokenizerError {
  match j {
    Array(arr) => arr
    _ => raise ParseError("\{ctx}: expected JSON array")
  }
}

///|
/// Read the `"type"` tag of a tagged object.
pub fn get_type(
  obj : Map[String, Json],
  ctx : String,
) -> String raise TokenizerError {
  match obj.get("type") {
    Some(String(t)) => t
    _ => raise ParseError("\{ctx}: missing or non-string \"type\" field")
  }
}

///|
/// Optional string field.
pub fn get_str_opt(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
/// String field with a default.
pub fn get_str(
  obj : Map[String, Json],
  key : String,
  default~ : String,
) -> String {
  match obj.get(key) {
    Some(String(s)) => s
    _ => default
  }
}

///|
/// Bool field with a default.
pub fn get_bool(obj : Map[String, Json], key : String, default~ : Bool) -> Bool {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    _ => default
  }
}

///|
/// Bool field with a default that raises on a wrong JSON type. HF serde rejects
/// e.g. `"yes"` or `1` where a boolean is expected instead of silently using
/// the default; a missing key still yields the default.
pub fn get_bool_strict(
  obj : Map[String, Json],
  key : String,
  default~ : Bool,
  ctx : String,
) -> Bool raise TokenizerError {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ParseError("\{ctx}: missing or non-bool \"\{key}\" field")
    None => default
  }
}

///|
/// Int field with a default (JSON numbers are doubles).
pub fn get_int(
  obj : Map[String, Json],
  key : String,
  default~ : Int32,
) -> Int32 {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
    _ => default
  }
}

///|
/// Int field with a default that raises on a wrong JSON type, matching HF
/// serde's rejection of a string/bool where a number is expected.
pub fn get_int_strict(
  obj : Map[String, Json],
  key : String,
  default~ : Int32,
  ctx : String,
) -> Int32 raise TokenizerError {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
    Some(_) =>
      raise ParseError("\{ctx}: missing or non-number \"\{key}\" field")
    None => default
  }
}

///|
/// Optional int field.
pub fn get_int_opt(obj : Map[String, Json], key : String) -> Int32? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

///|
/// Optional int field that raises on a wrong JSON type; null/absent -> None.
pub fn get_optional_int_strict(
  obj : Map[String, Json],
  key : String,
  ctx : String,
) -> Int32? raise TokenizerError {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.to_int())
    Some(Null) | None => None
    Some(_) => raise ParseError("\{ctx}: non-number \"\{key}\" field")
  }
}

///|
/// String field with a default that raises on a wrong JSON type.
pub fn get_str_strict(
  obj : Map[String, Json],
  key : String,
  default~ : String,
  ctx : String,
) -> String raise TokenizerError {
  match obj.get(key) {
    Some(String(s)) => s
    Some(_) =>
      raise ParseError("\{ctx}: missing or non-string \"\{key}\" field")
    None => default
  }
}

///|
/// Optional string field that raises on a wrong JSON type; null/absent -> None.
pub fn get_optional_string_strict(
  obj : Map[String, Json],
  key : String,
  ctx : String,
) -> String? raise TokenizerError {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    Some(Null) | None => None
    Some(_) => raise ParseError("\{ctx}: non-string \"\{key}\" field")
  }
}

///|
/// Required string field; raises when absent or not a JSON string.
pub fn get_required_string(
  obj : Map[String, Json],
  key : String,
  ctx : String,
) -> String raise TokenizerError {
  match obj.get(key) {
    Some(String(s)) => s
    _ => raise ParseError("\{ctx}: missing or non-string \"\{key}\" field")
  }
}

///|
/// Required int field; raises when absent or not a JSON number.
pub fn get_required_int(
  obj : Map[String, Json],
  key : String,
  ctx : String,
) -> Int32 raise TokenizerError {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
    _ => raise ParseError("\{ctx}: missing or non-number \"\{key}\" field")
  }
}

///|
/// Optional floating-point field that raises on a wrong JSON type;
/// null/absent -> None.
pub fn get_optional_number_strict(
  obj : Map[String, Json],
  key : String,
  ctx : String,
) -> Double? raise TokenizerError {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n)
    Some(Null) | None => None
    Some(_) => raise ParseError("\{ctx}: non-number \"\{key}\" field")
  }
}

///|
/// Char field: takes the first code point of a single-char string.
pub fn get_char(obj : Map[String, Json], key : String, default~ : Char) -> Char {
  match obj.get(key) {
    Some(String(s)) =>
      match s.iter().next() {
        Some(c) => c
        None => default
      }
    _ => default
  }
}
