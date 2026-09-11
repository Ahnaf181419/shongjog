# Shongjog (সংযোগ) — Documentation Suite

Welcome to the central documentation suite for **Shongjog**, an offline-first, voice-first, bilingual emergency companion application built for Bangladesh.

> **Core Thesis:** *"It works when the internet doesn't."*  
> Shongjog is engineered to ensure that when terrestrial power, cellular networks, and internet backbones fail during natural disasters (cyclones, floods, earthquakes), life-saving triage, verified medical guidance, shelter navigation, and peer-to-peer communications remain 100% operational on-device.

---

## Documentation Index

| Section | Document | Description |
|---|---|---|
| **Architecture** | [System Architecture Overview](architecture/overview.md) | High-level system design, module boundaries, layers, dependency rules, and offline-first paradigms. |
| **Architecture** | [AI & RAG Pipeline](architecture/ai-and-rag.md) | Gemma 4 on-device execution, LiteRT-LM runtime, 4-tier fallback hierarchy, BM25 + EmbeddingGemma vector retrieval, and safety guardrails. |
| **Features** | [Off-Grid Mesh Networking](features/mesh-networking.md) | Google Nearby Connections P2P clustering, Wi-Fi Direct fallback, full-duplex 8 kHz voice calls, and 5-hop SOS relay engine. |
| **Features** | [Emergency & Safety Systems](features/emergency-and-safety.md) | Deterministic triage wizard, slide-to-confirm 999 emergency dialer, GPS-encoded SOS SMS, offline shelter GIS, and quick cards. |
| **Features** | [Live Feeds & Coordinator Portal](features/live-feeds-and-coordinator.md) | 13 live telemetry endpoints, Firestore coordinator dashboard, safe/danger tracking, and access control security rules. |
| **Operations** | [Build, Release & Verification Gates](operations/build-and-release.md) | Build prerequisites, Firebase configuration, 10-gate release verification script, testing matrix, and device provisioning. |

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
     │ • MeshCommService (Nearby P2P)       │                  │ • Firestore Coordinator Sync         │
     │ • Triage Wizard (Deterministic)      │                  │ • Remote API Key Provisioning        │
     │ • Shelter GIS & Offline Tile Cache   │                  │ • Open-Meteo & NASA/GDACS Feeds      │
     └──────────────────────────────────────┘                  └──────────────────────────────────────┘
```

---

## Quick Reference & Project Snapshot

- **Primary Target:** Physical Android devices running **`arm64-v8a`** (minSdk 26).
- **Core Framework:** Flutter 3.x / Dart `^3.12.0`.
- **Knowledge Base:** 48 verified Bangla disaster/medical chunks across 22 topics.
- **Vector Search:** Bundled 768-dimensional L2-normalized float32 vectors (`vectors.bin`).
- **Locales:** Bilingual with complete support for Bangla (`bn-BD`) and English (`en-US`).
- **Test Suite:** 114 test files (~901 unit/widget tests passing).
