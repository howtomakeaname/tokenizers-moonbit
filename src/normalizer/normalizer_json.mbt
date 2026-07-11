///|
pub fn Normalizer::get_state(
  self : Normalizer,
) -> NormalizerState raise @types.TokenizerError {
  { json: self.state_json() }
}

///|
pub fn Normalizer::from_state(
  state : NormalizerState,
) -> Normalizer raise @types.TokenizerError {
  let parsed = @json.parse(state.json) catch {
    err => raise @types.ParseError("invalid normalizer state: \{err}")
  }
  Normalizer::from_json(parsed)
}

///|
pub fn Normalizer::__getstate__(
  self : Normalizer,
) -> NormalizerState raise @types.TokenizerError {
  self.get_state()
}

///|
pub fn Normalizer::__setstate__(
  state : NormalizerState,
) -> Normalizer raise @types.TokenizerError {
  Normalizer::from_state(state)
}

///|
pub fn Normalizer::__str__(
  self : Normalizer,
) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
pub fn Normalizer::__repr__(
  self : Normalizer,
) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
fn Normalizer::state_json(
  self : Normalizer,
) -> String raise @types.TokenizerError {
  match self.to_json() {
    Some(json) => json
    None =>
      raise @types.UnsupportedComponent("normalizer has no serialized state")
  }
}

///|
/// Serialize normalizers created through the typed/programmatic API.
pub fn Normalizer::to_json(self : Normalizer) -> String? {
  match self {
    NFC => Some("{\"type\":\"NFC\"}")
    NFD => Some("{\"type\":\"NFD\"}")
    NFKC => Some("{\"type\":\"NFKC\"}")
    NFKD => Some("{\"type\":\"NFKD\"}")
    Lowercase => Some("{\"type\":\"Lowercase\"}")
    Strip(left~, right~) => Some(strip_to_json(left, right))
    StripAccents => Some("{\"type\":\"StripAccents\"}")
    ByteLevel => Some("{\"type\":\"ByteLevel\"}")
    Replace(pattern~, content~) =>
      Some(replace_to_json(pattern, content, @common.RegexPattern))
    ReplaceString(pattern~, content~) =>
      Some(replace_to_json(pattern, content, @common.StringPattern))
    Prepend(prepend~) => Some(prepend_to_json(prepend))
    Nmt => Some("{\"type\":\"Nmt\"}")
    Precompiled => Some("{\"type\":\"Precompiled\"}")
    PrecompiledMap(..) => None
    BertNormalizer(
      clean_text~,
      handle_chinese_chars~,
      strip_accents~,
      lowercase~
    ) =>
      Some(
        bert_normalizer_to_json(
          clean_text, handle_chinese_chars, strip_accents, lowercase,
        ),
      )
    Sequence(steps) => normalizer_sequence_to_json(steps)
  }
}

///|
fn strip_to_json(left : Bool, right : Bool) -> String {
  "{\"type\":\"Strip\",\"strip_left\":" +
  bool_json(left) +
  ",\"strip_right\":" +
  bool_json(right) +
  "}"
}

///|
fn replace_to_json(
  pattern : String,
  content : String,
  pattern_kind : @common.PatternKind,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Replace\",\"pattern\":{")
  match pattern_kind {
    @common.StringPattern => sb.write_string("\"String\":")
    @common.RegexPattern => sb.write_string("\"Regex\":")
  }
  write_json_string(sb, pattern)
  sb.write_string("},\"content\":")
  write_json_string(sb, content)
  sb.write_char('}')
  sb.to_string()
}

///|
fn prepend_to_json(prepend : String) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Prepend\",\"prepend\":")
  write_json_string(sb, prepend)
  sb.write_char('}')
  sb.to_string()
}

///|
fn bert_normalizer_to_json(
  clean_text : Bool,
  handle_chinese_chars : Bool,
  strip_accents : Bool?,
  lowercase : Bool,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"BertNormalizer\",\"clean_text\":")
  sb.write_string(bool_json(clean_text))
  sb.write_string(",\"handle_chinese_chars\":")
  sb.write_string(bool_json(handle_chinese_chars))
  sb.write_string(",\"strip_accents\":")
  match strip_accents {
    Some(value) => sb.write_string(bool_json(value))
    None => sb.write_string("null")
  }
  sb.write_string(",\"lowercase\":")
  sb.write_string(bool_json(lowercase))
  sb.write_char('}')
  sb.to_string()
}

