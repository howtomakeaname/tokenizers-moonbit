///|
pub fn is_simple_split_regex_pattern(pattern : String) -> Bool {
  regex_literal_spec(pattern) is Some(_) ||
  regex_literal_alternatives_spec(pattern) is Some(_) ||
  is_simple_space_regex_pattern(pattern) ||
  is_exact_regex_pattern(pattern) ||
  is_min_regex_pattern(pattern) ||
  is_bounded_regex_pattern(pattern) ||
  is_anchored_regex_pattern(pattern) ||
  is_ranged_regex_pattern(pattern) ||
  pattern == "\\w+" ||
  pattern == "[A-Za-z0-9_]+" ||
  pattern == "\\b\\w+\\b" ||
  pattern == "\\b[A-Za-z0-9_]+\\b" ||
  pattern == "^\\w+" ||
  pattern == "^[A-Za-z0-9_]+" ||
  pattern == "\\w+$" ||
  pattern == "[A-Za-z0-9_]+$" ||
  pattern == "\\W+" ||
  pattern == "[^\\w]+" ||
  pattern == "[^A-Za-z0-9_]+" ||
  pattern == "\\w{2,}" ||
  pattern == "[A-Za-z0-9_]{2,}" ||
  pattern == "\\w{2}" ||
  pattern == "[A-Za-z0-9_]{2}" ||
  pattern == "\\w{3}" ||
  pattern == "[A-Za-z0-9_]{3}" ||
  pattern == "\\w{4}" ||
  pattern == "[A-Za-z0-9_]{4}" ||
  pattern == "[A-Za-z0-9]+" ||
  pattern == "[a-zA-Z0-9]+" ||
  pattern == "[A-Za-z0-9]{2,}" ||
  pattern == "[a-zA-Z0-9]{2,}" ||
  pattern == "[A-Za-z0-9]{2}" ||
  pattern == "[a-zA-Z0-9]{2}" ||
  pattern == "[A-Za-z0-9]{3}" ||
  pattern == "[a-zA-Z0-9]{3}" ||
  pattern == "[A-Za-z0-9]{4}" ||
  pattern == "[a-zA-Z0-9]{4}" ||
  pattern == "^[A-Za-z0-9]+" ||
  pattern == "^[a-zA-Z0-9]+" ||
  pattern == "[A-Za-z0-9]+$" ||
  pattern == "[a-zA-Z0-9]+$" ||
  pattern == "[^A-Za-z0-9]+" ||
  pattern == "[^a-zA-Z0-9]+" ||
  pattern == "[A-Za-z]+" ||
  pattern == "[a-zA-Z]+" ||
  pattern == "[A-Za-z]{2,}" ||
  pattern == "[a-zA-Z]{2,}" ||
  pattern == "[A-Za-z]{2}" ||
  pattern == "[a-zA-Z]{2}" ||
  pattern == "[A-Za-z]{3}" ||
  pattern == "[a-zA-Z]{3}" ||
  pattern == "[A-Za-z]{4}" ||
  pattern == "[a-zA-Z]{4}" ||
  pattern == "^[A-Za-z]+" ||
  pattern == "^[a-zA-Z]+" ||
  pattern == "[A-Za-z]+$" ||
  pattern == "[a-zA-Z]+$" ||
  pattern == "[^A-Za-z]+" ||
  pattern == "[^a-zA-Z]+" ||
  pattern == "\\p{L}+" ||
  pattern == "\\p{Letter}+" ||
  pattern == "[\\p{L}]+" ||
  pattern == "[\\p{Letter}]+" ||
  pattern == "\\p{L}{2,}" ||
  pattern == "\\p{Letter}{2,}" ||
  pattern == "[\\p{L}]{2,}" ||
  pattern == "[\\p{Letter}]{2,}" ||
  pattern == "\\p{L}{2}" ||
  pattern == "\\p{Letter}{2}" ||
  pattern == "[\\p{L}]{2}" ||
  pattern == "[\\p{Letter}]{2}" ||
  pattern == "\\p{L}{3}" ||
  pattern == "\\p{Letter}{3}" ||
  pattern == "[\\p{L}]{3}" ||
  pattern == "[\\p{Letter}]{3}" ||
  pattern == "\\p{L}{4}" ||
  pattern == "\\p{Letter}{4}" ||
  pattern == "[\\p{L}]{4}" ||
  pattern == "[\\p{Letter}]{4}" ||
  pattern == "^\\p{L}+" ||
  pattern == "^\\p{Letter}+" ||
  pattern == "^[\\p{L}]+" ||
  pattern == "^[\\p{Letter}]+" ||
  pattern == "\\p{L}+$" ||
  pattern == "\\p{Letter}+$" ||
  pattern == "[\\p{L}]+$" ||
  pattern == "[\\p{Letter}]+$" ||
  pattern == "\\P{L}+" ||
  pattern == "\\P{Letter}+" ||
  pattern == "[^\\p{L}]+" ||
  pattern == "[^\\p{Letter}]+" ||
  is_simple_punctuation_symbol_regex_pattern(pattern) ||
  is_simple_number_regex_pattern(pattern)
}

