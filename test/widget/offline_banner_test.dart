import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/features/shelter/widgets/offline_banner.dart';

void main() {
  group('OfflineBanner', () {
    testWidgets('renders the offline notice in Bangla', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(children: const [OfflineBanner()]),
        ),
      ));

      expect(
        find.textContaining(
            'অফলাইন — মানচিত্রের টাইলস লোড হবে না'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });
}
