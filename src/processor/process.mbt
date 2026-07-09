// Post-processing: insert special tokens and assign type_ids / masks.
//
// Operates on the model-produced Encoding(s). For single input, encoding_b is
// None. Mirrors HuggingFace TemplateProcessing / Bert / Roberta / ByteLevel.

///|
/// Apply post-processing. `a` is the primary encoding; `b` is the optional
/// second sequence (for pair inputs). Returns the assembled Encoding.
pub fn PostProcessor::process(
  self : PostProcessor,
  a : @types.Encoding,
  b : @types.Encoding?,
  add_special_tokens? : Bool = true,
) -> @types.Encoding {
  let processed = match self {
    TemplateProcessing(single~, pair~, special_tokens~) => {
      let template = match b {
        None => single
        Some(_) => pair
      }
      apply_template(template, special_tokens, a, b)
    }
    BertProcessing(sep~, cls~) => bert_like(a, b, cls, sep, false)
    RobertaProcessing(sep~, cls~, trim_offsets~, add_prefix_space~) => {
      let a = process_byte_level_offsets(a, trim_offsets, add_prefix_space)
      let b = match b {
        Some(eb) =>
          Some(process_byte_level_offsets(eb, trim_offsets, add_prefix_space))
        None => None
      }
      bert_like(a, b, cls, sep, true)
    }
    // ByteLevel post-processor adjusts byte-level whitespace offsets.
    ByteLevel(add_prefix_space~, trim_offsets~, ..) => {
      let a = process_byte_level_offsets(a, trim_offsets, add_prefix_space)
      let b = match b {
        Some(eb) =>
          Some(process_byte_level_offsets(eb, trim_offsets, add_prefix_space))
        None => None
      }
      merge_plain(a, b)
    }
    Sequence(steps) => {
      let mut acc = a
      let mut pair = b
      for step in steps {
        match step {
          ByteLevel(add_prefix_space~, trim_offsets~, ..) => {
            acc = process_byte_level_offsets(
              acc, trim_offsets, add_prefix_space,
            )
            pair = pair.map(eb => {
              process_byte_level_offsets(eb, trim_offsets, add_prefix_space)
            })
          }
          _ => {
            acc = step.process(acc, pair)
            pair = None
          }
        }
      }
      acc
    }
  }
  if add_special_tokens {
    processed
  } else {
    remove_post_processor_specials(processed)
  }
}

///|
fn remove_post_processor_specials(enc : @types.Encoding) -> @types.Encoding {
  let ids : Array[Int] = []
  let type_ids : Array[Int] = []
  let tokens : Array[String] = []
  let offsets : Array[(Int, Int)] = []
  let special_tokens_mask : Array[Int] = []
  let attention_mask : Array[Int] = []
  let sequence_ids : Array[Int?] = []
  let word_ids : Array[Int?] = []
  for i in 0..<enc.ids.length() {
    if !(enc.special_tokens_mask[i] == 1 && enc.sequence_ids[i] is None) {
      ids.push(enc.ids[i])
      type_ids.push(enc.type_ids[i])
      tokens.push(enc.tokens[i])
      offsets.push(enc.offsets[i])
      special_tokens_mask.push(enc.special_tokens_mask[i])
      attention_mask.push(enc.attention_mask[i])
      sequence_ids.push(enc.sequence_ids[i])
      word_ids.push(enc.word_ids[i])
    }
  }
  {
    ids,
    type_ids,
    tokens,
    offsets,
    special_tokens_mask,
    attention_mask,
    sequence_ids,
    word_ids,
    overflowing: enc.overflowing.map(e => remove_post_processor_specials(e)),
  }
}

// Build an Encoding by following a template of Sequence/SpecialToken pieces.

///|
fn apply_template(
  template : Array[Piece],
  special_tokens : Map[String, SpecialToken],
  a : @types.Encoding,
  b : @types.Encoding?,
) -> @types.Encoding {
  let out = new_builder()
  for piece in template {
    match piece {
      SequenceRef(id~, type_id~) => {
        let enc = if id == "B" {
          match b {
            Some(e) => e
            None => a
          }
        } else {
          a
        }
        let seq_id = if id == "B" { 1 } else { 0 }
        append_sequence_with_id(out, enc, type_id, seq_id)
      }
      SpecialTokenRef(id~, type_id~) =>
        match special_tokens.get(id) {
          Some(st) => append_special(out, st, type_id)
          None => ()
        }
    }
  }
  build(out)
}

// BERT/RoBERTa: [CLS] A [SEP] (B [SEP]).

///|
fn bert_like(
  a : @types.Encoding,
  b : @types.Encoding?,
  cls : (String, Int),
  sep : (String, Int),
  roberta : Bool,
) -> @types.Encoding {
  let out = new_builder()
  push_special(out, cls.1, cls.0, 0)
  append_sequence_with_id(out, a, 0, 0)
  push_special(out, sep.1, sep.0, 0)
  match b {
    Some(eb) => {
      // RoBERTa inserts an extra </s> between sequences.
      if roberta {
        push_special(out, sep.1, sep.0, 0)
      }
      let pair_type_id = if roberta { 0 } else { 1 }
      append_sequence_with_id(out, eb, pair_type_id, 1)
      push_special(out, sep.1, sep.0, pair_type_id)
    }
    None => ()
  }
  build(out)
}

