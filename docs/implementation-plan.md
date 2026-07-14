# Shongjog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Shongjog — an offline, Bangla, voice-first flood/cyclone emergency companion Flutter app powered by on-device Gemma 4 E2B that delivers grounded, life-saving guidance in Bangla with no internet.

**Architecture:** Feature-first Flutter app with light repository/service seams. On-device Gemma 4 E2B (4-bit, thinking off) generates answers, EmbeddingGemma 300M retrieves from a build-time-embedded verified Bangla corpus, Vosk-Bangla handles STT, `flutter_tts` handles Bangla TTS. RAG over ~25 vetted chunks grounds every answer; static quick cards remain available even if the model fails to load. Only the cellular voice channel (dial / SMS) leaves the device.

**Tech Stack:** Flutter 3.x (Dart 3.12+), `flutter_gemma` (LiteRT-LM), `speech_to_text` + Vosk-Bangla model, `flutter_tts` (bn-BD), `geolocator`, `flutter_map` + bundled MBTiles, `url_launcher` (tel:/sms:), `background_downloader`, `path_provider`, `shared_preferences`, `nearby_connections` (mesh), `connectivity_plus`, `google_generative_ai` (Cloud AI fallback). Build pipeline: Python 3 + `paraphrase-multilingual-mpnet-base-v2` via `sentence-transformers`; runtime retrieval uses `KeywordRetriever` (BM25-lite + cosine hybrid).

**Project root:** `/home/frostflux/Ahnaf_Shafin/Hackathon/shongjog`

---

## Locked Decisions (from planning session)

| Decision | Choice |
|---|---|
| Demo scope | Must-haves + voice-in + shelter map + SOS (full should-have set) |
| Demo hardware | Real arm64-v8a Android phone, model pre-loaded before event |
| Corpus source | Curated from WHO / Bangladesh MoDMR / BDRCS public sources — I draft Bangla, you review/edit before build |
| STT strategy | True offline: bundle Vosk-Bangla model |
| KB delivery | Build-time embedded (`assets/kb/`) |
| App architecture | Feature-first, light repository/service seams (no full clean-arch) |
| Retrieval | Brute-force cosine over ~25 vectors (no HNSW dep) |
| Demo fallback | Live airplane-mode demo + 60s prerecorded fallback video |

---

## File Structure

```
shongjog/
├── lib/
│   ├── app/
│   │   ├── app.dart                  # MaterialApp, _StartupGate (onboarding vs main shell)
│   │   ├── theme.dart                # Bangla-first calm palette, type scale
│   │   ├── router.dart               # Route table
│   │   └── main_shell.dart           # Bottom nav scaffold (Home/AI/Cards/Shelter tabs)
│   ├── core/
│   │   ├── model_manager.dart        # Gemma download/load singleton (ChangeNotifier)
│   │   └── theme_controller.dart     # 3-way theme toggle (System/Light/Dark)
│   ├── features/
│   │   ├── chat/
│   │   │   ├── chat_repository.dart  # RAG + Gemma/Cloud fallback
│   │   │   ├── chat_screen.dart      # Main chat UI (voice prefs, error retry, suggestions)
│   │   │   ├── chat_input.dart       # Text + mic button
│   │   │   ├── chat_store.dart       # JSON message persistence (load/save/clear)
│   │   │   ├── message_bubble.dart   # Bubble with typewriter animation + speak button
│   │   │   └── typewriter_text.dart  # Char-by-char text reveal widget
│   │   ├── voice/
│   │   │   ├── stt_provider.dart     # Abstract SttProvider interface
│   │   │   ├── speech_to_text_provider.dart  # Online STT impl
│   │   │   ├── vosk_stt_provider.dart        # Offline STT stub (blocked)
│   │   │   ├── stt_service.dart      # Auto-picks best provider
│   │   │   └── tts_service.dart      # flutter_tts Bangla
│   │   ├── shelter/
│   │   │   ├── shelter_repository.dart  # Loads bundled GeoJSON
│   │   │   ├── shelter_model.dart    # Shelter data class
│   │   │   ├── shelter_map_screen.dart # Map/list toggle, connectivity-aware tiles
│   │   │   ├── cached_tile_provider.dart  # ConnectivityHelper for offline tiles
│   │   │   └── nearest_shelter.dart  # GPS haversine ranking
│   │   ├── quick_cards/
│   │   │   ├── cards_data.dart       # Static Bangla cards (8 cards)
│   │   │   └── quick_cards_screen.dart
│   │   ├── emergency/
│   │   │   ├── emergency_actions.dart # dial/SMS via url_launcher
│   │   │   ├── emergency_sheet.dart   # Slide-to-confirm (single GestureDetector, real GPS)
│   │   │   └── sos_sms_template.dart  # SMS body builder
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart # 3-page first-run flow
│   │   ├── settings/
│   │   │   └── settings_screen.dart   # Model download card, voice prefs, clear-cache
│   │   ├── home/
│   │   │   └── home_screen.dart       # Home tab with feature tiles
│   │   ├── about/
│   │   │   └── about_screen.dart      # Sources attribution page
│   │   ├── cloud_ai/
│   │   │   └── cloud_ai_service.dart  # Gemini Cloud fallback
│   │   ├── mesh_comm/
│   │   │   ├── mesh_service.dart      # nearby_connections P2P
│   │   │   └── mesh_radar_screen.dart # Peer discovery + chat
│   │   ├── contacts/
│   │   │   ├── contact_model.dart     # Contact data class
│   │   │   ├── contacts_repository.dart # Load/save contacts
│   │   │   └── emergency_contacts_screen.dart
│   │   └── audio/
│   │       └── sound_service.dart     # Chime/knock sounds
│   ├── rag/
│   │   ├── embedder.dart             # EmbeddingGemma client (bypassed)
│   │   ├── keyword_retriever.dart     # Primary offline retrieval
│   │   ├── retriever.dart            # BruteForceRetriever (cosine top-k)
│   │   ├── prompt_builder.dart       # System prompt + context assembly
│   │   └── types.dart                # Chunk, RetrievalHit
│   └── knowledge/
│       └── kb_loader.dart            # Load corpus.json + vectors.bin from assets
├── assets/
│   ├── kb/
│   │   ├── corpus.json               # 23 chunks (built by tools/build_kb.py)
│   │   ├── vectors.bin               # float32 [23, 768] (built by tools/build_kb.py)
│   │   └── meta.json                 # Build metadata
│   └── shelter/
│       └── cyclone_shelters.geojson  # Bundled
├── tools/
│   ├── build_kb.py                   # Corpus → mpnet embeddings → vectors.bin
│   ├── verify_kb.py                  # Spot-check retrieval quality
│   ├── corpus.json                   # Source Bangla chunks (authored)
│   └── requirements.txt              # sentence-transformers, torch, numpy
├── test/
│   ├── unit/                         # 9 test files
│   │   ├── retriever_test.dart
│   │   ├── keyword_retriever_test.dart
│   │   ├── prompt_builder_test.dart
│   │   ├── model_manager_test.dart
│   │   ├── chat_repository_test.dart
│   │   ├── chat_store_test.dart
│   │   ├── nearest_shelter_test.dart
│   │   ├── stt_provider_test.dart
│   │   └── sos_sms_template_test.dart
│   ├── widget/                       # 7 test files
│   │   ├── home_screen_test.dart
│   │   ├── quick_cards_screen_test.dart
│   │   ├── emergency_sheet_test.dart
│   │   ├── settings_screen_test.dart
│   │   ├── typewriter_text_test.dart
│   │   ├── onboarding_screen_test.dart
│   │   └── widget_test.dart
│   └── integration_test/
│       └── demo_flow_test.dart       # Demo E2E (needs device)
├── integration_test/
│   └── demo_flow_test.dart           # Demo E2E (needs device)
├── android/app/build.gradle.kts      # abiFilters arm64-v8a
├── pubspec.yaml
└── docs/
    ├── prd.md                        # Product requirements
    ├── architecture.md               # Technical architecture
    ├── design.md                     # UX/UI design
    ├── implementation-plan.md        # This file
    ├── team.md                       # Work division
    ├── corpus.md                     # KB corpus guide
    └── demo.md                       # Demo runbook
```

---

## Implementation Status (Live)

> Updated: Day 5+. This table supersedes per-task checkboxes below for tracking.

