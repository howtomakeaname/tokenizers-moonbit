#!/usr/bin/env python3
"""Compare tokenizers-moonbit with HuggingFace tokenizers on the same host.

This script intentionally reports **ratios** instead of only standalone timings:
`moonbit_us / hf_us`, where lower is better for tokenizers-moonbit. It runs
`moon bench --target <target>`, parses MoonBit's benchmark table, then measures
HF `tokenizers` on the same tokenizer.json fixtures and corpora.

Default scope covers every model fixture known to bench_python.py on the mixed
corpus. Use `--corpus all` for the full model × corpus encode matrix.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass

from bench_python import CORPORA, DATA, MODELS

try:
    from tokenizers import AddedToken
    from tokenizers import Tokenizer
    from tokenizers import Regex
    from tokenizers import decoders as hf_decoders
    from tokenizers import models as hf_models
    from tokenizers import normalizers as hf_normalizers
    from tokenizers import pre_tokenizers as hf_pre_tokenizers
    from tokenizers import trainers as hf_trainers
except Exception as exc:  # pragma: no cover - environment diagnostic
    print("ERROR: Python package 'tokenizers' is required: pip install tokenizers", file=sys.stderr)
    raise SystemExit(2) from exc


QUICK_MODELS = ["gpt2", "bert", "llama", "Qwen2.5", "phi4_mini", "qwen3_coder"]
DEFAULT_MODELS = MODELS
TIME_RE = re.compile(r"^(?P<name>\S+)\s+(?P<value>[0-9.]+)\s+(?P<unit>ns|µs|us|ms|s)\b")


@dataclass
class Row:
    name: str
    moon_us: float
    hf_us: float

    @property
    def ratio(self) -> float:
        return self.moon_us / self.hf_us if self.hf_us > 0 else float("inf")

    @property
    def verdict(self) -> str:
        if self.ratio <= 0.90:
            return "faster"
        if self.ratio <= 1.10:
            return "same-range"
        return "slower"


def to_us(value: float, unit: str) -> float:
    if unit == "ns":
        return value / 1000.0
    if unit in ("µs", "us"):
        return value
    if unit == "ms":
        return value * 1000.0
    if unit == "s":
        return value * 1_000_000.0
    raise ValueError(unit)


def run_moon_bench(target: str) -> dict[str, float]:
    env = os.environ.copy()
    env["PATH"] = os.path.expanduser("~/.moon/bin") + os.pathsep + env.get("PATH", "")
    cmd = ["moon", "bench", "--target", target]
    proc = subprocess.run(cmd, text=True, capture_output=True, check=False, env=env)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode)
    results: dict[str, float] = {}
    for line in proc.stdout.splitlines():
        m = TIME_RE.match(line.strip())
        if not m:
            continue
        name = m.group("name")
        if name == "name":
            continue
        results[name] = to_us(float(m.group("value")), m.group("unit"))
    return results


def load_tokenizer(name: str) -> tuple[Tokenizer | None, str]:
    path = os.path.join(DATA, f"{name}.full.json")
    if not os.path.exists(path):
        return None, path
    return Tokenizer.from_file(path), path


def iterations_for(text: str) -> int:
    if len(text) > 10_000:
        return 120
    if len(text) > 2_000:
        return 400
    return 1_000


def timed_us(fn, iters: int) -> float:
    for _ in range(min(50, iters)):
        fn()
    t0 = time.perf_counter()
    for _ in range(iters):
        fn()
    return (time.perf_counter() - t0) / iters * 1_000_000.0


def hf_encode_us(tok: Tokenizer, text: str) -> float:
    iters = iterations_for(text)
    return timed_us(lambda: tok.encode(text, add_special_tokens=False), iters)


def hf_encode_batch_us(tok: Tokenizer, text: str) -> float:
    batch = [text] * 8
    iters = iterations_for(text)
    return timed_us(lambda: tok.encode_batch(batch, add_special_tokens=False), iters)


def hf_encode_batch_padded_us(path: str, text: str) -> float:
    tok = Tokenizer.from_file(path)
    tok.enable_padding(pad_id=0, pad_token="!", pad_to_multiple_of=8)
    batch = [text, "Hello", text + " tail", "a", text, "MoonBit", text, "x"]
    iters = iterations_for(text)
    return timed_us(lambda: tok.encode_batch(batch, add_special_tokens=False), iters)


def hf_encode_pair_batch_us(tok: Tokenizer, text: str) -> float:
    pair = (text, "Second sequence: " + text)
    batch = [pair] * 8
    iters = iterations_for(text)
    return timed_us(lambda: tok.encode_batch(batch, add_special_tokens=False), iters)


def pretokenized_words() -> list[str]:
    return [
        "The", "quick", "brown", "fox", "jumps", "over", "MoonBit", "tokenizers",
        "我", "🙂", "2026", "path/to/file.rs",
    ]


def hf_encode_pretokenized_us(tok: Tokenizer) -> float:
    words = pretokenized_words()
    return timed_us(lambda: tok.encode(words, is_pretokenized=True, add_special_tokens=False), 2_000)


def hf_encode_pretokenized_batch_us(tok: Tokenizer) -> float:
    words = pretokenized_words()
    batch = [words] * 8
    return timed_us(lambda: tok.encode_batch(batch, is_pretokenized=True, add_special_tokens=False), 2_000)


def hf_encode_pretokenized_pair_batch_us(tok: Tokenizer) -> float:
    pair = (pretokenized_words(), ["Second", "sequence", "MoonBit", "tokenizers", "2026"])
    batch = [pair] * 8
    return timed_us(lambda: tok.encode_batch(batch, is_pretokenized=True, add_special_tokens=False), 2_000)


def hf_pretokenized_added_tokenizer() -> Tokenizer:
    tok = Tokenizer(
        hf_models.WordLevel(
            {
                "the": 0,
                "quick": 1,
                "brown": 2,
                "fox": 3,
                "jumps": 4,
                "over": 5,
                "moonbit": 6,
                "tokenizers": 7,
                "[MASK]": 8,
                "[UNK]": 9,
            },
            unk_token="[UNK]",
        )
    )
    tok.normalizer = hf_normalizers.Lowercase()
    tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
    tok.add_special_tokens([
        AddedToken("[MASK]", special=True, lstrip=True, rstrip=True, normalized=False)
    ])
    return tok


def hf_encode_pretokenized_added_us() -> float:
    tok = hf_pretokenized_added_tokenizer()
    words = ["The", "quick", "brown[MASK]fox", "jumps", "over", "MoonBit", "tokenizers"]
    return timed_us(lambda: tok.encode(words, is_pretokenized=True, add_special_tokens=False), 2_000)


def hf_decode_us(tok: Tokenizer, text: str) -> float:
    ids = tok.encode(text, add_special_tokens=False).ids
    iters = iterations_for(text)
    return timed_us(lambda: tok.decode(ids, skip_special_tokens=False), iters)


def hf_decode_batch_us(tok: Tokenizer, text: str) -> float:
    ids = tok.encode(text, add_special_tokens=False).ids
    batch = [ids] * 8
    iters = iterations_for(text)
    return timed_us(lambda: tok.decode_batch(batch, skip_special_tokens=False), iters)


def hf_load_us(path: str) -> float:
    return timed_us(lambda: Tokenizer.from_file(path), 30)


def hf_to_json_us(tok: Tokenizer) -> float:
    return timed_us(lambda: tok.to_str(pretty=False), 30)


def hf_save_pretrained_us(tok: Tokenizer, name: str) -> float:
    out_dir = os.path.join("_build", "bench_hf_save_pretrained", name)
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "tokenizer.json")
    return timed_us(lambda: tok.save(out_path), 30)


def hf_train_wordlevel_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.WordLevel(unk_token="[UNK]"))
        tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
        trainer = hf_trainers.WordLevelTrainer(
            min_frequency=1,
            special_tokens=["[PAD]", "[UNK]"],
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 60)


def hf_train_wordlevel_split_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.WordLevel(unk_token="[UNK]"))
        tok.pre_tokenizer = hf_pre_tokenizers.Split(",", "removed", invert=False)
        trainer = hf_trainers.WordLevelTrainer(
            min_frequency=1,
            special_tokens=["[PAD]", "[UNK]"],
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 60)


def hf_train_wordlevel_capped_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.WordLevel(unk_token="[UNK]"))
        tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
        trainer = hf_trainers.WordLevelTrainer(
            vocab_size=128,
            min_frequency=1,
            special_tokens=["[PAD]", "[UNK]"],
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 60)


def hf_trained_wordlevel_to_json_us(text: str) -> float:
    tok = Tokenizer(hf_models.WordLevel(unk_token="[UNK]"))
    tok.pre_tokenizer = hf_pre_tokenizers.Split(",", "removed", invert=False)
    trainer = hf_trainers.WordLevelTrainer(
        min_frequency=1,
        special_tokens=["[PAD]", "[UNK]"],
    )
    tok.train_from_iterator([text, text], trainer=trainer)
    return timed_us(lambda: tok.to_str(pretty=False), 100)


def hf_train_wordpiece_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.WordPiece(unk_token="[UNK]"))
        tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
        trainer = hf_trainers.WordPieceTrainer(
            vocab_size=512,
            min_frequency=1,
            special_tokens=["[PAD]", "[UNK]"],
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 60)


def hf_train_wordpiece_alphabet_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.WordPiece(unk_token="[UNK]"))
        tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
        trainer = hf_trainers.WordPieceTrainer(
            vocab_size=512,
            min_frequency=1,
            special_tokens=["[PAD]", "[UNK]"],
            initial_alphabet=["z", "🙂"],
            limit_alphabet=128,
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 60)


def hf_trained_wordpiece_to_json_us(text: str) -> float:
    tok = Tokenizer(hf_models.WordPiece(unk_token="[UNK]"))
    tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
    trainer = hf_trainers.WordPieceTrainer(
        vocab_size=512,
        min_frequency=1,
        special_tokens=["[PAD]", "[UNK]"],
    )
    tok.train_from_iterator([text, text], trainer=trainer)
    return timed_us(lambda: tok.to_str(pretty=False), 100)


def hf_train_bpe_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.BPE(unk_token="[UNK]"))
        tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
        trainer = hf_trainers.BpeTrainer(
            vocab_size=512,
            min_frequency=2,
            special_tokens=["[PAD]", "[UNK]"],
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 30)


def hf_train_bpe_bytelevel_alphabet_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.BPE(unk_token="[UNK]"))
        tok.pre_tokenizer = hf_pre_tokenizers.ByteLevel(add_prefix_space=False, use_regex=True)
        trainer = hf_trainers.BpeTrainer(
            vocab_size=512,
            min_frequency=2,
            special_tokens=["[PAD]", "[UNK]"],
            initial_alphabet=hf_pre_tokenizers.ByteLevel.alphabet(),
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 30)


def hf_train_bpe_max_token_length_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.BPE(unk_token="[UNK]"))
        tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
        trainer = hf_trainers.BpeTrainer(
            vocab_size=512,
            min_frequency=2,
            special_tokens=["[PAD]", "[UNK]"],
            max_token_length=32,
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 30)


def hf_trained_bpe_to_json_us(text: str) -> float:
    tok = Tokenizer(hf_models.BPE(unk_token="[UNK]"))
    tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
    trainer = hf_trainers.BpeTrainer(
        vocab_size=512,
        min_frequency=2,
        special_tokens=["[PAD]", "[UNK]"],
    )
    tok.train_from_iterator([text, text], trainer=trainer)
    return timed_us(lambda: tok.to_str(pretty=False), 100)


def hf_train_unigram_us(text: str) -> float:
    corpus = [text] * 4

    def train_once() -> Tokenizer:
        tok = Tokenizer(hf_models.Unigram())
        tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
        trainer = hf_trainers.UnigramTrainer(
            vocab_size=512,
            special_tokens=["<pad>", "<unk>"],
            unk_token="<unk>",
        )
        tok.train_from_iterator(corpus, trainer=trainer)
        return tok

    return timed_us(train_once, 30)


def hf_trained_unigram_to_json_us(text: str) -> float:
    counts: dict[str, int] = {}
    char_counts: dict[str, int] = {}
    for sample in [text, text]:
        for word in sample.split():
            counts[word] = counts.get(word, 0) + 1
            for ch in word:
                char_counts[ch] = char_counts.get(ch, 0) + 1
    vocab: list[tuple[str, float]] = [("<pad>", 0.0), ("<unk>", 0.0)]
    for ch, _ in sorted(char_counts.items(), key=lambda kv: (-kv[1], kv[0])):
        if ch not in {tok for tok, _ in vocab} and len(vocab) < 512:
            vocab.append((ch, -10.0))
    seen = {tok for tok, _ in vocab}
    for word, freq in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        if word not in seen and len(vocab) < 512:
            vocab.append((word, float(freq)))
            seen.add(word)
    tok = Tokenizer(hf_models.Unigram(vocab, unk_id=1))
    tok.pre_tokenizer = hf_pre_tokenizers.WhitespaceSplit()
    return timed_us(lambda: tok.to_str(pretty=False), 100)


def hf_decoder_replace_regex_us() -> float:
    decoder = hf_decoders.Replace(Regex(r"\s+"), " ")
    tokens = [
        "The\tquick",
        "\u00a0brown\nfox",
        "\u3000jumps",
        " over\tthe lazy dog.",
        " MoonBit\nwasm\u3000tokenizers.",
    ]
    return timed_us(lambda: decoder.decode(tokens), 2_000)


def hf_decoder_replace_trailing_regex_us() -> float:
    decoder = hf_decoders.Replace(Regex(r"\s+$"), "")
    tokens = [
        "The quick brown fox",
        " jumps over the lazy dog.",
        " MoonBit wasm tokenizers.",
        "\t \n",
    ]
    return timed_us(lambda: decoder.decode(tokens), 2_000)


def hf_decoder_replace_leading_regex_us() -> float:
    decoder = hf_decoders.Replace(Regex(r"^\s+"), "")
    tokens = [
        "\t \u3000The quick brown fox",
        " jumps over the lazy dog.",
        " MoonBit wasm tokenizers.",
    ]
    return timed_us(lambda: decoder.decode(tokens), 2_000)


def hf_decoder_replace_anchored_union_regex_us() -> float:
    decoder = hf_decoders.Replace(Regex(r"[\p{P}\p{S}]+$"), "")
    tokens = [
        "The quick brown fox",
        " jumps over MoonBit",
        " wasm tokenizers🙂+!",
    ]
    return timed_us(lambda: decoder.decode(tokens), 2_000)


def hf_decoder_replace_digit_regex_us() -> float:
    decoder = hf_decoders.Replace(Regex(r"\d+"), "#")
    tokens = ["abc123", " def4567", " 890xyz", " MoonBit2026"]
    return timed_us(lambda: decoder.decode(tokens), 2_000)


def hf_decoder_replace_punct_symbol_regex_us() -> float:
    decoder = hf_decoders.Replace(Regex(r"[\p{P}\p{S}]+"), "_")
    tokens = ["hi,!", "$+🙂ok。", " code(a+b);", " path/to/file.rs"]
    return timed_us(lambda: decoder.decode(tokens), 2_000)


def hf_normalizer_replace_word_regex_us() -> float:
    normalizer = hf_normalizers.Replace(Regex(r"\w+"), "W")
    text = CORPORA["mixed"] + " snake_case abc123 中 Ж"
    return timed_us(lambda: normalizer.normalize_str(text), 2_000)


def hf_normalizer_replace_unicode_letter_regex_us() -> float:
    normalizer = hf_normalizers.Replace(Regex(r"\p{L}+"), "L")
    text = CORPORA["mixed"] + " café 中 Ж MoonBit 123"
    return timed_us(lambda: normalizer.normalize_str(text), 2_000)


def hf_normalizer_replace_punct_symbol_regex_us() -> float:
    normalizer = hf_normalizers.Replace(Regex(r"[\p{P}\p{S}]+"), "_")
    text = CORPORA["mixed"] + " $+🙂 wait!!! ok?! path/to/file.rs"
    return timed_us(lambda: normalizer.normalize_str(text), 2_000)


def hf_split_trailing_ws_regex_us() -> float:
    pt = hf_pre_tokenizers.Split(Regex(r"\s+$"), "removed", invert=False)
    text = CORPORA["mixed"] + "\t \n"
    return timed_us(lambda: pt.pre_tokenize_str(text), 2_000)


def hf_split_nonspace_regex_us() -> float:
    pt = hf_pre_tokenizers.Split(Regex(r"\S+"), "removed", invert=False)
    text = CORPORA["mixed"]
    return timed_us(lambda: pt.pre_tokenize_str(text), 2_000)


def hf_split_digit_regex_us() -> float:
    pt = hf_pre_tokenizers.Split(Regex(r"\d+"), "removed", invert=False)
    text = CORPORA["mixed"] + " 12345 2026"
    return timed_us(lambda: pt.pre_tokenize_str(text), 2_000)


def hf_split_punct_symbol_regex_us() -> float:
    pt = hf_pre_tokenizers.Split(Regex(r"[\p{P}\p{S}]+"), "isolated", invert=False)
    text = CORPORA["mixed"] + " $+🙂 ok。 code(a+b); path/to/file.rs"
    return timed_us(lambda: pt.pre_tokenize_str(text), 2_000)


def compare(models: list[str], corpora: list[str], target: str) -> list[Row]:
    moon = run_moon_bench(target)
    rows: list[Row] = []
    train_key = "wordlevel-train-mixedx4"
    if train_key in moon:
        rows.append(Row(train_key, moon[train_key], hf_train_wordlevel_us(CORPORA["mixed"])))
    train_split_key = "wordlevel-train-split-mixedx4"
    if train_split_key in moon:
        rows.append(Row(train_split_key, moon[train_split_key], hf_train_wordlevel_split_us(CORPORA["mixed"])))
    train_capped_key = "wordlevel-train-capped-mixedx4"
    if train_capped_key in moon:
        rows.append(Row(train_capped_key, moon[train_capped_key], hf_train_wordlevel_capped_us(CORPORA["mixed"])))
    trained_to_json_key = "wordlevel-trained-to_json-split"
    if trained_to_json_key in moon:
        rows.append(Row(trained_to_json_key, moon[trained_to_json_key], hf_trained_wordlevel_to_json_us(CORPORA["mixed"])))
    wordpiece_train_key = "wordpiece-train-mixedx4"
    if wordpiece_train_key in moon:
        rows.append(Row(wordpiece_train_key, moon[wordpiece_train_key], hf_train_wordpiece_us(CORPORA["mixed"])))
    wordpiece_train_alphabet_key = "wordpiece-train-alphabet-mixedx4"
    if wordpiece_train_alphabet_key in moon:
        rows.append(Row(
            wordpiece_train_alphabet_key,
            moon[wordpiece_train_alphabet_key],
            hf_train_wordpiece_alphabet_us(CORPORA["mixed"]),
        ))
    wordpiece_to_json_key = "wordpiece-trained-to_json-mixed"
    if wordpiece_to_json_key in moon:
        rows.append(Row(wordpiece_to_json_key, moon[wordpiece_to_json_key], hf_trained_wordpiece_to_json_us(CORPORA["mixed"])))
    bpe_train_key = "bpe-train-mixedx4"
    if bpe_train_key in moon:
        rows.append(Row(bpe_train_key, moon[bpe_train_key], hf_train_bpe_us(CORPORA["mixed"])))
    bpe_train_bytelevel_key = "bpe-train-bytelevel-alphabet-mixedx4"
    if bpe_train_bytelevel_key in moon:
        rows.append(Row(
            bpe_train_bytelevel_key,
            moon[bpe_train_bytelevel_key],
            hf_train_bpe_bytelevel_alphabet_us(CORPORA["mixed"]),
        ))
    bpe_train_max_len_key = "bpe-train-max-token-length-mixedx4"
    if bpe_train_max_len_key in moon:
        rows.append(Row(
            bpe_train_max_len_key,
            moon[bpe_train_max_len_key],
            hf_train_bpe_max_token_length_us(CORPORA["mixed"]),
        ))
    bpe_to_json_key = "bpe-trained-to_json-mixed"
    if bpe_to_json_key in moon:
        rows.append(Row(bpe_to_json_key, moon[bpe_to_json_key], hf_trained_bpe_to_json_us(CORPORA["mixed"])))
    unigram_train_key = "unigram-train-mixedx4"
    if unigram_train_key in moon:
        rows.append(Row(unigram_train_key, moon[unigram_train_key], hf_train_unigram_us(CORPORA["mixed"])))
    unigram_to_json_key = "unigram-trained-to_json-mixed"
    if unigram_to_json_key in moon:
        rows.append(Row(unigram_to_json_key, moon[unigram_to_json_key], hf_trained_unigram_to_json_us(CORPORA["mixed"])))
    decoder_replace_key = "decoder-replace-regex-mixed"
    if decoder_replace_key in moon:
        rows.append(Row(decoder_replace_key, moon[decoder_replace_key], hf_decoder_replace_regex_us()))
    decoder_replace_trailing_key = "decoder-replace-trailing-regex-mixed"
    if decoder_replace_trailing_key in moon:
        rows.append(Row(decoder_replace_trailing_key, moon[decoder_replace_trailing_key], hf_decoder_replace_trailing_regex_us()))
    decoder_replace_leading_key = "decoder-replace-leading-regex-mixed"
    if decoder_replace_leading_key in moon:
        rows.append(Row(decoder_replace_leading_key, moon[decoder_replace_leading_key], hf_decoder_replace_leading_regex_us()))
    decoder_replace_anchored_union_key = "decoder-replace-anchored-union-regex-mixed"
    if decoder_replace_anchored_union_key in moon:
        rows.append(Row(
            decoder_replace_anchored_union_key,
            moon[decoder_replace_anchored_union_key],
            hf_decoder_replace_anchored_union_regex_us(),
        ))
    decoder_replace_digit_key = "decoder-replace-digit-regex-mixed"
    if decoder_replace_digit_key in moon:
        rows.append(Row(decoder_replace_digit_key, moon[decoder_replace_digit_key], hf_decoder_replace_digit_regex_us()))
    decoder_replace_punct_symbol_key = "decoder-replace-punct-symbol-regex-mixed"
    if decoder_replace_punct_symbol_key in moon:
        rows.append(Row(
            decoder_replace_punct_symbol_key,
            moon[decoder_replace_punct_symbol_key],
            hf_decoder_replace_punct_symbol_regex_us(),
        ))
    normalizer_replace_word_key = "normalizer-replace-word-regex-mixed"
    if normalizer_replace_word_key in moon:
        rows.append(Row(
            normalizer_replace_word_key,
            moon[normalizer_replace_word_key],
            hf_normalizer_replace_word_regex_us(),
        ))
    normalizer_replace_unicode_letter_key = "normalizer-replace-unicode-letter-regex-mixed"
    if normalizer_replace_unicode_letter_key in moon:
        rows.append(Row(
            normalizer_replace_unicode_letter_key,
            moon[normalizer_replace_unicode_letter_key],
            hf_normalizer_replace_unicode_letter_regex_us(),
        ))
    normalizer_replace_punct_symbol_key = "normalizer-replace-punct-symbol-regex-mixed"
    if normalizer_replace_punct_symbol_key in moon:
        rows.append(Row(
            normalizer_replace_punct_symbol_key,
            moon[normalizer_replace_punct_symbol_key],
            hf_normalizer_replace_punct_symbol_regex_us(),
        ))
    split_trailing_ws_key = "pretokenizer-split-trailing-ws-regex-mixed"
    if split_trailing_ws_key in moon:
        rows.append(Row(split_trailing_ws_key, moon[split_trailing_ws_key], hf_split_trailing_ws_regex_us()))
    split_nonspace_key = "pretokenizer-split-nonspace-regex-mixed"
    if split_nonspace_key in moon:
        rows.append(Row(split_nonspace_key, moon[split_nonspace_key], hf_split_nonspace_regex_us()))
    split_digit_key = "pretokenizer-split-digit-regex-mixed"
    if split_digit_key in moon:
        rows.append(Row(split_digit_key, moon[split_digit_key], hf_split_digit_regex_us()))
    split_punct_symbol_key = "pretokenizer-split-punct-symbol-regex-mixed"
    if split_punct_symbol_key in moon:
        rows.append(Row(split_punct_symbol_key, moon[split_punct_symbol_key], hf_split_punct_symbol_regex_us()))
    wordpiece_cache_key = "bert-wordpiece-cache-repeat"
    if wordpiece_cache_key in moon:
        bert_tok, _ = load_tokenizer("bert")
        if bert_tok is not None:
            rows.append(Row(
                wordpiece_cache_key,
                moon[wordpiece_cache_key],
                hf_encode_us(bert_tok, "tokenization tokenization tokenization tokenization tokenization"),
            ))
    multi_cache_key = "from_pretrained-multi-cache-hit"
    if multi_cache_key in moon:
        _, gpt2_path = load_tokenizer("gpt2")
        _, bert_path = load_tokenizer("bert")
        rows.append(Row(
            multi_cache_key,
            moon[multi_cache_key],
            hf_load_us(gpt2_path) + hf_load_us(bert_path),
        ))
    pretokenized_added_key = "synthetic-encode-pretokenized-added"
    if pretokenized_added_key in moon:
        rows.append(Row(
            pretokenized_added_key,
            moon[pretokenized_added_key],
            hf_encode_pretokenized_added_us(),
        ))
    for model in models:
        tok, path = load_tokenizer(model)
        if tok is None:
            print(f"[skip] missing fixture: {path}")
            continue
        for corpus in corpora:
            text = CORPORA[corpus]
            encode_key = f"{model}-encode-{corpus}"
            encode_byte_offsets_key = f"{model}-encode-byte-offsets-{corpus}"
            if encode_key in moon:
                rows.append(Row(encode_key, moon[encode_key], hf_encode_us(tok, text)))
            if encode_byte_offsets_key in moon:
                # HF encodings carry byte offsets by default, so plain encode is
                # the closest same-work baseline for MoonBit's explicit byte
                # offset conversion API.
                rows.append(Row(encode_byte_offsets_key, moon[encode_byte_offsets_key], hf_encode_us(tok, text)))
        # Decode benches are currently standardized on the mixed corpus in
        # src/tokenizer/bench_test.mbt; include them once per model.
        decode_key = f"{model}-decode-mixed"
        decode_batch_key = f"{model}-decode-batch-mixedx8"
        encode_batch_key = f"{model}-encode-batch-mixedx8"
        encode_batch_padded_key = f"{model}-encode-batch-padded-mixedx8"
        encode_pair_batch_key = f"{model}-encode-pair-batch-mixedx8"
        pretokenized_key = f"{model}-encode-pretokenized-words"
        pretokenized_byte_key = f"{model}-encode-pretokenized-byte-offsets-words"
        pretokenized_batch_key = f"{model}-encode-pretokenized-batch-wordsx8"
        pretokenized_pair_batch_key = f"{model}-encode-pretokenized-pair-batch-wordsx8"
        load_key = f"{model}-from_str"
        pretrained_key = f"{model}-from_pretrained-file"
        pretrained_hub_cache_key = f"{model}-from_pretrained-hub-cache"
        to_json_key = f"{model}-to_json"
        save_pretrained_key = f"{model}-save_pretrained"
        if decode_key in moon:
            rows.append(Row(decode_key, moon[decode_key], hf_decode_us(tok, CORPORA["mixed"])))
        if decode_batch_key in moon:
            rows.append(Row(decode_batch_key, moon[decode_batch_key], hf_decode_batch_us(tok, CORPORA["mixed"])))
        if encode_batch_key in moon:
            rows.append(Row(encode_batch_key, moon[encode_batch_key], hf_encode_batch_us(tok, CORPORA["mixed"])))
        if encode_batch_padded_key in moon:
            rows.append(Row(encode_batch_padded_key, moon[encode_batch_padded_key], hf_encode_batch_padded_us(path, CORPORA["mixed"])))
        if encode_pair_batch_key in moon:
            rows.append(Row(encode_pair_batch_key, moon[encode_pair_batch_key], hf_encode_pair_batch_us(tok, CORPORA["mixed"])))
        if pretokenized_key in moon:
            rows.append(Row(pretokenized_key, moon[pretokenized_key], hf_encode_pretokenized_us(tok)))
        if pretokenized_byte_key in moon:
            rows.append(Row(pretokenized_byte_key, moon[pretokenized_byte_key], hf_encode_pretokenized_us(tok)))
        if pretokenized_batch_key in moon:
            rows.append(Row(pretokenized_batch_key, moon[pretokenized_batch_key], hf_encode_pretokenized_batch_us(tok)))
        if pretokenized_pair_batch_key in moon:
            rows.append(Row(
                pretokenized_pair_batch_key,
                moon[pretokenized_pair_batch_key],
                hf_encode_pretokenized_pair_batch_us(tok),
            ))
        if load_key in moon:
            rows.append(Row(load_key, moon[load_key], hf_load_us(path)))
        if pretrained_key in moon:
            # Local file from_pretrained is intentionally equivalent to HF's
            # from_file baseline; Hub/network fetching is outside this script.
            rows.append(Row(pretrained_key, moon[pretrained_key], hf_load_us(path)))
        if pretrained_hub_cache_key in moon:
            # MoonBit resolves the local HF cache metadata before reading the
            # same tokenizer.json payload; compare against HF's file load core.
            rows.append(Row(pretrained_hub_cache_key, moon[pretrained_hub_cache_key], hf_load_us(path)))
        if to_json_key in moon:
            rows.append(Row(to_json_key, moon[to_json_key], hf_to_json_us(tok)))
        if save_pretrained_key in moon:
            rows.append(Row(save_pretrained_key, moon[save_pretrained_key], hf_save_pretrained_us(tok, model)))
    return rows


def print_rows(rows: list[Row]) -> None:
    print("| case | MoonBit µs/op | HF tokenizers µs/op | Moon/HF | verdict |")
    print("|---|---:|---:|---:|---|")
    for r in rows:
        print(f"| {r.name} | {r.moon_us:.2f} | {r.hf_us:.2f} | {r.ratio:.2f}x | {r.verdict} |")
    slower = sorted([r for r in rows if r.ratio > 1.10], key=lambda r: r.ratio, reverse=True)
    if slower:
        print("\nOptimization focus:")
        for r in slower[:8]:
            print(f"- {r.name}: {r.ratio:.2f}x slower than HF")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", default="native", choices=["native", "js", "wasm", "wasm-gc"])
    parser.add_argument("--corpus", default="mixed", choices=sorted(CORPORA.keys()) + ["all"])
    parser.add_argument("--models", default=",".join(DEFAULT_MODELS), help="comma-separated model names")
    parser.add_argument("--quick", action="store_true", help="compare representative core models only")
    args = parser.parse_args()
    models = QUICK_MODELS if args.quick else [m for m in args.models.split(",") if m]
    corpora = list(CORPORA.keys()) if args.corpus == "all" else [args.corpus]
    print(f"Comparing target={args.target}, corpus={','.join(corpora)}, models={','.join(models)}")
    print_rows(compare(models, corpora, args.target))


if __name__ == "__main__":
    main()
