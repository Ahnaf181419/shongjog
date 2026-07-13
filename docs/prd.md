# Shongjog — Product Requirements Document

> **Internal team-facing document.** Scope, success criteria, and constraints for the
> *Build with Gemma 4: ML, AI, Deep Learning & NLP Community Hackathon* (Bangladesh).
>
> **One-line product statement:** An on-device, Bangla, voice-first flood/cyclone
> emergency companion powered by Gemma 4 — **it works when the internet doesn't.**

This PRD supersedes `docs/plan.md` (the original hackathon pitch). The pitch content
has been folded into the sections below. The companion task-by-task build plan lives in
`docs/implementation-plan.md`; technical detail in `docs/architecture.md`; UX in
`docs/design.md`; coordination in `docs/team.md`; corpus policy in `docs/corpus.md`.

---

## 1. Problem Statement

Every year, floods and cyclones displace millions of people across Bangladesh. In those
exact moments, mobile networks, mobile data, and electricity are the first things to
fail — which means every internet-dependent "AI assistant," helpline app, or chatbot
becomes useless precisely when guidance is needed most.

The people most exposed are the least served by internet-dependent tools:

- **Connectivity collapses.** Cellular data, broadband, and grid power routinely go
  down for hours or days. Cloud AI, translation apps, and web helplines go dark.
- **Guidance is hardest to reach when it matters most.** The window right after a
  disaster strikes — before responders arrive — is when correct first-aid and
  safe-water decisions save lives.
- **A literacy and language gap.** Official guidance is often English or dense Bangla
  text. Rural, elderly, and low-literacy users cannot read it quickly under stress.
- **Dangerous folk myths persist.** For snakebite, cholera, and water safety, incorrect
  "common knowledge" (cut a snakebite, drink untreated flood water) actively harms.

### Why existing solutions fall short

- Chatbots and translation apps assume a live internet connection.
- Static PDF leaflets and SMS alerts don't answer a person's *specific* situation.
- Generic LLM apps hallucinate medical advice and can't be trusted for triage.

### Why it matters

Bangladesh is one of the most flood- and cyclone-exposed countries on earth. Preventable
deaths from waterborne disease (cholera, severe diarrhea), unsafe drinking water,
drowning, and mismanaged snakebite spike during and after every major event. A tool that
delivers correct, personalized, offline guidance in the local language — accessible by
voice — directly addresses a recurring, high-stakes, real-world failure.

---

## 2. Solution

Shongjog is a **Flutter mobile app with Gemma 4 running fully on-device.** The user asks
an emergency question in Bangla — by voice or text — and the app:

1. Understands the question (Vosk-Bangla speech-to-text, fully offline).
2. Retrieves the most relevant, **verified** emergency guidance from an on-device
   knowledge base (RAG via EmbeddingGemma 300M).
3. Uses **Gemma 4 E2B** to generate a clear, grounded, step-by-step answer in simple
   Bangla.
4. Reads the answer aloud (Bangla text-to-speech) for low-literacy users.
5. Surfaces one-tap actions: call emergency services (999/333), find the nearest shelter,
   send a pre-drafted SOS SMS.

Nothing in the core loop requires a network connection. Calls and SMS use the cellular
voice channel, which frequently survives when mobile data is down — a deliberate design
decision.

---

## 3. Why On-Device Gemma 4 Is the Core (not a wrapper)

This is the heart of the project and the reason it qualifies as genuine Gemma 4
integration rather than an API call:

- **Offline is only possible because the model is open and local.** No cloud model can do
  this. The entire product thesis depends on Gemma 4 running on the device.
- **Gemma 4 E2B is purpose-built for this.** ~5.1B total / 2.3B active parameters,
  ~1.5GB one-time download, runs in under ~2GB RAM at 4-bit — practical on real (not
  just flagship) phones. Supports native function calling, a 128K context window, and
  native audio/vision input.
