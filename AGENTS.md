# Shongjog — Agent Guide

> Offline-first, Bangla, voice-first emergency-companion Flutter app. On-device
> Gemma 4 E2B (MediaPipe via flutter_gemma), on-device RAG over a verified Bangla
> corpus, `flutter_map` shelter map, slide-to-confirm 999 dial + SOS SMS,
> Bluetooth mesh messaging. Single sentence: **"it works when the internet doesn't."**

Read `docs/PROJECT-STATUS.md` first — it's the entry point. Then `docs/architecture.md`,
`docs/team.md`, `CONTRIBUTING.md`. Don't try to absorb the whole `docs/` tree in order.

## Hard constraints (will silently break the demo)

- **arm64-v8a only.** The MediaPipe LlmInference runtime + `flutter_gemma` are arm64-only. An x86
  Android emulator cannot run the model. The restriction is enforced in
  `android/app/build.gradle.kts` via `ndk { abiFilters += "arm64-v8a" }`. Do not remove
  this; see `CONTRIBUTING.md` §"What NOT to change".
- **No network in the core chat loop.** The whole product thesis is offline. The only
  network call paths are: (1) the one-time ~1.87 GB model download gated by `ModelManager`,
  (2) the optional Cloud AI fallback when the user passes `--dart-define=GEMINI_API_KEY=…`
  AND `connectivity_plus` reports online, and (3) the optional Open-Meteo weather tile on
  the home screen (`lib/features/weather/weather_service.dart`). Everything else must
  work in airplane mode or it's a bug.
- **Single model path.** All on-device LLM access goes through `modelManager`
  (`lib/core/model_manager.dart`) — the app-wide `final ModelManager modelManager`
  singleton. Never instantiate a second `FlutterGemmaPlugin.instance.init(...)`
  path; never branch around `ModelManager.initialize()` /
  `ModelManager.generate()`.
- **Model filename MUST be `model.bin`.** `flutter_gemma` 0.5.1's
  `MobileModelManager.isModelLoaded` hard-checks for the constant string
  `'model.bin'` at the app docs directory — it does NOT use the path passed to
  `setModelPath()`. If `_modelFileName` is anything other than `'model.bin'`,
  `init()` throws "Gemma Model is not loaded yet" even though the file is on disk.
  There is a `_legacyFileName` migration in `initialize()` that renames old
  `gemma-4-E2B-it-web.task` files to `model.bin` automatically.
- **No medical/advice content from outside the whitelist.** Allowed sources: WHO, BDRCS,
  MoDMR, BMD, CDC, IFRC. See `docs/corpus.md` §5 and `tools/README.md`.
- **No English in the user UI.** User surface is Bangla (HindSiliguri). English is only
  for logs, code identifiers, and engineering docs.
- **Bangla numerals (০-৯) and danda (`।`)** in user-facing strings. Latin digits and `.`
  only inside logs / `assert` / `FormatException` messages. See `CONTRIBUTING.md` §"Bangla
  content policy".
- **No auto-read TTS.** `pref_auto_read` opt-in required; never trigger `TtsService.speak`
  unsolicited on app launch.
- **No analytics that ship user content.** Voice, GPS, photos, chat queries never leave
  the device.

## Module map (`lib/`)

```
app/      MaterialApp, theme, _StartupGate (onboarding gate), MainShell (4-tab nav)
core/     Cross-cutting singletons: modelManager, connectivityProvider, themeController, haptics
rag/      Retrieval core (keyword_retriever, brute-force cosine, prompt_builder, types) — PURE DART
knowledge/ KB loader (reads assets/kb/{corpus.json, vectors.bin} via rootBundle)
features/ One folder per feature: chat, voice, shelter, quick_cards, emergency,
          onboarding, settings, home, about, cloud_ai, mesh_comm, contacts, audio, weather
```

**Dependency rule** (from `docs/architecture.md` §3):
`core/`, `rag/`, `knowledge/`, and pure parts of `features/` (e.g.
`features/shelter/nearest_shelter.dart`, `features/quick_cards/cards_data.dart`,
`features/emergency/sos_sms_template.dart`) import only `dart:*` and internal modules.
They must **not** import `flutter_gemma`, `vosk`, `geolocator`, or `flutter_tts`. The
adapter layer (repositories, services) wraps plugins and hands plain types inward. Keep
new logic pure when practical — that's what makes it unit-testable without a device.

**Tab vs route:** 4 tabs in `MainShell` (`lib/app/main_shell.dart`) are bottom-nav —
`হোম / এআই / কার্ড / আশ্রয়` (Home / AI / Cards / Shelter). `SettingsScreen`,
`EmergencyContactsScreen`, `AboutScreen`, `MeshRadarScreen` are push routes from `lib/app/router.dart`
(`AppRoutes.*` constants). The startup gate (`_StartupGate` in `app.dart`) reads
`SharedPreferences.getBool('pref_has_onboarded')`; first-run shows
`OnboardingScreen`, then routes to `MainShell`.

