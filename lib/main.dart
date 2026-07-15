import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/connectivity_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await connectivityProvider.initialize();
  runApp(const ShongjogApp());
}
