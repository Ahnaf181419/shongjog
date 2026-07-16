# Shongjog — Final Status & Handoff Document

> **One-shot status report.** Snapshot of everything done, everything still blocking on
> hardware, and explicit pointers to every other doc in the project. Read this first when
> picking up where someone left off — it's the single entry point that tells you the
> whole state.

**Date of this report:** 2026-07-16 (updated post-hackathon-feature-build)  
**Status:** 🟢 Code-complete + 5 demo features shipped. Tests green (246 pass, 1 skip). `flutter analyze` clean.  
**Branch:** `ahnaf` (10 commits ahead of `main`). Merge to `main` via PR after device testing.  
**Demo readiness:** Phase 0 (device spikes) and Phase 5 (live demo) are the only
remaining work, both requiring a physical arm64-v8a Android device.

---

## TL;DR

| Metric | Value |
|---|---|
| Tests passing | 246 (1 skipped) |
| `flutter analyze` | 0 issues |
| Dart files in `lib/` | 81 |
| Lines of Dart in `lib/` | ~9,656 |
| Lines of test code | ~3,952 |
| Bangla corpus chunks | 23 (10 topics) |
| APK size (release) | 126.5 MB (arm64-v8a only, no model bundled) |
| Model file | ~1.87 GB (gemma-4-E2B-it.litertlm, downloaded per-device) |
| Min Android ABI | arm64-v8a |
| Commits on `ahnaf` | 10 (mesh relay, triage wizard, safe beacon, directory, demo seeder, fixes) |

---

## What's working (no device required)

Everything below runs on the Android emulator and in `flutter test`:

### Core UX
- **App launch + onboarding gate.** First-run shows 3-page flow
  (`welcome → permissions → model download hint`).
- **Bottom navigation.** 4 tabs: হোম / এআই / কার্ড / আশ্রয়.
- **3-way theme toggle.** System / Light / Dark, persisted via `ThemeController`.
- **Home screen.** Bento grid of feature tiles that link to tabs.

### Knowledge base (offline)
- **23 emergency chunks** authored, reviewed, embedded via `tools/build_kb.py`.
- **Brute-force cosine retriever** (`BruteForceRetriever` over mpnet 768-dim vectors).
- **Keyword retriever** (BM25-lite + cosine hybrid — primary offline path).
- **Prompt builder** with safety guardrails (no diagnosis / prescription; 999 reminder
  auto-attached; "I don't know" fallback for low-confidence hits).
- **All 7 verification queries** pass (`tools/verify_kb.py` exit code 0).

### Static UI
- **8 expandable quick cards** (ORS, water purification, snakebite, diarrhea, cyclone
  shelter, bleeding control, fever, drowning). Works without the model.
- **Onboarding screen** (welcome / permissions / model download).
- **Settings screen** with model download card, voice toggles, clear-cache.
- **About page** with WHO/BDRCS/MoDMR/BMD/CDC/IFRC source attribution.
- **Emergency contacts** (add/list/call local contacts).

### AI / chat
- **ChatStore** (JSON persistence) — messages survive app restart.
- **Typewriter text** reveal animation for AI responses.
- **Error UX** — typed error bubble with retry + 999 call buttons.
- **Suggestion chips** in empty chat state.
- **Voice prefs** consumed by ChatScreen and Settings:
  - `pref_auto_read` → auto TTS after render
  - `pref_voice_input` → blocks mic when off
- **Cloud AI fallback** chain (Gemini 2.5-flash → 2.0-flash-lite) when online.

### Emergency
- **Slide-to-confirm dialer** for 999 — single GestureDetector, real GPS, real user
  name/phone from prefs.
- **SOS SMS template** with location-encoded body and Google Maps URL.
- **Slide knob haptic feedback** (50%, 90%, confirm).

### Shelter
- **Connectivity-aware tiles.** Online = OSM tiles; offline = styled background +
  shelter markers.
- **Map/list toggle.** SegmentedButton: list shows distance-ranked shelters.
- **Cached tile provider** with `ConnectivityHelper`.

### Mesh communication
- **`nearby_connections` peer-to-peer** text messaging (P2P_CLUSTER).
- **Radar screen** for peer discovery.
- **Multi-hop SOS relay** (`SosPayload` + `SosRelayEngine` + `SosRelayListener`).
  De-dupe by UUID, TTL (1h), max 5 hops, loop guard. Hop-count chip on
  received SOS message bubbles (`↻ N হপ`).
