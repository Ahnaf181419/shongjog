# Shongjog (সংযোগ) — Documentation Suite

Welcome to the central, authoritative documentation suite for **Shongjog**, an offline-first, voice-first, bilingual emergency companion application built for Bangladesh.

> **Core Thesis:** *"It works when the internet doesn't."*  
> Shongjog is engineered to ensure that when terrestrial power, cellular networks, and internet backbones fail during natural disasters (cyclones, floods, earthquakes), life-saving triage, verified medical guidance, shelter navigation, and peer-to-peer communications remain 100% operational on-device.

---

## Complete Documentation Index

### 1. Architecture & Core Pipelines
- **[System Architecture Overview](architecture/overview.md)**: High-level system design, module boundaries, pure-Dart decoupling rules, state management, and navigation deduplication (`pushNamedSafe`).
- **[AI & RAG Pipeline](architecture/ai-and-rag.md)**: Gemma 4 on-device execution (LiteRT-LM), 4-tier generation hierarchy, BM25 + EmbeddingGemma vector search (`vectors.bin`), safety guardrails, and dynamic Firestore API key distribution.
- **[Bilingual Localization Architecture](architecture/localization.md)**: `LocaleController`, ARB template pipelines (888 BN / 834 EN strings), dynamic feature loaders, and bilingual AI prompt persona rules.
- **[Historical Architecture Spec](architecture.md)**: Complete foundational technical architecture and module specifications.

### 2. Specialized Features & Subsystems
- **[Specialized AI Domain Modules](features/ai-specialized-modules.md)**: The 7 domain-specific AI modules (Family Disaster Planner, Emergency Kit Generator, Risk Assessment, Damage Scanner, Situation Summary, Shelter Brief, and Safety Re-Ranking).
- **[Voice & Audio Architecture](features/voice-and-audio.md)**: Voice-first assistant, Vosk offline STT model integration status, speech-to-text fallback with Bangla locale resolution, crisis-tuned TTS, and P2P mesh voice calling.
- **[Off-Grid Mesh Networking](features/mesh-networking.md)**: Google Nearby Connections (`P2P_CLUSTER`), Wi-Fi Direct fallback, full-duplex 8 kHz voice calls, and the 5-hop SOS epidemic relay engine with 256-entry LRU deduplication.
- **[Emergency & Life-Safety Systems](features/emergency-and-safety.md)**: Deterministic triage wizard (8 terminal routes), slide-to-confirm 999 emergency dialer, GPS-encoded SOS SMS composer, offline shelter GIS (263 shelters), and quick cards.
- **[Tools, User Profile & Emergency Contacts](features/tools-profile-contacts.md)**: Tools tab 2-column grid, personal and family profile schemas, behavioral intelligence engine, and 22-entry emergency directory.
- **[Live Telemetry Feeds & Coordinator Portal](features/live-feeds-and-coordinator.md)**: 13 fail-soft live telemetry endpoints (GDACS, NASA EONET, USGS, Open-Meteo), coordinator dashboard, distress pings, and authentic Firestore security rules.

### 3. Design System & Accessibility
- **[Design System & Accessibility (WCAG AAA)](design/design-system-and-accessibility.md)**: Ocean Blue identity, strict "Alert Red" invariant, Semantic Fills vs Inks (WCAG AAA contrast), Anek Bangla typography, and 1.5× accessibility scaling.
- **[Design Tokens & Visual Reference](design.md)**: 65 KB exhaustive visual dictionary, component radii, tactile feedback, and palette specification.

### 4. Operations, Training & Quality Assurance
- **[Build, Release & Verification Gates](operations/build-and-release.md)**: Hardware prerequisites (`arm64-v8a`), Firebase configuration, the 10 automated APK verification inspection gates, and the testing suite.
- **[Model Fine-Tuning & Evaluation Benchmark](operations/fine-tuning-and-eval.md)**: 179-example SFT dataset, LoRA fine-tuning pipeline on Gemma 4 E2B, automated LLM-as-a-judge benchmark harness, and the 5-criterion evaluation rubric.
- **[Project Status & Health Snapshot](PROJECT-STATUS.md)**: Living single-entry status report, test pass verification, and subsystem readiness.
- **[Product Requirements Document (PRD)](prd.md)**: Feature requirements, offline constraints, non-functional criteria, and disaster user journeys.
- **[Audit Log (2026-09-08)](audits/2026-09-08-feature-navigation-audit.md)**: Full 14-finding UI, navigation, and life-safety audit.
- **[Upgrade Summary (13 Rounds)](UPGRADE-SUMMARY-2026-09-08.md)**: Comprehensive scorecard of the 13 audit fix rounds.
- **[Contributing Guide](CONTRIBUTING.md)**: Local developer setup, Git conventions, testing rules, and PR flow.
- **[Changelog](CHANGELOG.md)**: Chronological Keep-a-Changelog release entries.

