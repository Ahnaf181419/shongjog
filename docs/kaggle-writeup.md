# Shongjog (সংযোগ) — Offline Bangla Multi-Hazard Emergency Companion Powered by Gemma 4

> **Title:** Shongjog — Offline Bangla Multi-Hazard Emergency Companion Powered by Gemma 4
>
> **Subtitle:** Bangla voice-first emergency AI for 12 disaster types. Gemma 4 on-device works offline, gets better online, and meshes phone-to-phone.
>
> **GitHub:** https://github.com/Ahnaf181419/shongjog

---

## In One Paragraph

Shongjog is a Bangla, voice-first emergency companion covering **12 hazard types** — floods, cyclones, earthquakes, fires, landslides, lightning, tsunami, heatwaves, cold waves, drought, riverbank erosion and chemical incidents — plus **13 first-aid topics**. **Gemma 4 runs fully on-device via LiteRT-LM**, so grounded Bangla guidance, RAG over 23 source-cited chunks, and six AI modules all work in airplane mode. Online, it enriches that core with **13 live endpoints**: Gemini vision damage scanning, GDACS, NASA EONET and USGS hazard feeds, Open-Meteo weather, marine surge and air quality, OSRM routing, Nominatim and Overpass search, plus Firestore coordinator sync. When towers fall, a dual-transport Bluetooth and Wi-Fi Direct mesh carries text, images, video, voice notes and **full-duplex voice calls** directly between phones, with multi-hop SOS relay flooding reports past radio range. Offline-first, online-enhanced, genuinely network-independent.

---

## The Problem

Disaster strikes Bangladesh in many forms — floods, cyclones, earthquakes, fires, landslides, lightning, heatwaves, cold waves, riverbank erosion. In every one of them, mobile networks and electricity fail first, and every internet-dependent AI assistant goes dark precisely when guidance is needed most.

- **Connectivity collapses** for hours or days. Cloud AI is unreachable.
- **The first hour decides outcomes** — before responders arrive, correct first-aid and safe-water decisions save lives.
- **Official guidance is dense Bangla text**, hard to read fast under stress.
- **Folk myths kill.** "Cut a snakebite," "drink flood water" — still common knowledge, still lethal.

Only a model running **on the device** can answer here. That is why Shongjog is built on Gemma 4.

---

## What We Built

**Shongjog** (সংযোগ, "connection") is a Flutter app with **Gemma 4 running fully on-device**. Ask an emergency question in Bangla — by voice or text — and the app:

1. **Understands** it (Bangla speech-to-text, typed fallback).
2. **Retrieves** verified guidance from an on-device knowledge base (RAG).
3. **Generates** a grounded, step-by-step Bangla answer with **Gemma 4 E2B**.
4. **Reads it aloud** (Bangla TTS) for low-literacy users.
5. **Offers one-tap action:** call 999, route to the nearest shelter, send an SOS SMS with GPS.

**The core loop needs no network.** The airplane-mode reveal is our demo: no WiFi, no data, and Gemma 4 answers anyway.

### Three Connectivity Regimes, One App

Shongjog is not "an offline app." It is engineered to stay useful across every network state a disaster produces, degrading in capability but never in availability:

| Regime | What powers it | What the user gets |
|---|---|---|
| **Online** | Gemma 4 on-device **+ 13 live endpoints** | Everything below, plus live hazard feeds, weather and marine surge, turn-by-turn routing, map/POI search, Gemini vision damage scanning, and cross-device coordinator sync |
| **No internet, phones nearby** | Gemma 4 on-device **+ Bluetooth / Wi-Fi Direct mesh** | Everything below, plus text, images, video, voice notes and **full-duplex voice calls** to nearby phones, and multi-hop SOS relay outward |
| **Fully isolated** | **Gemma 4 on-device alone** | Grounded Bangla Q&A, six of seven AI modules, triage wizard, 25 quick cards, shelter map with cached tiles, offline directory, SOS SMS |

The bottom row is the guarantee. Everything above it is upside.

---

## How We Use Gemma 4

Gemma 4 is not an add-on. It is the reason the app can exist.

### On-Device Generation — Gemma 4 E2B

- Runs entirely on-device via **LiteRT-LM** through `flutter_gemma_litertlm`.
- 4-bit quantized, ~2.5 GB on disk — sized for a mid-range phone. A **Gemma 4 E4B** variant is auto-selected on higher-RAM devices by a hardware probe.
- 1024-token context, 256-token replies, temperature 0.3, top-k 40, top-p 0.95 — tuned, not defaults. A fresh per-call seed plus top-p is what keeps answers varied and clean.
- **Adaptive thinking:** OFF for reflex emergencies (choking, drowning), ON for complex questions.
- Every generation is time-bounded, so the app always returns an answer — from Gemma 4, then cloud, then the verified corpus.

