# Shongjog (সংযোগ) — Offline Bangla Multi-Hazard Emergency Companion Powered by Gemma 4

> *"it works when the internet doesn't."*

Shongjog is a Bangla, voice-first emergency companion covering **12 hazard types** and **13 first-aid topics**. **Gemma 4 runs fully on-device**, so grounded RAG guidance and six AI modules work in airplane mode. Online, it enriches that core with live hazard feeds, Gemini vision damage scanning, and coordinator sync. When towers fall, a Bluetooth / Wi-Fi Direct mesh carries text, media, **full-duplex voice calls**, and multi-hop SOS relay between phones with no carrier. Offline-first, online-enhanced, genuinely network-independent.

---

## By the Numbers

| Metric | Value |
|---|---|
| On-device AI modules | 7 (6 offline + 1 cloud) |
| Quick reference cards | 25 (work with zero model) |
| Verified Bangla knowledge chunks | 23 (WHO, BDRCS, CDC, IFRC, UNICEF, BMD) |
| Bundled cyclone shelters | 263 |
| Live API endpoints | 13 (11 key-less) |
| SFT fine-tuning examples | 179 |
| Test suite | 878 pass · 100 files |
| Codebase | 156 Dart files · ~42,300 lines |
| Languages | Bangla-first (834 EN / 888 BN strings) |

---

## The Problem

Bangladesh is among the most disaster-exposed countries on earth. In every event — **flood, cyclone, earthquake, fire, landslide, lightning, tsunami, heatwave, cold wave, drought, riverbank erosion, chemical incident** — mobile networks fail first, and every internet-dependent AI assistant goes dark precisely when guidance is needed most.

- **The first hour decides outcomes** — before responders arrive, correct first-aid and safe-water decisions save lives.
- **Folk myths kill.** "Cut a snakebite," "drink flood water" — still common knowledge, still lethal.
- **Official guidance is dense Bangla text**, hard to read fast under stress.

Only a model running **on the device** can answer here. That is why Shongjog is built on Gemma 4.

---

## Three Connectivity Regimes, One App

Shongjog stays useful across every network state a disaster produces — degrading in capability, never in availability:

| Regime | What powers it | What the user gets |
|---|---|---|
| **Online** | Gemma 4 on-device **+ 13 live endpoints** | Everything below, plus live hazard feeds, weather and marine surge, turn-by-turn routing, map/POI search, Gemini vision damage scanning, and cross-device coordinator sync |
| **No internet, phones nearby** | Gemma 4 on-device **+ Bluetooth / Wi-Fi Direct mesh** | Everything below, plus text, images, video, voice notes and **full-duplex voice calls** to nearby phones, and multi-hop SOS relay outward |
| **Fully isolated** | **Gemma 4 on-device alone** | Grounded Bangla Q&A, six of seven AI modules, triage wizard, 25 quick cards, shelter map with cached tiles, offline directory, SOS SMS |

> *The bottom row is the guarantee. Everything above it is upside.*

---

## How We Use Gemma 4

Gemma 4 is not an add-on. It is the reason the app can exist.

### On-Device Generation — Gemma 4 E2B

Runs entirely on-device via **LiteRT-LM** through `flutter_gemma_litertlm`. The **E2B** variant (4-bit, ~2.47 GB) is the default for phones with ≤8 GB RAM; a hardware probe auto-selects **E4B** (~3.49 GB) on high-RAM devices (>8 GB). Sampling is tuned, not defaulted: 1024-token context, 256-token replies, temperature 0.3, top-k 40, top-p 0.95, fresh per-call seed. **Adaptive thinking** is OFF for reflex emergencies (choking, drowning), ON for complex questions.

Every generation is **time-bounded** — the app always returns an answer through a four-tier fallback chain: Gemma 4 on-device → cloud → verified corpus → "call 999."

### Retrieval-Augmented Generation

Gemma 4 answers **only** from vetted content. **23 verified guidance chunks** in simple Bangla, each tagged to a named source across **17 cited documents** — WHO, BDRCS, CDC, MoDMR, IFRC, UNICEF, and BMD. Every chunk is hand-checked against its source.

Embeddings use `paraphrase-multilingual-mpnet-base-v2` (768-dim, L2-normalized), bundled as an asset — present in airplane mode with no first-run download. Retrieval is keyword-first (sub-millisecond) with brute-force cosine as a second path.

### Function Calling

Gemma 4's function-calling produces a structured hazard report — location, casualties, injuries, needs — formatted as an SMS a 999 operator can act on. Shelter search, by contrast, is a pure-Dart haversine ranker in microseconds with no inference. **Knowing where not to put the LLM is part of the design.**

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

Every on-device module has a deterministic fallback — templated brief, distance ordering, keyword intent — so the app stays useful in every state.

### Cloud AI & Fine-Tuning

Gemma 4 on-device runs **first, even when online.** Cloud is reached only if the local model is still downloading: `gemini-3.1-flash-lite` → `-preview` → `gemma-4-26b-a4b-it`, rotating across a key ring. The API key is never compiled into the APK — fetched at launch from Firestore, revocable without a new release.

A **179-example** SFT dataset covers every corpus domain, myth correction, and safe refusal, with LoRA hot-swap support. A **50-query** held-out eval harness across 5 categories measures retrieval quality:

