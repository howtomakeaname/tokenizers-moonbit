#!/usr/bin/env python3
"""Behavioral-comparison case generator + golden runner (Python tokenizers 0.22.2).

Emits cases.json (shared input for the MoonBit driver) and golden.json
(expected outputs from the local Python `tokenizers`). Each case = a
tokenizer.json string + inputs; we compare encode ids/tokens/offsets and
decode round-trips. Vocabularies are intentionally rich (multi-char merges,
case, punctuation, accents, fullwidth, CJK, digits) so BPE/WordPiece paths
are actually exercised.

A separate real_models.json lists local real tokenizer.json files with the
same input battery for end-to-end model sweeps.
"""
import json
import os
import sys

from tokenizers import Tokenizer

BPE_ALPHABET = list("abchloĠwertdspnumifgcyABCHLEIOTSW.,!?-:;()'\"1234567890\n\tＬｕｎｉｃｏｄé你好，世界！？『』「」・ー")
BPE_MERGES = [
    ["a", "b"], ["ab", "c"], ["Ġ", "a"], ["h", "e"], ["l", "lo"],
    ["Ġ", "hello"], ["Ġ", "w"], ["Ġw", "or"], ["o", "r"], ["or", "ld"],
    ["Ġw", "orld"], ["t", "he"], ["Ġ", "the"], ["in", "g"], ["Ġin", "g"],
    ["e", "r"], ["er", "ing"], ["Ġ", "er"], ["Ġ", "world"], ["Ġo", "f"],
    ["an", "d"], ["Ġa", "nd"], ["H", "e"], ["He", "llo"], ["Ġ", "space"],
    ["i", "s"], ["Ġ", "is"], ["te", "st"], ["Ġt", "est"], ["Ｌ", "＇"],
    ["你", "好"], ["世", "界"], ["na", "ï"], ["ï", "ve"], ["ré", "sumé"],
    ["ca", "fé"], ["1", "2"], ["12", "3"], ["Ġ", "d"], ["en", "code"],
    ["de", "code"], ["Ġde", "code"], ["to", "ken"], ["Ġ", "token"],
    ["Ġtok", "en"], ["iz", "er"], ["Ġi", "z"], ["Ġ", "s"], ["Ġs", "p"],
    [".", "."], ["..", "."], ["!", "!"], ["!!", "!"], ["?", "?"],
    ["Ġ", "123"], ["Ġ1", "23"], ["Ġ", "n"], ["Ġn", "ew"], ["li", "ne"],
    ["Ġ", "line"], ["Ġli", "nes"], ["Ċ", "ĠĠ"], ["Ġ", "Ġ"],
]
_merged = {a + b for a, b in BPE_MERGES}
_parts = {p for pair in BPE_MERGES for p in pair}
BPE_VOCAB = {"<|endoftext|>": 0}
for i, tok in enumerate(dict.fromkeys(BPE_ALPHABET + sorted(_parts | _merged)), start=1):
    BPE_VOCAB[tok] = i

WORDPIECE_VOCAB = {
    "[PAD]": 0, "[UNK]": 1, "[CLS]": 2, "[SEP]": 3, "[MASK]": 4,
    "hello": 5, "##world": 6, "café": 7, "nom": 8, "##ade": 9,
    "ｈｅｌｌｏ": 10, "e": 12, "ç": 14, "##f": 15,
    "the": 16, "##re": 17, "is": 18, "##a": 19, "test": 20,
    "en": 21, "##coding": 22, "tok": 23, "##en": 24, "##izer": 25,
    "wide": 26, "##cards": 27, "you": 28, "##好": 29, "世": 30, "界": 31,
    "ｌ": 32, "##ｕ": 33, "ｎ": 34, "##ｉ": 35, "tab": 36, "##s": 37,
    "Ｌ": 38, "##＇": 39, "a": 40, "##b": 41, "##c": 42, "de": 43,
    "##code": 44, "with": 45, "##spaces": 46, "mid": 47, "##dle": 48,
}
INPUTS = [
    "Hello world",
    "hello world",
    "abc ab a",
    "  leading and trailing   ",
    "café café Nomade NOMADE",
    "Ｌｕｎｉｃｏｄé ｈｅｌｌｏ",
    "你好，世界！ Hello",
    "tabs\tand\nnewlines\r\n mixed",
    "Mixed123Numbers456 and 007 zero",
    "punct!!! ...??? --- ok;; ((()))",
    "naïve résumé",
    "éclair séance",
    "def tokenize(text): return text.split(' ')  # comment",
    "The quick brown fox jumps over the lazy dog",
    "THE WORLD WIDE WEB consortium",
    "new\nlines\n\nand   multiple     spaces",
    "identifier_name and camelCase and CONST_VALUE",
    "1234567890 987 42",
    "mixed 你好 world ＴＯＫＥＮ café 42!",
    "trailing punctuation?!...;;",
]


