# Shongjog — Architecture

> **Internal team-facing document.** Technical architecture, module boundaries, data
> flow, build pipeline, constraints, and failure modes.

This document applies Clean Architecture's **dependency rule** (dependencies only point
inward) adapted to Flutter — not full DDD, but enough seam to keep the on-device model,
RAG, and UI swappable during the spike and after. The build pipeline (Python → embedded
assets) is treated as a first-class component because it determines the corpus's shape.

Companion docs: product scope in `docs/prd.md`; build tasks in
`docs/implementation-plan.md`; corpus policy in `docs/corpus.md`; UX in `docs/design.md`.

---

## 1. System Diagram

```
[User: voice or text, in Bangla]
        |
        v
Speech-to-text (Vosk-Bangla, fully offline; typed input as fallback)
        |
        v
Query ──> EmbeddingGemma 300M ──> vector ──> brute-force cosine search
        |                                         |
        |                      top-3 verified emergency chunks
        v                                         |
Gemma 4 E2B  <──── retrieved context + Bangla system prompt
        |
        +──> grounded step-by-step Bangla answer ──> screen + TTS (read aloud)
        |
        +──> function call ──> [nearest shelter map] / [prepare SOS SMS]
        |
        +──> (low confidence) ──> canned "call 999 / talk to a human" response

===================== everything above requires NO network =====================
                                                                                 |
Calls (tel:999) and SOS SMS (sms:999?body=...) use the cellular voice channel  <-+
which frequently survives when mobile data is down.
```

---

## 2. Tech Stack

| Layer | Choice | Rationale |
|---|---|---|
| Framework | Flutter 3.x, Dart 3.12+ | Single codebase, strong typing, mature widget toolkit; Android-first, iOS-capable |
| Generation model | Gemma 4 E2B (4-bit, thinking off, GPU) | Smallest Gemma 4 that still grounds well in Bangla; fits ~2GB RAM |
| On-device runtime | `flutter_gemma` (LiteRT-LM) | Only mature Flutter binding for Gemma on Android arm64; validated by Phase 0 spike A |
| Retrieval / embeddings | `flutter_gemma` embedder API, EmbeddingGemma 300M (768-dim) | Same runtime family as the generator; one integration surface |
| Voice in | Vosk + bundled `vosk-model-small-bn-*` | True offline; Google STT (`speech_to_text`) needs network on many Androids — unacceptable for the offline thesis |
| Voice out | `flutter_tts` (`bn-BD`, `bn-IN` fallback) | Built into the platform; no extra download |
| Location | `geolocator` | Standard, well-maintained |
| Maps | `flutter_map` + bundled MBTiles | No Google Maps dependency; renders offline tiles we ship |
| Actions | `url_launcher` (`tel:`, `sms:`) | Uses the cellular voice channel that survives data outages |
| Model management | `background_downloader`, `path_provider`, `shared_preferences` | 1.5GB one-time download; resume on failure; persist local path |
| Retrieval index | brute-force cosine (no HNSW) | N≈23 vectors; brute force is faster and simpler than a real ANN index |
| Build pipeline | Python 3 + `sentence-transformers` | EmbeddingGemma via HF `transformers`; runs on a dev laptop, ships vectors as a binary asset |

### Why not alternatives

- **`tflite_flutter` directly?** Reinvents the LiteRT-LM session management that
  `flutter_gemma` already wraps. Not worth the time on a 7-day timeline.
- **Google STT (`speech_to_text`)?** Beautiful API, but on many Android OEM builds it
  silently falls back to a network recognizer. That breaks the offline claim. Vosk's
  bundled model is uglier but verifiably offline.
- **HNSW (`hnswlib`)?** At N=23 vectors, brute-force cosine is O(N·D) ≈ 17K multiplies —
  sub-millisecond on any phone. Adding a native ANN dep is pure overhead.
- **Runtime embedding (lazy download)?** Reintroduces a first-run network step that may
  fail in a real disaster. Build-time embedding makes the KB part of the APK.

---

## 3. Architectural Layers (Flutter adaptation of the dependency rule)

