# Exhibition deck

`Shongjog-Exhibition-Deck.pdf` — 19 slides, 16:9, for the AUST CSE Carnival 8.0
project exhibition.

## Regenerating

The PDF is rendered from `deck.html` by headless Chrome:

```bash
cd docs/presentation
google-chrome --headless=new --disable-gpu --no-sandbox \
  --allow-file-access-from-files \
  --run-all-compositor-stages-before-draw \
  --virtual-time-budget=20000 --no-pdf-header-footer \
  --print-to-pdf="Shongjog-Exhibition-Deck.pdf" \
  "file://$PWD/deck.html"
```

Edit `deck.html` and re-run. Every slide is one `<section class="s">`; the page box
is pinned to 1600 × 900 px by `@page`, so a slide that grows past its footer is
clipped rather than reflowed onto a new page.

**After any content edit, check nothing overflows.** Chrome silently crops it,
and a low-resolution preview hides the loss. Paste the measuring script from
this file's history into the page, or eyeball it:

```bash
pdftoppm -png -r 60 Shongjog-Exhibition-Deck.pdf /tmp/pg/p
montage /tmp/pg/p-*.png -tile 4x -geometry 400x225+5+5 /tmp/pg/sheet.png
```

## Speaking script

`SCRIPT.md` is the talk track for this deck — a per-slide script with measured
timings, the demo choreography word for word, a question bank, and what to do
when something breaks on stage. Timings there are derived from the actual word
counts at 125 wpm, so they are worth trusting during rehearsal.

## Slides

| # | Slide |
|---|---|
| 1 | Cover |
| 2–3 | The problem · why existing tools fail |
| 4–5 | What we built · a real Bangla answer in airplane mode |
| 6–8 | The four-tier cascade · grounding and governance · the on-device stack |
| 9–11 | The mesh · the product surface · the coordinator panel |
| 12 | Architecture — the dependency rule |
| 13 | **Architecture — the request path** (SVG diagram) |
| 14 | Evidence — tests, analyzer, release gates, retrieval numbers |
| 15–16 | SDG mapping · Complex Engineering Problem P1–P7 |
| 17–19 | Honest limits · demo run-sheet · close |

Slide 13 is the only diagram. It carries the deck's argument in one picture: the
request path left to right, colour-coded by architectural layer, with the horizon
rule showing that exactly one arrow — the Tier 2 cloud fallback — crosses it. The
strip along the bottom is what the pipeline reads from local storage.

### SVG gotcha

Chrome's PDF writer **drops a gradient applied to a `stroke`**. The horizon line in
the diagram silently vanished the first time it was rendered. The same gradient as a
`fill` on a 2px `<rect>` survives, which is how it is drawn now. If you add a
gradient to the diagram, render to PDF and look at it — the on-screen preview will
not show you the loss.

## Assets

| Path | What |
|---|---|
| `../../assets/fonts/Manrope.ttf` | Latin face — the app's own Latin fallback |
| `../../assets/fonts/AnekBangla.ttf` | Bangla face — the app's primary family |
| `../screenshots/*.jpeg` | Real device captures, not mockups |
| `mark-sky.png`, `mark-ocean.png` | Brand mark recoloured from `assets/icon_foreground.png` |

Fonts and images are referenced by relative path and embedded into the PDF at
render time, so the PDF is self-contained — it renders identically on a machine
that has neither font installed. Verify with `pdffonts` (every row should read
`emb yes`).

## Design notes

Palette, type scale and shape are taken from the product's own design system
(`lib/app/theme.dart`, `docs/design.md` §5), so the deck reads as the same
artefact as the app running on the phone. Two rules worth keeping if you edit it:

- **The horizon rule means one thing.** The 1px sky-coloured line
  (`.horizon`) marks the boundary where the network stops — content above it
  depends on connectivity, content below it does not. It is the deck's only
  repeated device. Don't reuse it as decoration.
- **No all-caps labels.** `docs/design.md` §2 bans them as a tell; the deck
  follows the same rule.

## Every number on these slides was verified against the repository

Re-check them before presenting if the code has moved:

| Claim | Source |
|---|---|
| 948 tests passing, 0 failing | `flutter test` |
| 0 analyzer issues | `flutter analyze` |
| 156 Dart files, ~44K lines | `find lib -name '*.dart'` |
| 48 chunks / 22 topics / 34 sources | `assets/kb/corpus.json`, `meta.json` |
| 263 shelters | `assets/shelter/cyclone_shelters.geojson` |
| 26 quick cards | `lib/features/quick_cards/cards_data.dart` |
| 799 strings per locale | `lib/l10n/app_{en,bn}.arb` |
| Recall@1 46% · Recall@3 62% | `eval/results/rebuilt_report.md` |
| 12 release checks | `scripts/build_release.sh` |
| Gemma 4 E2B 2.47 GB · EmbeddingGemma 300M 179 MB | `assets/embeddinggemma/`, model catalog |