def bpe_tokenizer(normalizer=None, pre_tokenizer=None, post=None, decoder=None, added=None):
    return {
        "version": "1.0",
        "truncation": None, "padding": None,
        "added_tokens": added or [],
        "normalizer": normalizer,
        "pre_tokenizer": pre_tokenizer,
        "post_processor": post,
        "decoder": decoder,
        "model": {
            "type": "BPE", "dropout": None, "unk_token": "<|endoftext|>",
            "continuing_subword_prefix": None, "end_of_word_suffix": None,
            "fuse_unk": False, "byte_fallback": False,
            "vocab": BPE_VOCAB, "merges": BPE_MERGES,
        },
    }


def wordpiece_tokenizer(normalizer=None, pre_tokenizer=None, post=None, decoder=None, added=None):
    return {
        "version": "1.0",
        "truncation": None, "padding": None,
        "added_tokens": added or [],
        "normalizer": normalizer,
        "pre_tokenizer": pre_tokenizer or {"type": "BertPreTokenizer"},
        "post_processor": post or {"type": "BertProcessing", "cls": ["[CLS]", 2], "sep": ["[SEP]", 3]},
        "decoder": decoder or {"type": "WordPiece", "prefix": "##", "cleanup": True},
        "model": {
            "type": "WordPiece", "unk_token": "[UNK]",
            "continuing_subword_prefix": "##", "max_input_chars_per_word": 10,
            "vocab": WORDPIECE_VOCAB,
        },
    }


CASES = []


def add(name, tok, inputs=None):
    CASES.append({
        "name": name,
        "tokenizer_json": json.dumps(tok, ensure_ascii=False),
        "inputs": inputs if inputs is not None else INPUTS,
    })


# ---- normalizer matrix (wordpiece) ----
add("norm-none", wordpiece_tokenizer(normalizer=None))
add("norm-lower", wordpiece_tokenizer(normalizer={"type": "Lowercase"}))
add("norm-strip", wordpiece_tokenizer(normalizer={"type": "Strip", "strip_left": True, "strip_right": True}))
add("norm-strip-accents", wordpiece_tokenizer(normalizer={"type": "StripAccents", "strip_accents": True}))
add("norm-bert", wordpiece_tokenizer(normalizer={"type": "BertNormalizer", "clean_text": True, "handle_chinese_chars": True, "strip_accents": None, "lowercase": True}))
add("norm-bert-nolower-stripaccents", wordpiece_tokenizer(normalizer={"type": "BertNormalizer", "clean_text": True, "handle_chinese_chars": True, "strip_accents": True, "lowercase": False}))
add("norm-bert-nochinese", wordpiece_tokenizer(normalizer={"type": "BertNormalizer", "clean_text": True, "handle_chinese_chars": False, "strip_accents": None, "lowercase": False}))
add("norm-nfc", wordpiece_tokenizer(normalizer={"type": "NFC"}))
add("norm-nfd", wordpiece_tokenizer(normalizer={"type": "NFD"}))
add("norm-nfkc", wordpiece_tokenizer(normalizer={"type": "NFKC"}))
add("norm-nfkd", wordpiece_tokenizer(normalizer={"type": "NFKD"}))
add("norm-replace", wordpiece_tokenizer(normalizer={"type": "Replace", "pattern": {"String": "café"}, "content": "coffee"}))
add("norm-prepend", wordpiece_tokenizer(normalizer={"type": "Prepend", "prepend": "ｈ"}))
add("norm-sequence", wordpiece_tokenizer(normalizer={"type": "Sequence", "normalizers": [
    {"type": "NFD"}, {"type": "StripAccents", "strip_accents": True}, {"type": "Lowercase"}]}))

