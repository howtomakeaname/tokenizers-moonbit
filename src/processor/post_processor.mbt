// The `post_processor` stage: adds special tokens (e.g. [CLS]/[SEP], <s>/</s>)
// and sets type_ids after the model produces tokens.
//
// P1 scope: enum + deserialization. `process` behaviour lands in P7.

///|
/// One piece of a processing template: either a reference to an input sequence
/// (A or B) or a literal special token, each tagged with a type_id.
pub enum Piece {
  SequenceRef(id~ : String, type_id~ : Int)
  SpecialTokenRef(id~ : String, type_id~ : Int)
} derive(Debug, Eq)

///|
pub fn Piece::from_tuple(
  t : (String, String, Int),
) -> Piece raise @types.TokenizerError {
  match t.0 {
    "SequenceRef" => SequenceRef(id=t.1, type_id=t.2)
    "SpecialTokenRef" => SpecialTokenRef(id=t.1, type_id=t.2)
    other => raise @types.ParseError("unknown template piece kind: \{other}")
  }
}

///|
pub fn Piece::as_tuple(self : Piece) -> (String, String, Int) {
  match self {
    SequenceRef(id~, type_id~) => ("SequenceRef", id, type_id)
    SpecialTokenRef(id~, type_id~) => ("SpecialTokenRef", id, type_id)
  }
}

///|
pub fn Piece::kind(self : Piece) -> String {
  self.as_tuple().0
}

///|
pub fn Piece::get_kind(self : Piece) -> String {
  self.kind()
}

///|
pub fn Piece::id(self : Piece) -> String {
  self.as_tuple().1
}

///|
pub fn Piece::get_id(self : Piece) -> String {
  self.id()
}

///|
pub fn Piece::type_id(self : Piece) -> Int {
  self.as_tuple().2
}

///|
pub fn Piece::get_type_id(self : Piece) -> Int {
  self.type_id()
}

///|
pub fn Piece::__str__(self : Piece) -> String {
  self.id()
}

///|
pub fn Piece::__repr__(self : Piece) -> String {
  let sb = StringBuilder::new()
  sb.write_string("Piece(kind=")
  write_repr_string(sb, self.kind())
  sb.write_string(", id=")
  write_repr_string(sb, self.id())
  sb.write_string(", type_id=")
  sb.write_string(self.type_id().to_string())
  sb.write_char(')')
  sb.to_string()
}

///|
/// A special token definition: its surface and the ids/tokens it expands to.
pub struct SpecialToken {
  id : String
  ids : Array[Int]
  tokens : Array[String]
} derive(Debug, Eq)

///|
/// Programmatic constructor for a TemplateProcessing special token. HF supports
/// special tokens that expand to more than one id/token; keep both arrays and
/// let processors expand them during post-processing.
pub fn SpecialToken::new(
  id : String,
  ids : Array[Int],
  tokens : Array[String],
) -> SpecialToken {
  { id, ids: ids.copy(), tokens: tokens.copy() }
}

///|
pub fn SpecialToken::from_tuple(
  t : (String, Array[Int], Array[String]),
) -> SpecialToken {
  SpecialToken::new(t.0, t.1, t.2)
}

///|
pub fn SpecialToken::as_tuple(
  self : SpecialToken,
) -> (String, Array[Int], Array[String]) {
  (self.id, self.ids.copy(), self.tokens.copy())
}

///|
pub fn SpecialToken::get_id(self : SpecialToken) -> String {
  self.id
}

///|
pub fn SpecialToken::id(self : SpecialToken) -> String {
  self.get_id()
}

///|
pub fn SpecialToken::get_ids(self : SpecialToken) -> Array[Int] {
  self.ids.copy()
}

///|
pub fn SpecialToken::ids(self : SpecialToken) -> Array[Int] {
  self.get_ids()
}

///|
pub fn SpecialToken::get_tokens(self : SpecialToken) -> Array[String] {
  self.tokens.copy()
}

///|
pub fn SpecialToken::tokens(self : SpecialToken) -> Array[String] {
  self.get_tokens()
}

///|
pub fn SpecialToken::__str__(self : SpecialToken) -> String {
  self.id
}

///|
pub fn SpecialToken::__repr__(self : SpecialToken) -> String {
  let sb = StringBuilder::new()
  sb.write_string("SpecialToken(id=")
  write_repr_string(sb, self.id)
  sb.write_string(", ids=")
  write_int_array(sb, self.ids)
  sb.write_string(", tokens=")
  write_string_array(sb, self.tokens)
  sb.write_char(')')
  sb.to_string()
}

