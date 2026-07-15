import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/connectivity_provider.dart';
import 'core/model_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
