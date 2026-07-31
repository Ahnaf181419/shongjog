# Setting Up an On-Device LLM from Scratch (flutter_gemma 1.x + LiteRT-LM)

> How Shongjog runs Gemma 4 E2B fully offline on Android, written so you can
> reproduce it on a clean project. Every value here is verified against a real
> device run (Redmi Note 13, MediaTek, arm64) on 2026-07-16, not copied from a
> tutorial. The traps called out in **⚠️** boxes each cost real debugging time
> — read them before writing code, not after.

**The one-sentence version:** add two packages, register the engine once in
`main.dart`, download the model's **`.litertlm`** file (NOT its `.task`), load
it with `installModel().fromFile()` → `getActiveModel(maxTokens: 1024)`, and
build the APK **arm64-only**.

---

## 0. The mental model

There are three moving parts, and getting any one wrong makes the model
"download but never answer" — a failure that looks identical to a bug:

1. **The right file.** Gemma 4's Android artifact is `.litertlm`. The `.task`
   in the same HuggingFace repo is a WebAssembly build the Android runtime
   cannot open. (§2)
2. **The engine, registered.** `flutter_gemma` 1.x ships no inference engine
   by default. You add `flutter_gemma_litertlm` and register it in `main.dart`,
   or every model call throws. (§3, §4)
3. **The APK, arm64-only.** The engine's native libraries exist for arm64
   alone. If any other ABI directory survives in the APK, Android can install
   the app onto a device with no engine. (§7)

Everything else is ordinary Flutter.

---

## 1. Prerequisites

| Requirement | Value | Why |
|---|---|---|
| Flutter | ≥ 3.44.0 | `flutter_gemma_litertlm` SDK constraint |
| Dart | ≥ 3.12.0 | same |
| Test device | **Android arm64 (arm64-v8a)** | the engine has native libs for arm64 only |
| RAM (device) | ~4 GB+ for E2B, ~8 GB+ for E4B | model card: E2B ≈ 1.7 GB CPU / 0.7 GB GPU at runtime |
| Free storage | 2× the model size during download | ~5 GB for E2B |

> ⚠️ **An x86_64 emulator can never run the model.** There is no x86 engine
> library. Model download will succeed and generation will always fail. Use a
> physical arm64 phone for anything touching inference; `flutter run` on an
> emulator is fine only for UI work.

---

## 2. Choosing the model file — the single most important step

Go to the model's HuggingFace repo, e.g.
[`litert-community/gemma-4-E2B-it-litert-lm`](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm).
You will see files like:

```
gemma-4-E2B-it.litertlm          ← THIS ONE (Android / iOS / Desktop)   2,588,147,712 bytes
gemma-4-E2B-it-web.litertlm      ← web build
gemma-4-E2B-it-web.task          ← web/WASM build — do NOT use on Android
gemma-4-E2B-it_qualcomm_*.litertlm  ← device-specific NPU builds
```

**Download the plain `.litertlm`.** For Shongjog:

| Variant | URL (suffix on the repo `resolve/main/`) | Exact bytes |
|---|---|---|
| E2B | `gemma-4-E2B-it.litertlm` | 2,588,147,712 |
| E4B | `gemma-4-E4B-it.litertlm` | 3,659,530,240 |

> ⚠️ **The `.task` file is a trap.** In this repo the only `.task` is a
> WebAssembly build. The model card documents it solely under *"Running on Web
> with MediaPipe"* — a path it calls "in maintenance mode." The Android
> `LlmInference`/LiteRT-LM runtime opens `.task` as a ZIP; a web `.task` is a
> raw TFLite flatbuffer and cannot be parsed. Feeding it to the native engine
> loads nothing and every answer silently falls back to your non-AI path.

**Verify any candidate file before wiring it in** — the first bytes tell you
the format without downloading gigabytes:

```bash
curl -sL -r 0-3 "<url>" | xxd
#   PK……        → ZIP (a MediaPipe .task bundle)  — OK for MediaPipe engine
#   LITERTLM     → LiteRT-LM bundle                — OK for LiteRT-LM engine (this guide)
#   TFL3         → raw TFLite web build            — WRONG, will not run natively
```

Confirm the exact size (used later for a completeness check):

```bash
curl -sIL "<url>" | grep -i content-length
```

