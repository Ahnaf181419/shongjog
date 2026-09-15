import 'dart:async';
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
import 'core/locale_controller.dart';
import 'core/model_manager.dart';
import 'core/prompt_cache_warmer.dart';
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

  // Restore the persisted locale before any locale-dependent warm-up so
  // the first frame already renders in the user's chosen language.
  await localeController.ensureLoaded();

  // Prime every locale-dependent asset cache (quick cards, districts,
  // and the six prompt-string bundles) and listen for language switches.
  await PromptCacheWarmer(localeController).start();

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
  // Local notification service: fast, purely on-device plugin initialization.
  try {
    await localNotificationService.initialize();
  } catch (e) {
    debugPrint('LocalNotificationService init failed: $e');
  }

  // Load admin role flag from SharedPreferences (purely local, instant).
  try {
    await firebaseAuthService.loadAdminFlag();
  } catch (e) {
    debugPrint('FirebaseAuthService loadAdminFlag failed: $e');
  }

  // Load local JSON caches for admin broadcasts and campaigns.
  try {
    await adminBroadcastService.initialize();
  } catch (e) {
    debugPrint('AdminBroadcastService init failed: $e');
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

  // Cloud / Firebase backend sync (non-fatal, runs asynchronously so the
  // app boots instantly on frame 1 even with NO internet connection).
  unawaited(_initCloudServices());
  try {
    await modelManager.autoSelectBestModel();
  } catch (e) {
    debugPrint('Model auto-select failed: $e');
  }
  // Warm the engine in the background, so the FIRST AI tap doesn't pay for it.
  //
  // `autoSelectBestModel()` only flips state to `ready` when the weights are
  // on disk — it never loads them, so `isReady` returns true while `_model`
  // is still null. The full `getActiveModel()` load (2.5 GB mmap + tensor
  // allocation, documented at 3–10s and guarded by a 60s ceiling) was
  // therefore paid by whichever AI tool the user happened to open first, on
  // top of that tool's own generation time — and because the state already
  // said "ready", the UI had no way to show that a model load was even
  // happening. It just looked like the tool was slow.
  //
  // Deliberately NOT awaited: this must not delay the first frame. Errors
  // are swallowed because a failed warm-up costs nothing — `generate()` calls
  // `initialize()` itself and will simply retry the load on demand, exactly
  // as it did before.
  unawaited(Future(() async {
    try {
      if (await modelManager.isAnyOnDisk()) {
        final sw = Stopwatch()..start();
        await modelManager.initialize();
        debugPrint('[warmup] model ready in ${sw.elapsedMilliseconds}ms');
      }
    } catch (e) {
      debugPrint('[warmup] deferred model load failed (non-fatal): $e');
    }
  }));
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

/// Initializes Firebase and remote sync in the background.
///
/// Must NEVER block `runApp()` or app boot: if the phone has no internet
/// connection (or is in airplane mode / disaster scenario), this must fail
/// gracefully or register a listener to sync once back online, without
/// delaying the first frame or freezing on the OS splash screen.
Future<void> _initCloudServices() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 3));
    if (connectivityProvider.isOnline) {
      await firebaseAuthService.ensureSignedIn();
      await remoteKeyService.syncOrRevoke();
      await deviceRegistryService.initialize();
    } else {
      // Offline at startup: attach listener to sync once internet is restored
      late void Function() connListener;
      connListener = () {
        if (connectivityProvider.isOnline) {
          connectivityProvider.removeListener(connListener);
          _initCloudServices();
        }
      };
      connectivityProvider.addListener(connListener);
    }
  } catch (e) {
    debugPrint('Cloud services init failed (non-fatal): $e');
  }
}