///|
pub enum PostProcessor {
  TemplateProcessing(
    single~ : Array[Piece],
    pair~ : Array[Piece],
    special_tokens~ : Map[String, SpecialToken]
  )
  BertProcessing(sep~ : (String, Int), cls~ : (String, Int))
  RobertaProcessing(
    sep~ : (String, Int),
    cls~ : (String, Int),
    trim_offsets~ : Bool,
    add_prefix_space~ : Bool
  )
  ByteLevel(add_prefix_space~ : Bool, trim_offsets~ : Bool, use_regex~ : Bool)
  Sequence(Array[PostProcessor])
}

///|
/// JSON-backed component state used by thin binding layers.
pub struct PostProcessorState {
  json : String
} derive(Debug, Eq)

///|
pub fn PostProcessorState::new(json : String) -> PostProcessorState {
  { json, }
}

///|
/// Return the post-processor family name used by thin binding layers.
pub fn PostProcessor::kind(self : PostProcessor) -> String {
  match self {
    TemplateProcessing(..) => "TemplateProcessing"
    BertProcessing(..) => "BertProcessing"
    RobertaProcessing(..) => "RobertaProcessing"
    ByteLevel(..) => "ByteLevel"
    Sequence(_) => "Sequence"
  }
}

///|
pub fn PostProcessor::get_state(
  self : PostProcessor,
) -> PostProcessorState raise @types.TokenizerError {
  { json: self.state_json() }
}

///|
pub fn PostProcessor::from_state(
  state : PostProcessorState,
) -> PostProcessor raise @types.TokenizerError {
  let parsed = @json.parse(state.json) catch {
    err => raise @types.ParseError("invalid post-processor state: \{err}")
  }
  PostProcessor::from_json(parsed)
}

///|
pub fn PostProcessor::__getstate__(
  self : PostProcessor,
) -> PostProcessorState raise @types.TokenizerError {
  self.get_state()
}

///|
pub fn PostProcessor::__setstate__(
  state : PostProcessorState,
) -> PostProcessor raise @types.TokenizerError {
  PostProcessor::from_state(state)
}

///|
pub fn PostProcessor::__str__(
  self : PostProcessor,
) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
pub fn PostProcessor::__repr__(
  self : PostProcessor,
) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
fn PostProcessor::state_json(
  self : PostProcessor,
) -> String raise @types.TokenizerError {
  match self.to_json() {
    Some(json) => json
    None =>
      raise @types.UnsupportedComponent(
        "post_processor has no serialized state",
      )
  }
}

///|
pub fn PostProcessor::sep(self : PostProcessor) -> (String, Int)? {
  match self {
    BertProcessing(sep~, ..) => Some(sep)
    RobertaProcessing(sep~, ..) => Some(sep)
    _ => None
  }
}

///|
pub fn PostProcessor::get_sep(self : PostProcessor) -> (String, Int)? {
  self.sep()
}

///|
pub fn PostProcessor::cls(self : PostProcessor) -> (String, Int)? {
  match self {
    BertProcessing(cls~, ..) => Some(cls)
    RobertaProcessing(cls~, ..) => Some(cls)
    _ => None
  }
}

///|
pub fn PostProcessor::get_cls(self : PostProcessor) -> (String, Int)? {
  self.cls()
}

///|
pub fn PostProcessor::trim_offsets(self : PostProcessor) -> Bool? {
  match self {
    RobertaProcessing(trim_offsets~, ..) => Some(trim_offsets)
    ByteLevel(trim_offsets~, ..) => Some(trim_offsets)
    _ => None
  }
}

///|
pub fn PostProcessor::get_trim_offsets(self : PostProcessor) -> Bool? {
  self.trim_offsets()
}

///|
pub fn PostProcessor::add_prefix_space(self : PostProcessor) -> Bool? {
  match self {
    RobertaProcessing(add_prefix_space~, ..) => Some(add_prefix_space)
    ByteLevel(add_prefix_space~, ..) => Some(add_prefix_space)
    _ => None
  }
}

///|
pub fn PostProcessor::get_add_prefix_space(self : PostProcessor) -> Bool? {
  self.add_prefix_space()
}

///|
pub fn PostProcessor::use_regex(self : PostProcessor) -> Bool? {
  match self {
    ByteLevel(use_regex~, ..) => Some(use_regex)
    _ => None
  }
}

///|
pub fn PostProcessor::get_use_regex(self : PostProcessor) -> Bool? {
  self.use_regex()
}

///|