---

## 3. Dependencies

`flutter_gemma` 1.x is modular: a small core plus opt-in **engine** packages.
For `.litertlm` you need the LiteRT-LM engine package.

```yaml
# pubspec.yaml
dependencies:
  flutter_gemma: ^1.3.0
  flutter_gemma_litertlm: ^1.1.0   # the .litertlm (FFI) engine
```

```bash
flutter pub get
```

> The first `flutter build`/`flutter run` triggers a native-assets hook that
> downloads and checksum-verifies the engine's `.so` libraries into
> `~/.cache/flutter_gemma/`. Watch for `litertlm libs cached to …` in the
> build log; if it is absent, the engine did not ship.

---

## 4. Register the engine (once, in `main.dart`)

The core registers **no** engine. Without this call, `getActiveModel()` throws
`"add the engine package"`.

```dart
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);
  } catch (e) {
    debugPrint('FlutterGemma.initialize failed: $e');
  }
  runApp(const MyApp());
}
```

---

## 5. Download the model into the app's documents directory

The engine loads the file **by absolute path, in place** — no copy, no magic
filename. Store it wherever `getApplicationDocumentsDirectory()` points:

- Android: `/data/data/<pkg>/app_flutter/`
- The file name is your choice; Shongjog uses `model_<variant>.litertlm`.

> ⚠️ **`getApplicationDocumentsDirectory()` is `app_flutter/`, not `files/`.**
> If you push a model onto a device by hand (§9) put it in `app_flutter/`, or
> the app's on-disk check will not find it and generation never even starts.

Any resumable HTTP download works. Sketch (stdlib `HttpClient` with Range
resume):

```dart
final dir = await getApplicationDocumentsDirectory();
final path = '${dir.path}/model_e2b.litertlm';
final f = File(path);

final existing = await f.exists() ? await f.length() : 0;
final req = await HttpClient().getUrl(Uri.parse(downloadUrl));
if (existing > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
final resp = await req.close();
final sink = f.openWrite(mode: existing > 0 && resp.statusCode == 206
    ? FileMode.append : FileMode.write);
await resp.forEach(sink.add);
await sink.flush();
await sink.close();
```

**Mark "downloaded" by comparing size to the known Content-Length with a 99%
floor** — not a flat threshold. A partial download that happens to exceed a
flat floor gets marked ready and then fails to load forever.

```dart
Future<bool> isOnDisk(File f, int expectedBytes) async =>
    await f.exists() && await f.length() >= (expectedBytes * 0.99).round();
```

> ⚠️ **A guessed `expectedBytes` silently rejects a complete download.** Use
> the real `Content-Length` from §2. Shongjog's constants:
> `_e2bBytes = 2588147712`, `_e4bBytes = 3659530240`.

---

## 6. Load and run the model

### Load (once the file is on disk)

```dart
// Register the on-disk file with the plugin. fromFile() is instant — it only
// records the path, it does not copy, so a 2.5 GB model costs no extra disk.
await FlutterGemma.installModel(
  modelType: ModelType.gemma4,
  fileType: ModelFileType.litertlm,
).fromFile(path).install();

// maxTokens here is the CONTEXT WINDOW, not the reply length.
final model = await FlutterGemma.getActiveModel(maxTokens: 1024);
```

