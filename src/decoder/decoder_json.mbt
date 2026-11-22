///|
pub fn Decoder::to_json(self : Decoder) -> String? {
  match self {
    ByteLevel(add_prefix_space~, trim_offsets~, use_regex~) =>
      Some(bytelevel_to_json(add_prefix_space, trim_offsets, use_regex))
    WordPiece(prefix~, cleanup~) => Some(wordpiece_to_json(prefix, cleanup))
    Metaspace(replacement~, prepend_scheme~, split~) =>
      Some(metaspace_to_json(replacement, prepend_scheme, split))
    BPEDecoder(suffix~) => Some(bpe_decoder_to_json(suffix))
    Strip(content~, start~, stop~) => Some(strip_to_json(content, start, stop))
    Fuse => Some("{\"type\":\"Fuse\"}")
    Replace(pattern~, content~) =>
      Some(replace_to_json(pattern, content, @common.RegexPattern))
    ReplaceString(pattern~, content~) =>
      Some(replace_to_json(pattern, content, @common.StringPattern))
    ByteFallback => Some("{\"type\":\"ByteFallback\"}")
    CTC(pad_token~, word_delimiter_token~, cleanup~) =>
      Some(ctc_to_json(pad_token, word_delimiter_token, cleanup))
    Sequence(steps) => decoder_sequence_to_json(steps)
  }
}

///|
fn bytelevel_to_json(
  add_prefix_space : Bool,
  trim_offsets : Bool,
  use_regex : Bool,
) -> String {
  "{\"type\":\"ByteLevel\",\"add_prefix_space\":" +
  bool_json(add_prefix_space) +
  ",\"trim_offsets\":" +
  bool_json(trim_offsets) +
  ",\"use_regex\":" +
  bool_json(use_regex) +
  "}"
}

///|
fn wordpiece_to_json(prefix : String, cleanup : Bool) -> String {
  let sb = StringBuilder()
  sb.write_string("{\"type\":\"WordPiece\",\"prefix\":")
  write_json_string(sb, prefix)
  sb.write_string(",\"cleanup\":")
  sb.write_string(bool_json(cleanup))
  sb.write_char('}')
  sb.to_string()
}

///|
fn metaspace_to_json(
  replacement : Char,
  prepend_scheme : String,
  split : Bool,
) -> String {
  let sb = StringBuilder()
  sb.write_string("{\"type\":\"Metaspace\",\"replacement\":")
  write_json_char(sb, replacement)
  sb.write_string(",\"prepend_scheme\":")
  write_json_string(sb, prepend_scheme)
  sb.write_string(",\"split\":")
  sb.write_string(bool_json(split))
  sb.write_char('}')
  sb.to_string()
}

///|
fn bpe_decoder_to_json(suffix : String) -> String {
  let sb = StringBuilder()
  sb.write_string("{\"type\":\"BPEDecoder\",\"suffix\":")
  write_json_string(sb, suffix)
  sb.write_char('}')
  sb.to_string()
}

///|
fn strip_to_json(content : Char, start : Int32, stop : Int32) -> String {
  let sb = StringBuilder()
  sb.write_string("{\"type\":\"Strip\",\"content\":")
  write_json_char(sb, content)
  sb.write_string(",\"start\":")
  sb.write_string(start.to_string())
  sb.write_string(",\"stop\":")
  sb.write_string(stop.to_string())
  sb.write_char('}')
  sb.to_string()
}