///|
fn is_simple_space_regex_pattern(pattern : String) -> Bool {
  pattern == "\\s+" ||
  pattern == " {2,}" ||
  pattern == "\\s{2,}" ||
  pattern == "[\\s]{2,}" ||
  pattern == "\\s{3,}" ||
  pattern == "[\\s]{3,}" ||
  pattern == "\\s{4,}" ||
  pattern == "[\\s]{4,}" ||
  pattern == "\\s{2}" ||
  pattern == "[\\s]{2}" ||
  pattern == "\\s{3}" ||
  pattern == "[\\s]{3}" ||
  pattern == "\\s{4}" ||
  pattern == "[\\s]{4}" ||
  pattern == "^\\s+" ||
  pattern == "\\S+" ||
  pattern == "[^\\s]+" ||
  pattern == "\\s+$" ||
  pattern == "[ \\t]+" ||
  pattern == "[^\\S\\r\\n]+" ||
  pattern == "[ \\t]{2,}" ||
  pattern == "[^\\S\\r\\n]{2,}" ||
  pattern == "[ \\t]{3,}" ||
  pattern == "[^\\S\\r\\n]{3,}" ||
  pattern == "[ \\t]{4,}" ||
  pattern == "[^\\S\\r\\n]{4,}" ||
  pattern == "[ \\t]{2}" ||
  pattern == "[^\\S\\r\\n]{2}" ||
  pattern == "[ \\t]{3}" ||
  pattern == "[^\\S\\r\\n]{3}" ||
  pattern == "[ \\t]{4}" ||
  pattern == "[^\\S\\r\\n]{4}" ||
  pattern == "[\\r\\n]" ||
  pattern == "[\r\n]" ||
  pattern == "[\\r\\n]+" ||
  pattern == "[\r\n]+" ||
  pattern == "[\\r\\n]{2,}" ||
  pattern == "[\r\n]{2,}" ||
  pattern == "[\\r\\n]{3,}" ||
  pattern == "[\r\n]{3,}" ||
  pattern == "[\\r\\n]{4,}" ||
  pattern == "[\r\n]{4,}" ||
  pattern == "[\\r\\n]{2}" ||
  pattern == "[\r\n]{2}" ||
  pattern == "[\\r\\n]{3}" ||
  pattern == "[\r\n]{3}" ||
  pattern == "[\\r\\n]{4}" ||
  pattern == "[\r\n]{4}"
}

