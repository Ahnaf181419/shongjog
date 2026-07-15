import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme_controller.dart';
import '../features/about/about_screen.dart';
import '../features/contacts/emergency_contacts_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
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
          home: const _StartupGate(),
          routes: {
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.emergencyContacts: (_) =>
                const EmergencyContactsScreen(),
            AppRoutes.about: (_) => const AboutScreen(),
            AppRoutes.meshRadar: (_) => const MeshRadarScreen(),
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('পাওয়া যায়নি')),
              body: const Center(
                child: Text('এই পৃষ্ঠাটি পাওয়া যায়নি।'),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

/// Decides whether to show onboarding (first run) or the main shell.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool? _hasOnboarded;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('pref_has_onboarded') ?? false;
    if (mounted) setState(() => _hasOnboarded = done);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasOnboarded == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded,
                  size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'সংযোগ',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (!_hasOnboarded!) {
      return OnboardingScreen(
        onComplete: () => setState(() => _hasOnboarded = true),
      );
    }

    return const MainShell();
  }
}
