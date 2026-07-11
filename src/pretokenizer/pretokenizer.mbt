// The `pre_tokenizer` stage: splits normalized text into word-like pieces
// before the model runs.
//
// P1 scope: enum + deserialization. `pre_tokenize` behaviour lands in P3
// (ByteLevel/GPT-2) and P5/P6/P7 (the rest).

///|
/// How a Split pre-tokenizer treats the matched delimiter.
pub enum SplitBehavior {
  Removed
  Isolated
  MergedWithPrevious
  MergedWithNext
  Contiguous
} derive(Eq, Debug)

///|
pub enum PreTokenizer {
  ByteLevel(add_prefix_space~ : Bool, use_regex~ : Bool, trim_offsets~ : Bool)
  Whitespace
  WhitespaceSplit
  Metaspace(replacement~ : Char, prepend_scheme~ : String, split~ : Bool)
  Punctuation(behavior~ : SplitBehavior)
  Split(
    pattern~ : String,
    behavior~ : SplitBehavior,
    invert~ : Bool,
    regex~ : Bool
  )
  BertPreTokenizer
  Digits(individual_digits~ : Bool)
  Delimiter(delimiter~ : Char)
  FixedLength(length~ : Int)
  UnicodeScripts
  Sequence(Array[PreTokenizer])
}

///|
/// JSON-backed component state used by thin binding layers.
pub struct PreTokenizerState {
  json : String
} derive(Debug, Eq)

///|
pub fn PreTokenizerState::new(json : String) -> PreTokenizerState {
  { json, }
}

///|
/// Return the pre-tokenizer family name used by thin binding layers.
pub fn PreTokenizer::kind(self : PreTokenizer) -> String {
  match self {
    ByteLevel(..) => "ByteLevel"
    Whitespace => "Whitespace"
    WhitespaceSplit => "WhitespaceSplit"
    Metaspace(..) => "Metaspace"
    Punctuation(..) => "Punctuation"
    Split(..) => "Split"
    BertPreTokenizer => "BertPreTokenizer"
    Digits(..) => "Digits"
    Delimiter(..) => "Delimiter"
    FixedLength(..) => "FixedLength"
    UnicodeScripts => "UnicodeScripts"
    Sequence(_) => "Sequence"
  }
}

///|

