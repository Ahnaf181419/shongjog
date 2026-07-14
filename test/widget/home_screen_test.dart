import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      await tester.pumpWidget(wrapHome());
      await pumpOnce(tester);
      expect(find.text('অফলাইনে চলে'), findsOneWidget);
      expect(find.text('তথ্য প্রস্তুত'), findsOneWidget);
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
  });
}