```
+-----------------------------------------------------------+
|  Presentation (lib/features/*)  — Widgets, screens        |  volatile, swap freely
+-----------------------------------------------------------+
|  Application (lib/features/*/repositories) — orchestration|  use-case seams
+-----------------------------------------------------------+
|  Core / Domain (lib/core, lib/rag, lib/knowledge)         |  stable, no Flutter deps in pure logic
|    - Result<T,E>, AppError                                |
|    - BruteForceRetriever, Chunk, RetrievalHit             |
|    - prompt_builder (pure string assembly)                |
+-----------------------------------------------------------+
|  Infrastructure / Adapters (lib/features/voice,           |  wraps external packages
|    lib/features/shelter, lib/core/model_manager)          |
+-----------------------------------------------------------+
```

**Rule:** the inner layers (`core`, `rag`, `knowledge`) must not import `flutter_gemma`,
`vosk`, `geolocator`, or `flutter_tts`. They take plain Dart types (vectors as
`Float32List`, queries as `String`). The adapter layer (repositories, services) wraps the
packages and hands plain types inward.

This keeps the spike-pivot survivable: if we swap Gemma 4 E2B → Gemma 3 1B, or Vosk → a
different STT, only the adapter layer changes. The retriever, prompt builder, and shelter
math are untouched.

---

## 4. Module Map

```
lib/
├── app/                      Presentation shell
│   ├── app.dart              MaterialApp, theme, routing
│   ├── theme.dart            Bangla-first calm palette, type scale
│   └── router.dart           Route table
├── core/                     Cross-cutting, no Flutter deps in pure parts
│   ├── model_manager.dart    Adapter: Gemma download/load lifecycle
│   ├── connectivity.dart     Online/offline indicator
│   ├── errors.dart           AppError sealed hierarchy
│   └── result.dart           Result<T, E> type
├── features/
│   ├── chat/
│   │   ├── chat_repository.dart   Application: RAG + Gemma call
│   │   ├── chat_screen.dart       Presentation
│   │   ├── chat_input.dart        Presentation
│   │   └── message_bubble.dart    Presentation
│   ├── voice/
│   │   ├── stt_service.dart       Adapter: Vosk Bangla
│   │   └── tts_service.dart       Adapter: flutter_tts
│   ├── shelter/
│   │   ├── shelter_repository.dart Adapter: loads bundled GeoJSON
│   │   ├── shelter_model.dart     Domain: Shelter value object
│   │   ├── shelter_map_screen.dart Presentation
│   │   └── nearest_shelter.dart   Domain: haversine ranking (pure)
│   ├── quick_cards/
│   │   ├── cards_data.dart        Domain: static Bangla cards (pure)
│   │   └── quick_cards_screen.dart Presentation
│   └── emergency/
│       ├── emergency_actions.dart Adapter: url_launcher dial
│       └── sos_sms_template.dart  Domain: SMS body builder (pure)
├── rag/                      Retrieval core (pure, except embedder)
│   ├── embedder.dart         Adapter: EmbeddingGemma client
│   ├── retriever.dart        Domain: BruteForceRetriever (pure)
│   ├── prompt_builder.dart   Domain: system + context assembly (pure)
│   └── types.dart            Domain: Chunk, RetrievalHit
└── knowledge/                On-device KB
    ├── kb_loader.dart        Adapter: rootBundle → in-memory index
    └── kb_index.dart         Domain: wraps retriever + chunks
```

**Pure (no Flutter / no package deps):** `lib/rag/retriever.dart`,
`lib/rag/prompt_builder.dart`, `lib/rag/types.dart`,
`lib/features/shelter/nearest_shelter.dart`, `lib/features/shelter/shelter_model.dart`,
`lib/features/emergency/sos_sms_template.dart`, `lib/features/quick_cards/cards_data.dart`.

These are the unit-testable correctness core.

---

## 5. On-Device Inference Pipeline

```
First run:
  ModelManager.ensureModel()
    ├── if File(modelPath).exists() && size > 100MB → skip download
    └── else → background_downloader fetches .task, persists to app docs dir

Per query:
  ChatRepository.ask(userQuery)
    1. qVec = embedder.embed(userQuery)               [EmbeddingGemma 300M]
    2. hits  = kb.retriever.topK(qVec, k:3, floor:0.35)
    3. if hits.isEmpty → return canned low-confidence response
    4. prompt = buildPrompt(query, hits)              [system + context + query]
    5. gemma  = modelManager.initialize()             [lazy, cached]
    6. session = gemma.createSession()
    7. return session.getResponse(prompt)
    8. (UI) ttsService.speak(answer)                  [bn-BD]
```

