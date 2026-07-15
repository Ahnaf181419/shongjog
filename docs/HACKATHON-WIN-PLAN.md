# Shongjog — 5-Day Hackathon Standout Plan

> Feature and pitch plan to make Shongjog win. Baseline: the codebase is already
> code-complete (see `PROJECT-STATUS.md`) — offline RAG, on-device Gemma, mesh,
> 160+ tests. Judges won't see that engineering; they see a 3-minute demo and a
> story. This plan converts existing infrastructure into demo moments no other
> team will have.
>
> **Thesis to prove on stage: "it works when the internet doesn't."**
> Every feature below must run in airplane mode or degrade gracefully.

**Date:** 2026-07-15
**Owner:** whole team — assign names per item in `team.md` before Day 1 ends.

---

## Priority summary

| # | Feature | Effort | Tier | Demo moment |
|---|---|---|---|---|
| 1 | Multi-hop mesh SOS relay | ~1.5 days | 1 | Phone with no SIM gets rescued through strangers' phones |
| 2 | "I'm safe" family check-in beacon | ~0.5 day | 1 | One tap → mesh broadcast + queued SMS |
| 3 | Offline Bangladesh MBTiles | ~1 day | 1 | Shelter map works with all radios off |
| 4 | Compass arrow to nearest shelter | ~0.5 day | 1 | Rotate the phone on stage, arrow tracks |
| 5 | Cyclone early-warning "disaster mode" | ~1 day | 1 | App prepares while online, protects while offline |
| 6 | Guided triage wizard (no LLM) | ~1 day | 1 | Life-critical steps without the model — can't hallucinate |
| 7 | AI SOS composer | ~1 day | 1 | Panicked rambling → structured SOS, on-device, offline |
| 8 | CPR metronome | ~2h | 2 | Full-screen 110 BPM pulse + haptics + Bangla count |
| 9 | ORS mixing calculator | ~2h | 2 | Slider → Bangla instructions (০-৯ numerals) |
| 10 | Torch SOS / whistle mode | ~2h | 2 | Flashlight Morse SOS for the physically trapped |
| 11 | Offline emergency directory | ~2h | 2 | District-filterable official numbers, tap-to-call |
| 12 | "Explain simply" button (AI) | ~0.5 day | 2 | One tap rewrites guidance in simpler Bangla + TTS |
| 13 | Preparedness plan generator (AI) | ~1 day | 2 | Family profile → personalized Bangla cyclone checklist |
| 14 | Battery-aware emergency mode | ~3h | 2 | Stripped black UI below 20% battery |
| 15 | Elderly / low-literacy mode | ~3h | 2 | Huge text + TTS speaker button on every card |
| 16 | First-run demo pack | ~1h | 2 | Chat never looks empty in judges' hands |

Pick **2–3 from Tier 1** plus as many Tier-2 quick wins as Day 4 allows.
Cut ruthlessly; a rehearsed demo beats one more feature.

---

## Tier 1 — demo "wow" features

### 1. Multi-hop mesh SOS relay (~1.5 days) — biggest untapped weapon

`nearby_connections` P2P messaging already works (`lib/features/mesh_comm/mesh_service.dart`).
Extend it so an SOS payload (name + GPS + message) **relays across hops**:

- Phone A (airplane mode, "no SIM") broadcasts SOS.
- Phone B receives and re-broadcasts to its own peers.
- Phone C — which has signal — forwards it as an SMS to 999 / emergency contacts
  (reuse `sos_sms_template.dart`).

Requirements:

- De-dupe by message UUID + TTL (max hops, e.g. 5) so packets don't loop.
- Live **hop-count badge** on the message bubble so judges see the relay happen.
- UTF-8 encoding as per the existing mesh rule (never `codeUnits` — garbles Bangla).
- Unit tests for the relay/de-dupe logic (pure Dart — keep it out of the plugin layer
  per the dependency rule in `architecture.md` §3).

Demo: three phones on stage. One is "trapped under rubble." Its SOS arrives at
the third phone via the second. No other team will have this.

### 2. "I'm safe" family check-in beacon (~0.5 day)

One giant Bangla button ("আমি নিরাপদ আছি") that:

- Broadcasts safe-status + location to all mesh peers.
- Queues an SMS to emergency contacts; sends automatically when signal returns
  (listen on `connectivityProvider`).

Rationale: during Cyclone Remal the #1 telecom traffic was families trying to reach
each other. Cheap — reuses the SOS SMS template, contacts store, and mesh service.

### 3. Offline Bangladesh MBTiles (~1 day) — promote from P2 to P0