- **`MeshService.ensureRelayEngine()`** wires the relay on app startup;
  `_onPayloadReceived` routes incoming bytes through the listener.
- **`broadcastSos()`** helper for the safe-beacon screen.

### Triage wizard (LLM-free, deterministic)
- **Pure-Dart decision tree** (`lib/features/triage/decision_tree.dart`) —
  5 yes/no questions, 5 terminal routes: cpr, bleeding, drowning,
  snakebite, escalation999. Cannot hallucinate.
- **Full-screen wizard UI** with giant হ্যাঁ/না buttons, Bengali
  numerals (প্রশ্ন ১ / ৫), terminal node shows first-aid title +
  subtitle + "কার্ড দেখুন" and "৯৯৯ কল করুন" CTAs.
- **Home-screen tile** (red accent) routes to `/triage`.

### Safe beacon ("I'm safe" check-in)
- **`SafeBeaconPayload`** (reuses SosPayload wire format with `state=safe`).
- **`SmsQueue`** (pure-Dart): enqueue/drain with head-retention on failure.
- **`SafeBeaconScreen`** — one giant Bangla button. On tap: reads GPS via
  `Geolocator`, broadcasts beacon over mesh, queues SMS for every emergency
  contact, drains on connectivity flip. All counts in Bengali numerals.
- **Home-screen tile** (teal accent) routes to `/safe-beacon`.

### Offline emergency directory
- **22-entry JSON asset** (`assets/emergency/directory.json`) — national
  hotlines (999, 16163, 333, 16263, 966, 109, 16239) + division hospitals
  + Cox's Bazar specifics + coast guard + tourist police.
- **`DirectoryScreen`** with division FilterChips, tap-to-call via
  `url_launcher` `tel:` URI, Bengali-digit phone display.
- **`@visibleForTesting` seam** (`debugSetEntries`) for widget tests.
- **Home-screen tile** routes to `/directory`.

### First-run demo seeder
- **`DemoSeeder`** (pure-Dart) returns 3 pre-answered Q&As (ORS recipe,
  shelter map, snakebite) — matches existing KB content.
- **ChatScreen** seeds on first run when store is empty AND
  `pref_demo_seeded_v1` flag is unset. Persists seed; idempotent.

### Cross-cutting
- **`HapticService`** (`lib/core/haptics.dart`) codified per design spec — 6 events.
- **`SoundService`** (`lib/features/audio/sound_service.dart`) — chime + knock,
  5-second debounce, gated by prefs.
- **Test suite** — 246 pass, 1 skip, organized into unit/widget/integration.
  36 new tests added on the `ahnaf` branch across 7 new test files.

---

## What's blocked (needs a physical arm64-v8a Android device)

### Phase 0.1 — Gemma E2B spike

**Why it matters:** Determines whether the whole product thesis holds. If Gemma
doesn't load or takes >25s cold-start, we pivot to Gemma 3 1B.

**What to do:** Follow `docs/spike-results.md` §Spike A. Push the `.task` file via
adb, run the spike app, record timings.

**Decision criteria:** 🟢 ≤15s cold start + ≥8 tok/s → ship. 🟡 15-25s → document.
🔴 OOM / never loads → pivot to Gemma 3 1B.

### Phase 0.2 — Vosk Bangla WER spike

**Why it matters:** Determines whether voice input is genuinely offline or whether
we accept "network-dependent speech_to_text as fallback".

**What to do:** Follow `docs/spike-results.md` §Spike B. Bundle the Vosk Bangla
model, transcribe 10 hand-authored utterances, compute WER.

**Decision criteria:** 🟢 avg WER < 0.3 → ship. 🟡 0.3-0.5 → hybrid. 🔴 ≥ 0.5 → typed-
input only in demo.

**Note:** The `vosk_flutter` plugin has a `compileSdk` issue with AGP 9.x —
documented in `docs/POST-HACKATHON.md` §1.1. May require a plugin fork or FFI
workaround before the spike can run.

### Phase 5.1 — Airplane-mode E2E

**Why it matters:** The thesis claim is verified only by running the app with all
radios off. If a package silently leaks a request, this catches it.

**What to do:** Run all 5 demo scenarios with airplane mode ON. Record timings in
`docs/spike-results.md` §Phase 5.

### Phase 5.3 — 60s fallback demo video

**Why it matters:** Insurance against live-demo flakiness. Switch to video at first
sign of trouble.

**What to do:** Record `adb shell screenrecord` while walking through the 5
scenarios. Trim to 60s. Save as `docs/demo-fallback.mp4`. Transfer to demo phone.

---

## Remaining work (ahnaf branch — needs device testing + demo polish)

### Done on `ahnaf`, needs on-device verification
- [ ] **Multi-hop mesh SOS relay** — 3-phone test (Phone A broadcasts, B
      relays, C receives with hop-count chip). Unit-tested but Bluetooth
      pairing + real delivery can't be verified without hardware.
- [ ] **"I'm safe" beacon** — GPS capture + mesh broadcast + SMS composer
      open. All logic unit-tested; `Geolocator` + `url_launcher` dialogs
      are device-only.
- [ ] **Triage wizard** — walk every branch on device, verify Bengali
      numerals + terminal node CTAs render correctly under real fonts.
- [ ] **Offline directory** — tap-to-call opens dialer, division filter
      works, 22 entries display with Bengali-digit phones.
- [ ] **Demo seeder** — first launch shows 3 Q&A pairs in chat; second
      launch does NOT re-seed.
- [ ] **Merge `ahnaf` → `main`** via PR after device test.

### Deferred from HACKATHON-WIN-PLAN (not started)
| # | Feature | Effort | Why deferred |
|---|---|---|---|
| 3 | Offline MBTiles | 1 day | No tile source ready; map uses styled markers offline |
| 4 | Compass arrow | 0.5 day | `flutter_compass` not in pubspec |
| 5 | Cyclone disaster mode | 1 day | Needs weather spike on device |
| 7 | AI SOS composer | 1 day | SOS path must not require model; template is safe path |
| 8-10 | CPR metronome, ORS calc, torch SOS | 2h each | Triage wizard covers "LLM-free guidance" pitch |
| 12 | "Explain simply" button | 0.5 day | Time-boxed out |
| 13 | Preparedness plan generator | 1 day | Time-boxed out |
| 14 | Battery-aware mode | 3h | Time-boxed out |
| 15 | Elderly / low-literacy mode | 3h | Time-boxed out |

---

## What's still pending (medium-effort, not blocking demo)

| Item | Effort | Priority | Notes |
|---|---|---|---|
| Generate/source Bangladesh MBTiles | 1-2 days | P2 | Currently relying on online OSM with offline markers fallback |
| Replace Material icons with custom SVG set (`docs/design.md` §15.4) | 1 day per icon | P3 | 10 icons, hand-drawn to match Hind Siliguri stroke weight |
| Add Bengali conjunct fallback font (Noto Serif Bengali) per screen | 2h | P2 | Phase 5 QA gates which screens need it |
| Encrypted ChatStore persistence (`flutter_secure_storage`) | 3h | P2 | Post-demo privacy hard-line |
| On-demand permission requests instead of all-at-once | 2h | P2 | UX polish |
| Model manager race condition guard | 1h | P3 | Single-init lock |

---

## Files inventory (what exists, what it does)

### Code structure (`lib/`)

```
lib/
├── main.dart                          # ShongjogApp entry point
├── app/                               # 4 files: app.dart, main_shell.dart, theme.dart, router.dart
├── core/                              # 3 files: model_manager.dart (singleton), theme_controller.dart,
│                                     #           haptics.dart (codified per design.md §13.1)
├── features/                          # 25 files across 11 features
│   ├── audio/sound_service.dart       # chime + knock, gated prefs
│   ├── chat/                          # 6 files: chat_screen, chat_input, chat_repository,
│   │                                  #          chat_store (JSON persistence), message_bubble,
│   │                                  #          typewriter_text (char-by-char reveal)
│   ├── contacts/                      # 3 files: emergency contacts (add/list/call)
│   ├── cloud_ai/cloud_ai_service.dart # Gemini fallback chain
│   ├── emergency/                     # 3 files: emergency_sheet (slide-to-confirm),
│   │                                  #          emergency_actions, sos_sms_template
│   ├── home/home_screen.dart          # home tab bento grid
│   ├── mesh_comm/                     # 2 files: mesh_service, mesh_radar_screen
│   ├── onboarding/                    # 1 file: onboarding_screen
│   ├── quick_cards/                   # 2 files: cards_data, quick_cards_screen
│   ├── settings/settings_screen.dart  # model download card + voice prefs
│   ├── shelter/                       # 5 files: shelter_map (with list toggle),
│   │                                  #          cached_tile_provider (connectivity),
│   │                                  #          shelter_model, shelter_repository, nearest_shelter
│   └── voice/                         # 5 files: stt_provider (abstract),
│                                      #          speech_to_text_provider (online),
│                                      #          vosk_stt_provider (offline stub),
│                                      #          stt_service (auto-select), tts_service
├── rag/                               # 5 files: retriever (cosine), keyword_retriever (primary),
│                                     #          embedder (bypassed), prompt_builder, types
└── knowledge/                         # kb_loader: reads assets/kb/* at startup
```

