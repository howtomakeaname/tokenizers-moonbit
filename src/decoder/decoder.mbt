// The `decoder` stage: token surfaces -> reconstructed text.
//
// P1 scope: enum + deserialization. `decode` behaviour lands in P4 (ByteLevel)
// and P5/P6 (WordPiece/Metaspace).

///|
pub enum Decoder {
  ByteLevel(add_prefix_space~ : Bool, trim_offsets~ : Bool, use_regex~ : Bool)
  WordPiece(prefix~ : String, cleanup~ : Bool)
  Metaspace(replacement~ : Char, prepend_scheme~ : String)
  BPEDecoder(suffix~ : String)
  Strip(content~ : Char, start~ : Int, stop~ : Int)
  Fuse
  Replace(pattern~ : String, content~ : String)
  // Reassemble <0xXX> byte tokens into UTF-8 text.
  ByteFallback
  // CTC decoder (speech models): dedup repeats, drop pad, delimiter -> space.
  CTC(pad_token~ : String, word_delimiter_token~ : String, cleanup~ : Bool)
  Sequence(Array[Decoder])
}

///|
/// JSON-backed component state used by thin binding layers.
pub struct DecoderState {
  json : String
} derive(Debug, Eq)

///|
pub fn DecoderState::new(json : String) -> DecoderState {
  { json, }
}

///|
/// Return the decoder family name used by thin binding layers.
pub fn Decoder::kind(self : Decoder) -> String {
  match self {
    ByteLevel(..) => "ByteLevel"
    WordPiece(..) => "WordPiece"
    Metaspace(..) => "Metaspace"
    BPEDecoder(..) => "BPEDecoder"
    Strip(..) => "Strip"
    Fuse => "Fuse"
    Replace(..) => "Replace"
    ByteFallback => "ByteFallback"
    CTC(..) => "CTC"
    Sequence(_) => "Sequence"
  }
}

///|
pub fn Decoder::get_state(
  self : Decoder,
) -> DecoderState raise @types.TokenizerError {
  { json: self.state_json() }
}

///|
pub fn Decoder::from_state(
  state : DecoderState,
) -> Decoder raise @types.TokenizerError {
  let parsed = @json.parse(state.json) catch {
    err => raise @types.ParseError("invalid decoder state: \{err}")
  }
  Decoder::from_json(parsed)
}

///|
pub fn Decoder::__getstate__(
  self : Decoder,
) -> DecoderState raise @types.TokenizerError {
  self.get_state()
}

///|
pub fn Decoder::__setstate__(
  state : DecoderState,
) -> Decoder raise @types.TokenizerError {
  Decoder::from_state(state)
}

///|
pub fn Decoder::__str__(self : Decoder) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
pub fn Decoder::__repr__(self : Decoder) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
fn Decoder::state_json(self : Decoder) -> String raise @types.TokenizerError {
  match self.to_json() {
    Some(json) => json
    None => raise @types.UnsupportedComponent("decoder has no serialized state")
  }
}

///|
pub fn Decoder::add_prefix_space(self : Decoder) -> Bool? {
  match self {
    ByteLevel(add_prefix_space~, ..) => Some(add_prefix_space)
    _ => None
  }
}

///|
pub fn Decoder::get_add_prefix_space(self : Decoder) -> Bool? {
  self.add_prefix_space()
}

///|
pub fn Decoder::trim_offsets(self : Decoder) -> Bool? {
  match self {
    ByteLevel(trim_offsets~, ..) => Some(trim_offsets)
    _ => None
  }
}

///|
pub fn Decoder::get_trim_offsets(self : Decoder) -> Bool? {
  self.trim_offsets()
}

///|
pub fn Decoder::use_regex(self : Decoder) -> Bool? {
  match self {
    ByteLevel(use_regex~, ..) => Some(use_regex)
    _ => None
  }
}

///|
pub fn Decoder::get_use_regex(self : Decoder) -> Bool? {
  self.use_regex()
}

///|
pub fn Decoder::prefix(self : Decoder) -> String? {
  match self {
    WordPiece(prefix~, ..) => Some(prefix)
    _ => None
  }
}

///|
pub fn Decoder::get_prefix(self : Decoder) -> String? {
  self.prefix()
}

///|
pub fn Decoder::cleanup(self : Decoder) -> Bool? {
  match self {
    WordPiece(cleanup~, ..) => Some(cleanup)
    CTC(cleanup~, ..) => Some(cleanup)
    _ => None
  }
}

