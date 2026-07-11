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
  ReplaceString(pattern~ : String, content~ : String)
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
    strip_accents~ : Bool?,
    lowercase~ : Bool
  )
  Sequence(Array[Normalizer])
}

///|
/// JSON-backed component state used by thin binding layers.
pub struct NormalizerState {
  json : String
} derive(Debug, Eq)

///|
pub fn NormalizerState::new(json : String) -> NormalizerState {
  { json, }
}

///|
/// Return the normalizer family name used by thin binding layers.
pub fn Normalizer::kind(self : Normalizer) -> String {
  match self {
    NFC => "NFC"
    NFD => "NFD"
    NFKC => "NFKC"
    NFKD => "NFKD"
    Lowercase => "Lowercase"
    Strip(..) => "Strip"
    StripAccents => "StripAccents"
    ByteLevel => "ByteLevel"
    Replace(..) | ReplaceString(..) => "Replace"
    Prepend(..) => "Prepend"
    Nmt => "Nmt"
    Precompiled | PrecompiledMap(..) => "Precompiled"
    BertNormalizer(..) => "BertNormalizer"
    Sequence(_) => "Sequence"
  }
}

///|
pub fn Normalizer::strip_left(self : Normalizer) -> Bool? {
  match self {
    Strip(left~, ..) => Some(left)
    _ => None
  }
}

///|
pub fn Normalizer::get_strip_left(self : Normalizer) -> Bool? {
  self.strip_left()
}

///|
/// HF/Python property-style alias for `Strip.left`.
pub fn Normalizer::left(self : Normalizer) -> Bool? {
  self.strip_left()
}

///|
pub fn Normalizer::strip_right(self : Normalizer) -> Bool? {
  match self {
    Strip(right~, ..) => Some(right)
    _ => None
  }
}

///|
pub fn Normalizer::get_strip_right(self : Normalizer) -> Bool? {
  self.strip_right()
}

///|
/// HF/Python property-style alias for `Strip.right`.
pub fn Normalizer::right(self : Normalizer) -> Bool? {
  self.strip_right()
}

///|
pub fn Normalizer::pattern(self : Normalizer) -> String? {
  match self {
    Replace(pattern~, ..) => Some(pattern)
    ReplaceString(pattern~, ..) => Some(pattern)
    _ => None
  }
}

///|
pub fn Normalizer::get_pattern(self : Normalizer) -> String? {
  self.pattern()
}

///|
pub fn Normalizer::pattern_kind(self : Normalizer) -> @common.PatternKind? {
  match self {
    Replace(..) => Some(@common.RegexPattern)
    ReplaceString(..) => Some(@common.StringPattern)
    _ => None
  }
}

///|
pub fn Normalizer::get_pattern_kind(self : Normalizer) -> @common.PatternKind? {
  self.pattern_kind()
}

///|
pub fn Normalizer::content(self : Normalizer) -> String? {
  match self {
    Replace(content~, ..) => Some(content)
    ReplaceString(content~, ..) => Some(content)
    _ => None
  }
}

///|
pub fn Normalizer::get_content(self : Normalizer) -> String? {
  self.content()
}

///|
pub fn Normalizer::prepend(self : Normalizer) -> String? {
  match self {
    Prepend(prepend~) => Some(prepend)
    _ => None
  }
}

///|
pub fn Normalizer::get_prepend(self : Normalizer) -> String? {
  self.prepend()
}

///|
pub fn Normalizer::clean_text(self : Normalizer) -> Bool? {
  match self {
    BertNormalizer(clean_text~, ..) => Some(clean_text)
    _ => None
  }
}

///|
pub fn Normalizer::get_clean_text(self : Normalizer) -> Bool? {
  self.clean_text()
}

///|
pub fn Normalizer::handle_chinese_chars(self : Normalizer) -> Bool? {
  match self {
    BertNormalizer(handle_chinese_chars~, ..) => Some(handle_chinese_chars)
    _ => None
  }
}

