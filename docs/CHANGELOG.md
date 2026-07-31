# Shongjog — Changelog

> **Internal team-facing document.** Hackathon-progress changelog. We use this to keep a
> running list of what's been built, what's been changed, and what was learned — so the
> team can scan it before any "what's the current state?" conversation.

Format follows [Keep a Changelog](https://keepachangelog.com). Each release groups the
work completed during a build phase or significant milestone.

---

## [Unreleased] — Docs, license & submission assets

### Added

- **`LICENSE`** — MIT license file added (README §License updated).
- **`docs/kaggle-writeup.md`** — full hackathon submission writeup (title, subtitle, Gemma 4 integration, 13 endpoints, mesh voice calls, privacy).
- **`docs/kaggle-thumbnail.png`** — 560×280 submission thumbnail (সংযোগ + SHONGJOG, Gemma badge).
- **`docs/screenshots/`** — 28 app screenshots added to the README as a gallery grid.
- **Splash screen** — dark-theme breathing splash + streamlined startup gate (`feat(splash)`).
- **Inline family form** + shared form widgets for the AI kit generator (`feat(kit)`).
- **Shelter locate-me** button, district filter, Dhaka default fallback (`feat(shelter)`).

### Fixed

- **Scanner** — camera permission flow, pre-flight checks, Android photo picker (`fix(scanner)`).
- **Voice STT** — locale resolution, failure classification, partial-transcript surfacing (`fix(voice)`).
- **Theme** — hardcoded ocean colors replaced with theme-aware `colorScheme.primary` (`fix(ui)`).

### Changed

- **Bangla spelling corrected** to `সংযোগ` across active docs (`CONTRIBUTING.md`, `design.md`, `kaggle-writeup.md`).
- **`CONTRIBUTING.md`** — test count (878), bilingual red-line, Firestore key-delivery pointer, corrected file paths.
- **`docs/README.md`** — rebuilt index to reflect current flat `docs/` structure.
- **`PROJECT-STATUS.md`** + **`architecture.md`** — refreshed stale metrics (tests, corpus, shelters, cards, model size) and added source-of-truth banners to the README / kaggle-writeup.

---

## [0.8.0] — 2026-07-31 — v3: AI modules, live endpoints, mesh voice, bilingual

### Added — AI (7 modules, 6 on-device)

- **AI Family Disaster Planner**, **Emergency Kit Generator**, **Risk Assessment**, **Situation Summary**, **Shelter Brief**, **Safety Re-Ranking** — all Gemma 4 on-device, each with a deterministic fallback.
- **AI Damage Scanner** — photo → damage type + severity via Gemini vision (online).
- **TIER 1–4 generation chain** — on-device Gemma first (even online), then cloud, then corpus, then "call 999".

### Added — Online intelligence (13 endpoints, 11 key-less)

- GDACS, NASA EONET, USGS, Open-Meteo (weather + marine + air quality), OSRM routing, Nominatim + Overpass search, OSM tiles, Hugging Face model delivery. All fail soft.

### Added — Mesh & communications

- **Full-duplex voice calls** over Nearby Connections / Wi-Fi Direct (custom `AudioTrackPlugin`, 8 kHz PCM).
- **GMS-free Wi-Fi Direct transport** (`flutter_p2p_connection`) behind one `MeshTransport` interface.
- Multi-hop SOS relay (LRU dedup, 5-hop cap, 1h TTL), "I'm safe" beacon, media/voice-note payloads.

### Added — Platform

- **Bilingual locale** — Bangla-first with full English (834 EN / 888 BN strings), Bangla numerals + punctuation.
- **Coordinator panel** — Firestore-backed live safe/danger counts, danger list, campaigns, broadcasts.
- **Gemma 4 E4B** auto-selection on high-RAM devices; `.litertlm` runtime via `flutter_gemma_litertlm`.
- **Firestore-delivered cloud key** — no key compiled into the APK; revocable without a release.

### Tests

- **878 pass, 1 skipped** across 100 files (up from 91). Coverage now includes WCAG contrast, 1.5× text scaling, mesh path-traversal, Firestore ACLs, tier-fallback chain.

---

## [0.5.0] — 2026-07-14 — Pre-demo polish

### Added

- **ModelManager singleton** (`modelManager`) — app-wide reactive state, 206-vs-200
  resume support, `markReadyIfOnDisk()` method.
- **ChatStore** — JSON-based message persistence (load/save/clear), survives app
  restart.
- **OnboardingScreen** — 3-page first-run flow (welcome → permissions → model
  download hint), gated by `pref_has_onboarded`.
- **TypewriterText** — Character-by-character reveal for AI responses, with cursor and
  `animate` flag.
- **Shelter list view toggle** — SegmentedButton map/list in `shelter_map_screen.dart`,
  distance-ranked list view offline-friendly.
- **Settings rework** — `ModelDownloadCard` (reactive to ModelManager), voice prefs,
  clear-cache wired to `ChatStore.clear()`.
- **ChatScreen rework** — Voice prefs consumed, ChatStore persistence, error bubble
  with retry + 999 call button, suggestion chips in empty state.
- **Emergency contacts screen** — Add/list/call local emergency contacts.
- **Mesh comm** (Maruf) — nearby_connections P2P, radar screen.
- **Home screen** — Bento grid with feature tiles.
- **SoundService** — Chime + knock gated by `pref_sound_enabled`, 5s debounce.
- **HapticService** — Codified in `docs/design.md` §15.2 (uses platform `HapticFeedback`).
- **Emergency sheet bug fixes** — Single GestureDetector (removed duplicate), real GPS
  via Geolocator, reads user name/phone from prefs.

### Fixed

- **Emergency slide knob**: duplicate overlapping GestureDetectors replaced with single
  drag handler + smooth snap-back animation.
- **SOS SMS**: hardcoded GPS (0,0) replaced with real Geolocator coordinates + user
  name/phone from prefs.
- **ModelManager resume**: 206-vs-200 status check prevents file corruption when
  server ignores Range header.
- **Settings clear-cache**: was a no-op; now calls `ChatStore.clear()` and shows
  confirmation.
- **Voice prefs**: stored but never read; now consumed by ChatScreen and Settings UI.

### Tests

- New test files: `chat_store_test`, `typewriter_text_test`, `onboarding_screen_test`,
  `emergency_sheet_test`, `settings_screen_test`.
- Test count: **91 pass, 1 skipped** (up from 46).
- `flutter analyze` clean — 0 issues.

---

## [0.4.0] — 2026-07-12 — Cloud AI + Mesh + Emergency Contacts

### Added

- `lib/features/cloud_ai/cloud_ai_service.dart` — Gemini 2.5-flash / 2.0-flash-lite (was the fictional 3.5/3.1 IDs). Real model IDs verified against current Google GenAI line.
  fallback chain when online.
- `lib/features/mesh_comm/mesh_service.dart` + `mesh_radar_screen.dart` — peer discovery
  via `nearby_connections`.
- `lib/features/contacts/` — local emergency contacts (add/list/call).
- Connectivity-aware cached tile provider (online tiles / offline styled background).

### Changed

- `ChatRepository` now orchestrates: keyword retrieval → Gemma session OR Cloud AI →
  canned fallback.
- `shelter_map_screen.dart` updated for connectivity-aware tile caching.

---

## [0.3.0] — 2026-07-10 — Gemma integration

### Added

- `lib/core/model_manager.dart` — downloads + loads Gemma `.task` files via
  `flutter_gemma`.
- `lib/features/chat/chat_repository.dart` — RAG + Gemma call orchestration.
- `lib/rag/prompt_builder.dart` — system prompt + retrieved context assembly.
- `lib/rag/types.dart` — Chunk, RetrievalHit value objects.

### Changed

- `lib/features/chat/chat_screen.dart` — full wired chat with TTS, mic button,
  loading states.
- `lib/features/voice/tts_service.dart` — flutter_tts integration (`bn-BD`, fallback
  to `bn-IN`).

### Skipped

- `lib/rag/embedder.dart` — EmbeddingGemma on-device embedder deferred (no public API
  in `flutter_gemma 0.5.0`).
- `KeywordRetriever` substituted as the primary retrieval path (BM25-lite + cosine
  hybrid over pre-computed vectors).

---

## [0.2.0] — 2026-07-08 — KB pipeline + retrieval

### Added

- `tools/build_kb.py` — produces `assets/kb/{corpus.json, vectors.bin, meta.json}`
  using `paraphrase-multilingual-mpnet-base-v2`.
- `tools/verify_kb.py` — 7 queries × expected topic spot-check.
- `tools/corpus.json` — 23 Bangla chunks across 10 topics.
- `lib/knowledge/kb_loader.dart` — loads corpus + vectors from assets.
- `lib/rag/retriever.dart` — `BruteForceRetriever` (cosine top-k).
- `lib/rag/keyword_retriever.dart` — primary offline retrieval.

### Verified

- All 7 `verify_kb.py` queries return the expected topic.
- Vectors: `[N=23, D=768]`, float32, row-major.

---

## [0.1.0] — 2026-07-05 — Foundation

### Added

- Project scaffold (`pubspec.yaml`, `android/app/build.gradle.kts`).
- `arm64-v8a` ABI filter.
- Bangla theme + 3-way system/light/dark toggle + ThemeController.
- 4-tab bottom navigation in `MainShell`.
- `quick_cards_screen.dart` with 8 emergency cards (ORS, water, snakebite, diarrhea, shelter, bleeding, fever, drowning).
- `quick_cards_screen_test.dart` (now 7 widget test files total).

### Verified

- `flutter pub get` + `flutter analyze` clean from Day 1.

---

## Older phases — pre-hackathon prep

- `docs/prd.md`, `docs/architecture.md`, `docs/design.md`, `docs/guides/corpus.md` —
  all written during 1-2 day planning sprint.
- Git pitches, model selection notes, initial corpus draft.

---

## Versioning

We use semantic-ish versioning during the hackathon:

- **0.X.Y** — feature version X, fix Y within
- Pre-1.0 means "may break between days, doesn't matter"
- Once BDRCS / MoDMR review starts (post-hackathon), bump to **1.0.0** and freeze

---

## Commit conventions used in this codebase

```
feat(<scope>): <imperative summary>
fix(<scope>): <imperative summary>
test(<scope>): <imperative summary>
docs(<scope>): <imperative summary>
build(<scope>): <imperative summary>
```

Scopes in this repo include: `chat`, `voice`, `shelter`, `emergency`, `kb`, `rag`,
`settings`, `mesh`, `contacts`, `audio`, `home`, `about`, `onboarding`, `app`,
`core`.

See `CONTRIBUTING.md` for the full commit / PR / branch conventions.