**Session reuse:** `FlutterGemma.instance` is initialized once and cached in
`ModelManager`. `createSession()` may be called per query or reused; we reuse one session
and inject context per turn to keep memory flat.

**Cold start:** first `initialize()` loads the model into RAM — expect 3–10s depending on
device. The UI must surface "AI প্রস্তুত হচ্ছে..." during this window. See `docs/design.md`
§Microinteractions.

---

## 6. Build Pipeline (Python → embedded assets)

The KB is built offline on a dev laptop and shipped inside the APK. Nothing about the
corpus depends on the phone.

```
tools/corpus.json   (authored, reviewed, signed off)
        |
        v
tools/build_kb.py
        |   loads EmbeddingGemma 300M via sentence-transformers
        |   embeds (text + keywords_bn) per chunk, L2-normalized
        v
assets/kb/corpus.json    (copy of source, shipped as-is for transparency)
assets/kb/vectors.bin    (float32 [N, 768], row-major)
        |
        v
Flutter bundle (rootBundle.load) at runtime
```

**Why build-time:** the corpus is small and authoritative; shipping it inside the APK
guarantees the KB is present in airplane mode with no first-run network step. A real
disaster is the worst time to discover the KB failed to download.

**Verification:** `tools/verify_kb.py` runs 7 hand-authored Bangla queries through the
embedded index and asserts the top-1 topic matches expectations. Any `BAD` line blocks
the build. See `docs/corpus.md` §Review Process.

---

## 7. Data Model

### `Chunk` (`lib/rag/types.dart`)

```dart
class Chunk {
  final String id;            // stable snake_case, e.g. 'ors_recipe_basic'
  final String topic;         // 'water' | 'ors' | 'diarrhea' | ...
  final String source;        // short citation, e.g. 'WHO Cholera FS, 2024'
  final String text;          // 60-120 words, simple Bangla
  final List<String> keywordsBn; // 5-10 keywords, aid fuzzy STT retrieval
}
```

### `RetrievalHit`

```dart
class RetrievalHit {
  final Chunk chunk;
  final double score;   // cosine similarity, [−1, 1]; we threshold at 0.35
}
```

### `Shelter` (`lib/features/shelter/shelter_model.dart`)

```dart
class Shelter {
  final String name;       // English / romanized
  final String nameBn;     // Bangla
  final double lat;
  final double lon;
  final int? capacity;     // nullable — not all sources carry it
  final String source;     // 'OSM' | 'MoDMR' | 'BDRCS'
}
```

### `RankedShelter`

```dart
class RankedShelter {
  final Shelter shelter;
  final double km;         // haversine distance from user GPS
}
```

