import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/planner/planner_screen.dart';

import 'test_app.dart';

void main() {
  group('PlannerScreen family-member stepper', () {
    // Regression test for the reported bug: tapping the +/- buttons
    // mutated the underlying TextEditingController but nothing rebuilt
    // the displayed digit, so it visually looked frozen at 0 forever
    // even though the value was tracked correctly underneath.
    testWidgets('tapping + on the first counter updates the displayed digit',
        (tester) async {
      await tester.pumpWidget(localizedApp(const PlannerScreen()));
      await tester.pumpAndSettle();

      // Three counters (মোট সদস্য, শিশু, প্রবীণ) all start at "0".
      expect(find.text('0'), findsNWidgets(3));
      expect(find.text('1'), findsNothing);

      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).first);
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('tapping + repeatedly increments the displayed digit each time',
        (tester) async {
      await tester.pumpWidget(localizedApp(const PlannerScreen()));
      await tester.pumpAndSettle();

      final plusButton = find.byIcon(Icons.add_circle_outline_rounded).first;
      await tester.tap(plusButton);
      await tester.pump();
      await tester.tap(plusButton);
      await tester.pump();
      await tester.tap(plusButton);
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('tapping - decrements the displayed digit and floors at 0',
        (tester) async {
      await tester.pumpWidget(localizedApp(const PlannerScreen()));
      await tester.pumpAndSettle();

      final plusButton = find.byIcon(Icons.add_circle_outline_rounded).first;
      final minusButton = find.byIcon(Icons.remove_circle_outline_rounded).first;
      await tester.tap(plusButton);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      await tester.tap(minusButton);
      await tester.pump();
      expect(find.text('1'), findsNothing);
      // Back to 3 counters reading "0".
      expect(find.text('0'), findsNWidgets(3));

      // Floors at 0 — does not go negative.
      await tester.tap(minusButton);
      await tester.pump();
      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets(
        "the floor-number stepper keeps its value across unrelated "
        "form changes (e.g. toggling a switch elsewhere)", (tester) async {
      await tester.pumpWidget(localizedApp(const PlannerScreen()));
      await tester.pumpAndSettle();

      // Select apartment home type to reveal the floor-number stepper.
      await tester.tap(find.text('ফ্ল্যাট'));
      await tester.pumpAndSettle();

      // The floor stepper starts at "0" (not blank) — regression check
      // for the inline-constructed-controller bug found alongside the
      // family-counter one.
      expect(find.text('0'), findsNWidgets(4)); // 3 family + 1 floor

      final addButtons = find.byIcon(Icons.add_circle_outline_rounded);
      // Floor stepper is the 4th _StepperRow — its + button is last.
      await tester.tap(addButtons.last);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      // Toggling an unrelated switch triggers a parent setState() and a
      // full _buildForm() re-run. Before the fix, this recreated the
      // floor controller inline and silently reset it.
      final petsSwitch = find.text('পোষা প্রাণী আছে');
      await tester.ensureVisible(petsSwitch);
      await tester.pumpAndSettle();
      await tester.tap(petsSwitch);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
    });
  });
}
