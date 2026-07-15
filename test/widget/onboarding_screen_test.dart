import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/features/onboarding/onboarding_screen.dart';
import 'package:shongjog/features/settings/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapOnboarding({
    VoidCallback? onComplete,
    Map<String, WidgetBuilder>? routes,
  }) {
    return MaterialApp(
      home: OnboardingScreen(onComplete: onComplete ?? () {}),
      routes: routes ?? const {},
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('OnboardingScreen', () {
    testWidgets('renders welcome page on first show', (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await settle(tester);
      expect(find.text('সংযোগে স্বাগতম'), findsOneWidget);
    });

    testWidgets('shows skip button on first page', (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await settle(tester);
      expect(find.text('স্কিপ'), findsOneWidget);
    });

    testWidgets('shows forward arrow and three page dots on first page',
        (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await settle(tester);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('navigates to permissions page on next', (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await settle(tester);

      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);

      expect(find.text('অনুমতি প্রয়োজন'), findsOneWidget);
      expect(find.text('মাইক্রোফোন'), findsOneWidget);
      expect(find.text('অবস্থান (GPS)'), findsOneWidget);
    });

    testWidgets('navigates back from permissions page via back arrow',
        (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await settle(tester);

      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);
      expect(find.text('অনুমতি প্রয়োজন'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);

      expect(find.text('সংযোগে স্বাগতম'), findsOneWidget);
    });

    testWidgets('navigates to model page on second next', (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await settle(tester);

      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);

      expect(find.text('AI মডেল ডাউনলোড'), findsOneWidget);
    });

    testWidgets('last page shows settings and home buttons, no forward arrow',
        (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await settle(tester);

      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);

      expect(find.text('সেটিংস'), findsOneWidget);
      expect(find.text('হোমে যান'), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });

    testWidgets('home button completes onboarding', (tester) async {
      var completed = false;
      await tester.pumpWidget(wrapOnboarding(onComplete: () => completed = true));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);
      await tester.tap(find.text('হোমে যান'));
      await settle(tester);

      expect(completed, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_has_onboarded'), isTrue);
    });

    testWidgets('settings button completes onboarding and pushes /settings',
        (tester) async {
      await tester.pumpWidget(wrapOnboarding(
        routes: {'/settings': (_) => const SettingsScreen()},
      ));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await settle(tester);

      await tester.tap(find.text('সেটিংস'));
      await settle(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_has_onboarded'), isTrue);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('skip button completes onboarding', (tester) async {
      var completed = false;
      await tester.pumpWidget(wrapOnboarding(onComplete: () => completed = true));
      await settle(tester);

      await tester.tap(find.text('স্কিপ'));
      await settle(tester);

      expect(completed, isTrue);
    });
  });
}
