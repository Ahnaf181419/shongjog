# Plan 006: Interview-deck spaced repetition — a review page over Ref 08's 12 questions

> **Executor instructions**: Follow this plan step by step. Run every verification command
> and confirm the expected result before moving to the next step. If anything in the
> "STOP conditions" section occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: site/ is gitignored. Confirm:
> `grep -n "Section B" site/reference/capstone-interview-bank.html` → a line reading
  `Section B — Judge / interview Q&A bank (12 questions)`; `grep -n "shongjog-progress" site/assets/site.js`
> → 1+ match; `./predeploy.sh` exit 0. On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW (new page, additive)
- **Depends on**: plans/002-deploy-gate.md (final gate)
- **Category**: direction (feature)
- **Planned at**: commit `a1b42a6`, 2026-08-22

## Why this matters

The course's terminal artifact is Reference 08 (`site/reference/capstone-interview-bank.html`)
— a 12-question judge/interview Q&A bank the learner is told to "rehearse from memory
until the words stop being the doc's". Today rehearsal is unstructured: no scheduling,
no due-date tracking, no feedback loop. A lightweight spaced-repetition review page
(SM-2-lite) over exactly those 12 cards turns the site's own closing instruction into a
feature, using the existing localStorage progress infrastructure.

## Current state

- `site/reference/capstone-interview-bank.html` — Section B (line 100):
  `<h2>Section B — Judge / interview Q&A bank (12 questions)</h2>`, followed by 11 `<h3>`
  sections site-wide; B's Q&A blocks are the content source (extract verbatim).
- `site/assets/site.js` (603 lines, vanilla ES5-ish JS; this is the shared page JS —
  there is NO course.js; that name is stale in old notes). Storage convention:
  ```js
  // lines ~92-97
  PROGRESS: "shongjog-progress",
  function storageGet(k) { try { return localStorage.getItem(k); } catch (_) { return null; } }
  function storageSet(k, v) { try { localStorage.setItem(k, v); } catch (v) {} }
  ```
  Existing keys: `shongjog-theme`, `shongjog-progress`. New key: `shongjog-srs`.
- Styling: `site/assets/course.css` (single shared stylesheet; `?v=2` cache-busted links).
  Callout/quiz/ask-box component classes exist; a `card`/`btn` vocabulary exists on
  `site/index.html`.
- Page skeleton conventions: topbar + `<link rel="stylesheet" href="../assets/course.css?v=2">`,
  footer nav; reference pages live at `site/reference/*.html`, top-level pages at
  `site/*.html` (e.g. `site/index.html`, `site/404.html`). The validator treats
  `site/lessons/` and `site/reference/` specially; a new top-level page gets only the
  generic checks.
- Accessibility convention from quiz.js: feedback nodes use `aria-live="polite"`; buttons
  are real `<button>`s.

## Commands you will need

| Purpose | Command | Expected on success |
|-----------|-------------|---------------------|
| Content gates | `python3 site/assets/validate_lessons.py` / `check_quiz_parity.py` | 0 errors,1 warn / PASS 47/257 |
| Serve | `python3 -m http.server 8913 --directory site` (fresh port; kill with `pkill -9 -f "[h]ttp.server 8913"`) | 200s |
| Full gate | `./predeploy.sh` | exit 0 |

## Scope

**In scope**:
- `site/review.html` (create)
- `site/assets/review.js` (create)
- `site/assets/course.css` (append a small `review`-page block)
- `site/assets/interview-deck.json` (create — extracted content)
- `site/index.html` (one hero link)
- `site/NOTES.md`

**Out of scope**:
- `site/reference/capstone-interview-bank.html` (content stays canonical there; the deck
  JSON is a rendering copy — add ONE link from Section B to `/review.html` and nothing else)
- `site/assets/site.js` progress/export logic (do not entangle SRS with the lesson
  progress system in v1)
- Any lesson file

## Git workflow

- site/ is gitignored; commit nothing.

## Steps

### Step 1: Extract the deck

Create `site/assets/interview-deck.json`:
```json
{ "cards": [ { "id": "b01", "q": "<verbatim question>", "a": ["<bullet 1>", "<bullet 2>"] } ] }
```
12 cards, `id` = `b01`…`b12`, text lifted VERBATIM from Section B (read
`site/reference/capstone-interview-bank.html` lines 100-119). Multi-paragraph answers
become bullet arrays. Do not paraphrase — the page's own instruction is that the words
should eventually be the learner's, not ours.

**Verify**: `python3 -c "import json; d=json.load(open('site/assets/interview-deck.json')); print(len(d['cards']))"` → 12.

