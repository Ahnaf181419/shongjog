#!/usr/bin/env bash
#
# Build the release APK, optionally injecting GEMINI_API_KEY from .env (or env var).
#
# Usage:
#   bash scripts/build_release.sh          # reads .env if present; else offline build
#   GEMINI_API_KEY=xxx bash scripts/build_release.sh   # override via env
#
# The demo-submission APK SHOULD be built WITHOUT a key (offline-purity + no
# billable credential in a public artifact). See CONTRIBUTING.md §"Build with key".
#
# Never commit the real .env — it is already in .gitignore.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
PLACEHOLDER="YOUR_GOOGLE_AI_STUDIO_KEY_HERE"

# 1. Start from whatever the caller exported (env wins over file).
KEY="${GEMINI_API_KEY:-}"

# 2. If nothing in env, try .env (sourced safely).
if [[ -z "$KEY" && -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  KEY="${GEMINI_API_KEY:-}"
fi

# 3. Decide.
if [[ -z "$KEY" || "$KEY" == "$PLACEHOLDER" ]]; then
  echo "==> GEMINI_API_KEY not set. Building OFFLINE (cloud fallback disabled)."
  echo "==> This is the correct path for the demo-submission APK."
  exec flutter build apk --release
fi

echo "==> GEMINI_API_KEY detected. Building with cloud AI fallback enabled."
echo "==> WARNING: the key will be embedded in the APK. Do not ship this build"
echo "==> publicly. For the demo, rebuild without .env (or with the placeholder)."
exec flutter build apk --release --dart-define=GEMINI_API_KEY="$KEY"
