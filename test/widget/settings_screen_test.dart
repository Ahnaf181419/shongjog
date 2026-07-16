import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/app/router.dart';
import 'package:shongjog/features/settings/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pref_auto_read': true,
      'pref_voice_input': true,
    });
  });

  Widget wrapSettings() {
    return MaterialApp(
      home: const SettingsScreen(),
      routes: {
        AppRoutes.about: (_) => const Scaffold(body: Text('About')),
        AppRoutes.emergencyContacts: (_) =>
            const Scaffold(body: Text('Contacts')),
      },
    );
  }

  group('SettingsScreen', () {
    testWidgets('renders theme section', (tester) async {
      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      expect(find.text('উপস্থিতি'), findsOneWidget);
      expect(find.text('লাইট'), findsOneWidget);
      expect(find.text('ডার্ক'), findsOneWidget);
      expect(find.text('সিস্টেম'), findsOneWidget);
    });

    testWidgets('renders voice section', (tester) async {
      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      expect(find.text('ভয়েস'), findsOneWidget);
      expect(find.text('স্বয়ংক্রিয় পঠন'), findsOneWidget);
      expect(find.text('ভয়েস ইনপুট'), findsOneWidget);
    });

    testWidgets('renders emergency section', (tester) async {
      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      // The whole section sits below the fold in the lazy ListView —
      // scroll each target into view before asserting.
      await tester.scrollUntilVisible(
        find.text('জরুরি'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('জরুরি'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('জরুরি পরিচিতি'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('জরুরি পরিচিতি'), findsOneWidget);
    });

    testWidgets('toggling auto-read persists to prefs', (tester) async {
      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      final switchFinder = find.widgetWithText(SwitchListTile, 'স্বয়ংক্রিয় পঠন');
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      final initialSwitch = tester.widget<SwitchListTile>(switchFinder);
      expect(initialSwitch.value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_auto_read'), false);
    });

    testWidgets('shows clear cache option', (tester) async {
      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      // Scroll down to find the clear cache option
      await tester.scrollUntilVisible(
        find.text('ক্যাশ মুছুন'),
        200,
      );
      await tester.pumpAndSettle();

      expect(find.text('ক্যাশ মুছুন'), findsOneWidget);
    });

    testWidgets('clear cache shows confirmation dialog', (tester) async {
      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('ক্যাশ মুছুন'),
        200,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ক্যাশ মুছুন'));
      await tester.pumpAndSettle();

      expect(find.text('ক্যাশ মুছুন?'), findsOneWidget);
      expect(find.text('বাতিল'), findsOneWidget);
      expect(find.text('মুছুন'), findsOneWidget);
    });

    testWidgets('clear cache shows confirmation dialog and cancel', (tester) async {
      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('ক্যাশ মুছুন'),
        200,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ক্যাশ মুছুন'));
      await tester.pumpAndSettle();

      expect(find.text('ক্যাশ মুছুন?'), findsOneWidget);
      // Cancel the dialog
      await tester.tap(find.text('বাতিল'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('ক্যাশ মুছুন?'), findsNothing);
    });

    testWidgets('AI model section shows model name and download CTA',
        (tester) async {
      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      // Scroll to the model name — it's below the "AI মডেল" section header
      await tester.scrollUntilVisible(find.text('Gemma 4 E2B'), 200);
      await tester.pumpAndSettle();

      expect(find.text('Gemma 4 E2B'), findsOneWidget);
      expect(find.text('ডাউনলোড'), findsWidgets);
    });
  });
}
