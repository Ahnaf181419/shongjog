# Text Content SSOT Sweep (v0.9)

**Date:** 2026-09-09
**Branch:** `i18n`
**Status:** Foundation landed; legacy carry-over at 53 files (budget: 60).

Shongjog ships in Bangla, with an English sibling. To prevent the codebase
from drifting back to "every screen hard-codes its own copy" — a failure
mode we've already paid for in the v0.8 era — every user-facing string
must live in **one** of three source-of-truth locations:

| Layer | Files | Reader | Format |
| --- | --- | --- | --- |
| UI copy | `lib/l10n/app_bn.arb` + `lib/l10n/app_en.arb` | `flutter gen-l10n` → `AppLocalizations` | `{key: "text"}` JSON |
| Data tables | `assets/data/*.json` | `lib/core/text_loader.dart` `TextLoader.loadJson<T>` | `{bn:{...}, en:{...}}` wrapper |
| LLM prompts | `assets/prompts/*.json` | per-feature `*_strings_loader.dart` | `{bn:{...}, en:{...}}` wrapper |

## What landed in this PR

### Phase 0 — Pre-flight
- 30 `@`-prefixed metadata blocks synced from `app_bn.arb` → `app_en.arb`.
- `pubspec.yaml` now declares `assets/data/` + `assets/prompts/`.
- Baseline: 955 tests passing, 1,451 raw Bangla literals in non-ARB Dart.

### Phase 1 — Shared loader
- `lib/core/text_loader.dart`: `loadJson<T>(path, parser, locale:)` with
  parsed-result cache keyed by `(path, locale)` so bn and en blocks coexist
  in the same load.
- `lib/features/rag/persona_loader.dart`: `PersonaBundle`, `loadPersona`.

### Phase 2 — Data tables → JSON
- `assets/data/cards.json` — 25 quick cards (bn + en) extracted from the
  600-line `lib/features/quick_cards/cards_data.dart` constant.
- `assets/data/districts.json` — 64 districts × 8 divisions bilingual.
- `assets/data/emergency_directory.json` — relocated from
  `assets/emergency/`.
- `assets/data/corpus.json` — RAG corpus with parallel `text_bn` /
  `text_en` + `keywords_bn` / `keywords_en`. Vector file unchanged
  (multilingual model maps both into the same embedding space).

### Phase 3 — LLM prompts → JSON
- `persona.json`, `planner.json`, `kit.json`, `risk.json`, `rumour.json`,
  `situation_summary.json`, `shelter.json`, `damage_scan.json`.
- `lib/rag/urgency_classifier.dart` — removed the hard-coded
  `labelBn` field; `UrgencyLevelLabel.label(context)` extension
  continues to source labels from `AppLocalizations`.
- `lib/rag/rumour_checker.dart` — rumour-check prompt + prefix list now
  load from `assets/prompts/rumour.json`.

### Phase 4 — UI strings → ARB
- Major: `triage_state.dart`, `demo_seeder.dart`,
  `weather_service.dart` now consume AppLocalizations.
- 53 legacy files remain as carry-over; `test/lint/no_scattered_bangla_test.dart`
  enforces ≤ 60 until a future sweep drains them.

### Phase 5 — Lint + sweep test
- `test/lint/no_scattered_bangla_test.dart` enforces:
  - **Hard:** all prompt/data assets have parallel `bn`/`en` blocks.
  - **Hard:** `app_bn.arb` and `app_en.arb` have identical key sets
    (ignoring `@`-prefixed metadata blocks).
  - **Soft:** total Bangla-literal files in `lib/` ≤ 60. Bump this
    down in subsequent sweeps until it hits 0, then flip the assertion
    to `isEmpty`.

## Verification
- `flutter test`: **963 / 963 passing** (+8 from new tests).
- `flutter analyze`: clean (one `use_build_context_synchronously`
  informational in `chat_screen.dart` 235 — guarded by `mounted` at the
  outer scope).

## What's left for v1.0
- Drain the 53 legacy Bangla-literal files down to 0.
  - Quick wins: `lib/features/chat/message_bubble.dart`,
    `lib/features/chat/typewriter_text.dart`,
    `lib/features/emergency/sos_composer_screen.dart`,
    `lib/features/about/about_screen.dart`,
    `lib/features/home/live_hazards_card.dart`,
    `lib/features/intelligence/intelligence_engine.dart`.
- Decide whether the on-device RAG vector index needs a true
  en-side embed pass. Currently the multilingual model maps both bn and
  en to the same space, so the bn vectors suffice for en queries as a
  first cut, but if F6 evaluation shows en precision drift we'll need a
  parallel `corpus_en.vectors.bin` and a runtime selector.
- Add a `custom_lint_builder`-based `shongjog_lints` package so the
  `no_user_facing_bangla` rule surfaces in IDEs (today only the sweep
  test catches it).

## Migration guide (for the next sweep)

```dart
// Before
'তুমি সংযোগ। {planQuestion}'

// After
AppLocalizations.of(context).planSystemPrompt

// OR for a prompt bundle:
final s = await loadPlannerStrings('bn');
s.systemRole  // already localized
```

```dart
// Before
final k = 'বন্যা';

// After — for enum labels that need to surface in UI
EonetCategory.floods.labelBn(loadEonetStrings('bn'))
// OR for AppLocalizations route:
AppLocalizations.of(context).eonetCategoryFlood
```
