///|
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
/// HF Python binding alias for `added_tokens(pair=is_pair)`.
pub fn PostProcessor::num_special_tokens_to_add(
  self : PostProcessor,
  is_pair? : Bool = false,
) -> Int {
  self.added_tokens(pair=is_pair)
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
