# Plan 003: Hash quiz answers out of the HTML source

> **Executor instructions**: Follow this plan step by step. Run every verification command
> and confirm the expected result before moving to the next step. If anything in the
> "STOP conditions" section occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: site/ is gitignored. Confirm instead:
> (a) `grep -c '"correct": true' site/lessons/0001-three-moving-parts.html` ≥ 1,
> (b) `sed -n '54p' site/assets/quiz.js` contains `if (opt.correct) {`,
> (c) `./predeploy.sh` exits 0. On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (touches all 47 lessons' quizzes + the quiz engine)
- **Depends on**: plans/001-validator-hardening.md, plans/002-deploy-gate.md
- **Category**: tech-debt
- **Planned at**: commit `a1b42a6`, 2026-08-22

## Why this matters

Every lesson's quiz HTML embeds the answer key in plain sight: `"correct": true` flags
inside the page source. A student who views source (or reads the page with dev tools
open) sees every answer. A 2026-08-22 fix already rotated correct positions to break the
"always option 1" pattern, but the flags remain trivially greppable. This plan replaces
the flags with a per-question hash: the source carries only `"a": <djb2-hash>` of the
correct option text; `quiz.js` computes the same hash client-side and compares. The
answer key becomes non-obvious to a casual reader while behavior stays identical.

## Current state

- `site/assets/quiz.js` (119 lines, plain ES5-style JS, no build step). Answer logic:
  ```js
  // line ~54
  if (opt.correct) {
    btn.classList.add("correct");
    correct++;
  ```
  ```js
  // lines ~61-62
  if (b.textContent === item.options.find(function (o) { return o.correct; }).t) {
    b.classList.add("correct");
  ```
  Options are shuffled per render (documented in the file header comment, lines 5-8).
- Quiz JSON format inside each lesson (47 files, 257 questions total), example shape:
  ```json
  { "questions": [
    { "q": "…?", "options": [
        { "t": "…", "correct": false },
        { "t": "…", "correct": true },
      ], "explain": "…" }
  ] }
  ```
  Serialization convention (exact, used by prior tooling): two-space indents as shown —
  question objects at 2 spaces, `"options": [` at 4, option objects at 6, `],` at 4,
  `"explain"` inline after options, `] }` closing.
- Both checkers read the flags: `site/assets/validate_lessons.py` `check_quiz` counts
  `o.get("correct")`; `site/assets/check_quiz_parity.py` (plan 002) does the same.
- Options contain Bangla text (U+0980-U+09FF) and occasionally emoji (astral plane).
  Any hash MUST be defined over UTF-16 code units so JS `charCodeAt` and Python agree.

## Commands you will need

| Purpose | Command | Expected on success |
|-----------|-------------|---------------------|
| Full gate | `./predeploy.sh` | exit 0 |
| Parity | `python3 site/assets/check_quiz_parity.py` | `PARITY: PASS 47 files / 257 questions` |
| No flags remain | `grep -r '"correct"' site/lessons/ \| wc -l` | `0` |

## Suggested executor toolkit

- Do the 47-file rewrite with a one-shot Python script kept in `/tmp/opencode/` (never
  committed). Use the exact reserialize format from "Current state".

## Scope

**In scope**:
- `site/assets/quiz.js`
- `site/lessons/*.html` (the 47 quiz JSON blocks only — no prose changes)
- `site/assets/validate_lessons.py` (the `check_quiz` correct-flag logic)
- `site/assets/check_quiz_parity.py` (same)
- `site/NOTES.md` (session-log entry)

**Out of scope**:
- Any lesson prose, headings, kickers, or option TEXT — the words must be byte-identical
  after migration
- `site/LESSON-SPEC.md` (operator will update it separately; note it in your report)

## Git workflow

- site/ is gitignored; commit nothing. App-side files untouched by this plan.

## Steps

### Step 1: Define the shared hash (design freeze)

Hash = djb2 variant over UTF-16 code units, 32-bit:

- **JS (goes in quiz.js)**:
  ```js
  function ansHash(s) {
    var x = 5381;
    for (var i = 0; i < s.length; i++) x = (Math.imul(33, x) + s.charCodeAt(i)) >>> 0;
    return x;
  }
  ```
- **Python (migration script + checkers)** — MUST produce identical values:
  ```python
  def ans_hash(s: str) -> int:
      x = 5381
      for unit in s.encode("utf-16-le"):
          pass  # WRONG unit size — see below; use this instead:
      # iterate 16-bit units:
      b = s.encode("utf-16-le")
      for i in range(0, len(b), 2):
          x = (33 * x + (b[i] | (b[i + 1] << 8))) % 4294967296
      return x
  ```
  (Clean that up — the loop body is `x = (33 * x + (b[i] | (b[i+1] << 8))) % 4294967296`.
  The `utf-16-le` 2-byte-unit iteration is what makes astral emoji and Bangla identical
  to JS `charCodeAt`.)

**Verify**: cross-check in a scratch dir — hash `"হ্যাঁ ঠিক"` and `"🟢 go"` with both
implementations; values must match exactly. Record the two values in your report.

### Step 2: Migrate the 47 quiz JSON blocks

One-shot `/tmp/opencode/migrate_quiz_hash.py`: for each `site/lessons/0*.html`, regex out
each JSON block (`<script type="application/json" id="(quiz[^"]+)">(.*?)</script>`, DOTALL),
parse, and for each question: find the option with `correct: true`, compute
`ans_hash(option["t"])`, insert `"a": <int>` as a question-level key next to `"q"`,
DELETE every `"correct"` key from every option. Reserialize with the exact format from
"Current state" (`ensure_ascii=False`), splice back. Report per-file question counts;
total must be 257.

**Verify**: `grep -r '"correct"' site/lessons/ | wc -l` → `0`;
`grep -c '"a":' <each file>` equals the old per-file flag count (spot-check 3 files);
`python3 -c "import json,re; [json.loads(m) for f in __import__('glob').glob('site/lessons/0*.html') for m in re.findall(r'<script type=\"application/json\" id=\"quiz[^\"]+\">(.*?)</script>', open(f).read(), 16)]"` → no exception.

### Step 3: Update `quiz.js`

Replace the two `opt.correct` / `find(...correct...)` sites with hash comparison:
`ansHash(opt.t) === item.a` (mark/feedback) and
`ansHash(JSON-parsed-option.t) === item.a` for the delayed-reveal branch. Add `ansHash`
near the top. Do not change shuffle logic, DOM structure, classes, or aria attributes.

**Verify**: `grep -c "ansHash" site/assets/quiz.js` → ≥ 3.

### Step 4: Update both checkers

- `validate_lessons.py` `check_quiz`: replace "exactly one `correct` flag" with "exactly
  one option whose hashed text equals the question's `a` value; `a` must be present and
  an int".
- `check_quiz_parity.py`: same substitution.

**Verify**: `python3 site/assets/validate_lessons.py` → `0 errors, 1 warnings`;
`python3 site/assets/check_quiz_parity.py` → `PARITY: PASS 47 files / 257 questions`.

### Step 5: Browser proof

`nohup python3 -m http.server 8912 --directory site &` (fresh port — see gotchas), then
with Playwright (or instruct operator if unavailable): open
`http://localhost:8912/lessons/0001-three-moving-parts.html`; click the CORRECT option text of question 1 (derive it
beforehand with the migration script: which option hashes to `a`), assert the button
gains class `correct` and an `.explain` node appears; click a wrong option on question 2,
assert it gains the wrong treatment. Kill the server
(`pkill -9 -f "[h]ttp.server 8912"`).

**Verify**: correct click → `correct` class + explain; wrong click → no false positive.

### Step 6: Gate + log

`./predeploy.sh` (exit 0). Append NOTES.md session entry (next after plan 002's — follow
whatever number 002's entry took): describe hash migration, note that LESSON-SPEC.md's
"exactly one `correct:true`" rule is now enforced as "exactly one option matching `a`".

**Verify**: `./predeploy.sh` exit 0; NOTES entry count +1.

## Test plan

- Cross-implementation hash equality (Step 1) is the critical test — Bangla + emoji.
- Step 5's two-click browser test covers the engine end-to-end.
- Fault-inject once: change one `a` value by +1 in a scratch copy of a lesson, confirm
  `check_quiz_parity.py` FAILS (zero options match), restore.

## Done criteria

- [ ] `grep -r '"correct"' site/lessons/ | wc -l` → 0
- [ ] `python3 site/assets/check_quiz_parity.py` → PASS 47/257
- [ ] `python3 site/assets/validate_lessons.py` → 0 errors, 1 warnings
- [ ] Browser test: correct answer marked correct, wrong not
- [ ] `./predeploy.sh` exits 0; zip rebuilt
- [ ] `plans/README.md` status row updated

## STOP conditions

- Any option TEXT changes during migration (byte-compare option `t` arrays before/after).
- JS and Python hashes disagree on the Step 1 test strings.
- Any lesson has a question where ZERO or TWO options match `a` after migration.
- Quiz rendering breaks in browser (explain not appearing) — restore from the
  `/tmp/opencode/` lesson backups and report.

## Maintenance notes

- `site/LESSON-SPEC.md` still documents the old flag format — the operator should amend
  it to the `a`-hash rule (quiz rules section). Flag this in the final report; do not
  edit the spec yourself unless the operator says otherwise.
- Future quiz authors need `tools` to compute `a`: note in your report that the migration
  script (kept at `/tmp/opencode/migrate_quiz_hash.py`) should be resurrected as a
  permanent `site/assets/quiz_hash.py` helper if new lessons get written — deferred, not
  in scope here.
- A determined reader can still brute-force hashes client-side; this raises the bar
  against casual viewing, it is not DRM. That matches the operator's intent.
