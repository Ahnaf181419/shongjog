#!/usr/bin/env bash
# Ad-hoc verification of the ahnaf-branch mesh SOS work
# (Tasks 1-3: SosPayload, SosRelayEngine, SosRelayListener +
# MeshService.sendBytesToAll). Per the hermes verification pattern:
# OS-safe tempdir via mktemp -d, hermes-verify- prefix, run, then
# remove the dir explicitly. Ad-hoc = not a CI gate.
set -uo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; NC=$'\033[0m'

# 1. Find an OS-safe tempdir
TMPROOT="$(mktemp -d -t hermes-verify-ahnaf.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT

cd /home/frostflux/Ahnaf_Shafin/Hackathon/shongjog

# 2. Sanitize label -> filename (no slashes, no spaces).
slug () { echo "$1" | tr '/ ' '__' ; }

run_check () {
  local label="$1"; shift
  local out
  out="$TMPROOT/$(slug "$label").log"
  echo "${YEL}--- ${label} ---${NC}"
  if "$@" >"$out" 2>&1; then
    echo "${GREEN}PASS${NC}: $label"
    tail -3 "$out" | sed 's/^/   /'
  else
    echo "${RED}FAIL${NC}: $label"
    tail -30 "$out" | sed 's/^/   /'
  fi
}

run_check "flutter analyze lib test" flutter analyze lib/ test/
run_check "flutter test sos_payload_test" flutter test test/unit/sos_payload_test.dart
run_check "flutter test sos_relay_test" flutter test test/unit/sos_relay_test.dart
run_check "flutter test sos_relay_listener_test" flutter test test/unit/sos_relay_listener_test.dart
run_check "flutter test full suite" flutter test