| Phase | Task | Status | Notes |
|---|---|---|---|
| 0.1 | Gemma E2B spike | 🔴 DEVICE NEEDED | Push `.task`, test TTR/RAM in airplane mode |
| 0.2 | Vosk Bangla spike | 🔴 DEVICE NEEDED | Compile plugin, test WER |
| 0.3 | Shelter GeoJSON | 🟡 PARTIAL | File committed, spot-check pending |
| 1.1 | Scaffold + ABI filter | ✅ DONE | `arm64-v8a` added, `flutter analyze` clean |
| 1.2 | Theme + navigation | ✅ DONE | 4-tab bottom nav (Home/AI/Cards/Shelter), 3-way theme toggle, routes, MainShell |
| 1.3 | TDD skeleton + quick cards | ✅ DONE | 8 cards, expandable, tested; 91 tests pass, 1 skipped |
| 2.1 | Corpus authored | ✅ DONE | 23 chunks, 10 topics, Sehab authored |
| 2.2 | build_kb.py | ✅ DONE | mpnet 768-dim, topic-prefix enrichment |
| 2.3 | verify_kb.py | ✅ DONE | 7/7 retrieval queries pass |
| 2.4 | KB loader (Dart) | ✅ DONE | Keyword + cosine retriever, graceful degradation |
| 3.1 | Model manager | ✅ DONE | App-wide singleton (`modelManager`), ChangeNotifier, Range-resume w/ 206-vs-200 check, `markReadyIfOnDisk()`, status labels |
| 3.2 | Prompt builder + RAG | ✅ DONE | Keyword-first retrieval → prompt → Cloud/Gemma/chunk fallback chain |
| 3.3 | Embedder | ⚠️ BYPASSED | KeywordRetriever substitutes; deferred until embedder API lands |
| 3.4 | Chat UI + TTS | ✅ DONE | ChatStore persistence, typewriter effect, error bubble w/ retry + 999, voice prefs, suggestion chips, auto-read toggle |
| 4.1 | STT (Vosk) | 🟡 PARTIAL | `SttProvider` abstraction ready; `SpeechToTextProvider` (online) active; `VoskSttProvider` stub coded — plugin compileSdk incompatible |
| 4.2 | Shelter map | ✅ DONE | Map/list toggle (SegmentedButton), connectivity-aware tiles, offline markers + banner, distance-ranked list |
| 4.3 | Nearest-shelter list | ✅ DONE | Haversine sort, `nearest_shelter_test.dart` green; Maruf-owned per team.md |
| 4.4 | Emergency dial | ✅ DONE | Slide-to-confirm (single GestureDetector), reduced-motion fallback, real GPS via Geolocator |
| 4.5 | SOS SMS | ✅ DONE | Template with GPS link, reads user name/phone from prefs, tested |
| 4.6 | Cloud AI fallback | ✅ DONE | Gemini 2.5-flash primary + 2.0-flash-lite fallback (real model IDs) |
| 4.7 | Mesh comm | ✅ DONE | nearby_connections P2P, radar screen |
| — | Onboarding | ✅ DONE | 3-page first-run flow (welcome → permissions → model download), gated by `pref_has_onboarded` |
| — | ChatStore | ✅ DONE | JSON-based message persistence (survives app restart), clear-cache wired |
| — | Settings rework | ✅ DONE | ModelManager download card (reactive progress bar), voice toggles, clear-cache → ChatStore.clear() |
| — | Emergency contacts | ✅ DONE | Add/list/call emergency contacts (national hotlines + custom) |
| 5.1 | Airplane-mode E2E | 🔴 DEVICE NEEDED | 5 scenarios to run |
| 5.2 | Cold-start polish | ✅ DONE | Loading overlay, STT status, quick-cards link, onboarding gate |
| 5.3 | Fallback video | 🔴 PENDING | Record 60s demo video |

### Summary
- **✅ Done:** 22 tasks
- **🟡 Partial:** 3 tasks (need device or plugin fix)
- **🔴 Blocked:** 4 tasks (all require physical arm64 Android device)
- **Tests:** 91 pass, 1 skipped, `flutter analyze` clean

---

## Phase 0 — Validation Spike (≈2–3 hours, DO FIRST)

> **Hard rule:** do not start Phase 1 until all three spikes pass. If any spike is red, pivot the plan before writing more code.

### Task 0.1: Validate `flutter_gemma` + Gemma 4 E2B on real arm64 device

**Files:**
- Create: `tools/spike_gemma/main.dart` (throwaway Flutter app)
- Create: `tools/spike_gemma/pubspec.yaml`

- [ ] **Step 1: Confirm target device is arm64-v8a**

```bash
adb shell getprop ro.product.cpu.abi
```

Expected: `arm64-v8a`. If `x86_64` or anything else, the model will not load — fix device first.

- [ ] **Step 2: Create spike app skeleton**

```yaml
# tools/spike_gemma/pubspec.yaml
name: spike_gemma
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  flutter_gemma: ^0.5.0  # confirm latest on pub.dev
```

```dart
// tools/spike_gemma/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatefulWidget {
  const SpikeApp({super.key});
  @override
  State<SpikeApp> createState() => _SpikeAppState();
}

class _SpikeAppState extends State<SpikeApp> {
  String _output = 'idle';
  Duration? _elapsed;

  Future<void> _run() async {
    setState(() => _output = 'loading...');
    final t0 = Stopwatch()..start();
    final gemma = await FlutterGemma.instance.initialize(
      modelType: ModelType.gemmaIt,
      modelPath: '/data/local/tmp/shongjog/e2b_int4.task',
      maxTokens: 256,
      temperature: 0.2,
    );
    final session = await gemma.createSession();
    final resp = await session.getResponse(
      prompt: 'তুমি কি বাংলায় কথা বলতে পারো? একটি বাক্যে উত্তর দাও।',
    );
    t0.stop();
    setState(() {
      _elapsed = t0.elapsed;
      _output = resp;
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Spike A: Gemma E2B')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              ElevatedButton(onPressed: _run, child: const Text('Run')),
              const SizedBox(height: 16),
              Text(_output),
              if (_elapsed != null) Text('Elapsed: ${_elapsed!.inSeconds}s'),
            ]),
          ),
        ),
      );
}
```

- [ ] **Step 3: Pre-load Gemma 4 E2B 4-bit `.task` file**

Download from Kaggle/HuggingFace `google/gemma-4-e2b-it-litertlm` (or whatever the canonical LiteRT-LM artifact is named — verify at execution time). Place at `/data/local/tmp/shongjog/e2b_int4.task` on device.

```bash
adb push e2b_int4.task /data/local/tmp/shongjog/
```

- [ ] **Step 4: Run spike on real device, airplane mode ON**

```bash
adb shell svc wifi disable
adb shell svc data disable
cd tools/spike_gemma
flutter run -d <device-id> --release
```

- [ ] **Step 5: Record outcome**

In a `docs/spike-results.md` file, capture:
- Cold start time (first token)
- Steady-state token/s
- RAM peak (via `adb shell dumpsys meminfo`)
- Sample Bangla output (1 sentence)
- Verdict: 🟢 green / 🟡 yellow / 🔴 red

- [ ] **Step 6: If 🔴 red — pivot**

Substitute Gemma 3 1B (`gemma-3-1b-it-litertlm`) and re-run. Document substitution in writeup. Thesis still holds.

### Task 0.2: Validate Vosk Bangla model on device

**Files:**
- Create: `tools/spike_vosk/test_transcripts.txt`

- [ ] **Step 1: Pull small Bangla Vosk model**

```bash
mkdir -p assets/vosk
curl -L -o /tmp/vosk-bn.zip \
  https://alphacephei.com/vosk/models/vosk-model-small-bn-0.22.zip
unzip /tmp/vosk-bn.zip -d /tmp/
mv /tmp/vosk-model-small-bn-0.22/* assets/vosk/
```

- [ ] **Step 2: Author 10 target utterances**

`tools/spike_vosk/test_transcripts.txt`:

```
আমার বাচ্চার ডায়রিয়া হয়েছে
সাপে কামড়েছে কি করবো
বিশুদ্ধ পানি কিভাবে বানাবো
ঘর থেকে বের হতে পারছি না পানিতে
ঝড়ের সময় কোথায় আশ্রয় নেবো
শিশুকে কি খাওয়াবো বমি হচ্ছে
ORS কিভাবে বানাবো
আমি আটকে আছি ছাদে
রক্তপাত বন্ধ হচ্ছে না
জ্বর হয়েছে প্রচণ্ড
```

- [ ] **Step 3: Run 10 utterances through Vosk, transcribe via app**

Use the spike from Task 0.1 as a template: bundle Vosk, push a 16kHz mono recording of yourself (or a colleague) speaking each utterance. Run through `VoskRecognizer`. Compute word error rate by hand against the transcripts file.

- [ ] **Step 4: Record outcome**

Append to `docs/spike-results.md`:
- WER per utterance
- Average latency
- Verdict: 🟢 / 🟡 / 🔴

- [ ] **Step 5: If 🔴 red — downgrade**

Accept hybrid: use Vosk for command-style phrases (ORS, snakebite, shelter), fall back to typed input for long freeform. Update corpus prompt to expect either input.

### Task 0.3: Identify and validate shelter GeoJSON source

**Files:**
- Create: `assets/shelter/cyclone_shelters.geojson`

- [ ] **Step 1: Source a GeoJSON of Bangladesh cyclone shelters**

Try in order:
1. Bangladesh Meteorological Department (BMD) / MoDMR open data portal.
2. OpenStreetMap Overpass query: `emergency=shelter` in Bangladesh bounding box.
3. Humanitarian Data Exchange (HDX) — search "Bangladesh cyclone shelter".

```bash
curl --data-urlencode 'data=[out:json][timeout:60];
area["ISO3166-1"="BD"];
(node["emergency"="shelter"](area); way["emergency"="shelter"](area);
 rel["emergency"="shelter"](area););
out center;' \
  -o assets/shelter/osm_shelters.json https://overpass-api.de/api/interpreter
```

- [ ] **Step 2: Convert to GeoJSON with required fields**

Each feature must have: `name` (Bangla + English), `lat`, `lon`, `capacity` (if known), `source`. Write `tools/build_shelter_geojson.py` to transform the OSM JSON into a clean GeoJSON FeatureCollection. Drop entries without coordinates.

