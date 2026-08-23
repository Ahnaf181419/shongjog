# Plan 004: Rebuild the stale KB — ship all 48 chunks — and sync every lesson that teaches the staleness

> **Executor instructions**: Follow this plan step by step. Run every verification command
> and confirm the expected result before moving to the next step. If anything in the
> "STOP conditions" section occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a1b42a6..HEAD -- tools/ assets/kb/ eval/`
> (empty is expected); and confirm site facts: `python3 -c "import json; print(len(json.load(open('tools/corpus.json'))))"`
> → 48, `python3 -c "import json; print(len(json.load(open('assets/kb/corpus.json'))))"`
> → 23. On mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED (changes shipped app data; large lesson-sync surface)
- **Depends on**: plans/002-deploy-gate.md (final gate)
- **Category**: bug
- **Planned at**: commit `a1b42a6`, 2026-08-22

## Why this matters

`tools/corpus.json` grew to 48 hand-authored Bangla chunks, but the last KB build ran at
23: `assets/kb/vectors.bin` is `[23, 768]` float32 (~75 KB) and `assets/kb/corpus.json`
is the stale copy. At runtime, 25 topics of verified safety content are invisible to
retrieval. The app's own honesty layer teaches this defect (lesson 0044's warn-callout,
lesson 0012, `reference/rag-pipeline.html`), so fixing the app without syncing the
lessons would make the course lie. This plan does both: rebuild + verify + eval-regress
the KB, then update every teaching claim from "is stale" to the new truth.

## Current state

- **Build tool**: `tools/build_kb.py` — embeds each chunk (text + `keywords_bn` + topic
  prefix) with `paraphrase-multilingual-mpnet-base-v2`, L2-normalizes, writes
  `assets/kb/corpus.json` (copy), `assets/kb/vectors.bin` (float32 row-major),
  `assets/kb/meta.json`. Header documents the exact setup:
  ```
  cd tools
  python3 -m venv .venv && source .venv/bin/activate
  pip install -r requirements.txt
  python3 build_kb.py
  ```
- **Deps**: `tools/requirements.txt` = `sentence-transformers>=3.0`, `torch>=2.3`,
  `numpy>=1.26` (multi-GB download; model itself ~1 GB).
- **Source of truth**: `tools/corpus.json` — a JSON list, currently 48 chunks.
- **Shipped (stale)**: `assets/kb/corpus.json` — 23 chunks.
- **Verifiers**: `tools/verify_kb.py` exists (structural check); `eval/run_eval.py`
  (50-query held-out test set at `eval/test_set.json`) replicates the Dart
  KeywordRetriever in Python and reports recall. **Baseline on record**
  (`eval/results/base_report.md`): **Recall@1 46.0%, Recall@3 60.0%**.
- **Lesson claim sites** (verified 2026-08-22; re-grep before editing — see Step 5):
  - `site/lessons/0012-corpus-and-loader.html` lines 39, 58, 91, 92, 136, 174 — teaches
    "23 chunks shipped / 48 authored, never rebuilt"; quiz Q&A + ask-box example
    reference "ship all 48 chunks".
  - `site/lessons/0023-map-location-permissions.html` lines 87, 88, 146, 165 — mentions
    the stale KB.
  - `site/lessons/0025-safe-beacon.html:111`, `site/lessons/0028-sos-relay-over-mesh.html:58,120`,
    `site/lessons/0026-mesh-fundamentals.html:79,171`, `site/lessons/0039-localization.html:75,123`,
    `site/lessons/0044b-first-fine-tune.html:45`.
  - `site/lessons/0044-architecture-tour.html` — the `<div class="callout warn">` "Trap —
    the stale KB" (in §4), plus §4 list items stating `[23, 768], ~75 KB` and "23
    hand-authored Bangla chunks".
  - `site/lessons/index.html` lines 98-99 — card topic strings: "23 chunks…" and
    "shipped KB is stale".
  - `site/reference/rag-pipeline.html` — same claims at reference level.
- **Quiz parity rule is binding** (`site/LESSON-SPEC.md`): any quiz option text you
  change must keep ALL options of that question at equal word count, exactly one
  correct, 4-6 questions, ≥3 options. The parity checker gates you.

## Commands you will need

| Purpose | Command | Expected on success |
|-----------|-------------|---------------------|
| Build KB | `cd tools && .venv/bin/python build_kb.py` (after venv+pip) | writes 3 files under `assets/kb/`, exit 0 |
| Verify KB | `cd tools && .venv/bin/python verify_kb.py` | exit 0, reports 48 chunks |
| Eval | `python3 eval/run_eval.py --report rebuilt` | writes `eval/results/rebuilt_report.md` |
| Flutter tests | `flutter test` | all pass |
| Content gates | `./predeploy.sh` | exit 0 |

## Scope

**In scope**:
- `tools/.venv/` (create; it is gitignored — confirm `git check-ignore tools/.venv || echo NOT-IGNORED`; if not ignored, STOP)
- `assets/kb/corpus.json`, `assets/kb/vectors.bin`, `assets/kb/meta.json` (build outputs)
- `eval/results/rebuilt.jsonl`, `eval/results/rebuilt_report.md` (eval outputs)
- The lesson/reference claim sites listed above (content edits)
- `site/NOTES.md` (session entry)

**Out of scope**:
- `tools/corpus.json` — the 48 chunks are reviewed and signed off; do NOT edit chunk text
- `lib/` Dart code — the loader auto-detects dimensions (see build_kb.py docstring)
- Any lesson content unrelated to the KB-staleness claims

## Git workflow

- App-side outputs (`assets/kb/*`, `eval/results/rebuilt*`) are tracked files — do not
  commit unless the operator explicitly permits. If permitted:
  `fix: rebuild KB to 48 chunks (was stale at 23)`. Site files are never committed.

## Steps

### Step 1: Build

```bash
cd tools
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python build_kb.py
```
Expect a long first run (model download ~1 GB). Then:
`ls -l ../assets/kb/` → `vectors.bin` ≈ 147,456 bytes (48 × 768 × 4).

**Verify**: `python3 -c "import json; print(len(json.load(open('../assets/kb/corpus.json'))))"` (from `tools/`) → 48; `stat -c%s ../assets/kb/vectors.bin` → 147456.

### Step 2: Structural verify + eval regression gate

```bash
cd tools && .venv/bin/python verify_kb.py
cd .. && python3 eval/run_eval.py --report rebuilt
```
Open `eval/results/rebuilt_report.md`: **Recall@1 ≥ 46.0% and Recall@3 ≥ 60.0%**
(matching-or-better than `base_report.md`). More chunks can shift keyword scores either
way; if recall DROPS below baseline, STOP and report the numbers — do not tune anything.

**Verify**: both thresholds met; report the exact numbers in your summary.

### Step 3: Flutter sanity

`flutter test` — all pass (loader is dimension-agnostic; no test should assert 23, but
confirm: `grep -rn "23" test/unit/*kb* test/unit/*knowledge* 2>/dev/null` → no chunk-count assertions).

**Verify**: `flutter test` exit 0.

### Step 4: Lesson-sync — classify every claim

Re-grep to get the live list (line numbers above may have drifted):
`grep -rn "23 chunks\|\[23, 768\]\|~75 KB\|stale" site/lessons site/reference > /tmp/opencode/kb-claims.txt`.
For EACH hit, classify and edit:
- **Counts/sizes**: `23 chunks` → `48 chunks`; `[23, 768]` → `[48, 768]`; `~75 KB` →
  `~144 KB`.
- **Present-tense staleness** (0012, 0044 warn-callout, index card topics,
  rag-pipeline): rewrite to past tense teaching the lesson it taught — e.g. 0044's
  warn-callout becomes the story: "The KB shipped stale at 23 chunks for months —
  `eval/run_eval.py` and `tools/verify_kb.py` were the only things that caught it; the
  unit tests never did. Rebuilt <date>; the habit to keep is: every corpus.json edit
  runs build_kb.py before release."
- **Quiz facts**: any quiz whose correct answer is "23" must be rewritten as a set —
  new correct answer "48", distractors re-padded to the SAME word count. Keep exactly
  one correct.
- **Do not** blindly replace the substring "23" — line numbers, phase numbers, other
  counts exist. Read each hit's sentence before editing.

**Verify**: `grep -rn "23 chunks\|\[23, 768\]\|~75 KB" site/lessons site/reference | wc -l` → 0;
`grep -rn "is stale\|currently stale" site/lessons site/reference | wc -l` → 0
(past-tense "was stale"/"shipped stale" may remain).

### Step 5: Content gates

`python3 site/assets/validate_lessons.py` → 0 errors, 1 warnings;
`python3 site/assets/check_quiz_parity.py` → PASS (question count may change only if you
rewrote, never added/removed questions — expect 257).

**Verify**: both green.

### Step 6: Gate + log

`./predeploy.sh` → exit 0, new zip. NOTES.md session entry: KB rebuilt (48/[48,768]/~144 KB),
eval numbers old→new, lesson-sync summary (files touched, claims rewritten).

**Verify**: `./predeploy.sh` exit 0; NOTES count +1.

## Test plan

- `tools/verify_kb.py` (structural), `eval/run_eval.py` (behavioral regression vs
  baseline), `flutter test` (integration), parity checker (content) — four independent
  gates, all specified above with expected outputs.

## Done criteria

- [ ] `assets/kb/corpus.json` has 48 chunks; `vectors.bin` is 147456 bytes
- [ ] `verify_kb.py` exit 0; Recall@1 ≥ 46.0%, Recall@3 ≥ 60.0% (report numbers)
- [ ] `flutter test` all pass
- [ ] Zero present-tense staleness claims; zero `23 chunks`/`[23, 768]`/`~75 KB` in site/
- [ ] Parity PASS 47 files / 257 questions; validator 0 errors
- [ ] `./predeploy.sh` exit 0
- [ ] `plans/README.md` status row updated

## STOP conditions

- Recall drops below baseline (Step 2) — report, do not tune corpus or code.
- `tools/.venv` is not gitignored.
- Model download fails / no network — report; do not substitute a different embedder
  model (dimension contract with shipped vectors).
- A stale-KB claim site turns out to be load-bearing for other content you can't
  rewrite without changing meaning — report the specific line.
- Any quiz rewrite can't hold word-parity — report the question rather than forcing it.

## Maintenance notes

- The 0044 warn-callout's new past-tense text should name the real rebuild date.
- Future corpus edits must re-run build_kb.py before any release — plan 002's gate does
  NOT catch app-asset staleness (site-only). A `flutter test` integration test asserting
  `assets/kb/corpus.json` chunk count == `tools/corpus.json` chunk count would make this
  class of drift impossible to ship — deferred as a follow-up, noted here so it isn't lost.
- Lesson 0047 (plan 008) will cite the post-rebuild eval numbers — keep
  `eval/results/rebuilt_report.md`.
