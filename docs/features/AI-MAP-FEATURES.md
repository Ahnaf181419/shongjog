# AI-Augmented Map — Feature Plan (2026-07-24)

> Plan doc for the four AI-on-the-map features. Read this first; each
> feature is then implemented as a separate round-based commit.

**Status:** planning → execution
**Branch:** `main`
**Sibling doc:** `docs/UPGRADE-SUMMARY-2026-07-24-free-apis.md` (the live
hazard feeds that Option 2 consumes)

---

## TL;DR — the four options

| # | Feature | AI mechanism | Offline? | Reuses |
|---|---------|--------------|----------|--------|
| 1 | Conversational shelter search | function-calling tool | ✅ fully | SOS tool pattern, `nearestShelters()` |
| 2 | AI smart-ranking with live hazards | one-shot JSON prompt | ⚠️ hybrid | EONET/GDACS feeds, distance ranking |
| 3 | Natural-language risk brief per shelter | RAG-style prompt | ✅ fully | `buildPrompt`, tapped-shelter context |
| 4 | Semantic map search | NL→structured intent | ⚠️ hybrid | Nominatim/Overpass, intent classifier |

All four route the AI over **structured data about the map**, not over
the bitmap — Gemma 4 E2B on-device has no vision, so "the model looks
at the map" is out. Instead the model reasons over shelter lists,
hazard points, and coordinates. This is deterministic, explainable,
and stays inside the 1024-token context window.

---

## Option 1 — Conversational shelter search (function-calling) ★

