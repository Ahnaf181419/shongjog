import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/locale_controller.dart';
import '../core/theme_controller.dart';
import '../features/about/about_screen.dart';
import '../l10n/app_localizations.dart';
import '../features/contacts/emergency_contacts_screen.dart';
import '../features/emergency/directory_screen.dart';
import '../features/emergency/sos_composer_screen.dart';
import '../features/mesh_comm/mesh_radar_screen.dart';
import '../features/mesh_comm/mesh_call_service.dart';
import '../features/mesh_comm/mesh_service.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/safe_beacon/safe_beacon_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/triage/triage_wizard_screen.dart';
import '../features/admin/admin_login_screen.dart';
import '../features/admin/admin_panel_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/splash/splash_screen.dart';
import '../main.dart';
import 'main_shell.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget.
class ShongjogApp extends StatelessWidget {
  const ShongjogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, localeController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Shongjog',
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: ShongjogTheme.light(),
          darkTheme: ShongjogTheme.dark(),
          themeMode: themeController.mode,
          locale: localeController.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (navContext) => SplashScreen(
              onComplete: () {
                Navigator.of(navContext).pushReplacement(
                  MaterialPageRoute(builder: (_) => const _StartupGate()),
                );
              },
            ),
          ),
          routes: {
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.emergencyContacts: (_) =>
                const EmergencyContactsScreen(),
            AppRoutes.about: (_) => const AboutScreen(),
            AppRoutes.meshRadar: (_) => const MeshRadarScreen(),
            AppRoutes.triage: (_) => const TriageWizardScreen(),
            AppRoutes.safeBeacon: (_) => const SafeBeaconScreen(),
            AppRoutes.directory: (_) => const DirectoryScreen(),
            AppRoutes.sosComposer: (_) => const SosComposerScreen(),
            AppRoutes.adminLogin: (_) => const AdminLoginScreen(),
            AppRoutes.adminPanel: (_) => const AdminPanelScreen(),
            AppRoutes.notifications: (_) => const NotificationsScreen(),
            AppRoutes.profile: (_) => const ProfileScreen(),
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (ctx) => Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(ctx).pageNotFound),
              ),
              body: Center(
                child: Text(AppLocalizations.of(ctx).pageNotFoundDesc),
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
  bool _meshStarted = false;
  static final _lifecycleObserver = _MeshLifecycleObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _checkOnboarding();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
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
                AppLocalizations.of(context).splashTitle,
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

    // Start mesh service once after onboarding (idempotent).
    if (!_meshStarted) {
      _meshStarted = true;
      meshService.start().then((result) {
        if (!result.ok) {
          debugPrint(
            'StartupGate: mesh failed to start (${result.reason}, '
            'wifiOn=${result.wifiOn})',
          );
        }
        // Wire the SOS relay engine regardless — the relay listener is
        // idempotent and only sends when peers are connected, so wiring
        // it on a failed start is harmless.
        meshService.ensureRelayEngine();
        // C1 FIX: initialize the call service so recorder/player open and
        // the signalling listener wires up. Without this, voice calls are
        // permanently dead (_recorderReady / _playerReady stay false).
        meshCallService.initialize().catchError(
          (e) => debugPrint('StartupGate: meshCallService init failed: $e'),
        );
      });
    }

    return const MainShell();
  }
}

/// Pauses mesh discovery when app backgrounds, resumes on foreground.
class _MeshLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background — stop discovery to save battery.
      // Keep advertising so other peers can still find us.
      try {
        Nearby().stopDiscovery();
      } catch (e) { debugPrint("[Catch] app: $e"); }
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground — restart discovery.
      if (meshService.isRunning) {
        meshService.restartDiscovery();
      }
    }
  }
}
