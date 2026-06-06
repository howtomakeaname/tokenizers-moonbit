// WordLevel tokenization: the whole pre-token is a single vocabulary lookup,
// falling back to the unk token when absent.

pub fn WordLevelModel::tokenize(
  self : WordLevelModel,
  word : String,
  offset~ : Int = 0,
) -> Array[@types.Token] {
  let span = word.char_length()
  match self.vocab.get(word) {
    Some(id) =>
      [@types.Token::{ id, value: word, offsets: (offset, offset + span) }]
    None =>
      match self.vocab.get(self.unk_token) {
        Some(uid) =>
          [
            @types.Token::{
              id: uid,
              value: self.unk_token,
              offsets: (offset, offset + span),
            },
          ]
        None =>
          [@types.Token::{ id: -1, value: word, offsets: (offset, offset + span) }]
      }
  }
}