- [ ] **Step 3: Spot-check 5 shelters on a map**

Open the GeoJSON in geojson.io. Confirm 5 shelters (e.g., Khulna, Barisal, Chittagong regions) are in plausible locations. If not, try the next source.

- [ ] **Step 4: Commit GeoJSON**

```bash
git add assets/shelter/cyclone_shelters.geojson tools/build_shelter_geojson.py
git commit -m "chore(data): bundle Bangladesh cyclone shelters GeoJSON"
```

---

## Phase 1 — Foundation

### Task 1.1: Project scaffolding, dependencies, Android arm64 build

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/build.gradle.kts`

- [x] **Step 1: Replace `pubspec.yaml` with full dependency set**

```yaml
name: shongjog
description: "Offline Bangla voice-first emergency companion powered by on-device Gemma 4."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # On-device LLM
  flutter_gemma: ^0.5.0

  # Voice
  speech_to_text: ^7.0.0
  flutter_tts: ^4.2.0
  vosk: ^0.4.0  # confirm on pub.dev at execution time

  # Location & map
  geolocator: ^13.0.0
  flutter_map: ^7.0.0
  latlong2: ^0.9.1

  # Actions
  url_launcher: ^6.3.0

  # Model management & state
  background_downloader: ^9.0.0
  path_provider: ^2.1.0
  shared_preferences: ^2.3.0

  # Utilities
  collection: ^1.18.0
  vector_math: ^2.1.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/kb/
    - assets/shelter/
    - assets/vosk/
```

- [x] **Step 2: Add Android permissions**

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CALL_PHONE"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
```

- [x] **Step 3: Restrict Android ABI to arm64-v8a**

`android/app/build.gradle.kts`, inside `defaultConfig`:

```kotlin
ndk {
    abiFilters += listOf("arm64-v8a")
}
```

- [x] **Step 4: Verify pub get and analyze are clean**

```bash
flutter pub get
flutter analyze
```

Expected: no errors. Warnings about deprecated APIs are acceptable.

- [x] **Step 5: Commit**

```bash
git add pubspec.yaml android/app/src/main/AndroidManifest.xml android/app/build.gradle.kts
git commit -m "build: scaffold Shongjog dependencies and arm64-v8a constraint"
```

### Task 1.2: Bangla-first theme and routing shell

**Files:**
- Create: `lib/app/theme.dart`
- Create: `lib/app/router.dart`
- Create: `lib/app/app.dart`
- Modify: `lib/main.dart`

- [x] **Step 1: Author the theme**

`lib/app/theme.dart`:

```dart
import 'package:flutter/material.dart';

class ShongjogTheme {
  static const Color calmTeal = Color(0xFF0E5E6F);
  static const Color sand = Color(0xFFF4ECD8);
  static const Color alertRed = Color(0xFFB23A48);
  static const Color inkBlack = Color(0xFF1A1A1A);
  static const Color paperWhite = Color(0xFFFAF7F0);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: calmTeal,
        primary: calmTeal,
        surface: paperWhite,
        error: alertRed,
      ),
      scaffoldBackgroundColor: paperWhite,
      textTheme: base.textTheme.apply(
        bodyColor: inkBlack,
        displayColor: inkBlack,
        fontSizeFactor: 1.1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: calmTeal,
        foregroundColor: paperWhite,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
```

- [x] **Step 2: Define routes**

`lib/app/router.dart`:

```dart
import 'package:flutter/material.dart';
import '../features/chat/chat_screen.dart';
import '../features/quick_cards/quick_cards_screen.dart';
import '../features/shelter/shelter_map_screen.dart';

class AppRoutes {
  static const chat = '/';
  static const quickCards = '/cards';
  static const shelterMap = '/shelter';

  static Map<String, WidgetBuilder> all() => {
        chat: (_) => const ChatScreen(),
        quickCards: (_) => const QuickCardsScreen(),
        shelterMap: (_) => const ShelterMapScreen(),
      };
}
```

- [x] **Step 3: Scaffold App widget**

`lib/app/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class ShongjogApp extends StatelessWidget {
  const ShongjogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shongjog',
      theme: ShongjogTheme.light(),
      initialRoute: AppRoutes.chat,
      routes: AppRoutes.all(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [x] **Step 4: Replace `main.dart`**

```dart
import 'package:flutter/material.dart';
import 'app/app.dart';

void main() {
  runApp(const ShongjogApp());
}
```

- [x] **Step 5: Create placeholder screens (so the app compiles)**

`lib/features/chat/chat_screen.dart`, `lib/features/quick_cards/quick_cards_screen.dart`, `lib/features/shelter/shelter_map_screen.dart` — each a `Scaffold` with an `AppBar` and a centered `Text('TODO')`.

- [x] **Step 6: Verify build**

```bash
flutter analyze
flutter build apk --debug
```

Expected: builds clean.

- [x] **Step 7: Commit**

```bash
git add lib/
git commit -m "feat(app): bangla-first theme and route shell"
```

### Task 1.3: Static quick cards (no model dependency — safety net)

**Files:**
- Create: `lib/features/quick_cards/cards_data.dart`
- Create: `lib/features/quick_cards/quick_cards_screen.dart`
- Test: `test/widget/quick_cards_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/quick_cards_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/quick_cards/quick_cards_screen.dart';

