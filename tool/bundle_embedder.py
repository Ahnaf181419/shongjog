#!/usr/bin/env python3
"""Bundle the EmbeddingGemma embedder into android/app/src/main/assets/embeddinggemma/.

Run before `flutter build apk --dart-define=EMBEDDER_SOURCE=asset` so the APK
ships with the model already on the device. No on-device download needed.

Usage:
    HF_TOKEN=hf_xxx python3 tool/bundle_embedder.py [--variant default]

The script downloads two files from two ungated HuggingFace mirrors of the
official EmbeddingGemma LiteRT-LM build (171 MB model + 2 MB tokenizer):

  - Model:    kontextdev/embeddinggemma-300m-litertlm/.../seq512_mixed-precision.tflite
  - Tokenizer: Arjuu/EmbeddingGemma.tflite/.../sentencepiece.model

Why these mirrors? The plugin's documented URL
(google/embeddinggemma-300m/model.tflite) does NOT exist — the official
HF repo only ships safetensors. The LiteRT-LM community publishes the
compiled .tflite under litert-community/ (auto-gated) and kontextdev/
(ungated mirror). The Arjuu mirror is the only ungated source of the
matching SentencePiece tokenizer. Verified 2026-09-09: both files are
byte-identical to the litert-community originals.

Reads HF_TOKEN from env. Writes:
    android/app/src/main/assets/embeddinggemma/model.tflite
    android/app/src/main/assets/embeddinggemma/sentencepiece.model

Idempotent: skips files that are already present and at least the expected
Content-Length (re-run with --force to redownload).

Prereqs: `requests`. Install with `uv pip install requests` or `pip install
requests`.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
ASSET_DIR = REPO_ROOT / "android" / "app" / "src" / "main" / "assets" / "embeddinggemma"

# Ungated HF mirrors verified 2026-09-09. Both files are byte-identical
# to the litert-community originals; the community repo itself is auto-
# gated so a one-time click-to-accept is needed to access it directly.
MODEL_REPO = "kontextdev/embeddinggemma-300m-litertlm"
MODEL_FILENAME = "embeddinggemma-300M_seq512_mixed-precision.tflite"
TOKENIZER_REPO = "Arjuu/EmbeddingGemma.tflite"
TOKENIZER_FILENAME = "sentencepiece.model"


def _hf_url(repo: str, filename: str) -> str:
    return f"https://huggingface.co/{repo}/resolve/main/{filename}"


def _download(url: str, dst: Path, token: str, expected_bytes: int | None = None,
              force: bool = False) -> None:
    """Stream a HuggingFace file to disk, skipping if already present and complete."""
    if dst.exists() and not force:
        if expected_bytes and dst.stat().st_size >= expected_bytes:
            print(f"  [skip] {dst.name} already present ({dst.stat().st_size // (1024*1024)} MB)")
            return
        if not expected_bytes:
            print(f"  [skip] {dst.name} already present ({dst.stat().st_size // (1024*1024)} MB)")
            return

    print(f"  [fetch] {url}")
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    # Resumable: if partial file exists, request Range from current size onward.
    pos = dst.stat().st_size if dst.exists() else 0
    if pos > 0:
        headers["Range"] = f"bytes={pos}-"

    with requests.get(url, headers=headers, stream=True, allow_redirects=True,
                      timeout=(30, 600)) as r:
        if r.status_code == 401:
            sys.exit(f"  [error] 401 Unauthorized — token missing scope or license not "
                     f"accepted at {url}")
        if r.status_code == 403:
            sys.exit(f"  [error] 403 Forbidden — likely gated; accept the model "
                     f"license on the HF model page first")
        if r.status_code not in (200, 206):
            sys.exit(f"  [error] HTTP {r.status_code} fetching {url}: {r.text[:200]}")

        total = int(r.headers.get("Content-Length", 0)) + pos
        mode = "ab" if pos > 0 and r.status_code == 206 else "wb"
        with open(dst, mode) as f:
            chunk_size = 1 << 20  # 1 MiB
            downloaded = pos
            last_reported = -1
            for chunk in r.iter_content(chunk_size=chunk_size):
                if not chunk:
                    continue
                f.write(chunk)
                downloaded += len(chunk)
                if total > 0:
                    pct = (downloaded * 100) // total
                    if pct >= last_reported + 10:
                        print(f"    {downloaded // (1024*1024)} MB / "
                              f"{total // (1024*1024)} MB ({pct}%)")
                        last_reported = pct
    print(f"  [done] {dst.name} -> {dst.stat().st_size // (1024*1024)} MB")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--force", action="store_true",
                   help="Redownload even if files already exist.")
    args = p.parse_args()

    token = os.environ.get("HF_TOKEN", "").strip()
    if not token:
        sys.exit("HF_TOKEN env var not set. Get a token at "
                 "https://huggingface.co/settings/tokens (read scope).")

    model_url = _hf_url(MODEL_REPO, MODEL_FILENAME)
    tok_url = _hf_url(TOKENIZER_REPO, TOKENIZER_FILENAME)

    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Bundling EmbeddingGemma into {ASSET_DIR}")
    print(f"  model:     {MODEL_REPO}/{MODEL_FILENAME}")
    print(f"  tokenizer: {TOKENIZER_REPO}/{TOKENIZER_FILENAME}")

    # Probe HEAD for expected size; the script refuses to skip a file
    # that's smaller than the expected size (catches partial / corrupt
    # downloads from earlier interrupted runs).
    def _head_size(url: str) -> int | None:
        try:
            r = requests.head(url, headers={"Authorization": f"Bearer {token}"},
                              allow_redirects=True, timeout=(10, 30))
            return int(r.headers.get("Content-Length", 0)) or None
        except requests.RequestException:
            return None

    model_size = _head_size(model_url)
    tok_size = _head_size(tok_url)
    _download(model_url, ASSET_DIR / "model.tflite", token,
              expected_bytes=model_size, force=args.force)
    _download(tok_url, ASSET_DIR / "sentencepiece.model", token,
              expected_bytes=tok_size,
              # Always re-fetch the tokenizer; tiny + cheap + idempotent.
              force=True)

    print("Done. Build the prebuilt APK with:")
    print("  flutter build apk --release --dart-define=EMBEDDER_SOURCE=asset")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
