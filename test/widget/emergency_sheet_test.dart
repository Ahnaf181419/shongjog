import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/emergency/emergency_sheet.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {
  Widget wrapEmergency() {
    return MaterialApp(
      locale: const Locale('bn'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const EmergencySheet(),
    );
  }

  group('EmergencySheet', () {
    testWidgets('renders 999 number', (tester) async {
      await tester.pumpWidget(wrapEmergency());
      await tester.pumpAndSettle();
      expect(find.text('৯৯৯'), findsOneWidget);
    });

    testWidgets('renders SOS link', (tester) async {
      await tester.pumpWidget(wrapEmergency());
      await tester.pumpAndSettle();
      expect(find.text('পরিবর্তে SOS পাঠান'), findsOneWidget);
    });

    testWidgets('has exactly one draggable knob (no duplicate)', (tester) async {
      await tester.pumpWidget(wrapEmergency());
      await tester.pumpAndSettle();

      // The slide-to-confirm should have exactly one GestureDetector on
      // the knob (not two overlapping ones).
      final gestureDetectors = find
          .bySubtype<GestureDetector>()
          .evaluate()
          .where((e) {
            final gd = e.widget as GestureDetector;
            return gd.onHorizontalDragUpdate != null;
          })
          .length;

      expect(gestureDetectors, 1,
          reason: 'Slide knob should have exactly one drag handler');
    });

    testWidgets('shows slide instruction text', (tester) async {
      await tester.pumpWidget(wrapEmergency());
      await tester.pumpAndSettle();
      // Should show the slide instruction
      expect(
        find.textContaining('স্লাইড'),
        findsWidgets,
      );
    });
  });
}
