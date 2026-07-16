# Flutter / R8 keep rules for Shongjog.
#
# This file is referenced by `android/app/build.gradle.kts` via the
# `proguardFiles` directive in the release build type.
#
# Current entries are the minimum needed to satisfy R8 / minification
# for the dependencies in pubspec.yaml at the time of skeleton authoring.
# Add entries here ONLY when a release-build failure identifies a missing
# class from a transitive library.

# -----------------------------------------------------------------------
# okhttp (pulled in by background_downloader)
# -----------------------------------------------------------------------
# background_downloader's okhttp 4.x transitively references OpenJSSE
# platform classes for TLS extension config. These classes are optional
# at runtime (only used on platforms that bundle OpenJSSE) but R8 sees
# the reference and fails the build without an explicit keep.
-dontwarn org.openjsse.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn okhttp3.internal.platform.**

# -----------------------------------------------------------------------
# MediaPipe tasks-genai — DORMANT (kept for if/when the engine is re-added)
# -----------------------------------------------------------------------
# The app now runs the on-device model through `flutter_gemma_litertlm`
# (LiteRT-LM over dart:ffi), whose engine is native .so code that R8 cannot
# touch. Since `flutter_gemma_mediapipe` is not a dependency, MediaPipe is
# no longer in the APK at all and these rules currently match nothing.
#
# They stay because they encode a bug that cost real hours: MediaPipe builds
# its inference graph by reflectively loading proto-generated calculator
# options, so R8 sees no references and deletes them. `-dontwarn` alone (the
# state this file was in) only silences the build warning — it retains
# NOTHING. That shipped a release APK with 506 classes stripped, including
# the whole com.google.protobuf runtime and CalculatorOptionsProto, so
# LlmInference loaded and then died building its graph: chat worked online
# (pure-Dart HTTP) while the on-device model silently failed in release only,
# invisible in every debug build and test.
#
# If `flutter_gemma_mediapipe` is ever added back, these become load-bearing
# again — verify with:
#   grep -cE '^com\.google\.(mediapipe|protobuf)[^:]*$' \
#     build/app/outputs/mapping/release/usage.txt   # must print 0
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-keep class com.google.odml.** { *; }
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**

# protobuf-lite parses generated messages reflectively through these
# members; keeping the class alone is not enough.
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
    <methods>;
}

# JNI binds native methods by name — obfuscation breaks the lookup.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# -----------------------------------------------------------------------
# LiteRT-LM (referenced by name in the HF repo; not the actual runtime)
# -----------------------------------------------------------------------
-keep class com.google.ai.edge.** { *; }
-dontwarn com.google.ai.edge.litertlm.**
-dontwarn com.google.ai.edge.lite.**

# -----------------------------------------------------------------------
# Flutter / Play Core (split install stubs not used in this app)
# -----------------------------------------------------------------------
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# -----------------------------------------------------------------------
# Standard Flutter rules
# -----------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }