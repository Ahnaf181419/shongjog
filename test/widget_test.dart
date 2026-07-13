// Smoke test for the skeleton shell. Verifies the chat screen renders with
// its Bangla AppBar title and empty-state suggestion pills. The full chat
// flow (model + TTS) is validated on-device in Phase 5, not in widget tests.

import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/app/app.dart';

void main() {
  testWidgets('chat screen renders AppBar title and empty-state suggestions',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ShongjogApp());
    // Let _bootstrap's async KB load run; it will fail in the test env
    // (no rootBundle) but the UI still renders the empty state.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('সংযোগ — জরুরি সহায়তা'), findsOneWidget);
    // Empty-state copy.
    expect(find.text('আপনার জরুরি প্রশ্ন বলুন বা লিখুন'), findsOneWidget);
  });
}