> ⚠️ **Context window must be ≥ 1024.** `.litertlm` fails to allocate tensors
> below 1024 (upstream #318). The old MediaPipe-era `maxTokens: 512` breaks
> outright here. `maxTokens` is the *whole context* (input + output); it is
> **not** how you make replies short — that's `maxOutputTokens` below.

### Generate (per query)

```dart
final session = await model.createSession(
  temperature: 0.2,
  topK: 40,
  maxOutputTokens: 512,   // caps GENERATED tokens without shrinking the context
);
try {
  await session.addQueryChunk(Message.text(text: prompt, isUser: true));
  return await session.getResponse();     // blocking; see "streaming" below
} finally {
  await session.close();                  // a live session holds a KV cache
}
```

> ⚠️ **Create a fresh session per query and `close()` it.** The `.litertlm`
> engine allows one live conversation at a time and each session holds a
> KV cache (~100–500 MB). Leaking sessions OOMs the process after a few
> questions on a phone.

### Unload / switch variants

```dart
// Closing is NOT optional. Weights are mmap'd natively (2.5 GB E2B / 3.5 GB
// E4B) and close() is also what lets the plugin core reset its singleton
// bookkeeping. Nulling the Dart reference alone leaves the old model resident
// while the next one loads — an OOM.
await model.close();
```

The full production version of all of the above lives in
`lib/core/model_manager.dart` (single-flight init, tier-based variant
selection, legacy-file purge, `lastInitError` for diagnostics).

---

## 7. Android build configuration (arm64-only)

Three settings are **each** insufficient alone; you need all three, because
they prune different things.

### `android/app/build.gradle.kts`

```kotlin
android {
    defaultConfig {
        ndk { abiFilters += listOf("arm64-v8a") }   // constrains NDK-built output only
    }

    // abiFilters does NOT touch prebuilt .so files inside plugin AARs
    // (libdartjni.so, libdatastore_shared_counter.so). A leftover lib/x86_64/
    // directory is enough for Android to select x86_64 at install time — on a
    // build whose engine and libflutter.so exist for arm64 only. Exclude them.
    packaging {
        jniLibs {
            excludes += setOf(
                "lib/armeabi-v7a/**",
                "lib/armeabi/**",
                "lib/x86/**",
                "lib/x86_64/**",
                "lib/mips/**",
            )
        }
    }
}
```

### The build command

```bash
flutter build apk --release --target-platform android-arm64
```

`--target-platform android-arm64` prunes Flutter's own libs; the `packaging`
block prunes the plugin AARs; `abiFilters` covers NDK output. Together the APK
is honestly arm64-v8a.

### R8 / ProGuard note

This app uses the LiteRT-LM engine, which is **native FFI** code R8 cannot
touch, so there is nothing special to keep. **But** if you ever add
`flutter_gemma_mediapipe` (the `.task` engine), MediaPipe loads proto classes
reflectively and R8 will delete them — `-dontwarn` does **not** retain
anything, only `-keep` does. Keep this in `proguard-rules.pro` as insurance:

```proguard
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-keep class com.google.odml.** { *; }
```

Verify nothing was stripped (must print `0`):

```bash
grep -cE '^com\.google\.(mediapipe|protobuf|odml)[^:]*$' \
  build/app/outputs/mapping/release/usage.txt
```

---

## 8. Building the release APK

Shongjog wraps all of this — arm64-only build + pre/post-build verification —
in `scripts/build_release.sh` (and `.ps1` for Windows). It fails the build if:

- the engine is not registered in `main.dart`,
- any variant points at a `.task` download URL (runs `device_capability_test`),
- the engine libs are missing from the APK,
- a non-arm64 ABI dir survived,
- R8 stripped any MediaPipe/protobuf class.

```bash
bash scripts/build_release.sh          # offline build (no cloud key)
GEMINI_API_KEY=xxx bash scripts/build_release.sh   # with cloud fallback
```

> These checks exist because every offline-model breakage in this project was
> invisible to `flutter analyze`, `flutter test`, AND `flutter run`. They only
> ever appeared in an installed release APK. A build script cannot load a
> 2.5 GB model, so it verifies the artifact is well-formed; **only a device
> test proves generation actually runs.**

---

## 9. Installing and testing on a device

### Normal path

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
# launch, let the app download the model in-app, then ask an off-corpus question
```

### Fast path — side-load the model (skip the 2.5 GB in-app download)

Useful when iterating. The app's private dir isn't writable by `adb push`
directly, so stage in `/data/local/tmp` and stream it in with `run-as`
(**requires a debug build** — release builds block `run-as`):

```bash
adb push model_e2b.litertlm /data/local/tmp/
adb shell "run-as <pkg> sh -c 'cat /data/local/tmp/model_e2b.litertlm > app_flutter/model_e2b.litertlm'"
adb shell rm /data/local/tmp/model_e2b.litertlm
adb shell am force-stop <pkg>    # restart so the app re-scans and activates it
```

> ⚠️ Put it in `app_flutter/`, not `files/` (§5). And on MIUI, `adb shell
> input tap` is blocked unless "USB debugging (Security settings)" is on — you
> may need to drive the UI by hand while reading `adb logcat`.

### Confirming it actually generates (the only real test)

Ask a question that is **not** covered by your offline knowledge base, so a
working model must generate and a broken one visibly falls back. In a debug
build, `logcat` shows the path taken:

```bash
adb logcat -s flutter:*
# success looks like:
#   [ChatRepo/Tier2] shouldTryDevice=true
#   [ChatRepo/Tier2] device path success len=685
# failure looks like:
#   [ChatRepo/Tier2] shouldTryDevice=false          (file not found / not activated)
#   [ChatRepo/Tier2] device path FAILED: <native error>
```

> Release builds strip `debugPrint`, so confirm from the UI instead
> (Shongjog: the AI-tab subtitle turns green "অফলাইন এআই (Gemma 4)" and an
> off-corpus question produces generated text).

---

## 10. Troubleshooting — symptom → cause

| Symptom | Most likely cause | Fix |
|---|---|---|
| Downloads, but chat always gives the canned/fallback answer | Model file not where the app looks, OR size check failing | Confirm the file is in `app_flutter/` (§5) and its size matches Content-Length within 99% (§2, §5) |
| `getActiveModel` throws "add the engine package" | Engine not registered | Add `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])` (§4) |
| Model loads, generation throws in `top_p_cpu_sampler` / tensor buffer | GPU/accelerator init failed on the host (e.g. `VK_ERROR_DEVICE_LOST`) | Real devices use OpenCL/NPU and are fine; on an unsupported host force `PreferredBackend.cpu` in `getActiveModel` |
| Init throws "fails to allocate tensors" | `maxTokens` < 1024 | Raise context to ≥ 1024; cap replies with `maxOutputTokens` instead (§6) |
| Works in debug, model silently fails only in release | R8 stripped MediaPipe classes (only if using the MediaPipe engine) | Add `-keep` rules; verify with the `usage.txt` grep (§7) |
| App installs on an emulator but model never runs | x86 build with no engine | Build arm64-only (§7); test on a real arm64 phone |
| Downloaded with an old build, now unreadable | Leftover `.task`/`.bin` from a previous engine | Purge incompatible legacy files on boot (see `_purgeIncompatibleLegacyFiles`) |

---

## 11. Performance — what to expect and how to improve it

Measured on a Redmi Note 13 (MediaTek, arm64), E2B, GPU backend:

| Phase | Time | Frequency |
|---|---|---|
| Engine cold start (load + accelerator init + KV prefill) | ~30 s | once per app launch |
| Prefill (reads the prompt) | 5–8.5 s | every question |
| Decode | ~6.4 tokens/s | every question (a 685-char answer ≈ 29 s) |

Decode speed is hardware-bound (a flagship measures ~46 tok/s). Levers that
help without changing the model:

1. **Pre-warm the engine at launch** — call the load path in the background
   after first frame so the ~30 s cold start is done before the first question.
2. **Stream tokens** — `session.getResponseAsync()` returns a `Stream<String>`;
   showing tokens as they arrive turns a 30 s blank wait into ~5–8 s to first
   text (same total time, far better perceived speed).
3. **Shorter answers** — lower `maxOutputTokens` (512 → 256) for terser,
   faster replies.
4. **Release build** — AOT is snappier than debug on the UI side.
5. **Backend** — default is GPU with CPU fallback; pass `preferredBackend` to
   `getActiveModel` to pin one.

---

## 12. Reference — files in this repo

| File | Role |
|---|---|
| `lib/main.dart` | Engine registration |
| `lib/core/model_manager.dart` | Download, load, session lifecycle, variant selection, diagnostics |
| `lib/core/device_capability.dart` | Model catalog (URLs, exact sizes, availability), RAM-tier selection |
| `lib/features/chat/local_llm.dart` | The `LocalLlm` contract the chat layer depends on |
| `lib/features/chat/chat_repository.dart` | 3-tier fallback (cloud → device → corpus → canned) |
| `android/app/build.gradle.kts` | arm64 ABI enforcement |
| `android/app/proguard-rules.pro` | R8 keeps (dormant unless MediaPipe is added) |
| `scripts/build_release.sh` / `.ps1` | Verified release build |
| `test/unit/device_capability_test.dart` | Enforces `.litertlm` URLs + exact sizes |