///|
fn replace_to_json(
  pattern : String,
  content : String,
  pattern_kind : @common.PatternKind,
) -> String {
  let sb = StringBuilder()
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
fn ctc_to_json(
  pad_token : String,
  word_delimiter_token : String,
  cleanup : Bool,
) -> String {
  let sb = StringBuilder()
  sb.write_string("{\"type\":\"CTC\",\"pad_token\":")
  write_json_string(sb, pad_token)
  sb.write_string(",\"word_delimiter_token\":")
  write_json_string(sb, word_delimiter_token)
  sb.write_string(",\"cleanup\":")
  sb.write_string(bool_json(cleanup))
  sb.write_char('}')
  sb.to_string()
}

///|
fn decoder_sequence_to_json(steps : Array[Decoder]) -> String? {
  let parts : Array[String] = []
  for step in steps {
    match step.to_json() {
      Some(json) => parts.push(json)
      None => return None
    }
  }
  let sb = StringBuilder()
  sb.write_string("{\"type\":\"Sequence\",\"decoders\":[")
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
fn write_json_char(sb : StringBuilder, c : Char) -> Unit {
  write_json_string(sb, @common.char_string(c))
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
/// Parse a decoder config object.
pub fn Decoder::from_json(j : Json) -> Decoder raise @types.TokenizerError {
  let obj = @types.as_object(j, "decoder")
  let ty = @types.get_type(obj, "decoder")
  match ty {
    "ByteLevel" =>
      ByteLevel(
        add_prefix_space=@types.get_bool_strict(
          obj,
          "add_prefix_space",
          default=true,
          "ByteLevel decoder",
        ),
        trim_offsets=@types.get_bool_strict(
          obj,
          "trim_offsets",
          default=true,
          "ByteLevel decoder",
        ),
        use_regex=@types.get_bool_strict(
          obj,
          "use_regex",
          default=true,
          "ByteLevel decoder",
        ),
      )
    "WordPiece" =>
      WordPiece(
        prefix=@types.get_str_strict(
          obj,
          "prefix",
          default="##",
          "WordPiece decoder",
        ),
        cleanup=@types.get_bool_strict(
          obj,
          "cleanup",
          default=true,
          "WordPiece decoder",
        ),
      )
    "Metaspace" =>
      Metaspace(
        replacement=@types.get_char(obj, "replacement", default='▁'),
        prepend_scheme=match @types.get_str_opt(obj, "prepend_scheme") {
          Some(s) => s
          None =>
            if @types.get_bool_strict(
                obj,
                "add_prefix_space",
                default=true,
                "Metaspace decoder",
              ) {
              "always"
            } else {
              "never"
            }
        },
        split=@types.get_bool_strict(
          obj,
          "split",
          default=true,
          "Metaspace decoder",
        ),
      )
    "BPEDecoder" =>
      BPEDecoder(
        suffix=@types.get_str_strict(
          obj,
          "suffix",
          default="</w>",
          "BPEDecoder",
        ),
      )
    "Fuse" => Fuse
    "ByteFallback" => ByteFallback
    "CTC" =>
      CTC(
        pad_token=@types.get_str_strict(
          obj,
          "pad_token",
          default="<pad>",
          "CTC decoder",
        ),
        word_delimiter_token=@types.get_str_strict(
          obj,
          "word_delimiter_token",
          default="|",
          "CTC decoder",
        ),
        cleanup=@types.get_bool_strict(
          obj,
          "cleanup",
          default=true,
          "CTC decoder",
        ),
      )
    "Strip" =>
      Strip(
        content=@types.get_char(obj, "content", default=' '),
        start=match @types.get_int_opt(obj, "left") {
          Some(v) => v
          None =>
            @types.get_int_strict(obj, "start", default=0, "Strip decoder")
        },
        stop=match @types.get_int_opt(obj, "right") {
          Some(v) => v
          None => @types.get_int_strict(obj, "stop", default=0, "Strip decoder")
        },
      )
    "Replace" => {
      let (pattern, pattern_kind) = parse_pattern(obj)
      let content = @types.get_str_strict(
        obj,
        "content",
        default="",
        "Replace decoder",
      )
      match pattern_kind {
        @common.StringPattern => ReplaceString(pattern~, content~)
        @common.RegexPattern => Replace(pattern~, content~)
      }
    }
    "Sequence" => {
      let arr = match obj.get("decoders") {
        Some(Array(a)) => a
        _ => raise @types.ParseError("decoder Sequence missing decoders")
      }
      Sequence(arr.map(x => Decoder::from_json(x)))
    }
    other => raise @types.UnsupportedComponent("decoder type: \{other}")
  }
}

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
