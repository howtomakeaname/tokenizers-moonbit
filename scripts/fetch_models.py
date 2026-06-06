#!/usr/bin/env python3
"""Download tokenizer.json fixtures for the parity test suite.

Models are listed in MODELS below, covering every model family the MoonBit
port implements (BPE, byte-level BPE, byte_fallback BPE, WordPiece, Unigram).

Usage:
    python3 scripts/fetch_models.py            # fetch all
    python3 scripts/fetch_models.py gpt2 bert  # fetch a subset (by local name)

Files are written to tests/data/<name>.full.json (git-ignored). Gated models
(e.g. official Llama) are avoided; public mirrors are used instead.
"""
import os
import sys
import urllib.request

# local name -> HuggingFace resolve URL of tokenizer.json
MODELS = {
    # byte-level BPE
    "gpt2": "https://huggingface.co/gpt2/resolve/main/tokenizer.json",
    "roberta": "https://huggingface.co/roberta-base/resolve/main/tokenizer.json",
    # byte_fallback BPE (+ Metaspace)
    "llama": "https://huggingface.co/hf-internal-testing/llama-tokenizer/resolve/main/tokenizer.json",
    # WordPiece
    "bert": "https://huggingface.co/bert-base-uncased/resolve/main/tokenizer.json",
    "bert_cased": "https://huggingface.co/bert-base-cased/resolve/main/tokenizer.json",
    "distilbert": "https://huggingface.co/distilbert-base-uncased/resolve/main/tokenizer.json",
    # Unigram (SentencePiece)
    "t5": "https://huggingface.co/t5-small/resolve/main/tokenizer.json",
    "albert": "https://huggingface.co/albert-base-v2/resolve/main/tokenizer.json",
    "xlm_roberta": "https://huggingface.co/xlm-roberta-base/resolve/main/tokenizer.json",
    # Modern LLMs (Qwen/Llama-3 family Split pattern + ByteLevel)
    "Qwen2.5": "https://huggingface.co/Qwen/Qwen2.5-0.5B/resolve/main/tokenizer.json",
    "qwen3": "https://huggingface.co/Qwen/Qwen3-0.6B/resolve/main/tokenizer.json",
    "deepseek": "https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite/resolve/main/tokenizer.json",
    "phi3": "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct/resolve/main/tokenizer.json",
    # BPE with Metaspace / Sequence pre-tokenizers
    "mistral": "https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.3/resolve/main/tokenizer.json",
    "falcon": "https://huggingface.co/tiiuae/falcon-7b/resolve/main/tokenizer.json",
    "starcoder2": "https://huggingface.co/bigcode/starcoder2-3b/resolve/main/tokenizer.json",
    "gptneox": "https://huggingface.co/EleutherAI/gpt-neox-20b/resolve/main/tokenizer.json",
    "clip": "https://huggingface.co/openai/clip-vit-base-patch32/resolve/main/tokenizer.json",
    # Public DeBERTa-family fixture with tokenizer.json. The main Microsoft
    # DeBERTa repos publish slow-tokenizer assets (vocab/spm) but no
    # tokenizer.json, so the fetcher uses HF's tiny random DeBERTaV2 fixture for
    # JSON-pipeline parity coverage.
    "deberta": "https://huggingface.co/hf-internal-testing/tiny-random-DebertaV2Model/resolve/main/tokenizer.json",
}

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "tests", "data")


def fetch(name: str, url: str) -> None:
    os.makedirs(DATA_DIR, exist_ok=True)
    dst = os.path.join(DATA_DIR, f"{name}.full.json")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        with open(dst, "wb") as f:
            f.write(data)
        print(f"[ok]   {name}: {len(data)} bytes")
    except Exception as e:  # noqa: BLE001
        print(f"[skip] {name}: {e}")


def main() -> None:
    names = sys.argv[1:] or list(MODELS)
    for name in names:
        if name not in MODELS:
            print(f"[warn] unknown model '{name}'")
            continue
        fetch(name, MODELS[name])


if __name__ == "__main__":
    main()
