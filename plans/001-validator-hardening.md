# Plan 001: Harden the lesson validator so every class of bug we actually hit is machine-caught

> **Executor instructions**: Follow this plan step by step. Run every verification command
> and confirm the expected result before moving to the next step. If anything in the
> "STOP conditions" section occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `site/` is gitignored (by design), so git diff cannot see
> it. Instead open `site/assets/validate_lessons.py` and confirm the excerpts in
> "Current state" match. On mismatch, STOP and report.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx / tests
- **Planned at**: commit `a1b42a6`, 2026-08-22

## Why this matters

The validator (`site/assets/validate_lessons.py`) is the only automated guard on 55
hand-authored HTML files. The 2026-08-22 content audit found real bug classes it did not
catch: U+FFFD encoding corruption (8 instances shipped), a lesson whose quiz `<script>`
was loaded in `<head>` before the DOM existed, kickers that drifted from the spec format,
and rebuild-exercise headings it doesn't know the accepted variant of ("Rebuild it from
memory" vs "Rebuild exercise"). This plan teaches the validator all four, so plan 002 can
gate deploys on it.

## Current state

- `site/assets/validate_lessons.py` — single-file stdlib Python validator. Structure:
  - `err(path, msg)` / `warn(path, msg)` append to `errors` / `warnings` lists (lines ~25-33)
  - `check_quiz(path, text)` — validates quiz JSON: ≥3 options, exactly one `correct`
    flag, non-empty `explain`, equal word counts across options (lines ~56-85)
  - `check_banned(path, text)` — regexes from a `BANNED` list, with a signing-TODO exemption (lines ~90-99)
  - `check_skeleton(path, text, is_lesson)` — checks stylesheet link `href="../assets/course.css(?:\?v=\d+)?"`,
    quiz.js script tag, `ask-box`, "Primary source", and `Next up (Lesson \d{4}` (lines ~100-115)
- Excerpt of the rebuild-heading check as it exists (in `check_skeleton`, continues past line 110):
  ```python
  if not re.search(r"Next up \(Lesson \d{4}", text):
  ```
  There is currently NO rebuild-exercise check, NO kicker check, NO U+FFFD check, NO
  quiz.js-position check.
- Binding content spec: `site/LESSON-SPEC.md` — kicker format (line 21) is
  `Lesson NNNN · Phase-name area · ~N min` (phase names are freeform: `On-device tier`,
  `Cloud AI tier`, `RAG, knowledge &amp; tool-calling`, `Fail-soft APIs &amp; map`,
  `Offline core &amp; mesh`, `Emergency &amp; feature UX`, `Platform tier`, `Capstone`;
  capstones use `~N hr`; 0044b suffixes ` · optional`).
- Rebuild-exercise variants in the wild (ALL 47 lessons have one — verified
  2026-08-23): 38 × `<h2>Rebuild exercise</h2>`, 3 × `<h2>Rebuild it from memory</h2>`
  (0012-0014), 3 × `<span class="label">Rebuild exercise</span>` (0034/0035/0036),
  3 × `<p>Rebuild exercise: …</p>` (0037/0038/0040). A plain-text regex covers all four.
- ONE known content drift exists: `site/lessons/0042-release-pipeline-hardening.html`
  kicker reads `Lesson 0042 · Platform · ~16 min` — every other phase-8 lesson says
  `Platform tier`. This plan fixes that single token (see Step 3).
- Quiz placement rule (spec + fixed bug in 0044b): the `<script src="../assets/quiz.js">`
  tag must appear AFTER the quiz JSON `<script type="application/json" id="quiz…">` block
  in document order.
- The 1 standing warning is `lessons/0046-mock-interview-demo.html: WARN: no next-lesson
  pointer` (terminal lesson — by design).

## Commands you will need

| Purpose | Command | Expected on success |
|-----------|-------------|---------------------|
| Run validator | `python3 site/assets/validate_lessons.py` (from repo root) | `55 files checked — 0 errors, 1 warnings` |

The 1 standing warning is `0046: no next-lesson pointer` (terminal lesson — by design).

## Scope

**In scope** (the only files you should modify):
- `site/assets/validate_lessons.py`
- `site/lessons/0042-release-pipeline-hardening.html` — ONE token only: the kicker
  `Platform` → `Platform tier` (Step 3b). Nothing else on that page.

**Out of scope** (do NOT touch):
- Any HTML file — this plan adds checks only; if a new check fires on real content, that
  is a finding to REPORT, not content to silently edit.
- `site/LESSON-SPEC.md`.

## Git workflow

- Do not commit anything. `site/` is gitignored by design; the operator manages deploys.

## Steps

### Step 1: Ban U+FFFD (encoding corruption) as an error

In `check_banned` (or a new `check_encoding(path, text)` called from the main loop right
after `check_banned`), add: if `"\ufffd"` appears anywhere in `text`, emit
`err(path, "U+FFFD replacement character — encoding corruption")`.

**Verify**: `python3 site/assets/validate_lessons.py` → still `0 errors, 1 warnings`
(the shipped content is clean — 8 corruptions were fixed on 2026-08-22).