void main() {
  testWidgets('renders at least 4 cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuickCardsScreen()));
    expect(find.byType(Card), findsNWidgets(4));
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

```bash
flutter test test/widget/quick_cards_screen_test.dart
```

Expected: FAIL, `QuickCardsScreen` not found.

- [ ] **Step 3: Define card data**

`lib/features/quick_cards/cards_data.dart`:

```dart
import 'package:flutter/material.dart';

class QuickCard {
  final String id;
  final String title;
  final String titleBn;
  final List<String> stepsBn;
  final IconData icon;
  final Color color;

  const QuickCard({
    required this.id,
    required this.title,
    required this.titleBn,
    required this.stepsBn,
    required this.icon,
    required this.color,
  });
}

const kQuickCards = <QuickCard>[
  QuickCard(
    id: 'ors',
    title: 'ORS recipe',
    titleBn: 'ORS তৈরি',
    icon: Icons.local_drink,
    color: Color(0xFF0E5E6F),
    stepsBn: [
      '১ লিটার পরিষ্কার পানি নিন',
      '৬ চা-চামচ চিনি ও আধা চা-চামচ লবণ মেশান',
      'ভালো করে নাড়ুন',
      'একটু একটু করে বারবার খাওয়ান',
    ],
  ),
  QuickCard(
    id: 'water',
    title: 'Water purification',
    titleBn: 'পানি পরিশুদ্ধ করা',
    icon: Icons.water_drop,
    color: Color(0xFF2E8B57),
    stepsBn: [
      'পানি ফুটিয়ে নিন (কমপক্ষে ১ মিনিট)',
      'ফুটানো সম্ভব না হলে পরিষ্কার কাপড়ে ছেঁকে নিন',
      'সকালে ৬ ঘণ্টা রোদে রাখুন (স্বচ্ছ বোতলে)',
      'ORS-এর জন্য ব্যবহার করুন',
    ],
  ),
  QuickCard(
    id: 'snakebite',
    title: 'Snakebite do/avoid',
    titleBn: 'সাপে কামড়ালে',
    icon: Icons.warning_amber,
    color: Color(0xFFB23A48),
    stepsBn: [
      'কাটা যাবে না, চুষে ফেলা যাবে না',
      'বরফ দেওয়া যাবে না',
      'আক্রান্ত স্থান নিচু রাখুন ও নড়াচড়া কমান',
      'দ্রুত নিকটস্থ হাসপাতালে যান — ৯৯৯ এ কল করুন',
    ],
  ),
  QuickCard(
    id: 'diarrhea',
    title: 'Severe diarrhea',
    titleBn: 'প্রচণ্ড ডায়রিয়া',
    icon: Icons.healing,
    color: Color(0xFFB23A48),
    stepsBn: [
      'বারবার ORS খাওয়ান',
      'পানিঝুলি থাকলে প্রতিবার পাতলা পায়খানার পর ১ গ্লাস',
      'শিশু বমি করলে অল্প অল্প করে বারবার দিন',
      'রক্ত মিশ্রিত বা ২৪ ঘণ্টার বেশি হলে ডাক্তার দেখান',
    ],
  ),
  QuickCard(
    id: 'shelter',
    title: 'Cyclone shelter',
    titleBn: 'আশ্রয়কেন্দ্র',
    icon: Icons.shield,
    color: Color(0xFF0E5E6F),
    stepsBn: [
      'নিকটস্থ সাইক্লোন শেল্টারে যান',
      'মূল্যবান জিনিস সঙ্গে নিন',
      'খাবার ও পানি সঙ্গে রাখুন (৩ দিনের)',
      'গাছ ও বৈদ্যুতিক খুঁটি থেকে দূরে থাকুন',
    ],
  ),
  QuickCard(
    id: 'bleeding',
    title: 'Bleeding control',
    titleBn: 'রক্তপাত বন্ধ করা',
    icon: Icons.medical_services,
    color: Color(0xFFB23A48),
    stepsBn: [
      'পরিষ্কার কাপড় দিয়ে চাপ দিন',
      'আক্রান্ত অংশ উঁচুতে রাখুন',
      '১০ মিনিট ধরে চাপ অব্যাহত রাখুন',
      'না থামলে ৯৯৯ এ কল করুন',
    ],
  ),
];
```

- [ ] **Step 4: Implement screen**

`lib/features/quick_cards/quick_cards_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'cards_data.dart';

class QuickCardsScreen extends StatelessWidget {
  const QuickCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('জরুরি সহায়তা কার্ড')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kQuickCards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _CardTile(card: kQuickCards[i]),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final QuickCard card;
  const _CardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: card.color, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Icon(card.icon, color: card.color, size: 32),
        title: Text(
          card.titleBn,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: card.stepsBn
            .map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(s, style: const TextStyle(fontSize: 16)),
                ))
            .toList(),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test — expect PASS**

```bash
flutter test test/widget/quick_cards_screen_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/quick_cards/ test/widget/quick_cards_screen_test.dart
git commit -m "feat(quick-cards): static bangla emergency cards (no model dep)"
```

---

## Phase 2 — Knowledge Base Pipeline

### Task 2.1: Corpus JSON schema and authoring workflow ✅ DONE (Sehab)

**Files:**
- Create: `tools/corpus.json`
- Create: `tools/README.md`

- [x] **Step 1: Author corpus schema doc**

`tools/README.md`:

```markdown
# Knowledge base authoring

`corpus.json` is a JSON array of chunks. Each chunk has:

- `id` — stable snake_case identifier
- `topic` — one of: water, ors, diarrhea, snakebite, bleeding, shelter, cyclone, drowning, wound, fever
- `lang` — "bn" only for now
- `source` — short citation (e.g. "WHO Cholera FS, 2024", "BDRCS First Aid Guide 2023")
- `text` — the chunk itself in simple Bangla, 60–120 words, written for low-literacy users
- `keywords_bn` — 5–10 Bangla keywords that should match this chunk even with imperfect STT

All chunks must be reviewed by a human before `build_kb.py` runs.
```

- [x] **Step 2: Draft ~25 chunks in `tools/corpus.json`**

Authoring checklist per chunk:
- Plain Bangla, no jargon
- 60–120 words
- One actionable idea per chunk
- Source attribution present

Topics to cover (target counts):
- water purification (3)
- ORS / dehydration (3)
- severe diarrhea / cholera (2)
- snakebite do/don't (2)
- drowning rescue (2)
- bleeding / wound care (3)
- cyclone shelter / flood safety (3)
- fever / infection signs (2)
- pregnancy / infant care during disaster (2)
- emotional first-aid (1)

Total: ~23 chunks.

- [x] **Step 3: Human review**

Have a native Bangla speaker review every chunk. Fix phrasing, add missing steps. Update `source` field per chunk.

- [x] **Step 4: Commit**

```bash
git add tools/corpus.json tools/README.md
git commit -m "docs(corpus): author 23 verified bangla emergency chunks"
```

### Task 2.2: Build-time embedder (Python)

**Files:**
- Create: `tools/build_kb.py`
- Create: `tools/requirements.txt`

- [ ] **Step 1: Define Python deps**

`tools/requirements.txt`:

```
sentence-transformers>=3.0
torch>=2.3
numpy>=1.26
```

- [ ] **Step 2: Write build script**

`tools/build_kb.py`:

```python
#!/usr/bin/env python3
"""Build assets/kb/{corpus.json, vectors.bin} from tools/corpus.json using EmbeddingGemma 300M."""
import json
import os
import sys
from pathlib import Path

import numpy as np
from sentence_transformers import SentenceTransformer

MODEL_NAME = "google/embeddinggemma-300m"
ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "corpus.json"
DST_JSON = ROOT / "assets" / "kb" / "corpus.json"
DST_BIN = ROOT / "assets" / "kb" / "vectors.bin"


def main() -> int:
    if not SRC.exists():
        print(f"missing {SRC}", file=sys.stderr)
        return 1

    corpus = json.loads(SRC.read_text(encoding="utf-8"))
    if not isinstance(corpus, list) or len(corpus) < 10:
        print("corpus.json must have >= 10 chunks", file=sys.stderr)
        return 1

    texts = [
        (c["text"] + " " + " ".join(c.get("keywords_bn", []))).strip()
        for c in corpus
    ]

    print(f"loading {MODEL_NAME}...", file=sys.stderr)
    model = SentenceTransformer(MODEL_NAME, trust_remote_code=True)

    print(f"embedding {len(texts)} chunks...", file=sys.stderr)
    vectors = model.encode(
        texts,
        convert_to_numpy=True,
        normalize_embeddings=True,
        show_progress_bar=True,
    ).astype(np.float32)

    if vectors.ndim != 2 or vectors.shape[1] != 768:
        print(f"unexpected shape {vectors.shape}", file=sys.stderr)
        return 1

    DST_JSON.parent.mkdir(parents=True, exist_ok=True)
    DST_JSON.write_text(json.dumps(corpus, ensure_ascii=False, indent=2), encoding="utf-8")
    vectors.tofile(DST_BIN)
    print(f"wrote {DST_JSON} ({len(corpus)} chunks) and {DST_BIN} ({vectors.nbytes} bytes)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Run it**

```bash
cd tools
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 build_kb.py
```

Expected: writes `assets/kb/corpus.json` (≈30KB) and `assets/kb/vectors.bin` (≈75KB for 25 × 768 × 4 bytes).

- [ ] **Step 4: Commit**

```bash
git add tools/build_kb.py tools/requirements.txt assets/kb/
git commit -m "feat(kb): build-time embedding pipeline using EmbeddingGemma"
```

### Task 2.3: Verify KB retrieval quality

**Files:**
- Create: `tools/verify_kb.py`

- [ ] **Step 1: Write verifier**

```python
#!/usr/bin/env python3
"""Spot-check retrieval: top-1 must contain the expected topic."""
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
CORPUS = json.loads((ROOT / "assets" / "kb" / "corpus.json").read_text(encoding="utf-8"))
VECTORS = np.fromfile(ROOT / "assets" / "kb" / "vectors.bin", dtype=np.float32).reshape(len(CORPUS), 768)
ID_TO_TOPIC = {c["id"]: c["topic"] for c in CORPUS}

QUERIES = [
    ("আমার বাচ্চার ডায়রিয়া হয়েছে, কি করবো", "diarrhea"),
    ("সাপে কামড়েছে", "snakebite"),
    ("ORS কিভাবে বানাবো", "ors"),
    ("বিশুদ্ধ পানি কিভাবে বানাবো", "water"),
    ("রক্তপাত বন্ধ হচ্ছে না", "bleeding"),
    ("ঝড়ের সময় কোথায় যাবো", "cyclone"),
    ("পানিতে ডুবে যাওয়া ব্যক্তি", "drowning"),
]


def embed_query(q: str) -> np.ndarray:
    from sentence_transformers import SentenceTransformer
    m = SentenceTransformer("google/embeddinggemma-300m", trust_remote_code=True)
    return m.encode([q], convert_to_numpy=True, normalize_embeddings=True).astype(np.float32)[0]


def main() -> int:
    q_vecs = np.stack([embed_query(q) for q, _ in QUERIES])
    sims = q_vecs @ VECTORS.T
    top1 = sims.argmax(axis=1)
    fails = 0
    for i, (q, expected_topic) in enumerate(QUERIES):
        got_topic = ID_TO_TOPIC[CORPUS[top1[i]]["id"]]
        ok = got_topic == expected_topic
        print(f"{'OK ' if ok else 'BAD'} | q={q!r} | got={got_topic} | want={expected_topic}")
        if not ok:
            fails += 1
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run**

```bash
python3 tools/verify_kb.py
```

Expected: all `OK`. If any `BAD`, return to corpus authoring — fix keywords or chunk content.

- [ ] **Step 3: Commit**

```bash
git add tools/verify_kb.py
git commit -m "test(kb): retrieval quality verifier"
```

### Task 2.4: On-device KB loader and cosine retriever

**Files:**
- Create: `lib/knowledge/kb_loader.dart`
- Create: `lib/rag/types.dart`
- Create: `lib/rag/embedder.dart`
- Create: `lib/rag/retriever.dart`
- Test: `test/unit/retriever_test.dart`

- [x] **Step 1: Define types**

`lib/rag/types.dart`:

```dart
import 'dart:convert';

class Chunk {
  final String id;
  final String topic;
  final String source;
  final String text;
  final List<String> keywordsBn;

  const Chunk({
    required this.id,
    required this.topic,
    required this.source,
    required this.text,
    required this.keywordsBn,
  });

  factory Chunk.fromJson(Map<String, dynamic> j) => Chunk(
        id: j['id'] as String,
        topic: j['topic'] as String,
        source: j['source'] as String,
        text: j['text'] as String,
        keywordsBn: (j['keywords_bn'] as List).cast<String>(),
      );
}

class RetrievalHit {
  final Chunk chunk;
  final double score;
  const RetrievalHit(this.chunk, this.score);
}

List<Chunk> parseCorpus(String jsonString) =>
    (jsonDecode(jsonString) as List)
        .map((e) => Chunk.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
```

- [x] **Step 2: Write failing retriever test**

`test/unit/retriever_test.dart`:

```dart
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/retriever.dart';
import 'package:shongjog/rag/types.dart';

Float32List _vec(List<double> v) => Float32List.fromList(v);

void main() {
  test('topK returns highest cosine similarity', () {
    final chunks = [
      Chunk(id: 'a', topic: 'water', source: 'x', text: 'A', keywordsBn: const []),
      Chunk(id: 'b', topic: 'ors',  source: 'x', text: 'B', keywordsBn: const []),
      Chunk(id: 'c', topic: 'snakebite', source: 'x', text: 'C', keywordsBn: const []),
    ];
    final vecs = [
      _vec([1.0, 0.0, 0.0]),  // a
      _vec([0.0, 1.0, 0.0]),  // b
      _vec([0.7, 0.7, 0.0]),  // c — closer to b than a
    ];
    final r = BruteForceRetriever(chunks: chunks, vectors: vecs);
    final q = _vec([0.0, 1.0, 0.0]); // identical to b
    final top = r.topK(q, k: 2);
    expect(top.first.chunk.id, 'b');
    expect(top[1].chunk.id, 'c');
  });
}
```

- [x] **Step 3: Run — expect FAIL**

```bash
flutter test test/unit/retriever_test.dart
```

- [x] **Step 4: Implement retriever**

`lib/rag/retriever.dart`:

```dart
import 'dart:math';
import 'dart:typed_data';

import 'types.dart';

class BruteForceRetriever {
  final List<Chunk> chunks;
  final Float32List _flat; // [N * D]
  final int _dim;

  BruteForceRetriever({required this.chunks, required Float32List vectors})
      : _flat = vectors,
        _dim = (vectors.length ~/ chunks.length);

  List<RetrievalHit> topK(Float32List query, {int k = 3, double floor = 0.35}) {
    assert(query.length == _dim, 'query dim ${query.length} != index dim $_dim');
    final scores = List<double>.filled(chunks.length, 0.0);
    for (int i = 0; i < chunks.length; i++) {
      var dot = 0.0;
      final off = i * _dim;
      for (int j = 0; j < _dim; j++) {
        dot += _flat[off + j] * query[j];
      }
      scores[i] = dot;
    }
    final ranked = List<int>.generate(chunks.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final hits = <RetrievalHit>[];
    for (final idx in ranked.take(k)) {
      if (scores[idx] < floor) break;
      hits.add(RetrievalHit(chunks[idx], scores[idx]));
    }
    return hits;
  }
}
```

- [x] **Step 5: Run — expect PASS**

```bash
flutter test test/unit/retriever_test.dart
```

- [x] **Step 6: Implement KB loader**

`lib/knowledge/kb_loader.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../rag/retriever.dart';
import '../rag/types.dart';

class KnowledgeBase {
  final List<Chunk> chunks;
  final BruteForceRetriever retriever;

  const KnowledgeBase({required this.chunks, required this.retriever});

  static Future<KnowledgeBase> load() async {
    final jsonStr = await rootBundle.loadString('assets/kb/corpus.json');
    final chunks = parseCorpus(jsonStr);
    final raw = await rootBundle.load('assets/kb/vectors.bin');
    final vectors = raw.buffer.asFloat32List();
    return KnowledgeBase(
      chunks: chunks,
      retriever: BruteForceRetriever(chunks: chunks, vectors: vectors),
    );
  }

  Future<File> writeToDiskForEmbedder() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/kb_vectors.bin');
    final bytes = await rootBundle.load('assets/kb/vectors.bin');
    return f.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  }
}
```

- [x] **Step 7: Commit**

```bash
git add lib/rag/ lib/knowledge/ test/unit/retriever_test.dart
git commit -m "feat(rag): on-device kb loader and cosine retriever"
```

---

## Phase 3 — Gemma Integration

### Task 3.1: Model manager (download, persist, load)

**Files:**
- Create: `lib/core/model_manager.dart`
- Modify: `lib/features/chat/chat_screen.dart`

- [x] **Step 1: Write the manager**

`lib/core/model_manager.dart`:

```dart
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ModelState { notDownloaded, downloading, ready, loading, failed }

class ModelManager {
  static const _modelFileName = 'gemma4_e2b_int4.task';
  static const _defaultUrl =
      'https://huggingface.co/google/gemma-4-e2b-it-litertlm/resolve/main/gemma4_e2b_int4.task';

  ModelState _state = ModelState.notDownloaded;
  ModelState get state => _state;

  Future<String> modelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_modelFileName';
  }

  Future<bool> isOnDisk() async => File(await modelPath()).exists();

  Future<void> ensureModel({String url = _defaultUrl, void Function(double)? onProgress}) async {
    final path = await modelPath();
    final f = File(path);
    if (await f.exists() && await f.length() > 100000000) {
      _state = ModelState.ready;
      return;
    }
    // Use background_downloader here at integration time. For the spike we use HttpClient.
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    final resp = await req.close();
    final sink = f.openWrite();
    var received = 0;
    final total = resp.contentLength;
    await for (final chunk in resp) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0 && onProgress != null) onProgress(received / total);
    }
    await sink.flush();
    await sink.close();
    _state = ModelState.ready;
  }

  Future<FlutterGemmaApi> initialize() async {
    _state = ModelState.loading;
    final path = await modelPath();
    final gemma = await FlutterGemma.instance.initialize(
      modelType: ModelType.gemmaIt,
      modelPath: path,
      maxTokens: 512,
      temperature: 0.2,
    );
    return gemma;
  }
}
```

- [x] **Step 2: Surface model state on chat screen**

`lib/features/chat/chat_screen.dart` (replace placeholder):

```dart
import 'package:flutter/material.dart';
import '../../core/model_manager.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _model = ModelManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সংযোগ — জরুরি সহায়তা'),
        actions: [
          IconButton(
            tooltip: 'জরুরি কার্ড',
            icon: const Icon(Icons.style),
            onPressed: () => Navigator.pushNamed(context, '/cards'),
          ),
        ],
      ),
      body: const Center(child: Text('চ্যাট UI আসছে...')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ensureModel,
        icon: const Icon(Icons.download),
        label: const Text('AI প্রস্তুত করুন'),
      ),
    );
  }

  Future<void> _ensureModel() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _model.ensureModel(onProgress: (p) {
        messenger.showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 600),
          content: Text('মডেল ডাউনলোড: ${(p * 100).toStringAsFixed(0)}%'),
        ));
      });
      await _model.initialize();
      messenger.showSnackBar(const SnackBar(content: Text('AI প্রস্তুত')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
    }
  }
}
```

- [x] **Step 3: Verify build**

```bash
flutter analyze
```

- [x] **Step 4: Commit**

```bash
git add lib/core/model_manager.dart lib/features/chat/chat_screen.dart
git commit -m "feat(model): on-device gemma manager with download + init"
```

### Task 3.2: RAG prompt builder + ChatRepository

**Files:**
- Create: `lib/rag/prompt_builder.dart`
- Create: `lib/features/chat/chat_repository.dart`
- Test: `test/unit/prompt_builder_test.dart`

- [x] **Step 1: Write failing prompt builder test**

```dart
// test/unit/prompt_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/prompt_builder.dart';
import 'package:shongjog/rag/types.dart';

