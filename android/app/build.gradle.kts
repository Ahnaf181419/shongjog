plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads google-services.json (gitignored, per-developer download from the
    // Firebase console) and wires the native Android Firebase config.
    id("com.google.gms.google-services")
}

android {
    namespace = "dev.frostflux.shongjog"
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
        applicationId = "dev.frostflux.shongjog"
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

    // abiFilters above only constrains NDK-built output. Prebuilt .so files
    // inside plugin AARs (libdartjni.so, libdatastore_shared_counter.so) slip
    // past it, and `--target-platform android-arm64` prunes only Flutter's own
    // libs — so a lib/x86_64/ directory survives in the APK. That is enough for
    // Android to select x86_64 at install time on a build whose LiteRT-LM
    // engine and libflutter.so exist for arm64 ONLY. Exclude them at packaging
    // so the APK is honestly arm64-v8a (AGENTS.md §"Hard constraints").
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
