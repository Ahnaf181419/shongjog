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
# MediaPipe (pulled in by flutter_gemma for inference graphs)
# -----------------------------------------------------------------------
# flutter_gemma uses MediaPipe graphs internally. The proto-generated
# classes are loaded reflectively at runtime via MediaPipe's graph
# config; R8's static analysis cannot see the references and fails
# the build without explicit dontwarn rules.
-dontwarn com.google.mediapipe.proto.**
-dontwarn com.google.mediapipe.framework.**
-dontwarn com.google.mediapipe.examples.**

# -----------------------------------------------------------------------
# LiteRT-LM (flutter_gemma runtime)
# -----------------------------------------------------------------------
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