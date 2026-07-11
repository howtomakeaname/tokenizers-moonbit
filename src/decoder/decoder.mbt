// The `decoder` stage: token surfaces -> reconstructed text.
//
// P1 scope: enum + deserialization. `decode` behaviour lands in P4 (ByteLevel)
// and P5/P6 (WordPiece/Metaspace).

///|
pub enum Decoder {
  ByteLevel(add_prefix_space~ : Bool, trim_offsets~ : Bool, use_regex~ : Bool)
  WordPiece(prefix~ : String, cleanup~ : Bool)
  Metaspace(replacement~ : Char, prepend_scheme~ : String, split~ : Bool)
  BPEDecoder(suffix~ : String)
  Strip(content~ : Char, start~ : Int, stop~ : Int)
  Fuse
  Replace(pattern~ : String, content~ : String)
  ReplaceString(pattern~ : String, content~ : String)
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
    Replace(..) | ReplaceString(..) => "Replace"
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
pub fn Decoder::split_enabled(self : Decoder) -> Bool? {
  match self {
    Metaspace(split~, ..) => Some(split)
    _ => None
  }
}

///|
pub fn Decoder::get_split(self : Decoder) -> Bool? {
  self.split_enabled()
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
    ReplaceString(content~, ..) => Some(content)
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
/// HF Python alias: `left` maps to `start` for Strip.
pub fn Decoder::left(self : Decoder) -> Int? {
  self.start()
}

///|
/// HF Python getter alias for `left`.
pub fn Decoder::get_left(self : Decoder) -> Int? {
  self.left()
}

///|
/// HF Python alias: `right` maps to `stop` for Strip.
pub fn Decoder::right(self : Decoder) -> Int? {
  self.stop()
}

///|
/// HF Python getter alias for `right`.
pub fn Decoder::get_right(self : Decoder) -> Int? {
  self.right()
}

///|
pub fn Decoder::pattern(self : Decoder) -> String? {
  match self {
    Replace(pattern~, ..) => Some(pattern)
    ReplaceString(pattern~, ..) => Some(pattern)
    _ => None
  }
}

///|
pub fn Decoder::get_pattern(self : Decoder) -> String? {
  self.pattern()
}

///|
pub fn Decoder::pattern_kind(self : Decoder) -> @common.PatternKind? {
  match self {
    Replace(..) => Some(@common.RegexPattern)
    ReplaceString(..) => Some(@common.StringPattern)
    _ => None
  }
}

///|
pub fn Decoder::get_pattern_kind(self : Decoder) -> @common.PatternKind? {
  self.pattern_kind()
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
/// Set add_prefix_space. Returns a new Decoder; only ByteLevel supports it.
pub fn Decoder::set_add_prefix_space(self : Decoder, val : Bool) -> Decoder {
  match self {
    ByteLevel(trim_offsets~, use_regex~, ..) =>
      ByteLevel(add_prefix_space=val, trim_offsets~, use_regex~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for add_prefix_space.
pub fn Decoder::set_add_prefix_space_alias(
  self : Decoder,
  val : Bool,
) -> Decoder {
  self.set_add_prefix_space(val)
}

///|
/// Set trim_offsets. Returns a new Decoder; only ByteLevel supports it.
pub fn Decoder::set_trim_offsets(self : Decoder, val : Bool) -> Decoder {
  match self {
    ByteLevel(add_prefix_space~, use_regex~, ..) =>
      ByteLevel(add_prefix_space~, trim_offsets=val, use_regex~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for trim_offsets.
pub fn Decoder::set_trim_offsets_alias(self : Decoder, val : Bool) -> Decoder {
  self.set_trim_offsets(val)
}

///|
/// Set use_regex. Returns a new Decoder; only ByteLevel supports it.
pub fn Decoder::set_use_regex(self : Decoder, val : Bool) -> Decoder {
  match self {
    ByteLevel(add_prefix_space~, trim_offsets~, ..) =>
      ByteLevel(add_prefix_space~, trim_offsets~, use_regex=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for use_regex.
pub fn Decoder::set_use_regex_alias(self : Decoder, val : Bool) -> Decoder {
  self.set_use_regex(val)
}

///|
/// Set prefix. Returns a new Decoder; only WordPiece supports it.
pub fn Decoder::set_prefix(self : Decoder, val : String) -> Decoder {
  match self {
    WordPiece(cleanup~, ..) => WordPiece(prefix=val, cleanup~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for prefix.
pub fn Decoder::set_prefix_alias(self : Decoder, val : String) -> Decoder {
  self.set_prefix(val)
}

///|
/// Set cleanup. Returns a new Decoder; WordPiece and CTC support it.
pub fn Decoder::set_cleanup(self : Decoder, val : Bool) -> Decoder {
  match self {
    WordPiece(prefix~, ..) => WordPiece(prefix~, cleanup=val)
    CTC(pad_token~, word_delimiter_token~, ..) =>
      CTC(pad_token~, word_delimiter_token~, cleanup=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for cleanup.
pub fn Decoder::set_cleanup_alias(self : Decoder, val : Bool) -> Decoder {
  self.set_cleanup(val)
}

///|
/// Set replacement. Returns a new Decoder; only Metaspace supports it.
pub fn Decoder::set_replacement(self : Decoder, val : Char) -> Decoder {
  match self {
    Metaspace(prepend_scheme~, split~, ..) =>
      Metaspace(replacement=val, prepend_scheme~, split~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for replacement.
pub fn Decoder::set_replacement_alias(self : Decoder, val : Char) -> Decoder {
  self.set_replacement(val)
}

///|
/// Set prepend_scheme. Returns a new Decoder; only Metaspace supports it.
pub fn Decoder::set_prepend_scheme(self : Decoder, val : String) -> Decoder {
  match self {
    Metaspace(replacement~, split~, ..) =>
      Metaspace(replacement~, prepend_scheme=val, split~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for prepend_scheme.
pub fn Decoder::set_prepend_scheme_alias(
  self : Decoder,
  val : String,
) -> Decoder {
  self.set_prepend_scheme(val)
}

///|
/// Set split (split_enabled). Returns a new Decoder; only Metaspace supports it.
pub fn Decoder::set_split_enabled(self : Decoder, val : Bool) -> Decoder {
  match self {
    Metaspace(replacement~, prepend_scheme~, ..) =>
      Metaspace(replacement~, prepend_scheme~, split=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for split_enabled.
pub fn Decoder::set_split_enabled_alias(self : Decoder, val : Bool) -> Decoder {
  self.set_split_enabled(val)
}

///|
/// Set suffix. Returns a new Decoder; only BPEDecoder supports it.
pub fn Decoder::set_suffix(self : Decoder, val : String) -> Decoder {
  match self {
    BPEDecoder(_) => BPEDecoder(suffix=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for suffix.
pub fn Decoder::set_suffix_alias(self : Decoder, val : String) -> Decoder {
  self.set_suffix(val)
}

///|
/// Set content. Returns a new Decoder; Replace and ReplaceString support it.
pub fn Decoder::set_content(self : Decoder, val : String) -> Decoder {
  match self {
    Replace(pattern~, ..) => Replace(pattern~, content=val)
    ReplaceString(pattern~, ..) => ReplaceString(pattern~, content=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for content.
pub fn Decoder::set_content_alias(self : Decoder, val : String) -> Decoder {
  self.set_content(val)
}

///|
/// Set start. Returns a new Decoder; only Strip supports it.
pub fn Decoder::set_start(self : Decoder, val : Int) -> Decoder {
  match self {
    Strip(content~, stop~, ..) => Strip(content~, start=val, stop~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for start.
pub fn Decoder::set_start_alias(self : Decoder, val : Int) -> Decoder {
  self.set_start(val)
}

///|
/// Set stop. Returns a new Decoder; only Strip supports it.
pub fn Decoder::set_stop(self : Decoder, val : Int) -> Decoder {
  match self {
    Strip(content~, start~, ..) => Strip(content~, start~, stop=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for stop.
pub fn Decoder::set_stop_alias(self : Decoder, val : Int) -> Decoder {
  self.set_stop(val)
}

///|
/// Set left (alias for start). Returns a new Decoder; only Strip supports it.
pub fn Decoder::set_left(self : Decoder, val : Int) -> Decoder {
  self.set_start(val)
}

///|
/// Python/property-style setter alias for left.
pub fn Decoder::set_left_alias(self : Decoder, val : Int) -> Decoder {
  self.set_left(val)
}

///|
/// Set right (alias for stop). Returns a new Decoder; only Strip supports it.
pub fn Decoder::set_right(self : Decoder, val : Int) -> Decoder {
  self.set_stop(val)
}

///|
/// Python/property-style setter alias for right.
pub fn Decoder::set_right_alias(self : Decoder, val : Int) -> Decoder {
  self.set_right(val)
}

///|
/// Set pad_token. Returns a new Decoder; only CTC supports it.
pub fn Decoder::set_pad_token(self : Decoder, val : String) -> Decoder {
  match self {
    CTC(word_delimiter_token~, cleanup~, ..) =>
      CTC(pad_token=val, word_delimiter_token~, cleanup~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for pad_token.
pub fn Decoder::set_pad_token_alias(self : Decoder, val : String) -> Decoder {
  self.set_pad_token(val)
}

///|
/// Set word_delimiter_token. Returns a new Decoder; only CTC supports it.
pub fn Decoder::set_word_delimiter_token(
  self : Decoder,
  val : String,
) -> Decoder {
  match self {
    CTC(pad_token~, cleanup~, ..) =>
      CTC(pad_token~, word_delimiter_token=val, cleanup~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for word_delimiter_token.
pub fn Decoder::set_word_delimiter_token_alias(
  self : Decoder,
  val : String,
) -> Decoder {
  self.set_word_delimiter_token(val)
}

///|
pub fn Decoder::replace(pattern : String, content : String) -> Decoder {
  ReplaceString(pattern~, content~)
}

///|
pub fn Decoder::replace_regex(pattern : String, content : String) -> Decoder {
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
  split? : Bool = true,
) -> Decoder {
  Metaspace(replacement~, prepend_scheme~, split~)
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