### Retrieval-Augmented Generation

Gemma 4 answers **only** from vetted content:

- **23 verified guidance chunks** in simple Bangla, each tagged to a named source across **17 cited documents** — WHO, Bangladesh Red Crescent Society, CDC, Ministry of Disaster Management and Relief, IFRC, UNICEF, and the Bangladesh Meteorological Department.
- Embedded with `paraphrase-multilingual-mpnet-base-v2` (768-dim, L2-normalized), shipped as a bundled asset — present in airplane mode with no first-run download.
- Offline keyword retrieval (sub-millisecond) with brute-force cosine over the bundled vectors as a second path.
- Every chunk is hand-checked against its source document.

### Function Calling

Gemma 4's function-calling produces a structured hazard report — location, casualties, injuries, needs, access notes — formatted as an SMS a 999 operator can act on.

Shelter search is answered by a pure-Dart haversine ranker instead, in microseconds with no inference. **Knowing where not to put the LLM is part of the design** — the most time-critical question in the app is also its fastest.

### Seven AI Modules

| Module | AI Path | Offline |
|--------|---------|---------|
| **AI Family Disaster Planner** — evacuation plan from your family profile | Gemma 4 on-device | ✅ |
| **AI Emergency Kit Generator** — supply list with quantities | Gemma 4 on-device | ✅ |
| **AI Risk Assessment** — risk score + mitigation for your home | Gemma 4 on-device | ✅ |
| **AI Situation Summary** — session reports into one briefing | Gemma 4 on-device | ✅ |
| **AI Shelter Brief** — what to expect and bring at the shelter you tapped | Gemma 4 on-device | ✅ |
| **AI Safety Re-Ranking** — reorders shelters by live hazard proximity and capacity | Gemma 4 on-device | ✅ |
| **AI Damage Scanner** — photo analysis of flood/fire/collapse damage | Gemini vision | ☁ |

Every on-device module has a deterministic fallback — templated brief, distance ordering, keyword search intent — so the app stays useful in every state.

### Cloud AI — A Safety Net Behind Gemma 4

Gemma 4 on-device runs **first, even when the phone is online.** Cloud is reached only if the local model is still downloading. The chain is `gemini-3.1-flash-lite` → `gemini-3.1-flash-lite-preview` → `gemma-4-26b-a4b-it`, rotating across a key ring so a spent free-tier quota never ends cloud access.

The API key is **never compiled into the APK** — the build ships with no key and fetches one at launch from a client-unwritable Firestore document, making it revocable by editing one field with no new release. A build gate enforces this on every release.

### LoRA Fine-Tuning

- **179-example** supervised fine-tuning dataset covering every corpus domain, myth correction, and safe refusal.
- Hot-swap LoRA adapter without reloading the base model.
- **50-query** held-out evaluation harness across 5 categories.

---

## Features

### Multi-Hazard Coverage
**12 disaster types** — flood, cyclone and tornado, earthquake, fire, landslide, lightning, tsunami, heatwave, cold wave, drought, riverbank erosion, chemical incident — plus **13 first-aid topics**: CPR, choking, bleeding, burns, drowning, snakebite, recovery position, ORS, water purification, diarrhoea, fever, shelter-seeking, and escalation to 999. All **25 cards work with no model loaded.**

### Voice-First, Bilingual
- **Bangla speech-to-text** with locale resolution, behind a provider interface for future on-device engines.
- **Clear failure messages** — the app says *why* input failed, never a generic "try again."
- **Bangla TTS** reads every answer aloud. Auto-read is opt-in.
- **Bangla-first with a full English locale** (834 strings) behind a language toggle: Bangla numerals (০-৯), Bangla punctuation (।), Bangla typography throughout.

### Shelter Map & Routing
- `flutter_map` with bundled GeoJSON — no Google Maps dependency.
- GPS-ranked shelters with distance, capacity, tap-to-call, division/district filters, and locate-me.
- **Tile caching**, so an opened area still renders after the network drops.
- **Turn-by-turn routing** via OSRM with distance and duration.
- **Free-form search** over place names (Nominatim) and nearby hospitals and pharmacies (Overpass).

### Online Intelligence — 13 Integrated Endpoints

Connectivity is treated as an enhancement layer over the on-device core. Thirteen endpoints across nine providers are wired in, and **eleven of them need no API key at all** — a deliberate resilience choice, since a billing account that lapses mid-disaster is a single point of failure:

