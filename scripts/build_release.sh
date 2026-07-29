#!/usr/bin/env bash
#
# Build the shippable release APK.
#
# Usage:
#   bash scripts/build_release.sh                         # the one you want
#   ALLOW_EMBEDDED_KEY=1 bash scripts/build_release.sh    # local dev only
#
# NO API KEY IS COMPILED IN BY DEFAULT, and .env is deliberately ignored.
# A `--dart-define` value ends up as a plaintext literal in libapp.so, so any
# public APK built with one has a public key — `strings libapp.so | grep
# AIzaSy` is the entire attack. The app fetches its key at runtime from
# Firestore `config/cloud_ai` instead (lib/core/remote_key_service.dart),
# which keeps the credential out of the binary AND makes it revocable without
# shipping a new build.
#
# ALLOW_EMBEDDED_KEY=1 restores the old behaviour — reads GEMINI_API_KEY from
# the environment or .env and bakes it in — for working on cloud AI without a
# Firestore round trip. That build is NOT publishable; the key gate below is
# relaxed for it, so nothing else will stop you from shipping it by mistake.
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

# The Firebase project every device must sync against. google-services.json is
# gitignored and downloaded per-developer, so two people can hold valid files
# for DIFFERENT projects — the build succeeds on both and the phones then talk
# to two separate backends, which looks exactly like "sync is broken" and
# nothing in the build output says otherwise. Pinning the id here turns that
# into a build failure. Not a secret: it ships in the APK regardless.
FIREBASE_PROJECT_ID="shongjog-007"

ALLOW_EMBEDDED_KEY="${ALLOW_EMBEDDED_KEY:-0}"

