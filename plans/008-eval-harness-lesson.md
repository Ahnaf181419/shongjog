# Plan 008: Lesson 0047 — teach the eval harness

> **Executor instructions**: Follow this plan step by step. Run every verification command
> and confirm the expected result before moving to the next step. If anything in the
> "STOP conditions" section occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a1b42a6..HEAD -- eval/` should show only
> plan-004 additions (rebuilt results). Confirm: `ls site/lessons/0046-mock-interview-demo.html`
> exists; `grep -c "End of course" site/lessons/0046-mock-interview-demo.html` → 1;
> `grep -n "def tokenize" eval/run_eval.py` → line 33. On mismatch beyond that, STOP.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW (additive lesson)
- **Depends on**: plans/004-kb-rebuild.md (cites post-rebuild eval numbers)
- **Category**: direction (content)
- **Planned at**: commit `a1b42a6`, 2026-08-22

## Why this matters

`eval/run_eval.py` is arguably the most instructive file in the repo — a Python
replication of the Dart keyword retriever, a 50-query held-out test set, honest recall
numbers (46% / 60% at baseline), and the only harness that caught the stale-KB defect.
No lesson teaches it. It is also the natural epilogue: after the capstone, "how do you
know it works?" This plan adds lesson 0047 (Capstone tier, optional) and closes the two
loose ends its existence creates (0046's "end of course" footer, the "47 lessons" count
in three places).

## Current state

- **Source material to teach (read ALL of these before writing)**:
  - `eval/run_eval.py` — header docstring (usage: `python3 eval/run_eval.py [--report base|finetuned]`),
    `tokenize()` at line 33 (`re.findall(r"[\u0980-\u09FFa-zA-Z]+", text.lower())`),
    `score_chunk()` replicating Dart scoring, outputs `eval/results/<report>.jsonl` +
    `_report.md`.
  - `eval/test_set.json` — 50 queries with expected topics.
  - `eval/rubric_template.csv` — manual grading rubric.
  - `eval/results/base_report.md` — baseline Recall@1 46.0% / Recall@3 60.0%;
    post-plan-004 there is also `eval/results/rebuilt_report.md` — cite THOSE numbers
    (read them; do not guess).
  - The stale-KB story now in past tense (plan 004 synced it) — 0047 retells it as
    "the harness that caught what the unit tests couldn't".
- **Lesson skeleton & binding spec**: `site/LESSON-SPEC.md` (READ IT FIRST — quiz rules,
  kicker format `Lesson NNNN · Phase tier · ~N min · optional`, ask-box, warn-callout,
  rebuild exercise phrasing, footer prev/next, "Primary source" line, quiz.js at end of
  body after the JSON block). Exemplar to model after:
  `site/lessons/0044b-first-fine-tune.html` (a recent optional-tier lesson that passed
  every gate) and `site/lessons/0012-corpus-and-loader.html` (grounding style).
- **Counters to update after adding**: `grep -n "47" site/index.html site/lessons/index.html`
  → 3 hits each (hero copy "all 47 lessons", metrics `<div class="num">47</div>`, any
  count in lessons/index header). Also 0046's footer (line ~170):
  `<b>End of course.</b> No next lesson — the capstone interview bank…` — must gain a
  next-lesson pointer while KEEPING Ref 08 as the back-pocket artifact.
- Quiz rules recap (enforced by `site/assets/check_quiz_parity.py`): 4-6 questions, ≥3
  options, exactly one correct, equal word counts per question's options.

## Commands you will need

| Purpose | Command | Expected on success |
|-----------|-------------|---------------------|
| Eval (dry) | `python3 eval/run_eval.py --report smoke` | writes results; recall sane |
| Parity | `python3 site/assets/check_quiz_parity.py` | PASS 48 files / 261-262 questions |
| Validator | `python3 site/assets/validate_lessons.py` | 0 errors, 1 warnings |
| Full gate | `./predeploy.sh` | exit 0 |

## Scope

**In scope**:
- `site/lessons/0047-eval-harness.html` (create)
- `site/lessons/index.html` (card + count), `site/index.html` (counts/hero copy)
- `site/lessons/0046-mock-interview-demo.html` (footer pointer ONLY)
- `site/NOTES.md`

**Out of scope**:
- `eval/` itself — the lesson teaches what exists; do not "improve" the harness
- Reference 08, any other lesson
- `site/LESSON-SPEC.md` (follow it, don't edit it)

## Git workflow

- site/ is gitignored; commit nothing. `eval/results/smoke*` created during dry-runs:
  delete them after verification (they are scratch, not records).

## Steps

### Step 1: Read + ground

Read every file in "Current state" (LESSON-SPEC first). Extract exact facts: tokenizer
regex, scoring weights from `score_chunk()`, test-set size, both recall reports' numbers,
what `rubric_template.csv` columns are. Every quiz explain and code cite in your lesson
must name a real file:line you have personally verified with `grep -n`.

**Verify**: your working notes (not committed) list ≥10 file:line facts; each confirmed
by grep. If any fact can't be grounded, drop it — never paraphrase-guess.

### Step 2: Write the lesson

`site/lessons/0047-eval-harness.html`, following the skeleton exactly:
- Kicker: `Lesson 0047 · Capstone tier · ~12 min · optional`
- Promise: by the end the learner can rebuild `tokenize()` + `score_chunk()` from
  memory, explain why the retriever is replicated in Python, and read a recall report
  honestly.
- Core sections (suggested): (1) why eval exists — the stale-KB story in past tense;
  (2) the harness tour — test set, replication, reports; (3) reading recall honestly —
  what 46%/60% does and does not mean, per-query jsonl; (4) the rubric — humans grade
  what recall can't; (5) limits — retrieval recall ≠ answer quality, Bangla tokenization
  edges.
- One `<div class="callout warn">` on a real trap (e.g. "the Python replica and the
  Dart original CAN drift — the eval measures the replica; any scoring change must land
  in both files or the numbers lie").
- Ask-box, "One real-world step": run `python3 eval/run_eval.py --report smoke` and read
  one per-query line (learner does this locally; the lesson shows the command verbatim).
- "Rebuild exercise": write `tokenize()` from memory, then diff against
  `eval/run_eval.py:33-36` (verify the exact line range before citing).
- Quiz: 4 questions minimum, JSON block + quiz.js at END of body, all spec rules.
- Footer: prev → 0046; next → Reference 08 as the continuing artifact; "Primary source"
  line pointing at `eval/run_eval.py`.

**Verify**: `python3 site/assets/validate_lessons.py` → the new file produces 0 errors
(warning count may stay at 1); file contains kicker/callout/ask-box/rebuild/quiz per
`grep -c`.

### Step 3: Close the loose ends

- 0046 footer: keep "End of course." but append the pointer — e.g. "Optional coda:
  Lesson 0047 (the eval harness) — how we know any of this works."
- `site/lessons/index.html`: add the card (copy a `<a class="card">` block, `data-num="0047"`,
  `data-phase="8"`, topic line, href), update the "47 lessons" count.
- `site/index.html`: update hero copy + metrics number 47 → 48.

**Verify**: `grep -rn "47 lessons\|all 47\|>47<" site/index.html site/lessons/index.html | wc -l` → 0;
`grep -c "0047" site/lessons/index.html` → ≥ 2 (card + count region).

### Step 4: Gates + log

`python3 site/assets/check_quiz_parity.py` → PASS 48 files (question total = 257 + your
count, report it); validator 0 errors; browser smoke on a fresh port (lesson renders,
quiz interactive — follow plan 002's port hygiene); `./predeploy.sh` exit 0. Delete
`eval/results/smoke*`. NOTES.md session entry.

**Verify**: all gates green; `ls eval/results/` shows no smoke files; NOTES count +1.

## Test plan

- Parity checker + validator + browser smoke are the test plan (content work).
- Cross-check every file:line cite in the lesson with a grep before declaring done —
  count them; target ≥10, zero misses.

## Done criteria

- [ ] `site/lessons/0047-eval-harness.html` exists and passes validator + parity
- [ ] Zero stale "47" counts; 0046 footer points at 0047
- [ ] Every code cite in the lesson grep-verifies (zero misses)
- [ ] Browser smoke passes; `./predeploy.sh` exit 0
- [ ] `plans/README.md` status row updated

## STOP conditions

- Plan 004 not DONE (its rebuilt_report.md numbers are required content).
- LESSON-SPEC conflicts with anything in this plan — the spec wins; report the conflict.
- You cannot ground a fact you wanted to teach — cut the fact, never soften it.

## Maintenance notes

- 0047's recall numbers are pinned to the post-0044b/0044/004 rebuild state — any future
  corpus change that reruns eval should refresh the lesson's quoted numbers.
- The lesson intentionally does NOT cover `training/lora_finetune.py` (0044b owns it);
  keep the boundary if the lesson is ever extended.
