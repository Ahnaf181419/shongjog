import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/locale_controller.dart';
import '../core/pending_chat_prompt.dart';
import '../core/theme_controller.dart';
import '../features/about/about_screen.dart';
import '../l10n/app_localizations.dart';
import '../features/contacts/emergency_contacts_screen.dart';
import '../features/emergency/directory_screen.dart';
import '../features/triage/triage_tts.dart';
import '../features/voice/tts_service.dart';
import '../features/emergency/sos_composer_screen.dart';
import '../features/mesh_comm/mesh_radar_screen.dart';
import '../features/mesh_comm/mesh_call_service.dart';
import '../features/mesh_comm/mesh_service.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/quick_cards/quick_card_detail_screen.dart';
import '../features/safe_beacon/safety_status_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/triage/triage_wizard_screen.dart';
import '../features/admin/admin_login_screen.dart';
import '../features/admin/admin_pages.dart';
import '../features/admin/admin_panel_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/damage_scanner/damage_scan_screen.dart';
import '../features/intelligence/situation_summary_screen.dart';
import '../features/planner/planner_screen.dart';
import '../features/planner/kit_screen.dart';
import '../features/planner/risk_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/splash/splash_screen.dart';
import '../main.dart';
import 'main_shell.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget.
class ShongjogApp extends StatelessWidget {
  const ShongjogApp({super.key});

  /// Upper bound on the OS text scale.
  ///
  /// Android lets a user pick up to 2.0x. Honouring that fully is the right
  /// default for a reading app, but Shongjog's screens are dense — a triage
  /// wizard, a shelter map with overlays, a chat composer — and were laid out
  /// against a 14sp floor. Past ~1.5x, labels stop wrapping and start
  /// clipping, which loses information rather than enlarging it.
  ///
  /// 1.5x is a deliberate compromise: it is 50% larger type, the range that
  /// covers most low-vision users, while keeping every layout intact. It is a
  /// ceiling, not a floor — anyone below it is unaffected.
  ///
  /// Downscaling is NOT clamped. A user who has shrunk their system text has
  /// chosen that, and nothing here should override it upward.
  static const double maxTextScale = 1.5;

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
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(maxScaleFactor: maxTextScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const _SplashBoot(),
          routes: {
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.emergencyContacts: (_) =>
                const EmergencyContactsScreen(),
            AppRoutes.about: (_) => const AboutScreen(),
            AppRoutes.meshRadar: (_) => const MeshRadarScreen(),
            AppRoutes.triage: (_) => TriageWizardScreen(
                  tts: _TriageTtsBridge(),
                ),
            AppRoutes.safeBeacon: (_) => const SafetyStatusScreen(),
            AppRoutes.directory: (_) => const DirectoryScreen(),
            AppRoutes.sosComposer: (_) => const SosComposerScreen(),
            AppRoutes.adminLogin: (_) => const AdminLoginScreen(),
            AppRoutes.adminPanel: (_) => const AdminPanelScreen(),
            AppRoutes.adminDashboard: (_) => const AdminDashboardPage(),
            AppRoutes.adminUsers: (_) => const AdminUsersPage(),
            AppRoutes.adminCampaigns: (_) => const AdminCampaignsPage(),
            AppRoutes.adminBroadcast: (_) => const AdminBroadcastPage(),
            AppRoutes.adminDangerList: (_) => const AdminDangerListPage(),
            AppRoutes.notifications: (_) => const NotificationsScreen(),
            AppRoutes.profile: (_) => const ProfileScreen(),
            AppRoutes.planner: (_) => const PlannerScreen(),
            AppRoutes.kit: (_) => const KitScreen(),
            AppRoutes.risk: (_) => const RiskScreen(),
            AppRoutes.damageScanner: (_) => const DamageScannerScreen(),
            AppRoutes.situationSummary: (_) =>
                const SituationSummaryScreen(),
            AppRoutes.quickCardDetail: (ctx) {
              final cardId = ModalRoute.of(ctx)?.settings.arguments;
              return QuickCardDetailScreen(
                cardId: cardId is String ? cardId : '',
              );
            },
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

/// Hosts the [SplashScreen] and pre-loads the onboarding check in
/// parallel with the breathing animation. When the splash calls
/// [SplashScreen.onComplete], this widget awaits the already-running
/// future and crossfades to [_StartupGate] — no intermediate loading
/// screen (design.md §7.8).
class _SplashBoot extends StatefulWidget {
  const _SplashBoot();

  @override
  State<_SplashBoot> createState() => _SplashBootState();
}

class _SplashBootState extends State<_SplashBoot> {
  late final Future<bool> _onboardingFuture;

  @override
  void initState() {
    super.initState();
    _onboardingFuture = _checkOnboarding();
  }

  static Future<bool> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pref_has_onboarded') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      onComplete: () async {
        final navigator = Navigator.of(context);
        final hasOnboarded = await _onboardingFuture;
        if (!mounted) return;
        navigator.pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) =>
                _StartupGate(hasOnboarded: hasOnboarded),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      },
    );
  }
}

/// Decides whether to show onboarding (first run) or the main shell.
///
/// Receives the pre-computed onboarding status from [_SplashBoot] so
/// there is no loading state — the screen builds directly to either
/// [OnboardingScreen] or [MainShell].
class _StartupGate extends StatefulWidget {
  const _StartupGate({required this.hasOnboarded});

  final bool hasOnboarded;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late bool _hasOnboarded = widget.hasOnboarded;
  bool _meshStarted = false;
  static final _lifecycleObserver = _MeshLifecycleObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasOnboarded) {
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

    return PendingChatPrompt(
      notifier: ValueNotifier<String?>(null),
      child: const MainShell(),
    );
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
      // App coming to foreground — restart discovery and advertising.
      if (meshService.isRunning) {
        meshService.restartDiscovery();
        meshService.restartAdvertising();
      }
    }
  }
}

/// Bridges [TtsService] into the [TriageTts] port, gated by the
/// `pref_auto_read` user preference (AGENTS.md: auto-read is opt-in).
/// Caches the lookup so we don't hit SharedPreferences on every
/// question.
class _TriageTtsBridge implements TriageTts {
  static final TtsService _service = TtsService();

  Future<bool> _isAutoReadOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pref_auto_read') ?? false;
  }

  @override
  Future<void> speak(String text) async {
    if (!await _isAutoReadOn()) return;
    await _service.speak(text);
  }

  @override
  Future<void> stop() async {
    if (!await _isAutoReadOn()) return;
    await _service.stop();
  }
}
