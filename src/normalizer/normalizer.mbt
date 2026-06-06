// The `normalizer` stage: text -> normalized text.
//
// P1 scope: enum + deserialization. Actual `normalize` behaviour for the
// simple variants (Lowercase/Strip/Replace/Sequence/Prepend/BertNormalizer)
// lands in P5/P7. The NFC/NFD/NFKC/NFKD variants are parsed here but require a
// Unicode normalization data table (TODO); they currently act as identity.

pub enum Normalizer {
  NFC
  NFD
  NFKC
  NFKD
  Lowercase
  Strip(left~ : Bool, right~ : Bool)
  StripAccents
  Replace(pattern~ : String, content~ : String)
  Prepend(prepend~ : String)
  BertNormalizer(
    clean_text~ : Bool,
    handle_chinese_chars~ : Bool,
    lowercase~ : Bool,
  )
  Sequence(Array[Normalizer])
}

/// Parse a normalizer config object (may be JSON null -> None upstream).
pub fn Normalizer::from_json(j : Json) -> Normalizer raise @types.TokenizerError {
  let obj = @types.as_object(j, "normalizer")
  let ty = @types.get_type(obj, "normalizer")
  match ty {
    "NFC" => NFC
    "NFD" => NFD
    "NFKC" => NFKC
    "NFKD" => NFKD
    "Lowercase" => Lowercase
    "StripAccents" => StripAccents
    "Strip" =>
      Strip(
        left=@types.get_bool(obj, "strip_left", default=true),
        right=@types.get_bool(obj, "strip_right", default=true),
      )
    "Replace" =>
      Replace(
        pattern=parse_pattern(obj),
        content=@types.get_str(obj, "content", default=""),
      )
    "Prepend" => Prepend(prepend=@types.get_str(obj, "prepend", default=""))
    "BertNormalizer" =>
      BertNormalizer(
        clean_text=@types.get_bool(obj, "clean_text", default=true),
        handle_chinese_chars=@types.get_bool(obj, "handle_chinese_chars", default=true),
        lowercase=@types.get_bool(obj, "lowercase", default=true),
      )
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

// HF "pattern" can be {"String": "x"} or {"Regex": "x"}; we keep the raw string.
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