///|
pub fn Decoder::get_cleanup(self : Decoder) -> Bool? {
  self.cleanup()
}

///|
pub fn Decoder::replacement(self : Decoder) -> Char? {
  match self {
    Metaspace(replacement~, ..) => Some(replacement)
    _ => None
  }
}

///|
pub fn Decoder::get_replacement(self : Decoder) -> Char? {
  self.replacement()
}

///|
pub fn Decoder::prepend_scheme(self : Decoder) -> String? {
  match self {
    Metaspace(prepend_scheme~, ..) => Some(prepend_scheme)
    _ => None
  }
}

///|
pub fn Decoder::get_prepend_scheme(self : Decoder) -> String? {
  self.prepend_scheme()
}

///|
pub fn Decoder::suffix(self : Decoder) -> String? {
  match self {
    BPEDecoder(suffix~) => Some(suffix)
    _ => None
  }
}

///|
pub fn Decoder::get_suffix(self : Decoder) -> String? {
  self.suffix()
}

///|
pub fn Decoder::content(self : Decoder) -> String? {
  match self {
    Strip(content~, ..) => Some(@common.char_string(content))
    Replace(content~, ..) => Some(content)
    _ => None
  }
}

///|
pub fn Decoder::get_content(self : Decoder) -> String? {
  self.content()
}

///|
pub fn Decoder::start(self : Decoder) -> Int? {
  match self {
    Strip(start~, ..) => Some(start)
    _ => None
  }
}

///|
pub fn Decoder::get_start(self : Decoder) -> Int? {
  self.start()
}

///|
pub fn Decoder::stop(self : Decoder) -> Int? {
  match self {
    Strip(stop~, ..) => Some(stop)
    _ => None
  }
}

///|
pub fn Decoder::get_stop(self : Decoder) -> Int? {
  self.stop()
}

///|
pub fn Decoder::pattern(self : Decoder) -> String? {
  match self {
    Replace(pattern~, ..) => Some(pattern)
    _ => None
  }
}

///|
pub fn Decoder::get_pattern(self : Decoder) -> String? {
  self.pattern()
}

///|
pub fn Decoder::pad_token(self : Decoder) -> String? {
  match self {
    CTC(pad_token~, ..) => Some(pad_token)
    _ => None
  }
}

///|
pub fn Decoder::get_pad_token(self : Decoder) -> String? {
  self.pad_token()
}

///|
pub fn Decoder::word_delimiter_token(self : Decoder) -> String? {
  match self {
    CTC(word_delimiter_token~, ..) => Some(word_delimiter_token)
    _ => None
  }
}

///|
pub fn Decoder::get_word_delimiter_token(self : Decoder) -> String? {
  self.word_delimiter_token()
}

///|
pub fn Decoder::decoders(self : Decoder) -> Array[Decoder] {
  match self {
    Sequence(steps) => steps.copy()
    _ => []
  }
}

///|
/// HF/Python getter alias for Sequence child decoders.
pub fn Decoder::get_decoders(self : Decoder) -> Array[Decoder] {
  self.decoders()
}

///|
pub fn Decoder::__len__(self : Decoder) -> Int {
  match self {
    Sequence(steps) => steps.length()
    _ => 0
  }
}

