// JSON access helpers shared across all component packages.
//
// HuggingFace tokenizer.json uses tagged objects like {"type": "BPE", ...}.
// These helpers read typed fields out of the underlying `Map[String, Json]`
// (the payload of `Json::Object`) with sane defaults, raising TokenizerError
// on shape mismatches.

/// Extract the underlying object map, or raise.
pub fn as_object(j : Json, ctx : String) -> Map[String, Json] raise TokenizerError {
  match j {
    Object(obj) => obj
    _ => raise ParseError("\{ctx}: expected JSON object")
  }
}

/// Extract the underlying array, or raise.
pub fn as_array(j : Json, ctx : String) -> Array[Json] raise TokenizerError {
  match j {
    Array(arr) => arr
    _ => raise ParseError("\{ctx}: expected JSON array")
  }
}

/// Read the `"type"` tag of a tagged object.
pub fn get_type(obj : Map[String, Json], ctx : String) -> String raise TokenizerError {
  match obj.get("type") {
    Some(String(t)) => t
    _ => raise ParseError("\{ctx}: missing or non-string \"type\" field")
  }
}

/// Optional string field.
pub fn get_str_opt(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

/// String field with a default.
pub fn get_str(obj : Map[String, Json], key : String, default~ : String) -> String {
  match obj.get(key) {
    Some(String(s)) => s
    _ => default
  }
}

/// Bool field with a default.
pub fn get_bool(obj : Map[String, Json], key : String, default~ : Bool) -> Bool {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    _ => default
  }
}

/// Int field with a default (JSON numbers are doubles).
pub fn get_int(obj : Map[String, Json], key : String, default~ : Int) -> Int {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
    _ => default
  }
}

/// Optional int field.
pub fn get_int_opt(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

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
