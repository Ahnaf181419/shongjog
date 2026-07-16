# Shongjog — Agent Guide

> Offline-first, Bangla, voice-first emergency-companion Flutter app. On-device
> Gemma 4 E2B (LiteRT-LM via flutter_gemma 1.x), on-device RAG over a verified Bangla
> corpus, `flutter_map` shelter map, slide-to-confirm 999 dial + SOS SMS,
> Bluetooth mesh messaging. Single sentence: **"it works when the internet doesn't."**

Read `docs/PROJECT-STATUS.md` first — it's the entry point. Then `docs/architecture.md`,
`docs/team.md`, `CONTRIBUTING.md`. Don't try to absorb the whole `docs/` tree in order.

## Hard constraints (will silently break the demo)

- **arm64-v8a only.** `flutter_gemma_litertlm` ships its native engine for
  `android_arm64` alone, so **an x86_64 emulator can never run the model** — it
  fails there exactly like a bug. Enforcement takes THREE things, because the
  first two are each insufficient on their own: `ndk { abiFilters }` (NDK output
  only), `--target-platform android-arm64` in `scripts/build_release.sh`
  (Flutter's own libs only), and `packaging { jniLibs { excludes } }` in
  `android/app/build.gradle.kts` — without that last one, prebuilt plugin `.so`s
  leave a `lib/x86_64/` directory behind, which is enough for Android to pick
  x86_64 at install and land on a build with no engine. Use `flutter run` for
  emulator/UI work; the release APK is arm64-only by design.
- **No network in the core chat loop.** The whole product thesis is offline. The only
  network call paths are: (1) the one-time ~2.5 GB model download gated by `ModelManager`,
  (2) the optional Cloud AI fallback when the user passes `--dart-define=GEMINI_API_KEY=…`
  AND `connectivity_plus` reports online, and (3) the optional Open-Meteo weather tile on
  the home screen (`lib/features/weather/weather_service.dart`). Everything else must
  work in airplane mode or it's a bug.
- **Single model path.** All on-device LLM access goes through `modelManager`
  (`lib/core/model_manager.dart`) — the app-wide `final ModelManager modelManager`
  singleton, which satisfies the `LocalLlm` contract the chat layer depends on.
  Never call `FlutterGemma.getActiveModel(...)` from anywhere else; never branch
  around `ModelManager.initialize()` / `ModelManager.generate()`.
- **`.litertlm` + LiteRT-LM only — never the repo's `.task`.** Gemma 4 has **no
  Android `.task`**. `litert-community/gemma-4-E2B-it-litert-lm` ships one
  `.task` (`gemma-4-E2B-it-web.task`) and it is a **WebAssembly build**: its
  magic bytes are `TFL3` (a raw TFLite flatbuffer), not the `PK` zip every
  MediaPipe bundle is, and the model card lists it only under "Running on Web
  with MediaPipe" (a route it calls "in maintenance mode"). Feeding it to a
  native runtime cannot work. Download `gemma-4-E2B-it.litertlm` instead — the
  card's Android/iOS/Desktop path — and run it through
  `flutter_gemma_litertlm`. To sanity-check any candidate file:
  `curl -sL -r 0-3 <url> | xxd` → must start with `PK` (MediaPipe) or
  `LITERTLM`; `TFL3` means it is the web build.
- **`flutter_gemma` 1.x is modular — the engine must be registered.** The core
  registers **no** inference engine, so `main.dart` must call
  `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])` before any
  `getActiveModel()`, or every call throws "add the engine package". The engine
  lives in the separate `flutter_gemma_litertlm` package; adding
  `flutter_gemma_mediapipe` is what would pull MediaPipe (and its R8 hazard)
  back in.
- **Context window >= 1024, and it is NOT the reply cap.**
  `getActiveModel(maxTokens:)` is the CONTEXT WINDOW; `.litertlm` fails to
  allocate tensors below 1024 (upstream #318), so the old MediaPipe-era
  `maxTokens: 512` breaks outright. Cap reply length with
  `createSession(maxOutputTokens: 512)` instead. See `_kContextTokens` /
  `_kMaxOutputTokens` in `model_manager.dart`.
- **Close the model before dropping it.** `resetSession()` must `await
  model.close()`. Weights are mmap'd natively (2.5 GB E2B / 3.5 GB E4B) and
  `close()` is also what resets flutter_gemma's core singleton bookkeeping.
  Nulling the reference alone leaves the old variant resident while the next
  one loads — an OOM on any phone. Same reason `deleteVariant()` closes before
  unlinking.
- **Sessions are per-query.** `generate()` creates a session, asks, and closes
  it in a `finally`. Each live session holds its own KV cache (~100–500 MB) and
  the `.litertlm` engine allows one live conversation anyway, so close+recreate
  is the documented pattern for models this size.
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
          onboarding, settings, home, about, cloud_ai, mesh_comm, contacts,
          audio, weather, intelligence, triage, safe_beacon
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
`EmergencyContactsScreen`, `AboutScreen`, `MeshRadarScreen`, `TriageWizardScreen`,
`SafeBeaconScreen`, `DirectoryScreen` are push routes from `lib/app/router.dart`
(`AppRoutes.*` constants). The startup gate (`_StartupGate` in `app.dart`) reads
`SharedPreferences.getBool('pref_has_onboarded')`; first-run shows
`OnboardingScreen`, then routes to `MainShell`.

**Mesh communication:** `meshService` (`lib/features/mesh_comm/mesh_service.dart`) is
an app-wide singleton using `nearby_connections` with `Strategy.P2P_CLUSTER`.
`MeshRadarScreen` and `home_screen.dart`'s `_OfflineMessageTile` both reference it
directly. Messages are UTF-8 encoded (NOT `codeUnits` — that garbles Bangla).
**Multi-hop SOS relay:** `SosPayload` (JSON wire format) + `SosRelayEngine`
(de-dupe by UUID, 1h TTL, max 5 hops, loop guard) + `SosRelayListener` (bridges
incoming bytes to the engine and re-broadcasts). `meshService.ensureRelayEngine()`
is called from `_StartupGate` on app startup. `broadcastSos()` sends a payload
to all peers and adds a local `hopCount: 0` message to the chat stream.
**Triage wizard:** pure-Dart `TriageTree` in `lib/features/triage/decision_tree.dart`
routes 5 yes/no questions to 5 terminal first-aid routes (cpr, bleeding, drowning,
snakebite, escalation999). No LLM involved; cannot hallucinate.
**Safe beacon:** `SafeBeaconScreen` broadcasts a "নিরাপদ" payload over the mesh
and queues SMSes to emergency contacts via `SmsQueue`, draining when
`connectivityProvider` reports online.
**Emergency directory:** `DirectoryScreen` reads `assets/emergency/directory.json`
(22 entries), filterable by division, tap-to-call via `url_launcher`.

## Commands

```bash
flutter pub get                            # standard
flutter analyze                            # must report "No issues found!"
flutter test                               # 246 pass, 1 skip — see note below
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
  avoid UI jank during the ~2.5 GB download.
- `isOnDisk(v)` checks the variant's file size against
  `DeviceCapability.getRecommendations()[v].sizeBytes` with 99% tolerance — NOT a
  flat floor (partial downloads were incorrectly marked ready, causing permanent
  "ready → failed" loops). **Those byte counts are the live `Content-Length` of
  each `.litertlm` file** (E2B 2,588,147,712; E4B 3,659,530,240, both verified
  2026-07-16). A guessed size silently rejects a complete download — re-verify
  with `curl -sIL <url> | grep -i content-length` before changing one. The 12B
  entry is `available: false` (its URL 404s); unavailable variants are hidden
  from the picker and rejected by `ensureModel()`.
- `initialize()` is single-flight (`_initFuture`) and records `lastInitError`,
  which Settings → ডায়াগনস্টিকস surfaces — Tier 2 degrades to corpus silently,
  so without that string a broken offline model is invisible on a real phone.
- Files are stored per-variant as `model_<variant>.litertlm` and loaded **in
  place** via `installModel(...).fromFile(path).install()` (instant — the
  handler only registers the path, it does not copy) followed by
  `getActiveModel()`. There is no magic filename and no second copy.
- `_purgeIncompatibleLegacyFiles()` deletes pre-1.x MediaPipe artifacts
  (`model.bin`, `model_*.bin`, `gemma-4-E2B-it-web.task`) at boot and on init —
  they are unreadable by this engine, so there is nothing to migrate, only
  ~1.9 GB to reclaim.
- Run config: context `maxTokens: 1024` (>= 1024 required — see Hard
  constraints), reply cap `maxOutputTokens: 512`, `temperature: 0.2`,
  `topK: 40`. Don't bump these casually — it risks OOM on low-RAM phones.
- `DeviceCapability.getRecommendedVariant()` returns **E2B everywhere except
  high-RAM devices**: the model card measures E2B at ~1.7 GB CPU / 0.7 GB GPU
  runtime, while E4B roughly doubles that on top of a 3.5 GB download — an OOM
  risk on the 6–8 GB phones this app targets. E4B stays one tap away in
  Settings. If you swap a model, update that variant's `sizeBytes` /
  `downloadUrl` in `DeviceCapability` and the spike entry in
  `docs/spike-results.md`.

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
Primary `gemma-4-31b-it`, fallback `gemini-3.1-flash-lite` (the old `gemini-2.0-flash-lite`
was deprecated June 1, 2026 — see `docs/IMPLAN.md` §1.1). The chain is invoked only when the app-wide
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
- `R8`/minification is on; rules live in `proguard-rules.pro`. **The MediaPipe /
  protobuf `-keep` rules there are load-bearing for the offline AI** — MediaPipe
  loads its calculator-option protos reflectively and binds native methods over
  JNI, so R8 sees them as unused and deletes them. `-dontwarn` does NOT retain
  anything; only `-keep` does. When they were missing, the release APK shipped
  with 506 classes stripped (the whole `com.google.protobuf` runtime plus
  `CalculatorOptionsProto`), `LlmInference` died building its graph, and Tier 2
  degraded to corpus answers — **release-only**, invisible in debug, while the
  online path kept working because it is pure-Dart HTTP. This class of bug does
  not reproduce in `flutter run` or any test; verify it against the APK:
  ```bash
  flutter build apk --release
  # must print 0 — any name without a trailing ':' is a DELETED class
  grep -cE '^com\.google\.(mediapipe|protobuf|odml)[^:]*$' \
    build/app/outputs/mapping/release/usage.txt
  ```
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
- Point the model download at a `.task` URL, or drop `maxTokens` below 1024, or
  drop `model.close()` from `resetSession()`. See §"Hard constraints" — each one
  breaks the offline model in a way that looks like "the AI just doesn't answer".
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