///|
pub fn Decoder::get_item(self : Decoder, index : Int) -> Decoder? {
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
pub fn Decoder::__getitem__(self : Decoder, index : Int) -> Decoder? {
  self.get_item(index)
}

///|
pub fn Decoder::replace(pattern : String, content : String) -> Decoder {
  Replace(pattern~, content~)
}

///|
pub fn Decoder::byte_level(
  add_prefix_space? : Bool = true,
  trim_offsets? : Bool = true,
  use_regex? : Bool = true,
) -> Decoder {
  ByteLevel(add_prefix_space~, trim_offsets~, use_regex~)
}

///|
pub fn Decoder::bpe_decoder(suffix? : String = "</w>") -> Decoder {
  BPEDecoder(suffix~)
}

///|
pub fn Decoder::metaspace(
  replacement? : Char = '▁',
  prepend_scheme? : String = "always",
) -> Decoder {
  Metaspace(replacement~, prepend_scheme~)
}

///|
pub fn Decoder::strip(content : Char, start : Int, stop : Int) -> Decoder {
  Strip(content~, start~, stop~)
}

///|
pub fn Decoder::fuse() -> Decoder {
  Fuse
}

///|
pub fn Decoder::sequence(decoders : Array[Decoder]) -> Decoder {
  Sequence(decoders)
}

///|
pub fn Decoder::byte_fallback() -> Decoder {
  ByteFallback
}

///|
pub fn Decoder::wordpiece(
  prefix? : String = "##",
  cleanup? : Bool = true,
) -> Decoder {
  WordPiece(prefix~, cleanup~)
}

///|
pub fn Decoder::ctc(
  pad_token? : String = "<pad>",
  word_delimiter_token? : String = "|",
  cleanup? : Bool = true,
) -> Decoder {
  CTC(pad_token~, word_delimiter_token~, cleanup~)
}

///|
/// Serialize decoders created through the typed/programmatic API.
pub fn Decoder::to_json(self : Decoder) -> String? {
  match self {
    ByteLevel(add_prefix_space~, trim_offsets~, use_regex~) =>
      Some(bytelevel_to_json(add_prefix_space, trim_offsets, use_regex))
    WordPiece(prefix~, cleanup~) => Some(wordpiece_to_json(prefix, cleanup))
    Metaspace(replacement~, prepend_scheme~) =>
      Some(metaspace_to_json(replacement, prepend_scheme))
    BPEDecoder(suffix~) => Some(bpe_decoder_to_json(suffix))
    Strip(content~, start~, stop~) => Some(strip_to_json(content, start, stop))
    Fuse => Some("{\"type\":\"Fuse\"}")
    Replace(pattern~, content~) => Some(replace_to_json(pattern, content))
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
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"WordPiece\",\"prefix\":")
  write_json_string(sb, prefix)
  sb.write_string(",\"cleanup\":")
  sb.write_string(bool_json(cleanup))
  sb.write_char('}')
  sb.to_string()
}

///|
fn metaspace_to_json(replacement : Char, prepend_scheme : String) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Metaspace\",\"replacement\":")
  write_json_char(sb, replacement)
  sb.write_string(",\"prepend_scheme\":")
  write_json_string(sb, prepend_scheme)
  sb.write_char('}')
  sb.to_string()
}

///|
fn bpe_decoder_to_json(suffix : String) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"BPEDecoder\",\"suffix\":")
  write_json_string(sb, suffix)
  sb.write_char('}')
  sb.to_string()
}

///|
fn strip_to_json(content : Char, start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
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
fn replace_to_json(pattern : String, content : String) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Replace\",\"pattern\":{\"String\":")
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
  let sb = StringBuilder::new()
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
  let sb = StringBuilder::new()
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
        add_prefix_space=@types.get_bool(obj, "add_prefix_space", default=true),
        trim_offsets=@types.get_bool(obj, "trim_offsets", default=true),
        use_regex=@types.get_bool(obj, "use_regex", default=true),
      )
    "WordPiece" =>
      WordPiece(
        prefix=@types.get_str(obj, "prefix", default="##"),
        cleanup=@types.get_bool(obj, "cleanup", default=true),
      )
    "Metaspace" =>
      Metaspace(
        replacement=@types.get_char(obj, "replacement", default='▁'),
        prepend_scheme=match @types.get_str_opt(obj, "prepend_scheme") {
          Some(s) => s
          None =>
            if @types.get_bool(obj, "add_prefix_space", default=true) {
              "always"
            } else {
              "never"
            }
        },
      )
    "BPEDecoder" =>
      BPEDecoder(suffix=@types.get_str(obj, "suffix", default="</w>"))
    "Fuse" => Fuse
    "ByteFallback" => ByteFallback
    "CTC" =>
      CTC(
        pad_token=@types.get_str(obj, "pad_token", default="<pad>"),
        word_delimiter_token=@types.get_str(
          obj,
          "word_delimiter_token",
          default="|",
        ),
        cleanup=@types.get_bool(obj, "cleanup", default=true),
      )
    "Strip" =>
      Strip(
        content=@types.get_char(obj, "content", default=' '),
        start=@types.get_int(obj, "start", default=0),
        stop=@types.get_int(obj, "stop", default=0),
      )
    "Replace" =>
      Replace(
        pattern=parse_pattern(obj),
        content=@types.get_str(obj, "content", default=""),
      )
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
fn parse_pattern(obj : Map[String, Json]) -> String {
  match obj.get("pattern") {
    Some(Object(p)) =>
      match p.get("String") {
        Some(String(s)) => s
        _ =>
          match p.get("Regex") {
            Some(String(s)) => s
            _ => ""
          }
      }
    Some(String(s)) => s
    _ => ""
  }
}