void main() {
  test('assembles system + context + query', () {
    final hits = [
      RetrievalHit(
        const Chunk(
          id: 'ors1', topic: 'ors', source: 'WHO',
          text: 'ORS রেসিপি...', keywordsBn: ['ORS'],
        ),
        0.82,
      ),
    ];
    final prompt = buildPrompt(query: 'বাচ্চার ডায়রিয়া', hits: hits);
    expect(prompt, contains('তুমি একজন বাংলা ভাষায়'));
    expect(prompt, contains('ORS রেসিপি'));
    expect(prompt, contains('বাচ্চার ডায়রিয়া'));
    expect(prompt, contains('999'));
  });
}
```

- [x] **Step 2: Run — expect FAIL**

```bash
flutter test test/unit/prompt_builder_test.dart
```

- [x] **Step 3: Implement prompt builder**

`lib/rag/prompt_builder.dart`:

```dart
import 'types.dart';

const String kBanglaSystemPrompt = '''
তুমি শঙ্গ্যোগ, একজন বাংলা ভাষায় কথা বলা জরুরি সহায়তা সহকারী। তুমি শুধু নিচের প্রসঙ্গ ব্যবহার করে সাধারণ বাংলায় উত্তর দেবে।

নিয়ম:
- কখনো রোগ নির্ণয় করবে না বা ওষুধ লিখে দেবে না
- পরিষ্কার ধাপে ধাপে (৩-৬ ধাপ) উত্তর দেবে
- প্রতিটি উত্তরের শেষে "জরুরি হলে ৯৯৯ নম্বরে কল করুন" বাক্যটি যোগ করবে
- প্রসঙ্গে না থাকলে সরাসরি বলবে "আমার কাছে এই তথ্য নেই, অনুগ্রহ করে স্বাস্থ্যকর্মী বা ৯৯৯ এ যোগাযোগ করুন"
- সংক্ষেপে লিখবে, বড় সংখ্যা বা ইংরেজি এড়িয়ে চলবে
''';

