// Post-processing: insert special tokens and assign type_ids / masks.
//
// Operates on the model-produced Encoding(s). For single input, encoding_b is
// None. Mirrors HuggingFace TemplateProcessing / Bert / Roberta / ByteLevel.

/// Apply post-processing. `a` is the primary encoding; `b` is the optional
/// second sequence (for pair inputs). Returns the assembled Encoding.
pub fn PostProcessor::process(
  self : PostProcessor,
  a : @types.Encoding,
  b : @types.Encoding?,
) -> @types.Encoding {
  match self {
    TemplateProcessing(single~, pair~, special_tokens~) => {
      let template = match b {
        None => single
        Some(_) => pair
      }
      apply_template(template, special_tokens, a, b)
    }
    BertProcessing(sep~, cls~) => bert_like(a, b, cls, sep, false)
    RobertaProcessing(sep~, cls~, ..) => bert_like(a, b, cls, sep, true)
    // ByteLevel post-processor only adjusts offsets; pass through.
    ByteLevel(..) => merge_plain(a, b)
    Sequence(steps) => {
      let mut acc = a
      for step in steps {
        acc = step.process(acc, b)
      }
      acc
    }
  }
}

// Build an Encoding by following a template of Sequence/SpecialToken pieces.
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
        append_sequence(out, enc, type_id)
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
fn bert_like(
  a : @types.Encoding,
  b : @types.Encoding?,
  cls : (String, Int),
  sep : (String, Int),
  roberta : Bool,
) -> @types.Encoding {
  let out = new_builder()
  push_special(out, cls.1, cls.0, 0)
  append_sequence(out, a, 0)
  push_special(out, sep.1, sep.0, 0)
  match b {
    Some(eb) => {
      // RoBERTa inserts an extra </s> between sequences.
      if roberta {
        push_special(out, sep.1, sep.0, 0)
      }
      let pair_type_id = if roberta { 0 } else { 1 }
      append_sequence(out, eb, pair_type_id)
      push_special(out, sep.1, sep.0, pair_type_id)
    }
    None => ()
  }
  build(out)
}

// No special tokens: concatenate a and optional b (type_id 0 / 1).
fn merge_plain(a : @types.Encoding, b : @types.Encoding?) -> @types.Encoding {
  let out = new_builder()
  append_sequence(out, a, 0)
  match b {
    Some(eb) => append_sequence(out, eb, 1)
    None => ()
  }
  build(out)
}

// --- mutable builder for assembling an Encoding ---

priv struct Builder {
  ids : Array[Int]
  type_ids : Array[Int]
  tokens : Array[String]
  offsets : Array[(Int, Int)]
  special_tokens_mask : Array[Int]
  attention_mask : Array[Int]
}

fn new_builder() -> Builder {
  {
    ids: [],
    type_ids: [],
    tokens: [],
    offsets: [],
    special_tokens_mask: [],
    attention_mask: [],
  }
}

fn append_sequence(out : Builder, enc : @types.Encoding, type_id : Int) -> Unit {
  for i in 0..<enc.ids.length() {
    out.ids.push(enc.ids[i])
    out.type_ids.push(type_id)
    out.tokens.push(enc.tokens[i])
    out.offsets.push(enc.offsets[i])
    out.special_tokens_mask.push(0)
    out.attention_mask.push(1)
  }
}

fn append_special(out : Builder, st : SpecialToken, type_id : Int) -> Unit {
  for i in 0..<st.ids.length() {
    out.ids.push(st.ids[i])
    out.type_ids.push(type_id)
    out.tokens.push(if i < st.tokens.length() { st.tokens[i] } else { st.id })
    out.offsets.push((0, 0))
    out.special_tokens_mask.push(1)
    out.attention_mask.push(1)
  }
}

fn push_special(out : Builder, id : Int, token : String, type_id : Int) -> Unit {
  out.ids.push(id)
  out.type_ids.push(type_id)
  out.tokens.push(token)
  out.offsets.push((0, 0))
  out.special_tokens_mask.push(1)
  out.attention_mask.push(1)
}

fn build(out : Builder) -> @types.Encoding {
  {
    ids: out.ids,
    type_ids: out.type_ids,
    tokens: out.tokens,
    offsets: out.offsets,
    special_tokens_mask: out.special_tokens_mask,
    attention_mask: out.attention_mask,
    overflowing: [],
  }
}