# Resolve a key ONLY when explicitly opted in. The default path never reads
# .env at all — leaving the file on disk must not silently produce an
# unpublishable APK, which is exactly what happens when a key is picked up
# implicitly.
KEY=""
if [[ "$ALLOW_EMBEDDED_KEY" == "1" ]]; then
  # Caller's environment wins over the file.
  KEY="${GEMINI_API_KEY:-}"
  if [[ -z "$KEY" && -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
    KEY="${GEMINI_API_KEY:-}"
  fi
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

EMBEDDED_KEY=0
if [[ -z "$KEY" || "$KEY" == "$PLACEHOLDER" ]]; then
  echo "==> No key compiled in — this build is publishable."
  echo "==> Cloud AI still works on device: the app fetches its key at first"
  echo "==> launch from Firestore config/cloud_ai. On-device Gemma 4 needs no"
  echo "==> key at all."
else
  EMBEDDED_KEY=1
  echo "==> ALLOW_EMBEDDED_KEY=1 — compiling GEMINI_API_KEY into the binary."
  echo "==> *** DO NOT PUBLISH THIS APK. *** The key is recoverable from it"
  echo "==> with a single grep. Re-run without ALLOW_EMBEDDED_KEY for a build"
  echo "==> you can upload."
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

# ── Cross-device sync checks ───────────────────────────────────────────
# The admin panel (broadcasts, campaign requests, safety reports) syncs over
# Firestore, and an incoming broadcast raises a tray notification on every
# other device. All three parts below are invisible to analyze/test — they
# live in the merged manifest and the packaged dex — and each fails silently
# at runtime: no crash, just an admin whose broadcast reaches nobody.
#
# `strings` is binutils; skip rather than fail if the box doesn't have it.
if ! command -v strings >/dev/null 2>&1; then
  echo "  ~ strings(1) not found — skipping Firebase/notification checks"
else
  # 4. Firebase must be wired, and to the RIGHT project. The google-services
  #    Gradle plugin already hard-fails when the JSON is absent, so this is
  #    really guarding against a stale file for a different project.
  if [[ "$(unzip -p "$APK" resources.arsc | strings -a | grep -c "$FIREBASE_PROJECT_ID" || true)" -gt 0 ]]; then
    echo "  ✓ Firebase wired to $FIREBASE_PROJECT_ID"
  else
    echo "  ✗ APK carries no reference to Firebase project $FIREBASE_PROJECT_ID."
    echo "    android/app/google-services.json is for a different project (or"
    echo "    was swapped) — admin broadcasts will not reach other devices."
    FAILED=1
  fi

  # 5. Without the plugin there is no tray notification: a broadcast still
  #    syncs and still updates the in-app bell, so this regression is only
  #    visible if you happen to be watching a second phone's lock screen.
  if [[ "$(unzip -p "$APK" 'classes*.dex' 2>/dev/null | strings -a | grep -c 'flutterlocalnotifications' || true)" -gt 0 ]]; then
    echo "  ✓ Local-notification plugin packaged"
  else
    echo "  ✗ flutter_local_notifications is not in the APK — incoming admin"
    echo "    broadcasts will sync silently, with no notification."
    FAILED=1
  fi

  # 6. No Gemini key compiled into the Dart binary. `--dart-define` values are
  #    plaintext literals in libapp.so, so a public APK built with one has a
  #    public key — `strings libapp.so | grep AIzaSy` is the whole attack.
  #    The key is delivered at runtime from Firestore instead
  #    (lib/core/remote_key_service.dart), so there is never a reason for one
  #    to be in here. Scans libapp.so ONLY: the Firebase Android API key is
  #    also an AIzaSy string, but it lives in resources.arsc and is meant to
  #    ship.
  #
  #    Matches BOTH credential shapes this project has actually had in .env:
  #    `AIzaSy…` (a real Google API key) and `AQ.Ab…` (the OAuth-style
  #    ephemeral token). A grep for AIzaSy alone would have waved through the
  #    keyed build made earlier in this project's history.
  KEY_HITS="$(unzip -p "$APK" lib/arm64-v8a/libapp.so | strings -a | grep -cE 'AIzaSy|AQ\.Ab' || true)"
  if [[ "$KEY_HITS" -eq 0 ]]; then
    echo "  ✓ No API key compiled into libapp.so"
  elif [[ "$EMBEDDED_KEY" == "1" ]]; then
    # Opted in above, so this is expected — say it loudly rather than failing,
    # or there'd be no way to make a local cloud-AI build at all.
    echo "  ! API key IS baked into libapp.so (ALLOW_EMBEDDED_KEY=1)"
    echo "    This APK is for local testing only — do not upload it."
  else
    echo "  ✗ A Gemini API key is baked into libapp.so, but this build never"
    echo "    passed one. Something else injected it — inspect before shipping."
    FAILED=1
  fi

  # 7. Binary AndroidManifest keeps its string pool in UTF-16, hence -el.
  #    Missing this permission is silent on Android 12 and below and total on
  #    13+, so a phone-dependent "notifications don't work" report.
  if [[ "$(unzip -p "$APK" AndroidManifest.xml | strings -el | grep -c 'POST_NOTIFICATIONS' || true)" -gt 0 ]]; then
    echo "  ✓ POST_NOTIFICATIONS declared"
  else
    echo "  ✗ POST_NOTIFICATIONS missing from the merged manifest — Android 13+"
    echo "    devices will silently drop every notification."
    FAILED=1
  fi

  # 8. Speech engine visibility. Android 11+ hides the system recogniser and
  #    the TTS engine unless the app declares intent to resolve them, and we
  #    target 36. Without these, initialize() returns false and voice input
  #    reports a microphone-permission error that isn't one.
  MANIFEST_STRINGS="$(unzip -p "$APK" AndroidManifest.xml | strings -el)"
  if [[ "$(grep -c 'android.speech.RecognitionService' <<<"$MANIFEST_STRINGS" || true)" -gt 0 &&
        "$(grep -c 'TTS_SERVICE' <<<"$MANIFEST_STRINGS" || true)" -gt 0 ]]; then
    echo "  ✓ Speech recogniser + TTS queries declared"
  else
    echo "  ✗ <queries> is missing the speech intents — voice input and"
    echo "    read-aloud will both fail on Android 11+."
    FAILED=1
  fi

  # 9. The notification small icon is named ONLY from a Dart string, so the
  #    release resource shrinker cannot see it and happily strips it. Debug
  #    builds keep it, which makes this invisible until someone installs the
  #    release APK and no notification ever appears. res/raw/keep.xml is what
  #    holds it in; this gate proves the keep rule actually worked.
  if command -v aapt2 >/dev/null 2>&1; then
    # grep -c, never grep -q: with `set -o pipefail`, -q exits on the first
    # match and SIGPIPEs aapt2, which fails the whole pipeline and reports a
    # missing resource that is actually present. Same trap as check 7.
    if [[ "$(aapt2 dump resources "$APK" 2>/dev/null |
             grep -c 'drawable/ic_notification' || true)" -gt 0 ]]; then
      echo "  ✓ Notification icon survived resource shrinking"
    else
      echo "  ✗ drawable/ic_notification was stripped from the APK. Android"
      echo "    resolves the missing id to 0 and refuses to post the"
      echo "    notification. Check android/app/src/main/res/raw/keep.xml."
      FAILED=1
    fi
  else
    echo "  ! aapt2 not on PATH — skipped the notification-icon check"
  fi
fi

echo
if [[ "$FAILED" -ne 0 ]]; then
  echo "==> BUILD IS NOT DEMO-SAFE — see the ✗ lines above."
  exit 1
fi

echo "==> OK: $APK ($(du -h "$APK" | cut -f1))"
echo "==> Install: adb install -r \"$APK\"   (arm64 phone; the model downloads in-app)"
