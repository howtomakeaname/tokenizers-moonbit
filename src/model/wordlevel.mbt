// WordLevel tokenization: the whole pre-token is a single vocabulary lookup,
// falling back to the unk token when absent.

///|
pub fn WordLevelModel::tokenize(
  self : WordLevelModel,
  word : String,
  offset? : Int = 0,
) -> Array[@types.Token] raise @types.TokenizerError {
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
          raise @types.VocabError(
            "WordLevel error: Missing \{self.unk_token} token from the vocabulary",
          )
      }
  }
}
