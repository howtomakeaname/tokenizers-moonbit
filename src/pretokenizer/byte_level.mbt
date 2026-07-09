// Byte-level mapping (GPT-2 / RoBERTa style).
//
// HuggingFace's ByteLevel maps each of the 256 byte values to a single visible
// Unicode code point so that no byte is ever an "unknown char". This module
// builds the byte<->char tables once and exposes encode/decode helpers.

// Lazily-initialized tables. byte_to_char[b] is the char for byte b;
// char_to_byte maps that char back to b.

///|
let byte_to_char : Array[Char] = build_byte_to_char()

///|
let char_to_byte : Map[Char, Int] = build_char_to_byte()

///|
fn build_bs() -> Array[Int] {
  // The "printable" byte ranges that map to themselves.
  let bs : Array[Int] = []
  for b in 33..<=126 {
    bs.push(b)
  }
  for b in 161..<=172 {
    bs.push(b)
  }
  for b in 174..<=255 {
    bs.push(b)
  }
  bs
}

///|
fn build_byte_to_char() -> Array[Char] {
  let bs = build_bs()
  // cs starts as a copy of bs; remaining bytes get assigned 256+n.
  let in_bs = Array::make(256, false)
  for b in bs {
    in_bs[b] = true
  }
  let table = Array::make(256, ' ')
  // Self-mapped bytes.
  for b in bs {
    table[b] = b.unsafe_to_char()
  }
  // Remaining bytes map to 256, 257, ...
  let mut n = 0
  for b in 0..<256 {
    if !in_bs[b] {
      table[b] = (256 + n).unsafe_to_char()
      n = n + 1
    }
  }
  table
}

///|
fn build_char_to_byte() -> Map[Char, Int] {
  let m : Map[Char, Int] = {}
  let table = build_byte_to_char()
  for b in 0..<256 {
    m[table[b]] = b
  }
  m
}

///|
/// Map a string to its byte-level representation: encode to UTF-8, then map
/// each byte to its visible char.
pub fn byte_level_encode_str(s : String) -> String {
  // NOTE: String::to_bytes returns UTF-16; we need UTF-8 here.
  let bytes = @utf8.encode(s)
  let sb = StringBuilder::new()
  let n = bytes.length()
  for i in 0..<n {
    let b = bytes[i].to_int()
    sb.write_char(byte_to_char[b])
  }
  sb.to_string()
}

///|
/// Return the 256-character ByteLevel alphabet used by GPT-2/RoBERTa style BPE
/// training. Pass this as BPE `initial_alphabet` to guarantee every byte can be
/// represented even when the training corpus does not contain it.
pub fn byte_level_alphabet() -> Array[String] {
  let out : Array[String] = []
  for b in 0..<256 {
    out.push(@common.char_string(byte_to_char[b]))
  }
  out
}

///|
/// HF-style ByteLevel.alphabet alias exposed on the pre-tokenizer facade.
pub fn PreTokenizer::byte_level_alphabet() -> Array[String] {
  byte_level_alphabet()
}

///|
/// HF-style ByteLevel.alphabet alias with the exact Python method name.
pub fn PreTokenizer::alphabet() -> Array[String] {
  byte_level_alphabet()
}

///|
/// Inverse of `byte_level_encode_str`: map each char back to a byte, then
/// decode the byte sequence as UTF-8 (lossy).
pub fn byte_level_decode_str(s : String) -> String {
  let buf = @buffer.Buffer::Buffer()
  for c in s {
    match char_to_byte.get(c) {
      Some(b) => buf.write_byte(b.to_byte())
      None => () // not a byte-level char; skip
    }
  }
  @utf8.decode_lossy(buf.to_bytes()[:])
}
