///|
/// HuggingFace `Replace.pattern` is tagged as either a literal string or a
/// regex. Keeping the tag lets component state round-trip without conflating the
/// two forms.
pub(all) enum PatternKind {
  StringPattern
  RegexPattern
} derive(Debug, Eq)

///|
pub extend PatternKind with Eq::{equal, not_equal}

///|
pub extend PatternKind with @debug.Debug::{to_repr}
