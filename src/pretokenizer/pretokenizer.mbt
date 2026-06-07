// The `pre_tokenizer` stage: splits normalized text into word-like pieces
// before the model runs.
//
// P1 scope: enum + deserialization. `pre_tokenize` behaviour lands in P3
// (ByteLevel/GPT-2) and P5/P6/P7 (the rest).

///|
/// How a Split pre-tokenizer treats the matched delimiter.
pub enum SplitBehavior {
  Removed
  Isolated
  MergedWithPrevious
  MergedWithNext
  Contiguous
} derive(Eq, Debug)

///|
pub enum PreTokenizer {
  ByteLevel(add_prefix_space~ : Bool, use_regex~ : Bool, trim_offsets~ : Bool)
  Whitespace
  WhitespaceSplit
  Metaspace(replacement~ : Char, prepend_scheme~ : String, split~ : Bool)
  Punctuation(behavior~ : SplitBehavior)
  Split(
    pattern~ : String,
    behavior~ : SplitBehavior,
    invert~ : Bool,
    regex~ : Bool
  )
  BertPreTokenizer
  Digits(individual_digits~ : Bool)
  Delimiter(delimiter~ : Char)
  FixedLength(length~ : Int)
  UnicodeScripts
  Sequence(Array[PreTokenizer])
}

///|
/// Public constructor for a WhitespaceSplit pre-tokenizer, used by higher-level
/// training helpers without exposing cross-package enum construction details.
pub fn PreTokenizer::whitespace_split() -> PreTokenizer {
  WhitespaceSplit
}

///|
pub fn SplitBehavior::removed() -> SplitBehavior {
  Removed
}

///|
pub fn PreTokenizer::split(
  pattern : String,
  behavior : SplitBehavior,
  invert : Bool,
  regex : Bool,
) -> PreTokenizer {
  Split(pattern~, behavior~, invert~, regex~)
}

///|
/// Serialize simple pre-tokenizers created through the training API.
pub fn PreTokenizer::to_json(self : PreTokenizer) -> String? {
  match self {
    WhitespaceSplit => Some("{\"type\":\"WhitespaceSplit\"}")
    Whitespace => Some("{\"type\":\"Whitespace\"}")
    BertPreTokenizer => Some("{\"type\":\"BertPreTokenizer\"}")
    Split(pattern~, behavior~, invert~, regex~) =>
      Some(split_to_json(pattern, behavior, invert, regex))
    Sequence(steps) => sequence_to_json(steps)
    _ => None
  }
}

///|
fn split_to_json(
  pattern : String,
  behavior : SplitBehavior,
  invert : Bool,
  regex : Bool,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Split\",\"pattern\":{")
  if regex {
    sb.write_string("\"Regex\":")
  } else {
    sb.write_string("\"String\":")
  }
  write_json_string(sb, pattern)
  sb.write_string("},\"behavior\":")
  write_json_string(sb, behavior_to_json(behavior))
  sb.write_string(",\"invert\":")
  sb.write_string(if invert { "true" } else { "false" })
  sb.write_char('}')
  sb.to_string()
}

///|
fn sequence_to_json(steps : Array[PreTokenizer]) -> String? {
  let parts : Array[String] = []
  for step in steps {
    match step.to_json() {
      Some(json) => parts.push(json)
      None => return None
    }
  }
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Sequence\",\"pretokenizers\":[")
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
fn behavior_to_json(behavior : SplitBehavior) -> String {
  match behavior {
    Removed => "Removed"
    Isolated => "Isolated"
    MergedWithPrevious => "MergedWithPrevious"
    MergedWithNext => "MergedWithNext"
    Contiguous => "Contiguous"
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
  let digits = "0123456789ABCDEF".to_array()
  sb.write_string("\\u00")
  sb.write_char(digits[u / 16 % 16])
  sb.write_char(digits[u % 16])
}

///|
/// Parse a pre_tokenizer config object.
pub fn PreTokenizer::from_json(
  j : Json,
) -> PreTokenizer raise @types.TokenizerError {
  let obj = @types.as_object(j, "pre_tokenizer")
  let ty = @types.get_type(obj, "pre_tokenizer")
  match ty {
    "ByteLevel" =>
      ByteLevel(
        add_prefix_space=@types.get_bool(obj, "add_prefix_space", default=true),
        use_regex=@types.get_bool(obj, "use_regex", default=true),
        trim_offsets=@types.get_bool(obj, "trim_offsets", default=true),
      )
    "Whitespace" => Whitespace
    "WhitespaceSplit" => WhitespaceSplit
    "Punctuation" => Punctuation(behavior=parse_behavior(obj))
    "BertPreTokenizer" => BertPreTokenizer
    "Metaspace" =>
      Metaspace(
        replacement=@types.get_char(obj, "replacement", default='▁'),
        prepend_scheme=parse_prepend_scheme(obj),
        split=@types.get_bool(obj, "split", default=true),
      )
    "Digits" =>
      Digits(
        individual_digits=@types.get_bool(
          obj,
          "individual_digits",
          default=false,
        ),
      )
    "Delimiter" | "CharDelimiterSplit" =>
      Delimiter(delimiter=@types.get_char(obj, "delimiter", default=' '))
    "FixedLength" =>
      FixedLength(length=@types.get_int(obj, "length", default=5))
    "UnicodeScripts" => UnicodeScripts
    "Split" => {
      let (pattern, regex) = parse_pattern_info(obj)
      if regex && !is_supported_split_regex(pattern) {
        raise @types.UnsupportedComponent(
          "pre_tokenizer Split regex: \{pattern}",
        )
      }
      Split(
        pattern~,
        behavior=parse_behavior(obj),
        invert=@types.get_bool(obj, "invert", default=false),
        regex~,
      )
    }
    "Sequence" => {
      let arr = match obj.get("pretokenizers") {
        Some(Array(a)) => a
        _ =>
          raise @types.ParseError(
            "pre_tokenizer Sequence missing pretokenizers",
          )
      }
      Sequence(arr.map(x => PreTokenizer::from_json(x)))
    }
    other => raise @types.UnsupportedComponent("pre_tokenizer type: \{other}")
  }
}

///|
fn parse_pattern_info(obj : Map[String, Json]) -> (String, Bool) {
  match obj.get("pattern") {
    Some(Object(p)) =>
      match p.get("String") {
        Some(String(s)) => (s, false)
        _ =>
          match p.get("Regex") {
            Some(String(s)) => (s, true)
            _ => ("", true)
          }
      }
    Some(String(s)) => (s, true)
    _ => ("", true)
  }
}

///|
fn parse_behavior(obj : Map[String, Json]) -> SplitBehavior {
  match @types.get_str_opt(obj, "behavior") {
    Some("Removed") => Removed
    Some("Isolated") => Isolated
    Some("MergedWithPrevious") => MergedWithPrevious
    Some("MergedWithNext") => MergedWithNext
    Some("Contiguous") => Contiguous
    _ => Isolated
  }
}

// Metaspace prepend scheme: new configs use "prepend_scheme"
// ("always"/"never"/"first"); old configs use a bool "add_prefix_space".

///|
fn parse_prepend_scheme(obj : Map[String, Json]) -> String {
  match @types.get_str_opt(obj, "prepend_scheme") {
    Some(s) => s
    None =>
      if @types.get_bool(obj, "add_prefix_space", default=true) {
        "always"
      } else {
        "never"
      }
  }
}