///|
fn normalizer_sequence_to_json(steps : Array[Normalizer]) -> String? {
  let parts : Array[String] = []
  for step in steps {
    match step.to_json() {
      Some(json) => parts.push(json)
      None => return None
    }
  }
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Sequence\",\"normalizers\":[")
  for i, part in parts {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_string(part)
  }
  sb.write_string("]}")
  Some(sb.to_string())
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
/// Parse a normalizer config object (may be JSON null -> None upstream).
pub fn Normalizer::from_json(
  j : Json,
) -> Normalizer raise @types.TokenizerError {
  let obj = @types.as_object(j, "normalizer")
  let ty = @types.get_type(obj, "normalizer")
  match ty {
    "NFC" => NFC
    "NFD" => NFD
    "NFKC" => NFKC
    "NFKD" => NFKD
    "Lowercase" => Lowercase
    "StripAccents" => StripAccents
    "ByteLevel" => ByteLevel
    "Strip" =>
      Strip(
        left=@types.get_bool(obj, "strip_left", default=true),
        right=@types.get_bool(obj, "strip_right", default=true),
      )
    "Replace" => {
      let (pattern, pattern_kind) = parse_pattern(obj)
      let content = @types.get_str(obj, "content", default="")
      match pattern_kind {
        @common.StringPattern => ReplaceString(pattern~, content~)
        @common.RegexPattern => Replace(pattern~, content~)
      }
    }
    "Prepend" => Prepend(prepend=@types.get_str(obj, "prepend", default=""))
    "Nmt" => Nmt
    "Precompiled" =>
      match obj.get("precompiled_charsmap") {
        Some(String(charsmap)) =>
          if charsmap.is_empty() {
            Precompiled
          } else {
            PrecompiledMap(data=parse_precompiled_charsmap(charsmap))
          }
        _ => Precompiled
      }
    "BertNormalizer" => {
      let lowercase = @types.get_bool(obj, "lowercase", default=true)
      let strip_accents = match obj.get("strip_accents") {
        Some(True) => Some(true)
        Some(False) => Some(false)
        _ => None
      }
      BertNormalizer(
        clean_text=@types.get_bool(obj, "clean_text", default=true),
        handle_chinese_chars=@types.get_bool(
          obj,
          "handle_chinese_chars",
          default=true,
        ),
        strip_accents~,
        lowercase~,
      )
    }
    "Sequence" => {
      let arr = match obj.get("normalizers") {
        Some(Array(a)) => a
        _ => raise @types.ParseError("normalizer Sequence missing normalizers")
      }
      Sequence(arr.map(x => Normalizer::from_json(x)))
    }
    other => raise @types.UnsupportedComponent("normalizer type: \{other}")
  }
}

///|
fn parse_precompiled_charsmap(
  charsmap : String,
) -> PrecompiledCharsMap raise @types.TokenizerError {
  let bytes = decode_base64(charsmap)
  guard read_le_u32(bytes, 0) is Some(trie_size) else {
    raise @types.ParseError("invalid precompiled_charsmap header")
  }
  if trie_size < 0 || trie_size % 4 != 0 || 4 + trie_size > bytes.length() {
    raise @types.ParseError("invalid precompiled_charsmap trie length")
  }
  let trie : Array[Int] = []
  let units = trie_size / 4
  for i in 0..<units {
    guard read_le_u32(bytes, 4 + i * 4) is Some(unit) else {
      raise @types.ParseError("invalid precompiled_charsmap trie unit")
    }
    trie.push(unit)
  }
  if trie.length() == 0 {
    raise @types.ParseError("invalid precompiled_charsmap empty trie")
  }
  let normalized : Array[Int] = []
  for i in (4 + trie_size)..<bytes.length() {
    normalized.push(bytes[i])
  }
  { trie, normalized }
}

///|
fn read_le_u32(bytes : Array[Int], offset : Int) -> Int? {
  if offset < 0 || offset + 4 > bytes.length() {
    return None
  }
  Some(
    bytes[offset] +
    bytes[offset + 1] * 256 +
    bytes[offset + 2] * 65536 +
    bytes[offset + 3] * 16777216,
  )
}

///|
fn decode_base64(s : String) -> Array[Int] raise @types.TokenizerError {
  let out : Array[Int] = []
  let mut acc = 0
  let mut bits = 0
  for c in s {
    if c == '=' {
      break
    }
    let v = base64_value(c)
    if v < 0 {
      if c == '\n' || c == '\r' || c == '\t' || c == ' ' {
        continue
      }
      raise @types.ParseError("invalid precompiled_charsmap base64")
    }
    acc = (acc << 6) | v
    bits = bits + 6
    while bits >= 8 {
      bits = bits - 8
      out.push((acc >> bits) & 0xFF)
    }
  }
  out
}

///|
fn base64_value(c : Char) -> Int {
  let u = c.to_int()
  if u >= 65 && u <= 90 {
    u - 65
  } else if u >= 97 && u <= 122 {
    u - 97 + 26
  } else if u >= 48 && u <= 57 {
    u - 48 + 52
  } else if c == '+' {
    62
  } else if c == '/' {
    63
  } else {
    -1
  }
}

// HF "pattern" can be {"String": "x"} or {"Regex": "x"}; keep both payload and
// tag so state and behavior do not conflate literal and regex patterns.

///|
fn parse_pattern(obj : Map[String, Json]) -> (String, @common.PatternKind) {
  match obj.get("pattern") {
    Some(Object(p)) =>
      match p.get("String") {
        Some(String(s)) => (s, @common.StringPattern)
        _ =>
          match p.get("Regex") {
            Some(String(s)) => (s, @common.RegexPattern)
            _ => ("", @common.StringPattern)
          }
      }
    Some(String(s)) => (s, @common.StringPattern)
    _ => ("", @common.StringPattern)
  }
}
