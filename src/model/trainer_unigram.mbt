///|
pub fn Model::train_unigram(
  texts : Array[String],
  unk_token? : String? = None,
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = Some(8000),
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
  max_piece_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  shrinking_factor? : Double = 0.75,
  n_sub_iterations? : Int = 2,
  show_progress? : Bool = true,
  seed_size? : Int = 1000000,
) -> Model {
  ignore(shrinking_factor)
  ignore(n_sub_iterations)
  ignore(show_progress)
  let unk_token = match unk_piece {
    Some(piece) => Some(piece)
    None => unk_token
  }
  let tokenized : Array[Array[String]] = []
  for text in texts {
    tokenized.push(whitespace_words(text))
  }
  Model::train_unigram_from_tokens(
    tokenized,
    unk_token~,
    min_frequency~,
    special_tokens~,
    vocab_size~,
    byte_fallback~,
    fuse_unk~,
    max_piece_length~,
    initial_alphabet~,
    shrinking_factor~,
    n_sub_iterations~,
    show_progress~,
    seed_size~,
  )
}

///|
/// Train a deterministic Unigram model from pre-tokenized token streams.
pub fn Model::train_unigram_from_tokens(
  tokenized_texts : Array[Array[String]],
  unk_token? : String? = None,
  unk_piece? : String? = None,
  min_frequency? : Int = 1,
  special_tokens? : Array[String] = [],
  vocab_size? : Int? = Some(8000),
  byte_fallback? : Bool = false,
  fuse_unk? : Bool = true,
  max_piece_length? : Int? = None,
  initial_alphabet? : Array[String] = [],
  shrinking_factor? : Double = 0.75,
  n_sub_iterations? : Int = 2,
  show_progress? : Bool = true,
  seed_size? : Int = 1000000,
) -> Model {
  ignore(show_progress)
  ignore(min_frequency)
  let unk_token = match unk_piece {
    Some(piece) => Some(piece)
    None => unk_token
  }
  let word_counts : Map[String, Int] = Map([])
  let word_order : Array[String] = []
  for tokens in tokenized_texts {
    for tok in tokens {
      bump_count(word_counts, word_order, tok)
    }
  }
  // Real EM training (hf-tokenizers 0.22.2 do_train port)
  let (em_pieces, em_unk) = unigram_do_train(
    word_order,
    word_counts,
    vocab_size,
    shrinking_factor,
    n_sub_iterations,
    match max_piece_length {
      Some(m) => m
      None => 16
    },
    seed_size,
    special_tokens,
    unk_token,
    initial_alphabet,
  )
  let vocab : Map[String, (Int, Double)] = Map([])
  let vocab_r : Array[String?] = []
  let mut em_i = 0
  while em_i < em_pieces.length() {
    vocab[em_pieces[em_i].token] = (em_i, em_pieces[em_i].score)
    vocab_r.push(Some(em_pieces[em_i].token))
    em_i += 1
  }
  Unigram({
    vocab,
    vocab_r,
    unk_id: em_unk,
    byte_fallback,
    fuse_unk,
    alpha: None,
    nbest_size: None,
    cache: {},
    cache_capacity: None,
  })
}

///|
fn whitespace_words(text : String) -> Array[String] {
  let chars = text.to_array()
  let out : Array[String] = []
  let n = chars.length()
  let mut i = 0
  while i < n {
    while i < n && is_train_space(chars[i]) {
      i = i + 1
    }
    let start = i
    while i < n && !is_train_space(chars[i]) {
      i = i + 1
    }
    if i > start {
      out.push(slice_train(chars, start, i))
    }
  }
  out
}

///|
fn is_train_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn slice_train(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}