///|
fn is_simple_punctuation_symbol_regex_pattern(pattern : String) -> Bool {
  pattern == "\\p{P}+" ||
  pattern == "\\p{Punctuation}+" ||
  pattern == "[\\p{P}]+" ||
  pattern == "[\\p{Punctuation}]+" ||
  pattern == "\\p{P}{2,}" ||
  pattern == "\\p{Punctuation}{2,}" ||
  pattern == "[\\p{P}]{2,}" ||
  pattern == "[\\p{Punctuation}]{2,}" ||
  pattern == "\\p{P}{2}" ||
  pattern == "\\p{Punctuation}{2}" ||
  pattern == "[\\p{P}]{2}" ||
  pattern == "[\\p{Punctuation}]{2}" ||
  pattern == "\\p{P}{3}" ||
  pattern == "\\p{Punctuation}{3}" ||
  pattern == "[\\p{P}]{3}" ||
  pattern == "[\\p{Punctuation}]{3}" ||
  pattern == "\\p{P}{4}" ||
  pattern == "\\p{Punctuation}{4}" ||
  pattern == "[\\p{P}]{4}" ||
  pattern == "[\\p{Punctuation}]{4}" ||
  pattern == "^\\p{P}+" ||
  pattern == "^\\p{Punctuation}+" ||
  pattern == "^[\\p{P}]+" ||
  pattern == "^[\\p{Punctuation}]+" ||
  pattern == "\\p{P}+$" ||
  pattern == "\\p{Punctuation}+$" ||
  pattern == "[\\p{P}]+$" ||
  pattern == "[\\p{Punctuation}]+$" ||
  pattern == "\\P{P}+" ||
  pattern == "\\P{Punctuation}+" ||
  pattern == "[^\\p{P}]+" ||
  pattern == "[^\\p{Punctuation}]+" ||
  pattern == "\\p{S}+" ||
  pattern == "\\p{Symbol}+" ||
  pattern == "[\\p{S}]+" ||
  pattern == "[\\p{Symbol}]+" ||
  pattern == "\\p{S}{2,}" ||
  pattern == "\\p{Symbol}{2,}" ||
  pattern == "[\\p{S}]{2,}" ||
  pattern == "[\\p{Symbol}]{2,}" ||
  pattern == "\\p{S}{2}" ||
  pattern == "\\p{Symbol}{2}" ||
  pattern == "[\\p{S}]{2}" ||
  pattern == "[\\p{Symbol}]{2}" ||
  pattern == "\\p{S}{3}" ||
  pattern == "\\p{Symbol}{3}" ||
  pattern == "[\\p{S}]{3}" ||
  pattern == "[\\p{Symbol}]{3}" ||
  pattern == "\\p{S}{4}" ||
  pattern == "\\p{Symbol}{4}" ||
  pattern == "[\\p{S}]{4}" ||
  pattern == "[\\p{Symbol}]{4}" ||
  pattern == "^\\p{S}+" ||
  pattern == "^\\p{Symbol}+" ||
  pattern == "^[\\p{S}]+" ||
  pattern == "^[\\p{Symbol}]+" ||
  pattern == "\\p{S}+$" ||
  pattern == "\\p{Symbol}+$" ||
  pattern == "[\\p{S}]+$" ||
  pattern == "[\\p{Symbol}]+$" ||
  pattern == "\\P{S}+" ||
  pattern == "\\P{Symbol}+" ||
  pattern == "[^\\p{S}]+" ||
  pattern == "[^\\p{Symbol}]+" ||
  pattern == "[\\p{P}\\p{S}]+" ||
  pattern == "[\\p{S}\\p{P}]+" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]+" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]+" ||
  pattern == "[\\p{P}\\p{S}]{2,}" ||
  pattern == "[\\p{S}\\p{P}]{2,}" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]{2,}" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]{2,}" ||
  pattern == "[\\p{P}\\p{S}]{2}" ||
  pattern == "[\\p{S}\\p{P}]{2}" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]{2}" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]{2}" ||
  pattern == "[\\p{P}\\p{S}]{3}" ||
  pattern == "[\\p{S}\\p{P}]{3}" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]{3}" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]{3}" ||
  pattern == "[\\p{P}\\p{S}]{4}" ||
  pattern == "[\\p{S}\\p{P}]{4}" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]{4}" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]{4}" ||
  pattern == "^[\\p{P}\\p{S}]+" ||
  pattern == "^[\\p{S}\\p{P}]+" ||
  pattern == "^[\\p{Punctuation}\\p{Symbol}]+" ||
  pattern == "^[\\p{Symbol}\\p{Punctuation}]+" ||
  pattern == "[\\p{P}\\p{S}]+$" ||
  pattern == "[\\p{S}\\p{P}]+$" ||
  pattern == "[\\p{Punctuation}\\p{Symbol}]+$" ||
  pattern == "[\\p{Symbol}\\p{Punctuation}]+$" ||
  pattern == "[^\\p{P}\\p{S}]+" ||
  pattern == "[^\\p{S}\\p{P}]+" ||
  pattern == "[^\\p{Punctuation}\\p{Symbol}]+" ||
  pattern == "[^\\p{Symbol}\\p{Punctuation}]+" ||
  pattern == "[^\\s\\p{L}\\p{N}]+" ||
  pattern == "[^\\s\\p{N}\\p{L}]+" ||
  pattern == "[^\\p{L}\\p{N}\\s]+" ||
  pattern == "[^\\p{N}\\p{L}\\s]+" ||
  pattern == "[^\\s\\p{Letter}\\p{Number}]+"
}