// No special tokens: concatenate a and optional b (type_id 0 / 1).

///|
fn merge_plain(a : @types.Encoding, b : @types.Encoding?) -> @types.Encoding {
  let out = new_builder()
  append_sequence_with_id(out, a, 0, 0)
  match b {
    Some(eb) => append_sequence_with_id(out, eb, 1, 1)
    None => ()
  }
  build(out)
}

// ByteLevel post-processing mirrors HF's offset trimming: byte-level spaces
// (the visible GPT-2 space char `Ġ`) are trimmed from offsets for non-initial
// leading whitespace and trailing whitespace. Token strings and ids are not
// changed.

///|
fn process_byte_level_offsets(
  enc : @types.Encoding,
  trim_offsets : Bool,
  add_prefix_space : Bool,
) -> @types.Encoding {
  if !trim_offsets {
    return enc
  }
  ignore(add_prefix_space)
  let offsets : Array[(Int, Int)] = []
  for i in 0..<enc.tokens.length() {
    offsets.push(process_token_offset(enc.tokens[i], enc.offsets[i]))
  }
  {
    ids: enc.ids.copy(),
    type_ids: enc.type_ids.copy(),
    tokens: enc.tokens.copy(),
    offsets,
    special_tokens_mask: enc.special_tokens_mask.copy(),
    attention_mask: enc.attention_mask.copy(),
    sequence_ids: enc.sequence_ids.copy(),
    word_ids: enc.word_ids.copy(),
    overflowing: enc.overflowing.map(e => {
      process_byte_level_offsets(e, trim_offsets, add_prefix_space)
    }),
  }
}

///|
fn process_token_offset(token : String, offsets : (Int, Int)) -> (Int, Int) {
  let leading_spaces = count_leading_byte_spaces(token)
  let trailing_spaces = count_trailing_byte_spaces(token)
  let mut start = offsets.0
  let mut stop = offsets.1
  if leading_spaces > 0 && start > 0 {
    start = min_int(start + leading_spaces, stop)
  }
  if trailing_spaces > 0 {
    if stop >= trailing_spaces {
      stop = max_int(stop - trailing_spaces, start)
    } else {
      stop = start
    }
  }
  (start, stop)
}

///|
fn count_leading_byte_spaces(token : String) -> Int {
  let mut n = 0
  for c in token {
    if is_byte_level_space(c) {
      n = n + 1
    } else {
      break
    }
  }
  n
}

///|
fn count_trailing_byte_spaces(token : String) -> Int {
  let chars = token.to_array()
  let mut n = 0
  let mut i = chars.length() - 1
  while i >= 0 {
    if is_byte_level_space(chars[i]) {
      n = n + 1
      i = i - 1
    } else {
      break
    }
  }
  n
}

///|
fn is_byte_level_space(c : Char) -> Bool {
  c == 'Ġ'
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

// --- mutable builder for assembling an Encoding ---

///|
priv struct Builder {
  ids : Array[Int]
  type_ids : Array[Int]
  tokens : Array[String]
  offsets : Array[(Int, Int)]
  special_tokens_mask : Array[Int]
  attention_mask : Array[Int]
  sequence_ids : Array[Int?]
  word_ids : Array[Int?]
}

///|
fn new_builder() -> Builder {
  {
    ids: [],
    type_ids: [],
    tokens: [],
    offsets: [],
    special_tokens_mask: [],
    attention_mask: [],
    sequence_ids: [],
    word_ids: [],
  }
}

///|
fn append_sequence_with_id(
  out : Builder,
  enc : @types.Encoding,
  type_id : Int,
  seq_id : Int,
) -> Unit {
  for i in 0..<enc.ids.length() {
    out.ids.push(enc.ids[i])
    out.type_ids.push(type_id)
    out.tokens.push(enc.tokens[i])
    out.offsets.push(enc.offsets[i])
    out.special_tokens_mask.push(0)
    out.attention_mask.push(1)
    out.sequence_ids.push(Some(seq_id))
    out.word_ids.push(enc.word_ids[i])
  }
}

///|
fn append_special(out : Builder, st : SpecialToken, type_id : Int) -> Unit {
  for i in 0..<st.ids.length() {
    out.ids.push(st.ids[i])
    out.type_ids.push(type_id)
    out.tokens.push(if i < st.tokens.length() { st.tokens[i] } else { st.id })
    out.offsets.push((0, 0))
    out.special_tokens_mask.push(1)
    out.attention_mask.push(1)
    out.sequence_ids.push(None)
    out.word_ids.push(None)
  }
}

///|
fn push_special(out : Builder, id : Int, token : String, type_id : Int) -> Unit {
  out.ids.push(id)
  out.type_ids.push(type_id)
  out.tokens.push(token)
  out.offsets.push((0, 0))
  out.special_tokens_mask.push(1)
  out.attention_mask.push(1)
  out.sequence_ids.push(None)
  out.word_ids.push(None)
}

///|
fn build(out : Builder) -> @types.Encoding {
  {
    ids: out.ids,
    type_ids: out.type_ids,
    tokens: out.tokens,
    offsets: out.offsets,
    special_tokens_mask: out.special_tokens_mask,
    attention_mask: out.attention_mask,
    sequence_ids: out.sequence_ids,
    word_ids: out.word_ids,
    overflowing: [],
  }
}