- **The whole Gemma family does the work, on-device:**
  - **Gemma 4 E2B** — answer generation (thinking mode off for speed).
  - **EmbeddingGemma 300M** — semantic retrieval for RAG.
  - **Gemma function-calling** — triggers app actions (nearest shelter, SOS).
  - *(Stretch, deferred)* **Gemma 4 E2B multimodal** — photograph a wound, snake, or
    floodwater for visual triage.
- **Privacy and cost.** User data (voice, photos, health details) never leaves the phone.
  Zero per-request cost scales to millions of users for free.

---

## 4. Grounding & Safety (RAG)

A 2B on-device model must **never** freelance medical advice. Shongjog grounds every
answer using **Retrieval-Augmented Generation** over a curated, on-device knowledge base
(see `docs/corpus.md` for the full authoring policy):

- A corpus of ~23 short, verified guidance chunks, each written in simple Bangla and
  tagged with its source (WHO, Bangladesh Red Crescent Society, CDC, national disaster
  guidelines).
- Embedded at build time with **EmbeddingGemma 300M** and shipped as a local vector
  index; retrieval runs on-device via brute-force cosine search.
- Gemma answers **only** from the retrieved, vetted content — grounded, attributable,
  and safe.

**Guardrails (stated explicitly to users and judges):**

- The app **triages and explains; it never diagnoses or prescribes.**
- Emergency numbers (999, 333) are always one tap away and appear on every critical
  answer.
- If retrieval confidence is low, the app says so and directs the user to a
  human/helpline instead of guessing.
