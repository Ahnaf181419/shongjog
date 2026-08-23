# Plan 007: Full-text search over all lessons and references

> **Executor instructions**: Follow this plan step by step. Run every verification command
> and confirm the expected result before moving to the next step. If anything in the
> "STOP conditions" section occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a1b42a6..HEAD -- tools/` (empty
> expected). Confirm site facts: `ls site/lessons/*.html | wc -l` → 47 (+2 index pages),
> `grep -c "class=\"searchbox\"\|search" site/lessons/index.html` → 0 (no search exists
> yet). On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW (additive; one new asset + small JS)
- **Depends on**: plans/002-deploy-gate.md (final gate; also owns the zip exclude list this plan extends)
- **Category**: direction (feature)
- **Planned at**: commit `a1b42a6`, 2026-08-22

## Why this matters

47 lessons + 8 references, ~415 KB of dense technical prose, zero search. A learner who
remembers "the lesson that explained desugaring" has only the card topics to go by. A
static prebuilt index + ~80 lines of vanilla JS gives full-text search with no service,
no dependency, and one extra cached asset fetch — fully in keeping with the site's
no-build-server architecture.

## Current state

- Content set: `site/lessons/0*.html` (47), `site/lessons/index.html`,
  `site/reference/*.html` (8), `site/index.html`. All static, hand-authored.
- Text is bilingual: Bangla (U+0980-U+09FF) + English + code identifiers. Bangla has no
  case; English should match case-insensitively. The app's own Python retriever
  tokenizes with `[\u0980-\u09FFa-zA-Z]+` (`eval/run_eval.py:33` — same convention to reuse).
- `site/lessons/index.html` — card grid page (`<div class="cards">` with `<a class="card">`
  per lesson, `data-*` attributes: slug/phase/num/title/topic). Phase-filter UI may
  already exist there via site.js — read the page before inserting UI.
- `site/assets/site.js` — shared JS (603 lines) with storage helpers; vanilla style, no
  framework, no modules (plain functions, `addEventListener`).
- Asset caching: `?v=2` query strings + 86400s asset cache (netlify.toml). New/changed
  assets need bumped `?v=` on the pages referencing them.
- Zip deploy excludes live in `predeploy.sh` (plan 002): new build-time tools must NOT
  ship in the zip → the builder script goes in `tools/` (repo root, tracked, not in
  site/), its OUTPUT (`site/assets/search-index.json`) ships.

## Commands you will need

| Purpose | Command | Expected on success |
|-----------|-------------|---------------------|
| Build index | `python3 tools/build_search_index.py` | writes `site/assets/search-index.json`, prints doc count |
| Validate JSON | `python3 -m json.tool site/assets/search-index.json > /dev/null` | exit 0 |
| JS syntax | `node --check site/assets/search.js` | exit 0 |
| Full gate | `./predeploy.sh` | exit 0 |

## Scope

**In scope**:
- `tools/build_search_index.py` (create — tracked file at repo root tools/)
- `site/assets/search-index.json` (generated; ships in zip)
- `site/assets/search.js` (create)
- `site/lessons/index.html`, `site/reference/index.html` if one exists (check; else
  `site/index.html` only) — search box markup + script include
- `predeploy.sh` — no exclude changes needed (builder lives outside site/)
- `site/NOTES.md`

**Out of scope**:
- Any lesson/reference content
- `site/assets/site.js` (keep search self-contained in search.js)
- Netlify redirects/headers

## Git workflow

- `tools/build_search_index.py` is a tracked file: commit only on explicit operator
  permission (`feat: static search index builder`). site/ files: never committed.

## Steps

### Step 1: Build the index builder

`tools/build_search_index.py` (stdlib only), modeled on `eval/run_eval.py`'s plain
functions + `Path` style. For each page in the content set:
- strip `<script>…</script>`, `<style>…</style>`, `<nav>…</nav>`, HTML comments, then
  all tags; unescape entities (`html.unescape`);
- title from `<title>`;
- record `{"u": <url relative to site root, e.g. "lessons/0012-corpus-and-loader.html">,
  "t": <title>, "h": [<h2/h3 texts>] , "b": <stripped body text, collapsed whitespace>}`.
Output JSON list to `site/assets/search-index.json` (compact separators, no sort_keys).
Print `<N> pages, <K> KB`.

**Verify**: run it → `57 pages` (47 lessons + lessons/index + 8 references + site/index
— count may legitimately differ if reference/index.html exists; report actual), size
roughly 300-500 KB.

### Step 2: search.js — client

~80 lines vanilla JS, no dependencies:
- `fetch` the index once on first interaction (lazy — only when the input receives
  focus or input event), cache in a closure variable.
- Query handling: split on whitespace; each term matches if `body.toLowerCase()`
  contains it OR the term's Bangla form appears in body (Bangla needs no lowering but
  lower-casing is harmless). Score: 10 per title hit, 4 per heading hit, 1 per body hit
  (count capped at 5 per term); sum across terms; require ALL terms to hit somewhere.
- Render top 10 as links (title + 90-char snippet centered on the first matched term,
  ellipses, matched term `<mark>`-wrapped) into a results container directly under the
  box; `role="status" aria-live="polite"` on the container; Escape clears; empty input
  hides results. Keyboard: results are real `<a>`s — tab-reachable by default.
- Debounce input at ~120ms.

**Verify**: `node --check site/assets/search.js` → exit 0.

### Step 3: Wire into the index pages

On `site/lessons/index.html` (and the reference hub page if one exists — check
`ls site/reference/index.html`; if the reference set has no index page, wire only
lessons + `site/index.html`):
```html
<div class="searchbox" role="search">
  <input id="site-search" type="search" placeholder="সব লেসন খুঁজুন / search all lessons…"
         aria-label="Search lessons and references" autocomplete="off">
  <div id="search-results" role="status" aria-live="polite"></div>
</div>
<script src="../assets/search.js?v=1" defer></script>
```
Place above the card grid. Add a `.searchbox` block to course.css (input styling
matching existing form/button tokens; results absolutely positioned, max-height with
scroll, existing card background/border tokens).

**Verify**: served page (http.server on a FRESH port, e.g. 8914, `pkill -9 -f "[h]ttp.server 8914"` after)
renders the box; typing `desugaring` yields 0042 first (its body covers it);
typing `সংযোগ` returns Bangla-content pages; `zzzqqq` shows "no matches" text.

### Step 4: Rebuild discipline + gates

Document at the top of `tools/build_search_index.py`: "run after ANY content edit;
predeploy.sh does not auto-run this (v1)". Then full gates: validator 0 errors, parity
PASS, `./predeploy.sh` exit 0 (zip grows by search assets). NOTES.md entry.

**Verify**: `./predeploy.sh` exit 0; NOTES count +1.

## Test plan

- `node --check` (syntax), JSON tool validation, and the three live queries in Step 3
  (English technical term, Bangla term, no-match) — verified in browser.
- Snippet sanity: a multi-term query (`stale KB`) returns pages containing BOTH terms,
  ranked above single-term pages.

## Done criteria

- [ ] `tools/build_search_index.py` exists; regenerating produces byte-identical output
      (run twice, `cmp` the two outputs — determinism check)
- [ ] search.js syntax-clean; live queries behave as specified (3 checks above)
- [ ] Validator 0 errors; parity PASS; `./predeploy.sh` exit 0
- [ ] `plans/README.md` status row updated

## STOP conditions

- The content set contains pages that break the tag-stripper (e.g. `<script>` inside
  `<pre>` code samples — check: if code samples in lessons embed literal script tags,
  switch the stripper to an HTMLParser-based implementation instead of regex).
- Index exceeds ~800 KB (would hurt first-search latency on mobile — report size).
- The lessons index page already has a filter UI that conflicts spatially.

## Maintenance notes

- The index MUST be rebuilt after content edits — until that's automated (v2 candidate:
  predeploy.sh step), stale search results will confuse learners. The script header
  says so; NOTES.md too.
- v2 candidates: Bangla stemming/normalization (v1 is substring-exact), search on the
  review page, per-phase scoping.