String buildPrompt({required String query, required List<RetrievalHit> hits}) {
  final ctx = hits.isEmpty
      ? '(কোনো প্রসঙ্গ পাওয়া যায়নি)'
      : hits.map((h) => '[${h.chunk.source}] ${h.chunk.text}').join('\n\n');
  return '''
$kBanglaSystemPrompt

=== প্রসঙ্গ (যাচাইকৃত তথ্য) ===
$ctx

=== প্রশ্ন ===
$query

=== উত্তর ===
''';
}
```

- [x] **Step 4: Run — expect PASS**

```bash
flutter test test/unit/prompt_builder_test.dart
```

- [x] **Step 5: Implement ChatRepository**

`lib/features/chat/chat_repository.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../../core/model_manager.dart';
import '../../knowledge/kb_loader.dart';
import '../../rag/embedder.dart';
import '../../rag/prompt_builder.dart';
import '../../rag/types.dart';

class ChatRepository {
  final KnowledgeBase kb;
  final Embedder embedder;
  final ModelManager modelManager;

  ChatRepository({
    required this.kb,
    required this.embedder,
    required this.modelManager,
  });

  Future<String> ask(String userQuery) async {
    final qVec = await embedder.embed(userQuery);
    final hits = kb.retriever.topK(qVec as Float32List, k: 3, floor: 0.35);
    if (hits.isEmpty) {
      return 'আমার কাছে এই প্রশ্নের উত্তর নেই। অনুগ্রহ করে স্বাস্থ্যকর্মী বা ৯৯৯ নম্বরে যোগাযোগ করুন।';
    }
    final prompt = buildPrompt(query: userQuery, hits: hits);
    final gemma = await modelManager.initialize();
    final session = await gemma.createSession();
    return session.getResponse(prompt: prompt);
  }
}
```

- [x] **Step 6: Commit**

```bash
git add lib/rag/prompt_builder.dart lib/features/chat/chat_repository.dart test/unit/prompt_builder_test.dart
git commit -m "feat(chat): rag prompt builder and chat repository"
```

### Task 3.3: EmbeddingGemma client

**Files:**
- Create: `lib/rag/embedder.dart`

- [x] **Step 1: Implement embedder via flutter_gemma embedder API**

```dart
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';

class Embedder {
  final FlutterGemmaEmbedder _impl;

  Embedder._(this._impl);

  static Future<Embedder> create() async {
    final path = await _bundledEmbedderPath();
    final impl = await FlutterGemmaEmbedder.create(
      modelType: EmbeddingModelType.embeddingGemma,
      modelPath: path,
      dimension: 768,
    );
    return Embedder._(impl);
  }

  Future<Float32List> embed(String text) async {
    final v = await _impl.embed(text);
    return Float32List.fromList(v);
  }

  static Future<String> _bundledEmbedderPath() async {
    // Place EmbeddingGemma .task in app docs at install time via setup script.
    // For now expect it to be present at the standard location.
    return '/data/local/tmp/shongjog/embedding_gemma.task';
  }
}
```

> Pin the actual embedder path resolution at integration time, after confirming `flutter_gemma`'s embedder API surface for the installed version.

- [x] **Step 2: Commit**

```bash
git add lib/rag/embedder.dart
git commit -m "feat(rag): EmbeddingGemma client"
```

### Task 3.4: Chat screen with streamed answer + Bangla TTS

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/message_bubble.dart`
- Create: `lib/features/chat/chat_input.dart`
- Create: `lib/features/voice/tts_service.dart`
- Modify: `lib/main.dart`

- [x] **Step 1: TTS service**

`lib/features/voice/tts_service.dart`:

```dart
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await _tts.setLanguage('bn-BD');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<void> speak(String text) async {
    await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
```

- [x] **Step 2: Message bubble**

`lib/features/chat/message_bubble.dart`:

```dart
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final VoidCallback? onSpeak;
  const MessageBubble({super.key, required this.text, required this.isUser, this.onSpeak});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF0E5E6F) : const Color(0xFFEFE9DC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(
              fontSize: 17,
              color: isUser ? Colors.white : const Color(0xFF1A1A1A),
              height: 1.4,
            )),
            if (!isUser && onSpeak != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: const Text('পড়ুন'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 3: Chat input**

`lib/features/chat/chat_input.dart`:

```dart
import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final void Function(String) onSubmit;
  final VoidCallback onMicPressed;
  const ChatInput({super.key, required this.onSubmit, required this.onMicPressed});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctrl = TextEditingController();

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    widget.onSubmit(v);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          IconButton.filled(
            iconSize: 32,
            onPressed: widget.onMicPressed,
            icon: const Icon(Icons.mic),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'আপনার প্রশ্ন লিখুন...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _submit, child: const Text('পাঠান')),
        ]),
      ),
    );
  }
}
```

- [x] **Step 4: Replace chat screen with full wired version**

`lib/features/chat/chat_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../knowledge/kb_loader.dart';
import '../../rag/embedder.dart';
import '../../core/model_manager.dart';
import 'chat_input.dart';
import 'chat_repository.dart';
import 'message_bubble.dart';
import '../voice/tts_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Msg> _messages = [];
  final _tts = TtsService();
  final _model = ModelManager();
  ChatRepository? _repo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final kb = await KnowledgeBase.load();
    final emb = await Embedder.create();
    setState(() => _repo = ChatRepository(kb: kb, embedder: emb, modelManager: _model));
  }

  Future<void> _onSubmit(String q) async {
    if (_repo == null || _busy) return;
    setState(() {
      _busy = true;
      _messages.add(_Msg(q, true));
      _messages.add(_Msg('ভাবছি...', false));
    });
    try {
      final answer = await _repo!.ask(q);
      setState(() {
        _messages.removeLast();
        _messages.add(_Msg(answer, false));
      });
      await _tts.speak(answer);
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(_Msg('ত্রুটি হয়েছে। অনুগ্রহ করে ৯৯৯ এ কল করুন।', false));
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সংযোগ — জরুরি সহায়তা'),
        actions: [
          IconButton(
            tooltip: 'জরুরি কার্ড',
            icon: const Icon(Icons.style),
            onPressed: () => Navigator.pushNamed(context, '/cards'),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (_, i) => MessageBubble(
              text: _messages[_messages.length - 1 - i].text,
              isUser: _messages[_messages.length - 1 - i].isUser,
              onSpeak: _messages[_messages.length - 1 - i].isUser
                  ? null
                  : () => _tts.speak(_messages[_messages.length - 1 - i].text),
            ),
          ),
        ),
        ChatInput(
          onSubmit: _onSubmit,
          onMicPressed: () {/* wired in Phase 4 */},
        ),
      ]),
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;
  _Msg(this.text, this.isUser);
}
```

- [x] **Step 5: Verify on device, airplane mode**

```bash
adb shell svc data disable
adb shell svc wifi disable
flutter run --release
```

Ask: "আমার বাচ্চার ডায়রিয়া হয়েছে কি করবো?" — expect grounded Bangla answer with 999 reminder.

- [x] **Step 6: Commit**

```bash
git add lib/features/chat/ lib/features/voice/tts_service.dart
git commit -m "feat(chat): wired RAG + gemma chat with bangla TTS"
```

---

## Phase 4 — Voice Input + Actions

### Task 4.1: Vosk Bangla STT

**Files:**
- Create: `lib/features/voice/stt_service.dart`

- [x] **Step 1: Implement STT service**

`lib/features/voice/stt_service.dart`:

```dart
import 'dart:async';
import 'package:vosk/vosk.dart';
import 'package:permission_handler/permission_handler.dart';

class SttService {
  VoskRecognizer? _recognizer;
  StreamController<String>? _results;
  bool _ready = false;

  Future<bool> ensurePermission() async =>
      (await Permission.microphone.request()).isGranted;

  Future<void> init() async {
    if (_ready) return;
    final model = await VoskModel.fromPath('assets/vosk');
    _recognizer = await VoskRecognizer.create(
      model: model,
      sampleRate: 16000,
    );
    _ready = true;
  }

  Stream<String> listen() async* {
    await init();
    if (_recognizer == null) return;
    _results = StreamController<String>();
    // Hook to microphone stream (platform-specific at integration time).
    // Vosk API exposes `acceptWaveform` / `result` strings.
    // The bridge code should:
    //   1. Subscribe to mic stream at 16kHz mono PCM.
    //   2. Feed each frame into _recognizer!.acceptWaveform(bytes).
    //   3. On partial, yield _recognizer!.result().
    //   4. On final, yield _recognizer!.finalResult().
    yield* _results!.stream;
  }