///|
/// Set trim_offsets. Returns a new PostProcessor; only RobertaProcessing and ByteLevel support it.
pub fn PostProcessor::set_trim_offsets(
  self : PostProcessor,
  val : Bool,
) -> PostProcessor {
  match self {
    RobertaProcessing(sep~, cls~, add_prefix_space~, ..) =>
      RobertaProcessing(sep~, cls~, trim_offsets=val, add_prefix_space~)
    ByteLevel(add_prefix_space~, use_regex~, ..) =>
      ByteLevel(add_prefix_space~, trim_offsets=val, use_regex~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for trim_offsets.
pub fn PostProcessor::set_trim_offsets_alias(
  self : PostProcessor,
  val : Bool,
) -> PostProcessor {
  self.set_trim_offsets(val)
}

///|
/// Set add_prefix_space. Returns a new PostProcessor; only RobertaProcessing and ByteLevel support it.
pub fn PostProcessor::set_add_prefix_space(
  self : PostProcessor,
  val : Bool,
) -> PostProcessor {
  match self {
    RobertaProcessing(sep~, cls~, trim_offsets~, ..) =>
      RobertaProcessing(sep~, cls~, trim_offsets~, add_prefix_space=val)
    ByteLevel(trim_offsets~, use_regex~, ..) =>
      ByteLevel(add_prefix_space=val, trim_offsets~, use_regex~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for add_prefix_space.
pub fn PostProcessor::set_add_prefix_space_alias(
  self : PostProcessor,
  val : Bool,
) -> PostProcessor {
  self.set_add_prefix_space(val)
}

///|
/// Set use_regex. Returns a new PostProcessor; only ByteLevel supports it.
pub fn PostProcessor::set_use_regex(
  self : PostProcessor,
  val : Bool,
) -> PostProcessor {
  match self {
    ByteLevel(add_prefix_space~, trim_offsets~, ..) =>
      ByteLevel(add_prefix_space~, trim_offsets~, use_regex=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for use_regex.
pub fn PostProcessor::set_use_regex_alias(
  self : PostProcessor,
  val : Bool,
) -> PostProcessor {
  self.set_use_regex(val)
}

///|
/// Set sep. Returns a new PostProcessor; only BertProcessing and RobertaProcessing support it.
pub fn PostProcessor::set_sep(
  self : PostProcessor,
  val : (String, Int),
) -> PostProcessor {
  match self {
    BertProcessing(cls~, ..) => BertProcessing(sep=val, cls~)
    RobertaProcessing(cls~, trim_offsets~, add_prefix_space~, ..) =>
      RobertaProcessing(sep=val, cls~, trim_offsets~, add_prefix_space~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for sep.
pub fn PostProcessor::set_sep_alias(
  self : PostProcessor,
  val : (String, Int),
) -> PostProcessor {
  self.set_sep(val)
}

///|
/// Set cls. Returns a new PostProcessor; only BertProcessing and RobertaProcessing support it.
pub fn PostProcessor::set_cls(
  self : PostProcessor,
  val : (String, Int),
) -> PostProcessor {
  match self {
    BertProcessing(sep~, ..) => BertProcessing(sep~, cls=val)
    RobertaProcessing(sep~, trim_offsets~, add_prefix_space~, ..) =>
      RobertaProcessing(sep~, cls=val, trim_offsets~, add_prefix_space~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for cls.
pub fn PostProcessor::set_cls_alias(
  self : PostProcessor,
  val : (String, Int),
) -> PostProcessor {
  self.set_cls(val)
}

///|
pub fn PostProcessor::single_pieces(self : PostProcessor) -> Array[Piece] {
  match self {
    TemplateProcessing(single~, ..) => single.copy()
    _ => []
  }
}

///|
pub fn PostProcessor::get_single_pieces(self : PostProcessor) -> Array[Piece] {
  self.single_pieces()
}

///|
/// HF-style `TemplateProcessing.single` typed alias.
pub fn PostProcessor::single(self : PostProcessor) -> Array[Piece] {
  self.single_pieces()
}

///|
pub fn PostProcessor::get_single(self : PostProcessor) -> Array[Piece] {
  self.single()
}

///|
pub fn PostProcessor::pair_pieces(self : PostProcessor) -> Array[Piece] {
  match self {
    TemplateProcessing(pair~, ..) => pair.copy()
    _ => []
  }
}

///|
pub fn PostProcessor::get_pair_pieces(self : PostProcessor) -> Array[Piece] {
  self.pair_pieces()
}

///|
/// HF-style `TemplateProcessing.pair` typed alias.
pub fn PostProcessor::pair(self : PostProcessor) -> Array[Piece] {
  self.pair_pieces()
}

///|
pub fn PostProcessor::get_pair(self : PostProcessor) -> Array[Piece] {
  self.pair()
}

///|
pub fn PostProcessor::special_tokens(
  self : PostProcessor,
) -> Map[String, SpecialToken] {
  match self {
    TemplateProcessing(special_tokens~, ..) =>
      copy_special_tokens(special_tokens)
    _ => {}
  }
}

///|
pub fn PostProcessor::get_special_tokens(
  self : PostProcessor,
) -> Map[String, SpecialToken] {
  self.special_tokens()
}

///|
pub fn PostProcessor::processors(self : PostProcessor) -> Array[PostProcessor] {
  match self {
    Sequence(steps) => steps.copy()
    _ => []
  }
}

///|
/// HF/Python getter alias for Sequence child post-processors.
pub fn PostProcessor::get_processors(
  self : PostProcessor,
) -> Array[PostProcessor] {
  self.processors()
}

///|
pub fn PostProcessor::__len__(self : PostProcessor) -> Int {
  match self {
    Sequence(steps) => steps.length()
    _ => 0
  }
}

///|
pub fn PostProcessor::get_item(
  self : PostProcessor,
  index : Int,
) -> PostProcessor? {
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
pub fn PostProcessor::__getitem__(
  self : PostProcessor,
  index : Int,
) -> PostProcessor? {
  self.get_item(index)
}

///|
/// Programmatic constructor for HF-style BERT post-processing:
/// `[CLS] A [SEP]` and `[CLS] A [SEP] B [SEP]`.
pub fn PostProcessor::bert(
  sep : (String, Int),
  cls : (String, Int),
) -> PostProcessor {
  BertProcessing(sep~, cls~)
}

///|
/// HF class-name style alias for `BertProcessing`.
pub fn PostProcessor::bert_processing(
  sep : (String, Int),
  cls : (String, Int),
) -> PostProcessor {
  PostProcessor::bert(sep, cls)
}

///|
/// Programmatic constructor for RoBERTa post-processing.
pub fn PostProcessor::roberta(
  sep : (String, Int),
  cls : (String, Int),
  trim_offsets? : Bool = true,
  add_prefix_space? : Bool = true,
) -> PostProcessor {
  RobertaProcessing(sep~, cls~, trim_offsets~, add_prefix_space~)
}

///|
/// HF class-name style alias for `RobertaProcessing`.
pub fn PostProcessor::roberta_processing(
  sep : (String, Int),
  cls : (String, Int),
  trim_offsets? : Bool = true,
  add_prefix_space? : Bool = true,
) -> PostProcessor {
  PostProcessor::roberta(sep, cls, trim_offsets~, add_prefix_space~)
}

///|
/// Programmatic constructor for template processing using already-parsed pieces.
pub fn PostProcessor::template(
  single : Array[Piece],
  pair : Array[Piece],
  special_tokens : Map[String, SpecialToken],
) -> PostProcessor {
  TemplateProcessing(single~, pair~, special_tokens~)
}

///|
/// HF class-name style alias for `TemplateProcessing` with parsed pieces.
pub fn PostProcessor::template_processing(
  single : Array[Piece],
  pair : Array[Piece],
  special_tokens : Map[String, SpecialToken],
) -> PostProcessor {
  PostProcessor::template(single, pair, special_tokens)
}

///|
/// Programmatic constructor that parses HF TemplateProcessing DSL strings such
/// as `"[CLS] $A [SEP]"` and `"[CLS]:0 $A:0 [SEP]:0 $B:1 [SEP]:1"`.
pub fn PostProcessor::template_from_strings(
  single : String,
  pair : String,
  special_tokens : Map[String, SpecialToken],
) -> PostProcessor raise @types.TokenizerError {
  TemplateProcessing(
    single=parse_template_string(single),
    pair=parse_template_string(pair),
    special_tokens~,
  )
}

///|
pub fn PostProcessor::byte_level(
  add_prefix_space? : Bool = true,
  trim_offsets? : Bool = true,
  use_regex? : Bool = true,
) -> PostProcessor {
  ByteLevel(add_prefix_space~, trim_offsets~, use_regex~)
}

///|
pub fn PostProcessor::sequence(steps : Array[PostProcessor]) -> PostProcessor {
  Sequence(steps)
}

///|
/// Serialize post-processors created through the typed/programmatic API.
pub fn PostProcessor::to_json(self : PostProcessor) -> String? {
  match self {
    TemplateProcessing(single~, pair~, special_tokens~) =>
      Some(template_to_json(single, pair, special_tokens))
    BertProcessing(sep~, cls~) => Some(bert_to_json(sep, cls))
    RobertaProcessing(sep~, cls~, trim_offsets~, add_prefix_space~) =>
      Some(roberta_to_json(sep, cls, trim_offsets, add_prefix_space))
    ByteLevel(add_prefix_space~, trim_offsets~, use_regex~) =>
      Some(bytelevel_to_json(add_prefix_space, trim_offsets, use_regex))
    Sequence(steps) => processor_sequence_to_json(steps)
  }
}

///|
fn template_to_json(
  single : Array[Piece],
  pair : Array[Piece],
  special_tokens : Map[String, SpecialToken],
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"TemplateProcessing\",\"single\":")
  write_pieces_json(sb, single)
  sb.write_string(",\"pair\":")
  write_pieces_json(sb, pair)
  sb.write_string(",\"special_tokens\":")
  write_special_tokens_json(sb, special_tokens)
  sb.write_char('}')
  sb.to_string()
}

///|
fn bert_to_json(sep : (String, Int), cls : (String, Int)) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"BertProcessing\",\"sep\":")
  write_token_id_pair(sb, sep)
  sb.write_string(",\"cls\":")
  write_token_id_pair(sb, cls)
  sb.write_char('}')
  sb.to_string()
}

///|
fn roberta_to_json(
  sep : (String, Int),
  cls : (String, Int),
  trim_offsets : Bool,
  add_prefix_space : Bool,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"RobertaProcessing\",\"sep\":")
  write_token_id_pair(sb, sep)
  sb.write_string(",\"cls\":")
  write_token_id_pair(sb, cls)
  sb.write_string(",\"trim_offsets\":")
  sb.write_string(bool_json(trim_offsets))
  sb.write_string(",\"add_prefix_space\":")
  sb.write_string(bool_json(add_prefix_space))
  sb.write_char('}')
  sb.to_string()
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
fn processor_sequence_to_json(steps : Array[PostProcessor]) -> String? {
  let parts : Array[String] = []
  for step in steps {
    match step.to_json() {
      Some(json) => parts.push(json)
      None => return None
    }
  }
  let sb = StringBuilder::new()
  sb.write_string("{\"type\":\"Sequence\",\"processors\":[")
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
fn write_pieces_json(sb : StringBuilder, pieces : Array[Piece]) -> Unit {
  sb.write_char('[')
  for i, piece in pieces {
    if i > 0 {
      sb.write_char(',')
    }
    match piece {
      SequenceRef(id~, type_id~) => {
        sb.write_string("{\"Sequence\":{\"id\":")
        write_json_string(sb, id)
        sb.write_string(",\"type_id\":")
        sb.write_string(type_id.to_string())
        sb.write_string("}}")
      }
      SpecialTokenRef(id~, type_id~) => {
        sb.write_string("{\"SpecialToken\":{\"id\":")
        write_json_string(sb, id)
        sb.write_string(",\"type_id\":")
        sb.write_string(type_id.to_string())
        sb.write_string("}}")
      }
    }
  }
  sb.write_char(']')
}

///|
fn write_special_tokens_json(
  sb : StringBuilder,
  special_tokens : Map[String, SpecialToken],
) -> Unit {
  let entries = special_tokens.to_array()
  sb.write_char('{')
  for i, kv in entries {
    if i > 0 {
      sb.write_char(',')
    }
    write_json_string(sb, kv.0)
    sb.write_string(":{\"id\":")
    write_json_string(sb, kv.1.id)
    sb.write_string(",\"ids\":")
    write_int_array(sb, kv.1.ids)
    sb.write_string(",\"tokens\":")
    write_string_array(sb, kv.1.tokens)
    sb.write_char('}')
  }
  sb.write_char('}')
}

///|
fn write_token_id_pair(sb : StringBuilder, pair : (String, Int)) -> Unit {
  sb.write_char('[')
  write_json_string(sb, pair.0)
  sb.write_char(',')
  sb.write_string(pair.1.to_string())
  sb.write_char(']')
}

///|
fn write_int_array(sb : StringBuilder, xs : Array[Int]) -> Unit {
  sb.write_char('[')
  for i, x in xs {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_string(x.to_string())
  }
  sb.write_char(']')
}

///|
fn write_string_array(sb : StringBuilder, xs : Array[String]) -> Unit {
  sb.write_char('[')
  for i, x in xs {
    if i > 0 {
      sb.write_char(',')
    }
    write_json_string(sb, x)
  }
  sb.write_char(']')
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
/// Number of special tokens this processor inserts for single/pair encoding.
/// Used to mirror HF truncation order: truncate raw sequences while reserving
/// room for post-processor specials, then post-process, then pad.
