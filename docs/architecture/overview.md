# System Architecture Overview

## 1. Architectural Philosophy

Shongjog is architected around an **offline-first, zero-failure** design philosophy tailored for low-connectivity and emergency scenarios in Bangladesh:

1. **Local-First & Resilient Tiers**: Critical operations default to on-device capabilities when connectivity is absent. When online, cloud capabilities enrich the experience (instant LLM responses, live hazard telemetry, real-time safety status syncing), while every subsystem maintains a strict, deterministic offline fallback.
2. **Deterministic Fallbacks (Fail-Soft)**: Critical life-safety features must never fail with an unhandled exception or blank screen. If an LLM inference times out or fails, the system falls back to a deterministic verified chunk, rule-based calculator, or hardcoded emergency protocols ("Call 999").
3. **Pure-Dart Decoupling**: Core business logic, knowledge ingestion, vector similarity, and retrieval algorithms remain strictly decoupled from Flutter UI code and third-party platform plugins.

---

## 2. Codebase Layering & Directory Structure

The Dart codebase resides in `lib/` and is strictly partitioned into distinct layers:

```
lib/
├── app/                  # Application initialization, routing, theming & root shell
│   ├── main_shell.dart   # Bottom navigation shell (5 tabs) + persistent drawer
│   ├── router.dart       # Named route definitions & pushNamedSafe deduplication
│   ├── theme.dart        # High-contrast accessible color palette & WCAG AAA tokens
│   └── startup_gate.dart # Onboarding & initial model check gate
├── core/                 # App-wide singleton services & state controllers
│   ├── model_manager.dart# Local on-device LLM management (Gemma 4 / LiteRT-LM)
│   ├── theme_controller.dart # 3-state theme management (System / Light / Dark)
│   ├── locale_controller.dart# Bilingual switching (Bangla / English)
│   ├── connectivity_provider.dart # Network monitoring & telemetry
│   └── firebase_auth_service.dart# Anonymous authentication & ownerUid tagging
├── knowledge/            # Knowledge Base data models & disk loaders
│   ├── knowledge_base.dart      # In-memory corpus store (48 verified chunks)
│   └── vector_store.dart        # 768-dim float32 binary embedding vector store
├── rag/                  # PURE DART retrieval & prompt engineering pipeline
│   ├── retriever.dart           # Keyword retriever (BM25-lite / TF-IDF hybrid)
│   ├── embedding_retriever.dart # Cosine vector similarity search over vectors.bin
│   ├── prompt_builder.dart      # Prompt formatting with safety guardrails
│   └── rumour_checker.dart      # Local disaster rumor verification logic
├── features/             # Feature-specific modules (presentation + local repositories)
│   ├── chat/             # AI emergency assistant conversation
│   ├── planner/          # Family Disaster Planner, Kit Generator, Risk Assessment
│   ├── damage_scanner/   # Vision-based structural damage classification
│   ├── intelligence/     # Situation summary & proactive behavioral intelligence
│   ├── voice/            # Bangla STT (Vosk/speech_to_text) & TTS services
│   ├── mesh_comm/        # P2P Nearby Connections, 8 kHz voice calls & SOS relay
│   ├── shelter/          # Offline shelter GIS, OSRM routing, cached tiles
│   ├── triage/           # Pure-Dart deterministic first-aid decision tree
│   ├── emergency/        # Slide-to-confirm 999 dialer & SOS SMS composer
│   ├── hazards/          # Live disaster feeds (GDACS, NASA EONET, USGS)
│   ├── weather/          # Open-Meteo weather & marine surge feeds
│   ├── admin/            # Coordinator emergency broadcast & status dashboard
│   ├── safe_beacon/      # SafetyStatusScreen & SMS retry queue
│   └── tools/            # ToolsScreen grid hosting the specialized AI tools
└── l10n/                 # Localization ARB templates (app_bn.arb, app_en.arb)
```

---

## 3. The Pure-Dart Architectural Boundary Rule

To maintain testability, stability, and speed:

> **The Boundary Rule:**  
> Files in `lib/core/` (interfaces/pure logic), `lib/rag/`, and `lib/knowledge/` must contain **ZERO** Flutter framework (`package:flutter/*`) and **ZERO** native plugin imports.

### Why this matters:
- Unit tests run in microseconds without booting the Flutter test environment or mocking platform channels.
- RAG algorithms, prompt sanitization, vector normalization, and decision logic can run on headless servers, CLI test harnesses, or non-Flutter environments.
- Native plugins (e.g. `flutter_gemma`, `geolocator`, `nearby_connections`) are isolated behind clean facade adapters in the outer layers.

---

## 4. State Management & Data Flow

Shongjog avoids bloated state-management frameworks in favor of lightweight, predictable, reactive patterns:

- **Singletons & Controllers**: Central services (`ModelManager`, `ThemeController`, `LocaleController`, `ConnectivityProvider`) are implemented as controllers backed by `ChangeNotifier` or `ValueNotifier`.
- **Repository Pattern**: Features interact with underlying data sources through repositories (e.g., `ChatRepository`, `ShelterRepository`, `HazardsRepository`, `ContactsRepository`).
- **Encapsulated Persistence**:
  - `SharedPreferences` for user preferences (locale, theme, voice toggles, onboarding state, user profile).
  - `flutter_secure_storage` (backed by Android Keystore) for remote Cloud AI API keys.
  - Local JSON storage (`ChatStore`) for offline message persistence.

---

## 5. UI Shell & Navigation Pattern

The primary user experience is structured around the `MainShell` ([`lib/app/main_shell.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/app/main_shell.dart)):
1. **5 Bottom Navigation Tabs**:
   - **হোম (Home)**: High-level dashboard, status beacon summary, slide-to-confirm 999 dialer, and quick access cards.
   - **এআই (AI Chat)**: Conversational emergency assistant backed by RAG and dual cloud/local inference.
   - **টুলস (Tools)**: 2-column grid linking to the 5 specialized AI tools: Family Disaster Planner, Emergency Kit Generator, Risk Assessment, Damage Scanner, and Situation Summary.
   - **কার্ড (Quick Cards)**: 25 offline expandable first-aid and hazard quick-reference guides.
   - **আশ্রয় (Shelters)**: Offline GIS map and list of 263 cyclone/flood shelters.
2. **Navigation Deduplication (`pushNamedSafe`)**:
   - All critical navigation calls route through `pushNamedSafe` in [`lib/app/router.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/app/router.dart), preventing rapid multi-tap screen stacking and race conditions.
