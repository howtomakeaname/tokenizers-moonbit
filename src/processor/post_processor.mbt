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
pub fn PostProcessor::sep(self : PostProcessor) -> (String, Int)? {
  match self {
    BertProcessing(sep~, ..) => Some(sep)
    RobertaProcessing(sep~, ..) => Some(sep)
    _ => None
  }
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
pub fn PostProcessor::trim_offsets(self : PostProcessor) -> Bool? {
  match self {
    RobertaProcessing(trim_offsets~, ..) => Some(trim_offsets)
    ByteLevel(trim_offsets~, ..) => Some(trim_offsets)
    _ => None
  }
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
pub fn PostProcessor::use_regex(self : PostProcessor) -> Bool? {
  match self {
    ByteLevel(use_regex~, ..) => Some(use_regex)
    _ => None
  }
}

///|
pub fn PostProcessor::single_pieces(self : PostProcessor) -> Array[Piece] {
  match self {
    TemplateProcessing(single~, ..) => single.copy()
    _ => []
  }
}

///|
pub fn PostProcessor::pair_pieces(self : PostProcessor) -> Array[Piece] {
  match self {
    TemplateProcessing(pair~, ..) => pair.copy()
    _ => []
  }
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
pub fn PostProcessor::processors(self : PostProcessor) -> Array[PostProcessor] {
  match self {
    Sequence(steps) => steps.copy()
    _ => []
  }
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
/// Programmatic constructor for template processing using already-parsed pieces.
pub fn PostProcessor::template(
  single : Array[Piece],
  pair : Array[Piece],
  special_tokens : Map[String, SpecialToken],
) -> PostProcessor {
  TemplateProcessing(single~, pair~, special_tokens~)
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
pub fn PostProcessor::added_tokens(
  self : PostProcessor,
  pair? : Bool = false,
) -> Int {
  match self {
    TemplateProcessing(single~, pair=pair_template, special_tokens~) =>
      count_specials(if pair { pair_template } else { single }, special_tokens)
    BertProcessing(..) => if pair { 3 } else { 2 }
    RobertaProcessing(..) => if pair { 4 } else { 2 }
    ByteLevel(..) => 0
    Sequence(steps) => {
      let mut n = 0
      for step in steps {
        n = n + step.added_tokens(pair~)
      }
      n
    }
  }
}

///|
fn count_specials(
  pieces : Array[Piece],
  special_tokens : Map[String, SpecialToken],
) -> Int {
  let mut n = 0
  for p in pieces {
    match p {
      SpecialTokenRef(id~, ..) =>
        match special_tokens.get(id) {
          Some(st) => n = n + st.ids.length()
          None => n = n + 1
        }
      SequenceRef(..) => ()
    }
  }
  n
}

///|
fn copy_special_tokens(
  special_tokens : Map[String, SpecialToken],
) -> Map[String, SpecialToken] {
  let out : Map[String, SpecialToken] = {}
  for kv in special_tokens {
    let (key, st) = kv
    out[key] = SpecialToken::new(st.id, st.ids, st.tokens)
  }
  out
}

///|
/// Parse a post_processor config object.
pub fn PostProcessor::from_json(
  j : Json,
) -> PostProcessor raise @types.TokenizerError {
  let obj = @types.as_object(j, "post_processor")
  let ty = @types.get_type(obj, "post_processor")
  match ty {
    "TemplateProcessing" =>
      TemplateProcessing(
        single=parse_pieces(obj, "single"),
        pair=parse_pieces(obj, "pair"),
        special_tokens=parse_special_tokens(obj),
      )
    "BertProcessing" =>
      BertProcessing(
        sep=parse_token_id_pair(obj, "sep"),
        cls=parse_token_id_pair(obj, "cls"),
      )
    "RobertaProcessing" =>
      RobertaProcessing(
        sep=parse_token_id_pair(obj, "sep"),
        cls=parse_token_id_pair(obj, "cls"),
        trim_offsets=@types.get_bool(obj, "trim_offsets", default=true),
        add_prefix_space=@types.get_bool(obj, "add_prefix_space", default=true),
      )
    "ByteLevel" =>
      ByteLevel(
        add_prefix_space=@types.get_bool(obj, "add_prefix_space", default=true),
        trim_offsets=@types.get_bool(obj, "trim_offsets", default=true),
        use_regex=@types.get_bool(obj, "use_regex", default=true),
      )
    "Sequence" => {
      let arr = match obj.get("processors") {
        Some(Array(a)) => a
        _ =>
          raise @types.ParseError("post_processor Sequence missing processors")
      }
      Sequence(arr.map(x => PostProcessor::from_json(x)))
    }
    other => raise @types.UnsupportedComponent("post_processor type: \{other}")
  }
}

// Bert/Roberta store sep/cls as ["[SEP]", 102].

///|
fn parse_token_id_pair(
  obj : Map[String, Json],
  key : String,
) -> (String, Int) raise @types.TokenizerError {
  match obj.get(key) {
    Some(Array([String(tok), Number(id, ..)])) => (tok, id.to_int())
    _ => raise @types.ParseError("post_processor.\{key} must be [token, id]")
  }
}

///|
fn parse_pieces(
  obj : Map[String, Json],
  key : String,
) -> Array[Piece] raise @types.TokenizerError {
  let out : Array[Piece] = []
  match obj.get(key) {
    Some(String(s)) =>
      for p in parse_template_string(s) {
        out.push(p)
      }
    Some(Array(arr)) =>
      for entry in arr {
        match entry {
          String(s) => out.push(parse_template_token(s))
          Object(eobj) =>
            match eobj.get("Sequence") {
              Some(Object(s)) =>
                out.push(
                  SequenceRef(
                    id=@types.get_str(s, "id", default="A"),
                    type_id=@types.get_int(s, "type_id", default=0),
                  ),
                )
              _ =>
                match eobj.get("SpecialToken") {
                  Some(Object(s)) =>
                    out.push(
                      SpecialTokenRef(
                        id=@types.get_str(s, "id", default=""),
                        type_id=@types.get_int(s, "type_id", default=0),
                      ),
                    )
                  _ => raise @types.ParseError("unknown template piece")
                }
            }
          _ => raise @types.ParseError("unknown template piece")
        }
      }
    _ => ()
  }
  out
}

///|
fn parse_template_string(
  s : String,
) -> Array[Piece] raise @types.TokenizerError {
  let out : Array[Piece] = []
  for tok in split_template_ws(s) {
    out.push(parse_template_token(tok))
  }
  out
}

///|
fn parse_template_token(tok : String) -> Piece raise @types.TokenizerError {
  if tok.is_empty() {
    raise @types.ParseError("empty template token")
  }
  let (id, type_id) = split_template_type(tok)
  if id.has_prefix("$") {
    let seq = drop_first_char(id)
    let seq = match seq {
      "0" => "A"
      "1" => "B"
      "A" | "B" => seq
      other => raise @types.ParseError("unknown template sequence: \{other}")
    }
    SequenceRef(id=seq, type_id~)
  } else {
    SpecialTokenRef(id~, type_id~)
  }
}

///|
fn split_template_ws(s : String) -> Array[String] {
  let chars = s.to_array()
  let out : Array[String] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    while i < n && is_template_ws(chars[i]) {
      i = i + 1
    }
    let start = i
    while i < n && !is_template_ws(chars[i]) {
      i = i + 1
    }
    if i > start {
      out.push(slice_chars(chars, start, i))
    }
  }
  out
}

///|
fn split_template_type(tok : String) -> (String, Int) {
  let chars = tok.to_array()
  for i in 0..<chars.length() {
    if chars[i] == ':' {
      return (
        slice_chars(chars, 0, i),
        parse_decimal(slice_chars(chars, i + 1, chars.length())),
      )
    }
  }
  (tok, 0)
}

///|
fn parse_decimal(s : String) -> Int {
  let mut out = 0
  for c in s {
    if c >= '0' && c <= '9' {
      out = out * 10 + (c.to_int() - '0'.to_int())
    }
  }
  out
}

///|
fn drop_first_char(s : String) -> String {
  let chars = s.to_array()
  if chars.length() <= 1 {
    ""
  } else {
    slice_chars(chars, 1, chars.length())
  }
}

///|
fn is_template_ws(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn slice_chars(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn parse_special_tokens(
  obj : Map[String, Json],
) -> Map[String, SpecialToken] raise @types.TokenizerError {
  let out : Map[String, SpecialToken] = {}
  let sobj = match obj.get("special_tokens") {
    Some(Object(s)) => s
    _ => return out
  }
  for kv in sobj {
    let (key, v) = kv
    let vobj = @types.as_object(v, "special_token")
    let id = @types.get_str(vobj, "id", default=key)
    let ids : Array[Int] = []
    match vobj.get("ids") {
      Some(Array(a)) =>
        for x in a {
          match x {
            Number(n, ..) => ids.push(n.to_int())
            _ => ()
          }
        }
      _ => ()
    }
    let tokens : Array[String] = []
    match vobj.get("tokens") {
      Some(Array(a)) =>
        for x in a {
          match x {
            String(s) => tokens.push(s)
            _ => ()
          }
        }
      _ => ()
    }
    out[key] = { id, ids, tokens }
  }
  out
}