///|
pub fn Normalizer::get_handle_chinese_chars(self : Normalizer) -> Bool? {
  self.handle_chinese_chars()
}

///|
pub fn Normalizer::strip_accents(self : Normalizer) -> Bool? {
  match self {
    BertNormalizer(strip_accents~, ..) => strip_accents
    _ => None
  }
}

///|
pub fn Normalizer::get_strip_accents(self : Normalizer) -> Bool? {
  self.strip_accents()
}

///|
pub fn Normalizer::lowercase(self : Normalizer) -> Bool? {
  match self {
    BertNormalizer(lowercase~, ..) => Some(lowercase)
    _ => None
  }
}

///|
pub fn Normalizer::get_lowercase(self : Normalizer) -> Bool? {
  self.lowercase()
}

///|
pub fn Normalizer::normalizers(self : Normalizer) -> Array[Normalizer] {
  match self {
    Sequence(steps) => steps.copy()
    _ => []
  }
}

///|
/// HF/Python getter alias for Sequence child normalizers.
pub fn Normalizer::get_normalizers(self : Normalizer) -> Array[Normalizer] {
  self.normalizers()
}

///|
pub fn Normalizer::__len__(self : Normalizer) -> Int {
  match self {
    Sequence(steps) => steps.length()
    _ => 0
  }
}

