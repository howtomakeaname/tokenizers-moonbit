// Decoding behaviour: token surfaces -> reconstructed text.
//
// Following HuggingFace, each decoder is a `decode_chain(tokens) -> tokens`
// transform; `Sequence` composes them, and the final text is the join of the
// resulting token list. This token-list model is required for decoders like
// ByteFallback that must group consecutive byte tokens before a later Fuse.

///|
/// Decode a list of token surface strings back into text.
pub fn Decoder::decode(self : Decoder, tokens : Array[String]) -> String {
  match self {
    Replace(pattern~, content~) =>
      return decode_replace_direct(tokens, pattern, content)
    ReplaceString(pattern~, content~) =>
      return join(tokens.map(t => @common.replace_literal(t, pattern, content)))
    _ => ()
  }
  let out = self.decode_chain(tokens)
  let sb = StringBuilder::new()
  for t in out {
    sb.write_string(t)
  }
  sb.to_string()
}

///|
fn decode_replace_direct(
  tokens : Array[String],
  pattern : String,
  content : String,
) -> String {
  if pattern == "\\s+" {
    return decode_replace_char_runs_direct(tokens, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  if pattern == "\\s+$" {
    return decode_replace_trailing_runs_direct(tokens, content, fn(c) {
      @common.is_unicode_whitespace(c.to_int())
    })
  }
  match @common.anchored_regex_kind(pattern) {
    Some((kind, leading)) =>
      if leading {
        return decode_replace_leading_runs_direct(tokens, content, fn(c) {
          @common.bounded_regex_kind_pred(kind, c)
        })
      } else {
        return decode_replace_trailing_runs_direct(tokens, content, fn(c) {
          @common.bounded_regex_kind_pred(kind, c)
        })
      }
    None => ()
  }
  if pattern == "\\d+" || pattern == "[\\d]+" || pattern == "[0-9]+" {
    return decode_replace_char_runs_direct(tokens, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  if pattern == "[\\p{P}\\p{S}]+" ||
    pattern == "[\\p{S}\\p{P}]+" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]+" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]+" {
    return decode_replace_char_runs_direct(tokens, content, fn(c) {
      is_punctuation_or_symbol_fast(c)
    })
  }
  if pattern == "\\D{3,}" ||
    pattern == "[\\D]{3,}" ||
    pattern == "[^\\d]{3,}" ||
    pattern == "[^0-9]{3,}" ||
    pattern == "\\P{N}{3,}" ||
    pattern == "\\P{Number}{3,}" ||
    pattern == "[^\\p{N}]{3,}" ||
    pattern == "[^\\p{Number}]{3,}" {
    return decode_replace_min_non_digit_direct(tokens, content, min_run=3)
  }
  if pattern == "[^\\s\\p{L}\\p{N}]{4}" ||
    pattern == "[^\\s\\p{N}\\p{L}]{4}" ||
    pattern == "[^\\p{L}\\p{N}\\s]{4}" ||
    pattern == "[^\\p{N}\\p{L}\\s]{4}" ||
    pattern == "[^\\s\\p{Letter}\\p{Number}]{4}" {
    return decode_replace_not_whitespace_letter_number_ranged_direct(
      tokens,
      content,
      min_run=4,
      max_run=4,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{1,2}" ||
    pattern == "[\\p{S}\\p{P}]{1,2}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{1,2}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{1,2}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=1,
      max_run=2,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{1,3}" ||
    pattern == "[\\p{S}\\p{P}]{1,3}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{1,3}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{1,3}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=1,
      max_run=3,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{1,4}" ||
    pattern == "[\\p{S}\\p{P}]{1,4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{1,4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{1,4}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=1,
      max_run=4,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{2,3}" ||
    pattern == "[\\p{S}\\p{P}]{2,3}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2,3}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2,3}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=2,
      max_run=3,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{2,4}" ||
    pattern == "[\\p{S}\\p{P}]{2,4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{2,4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{2,4}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=2,
      max_run=4,
    )
  }
  if pattern == "[\\p{P}\\p{S}]{3,4}" ||
    pattern == "[\\p{S}\\p{P}]{3,4}" ||
    pattern == "[\\p{Punctuation}\\p{Symbol}]{3,4}" ||
    pattern == "[\\p{Symbol}\\p{Punctuation}]{3,4}" {
    return decode_replace_punct_symbol_ranged_direct(
      tokens,
      content,
      min_run=3,
      max_run=4,
    )
  }
  match @common.bounded_regex_kind(pattern) {
    Some((kind, max_run)) =>
      return decode_replace_ranged_char_runs_direct(
        tokens,
        content,
        fn(c) { @common.bounded_regex_kind_pred(kind, c) },
        min_run=1,
        max_run~,
      )
    None => ()
  }
  match @common.ranged_regex_kind(pattern) {
    Some((kind, min_run, max_run)) =>
      return decode_replace_ranged_char_runs_direct(
        tokens,
        content,
        fn(c) { @common.bounded_regex_kind_pred(kind, c) },
        min_run~,
        max_run~,
      )
    None => ()
  }
  match @common.exact_regex_kind(pattern) {
    Some((kind, exact_run)) =>
      return decode_replace_ranged_char_runs_direct(
        tokens,
        content,
        fn(c) { @common.bounded_regex_kind_pred(kind, c) },
        min_run=exact_run,
        max_run=exact_run,
      )
    None => ()
  }
  match @common.min_regex_kind(pattern) {
    Some((kind, min_run)) =>
      return decode_replace_min_char_runs_direct(
        tokens,
        content,
        fn(c) { @common.bounded_regex_kind_pred(kind, c) },
        min_run~,
      )
    None => ()
  }
  if @common.is_simple_split_regex_pattern(pattern) {
    return decode_replace_simple_regex_direct(tokens, pattern, content)
  }
  let sb = StringBuilder::new()
  for t in tokens {
    sb.write_string(replace_all(t, pattern, content))
  }
  sb.to_string()
}

///|
fn decode_replace_simple_regex_direct(
  tokens : Array[String],
  pattern : String,
  content : String,
) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    match @common.replace_simple_regex(t, pattern, content) {
      Some(out) => sb.write_string(out)
      None => sb.write_string(t)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_char_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    let mut in_run = false
    for c in t {
      if pred(c) {
        if !in_run {
          sb.write_string(content)
          in_run = true
        }
      } else {
        sb.write_char(c)
        in_run = false
      }
    }
  }
  sb.to_string()
}

///|
fn decode_replace_ranged_char_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
  min_run~ : Int,
  max_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if pred(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else {
          c3 = c
        }
        run = run + 1
        if run == max_run {
          sb.write_string(content)
          run = 0
        }
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_min_char_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
  min_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if pred(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else if run == 3 {
          c3 = c
        }
        run = run + 1
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_punct_symbol_ranged_direct(
  tokens : Array[String],
  content : String,
  min_run~ : Int,
  max_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if is_punctuation_or_symbol_fast(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else {
          c3 = c
        }
        run = run + 1
        if run == max_run {
          sb.write_string(content)
          run = 0
        }
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn is_punctuation_or_symbol_fast(c : Char) -> Bool {
  let u = c.to_int()
  if u < 128 {
    return (u >= 0x21 && u <= 0x2F) ||
      (u >= 0x3A && u <= 0x40) ||
      (u >= 0x5B && u <= 0x60) ||
      (u >= 0x7B && u <= 0x7E)
  }
  if u >= 0x1F300 && u <= 0x1FAFF {
    return true
  }
  @common.is_unicode_punctuation_or_symbol(c)
}

///|
fn decode_replace_min_non_digit_direct(
  tokens : Array[String],
  content : String,
  min_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if !@common.is_decimal_number(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else if run == 3 {
          c3 = c
        }
        run = run + 1
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_not_whitespace_letter_number_ranged_direct(
  tokens : Array[String],
  content : String,
  min_run~ : Int,
  max_run~ : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut run = 0
  let mut c0 = '\u{0}'
  let mut c1 = '\u{0}'
  let mut c2 = '\u{0}'
  let mut c3 = '\u{0}'
  for t in tokens {
    run = 0
    for c in t {
      if @common.is_not_whitespace_letter_or_number(c) {
        if run == 0 {
          c0 = c
        } else if run == 1 {
          c1 = c
        } else if run == 2 {
          c2 = c
        } else {
          c3 = c
        }
        run = run + 1
        if run == max_run {
          sb.write_string(content)
          run = 0
        }
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else if run > 0 {
          write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
        }
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else if run > 0 {
      write_ranged_pending_chars(sb, run, c0, c1, c2, c3)
    }
  }
  sb.to_string()
}

///|
fn write_ranged_pending_chars(
  sb : StringBuilder,
  run : Int,
  c0 : Char,
  c1 : Char,
  c2 : Char,
  c3 : Char,
) -> Unit {
  if run > 0 {
    sb.write_char(c0)
  }
  if run > 1 {
    sb.write_char(c1)
  }
  if run > 2 {
    sb.write_char(c2)
  }
  if run > 3 {
    sb.write_char(c3)
  }
}

///|
fn decode_replace_leading_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    let chars = t.to_array()
    let n = chars.length()
    let mut start = 0
    while start < n && pred(chars[start]) {
      start = start + 1
    }
    if start > 0 {
      sb.write_string(content)
      for i in start..<n {
        sb.write_char(chars[i])
      }
    } else {
      sb.write_string(t)
    }
  }
  sb.to_string()
}

///|
fn decode_replace_trailing_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
) -> String {
  let sb = StringBuilder::new()
  for t in tokens {
    let chars = t.to_array()
    let mut stop = chars.length()
    while stop > 0 && pred(chars[stop - 1]) {
      stop = stop - 1
    }
    for i in 0..<stop {
      sb.write_char(chars[i])
    }
    if stop < chars.length() {
      sb.write_string(content)
    }
  }
  sb.to_string()
}

///|
/// Transform a token list (HF decode_chain semantics).
