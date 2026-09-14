# Educational Companion Platform (`site/`)

In addition to the mobile client, the Shongjog project contains a full-scale educational curriculum and interactive companion website located in [`site/`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/site) and deployed at [shongjog-lesson-guide.netlify.app](https://shongjog-lesson-guide.netlify.app/).

---

## 1. Architectural Philosophy & Zero-Build Design

The companion platform is intentionally built with **zero external dependencies and zero build steps**:

- **Pure Web Standards**: Authored in pure HTML5, vanilla CSS3, and modern vanilla JavaScript.
- **No Node.js / NPM Build Step**: Runs directly off static file hosting (Netlify, GitHub Pages, or any local HTTP server).
- **Graceful DOM Wrapping**: `site.js` dynamically wraps plain semantic markdown/HTML into an interactive application shell (sidebar navigation, top bar, progress tracker, and interactive JSON-driven quizzes in `quiz.js`). If JavaScript is disabled, the pages remain cleanly formatted and readable.
- **Local State**: Persists lesson completion progress and light/dark theme preference in browser `localStorage`.

---

## 2. Curriculum Structure: The 8 Phases & 48 Lessons

The curriculum ("Own the Shongjog AI Stack") maps 1-to-1 against the subsystems implemented in the Flutter application:

```
[ Phase 1: On-Device Local LLM ] ──────────► LiteRT-LM, Gemma 4 E2B, KV cache lifecycle
[ Phase 2: Cloud Fallback Tier ] ──────────► Gemini REST client, zero binary API key, vision triage
[ Phase 3: Offline RAG Pipeline ] ────────► 48-chunk corpus, BM25 + 768-dim vector embeddings
[ Phase 4: Offline Shelter GIS ] ─────────► GeoJSON parser, Haversine spherical ranking, OSRM
[ Phase 5: P2P Mesh Communication ] ──────► Nearby Connections, 8 kHz voice calls, multi-hop SOS
[ Phase 6: Deterministic Life-Safety ] ───► Pure-Dart triage decision tree, 999 slide dialer
[ Phase 7: Live Telemetry & EOC ] ────────► 13 live telemetry endpoints, Firestore security rules
[ Phase 8: Hardened Release Pipeline ] ──► 10-gate APK verification, automated eval harness
```

### Lesson & Codebase Cross-Reference

| Phase | Lesson Range | Core Codebase Mapping | Topics Covered |
|---|---|---|---|
| **Phase 1** | Lessons `0001`–`0007` | `lib/core/model_manager.dart` | Local inference on `arm64-v8a`, tensor allocation, 1024-token window limits, memory leakage prevention. |
| **Phase 2** | Lessons `0008`–`0011` | `lib/features/cloud_ai/` | Gemini REST integration, dynamic Firestore key fetching, base64 multimodal damage scanner. |
| **Phase 3** | Lessons `0012`–`0018` | `lib/rag/`, `lib/knowledge/` | 48-chunk disaster corpus, BM25 search, EmbeddingGemma vector similarity, life-safety prompt guardrails. |
| **Phase 4** | Lessons `0019`–`0025` | `lib/features/shelter/` | 263 bundled shelters, offline tile caching, OSRM routing, real-time AI hazard re-ranking. |
| **Phase 5** | Lessons `0026`–`0028` | `lib/features/mesh_comm/` | Google Nearby Connections `P2P_CLUSTER`, 8 kHz PCM voice streaming, epidemic SOS gossiping protocol. |
| **Phase 6** | Lessons `0029`–`0035` | `lib/features/triage/`, `emergency/` | Zero-hallucination medical decision tree, slide-to-confirm 999 dialer, GPS location encoding. |
| **Phase 7** | Lessons `0036`–`0041` | `lib/features/hazards/`, `admin/` | GDACS, NASA EONET, USGS earthquake polling, Open-Meteo surge models, coordinator access control. |
| **Phase 8** | Lessons `0042`–`0047` | `scripts/build_release.sh`, `eval/` | 10 release verification gates, R8 ProGuard rules, LLM-as-a-judge benchmark harness. |

---

## 3. Lesson Validation & Quality Assurance

The curriculum maintains automated content integrity scripts:

```bash
python3 site/assets/validate_lessons.py
```

- **Validation Rules**:
  - Verifies that all 48 lessons match the standard `LESSON-SPEC.md` structure (kicker, H1, promise statement, section headers, JSON quiz block, lesson footer).
  - Ensures zero broken cross-links between lessons and code files.
  - Confirms quiz schemas and answer key hashes.
  - Expected exit code: `0 errors found`.