- Static "quick cards" (ORS recipe, water purification, snakebite do/don't) remain
  available even if the model fails to load — a safety net that never depends on
  inference.

---

## 5. User Stories

1. As a **rural parent**, I want to ask "আমার বাচ্চার ডায়রিয়া হয়েছে, কি করবো?" in my own
   words and get a grounded, spoken answer in airplane mode, so that I can act correctly
   without internet.
2. As a **low-literacy user**, I want the answer read aloud in Bangla, so that I don't
   need to read text under stress.
3. As an **elderly person**, I want to speak my question hands-free instead of typing, so
   that I can use the app even if I can't type Bangla.
4. As a **community volunteer**, I want pre-loaded ORS/water/snakebite cards that work
   with no model loaded, so that I have guidance even if the model fails to start.
5. As a **person in immediate danger**, I want a single tap to dial 999, so that I can
   reach emergency services without navigating menus.
6. As a **person in immediate danger**, I want a single tap to send a pre-drafted SOS SMS
   with my GPS location, so that responders can find me when voice calls fail.
7. As a **displaced person**, I want to find the nearest cyclone shelter from my current
   GPS, so that I know where to go during a flood or cyclone.
8. As a **judge**, I want the airplane-mode reveal on stage, so that the offline claim is
   self-evidently true rather than asserted.
9. As a **teammate**, I want clear done-criteria per task, so that I can ship my slice
   without ambiguity.
10. As a **content reviewer**, I want every knowledge chunk tagged with its source, so
    that I can verify the corpus against authoritative material.

---

## 6. Scope

### Must-have (core demo)

| # | Feature |
|---|---|
| M1 | On-device Gemma 4 E2B chat that works in **airplane mode** |
| M2 | RAG grounding over the verified emergency knowledge base |
| M3 | Bangla input and output, with text-to-speech read-aloud for accessibility |
| M4 | Always-available static emergency quick cards (work even without the model) |

### Should-have (strong differentiators — **in scope for this hackathon**)

| # | Feature |
|---|---|
| S5 | **Voice input** — speak your emergency hands-free (Vosk-Bangla, fully offline) |
| S6 | **Offline shelter locator** — bundled GeoJSON of cyclone shelters + device GPS, triggered by a Gemma function call |
| S7 | **One-tap emergency dial** (999 / 333) and a **pre-drafted location SOS SMS** (SMS often works on the cellular voice channel when data is down) |

### Stretch (explicitly **deferred** — see Out of Scope)

- Multimodal triage (wound/snake/floodwater photos).
- Pre-season household prep checklist generator.
- "Mark family safe" local status board.

---

## 7. Success Criteria (mapped to judging rubric)

| Criterion | Weight | How Shongjog scores |
|---|---|---|
| Gemma Integration | 30% | End-to-end on-device Gemma family (E2B + EmbeddingGemma + function calling); Gemma is the reason the app works |
| Innovation & Impact | 30% | Offline-first disaster tech; Bangla voice for low-literacy users; grounded triage; addresses recurring, high-stakes national need |
| Functionality | 20% | Demonstrable **in airplane mode** with a real spoken Bangla query |
| Presentation & Writeup | 20% | The airplane-mode reveal is a memorable, self-evident proof point |

**Definition of Done** (submission gate — every box must be checked):

- [ ] App launches in airplane mode on a real arm64 device.
- [ ] Spoken Bangla question → grounded spoken Bangla answer with a 999 reminder.
- [ ] Static quick cards render without the model loaded.
- [ ] Nearest shelter returns a plausible result for current GPS.
- [ ] 999 dial and SOS SMS work end-to-end.
- [ ] 60-second fallback video exists and is playable on the demo device.
- [ ] `docs/spike-results.md` records all spike verdicts and Phase 5 timings.

---

## 8. Constraints

| Constraint | Value | Implication |
|---|---|---|
| Timeline | ~7 working days | Aggressive but feasible; Phase 0 spike gates everything |
| Model size | ~1.5GB | Must be pre-loaded onto the demo device; never rely on venue WiFi |
| Target ABI | `arm64-v8a` only | `.litertlm` will not run on x86 emulators; test on real arm64 hardware from hour zero |
| Runtime RAM | under ~2GB | E2B 4-bit, thinking off, GPU backend, `maxTokens` ~512 |
| Network at runtime | none | Core loop must work in airplane mode; dial/SMS use the cellular voice channel |
| Privacy | all on-device | Voice, GPS, and health details never leave the phone |

---

## 9. Implementation Decisions

These are the product-level decisions; technical rationale lives in
`docs/architecture.md`.

- **Framework:** Flutter (Android-first; iOS-capable but not prioritized for the demo).
- **Generation model:** Gemma 4 E2B, 4-bit, thinking **off**, GPU backend.
- **Retrieval:** EmbeddingGemma 300M (768-dim); brute-force cosine over ~23 vectors
  shipped at build time (no HNSW dependency at this scale).
- **Voice in:** Vosk-Bangla model bundled in assets (true offline, no Google STT
  dependency). See `docs/architecture.md` §Voice for the tradeoffs.
- **Voice out:** `flutter_tts` with `bn-BD` locale; `bn-IN` fallback.
- **Maps:** `flutter_map` + bundled GeoJSON cyclone shelters; offline MBTiles for the
  regions we cover.
- **Actions:** `url_launcher` for `tel:` dial and `sms:` SOS (cellular voice channel).
- **Knowledge base delivery:** build-time embedded (`assets/kb/`); no first-run network
  step. Build pipeline in `tools/build_kb.py` (see `docs/corpus.md`).
- **Architecture:** feature-first, light repository/service seams (no full clean-arch —
  the app is small and the timeline is short).
- **Corpus:** ~23 Bangla chunks curated from WHO / MoDMR / BDRCS / CDC public sources;
  Sehab drafts, Ahnaf reviews/edits, then sign-off before build.
- **Fallbacks:** (1) Gemma 4 E2B → Gemma 3 1B if the spike fails; (2) static quick cards
  always render even if the model fails to load; (3) 60s prerecorded fallback video.

---

## 10. Testing Decisions

What we test, and why:

- **Unit-test retrieval logic** (`test/unit/retriever_test.dart`) — cosine top-k is the
  correctness core of RAG; must be deterministic. No model needed to run it.
- **Unit-test prompt assembly** (`test/unit/prompt_builder_test.dart`) — system prompt +
  context + query must always include the 999 reminder and source brackets.
- **Unit-test nearest-shelter haversine** (`test/unit/nearest_shelter_test.dart`) — pure
  math, fast, deterministic.
- **Unit-test SOS SMS template** (`test/unit/sos_sms_template_test.dart`) — must always
  include name, phone, coords.
- **Widget-test quick cards screen** (`test/widget/quick_cards_screen_test.dart`) — cards
  render with no model dependency, so this is the always-green safety net.
- **Manual E2E in airplane mode** — the only way to truly validate the offline claim;
  timed and recorded in `docs/spike-results.md` (Phase 5). Five scenarios, run multiple
  times on the real demo device.

We do **not** write unit tests around `flutter_gemma`, `vosk`, or `flutter_tts` — those
are third-party runtime surfaces best validated by the Phase 0 spike and the Phase 5 E2E.

---

## 11. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Model won't load / OOM on demo phone | E2B 4-bit, thinking off, GPU backend, small `maxTokens`; fallback to Gemma 3 1B; final fallback = pre-recorded demo |
| 1.5GB download over venue WiFi | Pre-load the model onto the demo device beforehand — the #1 avoidable failure |
| Offline STT unreliable on some devices | Vosk-Bangla for command-style input; typed input always available as fallback |
| Emulator can't run `.litertlm` | Test on a real arm64 device from hour zero (Phase 0 spike A) |
| Model hallucinating medical advice | RAG grounding + static quick cards + triage-not-diagnose guardrails + low-confidence canned response |
| `flutter_gemma` package maturity | Phase 0 spike A is the gate; pivot to Gemma 3 1B if red |
| Vosk Bangla WER too high | Phase 0 spike B is the gate; hybrid (Vosk commands + typed fallback) if red |
| Shelter GeoJSON sparse | Phase 0 spike C; fall back to OSM-overpass data, mark Bangladesh-wide coverage |
| Async coordination drift (3-person team) | Three hard integration checkpoints IC-1/IC-2/IC-3; see `docs/team.md` |

---

## 12. Out of Scope

Deferred to post-hackathon roadmap (see §14):

- Multimodal triage (wound / snake / floodwater photos).
- Pre-season household prep checklist generator.
- "Mark family safe" local status board.
- Regional dialects and additional languages beyond `bn-BD` + English fallback.
- iOS build and App Store submission.
- Backend / cloud sync — by design, there is none.
- Crowd-sourced shelter status.
- Partnerships and distribution (pursued after a working demo).

---

## 13. Hackathon Rule Compliance

- **Gemma 4 is the primary and only LLM** powering the app's generative AI.
- EmbeddingGemma (retrieval), Vosk (STT), `flutter_tts` (TTS), GPS, and mapping are
  **non-generative supporting components** — explicitly permitted, since they support
  Gemma rather than replace it.
- Gemma is **core to the solution**: without on-device Gemma 4, the offline value
  proposition does not exist.

---

## 14. Roadmap Beyond the Hackathon

- Expand and professionally review the verified corpus with BDRCS / disaster-management
  partners.
- Add regional dialects and additional languages.
- Full offline multimodal triage (wounds, snakes, water quality cues).
- Community shelter data and crowd-sourced status once connectivity returns.
- Partnerships with national disaster agencies for distribution and content authority.

---

## 15. Why We Are Building This

Because the technology finally makes it possible. Open, efficient, multimodal models like
Gemma 4 can now run on an ordinary phone with no connection — and that single capability
turns a chronic, deadly gap into a solvable problem. The people most exposed to floods
and cyclones are often the least served by internet-dependent tools. Shongjog puts
trustworthy, spoken, local-language emergency guidance in their hands at the exact moment
everything else goes offline. That is a small app with a disproportionately large
potential to prevent harm.

---

## Further Notes

- The original hackathon pitch content that previously lived in `docs/plan.md` has been
  merged into §1–§4 and §13–§15 above. `docs/plan.md` is deleted once this PRD is
  committed.
- Detailed build tasks: `docs/implementation-plan.md`.
- Technical architecture: `docs/architecture.md`.
- UX/UI design: `docs/design.md`.
- Team division: `docs/team.md`.
- Corpus policy: `docs/corpus.md`.
- Demo runbook: `docs/demo.md`.
