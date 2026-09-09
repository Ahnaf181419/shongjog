import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/emergency/sos_composer_screen.dart';

import 'test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Audit F2 (2026-09-08): the composer's big red "৯৯৯ কল" button was
  // `Navigator.pop(_smsPreview)` — nothing was sent anywhere, and the only
  // caller (triage) dropped the popped value. These tests pin the contract:
  // tapping send MUST attempt an SMS to 999 via the SmsChannel method
  // channel, and MUST tell the user when it fails.
  testWidgets(
      'send button sends the composed report as SMS to 999 (audit F2)',
      (tester) async {
    final sent = <Map<String, dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.example.shongjog/sms'),
      (call) async {
        if (call.method == 'sendSms') {
          sent.add(Map<String, dynamic>.from(call.arguments as Map));
          return true;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.example.shongjog/sms'),
        null,
      );
    });

    await tester.pumpWidget(localizedApp(const SosComposerScreen()));
    await tester.enterText(find.byType(TextField).first, 'দুর্ঘটনা: ঢাকায় সড়ক দুর্ঘটনা');
    await tester.pump();
    // The SMS body carries the STRUCTURED fields (location, hazard, ...),
    // not the free-text description — fill the location field so the
    // delivered report is assertable.
    await tester.enterText(
      find.byType(TextField).at(1), // location field
      'ঢাকা, বাংলাদেশ',
    );
    await tester.pump();

    final sendButton = find.text('৯৯৯ কল করুন');
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.first['to'], '999');
    expect(sent.first['body'] as String, isNotEmpty);
    // Confirm the attempt carries the structured location forward.
    expect(sent.first['body'] as String, contains('ঢাকা'));
  });

  testWidgets(
      'send button surfaces a failure message when the SMS channel fails',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.example.shongjog/sms'),
      (call) async => false, // platform reports failure
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.example.shongjog/sms'),
        null,
      );
    });

    await tester.pumpWidget(localizedApp(const SosComposerScreen()));
    await tester.enterText(find.byType(TextField).first, 'অগ্নিকাণ্ড');
    await tester.pump();

    await tester.tap(find.text('৯৯৯ কল করুন'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // The user must be told the report did NOT go out.
    expect(find.text('SOS পাঠানো যায়নি — এখনই ৯৯৯ কল করুন।'), findsOneWidget);
  });
}
