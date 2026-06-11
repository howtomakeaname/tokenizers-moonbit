#!/usr/bin/env python3
"""Download tokenizer.json fixtures for the parity test suite.

Models are listed in MODELS below, covering every model family the MoonBit
port implements (BPE, byte-level BPE, byte_fallback BPE, WordPiece, Unigram).

Usage:
    python3 scripts/fetch_models.py            # fetch all
    python3 scripts/fetch_models.py gpt2 bert  # fetch a subset (by local name)

Set HF_ENDPOINT (for example https://hf-mirror.com) to fetch through a
HuggingFace-compatible mirror, and HF_TOKEN for private/gated repositories.

Files are written to tests/data/<name>.full.json (git-ignored). Gated models
(e.g. official Llama) are avoided; public mirrors are used instead.
"""
import os
import sys
import urllib.request


HF_UA = "unknown/None; hf_hub/0.34.4; python/3.x; tokenizers/0.21.4"
HF_ENDPOINT = os.environ.get("HF_ENDPOINT", "https://huggingface.co").rstrip("/")

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
    # 2024-2026 mainstream coverage matrix: Llama 3.x, Phi-4, DeepSeek, GPT-OSS,
    # GLM, Granite, Qwen3 coder/VL and embedding models. These are public
    # tokenizer.json fixtures when available; if a repo is gated/renamed the
    # fetcher skips it without breaking local tests.
    "llama3_2": "https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct/resolve/main/tokenizer.json",
    "phi4_mini": "https://huggingface.co/microsoft/Phi-4-mini-instruct/resolve/main/tokenizer.json",
    "deepseek_r1_qwen": "https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/tokenizer.json",
    "deepseek_v3_2": "https://huggingface.co/deepseek-ai/DeepSeek-V3.2/resolve/main/tokenizer.json",
    "gpt_oss": "https://huggingface.co/openai/gpt-oss-20b/resolve/main/tokenizer.json",
    "glm4_5": "https://huggingface.co/zai-org/GLM-4.5-Air/resolve/main/tokenizer.json",
    "granite4": "https://huggingface.co/ibm-granite/granite-4.0-tiny-preview/resolve/main/tokenizer.json",
    "qwen3_coder": "https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct/resolve/main/tokenizer.json",
    "qwen3_vl": "https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct/resolve/main/tokenizer.json",
    "bge_m3": "https://huggingface.co/BAAI/bge-m3/resolve/main/tokenizer.json",
    "e5_multilingual": "https://huggingface.co/intfloat/multilingual-e5-large/resolve/main/tokenizer.json",
    # Additional migration coverage: modern encoder stacks, popular embedding
    # tokenizers and small LLM fixtures that are public and ship tokenizer.json.
    "modernbert": "https://huggingface.co/answerdotai/ModernBERT-base/resolve/main/tokenizer.json",
    "gte_modernbert": "https://huggingface.co/Alibaba-NLP/gte-modernbert-base/resolve/main/tokenizer.json",
    "minilm": "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/tokenizer.json",
    "bge_large_en": "https://huggingface.co/BAAI/bge-large-en-v1.5/resolve/main/tokenizer.json",
    "jina_v3": "https://huggingface.co/jinaai/jina-embeddings-v3/resolve/main/tokenizer.json",
    "nomic_embed": "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5/resolve/main/tokenizer.json",
    "e5_small": "https://huggingface.co/intfloat/multilingual-e5-small/resolve/main/tokenizer.json",
    "mxbai_embed_large": "https://huggingface.co/mixedbread-ai/mxbai-embed-large-v1/resolve/main/tokenizer.json",
    "smollm2": "https://huggingface.co/HuggingFaceTB/SmolLM2-135M-Instruct/resolve/main/tokenizer.json",
}

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "tests", "data")


def resolve_url(url: str) -> str:
    prefix = "https://huggingface.co"
    if HF_ENDPOINT != prefix and url.startswith(prefix):
        return HF_ENDPOINT + url[len(prefix) :]
    return url


def request_headers() -> dict[str, str]:
    headers = {"User-Agent": HF_UA, "Accept": "*/*"}
    token = os.environ.get("HF_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def fetch(name: str, url: str) -> None:
    os.makedirs(DATA_DIR, exist_ok=True)
    dst = os.path.join(DATA_DIR, f"{name}.full.json")
    try:
        req = urllib.request.Request(resolve_url(url), headers=request_headers())
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
