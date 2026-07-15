#!/usr/bin/env python3
"""Build assets/kb/{corpus.json, vectors.bin, meta.json} from tools/corpus.json.

Uses a multilingual sentence-transformer model to embed each chunk's text +
keywords into a fixed-dimension L2-normalized vector. The Dart side
(BruteForceRetriever) auto-detects the dimension from vectors.length /
chunks.length, so any embedding model works here.

Default model: paraphrase-multilingual-mpnet-base-v2 (768-dim, solid Bangla).
Swap via --model CLI arg if a better Bangla embedder lands (e.g.
google/embeddinggemma-300m once published to HuggingFace).

Usage:
    cd tools
    python3 -m venv .venv && source .venv/bin/activate
    pip install -r requirements.txt
    python3 build_kb.py
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "corpus.json"
DST_DIR = ROOT / "assets" / "kb"
DST_JSON = DST_DIR / "corpus.json"
DST_BIN = DST_DIR / "vectors.bin"
DST_META = DST_DIR / "meta.json"

DEFAULT_MODEL = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Sentence-transformer model name (default: {DEFAULT_MODEL})",
    )
    args = parser.parse_args()

    if not SRC.exists():
        print(f"ERROR: missing {SRC}", file=sys.stderr)
        return 1

    corpus = json.loads(SRC.read_text(encoding="utf-8"))
    if not isinstance(corpus, list) or len(corpus) < 10:
        print(
            f"ERROR: corpus.json must have >= 10 chunks, got {len(corpus) if isinstance(corpus, list) else 'non-list'}",
            file=sys.stderr,
        )
        return 1

    for i, chunk in enumerate(corpus):
        for field in ("id", "topic", "source", "text", "keywords_bn"):
            if field not in chunk:
                print(f"ERROR: chunk[{i}] missing field '{field}'", file=sys.stderr)
                return 1

    texts = [
        (
            f"Topic: {c['topic']}. "
            + c["text"]
            + " "
            + " ".join(c.get("keywords_bn", []))
        ).strip()
        for c in corpus
    ]

    print(f"Loading model: {args.model}", file=sys.stderr)
    try:
        from sentence_transformers import SentenceTransformer
    except ImportError:
        print(
            "ERROR: sentence-transformers not installed. Run:\n"
            "  cd tools && python3 -m venv .venv && source .venv/bin/activate\n"
            "  pip install -r requirements.txt",
            file=sys.stderr,
        )
        return 1

    model = SentenceTransformer(args.model)

    print(f"Embedding {len(texts)} chunks...", file=sys.stderr)
    vectors = model.encode(
        texts,
        convert_to_numpy=True,
        normalize_embeddings=True,
        show_progress_bar=True,
    ).astype(np.float32)

    if vectors.ndim != 2:
        print(f"ERROR: unexpected vectors shape {vectors.shape}", file=sys.stderr)
        return 1

    dim = vectors.shape[1]
    n_chunks = len(corpus)
    nbytes = vectors.nbytes

    DST_DIR.mkdir(parents=True, exist_ok=True)

    DST_JSON.write_text(
        json.dumps(corpus, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    vectors.tofile(DST_BIN)

    meta = {
        "model": args.model,
        "num_chunks": n_chunks,
        "embedding_dim": dim,
        "vectors_bytes": nbytes,
    }
    DST_META.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    print(
        f"\nDone.\n"
        f"  {DST_JSON.relative_to(ROOT)} — {n_chunks} chunks\n"
        f"  {DST_BIN.relative_to(ROOT)} — {nbytes:,} bytes "
        f"({n_chunks} x {dim} x 4)\n"
        f"  {DST_META.relative_to(ROOT)} — {meta}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
