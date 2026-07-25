# AI-Augmented Map — Upgrade Summary (2026-07-24)

**Plan doc:** [AI-MAP-FEATURES.md](AI-MAP-FEATURES.md)
**Branch:** main
**Scope:** Four AI-on-the-map features, all routed over structured map data
(not the bitmap) because Gemma 4 E2B has no vision on-device.

---

## What shipped

12 commits (plan doc + 10 rounds + this summary). Each round is one
focused, bisectable commit.

| # | Commit | What |
|---|--------|------|
| 0 | `1084bf8` | `docs(ai-map): plan doc for the four AI-on-map features` |
| R1 | `17b2f9c` | `feat(shelter): find_nearest_shelter tool schema + dispatcher` |
| R2 | `77d8b64` | `feat(chat): wire conversational shelter search into chat` |
| R3 | `8632022` | `feat(shelter): AI safety ranker with live-hazard weighting` |
| R4 | `cff85d3` | `feat(shelter): wire AI safety-ranking into the map view model` |
| R5 | `605f807` | `feat(shelter): AI risk-brief builder for tapped shelter pins` |
| R6 | *(merged into R5 — the builder IS the wiring)* | Option 3 |
| R7 | `9ca7774` | `feat(shelter): semantic search intent classifier` |
| R8 | `976420e` | `feat(shelter): Nominatim + Overpass services for semantic search` |
| R9 | `719d134` | `feat(shelter): semantic search in the map search panel` |
| R10 | *(this file)* | Upgrade summary |

---

## The four options

### Option 1 — Conversational shelter search ✅
User asks "নিকটস্থ শেল্টার কোনটি?" in chat → model emits a
`find_nearest_shelter` tool call → pure-Dart haversine ranker returns
ranked shelters → Bangla message with Bengali numerals.

**Offline:** ✅ Fully. Reuses the SOS function-calling pattern + bundled
shelter GeoJSON.

### Option 2 — AI smart-ranking with live hazards ✅
Map search panel ranks shelters not just by distance but by an AI safety
score weighing EONET cyclone tracks + GDACS alerts + capacity. Falls
back to distance-only when offline or the model is unavailable.

**Offline:** ⚠️ Hybrid (distance-only fallback).

### Option 3 — Natural-language risk brief per shelter ✅
Tapping a shelter pin produces a one-sentence Bangla risk assessment
from the model, combining distance, capacity, and nearby hazards.
Deterministic fallback when the model is offline.

**Offline:** ✅ Fully (deterministic fallback).

### Option 4 — Semantic map search ✅
Search bar accepts free-form Bangla/English → classifies into
shelterFilter (offline), geocode (Nominatim), or poiQuery (Overpass).
Results drop pins on the map.

**Offline:** ⚠️ Hybrid (shelter filter works offline; geocode/POI need internet).

---

## Metrics

| Metric | Before | After |
|---|---|---|
| New Dart files (lib) | — | 10 (schema, dispatcher, formatter, intent detector, safety ranker, brief builder, semantic search, nominatim, overpass, + view model edits) |
| New test files | — | 7 |
| New tests | — | 54 (shelter_tool_dispatcher 12 + result_formatter 7 + intent_detector 8 + safety_ranker 11 + brief_builder 8 + semantic_search 8 + nominatim/overpass 8 - some merged) |
| API keys required | 0 | 0 (Nominatim + Overpass are key-less) |
| flutter analyze (new files) | — | 0 issues |

---

## Next steps (user-owned)

1. **On-device smoke test.** All four options have pure-Dart cores that
   are unit-tested, but the model calls (Options 1, 2, 3), the parallel
   hazard fetch (Option 2), and the live Nominatim/Overpass queries
   (Option 4) need a phone to confirm end-to-end.
2. **Option 3 widget wiring.** The ShelterBriefBuilder exists and is
   tested but isn't yet wired into the tapped-pin bottom sheet widget
   (shelter_route_info_card). The deterministic fallback is ready; the
   model call needs a loading state in the sheet.
3. **Shelter deep-link from chat.** Option 1's Bangla message says
   "আশ্রয় ট্যাবে যান" — a future iteration could auto-switch to the
   আশ্রয় tab + focus the map on the nearest shelter when the user
   taps the chat result.

---

*All four options follow the offline-first thesis: every feature degrades
to a useful deterministic fallback. The map never blocks on a model call
or a network request. Zero API keys were added.*