### GeoJSON feature contract (`assets/shelter/cyclone_shelters.geojson`)

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [90.40, 23.81] },
      "properties": {
        "name": "Khulna Shelter A",
        "name_bn": "খুলনা শেল্টার এ",
        "capacity": 1200,
        "source": "MoDMR"
      }
    }
  ]
}
```

Coordinates are `[lon, lat]` per the GeoJSON spec — the loader maps them to
`Shelter(lat: coords[1], lon: coords[0])`.

---

## 8. Build & Runtime Constraints

| Constraint | Value | Where enforced |
|---|---|---|
| Android ABI | `arm64-v8a` only | `android/app/build.gradle.kts` → `ndk { abiFilters += "arm64-v8a" }` |
| Model file | ~1.5GB, `.task` format | shipped pre-loaded on demo device; downloaded via `background_downloader` for real users |
| Runtime RAM | under ~2GB | 4-bit quantization + thinking off + `maxTokens` 512 |
| Vosk model | `vosk-model-small-bn-*`, ~50MB | bundled in `assets/vosk/` |
| KB assets | `corpus.json` (~30KB) + `vectors.bin` (~75KB) | bundled in `assets/kb/` |
| Shelter data | `cyclone_shelters.geojson` (variable, target < 1MB) | bundled in `assets/shelter/` |
| Cold start | ≤ 15s acceptable; UI shows progress | Phase 5 measurement |
| Steady-state Q→A | ≤ 8s acceptable | Phase 5 measurement |

---

## 9. Failure Modes & Fallbacks

| Failure | Detection | Fallback |
|---|---|---|
| Model won't load / OOM | `ModelManager.initialize()` throws | Gemma 3 1B; if that also fails, hide the chat affordance and rely on static quick cards |
| 1.5GB download fails on venue WiFi | download progress stalls | Pre-load before the event; final fallback = prerecorded 60s video |
| Low retrieval confidence | `topK` returns empty (all scores < 0.35) | Return canned Bangla response: "আমার কাছে এই তথ্য নেই, অনুগ্রহ করে স্বাস্থ্যকর্মী বা ৯৯৯ এ যোগাযোগ করুন" |
| Vosk STT produces garbage | WER > 0.5 on the 10 spike utterances | Hybrid mode: Vosk for short command-style phrases, typed input for freeform; final fallback = typed input only |
| GPS unavailable | `geolocator` permission denied or timeout | Show shelter map centered on Bangladesh default (23.8, 90.4); disable "nearest" sort |
| GeoJSON sparse / wrong | Phase 0 spike C spot-check fails | Use OSM-overpass data only; mark coverage as Bangladesh-wide in the UI |
| Model hallucinates medical advice | manual review of 20 test queries | Strengthen system prompt; raise cosine floor to 0.40; expand corpus |
| Network silently leaks | airplane-mode E2E test fails | Audit every package's network calls; remove any non-essential http |
| TTS `bn-BD` unavailable on device | `flutter_tts` init returns missing locale | Fall back to `bn-IN`; if both missing, disable speak button and rely on on-screen text |

---

## 10. Performance Budget

| Stage | Budget | Measurement |
|---|---|---|
| App cold start to first frame | ≤ 2s | `flutter run --trace-startup` |
| KB load from asset | ≤ 200ms | instrumented in `KnowledgeBase.load()` |
| EmbeddingGemma query embed | ≤ 300ms | instrumented in `Embedder.embed()` |
| Cosine top-3 retrieval | < 5ms | sub-millisecond expected at N=23 |
| Gemma first token | ≤ 4s | Phase 5 timing |
| Gemma full answer (≤ 512 tokens) | ≤ 8s | Phase 5 timing |
| TTS first audio | ≤ 500ms | instrumented in `TtsService.speak()` |

Anything over budget in Phase 5 is a P1 bug for the demo; P0 if it breaks the airplane-mode
flow.

---

## 11. Observability

On a hackathon timeline we don't ship a real telemetry pipeline, but we do instrument
key timings to a local log file (`docs/spike-results.md` for the spike; an in-app debug
overlay for Phase 5). Specifically:

- `ModelManager.initialize()` cold-start duration.
- `ChatRepository.ask()` end-to-end duration per query.
- `Retriever.topK()` hit count and top score per query (for low-confidence audits).
- `SttService.listen()` final transcript vs. expected (spike only).

This data feeds the Phase 5 demo-hardening decisions and the judge Q&A ("how fast does it
answer?").

---

## 12. Security & Privacy

- **No network in the core loop.** Confirmed by airplane-mode E2E in Phase 5.
- **Voice, GPS, and health queries never leave the device.** No analytics, no crash
  reporting, no cloud model.
- **Permissions** (`AndroidManifest.xml`): `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`,
  `CALL_PHONE`, `SEND_SMS`, plus `INTERNET` (used only for the one-time model download;
  gated behind `ModelManager`).
- **SMS body** contains the user's name, phone, and GPS — all user-supplied or
  device-derived; no third-party data.
- **Corpus** is public-source material; attribution preserved per chunk and shown to the
  user when relevant.

---

## 13. Open Questions (to resolve during execution)

1. Does `flutter_gemma`'s embedder API expose EmbeddingGemma 300M cleanly, or do we need
   a separate model file path? Resolved in Phase 0 spike A.
2. Does Vosk's small Bangla model handle our 10 spike utterances at acceptable WER?
   Resolved in Phase 0 spike B.
3. Can we bundle MBTiles for the whole Bangladesh bounding box, or only coastal districts
   (Khulna, Barisal, Chittagong)? Resolved in Phase 4.2.
4. Should the chat session persist across app restarts (so the user's last question is
   visible on relaunch)? Lean: yes, via `shared_preferences` for the message list only
   (never model state).
