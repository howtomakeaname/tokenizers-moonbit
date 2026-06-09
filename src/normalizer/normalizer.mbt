// The `normalizer` stage: text -> normalized text.
//
// P1 scope: enum + deserialization. Actual `normalize` behaviour for the
// simple variants (Lowercase/Strip/Replace/Sequence/Prepend/BertNormalizer)
// and Unicode NFC/NFD/NFKC/NFKD are implemented in normalize.mbt.

///|
pub(all) struct PrecompiledCharsMap {
  trie : Array[Int]
  normalized : Array[Int]
}

///|
pub(all) enum Normalizer {
  NFC
  NFD
  NFKC
  NFKD
  Lowercase
  Strip(left~ : Bool, right~ : Bool)
  StripAccents
  ByteLevel
  Replace(pattern~ : String, content~ : String)
  Prepend(prepend~ : String)
  // Moses/NMT style cleanup used by SentencePiece-era tokenizers.
  Nmt
  // SentencePiece Precompiled charsmap; common SPM NFKC+whitespace map.
  Precompiled
  // Parsed SentencePiece binary `precompiled_charsmap` double-array trie.
  PrecompiledMap(data~ : PrecompiledCharsMap)
  BertNormalizer(
    clean_text~ : Bool,
    handle_chinese_chars~ : Bool,
    strip_accents~ : Bool,
    lowercase~ : Bool
  )
  Sequence(Array[Normalizer])
}

///|
/// Parse a normalizer config object (may be JSON null -> None upstream).
pub fn Normalizer::from_json(
  j : Json,
) -> Normalizer raise @types.TokenizerError {
  let obj = @types.as_object(j, "normalizer")
  let ty = @types.get_type(obj, "normalizer")
  match ty {
    "NFC" => NFC
    "NFD" => NFD
    "NFKC" => NFKC
    "NFKD" => NFKD
    "Lowercase" => Lowercase
    "StripAccents" => StripAccents
    "ByteLevel" => ByteLevel
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
    "Nmt" => Nmt
    "Precompiled" =>
      match obj.get("precompiled_charsmap") {
        Some(String(charsmap)) =>
          if charsmap.is_empty() {
            Precompiled
          } else {
            PrecompiledMap(data=parse_precompiled_charsmap(charsmap))
          }
        _ => Precompiled
      }
    "BertNormalizer" => {
      let lowercase = @types.get_bool(obj, "lowercase", default=true)
      // strip_accents defaults to the lowercase value when absent/null (HF).
      let strip_accents = match obj.get("strip_accents") {
        Some(True) => true
        Some(False) => false
        _ => lowercase
      }
      BertNormalizer(
        clean_text=@types.get_bool(obj, "clean_text", default=true),
        handle_chinese_chars=@types.get_bool(
          obj,
          "handle_chinese_chars",
          default=true,
        ),
        strip_accents~,
        lowercase~,
      )
    }
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

///|
fn parse_precompiled_charsmap(
  charsmap : String,
) -> PrecompiledCharsMap raise @types.TokenizerError {
  let bytes = decode_base64(charsmap)
  guard read_le_u32(bytes, 0) is Some(trie_size) else {
    raise @types.ParseError("invalid precompiled_charsmap header")
  }
  if trie_size < 0 || trie_size % 4 != 0 || 4 + trie_size > bytes.length() {
    raise @types.ParseError("invalid precompiled_charsmap trie length")
  }
  let trie : Array[Int] = []
  let units = trie_size / 4
  for i in 0..<units {
    guard read_le_u32(bytes, 4 + i * 4) is Some(unit) else {
      raise @types.ParseError("invalid precompiled_charsmap trie unit")
    }
    trie.push(unit)
  }
  if trie.length() == 0 {
    raise @types.ParseError("invalid precompiled_charsmap empty trie")
  }
  let normalized : Array[Int] = []
  for i in (4 + trie_size)..<bytes.length() {
    normalized.push(bytes[i])
  }
  { trie, normalized }
}

///|
fn read_le_u32(bytes : Array[Int], offset : Int) -> Int? {
  if offset < 0 || offset + 4 > bytes.length() {
    return None
  }
  Some(
    bytes[offset] +
    bytes[offset + 1] * 256 +
    bytes[offset + 2] * 65536 +
    bytes[offset + 3] * 16777216,
  )
}

///|
fn decode_base64(s : String) -> Array[Int] raise @types.TokenizerError {
  let out : Array[Int] = []
  let mut acc = 0
  let mut bits = 0
  for c in s {
    if c == '=' {
      break
    }
    let v = base64_value(c)
    if v < 0 {
      if c == '\n' || c == '\r' || c == '\t' || c == ' ' {
        continue
      }
      raise @types.ParseError("invalid precompiled_charsmap base64")
    }
    acc = (acc << 6) | v
    bits = bits + 6
    while bits >= 8 {
      bits = bits - 8
      out.push((acc >> bits) & 0xFF)
    }
  }
  out
}

///|
fn base64_value(c : Char) -> Int {
  let u = c.to_int()
  if u >= 65 && u <= 90 {
    u - 65
  } else if u >= 97 && u <= 122 {
    u - 97 + 26
  } else if u >= 48 && u <= 57 {
    u - 48 + 52
  } else if c == '+' {
    62
  } else if c == '/' {
    63
  } else {
    -1
  }
}

// HF "pattern" can be {"String": "x"} or {"Regex": "x"}; we keep the raw string.

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
