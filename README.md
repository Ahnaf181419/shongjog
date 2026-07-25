# Shongjog
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter) ![Dart](https://img.shields.io/badge/Dart-%5E3.12.0-0175C2?logo=dart) ![Android](https://img.shields.io/badge/Android-arm64--v8a-3DDC84?logo=android) ![License](https://img.shields.io/badge/License-MIT-blue)

*"it works when the internet doesn't."*

[![Download APK](https://img.shields.io/badge/Download-APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Ahnaf181419/shongjog/releases/latest)

## What is Shongjog?
Shongjog is an offline-first, Bangla, voice-first emergency-companion Flutter application designed to operate in severe connectivity vacuums. Built for resilience during crises, the application leverages an on-device Gemma 4 E2B model (via LiteRT-LM) and an on-device Retrieval-Augmented Generation (RAG) system over a verified Bangla emergency corpus. 

Shongjog strictly targets Android `arm64-v8a` architecture to support heavy local model inference, bypassing the need for cloud infrastructure for its core functionalities.

## Download

Grab the latest release APK from the [**Releases**](https://github.com/Ahnaf181419/shongjog/releases/latest) page.

*   Requires an Android device with an `arm64-v8a` processor (nearly all phones from the last several years).
*   Not distributed via Play Store — after downloading, you'll need to allow "Install from unknown sources" for your browser/file manager.
*   On first launch, the app downloads the on-device Gemma 4 E2B model (~3 GB free space recommended) before the AI features become available; everything else (quick cards, shelter map offline markers, triage wizard) works immediately.

## Features
*   **On-Device AI Assistant:** Powered by Gemma 4 E2B running entirely locally via `flutter_gemma`.
*   **Offline RAG:** Semantic search over a verified Bangla emergency corpus using L2-normalized 768-dim fp32 vectors.
*   **Voice-First Interface:** Integrated Bangla speech-to-text and text-to-speech for accessibility during emergencies.
*   **Offline Shelter Map:** Uses `flutter_map` to display cyclone shelter locations without requiring internet access.
*   **One-Touch SOS:** Slide-to-confirm UI to instantly dial 999 and broadcast SOS SMS to designated contacts.
*   **Bluetooth Mesh Messaging:** Peer-to-peer communication using `nearby_connections` and `flutter_p2p_connection` when telecom networks fail.
*   **Triage Wizard:** An LLM-free, deterministic decision tree for rapid medical and safety triage.
*   **Safe-Beacon Check-in:** Low-bandwidth status broadcasting for personal safety verification.

## Dependencies

| Purpose | Package | Version |
| :--- | :--- | :--- |
| **On-device LLM** | `flutter_gemma` | `^1.3.0` |
| | `flutter_gemma_litertlm` | `^1.1.0` |
| **Voice / Audio** | `speech_to_text` | `^7.0.0` |
| | `flutter_tts` | `^4.2.0` |
| | `audioplayers` | `^6.8.1` |
| | `record` | `^6.1.0` |
| **Maps / Location** | `flutter_map` | `^7.0.0` |
| | `geolocator` | `^13.0.0` |
| | `latlong2` | `^0.9.1` |
| **Cloud / Network** | `http` | `^1.2.0` |
| | `google_generative_ai` | `^0.4.6` |
| | `connectivity_plus` | `^6.1.1` |
| **Mesh** | `nearby_connections` | `^4.3.0` |
| | `flutter_p2p_connection` | `^3.0.3` |
| **Utilities** | `url_launcher` | `^6.3.0` |
| | `permission_handler` | `^11.3.1` |
| | `device_info_plus` | `^13.2.0` |
| | `flutter_secure_storage` | `^10.3.1` |
| | `path_provider` | `^2.1.0` |
| | `shared_preferences` | `^2.3.0` |
| | `flutter_displaymode` | `^0.7.0` |
| **Dev** | `flutter_lints` | `^6.0.0 (dev)` |

## Configuration Files

| File Path | Purpose |
| :--- | :--- |
| `pubspec.yaml` | Dart dependencies, assets, fonts, app metadata |
| `.env.example` | Template for optional `GEMINI_API_KEY` (copy to `.env`) |
| `android/app/build.gradle.kts` | compileSdk/minSdk/targetSdk, arm64 ABI filter, packaging excludes, signing |
| `android/build.gradle.kts` | Kotlin JVM 17, AGP plugin version |
| `android/app/proguard-rules.pro` | R8 rules (load-bearing `-keep` for MediaPipe/Protobuf/ODML) |
| `android/app/src/main/AndroidManifest.xml` | All 18 required permissions and activity declarations |
| `analysis_options.yaml` | Dart lint rules |
| `.gitignore` | Excludes model files (`*.litertlm`, `*.task`, `*.tflite`, etc.) |
| `scripts/build_release.sh` | Pre/post-build verification (engine registration, arm64 check, R8 strip) |
| `scripts/build_release.ps1` | Windows PowerShell equivalent of the release script |
| `assets/kb/corpus.json` | 48 Bangla emergency corpus chunks across 22 topics |
| `assets/kb/vectors.bin` | L2-normalized 768-dim fp32 vectors for cosine retrieval |
| `assets/shelter/cyclone_shelters.geojson` | 25 cyclone shelter locations |
| `assets/emergency/directory.json` | 22-entry emergency contact directory |
| `assets/sound/chime.wav`, `assets/sound/knock.wav` | UI sound effects |
| `assets/fonts/HindSiliguri-*.ttf` | Bangla typeface (Light, Regular, Medium, SemiBold) |

## Prerequisites
*   **SDK:** Dart `^3.12.0` / Flutter `3.x`
*   **Android:** compileSdk 36, minSdk 26, targetSdk 36. Kotlin JVM 17, AGP 9.x.
*   **Hardware:** 
    *   Physical Android `arm64-v8a` device is **strictly required** for model inference runs. 
    *   x86_64 emulators can be used for UI-only work, but model operations will silently fail.
*   **Storage:** ~3 GB free space on the device for model download (Gemma 4 E2B = 2.47 GB + runtime overhead).

## Installation
1. Clone the repository.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Copy `.env.example` to `.env` if you plan to use the optional cloud fallback.

## Building & Running

**UI/Layout Debugging (Emulator):**
You can run the app on an x86_64 emulator strictly for UI work.
```bash
flutter run
```

**Full Inference Run (Physical Device):**
Model-bearing runs must be executed on a physical `arm64-v8a` device in release mode.
```bash
flutter run -d <arm64-device-id> --release
```

**Production Build:**
To build the APK or AppBundle, utilize the provided scripts to ensure pre/post-build verifications (like R8 strip counts and ABI enforcement) are met.
```bash
# Build APK with verification scripts
bash scripts/build_release.sh

# Build standard AppBundle for Play Store
flutter build appbundle --release
```
*Note:* The release APK is `arm64-v8a` only. Verify the release APK with the grep command found in `scripts/build_release.sh:139-148` to ensure load-bearing ProGuard rules (`proguard-rules.pro:45-68`) were respected.

## Configuration

### Cloud AI Fallback (Optional)
Shongjog operates offline by default without an API key. For cloud fallback (Primary: `gemma-4-31b-it`, Fallback: `gemini-3.1-flash-lite`), pass the key at build/run time:
```bash
flutter run --release --dart-define=GEMINI_API_KEY=<your_key>
```
This is read via `String.fromEnvironment('GEMINI_API_KEY')` in `lib/features/cloud_ai/cloud_ai_service.dart:27-28`. It is only invoked when `connectivityProvider.isOnline` is true and has thinking disabled (`thinkingBudget: 0`).

### App Preferences
*   **Theme:** 3-way toggle (System/Light/Dark) managed via `lib/core/theme_controller.dart` and persisted via `SharedPreferences`.
*   **Language:** Defaults to Bangla, with an English toggle via `lib/core/locale_controller.dart`.
*   **Model Variant:** Automatically selected based on RAM tier (`lib/core/device_capability.dart:169-179`). Devices with ≤8 GB RAM use E2B; >8 GB use E4B. This can be overridden in the Settings screen.

## Project Architecture
The `lib/` directory is structured by feature and core functionality:

*   `app/` – App entry (`MaterialApp`), routing, theme, `_StartupGate`, `MainShell`.
*   `core/` – Singletons and providers (`modelManager`, `connectivityProvider`, `device_capability`, etc.).
*   `rag/` – Pure Dart implementations of keyword retriever, cosine retriever, prompt builder, rumour checker, and types.
*   `knowledge/` – Handles loading the KB (`corpus.json` + `vectors.bin`).
*   `features/` – Isolated feature modules (e.g., `chat`, `voice`, `mesh_comm`, `triage`, `safe_beacon`, `shelter`).

**Critical Architectural Rules:**
1.  **Engine Initialization:** `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])` must run before any model call to register the FFI engine.
2.  **Singleton Access:** Use the `modelManager` (`lib/core/model_manager.dart`) implementing `LocalLlm`. Never call `FlutterGemma.getActiveModel()` directly in UI code.
3.  **Context Window:** `maxTokens` is strictly `1024` (minimum for `.litertlm`); `maxOutputTokens` is capped at `256`.
4.  **Session Lifecycle:** Sessions are per-query. `generate()` creates and closes each session in a `finally` block. `resetSession()` must await `model.close()` to release mmap'd weights.
5.  **Model Format:** `.litertlm` is strictly required. `.task` files are not compatible with this build.

## Testing
Run the test suites with the following commands. Ensure the analyzer reports "No issues found!" before pushing code.

```bash
# Static analysis
flutter analyze

# Run all tests (Expect 571 passes, 1 intentional skip)
flutter test

# Run unit tests only
flutter test test/unit/

# Run widget tests only
flutter test test/widget/
```

## Contributing
Please see `CONTRIBUTING.md` for our code of conduct and pull request process. We strictly adhere to conventional commits. 

## License
This project is licensed under the MIT License - see the LICENSE file for details.