# ---- pre-tokenizer matrix (bpe) ----
BL = {"type": "ByteLevel", "add_prefix_space": False, "use_regex": False, "trim_offsets": True}
add("pre-bytlelevel", bpe_tokenizer(pre_tokenizer=BL, post={"type": "ByteLevel", "add_prefix_space": False, "trim_offsets": True}))
add("pre-bytlelevel-prefix", bpe_tokenizer(pre_tokenizer={**BL, "add_prefix_space": True}, post={"type": "ByteLevel", "add_prefix_space": True, "trim_offsets": True}))
add("pre-whitespace", bpe_tokenizer(pre_tokenizer={"type": "Whitespace"}))
add("pre-whitespacesplit", bpe_tokenizer(pre_tokenizer={"type": "WhitespaceSplit"}))
add("pre-bertpre", bpe_tokenizer(pre_tokenizer={"type": "BertPreTokenizer"}))
add("pre-metaspace", bpe_tokenizer(pre_tokenizer={"type": "Metaspace", "replacement": "▁", "prepend_scheme": "always"}))
add("pre-metaspace-first", bpe_tokenizer(pre_tokenizer={"type": "Metaspace", "replacement": "▁", "prepend_scheme": "first"}))
add("pre-metaspace-never", bpe_tokenizer(pre_tokenizer={"type": "Metaspace", "replacement": "▁", "prepend_scheme": "never"}))
add("pre-punctuation", bpe_tokenizer(pre_tokenizer={"type": "Punctuation", "behavior": "Isolated"}))
add("pre-punctuation-lossy", bpe_tokenizer(pre_tokenizer={"type": "Punctuation", "behavior": "Removed"}))
add("pre-digits", bpe_tokenizer(pre_tokenizer={"type": "Digits", "individual_digits": True}))
add("pre-digits-grouped", bpe_tokenizer(pre_tokenizer={"type": "Digits", "individual_digits": False}))
add("pre-delimiter", bpe_tokenizer(pre_tokenizer={"type": "CharDelimiterSplit", "delimiter": "-"}))
add("pre-sequence", bpe_tokenizer(pre_tokenizer={"type": "Sequence", "pretokenizers": [
    {"type": "Digits", "individual_digits": True}, {"type": "WhitespaceSplit"}]}))

# ---- decoder matrix ----
add("dec-bpe", bpe_tokenizer(pre_tokenizer=BL, post={"type": "ByteLevel", "add_prefix_space": False, "trim_offsets": True}, decoder={"type": "BPEDecoder", "suffix": "</w>"}))
add("dec-wordpiece-direct", wordpiece_tokenizer(decoder={"type": "WordPiece", "prefix": "##", "cleanup": True}))
add("dec-wordpiece-nocleanup", wordpiece_tokenizer(decoder={"type": "WordPiece", "prefix": "##", "cleanup": False}))
add("dec-metaspace", bpe_tokenizer(pre_tokenizer={"type": "Metaspace", "replacement": "▁", "prepend_scheme": "always"}, decoder={"type": "Metaspace", "replacement": "▁", "prepend_scheme": "always"}))
add("dec-ctc", wordpiece_tokenizer(decoder={"type": "CTC", "pad_token": "<pad>", "word_delimiter_token": "|", "cleanup": True}))
add("dec-sequence", wordpiece_tokenizer(decoder={"type": "Sequence", "decoders": [
    {"type": "WordPiece", "prefix": "##", "cleanup": True}, {"type": "Strip", "content": " ", "start": 1, "stop": 0}]}))
