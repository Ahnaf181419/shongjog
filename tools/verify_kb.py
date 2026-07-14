#!/usr/bin/env python3
"""Spot-check retrieval quality against the built KB.

Embeds 7 test queries (Bangla), computes cosine similarity against all
chunk vectors, and checks that the top-1 hit's topic matches the expected
topic. Any mismatch prints a BAD line.

Run after build_kb.py:
    python3 tools/verify_kb.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
CORPUS_PATH = ROOT / "assets" / "kb" / "corpus.json"
VECTORS_PATH = ROOT / "assets" / "kb" / "vectors.bin"
META_PATH = ROOT / "assets" / "kb" / "meta.json"

QUERIES: list[tuple[str, str]] = [
    ("আমার বাচ্চার ডায়রিয়া হয়েছে, কি করবো", "diarrhea"),
    ("সাপে কামড়েছে", "snakebite"),
    ("ORS কিভাবে বানাবো", "ors"),
    ("বিশুদ্ধ পানি কিভাবে বানাবো", "water"),
    ("রক্তপাত বন্ধ হচ্ছে না", "bleeding"),
    ("ঝড়ের সময় কোথায় যাবো", "cyclone"),
    ("পানিতে ডুবে যাওয়া ব্যক্তি", "drowning"),
]


def main() -> int:
    if not CORPUS_PATH.exists() or not VECTORS_PATH.exists():
        print(
            "ERROR: KB not built. Run `python3 tools/build_kb.py` first.",
            file=sys.stderr,
        )
        return 1

    corpus = json.loads(CORPUS_PATH.read_text(encoding="utf-8"))
    meta = json.loads(META_PATH.read_text(encoding="utf-8")) if META_PATH.exists() else {}
    dim = meta.get("embedding_dim")
    if dim is None:
        dim = VECTORS_PATH.stat().st_size // (len(corpus) * 4)

    vectors = np.fromfile(VECTORS_PATH, dtype=np.float32).reshape(len(corpus), dim)
    id_to_topic = {c["id"]: c["topic"] for c in corpus}

    model_name = meta.get("model", "sentence-transformers/paraphrase-multilingual-mpnet-base-v2")
    print(f"Model: {model_name}", file=sys.stderr)
    print(f"Corpus: {len(corpus)} chunks, dim={dim}\n", file=sys.stderr)

    try:
        from sentence_transformers import SentenceTransformer
    except ImportError:
        print(
            "ERROR: sentence-transformers not installed. Run:\n"
            "  cd tools && source .venv/bin/activate",
            file=sys.stderr,
        )
        return 1

    model = SentenceTransformer(model_name)

    fails = 0
    for query, expected_topic in QUERIES:
        q_vec = model.encode(
            [query],
            convert_to_numpy=True,
            normalize_embeddings=True,
        ).astype(np.float32)[0]

        sims = vectors @ q_vec
        top_idx = int(np.argmax(sims))
        got_topic = id_to_topic[corpus[top_idx]["id"]]
        ok = got_topic == expected_topic
        status = "OK " if ok else "BAD"

        print(
            f"{status} | q={query!r}\n"
            f"     | got={got_topic} (score={sims[top_idx]:.3f}) "
            f"want={expected_topic}"
        )
        if not ok:
            fails += 1

    print(f"\n{'ALL PASS' if fails == 0 else f'{fails} FAILURES'}", file=sys.stderr)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
