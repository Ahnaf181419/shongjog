import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'app/app.dart';
import 'core/admin_broadcast_service.dart';
import 'core/connectivity_provider.dart';
import 'core/device_registry_service.dart';
import 'core/firebase_auth_service.dart';
import 'core/local_notification_service.dart';
import 'core/model_manager.dart';
import 'core/remote_key_service.dart';
import 'features/admin/campaign_request.dart';
import 'features/safe_beacon/safety_status_service.dart';

/// Global key for the root [ScaffoldMessenger]. Lets background operations
/// (e.g. model download completion) show snackbars without a valid
/// [BuildContext] — the widget that started the operation may be long gone.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handlers — capture uncaught errors in release mode where
  // debugPrint is a no-op. Without this, errors vanish silently on a
  // real phone with no logcat attached.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[ZoneError] $error\\n$stack');
    return true;
  };

  // Opt every gallery pick into Android's system photo picker.
  //
  // image_picker defaults `useAndroidPhotoPicker` to FALSE, which sends
  // gallery picks through `Intent.ACTION_GET_CONTENT`. On Android 11+ that
  // intent does not resolve unless the app declares it under <queries>, and
  // it drags in the legacy storage-permission model on older devices. The
  // system photo picker needs no permission at all, shows the modern UI, and
  // only hands back the one file the user chose.
  //
  // Set once here because ImagePickerPlatform.instance is a singleton — the
  // damage scanner, mesh chat and profile screens all pick it up.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final picker = ImagePickerPlatform.instance;
    if (picker is ImagePickerAndroid) {
      picker.useAndroidPhotoPicker = true;
    }
  }

  // flutter_gemma 1.x is modular and registers NO inference engine on its own,
  // so this must run before any getActiveModel() call or it throws "add the
  // engine package". LiteRtLmEngine reads `.litertlm` over FFI — the only
  // Android path for Gemma 4 (its lone `.task` is a web/WASM build).
  try {
    await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);
  } catch (e) {
    debugPrint('FlutterGemma.initialize failed: $e');
  }
  try {
    await connectivityProvider.initialize();
  } catch (e) {
    debugPrint('Connectivity init failed: $e');
  }
  // Firestore backend for the admin panel (campaigns, broadcasts, safety
  // reports) — cross-device sync so an admin on one phone can see data
  // submitted on another. Anonymous auth only, no PII beyond what the
  // existing local services already store. Non-fatal: the app must still
  // boot and work fully offline if Firebase is unreachable (no network on
  // first launch, or no Firebase project configured at all).
  //
  // No explicit `options:` — this is an Android-only build, and the
  // `com.google.gms.google-services` Gradle plugin (android/app/build.gradle.kts)
  // reads android/app/google-services.json at build time and wires the
  // native config automatically. That's also why there's no
  // `firebase_options.dart` / `flutterfire configure` step for this project.
  try {
    await Firebase.initializeApp();
    await firebaseAuthService.ensureSignedIn();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  // Pull the cloud-AI key from Firestore into the device's secure store, so
  // the published APK can ship with NO key compiled into it (a --dart-define
  // key is a plaintext literal in libapp.so — one `grep` recovers it from a
  // public download). Awaited, not fire-and-forget: ChatScreen reads the
  // stored key when it builds, and on a first launch that happens seconds
  // from now. One small doc read, served from Firestore's offline cache on
  // every launch after the first.
  try {
    await remoteKeyService.syncOrRevoke();
  } catch (e) {
    debugPrint('RemoteKeyService sync failed: $e');
  }
  // Must precede adminBroadcastService.initialize(): that subscribes to the
  // broadcast stream, and the first inbound broadcast raises a tray
  // notification through this service.
  try {
    await localNotificationService.initialize();
  } catch (e) {
    debugPrint('LocalNotificationService init failed: $e');
  }
  try {
    await adminBroadcastService.initialize();
  } catch (e) {
    debugPrint('AdminBroadcastService init failed: $e');
  }
  // Registers this device in `users/{uid}` and starts its heartbeat, so the
  // admin panel's Users page and stat row reflect every device running the
  // app — not just the Bluetooth peers within mesh range of the admin.
  try {
    await deviceRegistryService.initialize();
  } catch (e) {
    debugPrint('DeviceRegistryService init failed: $e');
  }
  try {
    await campaignRequestService.initialize();
  } catch (e) {
    debugPrint('CampaignRequestService init failed: $e');
  }
  try {
    safetyStatusService.initialize();
  } catch (e) {
    debugPrint('SafetyStatusService init failed: $e');
  }
  try {
    await modelManager.autoSelectBestModel();
  } catch (e) {
    debugPrint('Model auto-select failed: $e');
  }
  // Deliberately NOT `dart:io`'s Platform.isAndroid. That compiles fine for
  // web but throws `Unsupported operation: Platform._operatingSystem` at
  // runtime — and because this check sits outside the try/catch below, the
  // throw aborted main() before runApp(), leaving the web build stuck on the
  // #89CFF0 HTML splash forever. defaultTargetPlatform is web-safe, and the
  // kIsWeb guard keeps it honest: on web it reports the host OS, which can
  // legitimately be `android` in a mobile browser where this plugin has no
  // implementation.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('FlutterDisplayMode failed: $e');
    }
  }
  runApp(const ShongjogApp());
}