### Step 2: Build `site/review.html` + `site/assets/review.js`

- Page: standard skeleton, kicker `Review · Interview deck · 12 cards`, stylesheet
  `../assets/course.css?v=2`, topbar/back link, and a minimal shell:
  `<main id="review">` with a due-count line, one card container, and three grading
  buttons. Load `deck` via `fetch('../assets/interview-deck.json')`, script at end of body.
- SRS mechanics (SM-2-lite, days as epoch-day integers `Math.floor(Date.now()/864e5)`):
  state per card `{"due": <day>, "ivl": <days>, "ef": <2.5>}` under localStorage key
  `shongjog-srs` as `{"b01": {...}, ...}` (guarded with the same try/catch convention as
  site.js — copy the storageGet/Set helpers into review.js rather than depending on
  site.js internals). Grade buttons: **আবার (Again)** → `ivl=1, ef=max(1.3, ef-0.2)`;
  **ভালো (Good)** → `ivl=round(ivl*ef)||1`; **সহজ (Easy)** → `ivl=round(ivl*ef*1.3)||2`,
  `ef=min(2.8, ef+0.05)`. Cap `ivl` at 60. All cards unseen → due now.
  New-day rule: a card graded today is not re-served today (store `last=<day>` too).
- Show: question (front), tap/click reveals answer bullets, then the three buttons.
  Queue = due cards, ordered by `due` then id. Session end state: "No cards due — next
  review in N days" (min `due` − today).
- Progress preservation: grading writes state immediately; refresh mid-session resumes.

**Verify**: served page returns 200; `grep -c "aria-live" site/assets/review.js` ≥ 1;
`node -e "require('/dev/stdin')" < site/assets/review.js` NOT required (plain script) —
instead syntax-check with `node --check site/assets/review.js` → exit 0.

### Step 3: Index link + Section B pointer

- `site/index.html` hero CTA row (around line 49-52, next to "Browse all 47 lessons"):
  add `<a class="btn btn-ghost" href="review.html">Review due cards</a>`.
- `capstone-interview-bank.html` Section B intro: add one sentence linking
  `../review.html` for scheduled rehearsal. Nothing else on that page changes.

**Verify**: `grep -c "review.html" site/index.html site/reference/capstone-interview-bank.html` → 1 each.

### Step 4: CSS block

Append to `site/assets/course.css` a `/* review page */` block reusing existing tokens
(variables/colors already in the file — read the top of it first): card container,
front/back, grade buttons (three across, thumb-reachable on mobile ≥44px targets).
Because asset URLs carry `?v=2` and cache policy is 86400s, BUMP the review.html
stylesheet link to `?v=3` — and per the caching decision (NOTES entry 17) a global bump
is NOT required; only new/edited pages need a fresh query string. review.html is new, so
`?v=3` there is safe; index.html also changed → bump its two asset `?v=` strings to
`?v=3` as well.

**Verify**: `grep -o "course.css?v=[0-9]" site/review.html site/index.html | sort | uniq -c` → both v3.

### Step 5: Browser test + gates

Serve on 8913; with Playwright (else mark for operator): load `/review.html`, assert
12-card state initializes (localStorage `shongjog-srs` gains keys after first grade),
click আবার and সহজ on successive cards, reload, assert due count decreased accordingly.
Then `python3 site/assets/validate_lessons.py` (0 errors), parity PASS,
`./predeploy.sh` exit 0. NOTES.md session entry.

**Verify**: browser assertions pass; all gates green; NOTES count +1.

## Test plan

- `node --check` both JS files (syntax gate).
- Browser interaction test as specified in Step 5 (state persists across reload).
- Manual edge: with empty localStorage, first load shows 12 due; grading all Easy moves
  next-due ≥ 2 days out.

## Done criteria

- [ ] `site/assets/interview-deck.json` — 12 cards, verbatim content
- [ ] `node --check` clean on review.js; validator 0 errors; parity PASS
- [ ] Browser test: grade → reload → due count correct
- [ ] `./predeploy.sh` exit 0 (zip now includes review.html/review.js/interview-deck.json)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Section B does not contain exactly 12 Q&A items at the cited location.
- The skeleton/CSS conventions differ materially from every other page (validator will
  usually catch this first).
- fetch() of the deck JSON fails from `file://` — note it, but the site is always served
  over http(s); not a blocker.

## Maintenance notes

- Deck is a COPY of Ref 08 content — if Section B ever changes, the JSON must be
  re-extracted (add a line to Ref 08's maintenance note at the top of Section B).
- v2 candidates (deferred): extending the deck with per-lesson quiz questions; wiring
  SRS state into the site.js progress export. Both need operator buy-in first.