### Tests (`test/`)

```
test/
├── unit/                              # 10 files: pure-Dart correctness
│   ├── model_manager_test.dart        # singleton + range-resume
│   ├── prompt_builder_test.dart
│   ├── chat_repository_test.dart
│   ├── retriever_test.dart
│   ├── keyword_retriever_test.dart
│   ├── chat_store_test.dart           # ChatMessage + JSON serialization + file lifecycle
│   ├── nearest_shelter_test.dart
│   ├── stt_provider_test.dart
│   ├── sos_sms_template_test.dart
│   └── haptic_service_test.dart       # 8 tests, all haptic events
└── widget/                            # 7 files: in-app UI
    ├── home_screen_test.dart
    ├── quick_cards_screen_test.dart
    ├── emergency_sheet_test.dart      # 4 tests, including single GestureDetector
    ├── settings_screen_test.dart      # 7 tests, including clear-cache dialog
    ├── typewriter_text_test.dart      # 4 tests for char-by-char reveal
    ├── onboarding_screen_test.dart    # 6 tests for 3-page flow
    └── widget_test.dart
```

### Integration tests (`integration_test/`)

```
integration_test/
└── demo_flow_test.dart                # 14 tests: full app navigation flow
                                       # Run on device: flutter test integration_test/demo_flow_test.dart
```

### Assets (`assets/`)

```
assets/
├── fonts/                             # 4 Hind Siliguri TTFs (Light/Regular/Medium/SemiBold)
├── kb/                                # 23 chunks × 768-dim vectors (~75 KB)
├── shelter/                           # cyclone_shelters.geojson
├── sound/                             # chime.wav (66 KB), knock.wav (13 KB)
└── vosk/                              # (empty — bundled when ready)
```

### Build pipeline (`tools/`)

```
tools/
├── build_kb.py                        # corpus → embedded vectors
├── verify_kb.py                       # 7-query retrieval spot-check
├── corpus.json                        # 23 Bangla chunks (authored by Sehab, reviewed)
├── requirements.txt                   # sentence-transformers, torch, numpy
├── README.md                          # corpus authoring guide
└── .venv/                             # Python 3 venv for build pipeline
```

### Documentation (`docs/`)

```
docs/
├── prd.md                             # Product requirements
├── architecture.md                    # Technical architecture, layers, data model
├── design.md                          # UX/UI design (principles, screens, anti-patterns)
├── implementation-plan.md             # Phase-by-phase build plan + live status table
├── team.md                            # Work division + decision log
├── corpus.md                          # Knowledge base policy + source whitelist
├── demo.md                            # Live demo script + Q&A
├── spike-results.md                   # Phase 0 + Phase 5 measurement log (TEMPLATE)
├── PRE-DEMO.md                        # Operational runbook (NEW)
└── POST-HACKATHON.md                  # Long-term roadmap + red lines (NEW)

/CHANGELOG.md                          # Hackathon-progress changelog (NEW)
/CONTRIBUTING.md                       # For future maintainers (NEW)
```

---

## Quick reference: most important files to read first

If you're new to this codebase (or returning after a break), read these in order:

1. **`docs/prd.md`** — What's the product, who's it for, why does it exist.
2. **`docs/architecture.md` §3-5** — Layered architecture, module map, inference pipeline.
3. **`docs/design.md` §1-2** — Design principles + anti-patterns (knowing these saves
   every code review).
4. **`docs/implementation-plan.md`** — Status table — what's done, what's pending.
5. **`docs/team.md`** — Who's who, who owns what.
6. **`docs/demo.md`** — The 5 demo scenarios the team runs live.
7. **`CHANGELOG.md`** — Timeline of build phases.
8. **`CONTRIBUTING.md`** — How to set up local dev, run tests, file a PR.
9. **`docs/PRE-DEMO.md`** — When you're prepping for the actual demo, read this.

