// The `post_processor` stage: adds special tokens (e.g. [CLS]/[SEP], <s>/</s>)
// and sets type_ids after the model produces tokens.
//
// P1 scope: enum + deserialization. `process` behaviour lands in P7.

/// One piece of a processing template: either a reference to an input sequence
/// (A or B) or a literal special token, each tagged with a type_id.
pub enum Piece {
  SequenceRef(id~ : String, type_id~ : Int)
  SpecialTokenRef(id~ : String, type_id~ : Int)
} derive(Show, Eq)

/// A special token definition: its surface and the ids/tokens it expands to.
pub struct SpecialToken {
  id : String
  ids : Array[Int]
  tokens : Array[String]
} derive(Show, Eq)

pub enum PostProcessor {
  TemplateProcessing(
    single~ : Array[Piece],
    pair~ : Array[Piece],
    special_tokens~ : Map[String, SpecialToken],
  )
  BertProcessing(sep~ : (String, Int), cls~ : (String, Int))
  RobertaProcessing(
    sep~ : (String, Int),
    cls~ : (String, Int),
    trim_offsets~ : Bool,
    add_prefix_space~ : Bool,
  )
  ByteLevel(add_prefix_space~ : Bool, trim_offsets~ : Bool, use_regex~ : Bool)
  Sequence(Array[PostProcessor])
}

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
        _ => raise @types.ParseError("post_processor Sequence missing processors")
      }
      Sequence(arr.map(x => PostProcessor::from_json(x)))
    }
    other => raise @types.UnsupportedComponent("post_processor type: \{other}")
  }
}

// Bert/Roberta store sep/cls as ["[SEP]", 102].
fn parse_token_id_pair(
  obj : Map[String, Json],
  key : String,
) -> (String, Int) raise @types.TokenizerError {
  match obj.get(key) {
    Some(Array([String(tok), Number(id, ..)])) => (tok, id.to_int())
    _ => raise @types.ParseError("post_processor.\{key} must be [token, id]")
  }
}

fn parse_pieces(
  obj : Map[String, Json],
  key : String,
) -> Array[Piece] raise @types.TokenizerError {
  let arr = match obj.get(key) {
    Some(Array(a)) => a
    _ => []
  }
  let out : Array[Piece] = []
  for entry in arr {
    let eobj = @types.as_object(entry, "template piece")
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
  }
  out
}

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