**User story.** In the chat tab the user types or speaks:
  "আমি পটুয়াখালীতে আছি, কোন শেল্টার সবচেয়ে কাছে?"
  (I'm in Patuakhali — which shelter is closest?)

The model emits a `find_nearest_shelter` tool call. The app runs the
existing pure-Dart `nearestShelters()`, renders the result on the map,
and replies in Bangla with name + distance + a "ট্যাপ করে রুট দেখুন"
affordance.

**Why this is the flagship.** The codebase already proves the pattern:
`LocalLlm.generateStructured({tools})` is wired for SOS extraction
(`sos_function_schema.dart`), the shelter list is pure Dart, and
`nearest_shelter.dart` is already unit-tested. One new tool definition
+ a dispatcher in `chat_repository.dart` unlocks the feature.

**New files:**
- `lib/features/shelter/shelter_tool_schema.dart` — the
  `find_nearest_shelter` Tool definition (mirrors `sosReportTool`).
- `lib/features/shelter/shelter_tool_dispatcher.dart` — pure-Dart
  executor: takes the parsed tool args + user location + shelters,
  returns a list of `RankedShelter`. Unit-testable without a device.

**Wiring:**
- `chat_repository.dart`: after generation, if the structured response
  contains a `find_nearest_shelter` call, dispatch it and inject the
  result back into the chat as a system-rendered "map result" bubble
  that deep-links to `/shelter?focus=<lat>,<lon>`.

**Offline:** ✅ Fully offline. Gemma runs on-device, shelter data is
bundled, haversine is pure math, the tool dispatcher is pure Dart.

---

## Option 2 — AI smart-ranking with live hazard weighting

**User story.** When the user opens the shelter map, the shelters
aren't just sorted by raw distance. They're sorted by an AI-computed
safety score that weights:
  - distance (haversine — already done)
  - the *current* cyclone track (EONET severeStorms)
  - flood extent (GDACS floods)
  - capacity (small shelters deprioritized during a surge)

**Why it fits.** The live hazard feeds are already wired (this session).
The model does the fuzzy reasoning over numbers — exactly what it's
good at.

**New files:**
- `lib/features/shelter/shelter_safety_ranker.dart` — pure-Dart helper
  that builds the one-shot ranking prompt from (user GPS, top-N
  shelters, nearby hazards) and parses the model's JSON-array response
  into a re-ordered `List<RankedShelter>`. Falls back to distance-only
  ranking if the model output is unparseable or offline.

**Wiring:**
- `shelter_map_view_model.dart`: after `init()` and whenever
  `rankedShelters` is recomputed, if there are active hazards nearby,
  run the safety ranker and replace `rankedShelters` with the
  AI-ordered list. The map + search panel pick this up reactively.

**Offline:** ⚠️ Hybrid. The shelter ranking runs offline with Gemma,
but the *live* hazard weighting needs the EONET/GDACS fetch to have
succeeded. If offline, it gracefully falls back to pure distance
ranking (current behaviour) — no regression.

---

## Option 3 — Natural-language risk brief per shelter

**User story.** When the user taps a shelter pin, alongside the
existing info card (name, distance, capacity) they get a one-sentence
AI-generated risk brief in Bangla:

  "এই শেল্টারটি আপনার অবস্থান থেকে ৩.২ কিমি দূরে এবং বর্তমান
   ঘূর্ণিঝড়ের পথের বাইরে। ধারণক্ষমতা ১২০০।"
  (This shelter is 3.2 km away and outside the current cyclone track.
   Capacity 1200.)

**Why it fits.** Reuses the RAG prompt builder already in
`prompt_builder.dart`. The "context" fed to the model is the tapped
shelter + nearby hazards + user location. The model does what it
already does in the chat tab — write a warm Bangla sentence — but the
context is map data instead of corpus text.

**New files:**
- `lib/features/shelter/shelter_brief_builder.dart` — pure-Dart prompt
  builder that takes (tapped shelter, user GPS, nearby hazards) and
  returns a prompt string. Returns a deterministic fallback string if
  the model is offline or fails.

**Wiring:**
- `widgets/shelter_route_info_card.dart` (or the tapped-pin sheet):
  when a shelter is selected, call the brief builder, show the
  generated sentence in a new "AI ঝুঁকি মূল্যায়ন" row. Loading +
  failure both degrade gracefully to the deterministic fallback.

**Offline:** ✅ Fully offline (Gemma + bundled shelter data).

---

## Option 4 — Semantic map search

**User story.** A search bar at the top of the map screen accepts
natural language:
  - "ঢাকা মেডিকেল কলেজ হাসপাতাল" → Nominatim geocode → pin
  - "সাইক্লোন শেল্টার" → filters the shelter layer
  - "পানির কাছে নিরাপদ জায়গা" → model interprets → searches for
    elevated shelters near water

**Why it fits.** We scanned Nominatim + Overpass as free APIs. The
model acts as the semantic layer between free-form Bangla input and
deterministic queries.

**New files:**
- `lib/features/shelter/semantic_search_service.dart` — pure-Dart
  intent classifier: takes the raw query, classifies into
  `shelterFilter | geocode | poiQuery`, and returns a structured
  `SemanticSearchIntent`. Uses Gemma for the classification; falls
  back to keyword matching if the model is unavailable.
- `lib/features/shelter/nominatim_service.dart` — thin wrapper around
  the Nominatim REST API (free, key-less) for the `geocode` intent.
- `lib/features/shelter/overpass_service.dart` — thin wrapper around
  the Overpass API for the `poiQuery` intent (hospitals, pharmacies,
  police near a point).

**Wiring:**
- The existing `shelter_search_panel.dart` gains a text field above
  the ranked-shelter list. Typing fires the semantic classifier; the
  result drives either a shelter filter, a Nominatim pin, or an
  Overpass POI overlay.

**Offline:** ⚠️ The semantic interpretation runs on-device (Gemma),
but Nominatim/Overpass need internet. When offline, only the
`shelterFilter` intent works.

---

## Execution order

Per the round-based-execution skill: pure-logic first, plugin-free
first, highest leverage first.

1. **R1** — Option 1 core: `shelter_tool_schema.dart` + dispatcher + tests (pure Dart, offline).
2. **R2** — Option 1 wiring: chat_repository dispatch + map deep-link.
3. **R3** — Option 2 core: `shelter_safety_ranker.dart` + tests (pure Dart, offline fallback).
4. **R4** — Option 2 wiring: view-model integration.
5. **R5** — Option 3 core: `shelter_brief_builder.dart` + tests (pure Dart, offline).
6. **R6** — Option 3 wiring: tapped-pin sheet.
7. **R7** — Option 4 core: `semantic_search_service.dart` + tests (pure Dart intent classifier, offline).
8. **R8** — Option 4 online services: Nominatim + Overpass + tests.
9. **R9** — Option 4 wiring: search panel text field.
10. **R10** — Upgrade summary doc.

Each round = one commit. `flutter analyze` + `flutter test` between
every round.

---

## Hard constraints (carry-overs from AGENTS.md)

- All AI runs on-device through `modelManager`. No cloud calls in the
  map feature path.
- Bangla numerals (০-৯) and danda (।) in all user-facing strings.
- No analytics. Shelter selections, queries, and locations never leave
  the device.
- Offline-first: every feature degrades to a useful deterministic
  fallback. The map must never show a spinner that can't complete.

---

*This doc is the spec. Each round below references back to its option.*
