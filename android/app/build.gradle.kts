plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.shongjog"
    // Explicit SDK levels override the Flutter template defaults.
    // - compileSdk 36: required by androidx.core:1.17.0 and
    //   androidx.exifinterface:1.4.1 (transitive via flutter_map /
    //   geolocator_android). The Gradle error printed when this is too low
    //   is the source of truth.
    // - targetSdk 36: modern runtime behavior.
    // - minSdk 26: covers >97% of Android devices and satisfies the platform
    //   floor for flutter_gemma LiteRT-LM runtime + on-device embedding.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.shongjog"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Restrict to arm64-v8a — required for on-device Gemma LiteRT-LM
        // runtime and keeps APK size minimal for the hackathon demo.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // R8 / minification is on for release. Keep rules live in
            // proguard-rules.pro (referenced below).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