add("dec-replace", wordpiece_tokenizer(decoder={"type": "Replace", "pattern": {"String": "##"}, "content": ""}))
add("dec-strip", wordpiece_tokenizer(decoder={"type": "Strip", "content": "o", "start": 1, "stop": 1}))

# ---- added tokens / special tokens ----
add("added-special", wordpiece_tokenizer(added=[
    {"id": 5, "content": "<|endoftext|>", "single_word": False, "lstrip": False, "rstrip": False, "normalized": False, "special": True},
]))
add("added-lstrip-rstrip", wordpiece_tokenizer(added=[
    {"id": 5, "content": "hello", "single_word": False, "lstrip": True, "rstrip": True, "normalized": False, "special": False},
]))
add("added-single-word", wordpiece_tokenizer(added=[
    {"id": 5, "content": "café", "single_word": True, "lstrip": False, "rstrip": False, "normalized": False, "special": False},
]))

# ---- truncation / padding basics ----
def with_trunc_pad(tok, trunc=None, pad=None):
    t = dict(tok)
    t["truncation"] = trunc
    t["padding"] = pad
    return t

add("trunc-left", with_trunc_pad(wordpiece_tokenizer(), {"max_length": 3, "stride": 0, "strategy": "LongestFirst", "direction": "Left"}))
add("pad-left", with_trunc_pad(wordpiece_tokenizer(), None, {"strategy": {"Fixed": 8}, "direction": "Left", "pad_id": 0, "pad_token": "[PAD]", "pad_to_multiple_of": 0, "pad_type_id": 0}))
add("pad-batchlongest", with_trunc_pad(wordpiece_tokenizer(), None, {"strategy": "BatchLongest", "direction": "Right", "pad_id": 0, "pad_token": "[PAD]", "pad_to_multiple_of": 2, "pad_type_id": 0}))

# ---- real models sweep manifest ----
REAL_MODELS_DIR = os.environ.get(
    "PARITY_MODELS_DIR",
    "/Users/bytedance/Documents/projects/moonbit-exp-projects/consumer-eval/models",
)


def run_golden():
    golden = {}
    for case in CASES:
        tok = Tokenizer.from_str(case["tokenizer_json"])
        results = []
        for text in case["inputs"]:
            enc = tok.encode(text)
            results.append({
                "ids": enc.ids,
                "tokens": enc.tokens,
                "offsets": [list(o) for o in enc.offsets],
            })
        decs = []
        for r, text in zip(results[:4], case["inputs"][:4]):
            decs.append(tok.decode(r["ids"], skip_special_tokens=True))
        golden[case["name"]] = {"encode": results, "decode": decs}
    return golden


def run_real_models(out_dir):
    manifest = []
    if not os.path.isdir(REAL_MODELS_DIR):
        return manifest
    for fname in sorted(os.listdir(REAL_MODELS_DIR)):
        if not fname.endswith(".json"):
            continue
        path = os.path.join(REAL_MODELS_DIR, fname)
        try:
            tok = Tokenizer.from_file(path)
        except Exception:  # noqa: BLE001
            continue
        results = []
        for text in INPUTS:
            enc = tok.encode(text)
            results.append({
                "ids": enc.ids,
                "tokens": enc.tokens,
                "offsets": [list(o) for o in enc.offsets],
            })
        name = fname.replace(".json", "")
        with open(f"{out_dir}/real_{name}.golden.json", "w") as f:
            json.dump(results, f, ensure_ascii=False, separators=(",", ":"))
        manifest.append({"name": name, "path": path})
    return manifest


if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/parity-sweep"
    os.makedirs(out_dir, exist_ok=True)
    with open(f"{out_dir}/cases.json", "w") as f:
        json.dump(CASES, f, ensure_ascii=False, separators=(",", ":"))
    golden = run_golden()
    with open(f"{out_dir}/golden.json", "w") as f:
        json.dump(golden, f, ensure_ascii=False, separators=(",", ":"))
    manifest = run_real_models(out_dir)
    with open(f"{out_dir}/real_models.json", "w") as f:
        json.dump({"inputs": INPUTS, "models": manifest}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"cases: {len(CASES)} -> {out_dir}; real models: {len(manifest)}")
