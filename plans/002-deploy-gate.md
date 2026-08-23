# Plan 002: One-command predeploy gate — validator + parity + detector + verified zip

> **Executor instructions**: Follow this plan step by step. Run every verification command
> and confirm the expected result before moving to the next step. If anything in the
> "STOP conditions" section occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a1b42a6..HEAD -- site/assets/` shows
> nothing (site/ is gitignored). Instead: confirm `site/assets/validate_lessons.py`
> contains the four checks added by plan 001 (grep for `U+FFFD`, `Rebuild( exercise`,
> `kicker`, `quiz.js loaded before`) and that `python3 site/assets/validate_lessons.py`
> reports `0 errors`. On mismatch, plan 001 is not done — STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/001-validator-hardening.md
- **Category**: dx
- **Planned at**: commit `a1b42a6`, 2026-08-22

## Why this matters

Deploys today are a hand-typed zip command with excludes that live only in muscle memory
(and in `site/NOTES.md`). Nothing stops a zip that omits the diff-verify step, skips the
quiz-parity check, or ships with a validator regression. This plan makes
`./predeploy.sh` the single entry point: run all content gates, build the zip with the
canonical excludes, verify the zip byte-for-byte against `site/`, print the hash — and
refuse to produce a zip if any gate fails. Every later plan ends with "run predeploy.sh".

## Current state

- The zip build command used historically (run from inside `site/`, output at repo root):
  ```bash
  zip -qr ../shongjog-site-v2.zip . -x "LESSON-SPEC.md" -x "learning-records/*" -x "assets/validate_lessons.py" -x "*.zip"
  unzip -qo ../shongjog-site-v2.zip -d /tmp/zipcheck && diff -r /tmp/zipcheck . --exclude=LESSON-SPEC.md --exclude=learning-records --exclude=validate_lessons.py --exclude="*.zip"
  ```
- `site/assets/validate_lessons.py` — content validator (hardened by plan 001). Run from
  repo root: `python3 site/assets/validate_lessons.py`.
- Quiz parity is currently checked only by ad-hoc inline Python from a past session —
  there is NO permanent checker. Rules (binding, from `site/LESSON-SPEC.md`): every
  lesson quiz has 4-6 questions, ≥3 options per question, exactly one option with
  `"correct": true`, all options of one question have equal word counts
  (whitespace-split), JSON valid.
- Detector: `node /home/frostflux/.opencode/skills/impeccable/scripts/detect.mjs --json <dirs>`
  emits JSON `{findings: [{antipattern, ...}]}`. Accepted antipattern types (operator
  decision, NOTES.md entry 18): `em-dash-overuse`, `numbered-section-markers`. Any OTHER
  type is a regression. The path is machine-local — the script must degrade gracefully
  when absent.
- Expected zip shape today: 74 files, ~415 KB.

## Commands you will need

| Purpose | Command | Expected on success |
|-----------|-------------|---------------------|
| Validator | `python3 site/assets/validate_lessons.py` | `55 files checked — 0 errors, 1 warnings` |
| Flutter tests (sanity only, not part of the gate) | `flutter test` | all pass |
| Zip verify | `unzip -l ../shongjog-site-v2.zip \| tail -1` | `74 files` (grows as lessons are added) |

## Scope

**In scope** (the only files you should create/modify):
- `predeploy.sh` (create, repo root, `chmod +x`)
- `site/assets/check_quiz_parity.py` (create)

**Out of scope** (do NOT touch):
- `site/assets/validate_lessons.py` (plan 001 owns it)
- Any HTML/CSS/JS content
- `netlify.toml`, Netlify itself — deploys remain a manual drop by the operator

## Git workflow

- `predeploy.sh` and `site/assets/check_quiz_parity.py`: `site/` is gitignored by design;
  `predeploy.sh` at repo root IS tracked. Do not commit unless the operator explicitly
  permits (standing rule). If permitted, message style follows
  `git log --oneline` (conventional commits, e.g. `chore: add predeploy gate script`).

## Steps

### Step 1: Create the permanent parity checker

`site/assets/check_quiz_parity.py` — stdlib Python 3, no args needed (defaults to
`site/lessons/*.html` relative to repo root; accept optional dir override). For each
lesson file, extract every `<script type="application/json" id="quiz…">` block, parse
JSON, and enforce: 4-6 questions, ≥3 options, exactly one `"correct": true` per
question, equal word counts across each question's options, non-empty `explain`.
Print one line per file failure and a summary
`PARITY: PASS <N> files / <M> questions` or `PARITY: FAIL`. Exit code 1 on any failure.
Follow the code style of `site/assets/validate_lessons.py` (plain functions, `err`-style
collectors, final summary line).

**Verify**: `python3 site/assets/check_quiz_parity.py` → `PARITY: PASS 47 files / 257 questions`, exit 0.

### Step 2: Create `predeploy.sh` at repo root

Bash, `set -euo pipefail`, `cd` to script's directory. Stages:

1. **Validator gate**: `python3 site/assets/validate_lessons.py | tee /dev/stderr | tail -1 | grep -q " 0 errors,"` — fail the script if errors > 0 (the 1 standing warning is fine).
2. **Parity gate**: `python3 site/assets/check_quiz_parity.py`.
3. **Detector (advisory-gated)**: if `node` exists AND `/home/frostflux/.opencode/skills/impeccable/scripts/detect.mjs` exists, run it with `--json site/lessons site/reference`, parse the JSON, and fail ONLY if any finding's `antipattern` is outside `{em-dash-overuse, numbered-section-markers}`; print the accepted-type counts as info. If node or the script is missing, print `detector: SKIPPED (not installed)` and continue.
4. **Zip build**: `rm -f shongjog-site-v2.zip`; from `site/`: the canonical `zip -qr ../shongjog-site-v2.zip . -x …` command from "Current state" above.
5. **Zip diff-verify**: fresh `/tmp/opencode/zipcheck` (mkdir -p, rm -rf first), unzip, `diff -r` with the canonical excludes, then `rm -rf /tmp/opencode/zipcheck`.
6. **Report**: file count (`unzip -l | tail -1`), size (`ls -lh`), `sha256sum | cut -c1-16`, and the reminder line: `Deploy: drag shongjog-site-v2.zip into https://app.netlify.com/drop — then hard-refresh once if you had the old site open.`

**Verify**: `./predeploy.sh` → exits 0, prints both gate PASS lines (or detector SKIPPED),
`VERIFIED: zip == disk`, and a 16-char sha256 prefix.

### Step 3: Prove the gate actually blocks

Temporarily introduce a parity violation in a scratch copy: `cp site/lessons/0001-three-moving-parts.html /tmp/opencode/0001.bak`, edit the live file to give one question two `correct: true` flags, run `./predeploy.sh` (expect non-zero exit, no new zip produced — check `ls -l shongjog-site-v2.zip` timestamp unchanged), restore the backup, re-run `./predeploy.sh` (expect success).

**Verify**: gate failed on corruption; gate passes after restore; final `./predeploy.sh` exit 0.

### Step 4: Log it

Append a NOTES.md entry (next number after the last `## Session log` entry — currently
ends at 18; this becomes 19) in `site/NOTES.md`: one line describing predeploy.sh and the
parity checker, dated.

**Verify**: `grep -c "^- 2026" site/NOTES.md` → one more than before this step.

## Test plan

- Step 3 is the test plan (fault injection). No framework applies.

## Done criteria

- [ ] `./predeploy.sh` exits 0 end-to-end and prints a sha256 prefix
- [ ] `python3 site/assets/check_quiz_parity.py` → `PARITY: PASS 47 files / 257 questions`
- [ ] Fault-injection run (Step 3) blocked the deploy and produced no new zip
- [ ] `unzip -l shongjog-site-v2.zip | tail -1` → 74 files; zip diff-verify clean
- [ ] `git status` shows only `predeploy.sh` as new/untracked (plus plans/)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Validator or parity reports failures on CURRENT content — that means content regressed
  before the gate existed; report the exact messages.
- The historical zip excludes produce a diff-verify mismatch you cannot explain.
- `site/NOTES.md` does not end at entry 18 (session log drifted).

## Maintenance notes

- Plans 003-008 all end with `./predeploy.sh` — if its interface changes, update those plans.
- When a new excluded-from-deploy file appears under `site/` (e.g. another tool script),
  it must be added BOTH to the zip `-x` list and the `diff --exclude` list, or the
  diff-verify will false-fail.
- The detector path is machine-local by design; on a machine without the impeccable
  skill the gate degrades to validator+parity, which is acceptable.
