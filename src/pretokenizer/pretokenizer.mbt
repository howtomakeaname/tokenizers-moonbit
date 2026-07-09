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
/// JSON-backed component state used by thin binding layers.
pub struct PreTokenizerState {
  json : String
} derive(Debug, Eq)

///|
pub fn PreTokenizerState::new(json : String) -> PreTokenizerState {
  { json, }
}

///|
/// Return the pre-tokenizer family name used by thin binding layers.
pub fn PreTokenizer::kind(self : PreTokenizer) -> String {
  match self {
    ByteLevel(..) => "ByteLevel"
    Whitespace => "Whitespace"
    WhitespaceSplit => "WhitespaceSplit"
    Metaspace(..) => "Metaspace"
    Punctuation(..) => "Punctuation"
    Split(..) => "Split"
    BertPreTokenizer => "BertPreTokenizer"
    Digits(..) => "Digits"
    Delimiter(..) => "Delimiter"
    FixedLength(..) => "FixedLength"
    UnicodeScripts => "UnicodeScripts"
    Sequence(_) => "Sequence"
  }
}

///|
pub fn PreTokenizer::get_state(
  self : PreTokenizer,
) -> PreTokenizerState raise @types.TokenizerError {
  { json: self.state_json() }
}

///|
pub fn PreTokenizer::from_state(
  state : PreTokenizerState,
) -> PreTokenizer raise @types.TokenizerError {
  let parsed = @json.parse(state.json) catch {
    err => raise @types.ParseError("invalid pre-tokenizer state: \{err}")
  }
  PreTokenizer::from_json(parsed)
}

///|
pub fn PreTokenizer::__getstate__(
  self : PreTokenizer,
) -> PreTokenizerState raise @types.TokenizerError {
  self.get_state()
}

///|
pub fn PreTokenizer::__setstate__(
  state : PreTokenizerState,
) -> PreTokenizer raise @types.TokenizerError {
  PreTokenizer::from_state(state)
}

///|
pub fn PreTokenizer::__str__(
  self : PreTokenizer,
) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
pub fn PreTokenizer::__repr__(
  self : PreTokenizer,
) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
fn PreTokenizer::state_json(
  self : PreTokenizer,
) -> String raise @types.TokenizerError {
  match self.to_json() {
    Some(json) => json
    None =>
      raise @types.UnsupportedComponent("pre_tokenizer has no serialized state")
  }
}

///|
pub fn PreTokenizer::add_prefix_space(self : PreTokenizer) -> Bool? {
  match self {
    ByteLevel(add_prefix_space~, ..) => Some(add_prefix_space)
    _ => None
  }
}

///|
pub fn PreTokenizer::use_regex(self : PreTokenizer) -> Bool? {
  match self {
    ByteLevel(use_regex~, ..) => Some(use_regex)
    _ => None
  }
}

///|
pub fn PreTokenizer::trim_offsets(self : PreTokenizer) -> Bool? {
  match self {
    ByteLevel(trim_offsets~, ..) => Some(trim_offsets)
    _ => None
  }
}

///|
pub fn PreTokenizer::replacement(self : PreTokenizer) -> Char? {
  match self {
    Metaspace(replacement~, ..) => Some(replacement)
    _ => None
  }
}

///|
pub fn PreTokenizer::prepend_scheme(self : PreTokenizer) -> String? {
  match self {
    Metaspace(prepend_scheme~, ..) => Some(prepend_scheme)
    _ => None
  }
}

///|
pub fn PreTokenizer::split_enabled(self : PreTokenizer) -> Bool? {
  match self {
    Metaspace(split~, ..) => Some(split)
    _ => None
  }
}

///|
pub fn PreTokenizer::behavior(self : PreTokenizer) -> SplitBehavior? {
  match self {
    Punctuation(behavior~) => Some(behavior)
    Split(behavior~, ..) => Some(behavior)
    _ => None
  }
}

///|
pub fn PreTokenizer::pattern(self : PreTokenizer) -> String? {
  match self {
    Split(pattern~, ..) => Some(pattern)
    _ => None
  }
}

