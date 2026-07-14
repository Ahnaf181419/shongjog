import 'package:flutter/material.dart';

import '../core/theme_controller.dart';
import '../features/about/about_screen.dart';
import '../features/contacts/emergency_contacts_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/mesh_comm/mesh_radar_screen.dart';
import 'main_shell.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget.
class ShongjogApp extends StatelessWidget {
  const ShongjogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Shongjog',
          theme: ShongjogTheme.light(),
          darkTheme: ShongjogTheme.dark(),
          themeMode: themeController.mode,
          home: const MainShell(),
          routes: {
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.emergencyContacts: (_) =>
                const EmergencyContactsScreen(),
            AppRoutes.about: (_) => const AboutScreen(),
            AppRoutes.meshRadar: (_) => const MeshRadarScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
