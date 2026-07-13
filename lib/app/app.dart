import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// Root widget. The skeleton wires theme + routes; Phase 3 will layer in the
/// ModelManager / KB loader / connectivity state providers above this shell.
class ShongjogApp extends StatelessWidget {
  const ShongjogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shongjog',
      theme: ShongjogTheme.light(),
      darkTheme: ShongjogTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.chat,
      routes: AppRoutes.all(),
      debugShowCheckedModeBanner: false,
    );
  }
}