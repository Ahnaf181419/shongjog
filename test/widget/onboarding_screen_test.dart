import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/features/onboarding/onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapOnboarding({VoidCallback? onComplete}) {
    return MaterialApp(
      home: OnboardingScreen(onComplete: onComplete ?? () {}),
    );
  }

  group('OnboardingScreen', () {
    testWidgets('renders welcome page on first show', (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();
      expect(find.text('সংযোগে স্বাগতম'), findsOneWidget);
    });

    testWidgets('shows skip button on first page', (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();
      expect(find.text('স্কিপ'), findsOneWidget);
    });

    testWidgets('navigates to permissions page on next', (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();

      await tester.tap(find.text('পরবর্তী'));
      await tester.pumpAndSettle();

      expect(find.text('অনুমতি প্রয়োজন'), findsOneWidget);
      expect(find.text('মাইক্রোফোন'), findsOneWidget);
      expect(find.text('অবস্থান (GPS)'), findsOneWidget);
    });

    testWidgets('navigates to model page on second next', (tester) async {
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();

      await tester.tap(find.text('পরবর্তী'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('পরবর্তী'));
      await tester.pumpAndSettle();

      expect(find.text('AI মডেল ডাউনলোড'), findsOneWidget);
    });

    testWidgets('calls onComplete when finished', (tester) async {
      var completed = false;
      await tester.pumpWidget(wrapOnboarding(onComplete: () => completed = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('পরবর্তী'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('পরবর্তী'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('শুরু করুন'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_has_onboarded'), isTrue);
    });

    testWidgets('skip button completes onboarding', (tester) async {
      var completed = false;
      await tester.pumpWidget(wrapOnboarding(onComplete: () => completed = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('স্কিপ'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });
  });
}
