// The `decoder` stage: token surfaces -> reconstructed text.
//
// P1 scope: enum + deserialization. `decode` behaviour lands in P4 (ByteLevel)
// and P5/P6 (WordPiece/Metaspace).

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
    "BPEDecoder" => BPEDecoder(suffix=@types.get_str(obj, "suffix", default="</w>"))
    "Fuse" => Fuse
    "ByteFallback" => ByteFallback
    "CTC" =>
      CTC(
        pad_token=@types.get_str(obj, "pad_token", default="<pad>"),
        word_delimiter_token=@types.get_str(obj, "word_delimiter_token", default="|"),
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
