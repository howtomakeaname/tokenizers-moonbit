///|
pub fn ranged_regex_kind(pattern : String) -> (Int, Int, Int)? {
  match
    ranged_kind_variants(
      pattern,
      1,
      ["\\s{2,3}", "[\\s]{2,3}"],
      ["\\s{2,4}", "[\\s]{2,4}"],
      ["\\s{3,4}", "[\\s]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      2,
      ["[ \\t]{2,3}", "[^\\S\\r\\n]{2,3}"],
      ["[ \\t]{2,4}", "[^\\S\\r\\n]{2,4}"],
      ["[ \\t]{3,4}", "[^\\S\\r\\n]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      3,
      ["[\\r\\n]{2,3}", "[\r\n]{2,3}"],
      ["[\\r\\n]{2,4}", "[\r\n]{2,4}"],
      ["[\\r\\n]{3,4}", "[\r\n]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      12,
      ["\\S{2,3}", "[^\\s]{2,3}"],
      ["\\S{2,4}", "[^\\s]{2,4}"],
      ["\\S{3,4}", "[^\\s]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      11,
      [
        "\\d{2,3}", "[\\d]{2,3}", "[0-9]{2,3}", "\\p{N}{2,3}", "\\p{Number}{2,3}",
        "[\\p{N}]{2,3}", "[\\p{Number}]{2,3}",
      ],
      [
        "\\d{2,4}", "[\\d]{2,4}", "[0-9]{2,4}", "\\p{N}{2,4}", "\\p{Number}{2,4}",
        "[\\p{N}]{2,4}", "[\\p{Number}]{2,4}",
      ],
      [
        "\\d{3,4}", "[\\d]{3,4}", "[0-9]{3,4}", "\\p{N}{3,4}", "\\p{Number}{3,4}",
        "[\\p{N}]{3,4}", "[\\p{Number}]{3,4}",
      ],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      14,
      [
        "\\D{2,3}", "[\\D]{2,3}", "[^\\d]{2,3}", "[^0-9]{2,3}", "\\P{N}{2,3}", "\\P{Number}{2,3}",
        "[^\\p{N}]{2,3}", "[^\\p{Number}]{2,3}",
      ],
      [
        "\\D{2,4}", "[\\D]{2,4}", "[^\\d]{2,4}", "[^0-9]{2,4}", "\\P{N}{2,4}", "\\P{Number}{2,4}",
        "[^\\p{N}]{2,4}", "[^\\p{Number}]{2,4}",
      ],
      [
        "\\D{3,4}", "[\\D]{3,4}", "[^\\d]{3,4}", "[^0-9]{3,4}", "\\P{N}{3,4}", "\\P{Number}{3,4}",
        "[^\\p{N}]{3,4}", "[^\\p{Number}]{3,4}",
      ],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      4,
      ["\\w{2,3}", "[A-Za-z0-9_]{2,3}"],
      ["\\w{2,4}", "[A-Za-z0-9_]{2,4}"],
      ["\\w{3,4}", "[A-Za-z0-9_]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      13,
      ["\\W{2,3}", "[^\\w]{2,3}", "[^A-Za-z0-9_]{2,3}"],
      ["\\W{2,4}", "[^\\w]{2,4}", "[^A-Za-z0-9_]{2,4}"],
      ["\\W{3,4}", "[^\\w]{3,4}", "[^A-Za-z0-9_]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      5,
      ["[A-Za-z0-9]{2,3}", "[a-zA-Z0-9]{2,3}"],
      ["[A-Za-z0-9]{2,4}", "[a-zA-Z0-9]{2,4}"],
      ["[A-Za-z0-9]{3,4}", "[a-zA-Z0-9]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      15,
      ["[^A-Za-z0-9]{2,3}", "[^a-zA-Z0-9]{2,3}"],
      ["[^A-Za-z0-9]{2,4}", "[^a-zA-Z0-9]{2,4}"],
      ["[^A-Za-z0-9]{3,4}", "[^a-zA-Z0-9]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      6,
      ["[A-Za-z]{2,3}", "[a-zA-Z]{2,3}"],
      ["[A-Za-z]{2,4}", "[a-zA-Z]{2,4}"],
      ["[A-Za-z]{3,4}", "[a-zA-Z]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      16,
      ["[^A-Za-z]{2,3}", "[^a-zA-Z]{2,3}"],
      ["[^A-Za-z]{2,4}", "[^a-zA-Z]{2,4}"],
      ["[^A-Za-z]{3,4}", "[^a-zA-Z]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      7,
      ["\\p{L}{2,3}", "\\p{Letter}{2,3}", "[\\p{L}]{2,3}", "[\\p{Letter}]{2,3}"],
      ["\\p{L}{2,4}", "\\p{Letter}{2,4}", "[\\p{L}]{2,4}", "[\\p{Letter}]{2,4}"],
      ["\\p{L}{3,4}", "\\p{Letter}{3,4}", "[\\p{L}]{3,4}", "[\\p{Letter}]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      17,
      [
        "\\P{L}{2,3}", "\\P{Letter}{2,3}", "[^\\p{L}]{2,3}", "[^\\p{Letter}]{2,3}",
      ],
      [
        "\\P{L}{2,4}", "\\P{Letter}{2,4}", "[^\\p{L}]{2,4}", "[^\\p{Letter}]{2,4}",
      ],
      [
        "\\P{L}{3,4}", "\\P{Letter}{3,4}", "[^\\p{L}]{3,4}", "[^\\p{Letter}]{3,4}",
      ],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      8,
      [
        "\\p{P}{2,3}", "\\p{Punctuation}{2,3}", "[\\p{P}]{2,3}", "[\\p{Punctuation}]{2,3}",
      ],
      [
        "\\p{P}{2,4}", "\\p{Punctuation}{2,4}", "[\\p{P}]{2,4}", "[\\p{Punctuation}]{2,4}",
      ],
      [
        "\\p{P}{3,4}", "\\p{Punctuation}{3,4}", "[\\p{P}]{3,4}", "[\\p{Punctuation}]{3,4}",
      ],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      18,
      [
        "\\P{P}{2,3}", "\\P{Punctuation}{2,3}", "[^\\p{P}]{2,3}", "[^\\p{Punctuation}]{2,3}",
      ],
      [
        "\\P{P}{2,4}", "\\P{Punctuation}{2,4}", "[^\\p{P}]{2,4}", "[^\\p{Punctuation}]{2,4}",
      ],
      [
        "\\P{P}{3,4}", "\\P{Punctuation}{3,4}", "[^\\p{P}]{3,4}", "[^\\p{Punctuation}]{3,4}",
      ],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      9,
      ["\\p{S}{2,3}", "\\p{Symbol}{2,3}", "[\\p{S}]{2,3}", "[\\p{Symbol}]{2,3}"],
      ["\\p{S}{2,4}", "\\p{Symbol}{2,4}", "[\\p{S}]{2,4}", "[\\p{Symbol}]{2,4}"],
      ["\\p{S}{3,4}", "\\p{Symbol}{3,4}", "[\\p{S}]{3,4}", "[\\p{Symbol}]{3,4}"],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      19,
      [
        "\\P{S}{2,3}", "\\P{Symbol}{2,3}", "[^\\p{S}]{2,3}", "[^\\p{Symbol}]{2,3}",
      ],
      [
        "\\P{S}{2,4}", "\\P{Symbol}{2,4}", "[^\\p{S}]{2,4}", "[^\\p{Symbol}]{2,4}",
      ],
      [
        "\\P{S}{3,4}", "\\P{Symbol}{3,4}", "[^\\p{S}]{3,4}", "[^\\p{Symbol}]{3,4}",
      ],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      10,
      [
        "[\\p{P}\\p{S}]{2,3}", "[\\p{S}\\p{P}]{2,3}", "[\\p{Punctuation}\\p{Symbol}]{2,3}",
        "[\\p{Symbol}\\p{Punctuation}]{2,3}",
      ],
      [
        "[\\p{P}\\p{S}]{2,4}", "[\\p{S}\\p{P}]{2,4}", "[\\p{Punctuation}\\p{Symbol}]{2,4}",
        "[\\p{Symbol}\\p{Punctuation}]{2,4}",
      ],
      [
        "[\\p{P}\\p{S}]{3,4}", "[\\p{S}\\p{P}]{3,4}", "[\\p{Punctuation}\\p{Symbol}]{3,4}",
        "[\\p{Symbol}\\p{Punctuation}]{3,4}",
      ],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    ranged_kind_variants(
      pattern,
      20,
      [
        "[^\\p{P}\\p{S}]{2,3}", "[^\\p{S}\\p{P}]{2,3}", "[^\\p{Punctuation}\\p{Symbol}]{2,3}",
        "[^\\p{Symbol}\\p{Punctuation}]{2,3}",
      ],
      [
        "[^\\p{P}\\p{S}]{2,4}", "[^\\p{S}\\p{P}]{2,4}", "[^\\p{Punctuation}\\p{Symbol}]{2,4}",
        "[^\\p{Symbol}\\p{Punctuation}]{2,4}",
      ],
      [
        "[^\\p{P}\\p{S}]{3,4}", "[^\\p{S}\\p{P}]{3,4}", "[^\\p{Punctuation}\\p{Symbol}]{3,4}",
        "[^\\p{Symbol}\\p{Punctuation}]{3,4}",
      ],
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  ranged_kind_variants(
    pattern,
    21,
    [
      "[^\\s\\p{L}\\p{N}]{2,3}", "[^\\s\\p{N}\\p{L}]{2,3}", "[^\\p{L}\\p{N}\\s]{2,3}",
      "[^\\p{N}\\p{L}\\s]{2,3}", "[^\\s\\p{Letter}\\p{Number}]{2,3}",
    ],
    [
      "[^\\s\\p{L}\\p{N}]{2,4}", "[^\\s\\p{N}\\p{L}]{2,4}", "[^\\p{L}\\p{N}\\s]{2,4}",
      "[^\\p{N}\\p{L}\\s]{2,4}", "[^\\s\\p{Letter}\\p{Number}]{2,4}",
    ],
    [
      "[^\\s\\p{L}\\p{N}]{3,4}", "[^\\s\\p{N}\\p{L}]{3,4}", "[^\\p{L}\\p{N}\\s]{3,4}",
      "[^\\p{N}\\p{L}\\s]{3,4}", "[^\\s\\p{Letter}\\p{Number}]{3,4}",
    ],
  )
}

///|
pub fn is_ranged_regex_pattern(pattern : String) -> Bool {
  match ranged_regex_kind(pattern) {
    Some(_) => true
    None => false
  }
}

///|
/// Common exact `{n}` regex class families shared by Split, Normalizer Replace
/// and Decoder Replace. Return `(kind, exact_run)`. The supported exact run
/// sizes intentionally stay in the small tokenizer-oriented 2..4 window.
pub fn exact_regex_kind(pattern : String) -> (Int, Int)? {
  match quantified_class_kind(pattern, "{2}") {
    Some(kind) => return Some((kind, 2))
    None => ()
  }
  match quantified_class_kind(pattern, "{3}") {
    Some(kind) => return Some((kind, 3))
    None => ()
  }
  match quantified_class_kind(pattern, "{4}") {
    Some(kind) => return Some((kind, 4))
    None => ()
  }
  None
}

///|
pub fn is_exact_regex_pattern(pattern : String) -> Bool {
  match exact_regex_kind(pattern) {
    Some(_) => true
    None => false
  }
}

///|
/// Common minimum-run `{n,}` regex class families shared by Split, Normalizer
/// Replace and Decoder Replace. Return `(kind, min_run)`. This complements the
/// bounded `{1,n}` and ranged `{m,n}` tables without introducing a full regex
/// engine.
pub fn min_regex_kind(pattern : String) -> (Int, Int)? {
  match quantified_class_kind(pattern, "{2,}") {
    Some(kind) => return Some((kind, 2))
    None => ()
  }
  match quantified_class_kind(pattern, "{3,}") {
    Some(kind) => return Some((kind, 3))
    None => ()
  }
  match quantified_class_kind(pattern, "{4,}") {
    Some(kind) => return Some((kind, 4))
    None => ()
  }
  None
}

///|
pub fn is_min_regex_pattern(pattern : String) -> Bool {
  match min_regex_kind(pattern) {
    Some(_) => true
    None => false
  }
}

///|
/// Common anchored `^...+` / `...+$` regex class families shared by Split and
/// Replace. Return `(kind, leading)` where `kind` uses
/// `bounded_regex_kind_pred` and `leading=true` means `^...+`.
pub fn anchored_regex_kind(pattern : String) -> (Int, Bool)? {
  match
    anchored_variants(pattern, ["^\\s+", "^[\\s]+"], ["\\s+$", "[\\s]+$"], 1) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(pattern, ["^\\S+", "^[^\\s]+"], ["\\S+$", "[^\\s]+$"], 12) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      [
        "^\\d+", "^[\\d]+", "^[0-9]+", "^\\p{N}+", "^\\p{Number}+", "^[\\p{N}]+",
        "^[\\p{Number}]+",
      ],
      [
        "\\d+$", "[\\d]+$", "[0-9]+$", "\\p{N}+$", "\\p{Number}+$", "[\\p{N}]+$",
        "[\\p{Number}]+$",
      ],
      11,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      [
        "^\\D+", "^[\\D]+", "^[^\\d]+", "^[^0-9]+", "^\\P{N}+", "^\\P{Number}+",
        "^[^\\p{N}]+", "^[^\\p{Number}]+",
      ],
      [
        "\\D+$", "[\\D]+$", "[^\\d]+$", "[^0-9]+$", "\\P{N}+$", "\\P{Number}+$",
        "[^\\p{N}]+$", "[^\\p{Number}]+$",
      ],
      14,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^\\w+", "^[A-Za-z0-9_]+"],
      ["\\w+$", "[A-Za-z0-9_]+$"],
      4,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^\\W+", "^[^\\w]+", "^[^A-Za-z0-9_]+"],
      ["\\W+$", "[^\\w]+$", "[^A-Za-z0-9_]+$"],
      13,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^[A-Za-z0-9]+", "^[a-zA-Z0-9]+"],
      ["[A-Za-z0-9]+$", "[a-zA-Z0-9]+$"],
      5,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^[^A-Za-z0-9]+", "^[^a-zA-Z0-9]+"],
      ["[^A-Za-z0-9]+$", "[^a-zA-Z0-9]+$"],
      15,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^[A-Za-z]+", "^[a-zA-Z]+"],
      ["[A-Za-z]+$", "[a-zA-Z]+$"],
      6,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^[^A-Za-z]+", "^[^a-zA-Z]+"],
      ["[^A-Za-z]+$", "[^a-zA-Z]+$"],
      16,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^\\p{L}+", "^\\p{Letter}+", "^[\\p{L}]+", "^[\\p{Letter}]+"],
      ["\\p{L}+$", "\\p{Letter}+$", "[\\p{L}]+$", "[\\p{Letter}]+$"],
      7,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^\\P{L}+", "^\\P{Letter}+", "^[^\\p{L}]+", "^[^\\p{Letter}]+"],
      ["\\P{L}+$", "\\P{Letter}+$", "[^\\p{L}]+$", "[^\\p{Letter}]+$"],
      17,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^\\p{P}+", "^\\p{Punctuation}+", "^[\\p{P}]+", "^[\\p{Punctuation}]+"],
      ["\\p{P}+$", "\\p{Punctuation}+$", "[\\p{P}]+$", "[\\p{Punctuation}]+$"],
      8,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^\\P{P}+", "^\\P{Punctuation}+", "^[^\\p{P}]+", "^[^\\p{Punctuation}]+"],
      ["\\P{P}+$", "\\P{Punctuation}+$", "[^\\p{P}]+$", "[^\\p{Punctuation}]+$"],
      18,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^\\p{S}+", "^\\p{Symbol}+", "^[\\p{S}]+", "^[\\p{Symbol}]+"],
      ["\\p{S}+$", "\\p{Symbol}+$", "[\\p{S}]+$", "[\\p{Symbol}]+$"],
      9,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      ["^\\P{S}+", "^\\P{Symbol}+", "^[^\\p{S}]+", "^[^\\p{Symbol}]+"],
      ["\\P{S}+$", "\\P{Symbol}+$", "[^\\p{S}]+$", "[^\\p{Symbol}]+$"],
      19,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      [
        "^[\\p{P}\\p{S}]+", "^[\\p{S}\\p{P}]+", "^[\\p{Punctuation}\\p{Symbol}]+",
        "^[\\p{Symbol}\\p{Punctuation}]+",
      ],
      [
        "[\\p{P}\\p{S}]+$", "[\\p{S}\\p{P}]+$", "[\\p{Punctuation}\\p{Symbol}]+$",
        "[\\p{Symbol}\\p{Punctuation}]+$",
      ],
      10,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    anchored_variants(
      pattern,
      [
        "^[^\\p{P}\\p{S}]+", "^[^\\p{S}\\p{P}]+", "^[^\\p{Punctuation}\\p{Symbol}]+",
        "^[^\\p{Symbol}\\p{Punctuation}]+",
      ],
      [
        "[^\\p{P}\\p{S}]+$", "[^\\p{S}\\p{P}]+$", "[^\\p{Punctuation}\\p{Symbol}]+$",
        "[^\\p{Symbol}\\p{Punctuation}]+$",
      ],
      20,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  anchored_variants(
    pattern,
    [
      "^[^\\s\\p{L}\\p{N}]+", "^[^\\s\\p{N}\\p{L}]+", "^[^\\p{L}\\p{N}\\s]+", "^[^\\p{N}\\p{L}\\s]+",
      "^[^\\s\\p{Letter}\\p{Number}]+",
    ],
    [
      "[^\\s\\p{L}\\p{N}]+$", "[^\\s\\p{N}\\p{L}]+$", "[^\\p{L}\\p{N}\\s]+$", "[^\\p{N}\\p{L}\\s]+$",
      "[^\\s\\p{Letter}\\p{Number}]+$",
    ],
    21,
  )
}

///|
pub fn is_anchored_regex_pattern(pattern : String) -> Bool {
  match anchored_regex_kind(pattern) {
    Some(_) => true
    None => false
  }
}

///|
fn bounded_max(pattern : String, p2 : String, p3 : String, p4 : String) -> Int {
  if pattern == p2 {
    2
  } else if pattern == p3 {
    3
  } else if pattern == p4 {
    4
  } else {
    0
  }
}

///|
fn bounded_max_variants(
  pattern : String,
  p2 : Array[String],
  p3 : Array[String],
  p4 : Array[String],
) -> Int {
  for p in p2 {
    if pattern == p {
      return 2
    }
  }
  for p in p3 {
    if pattern == p {
      return 3
    }
  }
  for p in p4 {
    if pattern == p {
      return 4
    }
  }
  0
}

///|
fn ranged_kind_variants(
  pattern : String,
  kind : Int,
  p23 : Array[String],
  p24 : Array[String],
  p34 : Array[String],
) -> (Int, Int, Int)? {
  for p in p23 {
    if pattern == p {
      return Some((kind, 2, 3))
    }
  }
  for p in p24 {
    if pattern == p {
      return Some((kind, 2, 4))
    }
  }
  for p in p34 {
    if pattern == p {
      return Some((kind, 3, 4))
    }
  }
  None
}

///|
fn quantified_base_matches(
  pattern : String,
  bases : Array[String],
  suffix : String,
) -> Bool {
  for base in bases {
    if pattern == base + suffix {
      return true
    }
  }
  false
}

///|
fn quantified_class_kind(pattern : String, suffix : String) -> Int? {
  if quantified_base_matches(pattern, ["\\s", "[\\s]"], suffix) {
    return Some(1)
  }
  if quantified_base_matches(pattern, ["[ \\t]", "[^\\S\\r\\n]"], suffix) {
    return Some(2)
  }
  if quantified_base_matches(pattern, ["[\\r\\n]", "[\r\n]"], suffix) {
    return Some(3)
  }
  if quantified_base_matches(pattern, ["\\w", "[A-Za-z0-9_]"], suffix) {
    return Some(4)
  }
  if quantified_base_matches(pattern, ["[A-Za-z0-9]", "[a-zA-Z0-9]"], suffix) {
    return Some(5)
  }
  if quantified_base_matches(pattern, ["[A-Za-z]", "[a-zA-Z]"], suffix) {
    return Some(6)
  }
  if quantified_base_matches(
      pattern,
      ["\\p{L}", "\\p{Letter}", "[\\p{L}]", "[\\p{Letter}]"],
      suffix,
    ) {
    return Some(7)
  }
  if quantified_base_matches(
      pattern,
      ["\\p{P}", "\\p{Punctuation}", "[\\p{P}]", "[\\p{Punctuation}]"],
      suffix,
    ) {
    return Some(8)
  }
  if quantified_base_matches(
      pattern,
      ["\\p{S}", "\\p{Symbol}", "[\\p{S}]", "[\\p{Symbol}]"],
      suffix,
    ) {
    return Some(9)
  }
  if quantified_base_matches(
      pattern,
      [
        "[\\p{P}\\p{S}]", "[\\p{S}\\p{P}]", "[\\p{Punctuation}\\p{Symbol}]", "[\\p{Symbol}\\p{Punctuation}]",
      ],
      suffix,
    ) {
    return Some(10)
  }
  if quantified_base_matches(
      pattern,
      [
        "\\d", "[\\d]", "[0-9]", "\\p{N}", "\\p{Number}", "[\\p{N}]", "[\\p{Number}]",
      ],
      suffix,
    ) {
    return Some(11)
  }
  if quantified_base_matches(pattern, ["\\S", "[^\\s]"], suffix) {
    return Some(12)
  }
  if quantified_base_matches(
      pattern,
      ["\\W", "[^\\w]", "[^A-Za-z0-9_]"],
      suffix,
    ) {
    return Some(13)
  }
  if quantified_base_matches(
      pattern,
      [
        "\\D", "[\\D]", "[^\\d]", "[^0-9]", "\\P{N}", "\\P{Number}", "[^\\p{N}]",
        "[^\\p{Number}]",
      ],
      suffix,
    ) {
    return Some(14)
  }
  if quantified_base_matches(pattern, ["[^A-Za-z0-9]", "[^a-zA-Z0-9]"], suffix) {
    return Some(15)
  }
  if quantified_base_matches(pattern, ["[^A-Za-z]", "[^a-zA-Z]"], suffix) {
    return Some(16)
  }
  if quantified_base_matches(
      pattern,
      ["\\P{L}", "\\P{Letter}", "[^\\p{L}]", "[^\\p{Letter}]"],
      suffix,
    ) {
    return Some(17)
  }
  if quantified_base_matches(
      pattern,
      ["\\P{P}", "\\P{Punctuation}", "[^\\p{P}]", "[^\\p{Punctuation}]"],
      suffix,
    ) {
    return Some(18)
  }
  if quantified_base_matches(
      pattern,
      ["\\P{S}", "\\P{Symbol}", "[^\\p{S}]", "[^\\p{Symbol}]"],
      suffix,
    ) {
    return Some(19)
  }
  if quantified_base_matches(
      pattern,
      [
        "[^\\p{P}\\p{S}]", "[^\\p{S}\\p{P}]", "[^\\p{Punctuation}\\p{Symbol}]", "[^\\p{Symbol}\\p{Punctuation}]",
      ],
      suffix,
    ) {
    return Some(20)
  }
  if quantified_base_matches(
      pattern,
      [
        "[^\\s\\p{L}\\p{N}]", "[^\\s\\p{N}\\p{L}]", "[^\\p{L}\\p{N}\\s]", "[^\\p{N}\\p{L}\\s]",
        "[^\\s\\p{Letter}\\p{Number}]",
      ],
      suffix,
    ) {
    return Some(21)
  }
  None
}

///|
fn anchored_variants(
  pattern : String,
  leading : Array[String],
  trailing : Array[String],
  kind : Int,
) -> (Int, Bool)? {
  for p in leading {
    if pattern == p {
      return Some((kind, true))
    }
  }
  for p in trailing {
    if pattern == p {
      return Some((kind, false))
    }
  }
  None
}

///|
pub fn bounded_regex_kind_pred(kind : Int, c : Char) -> Bool {
  match kind {
    1 => is_unicode_whitespace(c.to_int())
    2 => is_unicode_whitespace(c.to_int()) && c != '\r' && c != '\n'
    3 => c == '\r' || c == '\n'
    4 => is_word_char(c)
    5 => is_ascii_alnum(c)
    6 => is_ascii_letter(c)
    7 => is_unicode_letter(c)
    8 => is_unicode_punctuation(c)
    9 => is_unicode_symbol(c)
    10 => is_unicode_punctuation_or_symbol(c)
    11 => is_decimal_number(c)
    12 => !is_unicode_whitespace(c.to_int())
    13 => !is_word_char(c)
    14 => !is_decimal_number(c)
    15 => !is_ascii_alnum(c)
    16 => !is_ascii_letter(c)
    17 => !is_unicode_letter(c)
    18 => !is_unicode_punctuation(c)
    19 => !is_unicode_symbol(c)
    20 => !is_unicode_punctuation_or_symbol(c)
    21 => is_not_whitespace_letter_or_number(c)
    _ => false
  }
}

///|
/// Unicode whitespace coverage used for HF/Rust-regex `\s`.
pub fn is_unicode_whitespace(u : Int) -> Bool {
  u == 0x09 ||
  u == 0x0A ||
  u == 0x0B ||
  u == 0x0C ||
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

///|
/// Build a one-character String.
pub fn char_string(c : Char) -> String {
  let sb = StringBuilder::new()
  sb.write_char(c)
  sb.to_string()
}