///|
/// Set add_prefix_space. Returns a new PreTokenizer; only ByteLevel supports it.
pub fn PreTokenizer::set_add_prefix_space(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  match self {
    ByteLevel(use_regex~, trim_offsets~, ..) =>
      ByteLevel(add_prefix_space=val, use_regex~, trim_offsets~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for add_prefix_space.
pub fn PreTokenizer::set_add_prefix_space_alias(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  self.set_add_prefix_space(val)
}

///|
/// Set use_regex. Returns a new PreTokenizer; only ByteLevel supports it.
pub fn PreTokenizer::set_use_regex(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  match self {
    ByteLevel(add_prefix_space~, trim_offsets~, ..) =>
      ByteLevel(add_prefix_space~, use_regex=val, trim_offsets~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for use_regex.
pub fn PreTokenizer::set_use_regex_alias(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  self.set_use_regex(val)
}

///|
/// Set trim_offsets. Returns a new PreTokenizer; only ByteLevel supports it.
pub fn PreTokenizer::set_trim_offsets(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  match self {
    ByteLevel(add_prefix_space~, use_regex~, ..) =>
      ByteLevel(add_prefix_space~, use_regex~, trim_offsets=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for trim_offsets.
pub fn PreTokenizer::set_trim_offsets_alias(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  self.set_trim_offsets(val)
}

///|
/// Set replacement. Returns a new PreTokenizer; only Metaspace supports it.
pub fn PreTokenizer::set_replacement(
  self : PreTokenizer,
  val : Char,
) -> PreTokenizer {
  match self {
    Metaspace(prepend_scheme~, split~, ..) =>
      Metaspace(replacement=val, prepend_scheme~, split~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for replacement.
pub fn PreTokenizer::set_replacement_alias(
  self : PreTokenizer,
  val : Char,
) -> PreTokenizer {
  self.set_replacement(val)
}

///|
/// Set prepend_scheme. Returns a new PreTokenizer; only Metaspace supports it.
pub fn PreTokenizer::set_prepend_scheme(
  self : PreTokenizer,
  val : String,
) -> PreTokenizer {
  match self {
    Metaspace(replacement~, split~, ..) =>
      Metaspace(replacement~, prepend_scheme=val, split~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for prepend_scheme.
pub fn PreTokenizer::set_prepend_scheme_alias(
  self : PreTokenizer,
  val : String,
) -> PreTokenizer {
  self.set_prepend_scheme(val)
}

///|
/// Set split. Returns a new PreTokenizer; only Metaspace supports it.
pub fn PreTokenizer::set_split_enabled(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  match self {
    Metaspace(replacement~, prepend_scheme~, ..) =>
      Metaspace(replacement~, prepend_scheme~, split=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for split.
pub fn PreTokenizer::set_split_alias(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  self.set_split_enabled(val)
}

///|
/// Set delimiter. Returns a new PreTokenizer; only CharDelimiterSplit supports it.
pub fn PreTokenizer::set_delimiter(
  self : PreTokenizer,
  val : Char,
) -> PreTokenizer {
  match self {
    Delimiter(..) => Delimiter(delimiter=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for delimiter.
pub fn PreTokenizer::set_delimiter_alias(
  self : PreTokenizer,
  val : Char,
) -> PreTokenizer {
  self.set_delimiter(val)
}

///|
/// Set individual_digits. Returns a new PreTokenizer; only Digits supports it.
pub fn PreTokenizer::set_individual_digits(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  match self {
    Digits(..) => Digits(individual_digits=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for individual_digits.
pub fn PreTokenizer::set_individual_digits_alias(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  self.set_individual_digits(val)
}

///|
/// Set length. Returns a new PreTokenizer; only FixedLength supports it.
pub fn PreTokenizer::set_length(self : PreTokenizer, val : Int) -> PreTokenizer {
  match self {
    FixedLength(..) => FixedLength(length=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for length.
pub fn PreTokenizer::set_length_alias(
  self : PreTokenizer,
  val : Int,
) -> PreTokenizer {
  self.set_length(val)
}

///|
/// Set behavior. Returns a new PreTokenizer; only Split/Punctuation support it.
pub fn PreTokenizer::set_behavior(
  self : PreTokenizer,
  val : SplitBehavior,
) -> PreTokenizer {
  match self {
    Split(pattern~, invert~, regex~, ..) =>
      Split(pattern~, behavior=val, invert~, regex~)
    Punctuation(..) => Punctuation(behavior=val)
    _ => self
  }
}

///|
/// Python/property-style setter alias for behavior.
pub fn PreTokenizer::set_behavior_alias(
  self : PreTokenizer,
  val : SplitBehavior,
) -> PreTokenizer {
  self.set_behavior(val)
}

///|
/// Set invert. Returns a new PreTokenizer; only Split supports it.
pub fn PreTokenizer::set_invert(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  match self {
    Split(pattern~, behavior~, regex~, ..) =>
      Split(pattern~, behavior~, invert=val, regex~)
    _ => self
  }
}

///|
/// Python/property-style setter alias for invert.
pub fn PreTokenizer::set_invert_alias(
  self : PreTokenizer,
  val : Bool,
) -> PreTokenizer {
  self.set_invert(val)
}

///|
pub fn PreTokenizer::get_state(
  self : PreTokenizer,
) -> PreTokenizerState raise @types.TokenizerError {
  { json: self.state_json() }
}

///|
pub fn PreTokenizer::from_state(
  state : PreTokenizerState,
) -> PreTokenizer raise @types.TokenizerError {
  let parsed = @json.parse(state.json) catch {
    err => raise @types.ParseError("invalid pre-tokenizer state: \{err}")
  }
  PreTokenizer::from_json(parsed)
}

///|
pub fn PreTokenizer::__getstate__(
  self : PreTokenizer,
) -> PreTokenizerState raise @types.TokenizerError {
  self.get_state()
}

///|
pub fn PreTokenizer::__setstate__(
  state : PreTokenizerState,
) -> PreTokenizer raise @types.TokenizerError {
  PreTokenizer::from_state(state)
}

///|
pub fn PreTokenizer::__str__(
  self : PreTokenizer,
) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
pub fn PreTokenizer::__repr__(
  self : PreTokenizer,
) -> String raise @types.TokenizerError {
  self.state_json()
}

///|
fn PreTokenizer::state_json(
  self : PreTokenizer,
) -> String raise @types.TokenizerError {
  match self.to_json() {
    Some(json) => json
    None =>
      raise @types.UnsupportedComponent("pre_tokenizer has no serialized state")
  }
}

///|
pub fn PreTokenizer::add_prefix_space(self : PreTokenizer) -> Bool? {
  match self {
    ByteLevel(add_prefix_space~, ..) => Some(add_prefix_space)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_add_prefix_space(self : PreTokenizer) -> Bool? {
  self.add_prefix_space()
}

///|
pub fn PreTokenizer::use_regex(self : PreTokenizer) -> Bool? {
  match self {
    ByteLevel(use_regex~, ..) => Some(use_regex)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_use_regex(self : PreTokenizer) -> Bool? {
  self.use_regex()
}

///|
pub fn PreTokenizer::trim_offsets(self : PreTokenizer) -> Bool? {
  match self {
    ByteLevel(trim_offsets~, ..) => Some(trim_offsets)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_trim_offsets(self : PreTokenizer) -> Bool? {
  self.trim_offsets()
}

///|
pub fn PreTokenizer::replacement(self : PreTokenizer) -> Char? {
  match self {
    Metaspace(replacement~, ..) => Some(replacement)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_replacement(self : PreTokenizer) -> Char? {
  self.replacement()
}

///|
pub fn PreTokenizer::prepend_scheme(self : PreTokenizer) -> String? {
  match self {
    Metaspace(prepend_scheme~, ..) => Some(prepend_scheme)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_prepend_scheme(self : PreTokenizer) -> String? {
  self.prepend_scheme()
}

///|
pub fn PreTokenizer::split_enabled(self : PreTokenizer) -> Bool? {
  match self {
    Metaspace(split~, ..) => Some(split)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_split(self : PreTokenizer) -> Bool? {
  self.split_enabled()
}

///|
pub fn PreTokenizer::behavior(self : PreTokenizer) -> SplitBehavior? {
  match self {
    Punctuation(behavior~) => Some(behavior)
    Split(behavior~, ..) => Some(behavior)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_behavior(self : PreTokenizer) -> SplitBehavior? {
  self.behavior()
}

///|
pub fn PreTokenizer::pattern(self : PreTokenizer) -> String? {
  match self {
    Split(pattern~, ..) => Some(pattern)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_pattern(self : PreTokenizer) -> String? {
  self.pattern()
}

///|
pub fn PreTokenizer::invert(self : PreTokenizer) -> Bool? {
  match self {
    Split(invert~, ..) => Some(invert)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_invert(self : PreTokenizer) -> Bool? {
  self.invert()
}

///|
pub fn PreTokenizer::regex(self : PreTokenizer) -> Bool? {
  match self {
    Split(regex~, ..) => Some(regex)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_regex(self : PreTokenizer) -> Bool? {
  self.regex()
}

///|
pub fn PreTokenizer::individual_digits(self : PreTokenizer) -> Bool? {
  match self {
    Digits(individual_digits~) => Some(individual_digits)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_individual_digits(self : PreTokenizer) -> Bool? {
  self.individual_digits()
}

///|
pub fn PreTokenizer::delimiter(self : PreTokenizer) -> Char? {
  match self {
    Delimiter(delimiter~) => Some(delimiter)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_delimiter(self : PreTokenizer) -> Char? {
  self.delimiter()
}

///|
pub fn PreTokenizer::length(self : PreTokenizer) -> Int? {
  match self {
    FixedLength(length~) => Some(length)
    _ => None
  }
}

///|
pub fn PreTokenizer::get_length(self : PreTokenizer) -> Int? {
  self.length()
}

///|
pub fn PreTokenizer::pre_tokenizers(self : PreTokenizer) -> Array[PreTokenizer] {
  match self {
    Sequence(steps) => steps.copy()
    _ => []
  }
}

///|
/// HF/Python getter alias for Sequence child pre-tokenizers.
pub fn PreTokenizer::get_pre_tokenizers(
  self : PreTokenizer,
) -> Array[PreTokenizer] {
  self.pre_tokenizers()
}

///|
pub fn PreTokenizer::__len__(self : PreTokenizer) -> Int {
  match self {
    Sequence(steps) => steps.length()
    _ => 0
  }
}

///|
pub fn PreTokenizer::get_item(
  self : PreTokenizer,
  index : Int,
) -> PreTokenizer? {
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
pub fn PreTokenizer::__getitem__(
  self : PreTokenizer,
  index : Int,
) -> PreTokenizer? {
  self.get_item(index)
}

///|
/// Public constructor for a WhitespaceSplit pre-tokenizer, used by higher-level
/// training helpers without exposing cross-package enum construction details.
pub fn PreTokenizer::whitespace_split() -> PreTokenizer {
  WhitespaceSplit
}

///|
pub fn PreTokenizer::whitespace() -> PreTokenizer {
  Whitespace
}

///|
pub fn PreTokenizer::bert_pre_tokenizer() -> PreTokenizer {
  BertPreTokenizer
}

///|
pub fn PreTokenizer::metaspace(
  replacement? : Char = '▁',
  prepend_scheme? : String = "always",
  split? : Bool = true,
) -> PreTokenizer {
  Metaspace(replacement~, prepend_scheme~, split~)
}

///|
pub fn PreTokenizer::punctuation(
  behavior? : SplitBehavior = Isolated,
) -> PreTokenizer {
  Punctuation(behavior~)
}

///|
pub fn PreTokenizer::digits(individual_digits? : Bool = false) -> PreTokenizer {
  Digits(individual_digits~)
}

///|
pub fn PreTokenizer::char_delimiter_split(delimiter : Char) -> PreTokenizer {
  Delimiter(delimiter~)
}

///|
pub fn PreTokenizer::fixed_length(length? : Int = 5) -> PreTokenizer {
  FixedLength(length~)
}

///|
pub fn PreTokenizer::unicode_scripts() -> PreTokenizer {
  UnicodeScripts
}

///|
pub fn PreTokenizer::sequence(
  pre_tokenizers : Array[PreTokenizer],
) -> PreTokenizer {
  Sequence(pre_tokenizers)
}

///|
/// Public constructor for GPT-2/RoBERTa style ByteLevel pre-tokenization.
pub fn PreTokenizer::byte_level(
  add_prefix_space? : Bool = true,
  use_regex? : Bool = true,
  trim_offsets? : Bool = true,
) -> PreTokenizer {
  ByteLevel(add_prefix_space~, use_regex~, trim_offsets~)
}

///|
pub fn SplitBehavior::removed() -> SplitBehavior {
  Removed
}

///|
pub fn SplitBehavior::isolated() -> SplitBehavior {
  Isolated
}

///|
pub fn SplitBehavior::contiguous() -> SplitBehavior {
  Contiguous
}

///|
pub fn SplitBehavior::merged_with_previous() -> SplitBehavior {
  MergedWithPrevious
}

///|
pub fn SplitBehavior::merged_with_next() -> SplitBehavior {
  MergedWithNext
}

///|
pub fn PreTokenizer::split(
  pattern : String,
  behavior : SplitBehavior,
  invert? : Bool = false,
  regex? : Bool = false,
) -> PreTokenizer {
  Split(pattern~, behavior~, invert~, regex~)
}

///|
/// Serialize simple pre-tokenizers created through the training API.