| Purpose | Endpoint | Key? |
|---|---|---|
| Cloud LLM fallback + vision | `generativelanguage.googleapis.com` | Firestore-delivered |
| Coordinator sync + auth | Firebase Firestore / Auth | config only |
| Global disaster alerts | GDACS (UN / European Commission) | — |
| Active natural events | NASA EONET | — |
| Seismic activity | USGS FDSN | — |
| Weather forecast | Open-Meteo | — |
| Marine wave height + direction | Open-Meteo Marine | — |
| Air quality (PM2.5 / PM10 / AQI) | Open-Meteo Air Quality | — |
| Turn-by-turn routing | OSRM | — |
| Place-name search | Nominatim | — |
| Nearby POI search | Overpass | — |
| Map tiles | OpenStreetMap | — |
| Model delivery | Hugging Face | — |

Every one is HTTPS, sends a compliant User-Agent where the provider's policy requires it, and **fails soft** — a card disappears rather than blocking a screen whose whole purpose is working without it. Marine surge and hazard proximity are not decoration: they are inputs the **AI Safety Re-Ranking** module weighs when reordering shelters.

### Triage Wizard — Deterministic
Pure-Dart decision tree to **8 terminal first-aid routes** (CPR, bleeding, drowning, snakebite, unconscious-but-breathing, burn, choking, 999). **Cannot hallucinate** — a safety net that works even before Gemma 4 loads.

### Offline Communications — Mesh Messaging, Media and Voice Calls

When every tower is down, phones can still reach each other. This is the most technically involved subsystem in the app.

**Dual transport, auto-negotiated.** Two backends sit behind one `MeshTransport` interface:

- **Nearby Connections** on the `P2P_CLUSTER` strategy — a Wi-Fi Direct / soft-AP topology. Bluetooth permissions are needed only for beacon advertising and scanning; bulk transport rides Wi-Fi, which is what makes media and live audio viable.
- **A GMS-free Wi-Fi Direct transport** via `flutter_p2p_connection`, for devices without Google Play Services. One device auto-elects itself Group Owner if no host answers within the scan window; the rest join as clients over BLE discovery. Both backends emit the same `TransportPeer` / `TransportMessage` events, so nothing above the transport layer knows which is active.

**What travels the mesh:**

| Payload | Mechanism |
|---|---|
| Text messages | UTF-8 `BYTES` payload |
| Images and video | `FILE` payload plus a paired `media:<id>:<name>:<type>` hint so the receiver can materialize it with the right type |
| Voice notes | `FILE` payload with a `voice:<id>` hint, recorded and replayed locally |
| **Live voice calls** | Continuous prefixed `BYTES` payloads — see below |
| SOS beacons | JSON envelope through the relay engine |

**Full-duplex voice calls over Bluetooth/Wi-Fi Direct, with no carrier and no internet:**

```
MIC ─► record startStream (PCM 8 kHz mono 16-bit) ─► Uint8List chunks
    ─► "CALL_AUDIO:" prefixed BYTES payload ─► Nearby Connections
    ─► receiver strips prefix ─► MethodChannel ─► Android AudioTrack
    ─► earpiece or loudspeaker
```

We wrote a **custom Kotlin `AudioTrackPlugin`** for the playback half, because Flutter has no low-latency PCM sink: it builds an `AudioTrack` at the negotiated sample rate with `ENCODING_PCM_16BIT`, floors the buffer at 1024 frames, and streams raw chunks straight to the speaker. Call setup, ringing, accept/reject and teardown run over a separate `CALL_SIG:` JSON signalling channel with its own state machine.

The **8 kHz mono 16-bit** rate (~16 KB/s) is a deliberate engineering choice, not a limitation — it fits comfortably inside real Wi-Fi Direct throughput between two phones under load, leaves headroom for concurrent text and file payloads on the same link, and keeps latency low enough for genuine conversation. Voice intelligibility, not fidelity, is the requirement.

**Multi-hop SOS relay.** A pure-Dart decision engine floods an SOS outward past direct radio range: LRU-bounded de-duplication over the last 256 message ids, a 5-hop ceiling, a 1-hour TTL, and a loop guard — so a report from someone with no signal can still reach a phone that has one. Being pure Dart, the entire relay policy is unit-tested with no radio involved.

**"I'm safe" beacon** broadcasts over the mesh and simultaneously queues SMS to your chosen contacts, draining automatically when any connectivity returns.

### Coordinator Panel
A Firestore-backed view for relief coordinators: live safe/danger counts, danger list with map links, campaign approval, and broadcasts that raise a tray notification on every install — so a coordinator on one phone sees what a user submitted on another, beyond mesh range.

### Built for the Worst Moment
- **Light and dark themes**, both contrast-audited, with text-safe semantic tones enforced by unit tests.
- **Text scales to 1.5×** without breaking a layout.
- **Haptics and audio cues** so confirmation registers without reading.
- **Slide-to-confirm 999 dialer** — deliberate, never accidental.
- **Emergency contacts manager**, onboarding, profile, a Tools tab collecting every AI feature, a notification centre with proximity alerts for nearby relief campaigns, and a full source list in About.