///|
pub fn Normalizer::get_item(self : Normalizer, index : Int) -> Normalizer? {
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
pub fn Normalizer::__getitem__(self : Normalizer, index : Int) -> Normalizer? {
  self.get_item(index)
}

///|
pub fn Normalizer::nfc() -> Normalizer {
  NFC
}

///|
pub fn Normalizer::nfd() -> Normalizer {
  NFD
}

///|
pub fn Normalizer::nfkc() -> Normalizer {
  NFKC
}

///|
pub fn Normalizer::nfkd() -> Normalizer {
  NFKD
}

///|
pub fn Normalizer::byte_level() -> Normalizer {
  ByteLevel
}

///|
pub fn Normalizer::lowercase_normalizer() -> Normalizer {
  Lowercase
}

///|
pub fn Normalizer::strip_accents_normalizer() -> Normalizer {
  StripAccents
}

///|
pub fn Normalizer::nmt() -> Normalizer {
  Nmt
}

///|
pub fn Normalizer::precompiled() -> Normalizer {
  Precompiled
}

///|
pub fn Normalizer::strip(
  left? : Bool = true,
  right? : Bool = true,
) -> Normalizer {
  Strip(left~, right~)
}

///|
pub fn Normalizer::replace(pattern : String, content : String) -> Normalizer {
  ReplaceString(pattern~, content~)
}

///|
pub fn Normalizer::replace_regex(
  pattern : String,
  content : String,
) -> Normalizer {
  Replace(pattern~, content~)
}

///|
pub fn Normalizer::prepend_normalizer(prepend : String) -> Normalizer {
  Prepend(prepend~)
}

///|
pub fn Normalizer::bert_normalizer(
  clean_text? : Bool = true,
  handle_chinese_chars? : Bool = true,
  strip_accents? : Bool? = None,
  lowercase? : Bool = true,
) -> Normalizer {
  BertNormalizer(clean_text~, handle_chinese_chars~, strip_accents~, lowercase~)
}

///|
pub fn Normalizer::sequence(normalizers : Array[Normalizer]) -> Normalizer {
  Sequence(normalizers)
}

///|

///|
/// Set left (strip from start). Returns a new Normalizer; only Strip supports it.
pub fn Normalizer::set_left(self : Normalizer, val : Bool) -> Normalizer {
  match self {
    Strip(right~, ..) => Strip(left=val, right~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for left.
pub fn Normalizer::set_left_alias(self : Normalizer, val : Bool) -> Normalizer {
  self.set_left(val)
}

///|
/// Set right (strip from end). Returns a new Normalizer; only Strip supports it.
pub fn Normalizer::set_right(self : Normalizer, val : Bool) -> Normalizer {
  match self {
    Strip(left~, ..) => Strip(left~, right=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for right.
pub fn Normalizer::set_right_alias(self : Normalizer, val : Bool) -> Normalizer {
  self.set_right(val)
}

///|
/// Set clean_text. Returns a new Normalizer; only BertNormalizer supports it.
pub fn Normalizer::set_clean_text(self : Normalizer, val : Bool) -> Normalizer {
  match self {
    BertNormalizer(handle_chinese_chars~, strip_accents~, lowercase~, ..) =>
      BertNormalizer(
        clean_text=val,
        handle_chinese_chars~,
        strip_accents~,
        lowercase~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for clean_text.
pub fn Normalizer::set_clean_text_alias(
  self : Normalizer,
  val : Bool,
) -> Normalizer {
  self.set_clean_text(val)
}

///|
/// Set handle_chinese_chars. Returns a new Normalizer; only BertNormalizer supports it.
pub fn Normalizer::set_handle_chinese_chars(
  self : Normalizer,
  val : Bool,
) -> Normalizer {
  match self {
    BertNormalizer(clean_text~, strip_accents~, lowercase~, ..) =>
      BertNormalizer(
        clean_text~,
        handle_chinese_chars=val,
        strip_accents~,
        lowercase~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for handle_chinese_chars.
pub fn Normalizer::set_handle_chinese_chars_alias(
  self : Normalizer,
  val : Bool,
) -> Normalizer {
  self.set_handle_chinese_chars(val)
}

///|
/// Set strip_accents. Returns a new Normalizer; only BertNormalizer supports it.
pub fn Normalizer::set_strip_accents(
  self : Normalizer,
  val : Bool?,
) -> Normalizer {
  match self {
    BertNormalizer(clean_text~, handle_chinese_chars~, lowercase~, ..) =>
      BertNormalizer(
        clean_text~,
        handle_chinese_chars~,
        strip_accents=val,
        lowercase~,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for strip_accents.
pub fn Normalizer::set_strip_accents_alias(
  self : Normalizer,
  val : Bool?,
) -> Normalizer {
  self.set_strip_accents(val)
}

///|
/// Set lowercase. Returns a new Normalizer; only BertNormalizer supports it.
pub fn Normalizer::set_lowercase(self : Normalizer, val : Bool) -> Normalizer {
  match self {
    BertNormalizer(clean_text~, handle_chinese_chars~, strip_accents~, ..) =>
      BertNormalizer(
        clean_text~,
        handle_chinese_chars~,
        strip_accents~,
        lowercase=val,
      )
    _ => self
  }
}

///|
/// Python/property-style setter alias for lowercase.
pub fn Normalizer::set_lowercase_alias(
  self : Normalizer,
  val : Bool,
) -> Normalizer {
  self.set_lowercase(val)
}

///|
/// Set prepend string. Returns a new Normalizer; only Prepend supports it.
pub fn Normalizer::set_prepend(self : Normalizer, val : String) -> Normalizer {
  match self {
    Prepend(..) => Prepend(prepend=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for prepend.
pub fn Normalizer::set_prepend_alias(
  self : Normalizer,
  val : String,
) -> Normalizer {
  self.set_prepend(val)
}

///|
/// Set content for Replace/ReplaceString. Returns a new Normalizer.
pub fn Normalizer::set_content(self : Normalizer, val : String) -> Normalizer {
  match self {
    Replace(pattern~, ..) => Replace(pattern~, content=val)
    ReplaceString(pattern~, ..) => ReplaceString(pattern~, content=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for content.
pub fn Normalizer::set_content_alias(
  self : Normalizer,
  val : String,
) -> Normalizer {
  self.set_content(val)
}

///|
