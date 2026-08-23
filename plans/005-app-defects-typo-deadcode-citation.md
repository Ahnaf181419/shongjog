# Plan 005: Fix the শঙ্গজগ typo, delete dead GmsDetector, resolve the UNICEF citation — then sync the lessons that teach them

> **Executor instructions**: Follow this plan step by step. Run every verification command
> and confirm the expected result before moving to the next step. If anything in the
> "STOP conditions" section occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a1b42a6..HEAD -- lib/ test/` (empty
> expected). Confirm: `grep -rn "শঙ্গজগ" lib/ | wc -l` → 5;
> `grep -n "GmsDetector" lib/features/mesh_comm/gms_detector.dart | head -1` exists;
> `grep -n "UNICEF" tools/corpus.json` → line 174. On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW-MED (string changes asserted by tests; deletion of a documented-dead file)
- **Depends on**: plans/002-deploy-gate.md (final gate)
- **Category**: bug / tech-debt
- **Planned at**: commit `a1b42a6`, 2026-08-22

## Why this matters

Three defects ship in the app and are TAUGHT as defects by the course (the honesty
callouts are a course signature). Fixing them without breaking the course requires
editing both sides. (1) The app's Bangla prompts misspell its own name: `শঙ্গজগ` instead
of `সংযোগ` — visible in every LLM prompt the app builds. (2) `GmsDetector` is unwired
scaffolding that contradicts nothing and helps nothing. (3) One corpus chunk cites a
UNICEF source that is off the project's whitelist — an attribution-integrity issue in a
disaster-information app.

## Current state

- **Typo, app side** — 5 occurrences of `শঙ্গজগ` (wrong) for `সংযোগ` (correct):
  - `lib/features/intelligence/situation_summary_service.dart:29` — `'তুমি শঙ্গজগ। নিচের সাম্প্রতিক প্রতিবেদনগুলির ভিত্তিতে '`
  - `lib/features/emergency/sos_function_schema.dart:58` — `'শঙ্গজগ SOS রিপোর্ট:'`
  - `lib/features/emergency/sos_function_schema.dart:84` — `'— শঙ্গজগ অ্যাপ থেকে পাঠানো'`
  - `lib/features/planner/kit_prompt_builder.dart:16` — `'তুমি শঙ্গজগ। এই পরিবারের জন্য একটি ব্যক্তিগতকৃত '`
  - `lib/features/planner/risk_prompt_builder.dart:124` — `'তুমি শঙ্গজগ। এই বাড়ি ও পরিবারের জন্য একটি '`
- **Typo, test side** — `test/unit/sos_function_test.dart:50` and `:71` assert the
  misspelled strings (`expect(body, contains('শঙ্গজগ'));` and
  `expect(body, contains('শঙ্গজগ SOS রিপোর্ট:'));`).
- **Typo, teaching side** — quoted as a "spot the bug" honesty exercise:
  `site/lessons/0030-sos-composer.html` (3 spots), `site/lessons/0032-planner-kit-risk.html`
  (1 spot), `site/reference/emergency-ux-flows.html` (1 spot).
- **GmsDetector** — `lib/features/mesh_comm/gms_detector.dart`: a static
  `isAvailable()` over `MethodChannel('shongjog/gms_check')`; NO Kotlin handler is
  registered (MainActivity registers SMS + audio only), the heuristic returns true
  unconditionally, and NOTHING imports it (verified: only hits in its own file; no tests).
  Taught as unwired in `site/lessons/0026-mesh-fundamentals.html` (lines 44, 47, and
  quiz Q at 110-121) and `site/reference/offline-mesh-core.html:49` ("the probe IS the
  detector").
- **UNICEF** — `tools/corpus.json:174`: `"source": "UNICEF Child hygiene in emergencies, 2023"`
  on one chunk. Taught as an off-whitelist example in `site/lessons/0012-corpus-and-loader.html`
  and `site/reference/rag-pipeline.html`. The corpus whitelist (MoDMR, BMD, etc.) is
  documented in the repo's corpus review docs — check `tools/README.md` first.

## Commands you will need

| Purpose | Command | Expected on success |
|-----------|-------------|---------------------|
| Tests | `flutter test` | all pass |
| Analyzer | `flutter analyze` | no new issues vs baseline |
| No typo remains | `grep -rn "শঙ্গজগ" lib/ test/ \| wc -l` | 0 |
| No GmsDetector remains | `grep -rn "GmsDetector" lib/ test/ \| wc -l` | 0 |
| Content gates | `./predeploy.sh` | exit 0 |

## Scope

**In scope**:
- The 5 lib files above (string fix only), `test/unit/sos_function_test.dart` (2 asserts)
- `lib/features/mesh_comm/gms_detector.dart` (DELETE)
- `tools/corpus.json` (source field of the one UNICEF chunk only) + `tools/build_kb.py`
  rerun NOT required (source is metadata, not embedded text — confirm in Step 3)
- Teaching-sync sites: 0030, 0032, 0026, `site/reference/emergency-ux-flows.html`,
  `site/reference/offline-mesh-core.html`, `site/reference/rag-pipeline.html`,
  `site/lessons/0012-corpus-and-loader.html`
- `site/NOTES.md`

**Out of scope**:
- Any other Bangla string content; any other corpus chunk
- `lib/features/mesh_comm/` transport code (Nearby/WiFi-Direct) — live code, do not touch
- Rewriting the 0026 lesson's core narrative (the "probe is the detector" teaching point
  SURVIVES the deletion — see Step 4)

## Git workflow

- lib/test/tools changes are tracked. Standing rule: commit only on explicit operator
  permission. If permitted: `fix: correct শঙ্গজগ→সংযোগ in prompts, drop unwired GmsDetector`.

## Steps

### Step 1: Fix the typo (app + tests)

Replace `শঙ্গজগ` → `সংযোগ` at the 5 lib sites and the 2 test asserts. Watch :29/:16/:124
carefully: only the name token changes, the surrounding Bengali sentence stays
byte-identical.

**Verify**: `grep -rn "শঙ্গজগ" lib/ test/ | wc -l` → 0; `flutter test test/unit/sos_function_test.dart` → pass.

### Step 2: Delete GmsDetector

`git rm lib/features/mesh_comm/gms_detector.dart` (or plain `rm` if not committing).
Confirm no references: `grep -rn "gms_check\|GmsDetector" lib/ test/ android/ | wc -l` → 0.

**Verify**: `flutter analyze` → no new errors; `flutter test` → all pass.

### Step 3: Resolve the UNICEF citation

Read `tools/README.md` (and any corpus review doc it points to) for the source
whitelist. Then:
- If the whitelist is explicit and UNICEF is off it: replace the chunk's `source` value
  with `"স্বাস্থ্য অধিদপ্তর (Directorate General of Health Services) — জরুরি স্বাস্থ্যসেবা নির্দেশিকা"`
  ONLY IF the chunk's guidance text actually matches that provenance; otherwise set
  `"source": "general emergency hygiene guidance — attribution pending review"` and STOP-report
  for an operator decision on the real source.
- If NO whitelist document exists: STOP and report — the "off-whitelist" premise came
  from the course text, and the right fix needs the operator's sourcing call.
- Check `tools/build_kb.py` whether `source` is part of the embedded text (grep the
  build script for `"source"`): if NOT embedded, no rebuild needed; if embedded, re-run
  the build per plan 004 Step 1 (venv already exists after 004).

**Verify**: `grep -n "UNICEF" tools/corpus.json` → 0 (or STOP reported); build/no-build
decision recorded in your report.

### Step 4: Sync the teaching side

- **0030 / 0032 / emergency-ux-flows**: the typo honesty-callouts become past tense —
  "the prompts misspelled the app's own name (`শঙ্গজগ`) until it was fixed; the tests
  asserted the typo too, which is how it survived review." Keep them as teaching
  moments; do not delete the callouts.
- **0026 + offline-mesh-core**: GmsDetector references become: "`gms_detector.dart` was
  unwired scaffolding — deleted `<date>`; the lesson it taught: the real GMS detection
  IS the Nearby probe in `MeshService.start()`, which never needed a helper." The 0026
  quiz question about GmsDetector must be REWRITTEN as a set (equal word counts across
  options, exactly one correct — parity checker gates you), e.g. testing "why was
  gms_detector.dart deleted" instead of "what does it do today".
- **0012 / rag-pipeline**: the UNICEF off-whitelist example becomes past tense
  consistent with whatever Step 3 decided.

**Verify**: `grep -rn "শঙ্গজগ" site/ | grep -v NOTES.md | wc -l` → 0 remaining
  PRESENT-tense bug claims (past-tense quotes of the old string are allowed);
  `grep -rn "GmsDetector" site/ | wc -l` → only past-tense mentions; parity PASS.

### Step 5: Full gates + log

`flutter test`; `python3 site/assets/validate_lessons.py` (0 errors, 1 warnings);
`python3 site/assets/check_quiz_parity.py` (PASS 47/257); `./predeploy.sh` (exit 0).
NOTES.md session entry summarizing all three fixes + lesson syncs.

**Verify**: all four green; NOTES count +1.

## Test plan

- `flutter test` covers the string asserts (updated in Step 1) and everything else.
- Fault check: `flutter test test/unit/sos_function_test.dart` alone first — fastest
  signal on the typo change.

## Done criteria

- [ ] `grep -rn "শঙ্গজগ" lib/ test/ | wc -l` → 0
- [ ] `ls lib/features/mesh_comm/gms_detector.dart` → No such file
- [ ] `flutter analyze` no new issues; `flutter test` all pass
- [ ] UNICEF resolved or STOP-reported with the whitelist evidence
- [ ] Teaching side: zero present-tense defect claims for all three items; parity PASS
- [ ] `./predeploy.sh` exit 0
- [ ] `plans/README.md` status row updated

## STOP conditions

- The whitelist for corpus sources doesn't exist or is ambiguous (Step 3).
- Deleting GmsDetector breaks `flutter analyze` (unexpected import somewhere).
- A lesson sync can't preserve quiz parity — report the question.
- The typo appears in MORE places than listed (e.g., android/iOS native strings) —
  extend only with the same fix, and report the extra sites.

## Maintenance notes

- The honesty-callout pattern (defect → past-tense teaching moment) is now established
  twice (KB staleness in plan 004, these three). Keep it: it is the course's signature.
- If a future `git log` archaeologist wonders why tests once asserted a misspelling:
  the answer lives in NOTES.md — keep entries append-only.