---

## Pointers for the demo

### The 5 scenarios (from `docs/demo.md`)

1. **Static quick cards** — 8 cards, expandable, no model needed. Shows the
   always-available safety net.
2. **Voice query → grounded spoken answer** — "আমার বাচ্চার ডায়রিয়া হয়েছে, পরিষ্কার
   পানি নেই, কি করবো?" → Bangla answer with 999 reminder.
3. **Snakebite do/don't** — "সাপে কামড়েছে, কি করবো?" → "কাটবেন না, চুষবেন না,
   বরফ দেবেন না".
4. **Nearest shelter via GPS** — GPS resolves, map opens, top 3 shields rendered.
5. **One-tap emergency dial 999** — slide-to-confirm → dialer opens.

### Likely judge questions (from `docs/demo.md` §5)

- "Does this really work offline?" → Yes; show airplane mode bar.
- "Why Gemma?" → Only open model that fits on a phone and runs Bangla.
- "Hallucination safety?" → RAG over 23 sourced chunks, cosine floor 0.35,
  canned "ask a human" for low confidence.
- "Privacy?" → All on-device. No analytics. SMS body stays on the device.
- "What if model doesn't fit on a low-end phone?" → Quick cards work without model;
  fallback to Gemma 3 1B if needed.

### Live-demo failure playbook (from `docs/PRE-DEMO.md` §Phase 5)

| Failure | Action |
|---|---|
| 999 dialer doesn't open | Show `tel:999` call link as alt |
| TTS silent | `bn-IN` fallback voice, or text-only |
| Answer empty after submit | ChatRepository catches → canned response |
| Shelter map blank | Offline markers + Bangladesh default + disclaimer |
| Model file missing | Defer to live internet to download |
| Phone freezes | Reboot; show fallback video while restarting |
| Auto-rotate changes layout | Set orientation lock beforehand |

---

## What NOT to change (red lines)

1. **Do not lift the arm64-v8a ABI restriction.** The model is arm64-only.
2. **Do not add network calls to the core chat loop.** The thesis is offline.
3. **Do not lower the cosine floor or remove canned fallbacks.** Anti-hallucination
   guardrails.
4. **Do not add analytics that ship user content.** Voice, GPS, photos, chat are
   device-local.
5. **Do not ship medical content from a non-whitelisted source.** Only WHO / BDRCS /
   MoDMR / BMD / CDC / IFRC.
6. **Do not branch the model path.** All model access goes through `modelManager`.
7. **Do not auto-read aloud without opt-in.** TTS must be user-triggered or `pref_auto_read`.

Full list in `CONTRIBUTING.md` §"What NOT to change".

---

## Hand-off checklist (when someone else takes over)

- [ ] Read this document (you're doing it).
- [ ] Read `CONTRIBUTING.md` for the dev workflow.
- [ ] Run `flutter pub get && flutter analyze && flutter test`.
- [ ] Verify you have arm64 device + `gemma-4-e2b-int4.task` to test the model path.
- [ ] Read `docs/PRE-DEMO.md` if you have a demo coming up.
- [ ] Read `docs/POST-HACKATHON.md` if you're past the hackathon.

Then look at `docs/spike-results.md` (TEMPLATE — fill in real values) and the open
issues list (if any) for what's still pending.

---

## Appendix — file size audit

These numbers are from before any model file is bundled. They reflect the codebase and
ship-ready assets only.

| Component | Size | Notes |
|---|---|---|
| `lib/` (all Dart) | ~3.5 MB | Lines of code: ~5,500 |
| `assets/fonts/` | ~1.0 MB | 4 Hind Siliguri weights |
| `assets/kb/` | ~75 KB | 23 chunks × 768 floats × 4 bytes |
| `assets/shelter/` | ~10 KB | GeoJSON (variable per source) |
| `assets/sound/` | ~80 KB | chime.wav + knock.wav |
| **APK (no model)** | ~15 MB | arm64-v8a, release |
| `gemma-4-e2b-int4.task` | ~1.5 GB | downloaded per-device, not bundled |

---

## End of report

This document is intentionally one-shot. Update it when there's a major state change
(hackathon → live pilot, version 1.0 → 2.0). Day-to-day progress lives in
`CHANGELOG.md`, design decisions live in `docs/team.md` Decision Log, and architecture
changes belong in `docs/architecture.md`.