### 5. Operational Runbooks & Guides (`guides/`)
- **[Offline Model Setup Guide](guides/OFFLINE-MODEL-SETUP.md)**: On-device Gemma 4 provisioning via LiteRT-LM from scratch.
- **[Demo Runbook & Fallback Playbook](guides/demo.md)**: Demo narrative arc, judge Q&A handling, and live presentation protocols.
- **[Pre-Demo Checklist](guides/PRE-DEMO.md)**: Device pre-flight checklist before live presentations.
- **[Knowledge Base Guide](guides/corpus.md)**: 48-chunk corpus schema, topic categorization, and vetting criteria.
- **[Corpus Review Record](guides/corpus-review.md)**: Medical and disaster response domain expert review notes.
- **[AI Context Anchor](guides/ai_context.md)**: AI developer session context anchor and history.

### 6. Hackathon Submission, Presentation & Media
- **[Kaggle Hackathon Writeup](kaggle-writeup.md)**: Official submission narrative covering Gemma 4 on-device architecture, P2P mesh, and live telemetry.
- **[Exhibition Pitch Deck (PDF)](presentation/Shongjog-Exhibition-Deck.pdf)**: Official exhibition slide deck.
- **[Interactive HTML Presentation](presentation/deck.html)**: Browser-based slide deck with custom typography and graphics.
- **[Presentation Script](presentation/SCRIPT.md)**: Timed speaker script for live demonstrations.
- **[Application Screenshots](screenshots/)**: 28 full-resolution screenshots documenting every screen in the application.

### 7. Educational Companion Curriculum
- **[Educational Companion Platform (`site/`)](educational/companion-site.md)**: Zero-build static architecture, 48-lesson interactive masterclass curriculum mapping 1-to-1 with Flutter subsystems, and automated lesson validation.

---

## High-Level System Landscape

```
                                      USER (Voice / Text / Touch)
                                                   │
                                                   ▼
                                         [ Presentation Layer ]
                            (MaterialApp, ThemeController, LocaleController, MainShell)
                                                   │
                      ┌────────────────────────────┴────────────────────────────┐
                      ▼                                                         ▼
             [ Core & Offline Logic ]                                 [ Cloud & Online Feeds ]
     ┌──────────────────────────────────────┐                  ┌──────────────────────────────────────┐
     │ • ModelManager (LiteRT-LM Gemma 4)   │                  │ • CloudAIService (Gemini 3.1 Flash)  │
     │ • Offline RAG (BM25 + Vectors)       │                  │ • Live Telemetry (13 Endpoints)      │
     │ • 7 Specialized AI Modules           │                  │ • Multimodal Damage Scanner (Vision) │
     │ • MeshCommService (Nearby P2P Calls) │                  │ • Firestore Coordinator Sync         │
     │ • Triage Wizard (Deterministic)      │                  │ • Remote API Key Provisioning        │
     │ • Shelter GIS & Offline Tile Cache   │                  │ • Open-Meteo & NASA/GDACS Feeds      │
     └──────────────────────────────────────┘                  └──────────────────────────────────────┘
```

---

## Key Metrics Summary

- **Primary Target Architecture:** Android `arm64-v8a` (minSdk 26).
- **On-Device LLM:** Google Gemma 4 E2B (~2.47 GB download) via LiteRT-LM (`.litertlm`).
- **Knowledge Base:** 48 verified Bangla disaster & medical chunks across 22 topics.
- **Vector Search:** Bundled 768-dimensional L2-normalized float32 vectors (`assets/kb/vectors.bin`).
- **Locales:** Bilingual with 888 Bangla (`bn-BD`) and 834 English (`en-US`) strings.
- **Test Suite:** 114 test files (~901 unit/widget tests passing).
- **Curriculum:** 48 interactive lessons across 8 phases in `site/`.
