# Shongjog (সংযোগ)

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter) ![Dart](https://img.shields.io/badge/Dart-%5E3.12.0-0175C2?logo=dart) ![Android](https://img.shields.io/badge/Android-arm64--v8a-3DDC84?logo=android) ![Tests](https://img.shields.io/badge/tests-878%20passing-brightgreen) ![Gemma](https://img.shields.io/badge/Gemma%204-on--device-4285F4?logo=google)

*"it works when the internet doesn't."*

[![Download APK](https://img.shields.io/badge/Download-APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Ahnaf181419/shongjog/releases/latest)

Shongjog is an offline-first, Bangla, voice-first emergency companion for Bangladesh, covering **12 hazard types** and **13 first-aid topics**. **Gemma 4 runs entirely on-device** via LiteRT-LM over a verified Bangla RAG corpus, so grounded guidance is available in airplane mode. Online it enriches that core with 13 live endpoints; with no internet at all it forms a Bluetooth / Wi-Fi Direct mesh carrying text, media and full-duplex voice calls between nearby phones.

Targets Android `arm64-v8a` only — local model inference requires it.

---

## Table of Contents

- [Download](#download) · [Features](#features) · [Quick Start](#quick-start)
- [Firebase Setup (required to build)](#firebase-setup-required-to-build)
- [Building](#building) · [Testing](#testing) · [Architecture](#architecture)
- [Configuration](#configuration) · [Documentation](#documentation) · [Contributing](#contributing)

---

## Download

Grab the latest APK from [**Releases**](https://github.com/Ahnaf181419/shongjog/releases/latest).

- Requires an **arm64-v8a** Android device (nearly all phones from the last several years), **minSdk 26**.
- Not on the Play Store — allow "Install from unknown sources" for your browser or file manager.
- On first launch the app downloads Gemma 4 E2B (**2.47 GB**; keep ~3 GB free). Everything else — quick cards, triage wizard, shelter map, offline directory — works immediately.

---

## Features

### AI (Chat + 7 modules)

| Module | Path | Offline |
|---|---|---|
| Chat — grounded Bangla Q&A over the RAG corpus | Gemma 4 on-device | ✅ |
| AI Family Disaster Planner | Gemma 4 on-device | ✅ |
| AI Emergency Kit Generator | Gemma 4 on-device | ✅ |
| AI Risk Assessment | Gemma 4 on-device | ✅ |
| AI Situation Summary | Gemma 4 on-device | ✅ |
| AI Shelter Brief | Gemma 4 on-device | ✅ |
| AI Safety Re-Ranking (weighs live hazard proximity) | Gemma 4 on-device | ✅ |
| AI Damage Scanner (photo → damage type + severity) | Gemini vision | ☁ |

Every on-device module falls back to a deterministic result rather than an error.

### Core

- **Offline RAG** — 23 verified Bangla chunks across 10 topics, each tagged to a named source (WHO, BDRCS, CDC, MoDMR, IFRC, UNICEF, BMD). Keyword retrieval primary; brute-force cosine over bundled 768-dim L2-normalized fp32 vectors as a second path.
- **Voice-first** — Bangla STT with locale resolution and failure classification; Bangla TTS (bn-BD, bn-IN fallback), opt-in auto-read.
- **Bilingual** — Bangla-first with a complete English locale (834 strings) behind a toggle.
- **Shelter map** — 263 bundled shelter locations, GPS ranking, cached tiles, OSRM turn-by-turn routing, Nominatim/Overpass search. No Google Maps dependency.
- **Mesh comms** — text, images, video, voice notes and **full-duplex 8 kHz voice calls** over `nearby_connections` (P2P_CLUSTER) with a GMS-free Wi-Fi Direct fallback. Multi-hop SOS relay: LRU dedup over 256 ids, 5-hop cap, 1-hour TTL.
- **Triage wizard** — pure-Dart decision tree to 8 terminal first-aid routes. No model, cannot hallucinate.
- **Live hazard feeds** — GDACS, NASA EONET, USGS, Open-Meteo weather / marine surge / air quality. All key-less, all fail soft.
- **Safety net** — 25 quick cards, slide-to-confirm 999 dialer, SOS SMS with GPS, 22-entry offline directory.
- **Coordinator panel** — Firestore-backed live safe/danger counts, danger list, campaign approval, broadcasts.

---

## Quick Start

```bash
git clone https://github.com/Ahnaf181419/shongjog.git
cd shongjog
flutter pub get
# → add android/app/google-services.json (see below) before building
flutter run -d <arm64-device-id> --release
```

### Prerequisites

| | |
|---|---|
| SDK | Flutter 3.x · Dart `^3.12.0` |
| Android | compileSdk 36 · targetSdk 36 · **minSdk 26** · Kotlin JVM 17 · AGP 9.x |
| Hardware | Physical **arm64-v8a** device required for inference |
| Storage | ~3 GB free for the model download |

> **x86_64 emulators run the UI only.** The APK ships arm64 libs exclusively, so every LiteRT-LM call fails on an emulator and the app degrades to corpus answers. Any model-bearing work needs real hardware.

---

## Firebase Setup (required to build)

**A fresh clone will not compile without this step.** `android/app/build.gradle.kts` applies the `com.google.gms.google-services` plugin, which needs `android/app/google-services.json` at build time. That file is **gitignored** — it is per-developer and never committed.

1. Create a Firebase project, add an Android app with applicationId **`dev.frostflux.shongjog`**.
2. Download `google-services.json` into `android/app/`.
3. Enable **Anonymous** sign-in (Authentication → Sign-in method).
4. Create a **Firestore** database.
5. Paste [`firestore.rules`](firestore.rules) into Firestore → Rules and publish.

> Step 5 is not optional. The rules enforce ownership binding and restrict access to safety reports (which carry name, phone and live GPS). The repo file is the source of truth, but **rules deploy from the console — committing them changes nothing until they are pasted**.

Firebase powers the coordinator panel and cloud-key delivery only. All init is wrapped in try/catch: with no network, or no Firebase project at all, the app still boots and the entire offline path works.

---

## Building

```bash
# Verified release build — this is the supported path
bash scripts/build_release.sh          # macOS/Linux
pwsh scripts/build_release.ps1         # Windows
```

The script builds, then **inspects the resulting APK** through 10 gates: LiteRT-LM libs present for arm64, arm64-only ABI, R8 stripped no MediaPipe/protobuf classes, Firebase wired, notification plugin packaged, **no API key compiled into `libapp.so`**, POST_NOTIFICATIONS declared, `<queries>` present for the speech recogniser, TTS, camera and file pickers, and the notification icon surviving resource shrinking.

Those gates exist because each one is a bug that shipped once. A missing `<queries>` block silently broke four features at once — Android 11 package visibility hides those services without raising an error.

```bash
flutter run                            # UI-only work on an emulator
flutter run -d <device> --release      # inference on real hardware
flutter build appbundle --release      # Play Store bundle
```

> The release build is currently **debug-signed** — it sideloads fine but is not Play-uploadable. Add `android/key.properties` and a release signing config before publishing.

---

## Testing

```bash
flutter analyze                        # must report "No issues found!"
flutter test                           # 878 pass, 1 intentional skip
flutter test test/unit/                # unit only
flutter test test/widget/              # widget only
```

**100 test files.** Coverage includes WCAG contrast ratios, 1.5× text scaling, Bangla numeral conversion, STT locale resolution, admin layout under stress, mesh path-traversal resistance, mesh link stability, Firestore access control, and the tier-fallback chain.

---

## Architecture

```
lib/
├── app/         MaterialApp, routing, theme, MainShell, startup gate
├── core/        singletons — modelManager, connectivity, auth, notifications
├── rag/         PURE DART — retrievers, prompt builder, rumour checker
├── knowledge/   KB loader (corpus.json + vectors.bin)
└── features/    chat · voice · mesh_comm · shelter · triage · safe_beacon
                 planner · damage_scanner · admin · hazards · weather …
```

**Dependency rule:** `core/`, `rag/` and `knowledge/` are pure Dart with zero Flutter or plugin imports — fully unit-testable without a device. Adapters wrap plugins and hand plain types inward.

### Load-bearing rules

1. **Engine registration** — `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])` must run before any model call. `flutter_gemma` 1.x registers no engine on its own.
2. **Model format** — `.litertlm` only. The repo's lone `.task` is a web/WASM build the Android runtime cannot open.
3. **Singleton access** — go through `modelManager` (implements `LocalLlm`). Never call `FlutterGemma.getActiveModel()` from UI code.
4. **Context window** — `maxTokens` is exactly `1024`; `.litertlm` refuses to allocate tensors below it. Reply cap is `maxOutputTokens: 256`.
5. **Session lifecycle** — one session per query, closed in a `finally`. Native sessions hold a KV cache; leaking them exhausts memory in a handful of questions.
6. **Tier order** — on-device Gemma runs **first, even when online**. Cloud is a fallback, never the primary path.

### Generation tiers

```
shelter-shaped query → pure-Dart haversine ranker (microseconds, no model)
        ↓
TIER 1  Gemma 4 E2B on-device          (90s ceiling, falls through on failure)
TIER 2  gemini-3.1-flash-lite → -preview → gemma-4-26b-a4b-it   (online only)
TIER 3  verified corpus chunk, verbatim
TIER 4  "call 999"
```

Tiers 1, 3 and 4 need no network.

---

## Configuration

### Cloud AI key

The published APK ships with **no key compiled in** — a `--dart-define` key is a plaintext literal in `libapp.so` that one `grep` recovers from any public download, and Dart obfuscation renames symbols, not string constants. Instead the app fetches a key at launch from Firestore `config/cloud_ai` (readable by signed-in clients, writable by none) and caches it in Android Keystore via `flutter_secure_storage`.

Set `geminiApiKeys` (array) or `geminiApiKey` (string) on that document. Blanking it revokes the key on every installed device at next launch, with no new release. A build gate fails the release if a key is ever found in the binary.

For local development only, `.env` / `--dart-define=GEMINI_API_KEY=…` still works as a last-resort fallback.

### Preferences

| Setting | Source |
|---|---|
| Theme (System/Light/Dark) | `lib/core/theme_controller.dart` |
| Language (বাংলা / English) | `lib/core/locale_controller.dart` |
| Model variant | auto by RAM tier — ≤4 GB low, ≤8 GB mid → **E2B**; >8 GB high → **E4B**. Overridable in Settings. |
| Mesh media → gallery | opt-in, default off |

### Key files

| Path | Purpose |
|---|---|
| `firestore.rules` | Access control — **paste into the console to take effect** |
| `scripts/build_release.sh` | Build + 10-gate APK verification |
| `android/app/proguard-rules.pro` | Load-bearing R8 `-keep` rules for MediaPipe/Protobuf/ODML |
| `android/app/src/main/AndroidManifest.xml` | 19 permissions + `<queries>` for speech, TTS, camera, pickers |
| `assets/kb/corpus.json` | 23 verified Bangla chunks, 10 topics |
| `assets/kb/vectors.bin` | 768-dim L2-normalized fp32 vectors |
| `assets/shelter/cyclone_shelters.geojson` | 263 shelter locations |
| `assets/emergency/directory.json` | 22-entry emergency directory |
| `lib/l10n/app_bn.arb`, `app_en.arb` | 834 EN / 888 BN strings |
| `training/`, `eval/` | LoRA SFT dataset (179 examples) + 50-query eval harness |

---

## Documentation

Full docs live in [`docs/`](docs/) — start at [`docs/PROJECT-STATUS.md`](docs/PROJECT-STATUS.md).

- [`docs/architecture.md`](docs/architecture.md) — technical architecture
- [`docs/design.md`](docs/design.md) — design system, tokens, accessibility
- [`docs/prd.md`](docs/prd.md) — product requirements
- [`docs/kaggle-writeup.md`](docs/kaggle-writeup.md) — hackathon submission writeup

## Contributing

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md). Conventional commits; `flutter analyze` clean and the full suite green before pushing.

## License

MIT — see [`LICENSE`](LICENSE).

---

## Screenshots

<table>
  <tr>
    <td><img src="docs/screenshots/0.jpeg" width="280"></td>
    <td><img src="docs/screenshots/1.jpeg" width="280"></td>
    <td><img src="docs/screenshots/2.jpeg" width="280"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/3.jpeg" width="280"></td>
    <td><img src="docs/screenshots/4.jpeg" width="280"></td>
    <td><img src="docs/screenshots/5.jpeg" width="280"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/6.jpeg" width="280"></td>
    <td><img src="docs/screenshots/7.jpeg" width="280"></td>
    <td><img src="docs/screenshots/8.jpeg" width="280"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/9.jpeg" width="280"></td>
    <td><img src="docs/screenshots/10.jpeg" width="280"></td>
    <td><img src="docs/screenshots/11.jpeg" width="280"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/12.jpeg" width="280"></td>
    <td><img src="docs/screenshots/13.jpeg" width="280"></td>
    <td><img src="docs/screenshots/14.jpeg" width="280"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/15.jpeg" width="280"></td>
    <td><img src="docs/screenshots/16.jpeg" width="280"></td>
    <td><img src="docs/screenshots/17.jpeg" width="280"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/18.jpeg" width="280"></td>
    <td><img src="docs/screenshots/19.jpeg" width="280"></td>
    <td><img src="docs/screenshots/20.jpeg" width="280"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/21.jpeg" width="280"></td>
    <td><img src="docs/screenshots/22.jpeg" width="280"></td>
    <td><img src="docs/screenshots/23.jpeg" width="280"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/24.jpeg" width="280"></td>
    <td><img src="docs/screenshots/25.jpeg" width="280"></td>
    <td><img src="docs/screenshots/26.jpeg" width="280"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/27.jpeg" width="280"></td>
    <td></td>
    <td></td>
  </tr>
</table>
