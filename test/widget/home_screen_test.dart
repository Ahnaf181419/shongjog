import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/connectivity_provider.dart';
import 'package:shongjog/features/home/home_screen.dart';

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

    testWidgets('renders 3-tile emergency triad', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.text('জরুরি কার্ড'), findsOneWidget);
      expect(find.text('জরুরি কল'), findsOneWidget);
      expect(find.text('নিকটস্থ আশ্রয়'), findsOneWidget);
      // Settings moved to AppBar — must NOT appear in body.
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
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

    testWidgets('renders weather tile in some state', (tester) async {
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      // Either a loading indicator or a fallback/error message.
      // Real weather fetches never complete in widget tests.
      final hasErrorOrHint = find.textContaining('আবহাওয়া').evaluate().isNotEmpty;
      final hasCircular = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      expect(hasErrorOrHint || hasCircular, isTrue);
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