///|
pub fn PreTokenizer::invert(self : PreTokenizer) -> Bool? {
  match self {
    Split(invert~, ..) => Some(invert)
    _ => None
  }
}

///|
pub fn PreTokenizer::regex(self : PreTokenizer) -> Bool? {
  match self {
    Split(regex~, ..) => Some(regex)
    _ => None
  }
}

///|
pub fn PreTokenizer::individual_digits(self : PreTokenizer) -> Bool? {
  match self {
    Digits(individual_digits~) => Some(individual_digits)
    _ => None
  }
}

///|
pub fn PreTokenizer::delimiter(self : PreTokenizer) -> Char? {
  match self {
    Delimiter(delimiter~) => Some(delimiter)
    _ => None
  }
}

///|
pub fn PreTokenizer::length(self : PreTokenizer) -> Int? {
  match self {
    FixedLength(length~) => Some(length)
    _ => None
  }
}

///|
pub fn PreTokenizer::pre_tokenizers(self : PreTokenizer) -> Array[PreTokenizer] {
  match self {
    Sequence(steps) => steps.copy()
    _ => []
  }
}

///|
pub fn PreTokenizer::__len__(self : PreTokenizer) -> Int {
  match self {
    Sequence(steps) => steps.length()
    _ => 0
  }
}

