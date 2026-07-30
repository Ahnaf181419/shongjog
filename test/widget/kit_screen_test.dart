import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/features/planner/kit_screen.dart';

import 'test_app.dart';

void main() {
  group('KitScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows inline form when no family profile exists',
        (tester) async {
      await tester.pumpWidget(localizedApp(const KitScreen()));
      await tester.pumpAndSettle();

      // Three steppers (members, children, elderly) all start at "0".
      expect(find.text('0'), findsNWidgets(3));
      // Generate button visible.
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      // No close (X) button — nothing to cancel to without a profile.
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('steppers increment in the inline form', (tester) async {
      await tester.pumpWidget(localizedApp(const KitScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).first);
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('shows summary chips when a family profile exists',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'family_size': 4,
        'family_children': 1,
        'family_elderly': 1,
        'family_home_type': 'pucka',
      });

      await tester.pumpWidget(localizedApp(const KitScreen()));
      await tester.pumpAndSettle();

      // Summary chips (Bangla locale, Latin digits from ICU format).
      expect(find.text('4 জন'), findsOneWidget);
      expect(find.text('1 শিশু'), findsOneWidget);
      expect(find.text('1 প্রবীণ'), findsOneWidget);

      // Edit + Generate buttons present.
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('tapping Edit reveals the form with pre-populated values',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'family_size': 3,
        'family_home_type': 'pucka',
      });

      await tester.pumpWidget(localizedApp(const KitScreen()));
      await tester.pumpAndSettle();

      // Summary view initially.
      expect(find.text('3 জন'), findsOneWidget);

      // Tap Edit.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Now in form view — close (X) button appears.
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // Pre-populated: 3 for members, 0 for children and elderly.
      expect(find.text('3'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('tapping close (X) returns to summary', (tester) async {
      SharedPreferences.setMockInitialValues({
        'family_size': 2,
        'family_home_type': 'pucka',
      });

      await tester.pumpWidget(localizedApp(const KitScreen()));
      await tester.pumpAndSettle();

      // Enter edit mode.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Change a value — this should be discarded on cancel.
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).first);
      await tester.pump();

      // Tap close to cancel.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Back to summary — original value restored (2, not 3).
      expect(find.text('2 জন'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });
}
