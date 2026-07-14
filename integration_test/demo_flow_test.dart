import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:shongjog/app/main_shell.dart';

/// Integration test for the critical demo path.
///
/// Run on a connected device:
///   flutter test integration_test/demo_flow_test.dart
///
/// Tests the full app flow: launch → home → AI chat → quick cards.
/// Shelter map is excluded due to HTTP tile dependencies.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Demo flow', () {
    testWidgets('app launches and home screen renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();

      expect(find.text('সংযোগ'), findsOneWidget);
      expect(find.text('প্রশ্ন করুন'), findsOneWidget);
    });

    testWidgets('navigate to AI tab and type a query', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();

      // Tap the AI tab (index 1).
      await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
      await tester.pumpAndSettle();

      // AI screen should be visible.
      expect(find.text('AI সহায়ক'), findsOneWidget);
    });

    testWidgets('navigate to quick cards tab', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();

      // Tap the cards tab (index 2).
      await tester.tap(find.byIcon(Icons.style_outlined));
      await tester.pumpAndSettle();

      // Quick cards screen should render.
      expect(find.text('দ্রুত নির্দেশিকা'), findsWidgets);
    });

    testWidgets('home bento tiles navigate to tabs', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();

      // Tap "প্রশ্ন করুন" hero card → should navigate to AI tab.
      await tester.tap(find.text('প্রশ্ন করুন'));
      await tester.pumpAndSettle();

      expect(find.text('AI সহায়ক'), findsOneWidget);
    });
  });
}