| Metric | Result |
|---|---|
| Retrieval hit rate (any relevant in top-3) | **98%** |
| Recall@1 | **46%** |
| Recall@3 | **60%** |
| Myth-correction Recall@1 | **60%** |
| Out-of-scope rejection | **100%** (no false positives) |

The 100% out-of-scope rejection is safety-critical: off-corpus queries return no chunk, so the model says "I don't know" and routes to a helpline instead of hallucinating.

---

## Key Features

| Feature | What it does | Offline? |
|---|---|---|
| **Voice-first** | Bangla STT with locale resolution; Bangla TTS reads answers aloud (opt-in) | ✅ |
| **Bilingual** | Bangla-first UI, full English locale (834 strings), Bangla numerals (০-৯) | ✅ |
| **Shelter map** | 263 GPS-ranked shelters with distance, capacity, tap-to-call, tile caching, OSRM turn-by-turn routing | ✅ |
| **Triage wizard** | Pure-Dart decision tree to 8 terminal first-aid routes — cannot hallucinate | ✅ |
| **Quick cards** | 25 expandable cards: ORS, snakebite, CPR, drowning, bleeding, burns, and more | ✅ |
| **Mesh comms** | Text, media, full-duplex voice calls, multi-hop SOS relay — no carrier needed | ✅ |
| **Hazard feeds** | 13 endpoints: GDACS, NASA EONET, USGS, Open-Meteo ×3, OSRM, Nominatim, Overpass, OSM | ☁ |
| **Coordinator panel** | Firestore live safe/danger counts, danger reports, campaign approval, broadcasts | ☁ |

### Offline Mesh — Phone-to-Phone Without Towers

When every tower is down, phones still reach each other. A dual-transport mesh auto-negotiates between **Nearby Connections** (P2P_CLUSTER) and a **GMS-free Wi-Fi Direct fallback** — both behind one interface.

Text, images, video, and voice notes travel as `BYTES` and `FILE` payloads. **Full-duplex voice calls** stream PCM audio (8 kHz mono, ~16 KB/s) through a custom Kotlin `AudioTrackPlugin` — Flutter has no low-latency PCM sink. A pure-Dart **multi-hop SOS relay** floods reports past radio range (5-hop cap, LRU dedup, 1-hour TTL) — unit-tested with no radio.

---

## Architecture

```
[User: voice or text, in Bangla]
    │
    ▼
Speech-to-Text ──► (shelter query? ─► pure-Dart haversine ranker ─► instant)
    │
    ▼
Query ──► KeywordRetriever (offline) ──► top-3 verified chunks
    │
    ▼
TIER 1  ★ GEMMA 4 E2B ON-DEVICE ★ ◄── retrieved context + Bangla system prompt
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
| **Model** | **Gemma 4 E2B / E4B (4-bit, LiteRT-LM)** | Grounds well in Bangla on a mid-range phone |
| Runtime | `flutter_gemma_litertlm` | Mature Flutter binding for Gemma 4 on arm64 |
| Retrieval | Keyword + cosine over mpnet 768-dim vectors | Offline-first, sub-millisecond |
| Mesh | `nearby_connections` (P2P_CLUSTER) + Wi-Fi Direct | Works with cellular down |
| Coordinator | Firestore + anonymous auth | Cross-device coordination |

**Clean architecture:** `core/`, `rag/` and `knowledge/` are pure Dart — fully unit-testable without a device.

---

## Engineering Quality

Disaster software has to work unattended, offline, on a phone nobody can debug.

- **878 tests across 100 files** — WCAG contrast, 1.5× text scaling, numeral conversion, STT locale, mesh path-traversal resistance, tier-fallback chain.
- **10-gate release script inspects the APK binary**: LiteRT-LM libs present, arm64-only, R8 clean, notification icon survived, **no API key in `libapp.so`.**
- **Security-audited data model:** auth-bound writes, role-restricted coordinator data, type-validated documents.

---

## Privacy & Safety

**Your emergency conversation stays on your phone.** The core loop runs entirely on-device — no analytics, no crash reporting, no advertising SDK, no third-party tracking. Every endpoint is HTTPS. Online features are explicit user choices.

| Principle | Enforcement |
|---|---|
| Triage and explain; never diagnose or prescribe | System prompt constraint |
| No guessing on low confidence | Explicit "I don't know" → human helpline |
| Myth correction | "না, এটি ভুল" (*No, this is wrong*) + source attribution |
| Zero tracking | No analytics, no ads, no crash SDK |

---

## Impact

Every existing disaster tool for Bangladesh assumes connectivity — an SMS portal, a Facebook page, a web dashboard. None answer when the towers fall. Shongjog puts a grounded LLM, voice interaction, and a phone-to-phone mesh on a ৳15,000 device — built for the person who needs it most, in the moment they need it most.

> *The bar is not "beautiful." The bar is trustworthy and usable under stress, by people who may not read well, may be wet, may be shaking, and may have one hand free.*

---

## Project Links

- **GitHub:** https://github.com/Ahnaf181419/shongjog
- **APK:** [Download v1.0.0](https://github.com/Ahnaf181419/shongjog/releases/tag/v1.0.0)

---

## Team

Built for the *Build with Gemma 4: ML, AI, Deep Learning & NLP Community Hackathon* (Bangladesh).
