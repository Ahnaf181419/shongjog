import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/features/shelter/widgets/gps_banner.dart';
import 'test_app.dart';

void main() {
  group('GpsBanner', () {
    testWidgets('shows generic message when no error', (tester) async {
      await tester.pumpWidget(localizedApp(
        Scaffold(
          body: Stack(children: const [
            GpsBanner(error: null, stackedBelowOfflinePill: false),
          ]),
        ),
      ));

      expect(
        find.textContaining('সমগ্র বাংলাদেশ দেখানো হচ্ছে'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
    });

    testWidgets('shows supplied error message verbatim', (tester) async {
      await tester.pumpWidget(localizedApp(
        Scaffold(
          body: Stack(children: const [
            GpsBanner(
              error: 'GPS অনুমতি নেই',
              stackedBelowOfflinePill: false,
            ),
          ]),
        ),
      ));

      expect(find.text('GPS অনুমতি নেই'), findsOneWidget);
    });
  });
}
