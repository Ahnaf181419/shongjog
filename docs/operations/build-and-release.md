# Build, Release & Verification Gates

## 1. Prerequisites & Environment

| Component | Required Version / Specification | Notes |
|---|---|---|
| **Flutter SDK** | `3.x` | Stable channel |
| **Dart SDK** | `^3.12.0` | Null-safety strictly enforced |
| **Android SDK** | `compileSdk 36`, `targetSdk 36`, `minSdk 26` | Android 8.0 Oreo minimum |
| **Android Build Tools** | AGP `9.x`, Kotlin JVM `17` | Gradle 8.x+ |
| **Target Hardware** | Physical Android device (`arm64-v8a`) | **Required for local inference**. x86_64 emulators run the UI only; LiteRT-LM calls fail gracefully to Tier 3 on non-arm64 hardware. |
| **Device Storage** | ~3 GB free | Required for downloading the 2.47 GB `gemma-4-E2B-it.litertlm` model file. |

---

## 2. Firebase Configuration (Build Requirement)

A fresh repository clone will fail to compile without `google-services.json`:

1. In the Firebase Console, create a project and register an Android app with Package Name / Application ID:
   ```
   dev.frostflux.shongjog
   ```
2. Download `google-services.json` and place it in `android/app/google-services.json` (this file is gitignored).
3. Enable **Anonymous Authentication** in Firebase Console (`Authentication ➔ Sign-in method ➔ Anonymous`).
4. Provision a Cloud Firestore database in production mode.
5. Deploy or copy-paste [`firestore.rules`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/firestore.rules) into the Firestore Console.

---

## 3. Building Verified Release APKs

Do not build production binaries via raw `flutter build apk`. Use the verified release scripts:

```bash
# macOS / Linux:
bash scripts/build_release.sh

# Windows (PowerShell):
pwsh scripts/build_release.ps1
```

---

## 4. The 10 Automated Release Verification Gates

The release script compiles the APK and executes **10 automated inspection gates** against the generated APK binary. Each gate guards against a bug that previously broke releases in production:

```
[ Build Release APK ]
          │
          ▼
Gate 1: LiteRT-LM Libraries Check     ──► Ensures liblitert_lm.so exists in arm64-v8a.
Gate 2: ABI Targeting Verification    ──► Ensures APK contains arm64-v8a binaries only.
Gate 3: R8 ProGuard Preservation      ──► Validates MediaPipe & Protobuf classes are unstripped.
Gate 4: Firebase Plugin Wiring        ──► Confirms Firebase core native binaries are present.
Gate 5: Notification Service Bundle   ──► Checks flutter_local_notifications receiver declarations.
Gate 6: Plaintext Secret Audit        ──► Scans libapp.so with grep to ensure ZERO API keys leaked.
Gate 7: POST_NOTIFICATIONS Permission ──► Verifies Android 13+ notification runtime permission.
Gate 8: Package Visibility <queries>  ──► Ensures Speech Recognizer, TTS & Camera visible to app.
Gate 9: Res Shrinking Icon Guard      ──► Verifies app & notification icons survived R8 shrinkage.
Gate 10: Asset Bundle Integrity       ──► Verifies corpus.json, vectors.bin & GeoJSON bundled intact.
```

> **Why Gate 8 is Critical:**  
> Android 11+ package visibility filters out system services if they are not explicitly declared in a `<queries>` block in `AndroidManifest.xml`. Without Gate 8, speech-to-text, text-to-speech, camera, and file pickers silently fail without throwing runtime exceptions.

---

## 5. Testing & Quality Assurance Suite

Shongjog enforces strict verification standards before any commit or release:

```bash
# Static analysis (must report zero warnings/errors):
flutter analyze

# Complete test suite:
flutter test

# Focused test categories:
flutter test test/unit/        # Pure Dart RAG, vector matching, controllers
flutter test test/widget/      # UI widgets, sliders, responsive layout, screens
```

### Coverage Highlights
- **WCAG Accessibility**: Automated color contrast checks verify minimum 4.5:1 text-to-background contrast across light, dark, and high-contrast themes.
- **Font & Display Scaling**: Layouts are tested under 1.5× system text scaling to prevent text clipping during emergency usage.
- **Bangla Number Conversion**: Tests verify bidirectionally accurate conversion of numerals (`১, ২, ৩` ↔ `1, 2, 3`).
- **Mesh Link & Path Traversal Resistance**: Security tests verify that P2P file transfers reject path traversal attacks (`../../`).
- **Access Control & Fallback Chains**: Validates that Firestore security rules and the 4-tier AI fallback chain execute correctly.
