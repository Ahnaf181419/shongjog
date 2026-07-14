# Shongjog

**An on-device, Bangla, voice-first flood/cyclone emergency companion powered by Gemma 4
— it works when the internet doesn't.**

Built for the *Build with Gemma 4: ML, AI, Deep Learning & NLP Community Hackathon*
(Bangladesh). Flutter app, Gemma 4 E2B running fully on-device, RAG over a verified
Bangla corpus, Vosk-Bangla speech-to-text, and offline maps. The entire core loop runs in
airplane mode.

> The single sentence that defines this project: **it works when the internet doesn't.**

## Documentation

All project docs live in [`docs/`](./docs). Start there.

| Doc | What it covers |
|---|---|
| [`docs/PROJECT-STATUS.md`](./docs/PROJECT-STATUS.md) | **START HERE** — one-shot status report + handoff doc |
| [`docs/prd.md`](./docs/prd.md) | Product requirements — problem, scope, success criteria, risks |
| [`docs/architecture.md`](./docs/architecture.md) | Technical architecture — stack, pipeline, data model, constraints |
| [`docs/design.md`](./docs/design.md) | UX/UI design — principles, personas, flows, visual system, accessibility |
| [`docs/team.md`](./docs/team.md) | Work division — roles, per-person checklist, integration checkpoints, decision log |
| [`docs/corpus.md`](./docs/corpus.md) | Knowledge base — topic coverage, schema, authoring guide, source policy |
| [`docs/demo.md`](./docs/demo.md) | Demo script — live scenario, judge Q&A, fallback playbook |
| [`docs/spike-results.md`](./docs/spike-results.md) | Spike + Phase 5 measurement log template |
| [`docs/PRE-DEMO.md`](./docs/PRE-DEMO.md) | Pre-demo operational runbook (device setup, rehearsal) |
| [`docs/POST-HACKATHON.md`](./docs/POST-HACKATHON.md) | Long-term roadmap, partner plan, red lines |
| [`docs/implementation-plan.md`](./docs/implementation-plan.md) | Task-by-task build plan (Phase 0 → Phase 5) + live status table |
| [`CHANGELOG.md`](./CHANGELOG.md) | Hackathon-progress changelog (build phases) |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | For future maintainers — dev setup, conventions, red lines |

## Quick Start

```bash
flutter pub get
flutter analyze          # zero issues
flutter test             # 81 pass, 1 skip
flutter run -d <arm64-device-id> --release
```

> **Note:** `.litertlm` inference is `arm64-v8a` only. A standard x86 emulator will not
> run the model — test on a real arm64 Android device. The Android build is restricted
> via `abiFilters 'arm64-v8a'` in `android/app/build.gradle.kts`.

## Features

| Feature | Status |
|---|---|
| Bangla-first UI with 3-way theme (light/dark/system) | ✅ Done |
| 4-tab bottom nav (Home / AI / Cards / Shelter) | ✅ Done |
| First-run onboarding (3 pages: welcome → permissions → model download) | ✅ Done |
| Static quick cards — 8 expandable Bangla emergency guides (no model needed) | ✅ Done |
| RAG chat with keyword retrieval over 23-chunk verified Bangla corpus | ✅ Done |
| Cloud AI fallback (Gemini 3.5-flash → 3.1-flash-lite) when online | ✅ Done |
| On-device Gemma 4 E2B integration (ModelManager singleton, Range-resume download) | ✅ Done |
| Chat persistence across app restarts (JSON-based ChatStore) | ✅ Done |
| Typewriter text reveal for AI responses | ✅ Done |
| Bangla TTS with auto-read toggle | ✅ Done |
| Voice input via STT provider abstraction (speech_to_text online, Vosk stub offline) | ✅ Done |
| Shelter map with map/list toggle, connectivity-aware tiles, distance ranking | ✅ Done |
| Emergency slide-to-confirm dial (999) with real GPS | ✅ Done |
| SOS SMS with location-encoded body | ✅ Done |
| Settings screen with model download card, voice prefs, clear-cache | ✅ Done |
| Offline mesh communication (nearby_connections P2P, radar screen) | ✅ Done |
| Emergency contacts (add/list/call) | ✅ Done |
| Phase 0 device spikes (Gemma E2B TTR/RAM, Vosk WER, shelter spot-check) | 🔴 Needs device |
| Airplane-mode E2E demo test | 🔴 Needs device |
| 60s fallback demo video | 🔴 Pending |

## Status

**Active development.** 16+ tasks complete, 81 tests passing, `flutter analyze` clean.
Remaining work is device-dependent (Phase 0 spikes, Phase 5 demo hardening) — see
[`docs/implementation-plan.md`](./docs/implementation-plan.md) for the full status table.
