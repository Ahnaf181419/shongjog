# AI & RAG Pipeline

## 1. On-Device LLM: Gemma 4 via LiteRT-LM

Shongjog runs **Google Gemma 4** locally on-device using the `flutter_gemma` (v1.x) plugin backed by Google's **LiteRT-LM** (formerly MediaPipe GenAI / TensorFlow Lite) runtime.

### Runtime Requirements & Invariants

| Parameter | Specification | Load-Bearing Requirement |
|---|---|---|
| **Architecture** | Android `arm64-v8a` | Inference libraries are built exclusively for 64-bit ARM. Emulators run UI only. |
| **Model Format** | `.litertlm` binary | Must be `.litertlm` (e.g., `gemma-4-E2B-it.litertlm`). `.task` files fail on Android. |
| **Context Window** | Exactly `1024` tokens | `.litertlm` requires tensor pre-allocation for 1024 tokens. Lower allocations will crash. |
| **Output Token Cap** | `256` tokens | Enforces concise, rapid, life-critical emergency responses. |
| **Session Lifecycle** | Ephemeral (one session per query) | Sessions allocate native Key-Value (KV) cache memory. Leaking sessions will exhaust memory. Must be closed in `finally`. |
| **Initialization** | `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])` | Must be called explicitly during startup before any model invocation. |

---

## 2. 4-Tier Generation Hierarchy

Shongjog does not treat AI as a brittle single point of failure. It employs a strict 4-tier fallback chain:

```
                            [ User Query Received ]
                                       │
                    Is it a shelter / distance query?
                                  ├──► YES ──► Pure-Dart Haversine Ranker (Microseconds, 0 Model)
                                  │
                                  ▼ NO
                     [ TIER 1: On-Device Gemma 4 ]
                         (Runs first, offline or online)
                         (90-second execution ceiling)
                                  │
                       Did Tier 1 succeed?
                                  ├──► YES ──► Return Grounded Local AI Response
                                  │
                                  ▼ NO (Model not downloaded, timeout, or OOM)
                     [ TIER 2: Cloud AI Fallback ]
                       (Only if network is available)
                       gemini-3.1-flash-lite ──► preview ──► gemma-4-26b-a4b-it
                                  │
                       Did Tier 2 succeed?
                                  ├──► YES ──► Return Cloud AI Response
                                  │
                                  ▼ NO (Offline or API quota error)
                     [ TIER 3: Verified Corpus Chunk ]
                   (Verbatim citation from local RAG database)
                                  │
                       Did Tier 3 match (>0.6 score)?
                                  ├──► YES ──► Return Verbatim Verified Guidance
                                  │
                                  ▼ NO
                     [ TIER 4: Hard Safety Fallback ]
                  "জরুরি পরিস্থিতিতে ৯৯৯ নম্বরে কল করুন" (Call 999)
```

---

## 3. Offline RAG Architecture

### The Corpus (`assets/kb/corpus.json`)
- **Size**: 48 verified Bangla text chunks covering 22 hazard and first-aid categories.
- **Vetted Source Whitelist**: Strict medical and institutional provenance:
  - World Health Organization (WHO)
  - Bangladesh Red Crescent Society (BDRCS)
  - Ministry of Disaster Management and Relief (MoDMR)
  - Bangladesh Meteorological Department (BMD)
  - Centers for Disease Control and Prevention (CDC)
  - International Federation of Red Cross and Red Crescent Societies (IFRC)
  - United Nations Children's Fund (UNICEF)

### Dual-Track Retrieval Engine
1. **Keyword Retriever (`lib/rag/retriever.dart`)**:
   - BM25-lite / TF-IDF hybrid scoring.
   - Handles Bangla morphological variations, transliterations, and emergency abbreviations.
   - Primary high-speed offline retrieval track.
2. **Vector Retriever (`lib/rag/vector_retriever.dart`)**:
   - 768-dimensional L2-normalized float32 embedding vectors bundled in `assets/kb/vectors.bin`.
   - Embeddings generated via Google's `EmbeddingGemma`.
   - Pure-Dart cosine similarity calculation against user query embeddings.

---

## 4. Prompt Engineering & Safety Guardrails

The Prompt Builder ([`lib/rag/prompt_builder.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/rag/prompt_builder.dart)) enforces strict life-safety guardrails:

```
+-----------------------------------------------------------------------+
| SYSTEM PROMPT INVARIANTS:                                             |
| 1. Grounding: Answer ONLY using the provided Bangla context chunk.    |
| 2. No Diagnosis / Prescription: Never prescribe prescription drugs    |
|    or attempt clinical diagnostic conclusions.                         |
| 3. Mandatory 999 Notice: Always append advice to call 999 in critical  |
|    emergencies.                                                       |
| 4. Low-Confidence Fallback: If the context does not answer the        |
|    question, reply with "আমি নিশ্চিত নই, জরুরি সেবায় যোগাযোগ করুন"   |
|    (I am not sure, please contact emergency services).                |
+-----------------------------------------------------------------------+
```

---

## 5. Cloud AI Key Provisioning (Zero Binary Secret)

To prevent API keys from leaking in decompiled APKs:
- **Build Gate Requirement**: No `--dart-define` keys or plaintext strings exist inside compiled `libapp.so`.
- **Dynamic Fetch**: At application startup, `CloudAIService` requests the operational key from Firebase Firestore (`config/cloud_ai`).
- **Encrypted Local Storage**: The fetched key is saved in the Android Keystore using `flutter_secure_storage`.
- **Instant Revocation**: Modifying or blanking the Firestore key revokes access across all deployed devices without issuing an app update.
