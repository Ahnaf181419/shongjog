# AI-First Feature Expansion — Plan (2026-07-25)

> Derived from `docs/v3.md` (revised blueprint). Implements the
> modules that map to Gemma E2B's actual capabilities (text-only
> modules via on-device model) plus cloud-vision where the device
> model can't help.

**Status:** planning → execution
**Branch:** `main`
**Parent docs:** `docs/v3.md` (source blueprint), `docs/AI-MAP-FEATURES.md`

---

## TL;DR — five modules, two delivery paths

| Module | v3 ref | AI path | Offline? | Reuses |
|--------|--------|---------|----------|--------|
| AI Family Disaster Planner | Module 4 | on-device Gemma | ✅ | Family profile (new) |
| AI Emergency Kit Generator | Module 5 | on-device Gemma | ✅ | Planner profile |
| AI Risk Assessment | Module 6 | on-device Gemma | ✅ | Planner profile |
| AI Damage Scanner | Module 2/7 | cloud Gemini vision | ❌ online | CloudAiService |
| AI Situation Summary | Module 8 | on-device Gemma | ✅ | Chat/SOS history |

**Constraint:** Gemma 4 E2B `.litertlm` has no vision. Modules 2/7
route through `CloudAiService` (Gemini API) which has vision. All
text-only modules run on-device through `modelManager`.

---

## Module A — AI Family Disaster Planner (highest impact)

**User story.** User fills a structured form: family size, children
count, elderly count, medical conditions, home type (tin/tin-shed/
pucka/apartment), floor number, nearby river/coast, pets. Gemma
generates a personalized disaster plan: evacuation steps, preparation
timeline, special-needs notes, emergency contacts.

**New files:**
- `lib/features/planner/family_profile.dart` — pure-Dart model +
  SharedPreferences persistence (extends the existing `user_*` keys
  pattern with `family_*` keys). The structured questionnaire data.
- `lib/features/planner/planner_prompt_builder.dart` — pure-Dart
  prompt builder. Takes `FamilyProfile` → returns a Bangla instruction
  prompt. Unit-tested.
- `lib/features/planner/planner_service.dart` — thin service that
  calls `modelManager.generate()` with the prompt, falls back to a
  deterministic checklist on failure.
- `lib/features/planner/planner_screen.dart` — UI: questionnaire form
  → "তৈরি করুন" button → loading → rendered plan.

**Wiring:** new route `AppRoutes.planner` → home screen card.

---

## Module B — AI Emergency Kit Generator

**User story.** Reads the family profile from Module A → Gemma
generates a customized supply list with quantities (baby formula,
insulin, pet food, blankets, water litres).

**New files:**
- `lib/features/planner/kit_prompt_builder.dart` — pure-Dart prompt
  builder. Takes `FamilyProfile` → returns a kit-generation prompt.
- `lib/features/planner/kit_screen.dart` — UI: "কিট তৈরি করুন"
  button → loading → rendered checklist with quantity column.

**Wiring:** new route `AppRoutes.kit` → home screen card.

---

## Module C — AI Risk Assessment

**User story.** Structured questionnaire: house material, flood
history, elevation, nearby water bodies. Gemma computes a risk score
(1-10) + explanation + improvement suggestions.

**New files:**
- `lib/features/planner/risk_prompt_builder.dart` — pure-Dart prompt
  builder. Takes `RiskInputs` → returns a risk-assessment prompt.
- `lib/features/planner/risk_screen.dart` — UI: questionnaire →
  "ঝুঁকি মূল্যায়ন করুন" button → risk score gauge + explanation.

**Wiring:** new route `AppRoutes.risk` → home screen card.

---

## Module D — AI Damage Scanner (cloud vision)

**User story.** User takes a photo (or picks from gallery) → cloud
Gemini analyzes the image → returns damage type (flood/fire/collapse/
blocked road), severity (low/medium/high/critical), and a
recommendation.

**New files:**
- `lib/features/damage_scanner/damage_scan_service.dart` — calls
  `CloudAiService` with the image as inline_data (base64). Parses the
  structured response. Falls back to "please connect to internet"
  when offline.
- `lib/features/damage_scanner/damage_scan_screen.dart` — UI: camera
  capture + gallery pick → loading → result card (type + severity
  badge + recommendation).

**Wiring:** new route `AppRoutes.damageScanner` → home screen card.

**Constraint:** requires `GEMINI_API_KEY` via `--dart-define` and
internet. Shows a clear "needs internet" gate when unavailable.

---

## Module E — AI Situation Summary

**User story.** Aggregates recent chat queries + SOS reports from the
session → Gemma summarizes the current situation: most common
incidents, highest-priority areas, recommended actions.

**New files:**
- `lib/features/intelligence/situation_summary_service.dart` — pure-
  Dart service that collects recent reports + builds a summarization
  prompt.
- `lib/features/intelligence/situation_summary_screen.dart` — UI:
  "পরিস্থিতি সারাংশ" button → loading → rendered summary.

**Wiring:** new route `AppRoutes.situationSummary` → home screen card.

---

## Execution order

Per round-based-execution: pure-logic first, shared data model first.

1. **R1** — Family profile model + persistence + tests (pure Dart,
   blocks Modules A/B/C).
2. **R2** — Module A: planner prompt builder + planner service + tests.
3. **R3** — Module A: planner screen + route + home card.
4. **R4** — Module B: kit prompt builder + screen + tests.
5. **R5** — Module C: risk prompt builder + screen + tests.
6. **R6** — Module D: damage scan service + tests.
7. **R7** — Module D: damage scan screen + route + home card.
8. **R8** — Module E: situation summary service + screen + tests.
9. **R9** — Closing wiring check: grep all new public APIs, confirm
   each is called from a non-test file.
10. **R10** — Upgrade summary doc.

Each round = one commit. `flutter analyze` + `flutter test` between
every round. TDD on the pure-Dart prompt builders (the testable core).

---

## Hard constraints (carry-overs)

- All text-only AI runs through `modelManager` (on-device) with
  deterministic fallbacks. No feature shows a blank result.
- Cloud-vision (Module D) gates on connectivity + API key. Shows a
  clear offline message, never a spinner that can't complete.
- Bangla numerals (০-৯) and danda (।) in all user-facing strings.
- No analytics. Family profiles, photos, queries never leave the
  device (except the cloud-vision image, which is the explicit user
  action).
- Family profile persistence reuses the SharedPreferences `user_*`
  key pattern (consistency with existing profile_screen.dart).

---

*Each round below references back to its module.*