**Mesh communication:** `meshService` (`lib/features/mesh_comm/mesh_service.dart`) is
an app-wide singleton using `nearby_connections` with `Strategy.P2P_CLUSTER`.
`MeshRadarScreen` and `home_screen.dart`'s `_OfflineMessageTile` both reference it
directly. Messages are UTF-8 encoded (NOT `codeUnits` — that garbles Bangla).

## Commands

```bash
flutter pub get                            # standard
flutter analyze                            # must report "No issues found!"
flutter test                               # 160 pass, 1 skip — see note below
flutter test test/unit/                    # only unit tests (fast)
flutter test test/widget/                  # only widget tests
flutter test integration_test/...          # REQUIRES a connected device
flutter run -d <arm64-device-id> --release # for model-bearing runs
flutter build apk --release                # arm64-v8a only (no flag needed)
bash scripts/build_release.sh             # same APK; injects GEMINI_API_KEY from .env if set
flutter build appbundle --release          # post-hackathon Play submission
```

Code-quality gate per `docs/PRE-DEMO.md`: `flutter analyze` clean AND `flutter test`
all-pass + 1 skip. The `1 skipped` is the intentional `skip: true` in
`test/widget_test.dart` (IndexedStack pre-renders `ShelterMapScreen` whose `flutter_map`
tile fetch returns 400 under the headless test runner — the comment in that file
explains it).

**Rebuilding the knowledge base** (only when `tools/corpus.json` changes):

```bash
cd tools
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt   # sentence-transformers, torch, numpy
python3 build_kb.py              # ~5 min on first run (downloads mpnet)
cd ..
python3 tools/verify_kb.py        # all 7 queries must print "OK"; any "BAD" blocks ship
```

`build_kb.py` writes `assets/kb/{corpus.json, vectors.bin}` (float32 `[N, 768]`,
L2-normalized) which is bundled inside the APK — the KB is present in airplane mode
with no first-run network step.

## RAG / chat flow (`lib/features/chat/chat_repository.dart:34`)

`ChatRepository.ask(query)`:
1. `kb.keywordRetriever.topK(query, k: 5)` then `.take(3)` — **primary path, fully offline**.
2. If `cloudAi != null` and online → `cloudAi!.generate(prompt)`. On failure, falls through.
3. If retrieval returned no hits → canned Bangla "call 999 / talk to a human" response.
4. If `modelManager.isReady || isOnDisk()` → `modelManager.generate(prompt)`.
5. Otherwise → returns `hits.first.chunk.text` directly (raw Bangla guidance, no LLM).

The cosine secondary ranker is **deferred** (`flutter_gemma 0.5.x` has no embedder API;
see `docs/POST-HACKATHON.md` §1). `KeywordRetriever` is the primary path. Don't add an
on-device embedder without coordinating with the model stack.

## On-device model (`lib/core/model_manager.dart`)

- Singleton: `final ModelManager modelManager = ModelManager();`
- States: `notDownloaded → downloading → ready → loading → ready` (or `failed`). The
  UI reacts via `ChangeNotifier` (`ListenableBuilder` in `chat_screen.dart`).
- `ensureModel()` uses stdlib `HttpClient` with Range-resume; checks for `206` and
  truncates+restarts on `200` to avoid corrupting the file. Connection timeout 30s,
  idle timeout 60s. `notifyListeners()` is throttled to 1/sec + on percent-change to
  avoid UI jank during the ~1.87 GB download.
- `isOnDisk()` checks file size against `_expectedModelSize` (2,003,697,664 bytes)
  with 99% tolerance — NOT the old 100MB floor (partial downloads >100MB were
  incorrectly marked ready, causing permanent "ready → failed" loops).
- `initialize()` auto-deletes the model file on failure so corrupted/partial files
  don't cause a permanent stuck state. It also runs `_migrateOldFilename()` which
  renames legacy `gemma-4-E2B-it-web.task` files to `model.bin`.
- Cold start (`initialize()` → `FlutterGemmaPlugin.init`) is 3–10s on arm64. Surface
  "AI প্রস্তুত হচ্ছে..." (`ModelState.loading` → `statusLabelBn`) during this window.
- Generated model run config (per `docs/prd.md` §8): `maxTokens: 512`, `temperature: 0.2`,
  4-bit, thinking off. Don't bump these casually — it risks OOM on low-RAM phones.
- Model URL (`ModelManager._defaultUrl`) is a `litert-community` HF mirror of Gemma 4
  E2B IT in MediaPipe `.task` format (~1.87 GB). The actual runtime is MediaPipe
  `LlmInference` (`com.google.mediapipe:tasks-genai:0.10.21`), NOT LiteRT-LM — despite
  the HF repo name. If you swap the model, also touch the matching TODO in
  `_modelFileName` and the spike entry in `docs/spike-results.md`.

## Bangla STT (`lib/features/voice/`)

`SttService._ensureProvider()` tries Vosk first (`VoskSttProvider.isModelBundled()`),
falls back to `SpeechToTextProvider` (online). **Vosk is currently a stub**: the
`vosk_flutter` plugin's `compileSdk 33` conflicts with AGP 9.x and the app currently
falls through to the online provider. Fix-it options are listed in the file's header
comment and in `docs/POST-HACKATHON.md` §1.1.

