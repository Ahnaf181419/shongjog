import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// Root widget.
class ShongjogApp extends StatelessWidget {
  const ShongjogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shongjog',
      theme: ShongjogTheme.light(),
      darkTheme: ShongjogTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.hub,
      routes: AppRoutes.all(),
      debugShowCheckedModeBanner: false,
    );
  }
}