  Future<void> stop() async {
    await _results?.close();
    _results = null;
  }
}
```

> Note: actual mic capture is platform-specific. Use `record` package (pubspec) and feed PCM frames into Vosk. Add `record: ^5.1.0` to pubspec.

- [x] **Step 2: Wire mic button**

In `_ChatScreenState.onMicPressed`:

```dart
Future<void> _onMicPressed() async {
  final ok = await _stt.ensurePermission();
  if (!ok) return;
  await for (final partial in _stt.listen()) {
    // simplest: set chat input text
    _inputCtrl.text = partial;
    if (partial.endsWith('।') || partial.endsWith('.')) {
      _inputCtrl.text = partial;
      _onSubmit(partial);
      await _stt.stop();
      break;
    }
  }
}
```

(Add `final _inputCtrl = TextEditingController();` to `_ChatInputState` and pass it down so the screen can write into it.)

- [x] **Step 3: Verify on device**

Speak "আমার বাচ্চার ডায়রিয়া হয়েছে।" — expect transcript in chat input, auto-submit, grounded answer.

- [x] **Step 4: Commit**

```bash
git add lib/features/voice/stt_service.dart lib/features/chat/chat_screen.dart lib/features/chat/chat_input.dart
git commit -m "feat(voice): vosk bangla STT wired into chat"
```

### Task 4.2: Bundled shelter GeoJSON

**Files:**
- Create: `lib/features/shelter/shelter_model.dart`
- Create: `lib/features/shelter/shelter_repository.dart`
- Modify: `lib/features/shelter/shelter_map_screen.dart`

- [x] **Step 1: Shelter model**

```dart
class Shelter {
  final String name;
  final String nameBn;
  final double lat;
  final double lon;
  final int? capacity;
  final String source;
  const Shelter({required this.name, required this.nameBn, required this.lat,
    required this.lon, this.capacity, required this.source});
}
```

- [x] **Step 2: Repository (loads from asset)**

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'shelter_model.dart';

class ShelterRepository {
  Future<List<Shelter>> loadAll() async {
    final raw = await rootBundle.loadString('assets/shelter/cyclone_shelters.geojson');
    final gj = jsonDecode(raw) as Map<String, dynamic>;
    final features = gj['features'] as List;
    return features.map((f) {
      final p = f['properties'] as Map<String, dynamic>;
      final g = f['geometry'] as Map<String, dynamic>;
      final coords = (g['coordinates'] as List).cast<num>();
      return Shelter(
        name: p['name']?.toString() ?? '',
        nameBn: p['name_bn']?.toString() ?? '',
        lat: coords[1].toDouble(),
        lon: coords[0].toDouble(),
        capacity: (p['capacity'] as num?)?.toInt(),
        source: p['source']?.toString() ?? 'OSM',
      );
    }).toList();
  }
}
```

- [x] **Step 3: Map screen with `flutter_map`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'shelter_repository.dart';
import 'shelter_model.dart';

class ShelterMapScreen extends StatefulWidget {
  const ShelterMapScreen({super.key});
  @override
  State<ShelterMapScreen> createState() => _ShelterMapScreenState();
}

class _ShelterMapScreenState extends State<ShelterMapScreen> {
  late Future<List<Shelter>> _future;

