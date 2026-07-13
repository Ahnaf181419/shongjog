// Smoke test for the skeleton shell. Verifies that:
//  - the chat screen renders on initialRoute
//  - the AppBar shows the Bangla title
//  - the placeholder body text renders
// Real widget tests for each feature land with that feature (Phase 1.3+).

import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/app/app.dart';

void main() {
  testWidgets('skeleton shell renders chat screen with Bangla AppBar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ShongjogApp());
    await tester.pumpAndSettle();

    expect(find.text('সংযোগ — জরুরি সহায়তা'), findsOneWidget);
    expect(find.text('চ্যাট — শীঘ্রই আসছে'), findsOneWidget);
  });
}