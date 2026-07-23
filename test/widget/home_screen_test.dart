import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/connectivity_provider.dart';
import 'package:shongjog/core/device_capability.dart';
import 'package:shongjog/core/model_manager.dart';
import 'package:shongjog/features/home/home_screen.dart';
import 'package:shongjog/features/weather/weather_card.dart';
import 'package:shongjog/main.dart';

void main() {
  Widget wrapHome({ValueChanged<int>? onNavigateToTab}) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: HomeScreen(onNavigateToTab: onNavigateToTab),
      routes: {
        '/settings': (_) => const Scaffold(body: Center(child: Text('Settings'))),
        '/emergency-contacts': (_) =>
            const Scaffold(body: Center(child: Text('Contacts'))),
      },
    );
  }

  /// Pump once past the first frame (animations never settle — the status
  /// dot and breathing pulse run forever by design).
  Future<void> pumpOnce(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  group('HomeScreen', () {
    testWidgets('renders app bar with profile title', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      // The AppBar title is now a _ProfileTitle widget (avatar + name).
      // With no profile set, it shows a person icon.
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('renders 2-tile emergency triad + AppBar 999 pill',
        (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      // Two body tiles remain — 999 has moved to the AppBar pill.
      expect(find.text('জরুরি কার্ড'), findsOneWidget);
      expect(find.text('নিকটস্থ আশ্রয়'), findsOneWidget);
      // জরুরি কল lives in the AppBar pill exactly once.
      expect(find.text('জরুরি কল'), findsOneWidget);
      // Settings still in AppBar — must NOT appear in body.
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    testWidgets('app bar shows জরুরি কল pill left of settings icon',
        (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      final pillBox = tester.getRect(find.text('জরুরি কল'));
      final settingsBox = tester.getRect(find.byIcon(Icons.settings_rounded));
      // The meaningful invariant: pill is to the left of settings. Y-axis
      // alignment is incidental (the pill has its own vertical padding).
      expect(pillBox.right, lessThan(settingsBox.left + 1));
    });

    testWidgets('app bar জরুরি কল pill routes to emergency contacts',
        (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      await tester.tap(find.text('জরুরি কল'));
      // Pump the page transition without pumpAndSettle — the hero
      // press-scale + the breathing dot are infinite by design.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // wrapHome stubs /emergency-contacts with a Scaffold that renders
      // 'Contacts' as body text.
      expect(find.text('Contacts'), findsOneWidget);
    });

    testWidgets('renders status line', (tester) async {
      // Force offline branch so this test deterministically exercises the
      // label the rest of the test file was written against.
      connectivityProvider.debugSetOnline(false);
      addTearDown(() => connectivityProvider.debugSetOnline(true));
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.text('অফলাইনে চলে'), findsOneWidget);
      expect(find.text('তথ্য প্রস্তুত'), findsOneWidget);
    });

    testWidgets('status line shows online label when provider reports online',
        (tester) async {
      connectivityProvider.debugSetOnline(true);
      addTearDown(() => connectivityProvider.debugSetOnline(false));
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.text('অনলাইনে চলছে'), findsOneWidget);
      expect(find.text('তথ্য প্রস্তুত'), findsOneWidget);
      expect(find.text('অফলাইনে চলে'), findsNothing);
    });

    testWidgets('status line flips when connectivity changes', (tester) async {
      connectivityProvider.debugSetOnline(true);
      addTearDown(() => connectivityProvider.debugSetOnline(false));
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.text('অনলাইনে চলছে'), findsOneWidget);

      connectivityProvider.debugSetOnline(false);
      await tester.pump();
      expect(find.text('অফলাইনে চলে'), findsOneWidget);
      expect(find.text('অনলাইনে চলছে'), findsNothing);
    });

    testWidgets('renders weather card in some state', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      // Real weather fetches never complete in widget tests, so the card
      // is in skeleton / offline state. Verifying the widget type itself
      // is present guarantees the new WeatherCard replaces the old tile.
      expect(find.byType(WeatherCard), findsOneWidget);
      // Every state label contains 'আবহাওয়া' for consistency.
      final hasBangla = find.textContaining('আবহাওয়া').evaluate().isNotEmpty;
      expect(hasBangla, isTrue);
    });

    testWidgets('renders insight card after scrolling', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      // With no chat history the intelligence engine yields the default
      // insight, so its title is the stable thing to assert on.
      await tester.scrollUntilVisible(
        find.text('অফলাইন AI প্রস্তুত'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('অফলাইন AI প্রস্তুত'), findsOneWidget);
    });

  });

  // ════════════════════════════════════════════════════════════════
  //  Download progress chip — visible on Home when modelManager reports
  //  a variant downloading. Lets the user leave Settings mid-download.
  // ════════════════════════════════════════════════════════════════
  group('HomeScreen download progress chip', () {
    setUp(() {
      for (final v in ModelVariant.values) {
        modelManager.debugClearDownloadingState(v);
      }
    });

    tearDown(() {
      for (final v in ModelVariant.values) {
        modelManager.debugClearDownloadingState(v);
      }
    });

    testWidgets('shows progress chip when a variant is downloading',
        (tester) async {
      modelManager.debugSetDownloadingState(ModelVariant.e2b, 0.45);
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.textContaining('ডাউনলোড'), findsWidgets);
      expect(find.textContaining('৪৫'), findsWidgets);
    });

    testWidgets('updates percentage when progress changes', (tester) async {
      modelManager.debugSetDownloadingState(ModelVariant.e2b, 0.45);
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.textContaining('৪৫'), findsWidgets);

      modelManager.debugSetDownloadingState(ModelVariant.e2b, 0.80);
      await tester.pump();
      expect(find.textContaining('৮০'), findsWidgets);
    });

    testWidgets('hides progress chip when no download is active',
        (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      // "মডেল ডাউনলোড" is the chip text — must not appear when idle.
      expect(find.textContaining('মডেল ডাউনলোড'), findsNothing);
    });

    testWidgets('hides chip after download completes', (tester) async {
      modelManager.debugSetDownloadingState(ModelVariant.e2b, 0.90);
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.textContaining('ডাউনলোড'), findsWidgets);

      modelManager.debugClearDownloadingState(ModelVariant.e2b);
      await tester.pump();
      expect(find.textContaining('মডেল ডাউনলোড'), findsNothing);
    });

    testWidgets('shows completion snackbar when download finishes',
        (tester) async {
      modelManager.debugSetDownloadingState(ModelVariant.e2b, 0.95);
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);

      // Simulate download completing: state goes downloading → not-downloaded.
      modelManager.debugClearDownloadingState(ModelVariant.e2b);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('প্রস্তুত'), findsWidgets);
    });
  });
}
