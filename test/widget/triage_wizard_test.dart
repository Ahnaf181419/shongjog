import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/triage/triage_wizard_screen.dart';

void main() {
  testWidgets('renders the first question and big yes/no buttons',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TriageWizardScreen()),
    );
    expect(find.text('ব্যক্তি কি সচেতন?'), findsOneWidget);
    expect(find.text('হ্যাঁ'), findsOneWidget);
    expect(find.text('না'), findsOneWidget);
    expect(find.textContaining('প্রশ্ন'), findsOneWidget);
    expect(find.textContaining('প্রশ্ন ১ /'), findsOneWidget);
  });

  testWidgets('tapping হ্যাঁ advances to the next question', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TriageWizardScreen()),
    );
    await tester.tap(find.text('হ্যাঁ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('প্রশ্ন ২ /'), findsOneWidget);
    expect(find.text('শ্বাস নিচ্ছে?'), findsOneWidget);
  });

  testWidgets('first-question না lands directly on cpr terminal',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TriageWizardScreen()),
    );
    await tester.tap(find.text('না'));
    await tester.pumpAndSettle();
    expect(find.text('সিপিআর শুরু করুন'), findsOneWidget);
    expect(find.text('৯৯৯ কল করুন'), findsOneWidget);
  });

  testWidgets('yes-yes-yes lands on bleeding route', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TriageWizardScreen()),
    );
    await tester.tap(find.text('হ্যাঁ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('হ্যাঁ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('হ্যাঁ'));
    await tester.pumpAndSettle();
    expect(find.text('রক্তপাত বন্ধ করুন'), findsOneWidget);
  });

  testWidgets('yes-no-yes lands on bleeding route (no breathing)', (tester) async {
    // breathing=no -> cpr (terminal).
    await tester.pumpWidget(
      const MaterialApp(home: TriageWizardScreen()),
    );
    await tester.tap(find.text('হ্যাঁ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('না'));
    await tester.pumpAndSettle();
    expect(find.text('সিপিআর শুরু করুন'), findsOneWidget);
  });

  testWidgets('reset button clears answers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TriageWizardScreen()),
    );
    await tester.tap(find.text('না'));
    await tester.pumpAndSettle();
    expect(find.text('সিপিআর শুরু করুন'), findsOneWidget);
    await tester.tap(find.byTooltip('পুনরায় শুরু'));
    await tester.pumpAndSettle();
    expect(find.text('ব্যক্তি কি সচেতন?'), findsOneWidget);
  });
}