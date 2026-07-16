import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'app/app.dart';
import 'core/connectivity_provider.dart';
import 'core/model_manager.dart';

/// Global key for the root [ScaffoldMessenger]. Lets background operations
/// (e.g. model download completion) show snackbars without a valid
/// [BuildContext] — the widget that started the operation may be long gone.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  try {
    await modelManager.autoSelectBestModel();
  } catch (e) {
    debugPrint('Model auto-select failed: $e');
  }
  runApp(const ShongjogApp());
}