---

## Architecture

```
[User: voice or text, in Bangla]
    │
    ▼
Speech-to-Text ──► (shelter query? ─► pure-Dart haversine ranker ─► instant answer)
    │
    ▼
Query ──► KeywordRetriever (offline) ──► top-3 verified chunks
    │
    ▼
TIER 1  ★ GEMMA 4 E2B ON-DEVICE ★ ◄──── retrieved context + Bangla system prompt
    │
    ├──► grounded step-by-step Bangla answer ──► screen + TTS
    ├──► function call ──► [SOS SMS]
    │
    ▼ (only while the on-device model is still downloading)
TIER 2  Cloud: gemini-3.1-flash-lite → -preview → gemma-4-26b-a4b-it
    │
    ▼ (always available)
TIER 3  Verified corpus chunk  ──►  TIER 4  "call 999"

═════ tiers 1, 3 and 4 require NO network ═════
```

| Layer | Choice | Why |
|-------|--------|-----|
| Framework | Flutter 3.x / Dart 3.12+ | Single codebase, Android-first |
| **Model** | **Gemma 4 E2B / E4B (4-bit, LiteRT-LM)** | Grounds well in Bangla on a mid-range phone |
| Runtime | `flutter_gemma_litertlm` | Mature Flutter binding for Gemma 4 on arm64 |
| Retrieval | Keyword + cosine over mpnet 768-dim vectors | Offline-first, sub-millisecond |
| Voice | `speech_to_text` + `flutter_tts` (bn-BD, bn-IN) | Locale resolution, diagnosable states |
| Maps | `flutter_map` + GeoJSON + cached tiles | No Google Maps dependency |
| Routing & search | OSRM, Nominatim, Overpass | Free, key-less, open data |
| Hazard feeds | GDACS, NASA EONET, USGS, Open-Meteo ×3 | Free, key-less, CC-BY |
| Mesh | `nearby_connections` (P2P_CLUSTER) | Works with cellular down |
| Coordinator sync | Firestore + anonymous auth | Cross-device coordination |

**Clean architecture:** `core/`, `rag/` and `knowledge/` are pure Dart with zero Flutter or plugin imports — fully unit-testable without a device.

---

## Engineering Quality

Disaster software has to work unattended, offline, on a phone nobody can debug. We verify rather than assume.

- **878 automated tests across 100 files** — unit, widget, integration — covering contrast ratios, 1.5× text scaling, Bangla numeral conversion, STT locale resolution, layout under stress, and security properties.
- **A 10-gate release script that inspects the shipped APK**, not just the build: LiteRT-LM libs present, arm64-only, R8 stripped cleanly, notification icon survived resource shrinking, Android 11 package-visibility `<queries>` declared for speech, TTS, camera and pickers, and **no API key inside `libapp.so`.**
- **Every regression becomes a gate**, so a fix stays fixed.
- **Security-audited data model:** writes are bound to the caller's authenticated identity, sensitive coordinator data is role-restricted, documents are type- and size-validated, and malformed input is isolated per-record.

---

## Privacy & Safety

**Your emergency conversation stays on your phone.** The core loop — question in, Gemma 4 answer out — runs entirely on-device: the model, the verified corpus, the triage wizard, all 25 quick cards, the shelter map, and the offline directory. **Full function in airplane mode**, and that is the product.

Online features are explicit user choices: tapping the damage scanner, pressing "I'm safe," or submitting a campaign request. There is **no analytics, no crash reporting, no advertising SDK, and no third-party tracking** anywhere in the app, and every endpoint is HTTPS.

**Clinical guardrails:**
- **Triage and explain; never diagnose or prescribe** — enforced in the system prompt.
- **Emergency numbers one tap away** on every critical answer.
- **No guessing** — with no confident retrieval, the app says so and routes to a human helpline.
- **Myth correction** — folk-myth queries ("should I cut a snakebite?") get "না, এটি ভুল" (No, this is wrong) with source attribution.

---

## Impact

Bangladesh is among the most disaster-exposed countries on earth, and preventable deaths from unsafe water, drowning, untreated injury and mismanaged snakebite spike during every event.

Shongjog delivers correct, personalized, **offline** guidance across **12 hazard types**, in the local language, by **voice**, grounded in **verified sources** — solving a recurring, high-stakes failure that no cloud-dependent tool can reach.

**The bar is not "beautiful." The bar is trustworthy and usable under stress, by people who may not read well, may be wet, may be shaking, and may have one hand free.**

---

## Project Links

- **GitHub:** https://github.com/Ahnaf181419/shongjog
- **Track:** Open Innovation

---

## Team

Built for the *Build with Gemma 4: ML, AI, Deep Learning & NLP Community Hackathon* (Bangladesh).