The first thing a skeptical judge does is enable airplane mode and open the shelter
map. Today that shows a styled background + markers. Bundle real offline tiles for
the coastal belt (Cox's Bazar + Barisal divisions, zoom ~8–14):

- Source: pre-built MBTiles from OpenMapTiles for a bounding box, or `tilemaker`
  from a Geofabrik Bangladesh extract.
- Wire into the existing `cached_tile_provider` / connectivity fallback path.
- Keep the bundle size sane (< ~80 MB); scope the bbox to the demo region if needed.

This turns the weakest airplane-mode moment into a strong one.

### 4. Compass arrow to nearest shelter (~0.5 day)

OSRM routing is online-only. Add the offline degradation:

- Big compass arrow + distance ("আশ্রয়কেন্দ্র ১.২ কিমি উত্তর-পূর্বে") using
  `flutter_compass` heading + bearing math from `nearest_shelter.dart`.
- Zero tiles needed; works in full airplane mode.

Demo: physically rotate the phone on stage; the arrow tracks.

### 5. Cyclone early-warning "disaster mode" (~1 day)

- While online, pre-cache the Open-Meteo/BMD forecast (extend
  `lib/features/weather/weather_service.dart` — this is already an allowed
  network path).
- When the danger signal is high, flip the home screen into a red preparedness
  mode: countdown checklist (secure documents, fill water, charge phone),
  nearest shelter pinned, mesh auto-on prompt.

Story: *the app prepares while you have internet, and protects you when you don't.*

### 6. Guided triage wizard — deterministic, no LLM (~1 day)

Free-text chat is the wrong interface for a panicking user. Build a step-by-step
decision tree with giant yes/no buttons — "ব্যক্তি কি সচেতন?" → "শ্বাস নিচ্ছে?" →
… — that routes into the existing quick-card content (CPR, bleeding control,
drowning, snakebite).

- Deterministic flow: no model needed, works instantly on any phone, **cannot
  hallucinate**. This is what IFRC first-aid apps actually do.
- Content stays inside the whitelist (WHO/IFRC/CDC first-aid protocols); every
  terminal node ends with the 999 reminder.
- Pure-Dart decision-tree model in `features/` (unit-testable per the dependency
  rule); thin widget layer on top with widget tests.

Pitch value: a second answer to the hallucination question —
*"for life-threatening steps we don't even use the LLM."*

### 7. AI SOS composer (~1 day)

A panicked user can't write a good SOS. Let them speak (or type) a rambling
Bangla description — "পানি উঠে গেছে, আমরা ছাদে, আমার মা হাঁটতে পারে না…" — and
Gemma condenses it into a structured SOS: location, number of people, injuries,
immediate needs. The structured message feeds the existing SOS SMS template
**and** the mesh relay payload.

- The model **summarizes the user's own words** — it adds no facts, so
  hallucination risk is minimal by construction. Validate the output: if a
  required field is missing or garbled, fall back to the raw text + GPS
  (never block the SOS on the model).
- Works when `modelManager.isReady`; degrades to the plain SOS template when
  the model isn't loaded. The SOS path must never *require* the model.
- Demos inside the same 3-phone mesh scene: speak a panicked sentence, show
  the clean structured SOS arriving two hops away.

**AI guardrails common to items 7, 12, 13:** all generation goes through the
`modelManager` singleton (single model path — red line), prompts built via
`rag/prompt_builder.dart` patterns, `maxTokens: 512` respected, fully offline.
The model transforms trusted content or the user's own words; it is never a
knowledge source outside the corpus.

---

## Tier 2 — cheap wins (hours each)

- **CPR metronome (~2h).** Full-screen pulse at 110 BPM, haptic beat via
  `HapticService`, Bangla voice counts via TTS. No model needed; content within
  the CDC/IFRC whitelist.
- **ORS mixing calculator (~2h).** Interactive quick card: water-amount slider →
  Bangla instructions with ০-৯ numerals. Diarrhea is the #1 post-flood killer —
  domain-aware judges will notice.
- **Torch SOS / whistle mode (~2h).** Battery-black screen, flashlight blinking
  Morse SOS, loud whistle tone. One button in the emergency sheet.
- **Offline emergency directory (~2h).** Cached, district-filterable list of
  official numbers — fire service, ambulance, district hospitals, poison
  control — from official MoDMR/DGHS listings, with tap-to-call (reuse the
  contacts feature's call path). Static JSON asset; 999 is covered, but this is
  what people actually fumble for.
- **"Explain simply" button (AI, ~0.5 day).** On every AI answer and quick card:
  one tap asks Gemma to rewrite the guidance in simpler Bangla / numbered steps,
  with a TTS read-aloud button. Input is the already-verified card/answer text,
  so the model simplifies trusted content rather than generating new claims.
  Directly serves low-literacy users; strengthens the inclusion story.
  Guardrails per Tier 1 item 7.
- **Preparedness plan generator (AI, ~1 day).** User enters a family profile —
  elderly members, infants, medications, house type — and Gemma + retrieved
  corpus chunks generate a personalized Bangla cyclone-prep checklist. Safe
  use of AI (pre-disaster, user is calm, content grounded in the corpus);
  pairs naturally with disaster mode and shows AI doing something no static
  app can. Persist the generated plan locally so it's readable offline later
  without re-generation. Guardrails per Tier 1 item 7.
- **Battery-aware emergency mode (~3h).** Below 20% battery, offer a stripped
  black UI (OLED savings), disable typewriter/breathing animations.
  Pitch line: "designed for hour 14 of the power cut."
- **Elderly / low-literacy mode (~3h).** Huge-text toggle; speaker (TTS) button on
  every quick card. Respect the `pref_auto_read` opt-in rule — buttons are
  user-triggered, never unsolicited.
- **First-run demo pack (~1h).** Seed the chat with 2–3 pre-answered example Q&As
  so the app never looks empty on a judge's hands-on table.

All new logic follows the testing policy: pure-Dart core + unit tests, widget
tests for new UI. No feature ships without tests (`CONTRIBUTING.md`).

---

## Tier 3 — the pitch (worth as much as any feature)

1. **Airplane mode for the entire demo.** Enable it on stage at the start,
   keep the icon visible in the status bar, and never mention it again —
   let judges notice.
2. **Lead with the statistic, not the tech.** "When Cyclone Remal hit in 2024,
   ~30M people lost mobile network for days. Every disaster app in the store
   became a blank screen." Then demo.
3. **Metrics slide** (fill from Phase 0 spikes in `spike-results.md`):
   model size 1.87 GB, X tok/s on a ৳15,000 phone, cold start X s,
   23 verified chunks (WHO/BDRCS/MoDMR/BMD/CDC/IFRC), 160+ tests,
   zero network calls in the core loop.
4. **Demo the failure mode on purpose.** Ask an off-corpus question and show the
   canned "call 999 / ask a human" response. Deliberately showing the
   anti-hallucination guardrail is a power move almost nobody does.
5. **Privacy line:** "Your voice, your location, your questions never leave your
   phone — not because we promise, but because there is no code path for them to."
6. **Record the fallback video early** (Phase 5.3 in `PRE-DEMO.md`). Teams lose
   hackathons to demo flakiness more than to missing features. Switch to video
   at the first sign of trouble.

---

## Stretch — only if a day is left over

- **Photo → first-aid guidance.** Gemma 3n-class models are multimodal via
  MediaPipe; if the current `flutter_gemma` exposes image input, "photo of a
  wound → grounded Bangla guidance" is a jaw-dropper. High-risk against the
  single-model-path red line and the medical whitelist — spike in isolation
  first; cut ruthlessly if it wobbles.
- **Vosk offline STT fix.** Fully-offline voice completes the thesis, but the
  AGP `compileSdk` conflict (`POST-HACKATHON.md` §1.1) is a rabbit hole.
  Online STT fallback + typed input is demo-acceptable. Timebox to half a day, max.

---

## What NOT to do

- No more chat features, themes, settings, or corpus growth — judges can't tell
  23 chunks from 50.
- Nothing that needs a server. The entire differentiation is that there isn't one.
- Don't touch the red lines (`CONTRIBUTING.md` §"What NOT to change"): model path,
  arm64 filter, cosine floor, `model.bin` filename, corpus whitelist, Bangla-only
  UI, no unsolicited TTS, no content-shipping analytics.

---

## Day-by-day schedule

The plan now needs **two parallel tracks** (assign per `team.md`):
Track A = mesh / maps / hardware features. Track B = AI / UX features.

| Day | Track A | Track B | Exit criteria |
|---|---|---|---|
| **1** | Mesh SOS relay: payload schema, relay + de-dupe + TTL logic (pure Dart, unit-tested) | Guided triage wizard: decision-tree core (pure Dart, unit-tested) | Relay + tree logic green in `flutter test` |
| **2** | Mesh SOS relay: wire into `meshService` + UI hop badge; **"I'm safe" beacon** | Guided triage wizard: UI + wiring into quick-card content | 3-phone relay works in a room test; wizard reaches every terminal node |
| **3** | Offline MBTiles bundled + wired; compass arrow to nearest shelter | **AI SOS composer**: prompt + output validation + fallback to raw SOS; feed SMS template & mesh payload | Map + arrow work in airplane mode; composer degrades safely with model absent |
| **4** | Quick wins: offline emergency directory, CPR metronome, torch SOS, ORS calculator | **"Explain simply" button**; then **preparedness plan generator** as time allows | Directory tap-to-call works; explain-simply on cards + answers; tests green |
| **5** | *(both tracks)* Pitch deck, metrics slide, fallback video (`demo-fallback.mp4`), full airplane-mode rehearsal ×3 on real phones | | `PRE-DEMO.md` checklist complete; `flutter analyze` clean; `flutter test` all-pass |

If anything slips, cut in this order: stretch items → unscheduled Tier 2
(battery mode, elderly mode) → preparedness plan generator → Tier-2 quick wins →
"explain simply" → Tier 1 item 5 (disaster mode, already unscheduled).
Never cut the mesh relay, the triage wizard, or rehearsal time.

---

## The three moments no other team will have

1. A phone with **no SIM getting rescued** through a mesh of strangers' phones.
2. A **working map and AI with every radio off**.
3. An AI that **refuses to hallucinate** — on purpose, on stage.
