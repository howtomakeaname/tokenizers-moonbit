// The `pre_tokenizer` stage: splits normalized text into word-like pieces
// before the model runs.
//
// P1 scope: enum + deserialization. `pre_tokenize` behaviour lands in P3
// (ByteLevel/GPT-2) and P5/P6/P7 (the rest).

/// How a Split pre-tokenizer treats the matched delimiter.
pub enum SplitBehavior {
  Removed
  Isolated
  MergedWithPrevious
  MergedWithNext
  Contiguous
} derive(Eq, Show)

pub enum PreTokenizer {
  ByteLevel(add_prefix_space~ : Bool, use_regex~ : Bool, trim_offsets~ : Bool)
  Whitespace
  WhitespaceSplit
  Metaspace(replacement~ : Char, prepend_scheme~ : String)
  Punctuation
  Split(pattern~ : String, behavior~ : SplitBehavior, invert~ : Bool)
  BertPreTokenizer
  Digits(individual_digits~ : Bool)
  Sequence(Array[PreTokenizer])
}

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
    "Punctuation" => Punctuation
    "BertPreTokenizer" => BertPreTokenizer
    "Metaspace" =>
      Metaspace(
        replacement=@types.get_char(obj, "replacement", default='▁'),
        prepend_scheme=@types.get_str(obj, "prepend_scheme", default="always"),
      )
    "Digits" =>
      Digits(individual_digits=@types.get_bool(obj, "individual_digits", default=false))
    "Split" =>
      Split(
        pattern=parse_pattern(obj),
        behavior=parse_behavior(obj),
        invert=@types.get_bool(obj, "invert", default=false),
      )
    "Sequence" => {
      let arr = match obj.get("pretokenizers") {
        Some(Array(a)) => a
        _ => raise @types.ParseError("pre_tokenizer Sequence missing pretokenizers")
      }
      Sequence(arr.map(x => PreTokenizer::from_json(x)))
    }
    other => raise @types.UnsupportedComponent("pre_tokenizer type: \{other}")
  }
}

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