///|
pub fn PreTokenizer::get_item(
  self : PreTokenizer,
  index : Int,
) -> PreTokenizer? {
  match self {
    Sequence(steps) =>
      if index >= 0 && index < steps.length() {
        Some(steps[index])
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn PreTokenizer::__getitem__(
  self : PreTokenizer,
  index : Int,
) -> PreTokenizer? {
  self.get_item(index)
}

///|
/// Public constructor for a WhitespaceSplit pre-tokenizer, used by higher-level
/// training helpers without exposing cross-package enum construction details.
pub fn PreTokenizer::whitespace_split() -> PreTokenizer {
  WhitespaceSplit
}

///|
pub fn PreTokenizer::whitespace() -> PreTokenizer {
  Whitespace
}

///|
pub fn PreTokenizer::bert_pre_tokenizer() -> PreTokenizer {
  BertPreTokenizer
}

///|
pub fn PreTokenizer::metaspace(
  replacement? : Char = '▁',
  prepend_scheme? : String = "always",
  split? : Bool = true,
) -> PreTokenizer {
  Metaspace(replacement~, prepend_scheme~, split~)
}

///|
pub fn PreTokenizer::punctuation(
  behavior? : SplitBehavior = Isolated,
) -> PreTokenizer {
  Punctuation(behavior~)
}

///|
pub fn PreTokenizer::digits(individual_digits? : Bool = false) -> PreTokenizer {
  Digits(individual_digits~)
}

///|
pub fn PreTokenizer::char_delimiter_split(delimiter : Char) -> PreTokenizer {
  Delimiter(delimiter~)
}

///|
pub fn PreTokenizer::fixed_length(length? : Int = 5) -> PreTokenizer {
  FixedLength(length~)
}

///|
pub fn PreTokenizer::unicode_scripts() -> PreTokenizer {
  UnicodeScripts
}

///|
pub fn PreTokenizer::sequence(
  pre_tokenizers : Array[PreTokenizer],
) -> PreTokenizer {
  Sequence(pre_tokenizers)
}

///|
/// Public constructor for GPT-2/RoBERTa style ByteLevel pre-tokenization.
pub fn PreTokenizer::byte_level(
  add_prefix_space? : Bool = true,
  use_regex? : Bool = true,
  trim_offsets? : Bool = true,
) -> PreTokenizer {
  ByteLevel(add_prefix_space~, use_regex~, trim_offsets~)
}

///|
pub fn SplitBehavior::removed() -> SplitBehavior {
  Removed
}

///|
pub fn SplitBehavior::isolated() -> SplitBehavior {
  Isolated
}

///|
pub fn SplitBehavior::contiguous() -> SplitBehavior {
  Contiguous
}

///|
pub fn SplitBehavior::merged_with_previous() -> SplitBehavior {
  MergedWithPrevious
}

///|
pub fn SplitBehavior::merged_with_next() -> SplitBehavior {
  MergedWithNext
}

///|
pub fn PreTokenizer::split(
  pattern : String,
  behavior : SplitBehavior,
  invert? : Bool = false,
  regex? : Bool = false,
) -> PreTokenizer {
  Split(pattern~, behavior~, invert~, regex~)
}

///|
/// Serialize simple pre-tokenizers created through the training API.
pub fn PreTokenizer::to_json(self : PreTokenizer) -> String? {
  match self {
    ByteLevel(add_prefix_space~, use_regex~, trim_offsets~) =>
      Some(bytelevel_to_json(add_prefix_space, use_regex, trim_offsets))
    WhitespaceSplit => Some("{\"type\":\"WhitespaceSplit\"}")
    Whitespace => Some("{\"type\":\"Whitespace\"}")
    BertPreTokenizer => Some("{\"type\":\"BertPreTokenizer\"}")
    Punctuation(behavior~) =>
      Some(behavior_component_to_json("Punctuation", behavior))
    Metaspace(replacement~, prepend_scheme~, split~) =>
      Some(metaspace_to_json(replacement, prepend_scheme, split))
    Split(pattern~, behavior~, invert~, regex~) =>
      Some(split_to_json(pattern, behavior, invert, regex))
    Digits(individual_digits~) => Some(digits_to_json(individual_digits))
    Delimiter(delimiter~) => Some(delimiter_to_json(delimiter))
    FixedLength(length~) => Some(fixed_length_to_json(length))
    UnicodeScripts => Some("{\"type\":\"UnicodeScripts\"}")
    Sequence(steps) => sequence_to_json(steps)
  }
}

///|
fn bytelevel_to_json(
  add_prefix_space : Bool,
  use_regex : Bool,
  trim_offsets : Bool,
) -> String {
  "{\"type\":\"ByteLevel\",\"add_prefix_space\":" +
  bool_json(add_prefix_space) +
  ",\"use_regex\":" +
  bool_json(use_regex) +
  ",\"trim_offsets\":" +
  bool_json(trim_offsets) +
  "}"
}

///|
fn behavior_component_to_json(ty : String, behavior : SplitBehavior) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":")
  write_json_string(sb, ty)
  sb.write_string(",\"behavior\":")
  write_json_string(sb, behavior_to_json(behavior))
  sb.write_char('}')
  sb.to_string()
}

///|
fn metaspace_to_json(
  replacement : Char,
  prepend_scheme : String,
  split : Bool,
) -> String {
  let sb = StringBuilder::new()
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
  sb.write_string(bool_json(invert))
  sb.write_char('}')
  sb.to_string()
}

///|
fn digits_to_json(individual_digits : Bool) -> String {
  "{\"type\":\"Digits\",\"individual_digits\":" +
  bool_json(individual_digits) +
  "}"
}

///|
fn delimiter_to_json(delimiter : Char) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Delimiter\",\"delimiter\":")
  write_json_char(sb, delimiter)
  sb.write_char('}')
  sb.to_string()
}

///|
fn fixed_length_to_json(length : Int) -> String {
  "{\"type\":\"FixedLength\",\"length\":" + length.to_string() + "}"
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
fn write_json_char(sb : StringBuilder, c : Char) -> Unit {
  sb.write_char('"')
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
  sb.write_char('"')
}

///|
fn bool_json(b : Bool) -> String {
  if b {
    "true"
  } else {
    "false"
  }
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
    "FixedLength" => parse_fixed_length(obj)
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
fn parse_fixed_length(
  obj : Map[String, Json],
) -> PreTokenizer raise @types.TokenizerError {
  let length = @types.get_int(obj, "length", default=5)
  if length <= 0 {
    raise @types.ParseError("FixedLength length must be positive")
  }
  FixedLength(length~)
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
