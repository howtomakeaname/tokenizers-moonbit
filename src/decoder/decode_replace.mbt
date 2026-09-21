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
  let sb = StringBuilder()
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
  // double-anchored whole-line spellings claim the pattern FIRST (the
  // non-multiline literal/anchored wrappers below previously swallowed
  // them — review finding: Decoder::Replace("^a$").decode(["a\na"])
  // stayed unchanged while HF gives "#\n#"); the engine applies the
  // line semantics within each token surface
  if @common.double_anchored_spec(pattern) is Some((kind, literal, lo, hi)) {
    let pred : (Char) -> Bool = if kind == -1 {
      let c = literal.unwrap_or('\u{0}')
      fn(x) { x == c }
    } else {
      fn(x) { @common.bounded_regex_kind_pred(kind, x) }
    }
    let sb = StringBuilder()
    for t in tokens {
      sb.write_string(
        @common.replace_double_anchored_line_runs(t, content, pred, lo, hi),
      )
    }
    return sb.to_string()
  }
  // single-char literal bounded quantifiers run per token (HF decoders are
  // per-token: a{2} replaces only within one token surface)
  if @common.char_bounded_spec(pattern) is Some(_) {
    let sb = StringBuilder()
    for t in tokens {
      match @common.replace_char_bounded_runs(t, pattern, content) {
        Some(out) => sb.write_string(out)
        None => sb.write_string(t)
      }
    }
    return sb.to_string()
  }
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
  if pattern == "\\d+" || pattern == "[\\d]+" {
    return decode_replace_char_runs_direct(tokens, content, fn(c) {
      @common.is_decimal_number(c)
    })
  }
  // `[0-9]+` is ASCII-only (HF: fullwidth digits stay)
  if pattern == "[0-9]+" {
    return decode_replace_char_runs_direct(tokens, content, fn(c) {
      c >= '0' && c <= '9'
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
    pattern == "[^0-9]{3,}" {
    return decode_replace_min_non_digit_direct(tokens, content, min_run=3)
  }
  // \\P{N} is the complement of FULL N (Nd + Nl + No; probed 0.22.2)
  if pattern == "\\P{N}{3,}" ||
    pattern == "\\P{Number}{3,}" ||
    pattern == "[^\\p{N}]{3,}" ||
    pattern == "[^\\p{Number}]{3,}" {
    return decode_replace_min_runs_direct(
      tokens,
      content,
      fn(c) { !@common.is_unicode_number(c) },
      min_run=3,
    )
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
  // Unsupported regex family: fail explicitly (same gate as decode_chain's
  // Replace arm) instead of silently falling back to a literal replace.
  guard replace_pattern_supported(pattern) else {
    abort("unsupported Replace decoder pattern: \{pattern}")
  }
  let sb = StringBuilder()
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
  let sb = StringBuilder()
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
  let sb = StringBuilder()
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
  let sb = StringBuilder()
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
  let sb = StringBuilder()
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
  let sb = StringBuilder()
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
  let sb = StringBuilder()
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
  let sb = StringBuilder()
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
  // HF anchors are MULTILINE even per token surface (probed: ^[\r\n]+ on
  // ["x\n\n","y"] -> "x\n#y")
  let sb = StringBuilder()
  for t in tokens {
    let chars = t.to_array()
    let n = chars.length()
    let mut i = 0
    let mut at_line_head = true
    while i < n {
      if at_line_head {
        let start = i
        while i < n && pred(chars[i]) {
          i = i + 1
        }
        if i > start {
          sb.write_string(content)
        }
        at_line_head = false
        continue
      }
      sb.write_char(chars[i])
      if chars[i] == '\n' {
        at_line_head = true
      }
      i = i + 1
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
  // MULTILINE $: longest run prefix ending at a line boundary (before any
  // \n or at token end); probed: [\w]+$ on ["ab\n","cd"] -> "#\n#"
  let sb = StringBuilder()
  for t in tokens {
    let chars = t.to_array()
    let n = chars.length()
    let mut i = 0
    while i < n {
      if pred(chars[i]) {
        let start = i
        let mut g = i
        while g < n && pred(chars[g]) {
          g = g + 1
        }
        let mut j = -1
        if g == n {
          j = g
        } else {
          let mut k = g
          while k > start {
            if chars[k] == '\n' {
              j = k
              break
            }
            k = k - 1
          }
        }
        if j > start {
          sb.write_string(content)
          i = j
          continue
        }
        for x in start..<g {
          sb.write_char(chars[x])
        }
        i = g
        continue
      }
      sb.write_char(chars[i])
      i = i + 1
    }
  }
  sb.to_string()
}

///|
/// Transform a token list (HF decode_chain semantics).

///|
/// Per-token min-run replace with a caller-supplied predicate (the
/// `\P{N}{n,}` family needs the FULL-N complement, distinct from
/// `decode_replace_min_non_digit_direct`'s Nd complement).
fn decode_replace_min_runs_direct(
  tokens : Array[String],
  content : String,
  pred : (Char) -> Bool,
  min_run~ : Int,
) -> String {
  let sb = StringBuilder()
  for t in tokens {
    let pending = StringBuilder()
    let mut run = 0
    for c in t {
      if pred(c) {
        pending.write_char(c)
        run = run + 1
      } else {
        if run >= min_run {
          sb.write_string(content)
        } else {
          sb.write_string(pending.to_string())
        }
        pending.reset()
        run = 0
        sb.write_char(c)
      }
    }
    if run >= min_run {
      sb.write_string(content)
    } else {
      sb.write_string(pending.to_string())
    }
  }
  sb.to_string()
}