TTS (`flutter_tts`) is at `lib/features/voice/tts_service.dart`; configured for `bn-BD`
with `bn-IN` fallback, no extra download.

## Cloud AI fallback (`lib/features/cloud_ai/cloud_ai_service.dart`)

Optional. Constructed only when `--dart-define=GEMINI_API_KEY=<key>` is passed at build.
Primary `gemini-2.5-flash`, fallback `gemini-2.0-flash-lite` (verify at build time —
fictional model IDs return 404). The chain is invoked only when the app-wide
`connectivityProvider.isOnline` singleton (`lib/core/connectivity_provider.dart`,
initialized once in `main.dart`) reports online — read that cached boolean, don't
poll `Connectivity().checkConnectivity()`. The API key is read via
`String.fromEnvironment('GEMINI_API_KEY')` with an empty default — passing the key on
the command line only. Never commit any API key or add a `defaultValue` with a real key.

## Testing policy

Three layers; see `CONTRIBUTING.md` §"Testing policy".

- `test/unit/` — pure Dart, fast, no widget tree. Required for any new logic in
  `lib/rag/`, `lib/core/`, `lib/knowledge/`.
- `test/widget/` — widget tests, no IO. Avoid `pumpAndSettle` on typewriter /
  breathing animations; use `pump(Duration)`.
- `integration_test/demo_flow_test.dart` — full app on device. Run manually before
  any demo, not in CI.

**Don't ship a feature without tests.** PRs that add a feature with no new tests must
explain why in the PR body or they're blocked.

## Android build setup

- `compileSdk = 36`, `minSdk = 26`, `targetSdk = 36`, `applicationId = "com.example.shongjog"`
  in `android/app/build.gradle.kts`. The high `compileSdk` is required by
  `androidx.core:1.17.0` / `androidx.exifinterface:1.4.1` (transitive via `flutter_map`
  and `geolocator_android`).
- Release builds are signed with the debug key for the demo (`flutter run --release`
  works out of the box). Production signing is post-hackathon.
- `R8`/minification is on; rules live in `proguard-rules.pro`.
- Permissions required in `AndroidManifest.xml`: `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`
  (+ `ACCESS_COARSE_LOCATION`), `CALL_PHONE`, `SEND_SMS`, `INTERNET` (only for the
  model download), plus Bluetooth/Wi-Fi set for mesh (`BLUETOOTH_*`, `NEARBY_WIFI_DEVICES`,
  `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`) used by `nearby_connections`.

## Commit / branch conventions

- Commits: `feat(<scope>): …`, `fix(<scope>): …`, `test(<scope>): …`, `docs(<scope>): …`,
  `build(<scope>): …`, `refactor(<scope>): …`, `chore: …`. Valid scopes listed in
  `CONTRIBUTING.md` §"Commit prefix style".
- Branches: `feat/<scope>`, `fix/<scope>`, `docs/<scope>` from `main`. **No
  `git push --force` to `main`.**
- `main` is protected; merges only via PR.
- A GitHub PR template is defined in `CONTRIBUTING.md` §"PR body template"; follow it
  including `flutter analyze` / `flutter test` / device-manual checkboxes.

## What you almost certainly should NOT do

- Remove the `arm64-v8a` ABI filter, add a second `FlutterGemma` instance, or branch
  the model path.
- Rename `_modelFileName` to anything other than `'model.bin'` — `flutter_gemma`'s
  `isModelLoaded` hard-checks for that constant string.
- Ship a corpus chunk from outside `WHO / BDRCS / MoDMR / BMD / CDC / IFRC`.
- Lower the cosine floor in the retriever or strip the canned 999 fallback to "fix"
  retrieval gaps — fix the corpus instead.
- Add analytics that ship voice, GPS, chat content, or photos off-device.
- Add an English-language UI string in user-facing copy.
- Auto-speak via TTS without the `pref_auto_read` opt-in.
- Bundle a model file in the APK or check model files (`*.task`, `*.litertlm`,
  `*.tflite`, `*.gguf`, `*.onnx`, `*.pb`) into git — `.gitignore` already excludes them.
- Edit `_StartupGate` / `OnboardingScreen` on first run to skip the gate.

## File references

- App root widget: `lib/main.dart` → `lib/app/app.dart` (`ShongjogApp`)
- Bottom nav: `lib/app/main_shell.dart:67`
- Theme tokens: `lib/app/theme.dart`
- Model lifecycle: `lib/core/model_manager.dart`
- Connectivity singleton: `lib/core/connectivity_provider.dart` (init once in `main.dart`)
- RAG entry: `lib/features/chat/chat_repository.dart:34`
- STT auto-pick: `lib/features/voice/stt_service.dart:32`
- TTS adapter: `lib/features/voice/tts_service.dart`
- KB asset loader: `lib/knowledge/kb_loader.dart:36`
- Build pipeline: `tools/build_kb.py`, `tools/verify_kb.py`
- Spikes (Phase 0 measurements): `docs/spike-results.md`