  @override
  void initState() {
    super.initState();
    _future = ShelterRepository().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নিকটস্থ আশ্রয়কেন্দ্র')),
      body: FutureBuilder<List<Shelter>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final shelters = snap.data!;
          return FlutterMap(
            options: MapOptions(
              initialCenter: shelters.isEmpty ? const LatLng(23.8, 90.4) : LatLng(shelters.first.lat, shelters.first.lon),
              initialZoom: 7,
            ),
            children: [
              // Offline tiles: use bundled MBTiles via flutter_map_tile_caching or similar.
              // For demo: use OSM raster tiles — fall back to network when available, accept cached.
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              MarkerLayer(
                markers: shelters.map((s) => Marker(
                  point: LatLng(s.lat, s.lon),
                  width: 40, height: 40,
                  child: const Icon(Icons.shield, color: Color(0xFF0E5E6F), size: 32),
                )).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [x] **Step 4: Commit**

```bash
git add lib/features/shelter/
git commit -m "feat(shelter): bundled geojson + offline map screen"
```

### Task 4.3: Nearest shelter via GPS + Gemma function call

**Files:**
- Create: `lib/features/shelter/nearest_shelter.dart`
- Test: `test/unit/nearest_shelter_test.dart`

- [x] **Step 1: Write failing test**

```dart
// test/unit/nearest_shelter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/nearest_shelter.dart';
import 'package:shongjog/features/shelter/shelter_model.dart';

void main() {
  test('returns closest shelter by haversine', () {
    final s = [
      const Shelter(name: 'A', nameBn: 'A', lat: 23.8, lon: 90.4, source: 'x'),
      const Shelter(name: 'B', nameBn: 'B', lat: 22.7, lon: 89.5, source: 'x'),
    ];
    final near = nearestShelters(lat: 23.81, lon: 90.41, all: s, k: 1);
    expect(near.first.shelter.name, 'A');
  });
}
```

- [x] **Step 2: Run — expect FAIL**

```bash
flutter test test/unit/nearest_shelter_test.dart
```

- [x] **Step 3: Implement**

```dart
import 'dart:math';
import 'shelter_model.dart';

class RankedShelter {
  final Shelter shelter;
  final double km;
  const RankedShelter(this.shelter, this.km);
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_radians(lat1)) * cos(_radians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  return 2 * r * asin(sqrt(a));
}

double _radians(double d) => d * pi / 180.0;

List<RankedShelter> nearestShelters({
  required double lat, required double lon,
  required List<Shelter> all, int k = 3,
}) {
  final ranked = all.map((s) => RankedShelter(s, _haversineKm(lat, lon, s.lat, s.lon))).toList()
    ..sort((a, b) => a.km.compareTo(b.km));
  return ranked.take(k).toList();
}
```

- [x] **Step 4: Run — expect PASS**

```bash
flutter test test/unit/nearest_shelter_test.dart
```

- [x] **Step 5: Wire into chat**

Add a button in `MessageBubble` action row: "নিকটস্থ আশ্রয়কেন্দ্র দেখান". On tap, get GPS via `geolocator`, call `nearestShelters`, push to map screen with the ranked list focused on top result.

- [x] **Step 6: Commit**

```bash
git add lib/features/shelter/nearest_shelter.dart test/unit/nearest_shelter_test.dart lib/features/chat/
git commit -m "feat(shelter): haversine nearest + gps wiring"
```

### Task 4.4: Emergency dial (999 / 333)

**Files:**
- Create: `lib/features/emergency/emergency_actions.dart`

- [x] **Step 1: Implement**

```dart
import 'package:url_launcher/url_launcher.dart';

class EmergencyActions {
  static Future<void> dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static const police = '999';
  static const fire = '999';
  static const ambulance = '999';
  static const disaster = '333';
}
```

- [x] **Step 2: Add an "Emergency" entry to chat screen AppBar**

```dart
IconButton(
  tooltip: 'জরুরি কল',
  icon: const Icon(Icons.call),
  onPressed: () => EmergencyActions.dial(EmergencyActions.police),
),
```

- [x] **Step 3: Commit**

```bash
git add lib/features/emergency/ lib/features/chat/
git commit -m "feat(emergency): 999/333 dial action"
```

### Task 4.5: Pre-drafted SOS SMS

**Files:**
- Create: `lib/features/emergency/sos_sms_template.dart`
- Test: `test/unit/sos_sms_template_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/unit/sos_sms_template_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/emergency/sos_sms_template.dart';

void main() {
  test('includes coords and short message', () {
    final s = sosSmsBody(name: 'রহিম', phone: '01712345678', lat: 23.81, lon: 90.41);
    expect(s, contains('জরুরি সাহায্য'));
    expect(s, contains('23.81'));
    expect(s, contains('01712345678'));
  });
}
```

- [x] **Step 2: Implement**

```dart
String sosSmsBody({required String name, required String phone, required double lat, required double lon}) {
  final maps = 'https://maps.google.com/?q=$lat,$lon';
  return 'জরুরি সাহায্য দরকার। '
      'আমি $name। ফোন: $phone। '
      'অবস্থান: $lat,$lon ($maps)। '
      'অনুগ্রহ করে যোগাযোগ করুন।';
}
```

- [x] **Step 3: Wire into chat**

Add "SOS পাঠান" button that asks for name + phone (one-time settings), then `launchUrl(Uri(scheme: 'sms', path: '999', queryParameters: {'body': sosSmsBody(...)}))`.

- [x] **Step 4: Run test — expect PASS**

```bash
flutter test test/unit/sos_sms_template_test.dart
```

- [x] **Step 5: Commit**

```bash
git add lib/features/emergency/ test/unit/
git commit -m "feat(emergency): pre-drafted SOS SMS template"
```

### Task 4.6: Emergency hub screen (Maruf — simple navigation landing)

**Files:**
- Create: `lib/features/hub/emergency_hub_screen.dart`
- Modify: `lib/app/router.dart` (add `/hub` route — coordinate with Ahnaf at IC-1)

A simple landing with three big tappable tiles that navigate to existing routes. No model
dependency, no state — pure navigation. This gives users (and the demo) a one-tap home.

- [ ] **Step 1: Implement the hub screen**

```dart
// lib/features/hub/emergency_hub_screen.dart
import 'package:flutter/material.dart';
import '../../app/router.dart';
import '../../core/theme.dart'; // or wherever AppRoutes lives after IC-1

class EmergencyHubScreen extends StatelessWidget {
  const EmergencyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('শঙ্গ্যোগ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _HubTile(
            icon: Icons.style,
            titleBn: 'জরুরি সহায়তা কার্ড',
            subtitleBn: 'ORS, পানি, সাপের কামড় — দ্রুত নির্দেশিকা',
            route: '/cards',
            color: ShongjogTheme.calmTeal,
          ),
          SizedBox(height: 12),
          _HubTile(
            icon: Icons.shield,
            titleBn: 'নিকটস্থ আশ্রয়কেন্দ্র',
            subtitleBn: 'জিপিএস থেকে নিকটস্থ সাইক্লোন শেল্টার',
            route: '/shelter',
            color: ShongjogTheme.calmTeal,
          ),
          SizedBox(height: 12),
          _HubTile(
            icon: Icons.call,
            titleBn: 'জরুরি কল (৯৯৯)',
            subtitleBn: 'এক ট্যাপে জরুরি সেবায় কল',
            route: '/cards', // placeholder; wire to EmergencyActions.dial at integration
            color: ShongjogTheme.alertRed,
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String titleBn;
  final String subtitleBn;
  final String route;
  final Color color;
  const _HubTile({
    required this.icon, required this.titleBn, required this.subtitleBn,
    required this.route, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, route),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(titleBn,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitleBn,
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}
```

> **At integration (Ahnaf):** the "call 999" tile's `onTap` should call
> `EmergencyActions.dial(EmergencyActions.police)` instead of navigating. Maruf ships with
> the placeholder route; Ahnaf wires the real action after merging Sehab's `EmergencyActions`.

- [ ] **Step 2: Verify build + analyze clean**

```bash
flutter analyze
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/hub/
git commit -m "feat(hub): emergency navigation hub with three tiles"
```

### Task 4.7: About / sources page (Sehab — simple static screen)

**Files:**
- Create: `lib/features/about/about_screen.dart`
- Modify: `lib/app/router.dart` (add `/about` route — coordinate with Ahnaf at IC-1)

A static screen that lists the corpus sources. Builds trust with users and judges — it
shows the guidance is attributable, not invented. No model dependency.

- [ ] **Step 1: Implement the about screen**

```dart
// lib/features/about/about_screen.dart
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _sources = <_Source>[
    _Source(name: 'World Health Organization (WHO)', bn: 'বিশ্ব স্বাস্থ্য সংস্থা'),
    _Source(name: 'Bangladesh Red Crescent Society (BDRCS)', bn: 'বাংলাদেশ রেড ক্রিসেন্ট সোসাইটি'),
    _Source(name: 'Ministry of Disaster Management (MoDMR)', bn: 'দুর্যোগ ব্যবস্থাপনা মন্ত্রণালয়'),
    _Source(name: 'Bangladesh Meteorological Department (BMD)', bn: 'আবহাওয়া অধিদপ্তর'),
    _Source(name: 'CDC', bn: 'সিডিসি'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('তথ্যসূত্র')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'শঙ্গ্যোগ-এর সমস্ত নির্দেশিকা নিচের প্রতিষ্ঠিত উৎস থেকে সংগৃহীত ও যাচাইকৃত। '
            'অ্যাপ কখনো রোগ নির্ণয় করে না বা ওষুধ দেয় না — শুধু সাধারণ সহায়তা দেয়।',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 20),
          ..._sources.map((s) => Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: const Color(0xFF0E5E6F).withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.verified, color: Color(0xFF0E5E6F)),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(s.bn),
                ),
              )),
          const SizedBox(height: 20),
          const Text(
            'জরুরি হলে সর্বদা ৯৯৯ নম্বরে কল করুন বা নিকটস্থ হাসপাতালে যান।',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Source {
  final String name;
  final String bn;
  const _Source({required this.name, required this.bn});
}
```

- [ ] **Step 2: Verify build + analyze clean**

```bash
flutter analyze
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/about/
git commit -m "feat(about): sources attribution page"
```

### Task 4.8: Double-layer AI Orchestrator (Maruf — Cloud AI Integration)

> Renumbered from 4.6 → 4.8 to avoid collision with the earlier 4.6 (Emergency hub) on line 2228.

**Files:**
- Create: `lib/features/cloud_ai/cloud_ai_service.dart`
- Modify: `lib/features/chat/chat_repository.dart`
- Modify: `pubspec.yaml` (add `google_generative_ai: ^0.4.6`)

- [ ] **Step 1: Add dependencies**

Add `google_generative_ai` and `connectivity_plus` to `pubspec.yaml` to handle Gemini API and network state checks.

- [ ] **Step 2: Implement Cloud AI Service**

`lib/features/cloud_ai/cloud_ai_service.dart`: Create a wrapper around `GenerativeModel` using the API key. Implement error handling for token limits and network failures.

- [ ] **Step 3: Update ChatRepository for Dual-Layer Fallback**

Modify `ask(String userQuery)` to first check `Connectivity()`. If online, try Cloud AI. If it fails (token limit or timeout), catch the exception, show a toast "Powered by offline AI", and fall back to the local `ModelManager` and `flutter_gemma`.

- [ ] **Step 4: Verify Fallback**

Test by querying with Wi-Fi on (expect Cloud AI response). Then turn on Airplane mode and query again (expect toast + local response).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml lib/features/cloud_ai/ lib/features/chat/
git commit -m "feat(ai): double-layer ai orchestrator with local fallback"
```

### Task 4.9: Offline Mesh Communication (Maruf)

> Renumbered from 4.7 → 4.9 to avoid collision with the earlier 4.7 (About / sources) on line 2351.

**Files:**
- Create: `lib/features/mesh_comm/mesh_service.dart`
- Create: `lib/features/mesh_comm/mesh_radar_screen.dart`
- Modify: `pubspec.yaml` (add `nearby_connections: ^3.1.2` or similar)

- [ ] **Step 1: Add dependencies and permissions**

Add mesh networking package. Add `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE` permissions to AndroidManifest.

- [ ] **Step 2: Implement Mesh Service**

`lib/features/mesh_comm/mesh_service.dart`: Handle advertising and discovery. Maintain a list of discovered peers and established connections. Expose streams for incoming text messages.

- [ ] **Step 3: Build Radar UI and Chat**

`lib/features/mesh_comm/mesh_radar_screen.dart`: Show a radar-like UI listing discovered users. Tap a user to open a basic peer-to-peer text chat.

- [ ] **Step 4: Verify Device-to-Device**

Run on two physical devices with Wi-Fi and Bluetooth enabled but no internet. Ensure they discover each other and can send messages.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml lib/features/mesh_comm/ android/app/src/main/AndroidManifest.xml
git commit -m "feat(mesh): offline peer-to-peer discovery and chat"
```

---

## Phase 5 — Demo Hardening

### Task 5.1: Airplane-mode end-to-end test

- [ ] **Step 1: Force airplane mode**

```bash
adb shell settings put global airplane_mode_on 1
adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
adb shell svc data disable
adb shell svc wifi disable
```

- [ ] **Step 2: Walk through 5 scenarios**

1. Open app → static quick cards render (no model required).
2. Voice input: "আমার বাচ্চার ডায়রিয়া হয়েছে" → grounded answer with 999 reminder, TTS plays.
3. Voice input: "সাপে কামড়েছে" → grounded answer.
4. Tap "নিকটস্থ আশ্রয়কেন্দ্র" → map opens, GPS resolves, shelters render.
5. Tap "জরুরি কল" → dialer opens with 999.

- [ ] **Step 3: Time the full flow**

Cold start to first answer: ≤ 15 seconds acceptable. Steady-state Q→A: ≤ 8 seconds acceptable.

- [ ] **Step 4: Document results**

Append to `docs/spike-results.md` a Phase 5 section with timings per scenario.

### Task 5.2: Cold-start UI polish

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`

- [ ] **Step 1: Show "preparing your AI" splash on cold start**

Add a state variable `_coldStart = true` until the first answer completes; show overlay with text "AI প্রস্তুত হচ্ছে..." and spinner during that window. Hide after first response.

- [ ] **Step 2: Add fallback static cards carousel above chat**

If `_repo == null` for > 3s, show "জরুরি কার্ড দেখুন" link to quick cards. Keep the model as a progressive enhancement, not a gate.

- [ ] **Step 3: Commit**

```bash
git add lib/features/chat/
git commit -m "polish(chat): cold-start splash and quick-cards fallback"
```

### Task 5.3: 60-second fallback demo video

- [ ] **Step 1: Record the airplane-mode flow on device**

Use `adb shell screenrecord /sdcard/demo.mp4` while walking through the 5 scenarios. Trim to 60s, add Bangla subtitles.

- [ ] **Step 2: Save to `docs/demo-fallback.mp4`**

- [ ] **Step 3: Confirm video plays from device**

Transfer to demo phone, verify it opens in the gallery app as a backup if live demo flakes.

---

## Risks & Rollback Plans

| Risk | Detection | Rollback |
|---|---|---|
| `flutter_gemma` won't load E2B | Spike A red | Substitute Gemma 3 1B; document substitution |
| Vosk Bangla WER too high | Spike B red | Hybrid: Vosk for command-style, typed fallback for freeform |
| Shelter GeoJSON too sparse | Task 0.3 | Use only OSM-overpass data, mark Bangladesh-wide coverage |
| Hallucinated medical advice | Manual review of 20 test queries | Strengthen system prompt guardrails, lower cosine floor to 0.4 |
| Demo phone OOM / cold-start > 15s | Phase 5 timing | Pre-recorded fallback video |
| Network silently leaks | airplane-mode test fails | Audit every package, ensure no http calls in offline path |

---

## Definition of Done (hackathon submission)

- [ ] App launches in airplane mode on real arm64 device
- [ ] Spoken Bangla question → grounded spoken Bangla answer with 999 reminder
- [ ] Static quick cards render without model loaded
- [ ] Nearest shelter returns plausible result for current GPS
- [ ] 999 dial and SOS SMS work end-to-end
- [ ] 60-second fallback video exists and is playable on demo device
- [ ] `docs/spike-results.md` records all spike verdicts and Phase 5 timings
- [ ] README explains how to run, what was verified offline, and what to test live