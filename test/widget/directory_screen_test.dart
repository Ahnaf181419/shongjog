import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/emergency/directory_loader.dart';
import 'package:shongjog/features/emergency/directory_screen.dart';

import 'test_app.dart';

void main() {
  setUp(() {
    DirectoryLoader.debugClearCache();
    DirectoryLoader.debugSetEntries(const [
      EmergencyEntry(
        nameBn: 'জাতীয় জরুরি',
        name: 'National Emergency',
        phone: '999',
        division: 'all',
        type: 'police',
      ),
      EmergencyEntry(
        nameBn: 'ঢাকা হাসপাতাল',
        name: 'Dhaka Hospital',
        phone: '0255165080',
        division: 'dhaka',
        type: 'hospital',
      ),
      EmergencyEntry(
        nameBn: 'চট্টগ্রাম হাসপাতাল',
        name: 'Chattogram Hospital',
        phone: '0312503530',
        division: 'chattogram',
        type: 'hospital',
      ),
    ]);
  });

  tearDown(() {
    DirectoryLoader.debugClearCache();
  });

  testWidgets('renders entries with phone numbers and call buttons',
      (tester) async {
    await tester.pumpWidget(
      localizedApp(const DirectoryScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('জাতীয় জরুরি'), findsOneWidget);
    expect(find.text('৯৯৯'), findsOneWidget);
    expect(find.text('ঢাকা হাসপাতাল'), findsOneWidget);
    expect(find.text('চট্টগ্রাম হাসপাতাল'), findsOneWidget);
  });

  testWidgets('division filter narrows results', (tester) async {
    await tester.pumpWidget(
      localizedApp(const DirectoryScreen(initialDivision: 'dhaka')),
    );
    await tester.pumpAndSettle();
    // National (all-division) is still shown, plus Dhaka, but NOT Chattogram.
    expect(find.text('জাতীয় জরুরি'), findsOneWidget);
    expect(find.text('ঢাকা হাসপাতাল'), findsOneWidget);
    expect(find.text('চট্টগ্রাম হাসপাতাল'), findsNothing);
  });
}