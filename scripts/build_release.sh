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
#
# arm64-v8a ONLY (see AGENTS.md §"Hard constraints"). The LiteRT-LM engine
# ships native libs for arm64 alone: a fat APK still installs on armeabi-v7a /
# x86_64 (e.g. an emulator) but has NO engine there, so the offline AI fails in
# a way that looks exactly like a bug. Restricting the ABI makes that
# impossible and drops ~36 MB. Use `flutter run` for emulator/UI work.
#
# The post-build checks below exist because both historical breakages of the
# offline model were invisible to `flutter analyze`, `flutter test` AND
# `flutter run` — they only ever showed up in an installed release APK.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
PLACEHOLDER="YOUR_GOOGLE_AI_STUDIO_KEY_HERE"
APK="$REPO_ROOT/build/app/outputs/flutter-apk/app-release.apk"
USAGE_TXT="$REPO_ROOT/build/app/outputs/mapping/release/usage.txt"

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

# ── Pre-build source verification ──────────────────────────────────────
# Run BEFORE the expensive build so a broken source fails in seconds. These
# guard the two runtime failures the artifact checks below CANNOT see: a
# wrong model URL and a missing engine registration. Both shipped an APK that
# passed every structural check and still could not answer offline.
echo "==> Verifying source before build..."
PRE_FAILED=0

# a. The engine must be registered in main.dart, or getActiveModel() throws
#    "add the engine package" at runtime — libs present, app still broken.
if grep -q "LiteRtLmEngine()" "$REPO_ROOT/lib/main.dart"; then
  echo "  ✓ LiteRtLmEngine registered in main.dart"
else
  echo "  ✗ main.dart does not register LiteRtLmEngine() — offline AI will"
  echo "    throw 'add the engine package' at runtime. See AGENTS.md."
  PRE_FAILED=1
fi

# b. Every downloadable variant must use a .litertlm URL, never the repo's
#    -web.task (a WebAssembly build the Android engine cannot open). This is
#    THE original bug. The device_capability unit test encodes the invariant
#    in real Dart — more reliable than grepping the availability flags here.
if flutter test "$REPO_ROOT/test/unit/device_capability_test.dart" >/dev/null 2>&1; then
  echo "  ✓ Model catalog verified (.litertlm URLs, sizes, gated variants)"
else
  echo "  ✗ device_capability_test FAILED — a variant likely points at a"
  echo "    .task URL or has a wrong size. Run the test to see which:"
  echo "    flutter test test/unit/device_capability_test.dart"
  PRE_FAILED=1
fi

if [[ "$PRE_FAILED" -ne 0 ]]; then
  echo "==> Source is not demo-safe — fix the ✗ lines above before building."
  exit 1
fi
echo

# 3. Build (arm64-v8a only).
BUILD_ARGS=(build apk --release --target-platform android-arm64)

if [[ -z "$KEY" || "$KEY" == "$PLACEHOLDER" ]]; then
  echo "==> GEMINI_API_KEY not set. Building OFFLINE (cloud fallback disabled)."
  echo "==> This is the correct path for the demo-submission APK."
else
  echo "==> GEMINI_API_KEY detected. Building with cloud AI fallback enabled."
  echo "==> WARNING: the key will be embedded in the APK. Do not ship this build"
  echo "==> publicly. For the demo, rebuild without .env (or with the placeholder)."
  BUILD_ARGS+=(--dart-define=GEMINI_API_KEY="$KEY")
fi

flutter "${BUILD_ARGS[@]}"

# ── Post-build verification ────────────────────────────────────────────
# A green build does NOT mean the on-device model works. Check the artifact.
echo
echo "==> Verifying the APK can actually run the offline model..."
FAILED=0

if [[ ! -f "$APK" ]]; then
  echo "  ✗ APK not found at $APK"
  exit 1
fi

# List the APK ONCE into a variable. Do NOT pipe `unzip -l` straight into
# `grep -q`: grep exits at the first match, unzip then dies of SIGPIPE, and
# under `pipefail` the pipeline reports failure — so a check INVERTS itself.
# It only trips when the listing exceeds the 64 KB pipe buffer, which this
# APK is right on the edge of, making it fail intermittently.
ENTRIES="$(unzip -Z1 "$APK")"

# 1. The LiteRT-LM engine must be present for arm64, or Tier 2 silently
#    degrades to corpus answers on every phone.
if grep -qiE "^lib/arm64-v8a/.*(litert|gemma)" <<<"$ENTRIES"; then
  echo "  ✓ LiteRT-LM engine libs present (arm64-v8a)"
else
  echo "  ✗ NO LiteRT-LM engine libs in the APK — offline AI cannot run."
  echo "    The flutter_gemma native-assets hook likely failed; check the"
  echo "    build log for 'litertlm libs cached to'."
  FAILED=1
fi

# 2. Any non-arm64 lib dir lets Android pick that ABI on install — and those
#    dirs carry no engine (and no libflutter.so once --target-platform has
#    pruned them), so the app breaks. arm64 is the documented hard constraint.
OTHER_ABIS="$(grep -E "^lib/(armeabi-v7a|x86|x86_64|mips)/" <<<"$ENTRIES" || true)"
if [[ -n "$OTHER_ABIS" ]]; then
  echo "  ✗ Non-arm64 ABI present — that build can install without an engine:"
  sed 's/^/      /' <<<"$OTHER_ABIS"
  FAILED=1
else
  echo "  ✓ arm64-v8a only"
fi

# 3. R8 must not have deleted any Java class the engine reflects into.
#    (Dormant while MediaPipe is absent; real again if it is re-added.)
if [[ -f "$USAGE_TXT" ]]; then
  STRIPPED=$(grep -cE '^com\.google\.(mediapipe|protobuf|odml)[^:]*$' "$USAGE_TXT" || true)
  if [[ "$STRIPPED" -eq 0 ]]; then
    echo "  ✓ R8 stripped no MediaPipe/protobuf classes"
  else
    echo "  ✗ R8 deleted $STRIPPED MediaPipe/protobuf classes — see"
    echo "    android/app/proguard-rules.pro (-dontwarn does NOT keep them)."
    FAILED=1
  fi
fi

echo
if [[ "$FAILED" -ne 0 ]]; then
  echo "==> BUILD IS NOT DEMO-SAFE — see the ✗ lines above."
  exit 1
fi

echo "==> OK: $APK ($(du -h "$APK" | cut -f1))"
echo "==> Install: adb install -r \"$APK\"   (arm64 phone; the model downloads in-app)"