### Step 2: Accept all four rebuild-exercise variants (warn, not error)

In `check_skeleton`, when `is_lesson` is true, add:

```python
if not re.search(r"Rebuild (exercise|it from memory)", text):
    warn(path, "no rebuild-exercise (Rebuild exercise / Rebuild it from memory)")
```

(Plain-text regex on purpose: the exercise appears as an `<h2>`, a callout
`<span class="label">`, or a `<p>` prefix depending on the lesson.)

**Verify**: `python3 site/assets/validate_lessons.py` → warning count unchanged at 1
(all 47 lessons match one of the four variants).

### Step 3: Validate the kicker format (and fix the one drifted kicker)

In `check_skeleton` for lessons — but ONLY when the filename starts with four digits
(`re.match(r"\d{4}", os.path.basename(path))` — this excludes `lessons/index.html`,
whose kicker is `Shongjog AI Stack · Course catalog` by design):

```python
if not re.search(r'class="kicker"[^>]*>Lesson \d{4}b? · (?:On-device tier|Cloud AI tier|RAG, knowledge &amp; tool-calling|Fail-soft APIs &amp; map|Offline core &amp; mesh|Emergency &amp; feature UX|Platform tier|Capstone) · ~\d+ (?:min|hr)(?: · optional)?\s*<', text):
    err(path, "kicker phase is not one of the eight canonical phase names (or format drifted)")
```

(The phase alternation is closed-world on purpose: it catches vocabulary drift like
`Platform` vs `Platform tier`, which a `[^<·]+` wildcard cannot. New phases require
updating this list AND `site/lessons/index.html`'s phase grouping.)

Run the validator first — expect EXACTLY ONE error: 0042's kicker (`Platform` missing
`tier`). Then apply **Step 3b**, the single content fix this plan allows: in
`site/lessons/0042-release-pipeline-hardening.html`, change
`Lesson 0042 · Platform · ~16 min` → `Lesson 0042 · Platform tier · ~16 min`.

**Verify (after 3b)**: `python3 site/assets/validate_lessons.py` → `0 errors, 1 warnings`;
`grep -o 'Lesson 0042 · [^<]*' site/lessons/0042-release-pipeline-hardening.html` →
`Lesson 0042 · Platform tier · ~16 min`.

### Step 4: Enforce quiz.js placement after the JSON block

In `check_quiz` (which already extracts JSON blocks with their `id`s), after the existing
loop add: find `m_js = re.search(r'src="\.\./assets/quiz\.js(?:\?v=\d+)?"', text)` and the
first JSON block match position `m_json = re.search(r'<script type="application/json" id="quiz', text)`.
If both exist and `m_js.start() < m_json.start()`, emit
`err(path, "quiz.js loaded before the quiz JSON block — must be at end of body")`.

**Verify**: `python3 site/assets/validate_lessons.py` → `0 errors` (0044b was fixed).

### Step 5: Negative tests — prove the new checks fire

Create a throwaway copy OUTSIDE the repo (`/tmp/opencode/vtest/copy.html` style is fine —
do not create files inside the repo): copy any one lesson file, then one at a time (a)
insert `\ufffd`, (b) delete its rebuild-exercise text, (c) mangle the kicker, (d) move the
quiz.js tag above the JSON block — and run the validator pointed at a temp directory
containing only that file (`python3 site/assets/validate_lessons.py /tmp/opencode/vtest`
if the script takes a path argument; if it hardcodes `site/`, temporarily copy the
validator next to the temp dir and run it there). Expect exactly one new error/warning
per mutation. Delete the temp dir afterwards.

**Verify**: each of the four mutations produced its specific message; final
`python3 site/assets/validate_lessons.py` from repo root → `55 files checked — 0 errors, 1 warnings`.

## Test plan

- No unit-test framework exists for the validator; the negative tests in Step 5 ARE the
  test plan. Keep them in `/tmp`, never in the repo.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `python3 site/assets/validate_lessons.py` → `55 files checked — 0 errors, 1 warnings`
- [ ] `grep -n "ufffd\|U+FFFD" site/assets/validate_lessons.py` → at least one match
- [ ] `grep -n "Rebuild (exercise\| it from memory)" site/assets/validate_lessons.py` → one match
- [ ] `grep -n "kicker" site/assets/validate_lessons.py` → ≥ 1
- [ ] 0042 kicker reads `Lesson 0042 · Platform tier · ~16 min`
- [ ] All four Step-5 negative tests fired their specific message
- [ ] `git status` shows no tracked-file changes; only validate_lessons.py and 0042 differ under site/
- [ ] `plans/README.md` status row updated

## STOP conditions

- Any new check fires on the CURRENT shipped content (means the excerpt assumptions are
  wrong — report, don't edit content).
- The validator script structure differs materially from "Current state".
- You find yourself wanting to edit an HTML file to make a check pass.

## Maintenance notes

- Plans 003 and 004 will re-run this validator as a gate; keep error messages
  single-line and prefixed with the file path (existing convention).
- When a new lesson-shape rule is added to `site/LESSON-SPEC.md`, it should get a check
  here in the same session.
