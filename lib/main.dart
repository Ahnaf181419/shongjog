import 'dart:ui' show PlatformDispatcher;
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'app/app.dart';
import 'core/admin_broadcast_service.dart';
import 'core/connectivity_provider.dart';
import 'core/firebase_auth_service.dart';
import 'core/model_manager.dart';
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
  try {
    await modelManager.autoSelectBestModel();
  } catch (e) {
    debugPrint('Model auto-select failed: $e');
  }
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('FlutterDisplayMode failed: $e');
    }
  }
  runApp(const ShongjogApp());
}
