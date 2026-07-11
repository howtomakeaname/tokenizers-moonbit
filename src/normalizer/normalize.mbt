// Normalization behaviour: text -> normalized text.
//
// P3 scope started with GPT-2/simple variants; this file now also routes
// Unicode NFC/NFD/NFKC/NFKD through generated normalization tables.

///|
/// Apply this normalizer to a string.
pub fn Normalizer::normalize(self : Normalizer, input : String) -> String {
  match self {
    Lowercase => to_lowercase(input)
    Strip(left~, right~) => strip(input, left, right)
    StripAccents => strip_accents(input)
    ByteLevel => byte_level_normalize(input)
    Nmt => nmt_normalize(input)
    Prepend(prepend~) => prepend + input
    Replace(pattern~, content~) => replace_all(input, pattern, content)
    ReplaceString(pattern~, content~) =>
      @common.replace_literal(input, pattern, content)
    Sequence(steps) => {
      let mut s = input
      for step in steps {
        s = step.normalize(s)
      }
      s
    }
    BertNormalizer(
      clean_text~,
      handle_chinese_chars~,
      strip_accents=sa,
      lowercase~
    ) => {
      let mut s = input
      if clean_text {
        s = bert_clean_text(s)
      }
      if handle_chinese_chars {
        s = bert_pad_chinese(s)
      }
      let should_strip_accents = match sa {
        Some(value) => value
        None => lowercase
      }
      if should_strip_accents {
        s = strip_accents(s)
      }
      if lowercase {
        s = to_lowercase(s)
      }
      s
    }
    NFC => normalize_unicode(input, compat=false, compose=true)
    NFD => normalize_unicode(input, compat=false, compose=false)
    NFKC => normalize_unicode(input, compat=true, compose=true)
    NFKD => normalize_unicode(input, compat=true, compose=false)
    // SentencePiece's common precompiled map is the NFKC charmap used by SPM
    // models, plus Unicode whitespace folding to ASCII spaces.
    Precompiled => precompiled_normalize(input)
    PrecompiledMap(data~) => precompiled_map_normalize(data, input)
  }
}

///|
/// HF Python binding-style alias for normalizing a string.
pub fn Normalizer::normalize_str(self : Normalizer, input : String) -> String {
  self.normalize(input)
}

// HF ByteLevel normalizer maps every UTF-8 byte to the reversible GPT-2
// byte-level alphabet. This is distinct from the ByteLevel pre-tokenizer: some
// tokenizer.json files put byte-level mapping in the normalizer stage.

///|
fn byte_level_normalize(s : String) -> String {
  let bytes = @utf8.encode(s)
  let sb = StringBuilder::new()
  for i in 0..<bytes.length() {
    sb.write_char(byte_to_visible_char(bytes[i].to_int()))
  }
  sb.to_string()
}

///|
fn byte_to_visible_char(b : Int) -> Char {
  if is_byte_self_mapped(b) {
    b.unsafe_to_char()
  } else {
    let mut n = 0
    for x in 0..<b {
      if !is_byte_self_mapped(x) {
        n = n + 1
      }
    }
    (256 + n).unsafe_to_char()
  }
}

///|
fn is_byte_self_mapped(b : Int) -> Bool {
  (b >= 33 && b <= 126) || (b >= 161 && b <= 172) || (b >= 174 && b <= 255)
}

// Approximation of HF's Nmt normalizer: remove format/control characters that
// should not survive tokenization and map common Unicode space separators to a
// regular ASCII space. This covers the behaviour used by common SPM pipelines;
// full category-table parity can be tightened later if a fixture requires it.

///|
fn nmt_normalize(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    let u = c.to_int()
    if u == 0 || u == 0xFFFD || is_nmt_control_or_format(u) {
      continue
    }
    if is_nmt_space(u) {
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn is_nmt_control_or_format(u : Int) -> Bool {
  // Keep tab/newline/carriage-return as whitespace; drop the rest of C0/C1 and
  // common Cf ranges such as ZWSP/BOM/variation selectors.
  ((u >= 0 && u < 0x20) && u != 0x09 && u != 0x0A && u != 0x0D) ||
  (u >= 0x7F && u <= 0x9F) ||
  (u >= 0x200B && u <= 0x200F) ||
  (u >= 0x202A && u <= 0x202E) ||
  (u >= 0x2060 && u <= 0x206F) ||
  u == 0xFEFF ||
  (u >= 0xFE00 && u <= 0xFE0F)
}

///|
fn is_nmt_space(u : Int) -> Bool {
  u == 0x09 ||
  u == 0x0A ||
  u == 0x0D ||
  u == 0x20 ||
  u == 0x85 ||
  u == 0xA0 ||
  u == 0x1680 ||
  (u >= 0x2000 && u <= 0x200A) ||
  u == 0x2028 ||
  u == 0x2029 ||
  u == 0x202F ||
  u == 0x205F ||
  u == 0x3000
}

// SentencePiece Precompiled normalizer behavior for the common SPM charmap:
// apply NFKC compatibility normalization, then map every Unicode whitespace
// scalar to one ASCII space. Unlike Strip/Bert cleanup this does not collapse
// runs: tabs/newlines/NBSP each become their own space, matching HF's bundled
// `precompiled_charsmap` used by T5/ALBERT/XLM-R/DeBERTa-style models.

///|
