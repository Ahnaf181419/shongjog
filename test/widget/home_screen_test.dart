import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/connectivity_provider.dart';
import 'package:shongjog/features/home/home_screen.dart';
import 'package:shongjog/features/weather/weather_card.dart';

void main() {
  Widget wrapHome({ValueChanged<int>? onNavigateToTab}) {
    return MaterialApp(
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
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.text('সংযোগ'), findsOneWidget);
    });

    testWidgets('renders hero card with primary CTA', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.text('প্রশ্ন করুন'), findsOneWidget);
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

    testWidgets('renders tip card after scrolling', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      await tester.scrollUntilVisible(
        find.text('আজকের পরামর্শ'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('আজকের পরামর্শ'), findsOneWidget);
    });

    testWidgets('AI hero CTA triggers onNavigateToTab(1)', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        wrapHome(onNavigateToTab: (i) => tappedIndex = i),
      );
      await pumpOnce(tester);
      await tester.tap(find.text('প্রশ্ন করুন'));
      expect(tappedIndex, 1);
    });

    testWidgets('hero panel renders a gradient decoration', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      // The drenched hero uses `Ink.decoration` with a `BoxDecoration`
      // whose `gradient` is set. Find exactly one such widget in the tree.
      final gradientInks = find.byWidgetPredicate((w) {
        if (w is! Ink) return false;
        final d = w.decoration;
        if (d is! BoxDecoration) return false;
        return d.gradient != null;
      });
      expect(gradientInks, findsOneWidget);
    });

    testWidgets('hero includes the Bangla numeral status chip', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      // Asymmetric right-side marker — Bangla '১' inside a bordered chip.
      expect(find.text('১'), findsOneWidget);
      expect(find.text('২৪/৭ সক্রিয়'), findsOneWidget);
    });
  });
}
