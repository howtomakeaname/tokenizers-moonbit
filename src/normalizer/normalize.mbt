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
      if sa {
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
  }
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
fn precompiled_normalize(s : String) -> String {
  let sb = StringBuilder::new()
  let normalized = normalize_unicode(s, compat=true, compose=true)
  for c in normalized {
    if @common.is_ascii_whitespace(c) {
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

// strip_accents: remove combining marks via the precomputed NFD-minus-Mn table.

///|
fn strip_accents(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    let cp = c.to_int()
    if is_combining_mark(cp) {
      continue
    }
    match accent_map().get(cp) {
      Some(stripped) => sb.write_string(stripped)
      None => sb.write_char(c)
    }
  }
  sb.to_string()
}

// HF StripAccents is NFD then drop Unicode category Mn. The precomputed
// `accent_map` covers precomposed characters such as é -> e. This predicate
// additionally drops already-decomposed combining marks, which is required when
// StripAccents follows NFKD in tokenizer.json (e.g. ALBERT).

///|
fn is_combining_mark(cp : Int) -> Bool {
  (cp >= 0x0300 && cp <= 0x036F) ||
  (cp >= 0x1AB0 && cp <= 0x1AFF) ||
  (cp >= 0x1DC0 && cp <= 0x1DFF) ||
  (cp >= 0x20D0 && cp <= 0x20FF) ||
  (cp >= 0xFE20 && cp <= 0xFE2F)
}

// Lazily-built map: code point -> accent-stripped form.

///|
let accent_map_cache : Ref[Map[Int, String]?] = { val: None }

///|
fn accent_map() -> Map[Int, String] {
  match accent_map_cache.val {
    Some(m) => m
    None => {
      let m : Map[Int, String] = {}
      for e in accent_entries() {
        m[e.0] = e.1
      }
      accent_map_cache.val = Some(m)
      m
    }
  }
}

// BertNormalizer clean_text: drop control chars and 0xFFFD, map whitespace to
// a single space.

///|
fn bert_clean_text(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    let u = c.to_int()
    if u == 0 || u == 0xFFFD || is_control(c) {
      continue
    }
    if @common.is_ascii_whitespace(c) {
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

// BertNormalizer handle_chinese_chars: surround each CJK char with spaces.

///|
fn bert_pad_chinese(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    if is_chinese_char(c) {
      sb.write_char(' ')
      sb.write_char(c)
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn is_control(c : Char) -> Bool {
  // \t \n \r are treated as whitespace, not control, by BERT.
  if c == '\t' || c == '\n' || c == '\r' {
    return false
  }
  let u = c.to_int()
  (u >= 0 && u < 0x20) || u == 0x7F
}

///|
fn is_chinese_char(c : Char) -> Bool {
  let u = c.to_int()
  (u >= 0x4E00 && u <= 0x9FFF) ||
  (u >= 0x3400 && u <= 0x4DBF) ||
  (u >= 0x20000 && u <= 0x2A6DF) ||
  (u >= 0xF900 && u <= 0xFAFF)
}

///|
fn to_lowercase(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    sb.write_char(c.to_ascii_lowercase())
  }
  sb.to_string()
}

///|
fn strip(s : String, left : Bool, right : Bool) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let mut start = 0
  let mut stop = n
  if left {
    while start < stop && @common.is_ascii_whitespace(chars[start]) {
      start = start + 1
    }
  }
  if right {
    while stop > start && @common.is_ascii_whitespace(chars[stop - 1]) {
      stop = stop - 1
    }
  }
  let sb = StringBuilder::new()
  for k in start..<stop {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

// Replacement for HF Replace. Common Regex patterns used by SPM tokenizers are
// handled explicitly; otherwise this falls back to literal substring replace.

///|
fn replace_all(s : String, pattern : String, content : String) -> String {
  if pattern.is_empty() {
    return s
  }
  match @common.replace_bounded_simple_regex(s, pattern, content) {
    Some(out) => return out
    None => ()
  }
  if pattern == " {2,}" {
    return @common.replace_space_runs(s, content, min_run=2)
  }
  if pattern == "\\s{2,}" || pattern == "[\\s]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=2,
    )
  }
  if pattern == "\\s{3,}" || pattern == "[\\s]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=3,
    )
  }
  if pattern == "\\s{4,}" || pattern == "[\\s]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      min_run=4,
    )
  }
  if pattern == "\\s{2}" || pattern == "[\\s]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      exact_run=2,
    )
  }
  if pattern == "\\s{3}" || pattern == "[\\s]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      exact_run=3,
    )
  }
  if pattern == "\\s{4}" || pattern == "[\\s]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_whitespace(c.to_int()) },
      exact_run=4,
    )
  }
  if pattern == "^\\s+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  if pattern == "\\s+" {
    return @common.replace_whitespace_runs(s, content)
  }
  if pattern == "\\s+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  if pattern == "[\\r\\n]+" || pattern == "[\r\n]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      c == '\r' || c == '\n'
    })
  }
  if pattern == "[\\r\\n]{2,}" || pattern == "[\r\n]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      min_run=2,
    )
  }
  if pattern == "[\\r\\n]{3,}" || pattern == "[\r\n]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      min_run=3,
    )
  }
  if pattern == "[\\r\\n]{4,}" || pattern == "[\r\n]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      min_run=4,
    )
  }
  if pattern == "[\\r\\n]{2}" || pattern == "[\r\n]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      exact_run=2,
    )
  }
  if pattern == "[\\r\\n]{3}" || pattern == "[\r\n]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      exact_run=3,
    )
  }
  if pattern == "[\\r\\n]{4}" || pattern == "[\r\n]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == '\r' || c == '\n' },
      exact_run=4,
    )
  }
  if pattern == "\\d+" ||
    pattern == "[\\d]+" ||
    pattern == "[0-9]+" ||
    pattern == "\\p{N}+" ||
    pattern == "\\p{Number}+" ||
    pattern == "[\\p{N}]+" ||
    pattern == "[\\p{Number}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "^\\d+" ||
    pattern == "^[\\d]+" ||
    pattern == "^[0-9]+" ||
    pattern == "^\\p{N}+" ||
    pattern == "^\\p{Number}+" ||
    pattern == "^[\\p{N}]+" ||
    pattern == "^[\\p{Number}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "\\d+$" ||
    pattern == "[\\d]+$" ||
    pattern == "[0-9]+$" ||
    pattern == "\\p{N}+$" ||
    pattern == "\\p{Number}+$" ||
    pattern == "[\\p{N}]+$" ||
    pattern == "[\\p{Number}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "\\D+" ||
    pattern == "[\\D]+" ||
    pattern == "[^\\d]+" ||
    pattern == "[^0-9]+" ||
    pattern == "\\P{N}+" ||
    pattern == "\\P{Number}+" ||
    pattern == "[^\\p{N}]+" ||
    pattern == "[^\\p{Number}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_decimal_number(c)
    })
  }
  if pattern == "\\d{2,}" ||
    pattern == "[\\d]{2,}" ||
    pattern == "[0-9]{2,}" ||
    pattern == "\\p{N}{2,}" ||
    pattern == "\\p{Number}{2,}" ||
    pattern == "[\\p{N}]{2,}" ||
    pattern == "[\\p{Number}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{N}{2}" ||
    pattern == "\\p{Number}{2}" ||
    pattern == "[\\p{N}]{2}" ||
    pattern == "[\\p{Number}]{2}" ||
    pattern == "\\d{2}" ||
    pattern == "[\\d]{2}" ||
    pattern == "[0-9]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{N}{3}" ||
    pattern == "\\p{Number}{3}" ||
    pattern == "[\\p{N}]{3}" ||
    pattern == "[\\p{Number}]{3}" ||
    pattern == "\\d{3}" ||
    pattern == "[\\d]{3}" ||
    pattern == "[0-9]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{N}{4}" ||
    pattern == "\\p{Number}{4}" ||
    pattern == "[\\p{N}]{4}" ||
    pattern == "[\\p{Number}]{4}" ||
    pattern == "\\d{4}" ||
    pattern == "[\\d]{4}" ||
    pattern == "[0-9]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      exact_run=4,
    )
  }
  if pattern == "\\p{N}{1,3}" ||
    pattern == "\\p{Number}{1,3}" ||
    pattern == "[\\p{N}]{1,3}" ||
    pattern == "[\\p{Number}]{1,3}" ||
    pattern == "\\d{1,3}" ||
    pattern == "[\\d]{1,3}" ||
    pattern == "[0-9]{1,3}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      max_run=3,
    )
  }
  if pattern == "\\d{1,2}" || pattern == "[\\d]{1,2}" || pattern == "[0-9]{1,2}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      max_run=2,
    )
  }
  if pattern == "\\d{1,4}" || pattern == "[\\d]{1,4}" || pattern == "[0-9]{1,4}" {
    return @common.replace_bounded_char_runs(
      s,
      content,
      fn(c) { @common.is_decimal_number(c) },
      max_run=4,
    )
  }
  if pattern == "[ \\t]+" {
    return @common.replace_char_runs(s, content, fn(c) { c == ' ' || c == '\t' })
  }
  if pattern == "[ \\t]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      min_run=2,
    )
  }
  if pattern == "[ \\t]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      min_run=3,
    )
  }
  if pattern == "[ \\t]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      min_run=4,
    )
  }
  if pattern == "[ \\t]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      exact_run=2,
    )
  }
  if pattern == "[ \\t]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      exact_run=3,
    )
  }
  if pattern == "[ \\t]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { c == ' ' || c == '\t' },
      exact_run=4,
    )
  }
  if pattern == "\\w+" ||
    pattern == "[A-Za-z0-9_]+" ||
    pattern == "\\b\\w+\\b" ||
    pattern == "\\b[A-Za-z0-9_]+\\b" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_word_char(c)
    })
  }
  if pattern == "^\\w+" || pattern == "^[A-Za-z0-9_]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_word_char(c)
    })
  }
  if pattern == "\\w+$" || pattern == "[A-Za-z0-9_]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_word_char(c)
    })
  }
  if pattern == "\\W+" || pattern == "[^\\w]+" || pattern == "[^A-Za-z0-9_]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_word_char(c)
    })
  }
  if pattern == "\\w{2,}" || pattern == "[A-Za-z0-9_]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      min_run=2,
    )
  }
  if pattern == "\\w{2}" || pattern == "[A-Za-z0-9_]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      exact_run=2,
    )
  }
  if pattern == "\\w{3}" || pattern == "[A-Za-z0-9_]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      exact_run=3,
    )
  }
  if pattern == "\\w{4}" || pattern == "[A-Za-z0-9_]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_word_char(c) },
      exact_run=4,
    )
  }
  if pattern == "[A-Za-z0-9]+" || pattern == "[a-zA-Z0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
  }
  if pattern == "[A-Za-z0-9]{2,}" || pattern == "[a-zA-Z0-9]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      min_run=2,
    )
  }
  if pattern == "[A-Za-z0-9]{2}" || pattern == "[a-zA-Z0-9]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      exact_run=2,
    )
  }
  if pattern == "[A-Za-z0-9]{3}" || pattern == "[a-zA-Z0-9]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      exact_run=3,
    )
  }
  if pattern == "[A-Za-z0-9]{4}" || pattern == "[a-zA-Z0-9]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_alnum(c) },
      exact_run=4,
    )
  }
  if pattern == "^[A-Za-z0-9]+" || pattern == "^[a-zA-Z0-9]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
  }
  if pattern == "[A-Za-z0-9]+$" || pattern == "[a-zA-Z0-9]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_ascii_alnum(c)
    })
  }
  if pattern == "[^A-Za-z0-9]+" || pattern == "[^a-zA-Z0-9]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_ascii_alnum(c)
    })
  }
  if pattern == "[A-Za-z]+" || pattern == "[a-zA-Z]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_ascii_letter(c)
    })
  }
  if pattern == "[A-Za-z]{2,}" || pattern == "[a-zA-Z]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      min_run=2,
    )
  }
  if pattern == "[A-Za-z]{2}" || pattern == "[a-zA-Z]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      exact_run=2,
    )
  }
  if pattern == "[A-Za-z]{3}" || pattern == "[a-zA-Z]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      exact_run=3,
    )
  }
  if pattern == "[A-Za-z]{4}" || pattern == "[a-zA-Z]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_ascii_letter(c) },
      exact_run=4,
    )
  }
  if pattern == "^[A-Za-z]+" || pattern == "^[a-zA-Z]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_ascii_letter(c)
    })
  }
  if pattern == "[A-Za-z]+$" || pattern == "[a-zA-Z]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_ascii_letter(c)
    })
  }
  if pattern == "[^A-Za-z]+" || pattern == "[^a-zA-Z]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_ascii_letter(c)
    })
  }
  if pattern == "\\p{L}+" ||
    pattern == "\\p{Letter}+" ||
    pattern == "[\\p{L}]+" ||
    pattern == "[\\p{Letter}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_letter(c)
    })
  }
  if pattern == "\\p{L}{2,}" ||
    pattern == "\\p{Letter}{2,}" ||
    pattern == "[\\p{L}]{2,}" ||
    pattern == "[\\p{Letter}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{L}{2}" ||
    pattern == "\\p{Letter}{2}" ||
    pattern == "[\\p{L}]{2}" ||
    pattern == "[\\p{Letter}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{L}{3}" ||
    pattern == "\\p{Letter}{3}" ||
    pattern == "[\\p{L}]{3}" ||
    pattern == "[\\p{Letter}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{L}{4}" ||
    pattern == "\\p{Letter}{4}" ||
    pattern == "[\\p{L}]{4}" ||
    pattern == "[\\p{Letter}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_letter(c) },
      exact_run=4,
    )
  }
  if pattern == "^\\p{L}+" ||
    pattern == "^\\p{Letter}+" ||
    pattern == "^[\\p{L}]+" ||
    pattern == "^[\\p{Letter}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_letter(c)
    })
  }
  if pattern == "\\p{L}+$" ||
    pattern == "\\p{Letter}+$" ||
    pattern == "[\\p{L}]+$" ||
    pattern == "[\\p{Letter}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_letter(c)
    })
  }
  if pattern == "\\P{L}+" ||
    pattern == "\\P{Letter}+" ||
    pattern == "[^\\p{L}]+" ||
    pattern == "[^\\p{Letter}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_letter(c)
    })
  }
  if pattern == "\\p{P}+" ||
    pattern == "\\p{Punctuation}+" ||
    pattern == "[\\p{P}]+" ||
    pattern == "[\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\p{P}{2,}" ||
    pattern == "\\p{Punctuation}{2,}" ||
    pattern == "[\\p{P}]{2,}" ||
    pattern == "[\\p{Punctuation}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{P}{2}" ||
    pattern == "\\p{Punctuation}{2}" ||
    pattern == "[\\p{P}]{2}" ||
    pattern == "[\\p{Punctuation}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{P}{3}" ||
    pattern == "\\p{Punctuation}{3}" ||
    pattern == "[\\p{P}]{3}" ||
    pattern == "[\\p{Punctuation}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{P}{4}" ||
    pattern == "\\p{Punctuation}{4}" ||
    pattern == "[\\p{P}]{4}" ||
    pattern == "[\\p{Punctuation}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation(c) },
      exact_run=4,
    )
  }
  if pattern == "^\\p{P}+" ||
    pattern == "^\\p{Punctuation}+" ||
    pattern == "^[\\p{P}]+" ||
    pattern == "^[\\p{Punctuation}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\p{P}+$" ||
    pattern == "\\p{Punctuation}+$" ||
    pattern == "[\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\P{P}+" ||
    pattern == "\\P{Punctuation}+" ||
    pattern == "[^\\p{P}]+" ||
    pattern == "[^\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_punctuation(c)
    })
  }
  if pattern == "\\p{S}+" ||
    pattern == "\\p{Symbol}+" ||
    pattern == "[\\p{S}]+" ||
    pattern == "[\\p{Symbol}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_symbol(c)
    })
  }
  if pattern == "\\p{S}{2,}" ||
    pattern == "\\p{Symbol}{2,}" ||
    pattern == "[\\p{S}]{2,}" ||
    pattern == "[\\p{Symbol}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      min_run=2,
    )
  }
  if pattern == "\\p{S}{2}" ||
    pattern == "\\p{Symbol}{2}" ||
    pattern == "[\\p{S}]{2}" ||
    pattern == "[\\p{Symbol}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      exact_run=2,
    )
  }
  if pattern == "\\p{S}{3}" ||
    pattern == "\\p{Symbol}{3}" ||
    pattern == "[\\p{S}]{3}" ||
    pattern == "[\\p{Symbol}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      exact_run=3,
    )
  }
  if pattern == "\\p{S}{4}" ||
    pattern == "\\p{Symbol}{4}" ||
    pattern == "[\\p{S}]{4}" ||
    pattern == "[\\p{Symbol}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_symbol(c) },
      exact_run=4,
    )
  }
  if pattern == "^\\p{S}+" ||
    pattern == "^\\p{Symbol}+" ||
    pattern == "^[\\p{S}]+" ||
    pattern == "^[\\p{Symbol}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_symbol(c)
    })
  }
  if pattern == "\\p{S}+$" ||
    pattern == "\\p{Symbol}+$" ||
    pattern == "[\\p{S}]+$" ||
    pattern == "[\\p{Symbol}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_symbol(c)
    })
  }
  if pattern == "\\P{S}+" ||
    pattern == "\\P{Symbol}+" ||
    pattern == "[^\\p{S}]+" ||
    pattern == "[^\\p{Symbol}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_symbol(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]+" ||
    pattern == "[\\p{S}\\p{P}]+" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]{2,}" ||
    pattern == "[\\p{S}\\p{P}]{2,}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2,}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      min_run=2,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{2}" ||
    pattern == "[\\p{S}\\p{P}]{2}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      exact_run=2,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{3}" ||
    pattern == "[\\p{S}\\p{P}]{3}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{3}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      exact_run=3,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{4}" ||
    pattern == "[\\p{S}\\p{P}]{4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) { @common.is_unicode_punctuation_or_symbol(c) },
      exact_run=4,
    )
  }
  if pattern == "^[\\p{P}\\p{S}]+" ||
    pattern == "^[\\p{S}\\p{P}]+" ||
    pattern == "^[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "^[\\p{Symbol}\\p{Punctuation}]+" {
    return @common.replace_leading_runs(s, content, fn(c) {
      @common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]+$" ||
    pattern == "[\\p{S}\\p{P}]+$" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+$" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+$" {
    return @common.replace_trailing_runs(s, content, fn(c) {
      @common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[^\\p{P}\\p{S}]+" ||
    pattern == "[^\\p{S}\\p{P}]+" ||
    pattern == "[^\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[^\\p{Symbol}\\p{Punctuation}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      !@common.is_unicode_punctuation_or_symbol(c)
    })
  }
  if pattern == "[^\\s\\p{L}\\p{N}]+" ||
    pattern == "[^\\s\\p{N}\\p{L}]+" ||
    pattern == "[^\\p{L}\\p{N}\\s]+" ||
    pattern == "[^\\p{N}\\p{L}\\s]+" ||
    pattern == "[^\\s\\p{Letter}\\p{Number}]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_not_whitespace_letter_or_number(c)
    })
  }
  if pattern == "[^\\S\\r\\n]+" {
    return @common.replace_char_runs(s, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
    })
  }
  if pattern == "[^\\S\\r\\n]{2,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      min_run=2,
    )
  }
  if pattern == "[^\\S\\r\\n]{3,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      min_run=3,
    )
  }
  if pattern == "[^\\S\\r\\n]{4,}" {
    return @common.replace_min_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      min_run=4,
    )
  }
  if pattern == "[^\\S\\r\\n]{2}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      exact_run=2,
    )
  }
  if pattern == "[^\\S\\r\\n]{3}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      exact_run=3,
    )
  }
  if pattern == "[^\\S\\r\\n]{4}" {
    return @common.replace_exact_char_runs(
      s,
      content,
      fn(c) {
        @common.is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
      },
      exact_run=4,
    )
  }
  @common.replace_literal(s, pattern, content)
}