///|
fn is_simple_number_regex_pattern(pattern : String) -> Bool {
  pattern == "\\d+" ||
  pattern == "[\\d]+" ||
  pattern == "[0-9]+" ||
  pattern == "\\p{N}+" ||
  pattern == "\\p{Number}+" ||
  pattern == "[\\p{N}]+" ||
  pattern == "[\\p{Number}]+" ||
  pattern == "^\\d+" ||
  pattern == "^[\\d]+" ||
  pattern == "^[0-9]+" ||
  pattern == "^\\p{N}+" ||
  pattern == "^\\p{Number}+" ||
  pattern == "^[\\p{N}]+" ||
  pattern == "^[\\p{Number}]+" ||
  pattern == "\\d+$" ||
  pattern == "[\\d]+$" ||
  pattern == "[0-9]+$" ||
  pattern == "\\p{N}+$" ||
  pattern == "\\p{Number}+$" ||
  pattern == "[\\p{N}]+$" ||
  pattern == "[\\p{Number}]+$" ||
  pattern == "\\D+" ||
  pattern == "[\\D]+" ||
  pattern == "[^\\d]+" ||
  pattern == "[^0-9]+" ||
  pattern == "\\P{N}+" ||
  pattern == "\\P{Number}+" ||
  pattern == "[^\\p{N}]+" ||
  pattern == "[^\\p{Number}]+" ||
  pattern == "\\d{2,}" ||
  pattern == "[\\d]{2,}" ||
  pattern == "[0-9]{2,}" ||
  pattern == "\\p{N}{2,}" ||
  pattern == "\\p{Number}{2,}" ||
  pattern == "[\\p{N}]{2,}" ||
  pattern == "[\\p{Number}]{2,}" ||
  pattern == "\\p{N}{2}" ||
  pattern == "\\p{Number}{2}" ||
  pattern == "[\\p{N}]{2}" ||
  pattern == "[\\p{Number}]{2}" ||
  pattern == "\\d{2}" ||
  pattern == "[\\d]{2}" ||
  pattern == "[0-9]{2}" ||
  pattern == "\\p{N}{3}" ||
  pattern == "\\p{Number}{3}" ||
  pattern == "[\\p{N}]{3}" ||
  pattern == "[\\p{Number}]{3}" ||
  pattern == "\\d{3}" ||
  pattern == "[\\d]{3}" ||
  pattern == "[0-9]{3}" ||
  pattern == "\\p{N}{4}" ||
  pattern == "\\p{Number}{4}" ||
  pattern == "[\\p{N}]{4}" ||
  pattern == "[\\p{Number}]{4}" ||
  pattern == "\\d{4}" ||
  pattern == "[\\d]{4}" ||
  pattern == "[0-9]{4}" ||
  pattern == "\\p{N}{1,2}" ||
  pattern == "\\p{Number}{1,2}" ||
  pattern == "[\\p{N}]{1,2}" ||
  pattern == "[\\p{Number}]{1,2}" ||
  pattern == "\\d{1,2}" ||
  pattern == "[\\d]{1,2}" ||
  pattern == "[0-9]{1,2}" ||
  pattern == "[0-9][0-9]" ||
  pattern == "\\p{N}{1,3}" ||
  pattern == "\\p{Number}{1,3}" ||
  pattern == "[\\p{N}]{1,3}" ||
  pattern == "[\\p{Number}]{1,3}" ||
  pattern == "\\d{1,3}" ||
  pattern == "[\\d]{1,3}" ||
  pattern == "[0-9]{1,3}" ||
  pattern == "[0-9][0-9][0-9]" ||
  pattern == "\\p{N}{1,4}" ||
  pattern == "\\p{Number}{1,4}" ||
  pattern == "[\\p{N}]{1,4}" ||
  pattern == "[\\p{Number}]{1,4}" ||
  pattern == "\\d{1,4}" ||
  pattern == "[\\d]{1,4}" ||
  pattern == "[0-9]{1,4}" ||
  pattern == "[0-9][0-9][0-9][0-9]"
}

///|
