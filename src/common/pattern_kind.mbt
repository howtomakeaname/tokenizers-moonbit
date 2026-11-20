///|
/// HuggingFace `Replace.pattern` is tagged as either a literal string or a
/// regex. Keeping the tag lets component state round-trip without conflating the
/// two forms.
#derive(Debug, Eq)
pub(all) enum PatternKind {
  StringPattern
  RegexPattern
}

///|
pub extend PatternKind with Eq::{equal, not_equal}

///|
pub extend PatternKind with @debug.Debug::{to_repr}
