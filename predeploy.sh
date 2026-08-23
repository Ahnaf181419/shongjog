#!/usr/bin/env bash
# One-command predeploy gate: validator + quiz parity + detector + verified zip.
# Builds shongjog-site-v2.zip from site/ and refuses to ship it if any gate fails.
# Usage: ./predeploy.sh
set -euo pipefail
cd "$(dirname "$0")"

ZIP=shongjog-site-v2.zip
DETECT=/home/frostflux/.opencode/skills/impeccable/scripts/detect.mjs
mkdir -p /tmp/opencode

echo "== 1/6 validator =="
VAL_OUT=/tmp/opencode/predeploy-validator.txt
set +e
python3 site/assets/validate_lessons.py | tee "$VAL_OUT"
set -e
if ! tail -1 "$VAL_OUT" | grep -q " 0 errors,"; then
    echo "GATE FAILED: validator reported errors"
    exit 1
fi

echo "== 2/6 quiz parity =="
python3 site/assets/check_quiz_parity.py

echo "== 3/6 detector =="
if command -v node >/dev/null 2>&1 && [ -f "$DETECT" ]; then
    mkdir -p /tmp/opencode
    DETECT_JSON=/tmp/opencode/predeploy-detect.json
    set +e
    node "$DETECT" --json site/lessons site/reference > "$DETECT_JSON"
    DETECT_EXIT=$?
    set -e
    # exit 0 = clean, exit 2 = findings present; anything else is a real failure
    if [ "$DETECT_EXIT" -ne 0 ] && [ "$DETECT_EXIT" -ne 2 ]; then
        echo "GATE FAILED: detector exited $DETECT_EXIT"
        exit 1
    fi
    python3 - "$DETECT_JSON" <<'PY'
import collections
import json
import sys

accepted = {"em-dash-overuse", "numbered-section-markers"}
with open(sys.argv[1]) as f:
    data = json.load(f)
findings = data.get("findings", []) if isinstance(data, dict) else data
counts = collections.Counter(f.get("antipattern") for f in findings)
for ap, n in sorted(counts.items()):
    if ap in accepted:
        print(f"detector: {ap}: {n} (accepted)")
regressions = [f for f in findings if f.get("antipattern") not in accepted]
for f in regressions:
    print(f"detector REGRESSION: {f.get('antipattern')} in {f.get('file', '?')}")
if regressions:
    sys.exit(1)
print("detector: no regressions")
PY
else
    echo "detector: SKIPPED (not installed)"
fi

echo "== 4/6 zip build =="
rm -f "$ZIP"
(
    cd site
    zip -qr "../$ZIP" . \
        -x "LESSON-SPEC.md" \
        -x "learning-records/*" \
        -x "assets/validate_lessons.py" \
        -x "assets/check_quiz_parity.py" \
        -x "assets/quiz_hash.py" \
        -x "*.zip"
)

echo "== 5/6 zip diff-verify =="
rm -rf /tmp/opencode/zipcheck
mkdir -p /tmp/opencode/zipcheck
unzip -qo "$ZIP" -d /tmp/opencode/zipcheck
diff -r /tmp/opencode/zipcheck site \
    --exclude=LESSON-SPEC.md \
    --exclude=learning-records \
    --exclude=validate_lessons.py \
    --exclude=check_quiz_parity.py \
    --exclude=quiz_hash.py \
    --exclude="*.zip"
rm -rf /tmp/opencode/zipcheck
echo "VERIFIED: zip == disk"

echo "== 6/6 report =="
unzip -l "$ZIP" | tail -1
ls -lh "$ZIP"
echo "sha256: $(sha256sum "$ZIP" | cut -c1-16)"
echo "Deploy: drag $ZIP into https://app.netlify.com/drop — then hard-refresh once if you had the old site open."
