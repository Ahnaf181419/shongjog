import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/app/app.dart';

void main() {
  testWidgets('hub is the home screen with navigation tiles',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ShongjogApp());
    await tester.pumpAndSettle();

    // Hub AppBar title.
    expect(find.text('সংযোগ'), findsOneWidget);
    // At least the primary tiles are present.
    expect(find.text('AI সহায়ক'), findsOneWidget);
    expect(find.text('জরুরি কার্ড'), findsOneWidget);
    expect(find.text('জরুরি কল (৯৯৯)'), findsOneWidget);
  });
}