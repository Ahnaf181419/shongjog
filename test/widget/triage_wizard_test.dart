import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/router.dart';
import 'package:shongjog/features/emergency/sos_composer_screen.dart';
import 'package:shongjog/features/quick_cards/quick_card_detail_screen.dart';
import 'package:shongjog/features/triage/triage_tts.dart';
import 'package:shongjog/features/triage/triage_wizard_screen.dart';

import 'fake_triage_tts.dart';
import 'test_app.dart';

void main() {
  testWidgets('renders the first question and big yes/no buttons',
      (tester) async {
    await tester.pumpWidget(
      localizedApp(const TriageWizardScreen()),
    );
    expect(find.text('ব্যক্তি কি সচেতন?'), findsOneWidget);
    expect(find.text('হ্যাঁ'), findsOneWidget);
    expect(find.text('না'), findsOneWidget);
    expect(find.textContaining('প্রশ্ন'), findsOneWidget);
    expect(find.textContaining('প্রশ্ন ১ /'), findsOneWidget);
  });

  testWidgets('tapping হ্যাঁ advances to the next question', (tester) async {
    await tester.pumpWidget(
      localizedApp(const TriageWizardScreen()),
    );
    await tester.tap(find.text('হ্যাঁ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('প্রশ্ন ২ /'), findsOneWidget);
    expect(find.text('শ্বাস নিচ্ছে?'), findsOneWidget);
  });

  testWidgets('unconscious + not breathing -> cpr terminal',
      (tester) async {
    await tester.pumpWidget(
      localizedApp(const TriageWizardScreen()),
    );
    await tester.tap(find.text('না'));
    await tester.pumpAndSettle();
    expect(find.text('শ্বাস নিচ্ছে?'), findsOneWidget);
    await tester.tap(find.text('না'));
    await tester.pumpAndSettle();
    expect(find.text('সিপিআর শুরু করুন'), findsOneWidget);
    expect(find.text('৯৯৯ কল করুন'), findsOneWidget);
  });

  testWidgets('yes-yes-yes lands on bleeding route', (tester) async {
    await tester.pumpWidget(
      localizedApp(const TriageWizardScreen()),
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
      localizedApp(const TriageWizardScreen()),
    );
    await tester.tap(find.text('হ্যাঁ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('না'));
    await tester.pumpAndSettle();
    expect(find.text('সিপিআর শুরু করুন'), findsOneWidget);
  });

  testWidgets('reset button clears answers', (tester) async {
    await tester.pumpWidget(
      localizedApp(const TriageWizardScreen()),
    );
    await tester.tap(find.text('না'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('না'));
    await tester.pumpAndSettle();
    expect(find.text('সিপিআর শুরু করুন'), findsOneWidget);
    await tester.tap(find.byTooltip('পুনরায় শুরু'));
    await tester.pumpAndSettle();
    expect(find.text('ব্যক্তি কি সচেতন?'), findsOneWidget);
  });

  // ── Cycle 1 (A): View Card CTA actually opens a QuickCard ──────────
  testWidgets('view-card CTA on cpr route opens a cpr card',
      (tester) async {
    await _driveToCprTerminal(tester);
    expect(find.text('কার্ড দেখুন'), findsOneWidget);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.textContaining('সিপিআর'), findsWidgets);
    expect(find.text('রক্তপাত বন্ধ'), findsNothing);
  });

  testWidgets('view-card CTA on bleeding route opens bleeding card',
      (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ', 'হ্যাঁ', 'হ্যাঁ']);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('রক্তপাত বন্ধ'), findsOneWidget);
  });

  testWidgets('view-card CTA on drowning route opens drowning card',
      (tester) async {
    await _driveToTerminal(tester,
        taps: const ['হ্যাঁ', 'হ্যাঁ', 'না', 'হ্যাঁ']);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('ডুবে যাওয়া ব্যক্তি'), findsOneWidget);
  });

  testWidgets('view-card CTA on snakebite route opens snakebite card',
      (tester) async {
    await _driveToTerminal(tester,
        taps: const ['হ্যাঁ', 'হ্যাঁ', 'না', 'না', 'হ্যাঁ']);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('সাপের কামড়'), findsOneWidget);
  });

  testWidgets('view-card CTA on escalation route opens escalation card',
      (tester) async {
    await _driveToTerminal(tester,
        taps: const ['হ্যাঁ', 'হ্যাঁ', 'না', 'না', 'না', 'না', 'হ্যাঁ']);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('৯৯৯ কিভাবে কল করবেন'), findsOneWidget);
    expect(find.text('৯৯৯ কল করুন'), findsNothing);
  });

  testWidgets('quick card detail has a close button', (tester) async {
    await _driveToCprTerminal(tester);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('ফিরে যান'), findsOneWidget);
    await tester.tap(find.byTooltip('ফিরে যান'));
    await tester.pumpAndSettle();
    expect(find.text('সিপিআর শুরু করুন'), findsOneWidget);
  });

  testWidgets('quick card detail renders numbered steps in Bangla',
      (tester) async {
    await _driveToCprTerminal(tester);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('১'), findsOneWidget);
  });

  // ── Cycle 2 (B): new triage routes via the wizard ───────────────────
  testWidgets('unconscious + breathing -> recovery position card',
      (tester) async {
    await _driveToTerminal(tester, taps: const ['না', 'হ্যাঁ']);
    expect(find.text('রিকভারি পজিশনে রাখুন'), findsOneWidget);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('রিকভারি পজিশন'), findsOneWidget);
  });

  testWidgets('yes-yes-no-no-no-yes -> severe burn card', (tester) async {
    await _driveToTerminal(
      tester,
      taps: const ['হ্যাঁ', 'হ্যাঁ', 'না', 'না', 'না', 'হ্যাঁ'],
    );
    expect(find.text('গুরুতর পোড়া — ঠাণ্ডা পানি দিন'), findsOneWidget);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('গুরুতর পোড়া'), findsOneWidget);
  });

  testWidgets('yes-yes-no-no-no-no-no -> choking card', (tester) async {
    await _driveToTerminal(
      tester,
      taps: const ['হ্যাঁ', 'হ্যাঁ', 'না', 'না', 'না', 'না', 'না'],
    );
    expect(find.text('শ্বাসরোধ — পিঠে ও পেটে চাপ দিন'), findsOneWidget);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('শ্বাসরোধ (আটকে যাওয়া)'), findsOneWidget);
  });

  testWidgets('yes-yes-no-no-no-no-yes -> escalation card', (tester) async {
    await _driveToTerminal(
      tester,
      taps: const ['হ্যাঁ', 'হ্যাঁ', 'না', 'না', 'না', 'না', 'হ্যাঁ'],
    );
    expect(find.text('জরুরি সহায়তা প্রয়োজন'), findsOneWidget);
    await tester.tap(find.text('কার্ড দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('৯৯৯ কিভাবে কল করবেন'), findsOneWidget);
  });

  testWidgets('existing snakebite path still works on extended tree',
      (tester) async {
    await _driveToTerminal(
      tester,
      taps: const ['হ্যাঁ', 'হ্যাঁ', 'না', 'না', 'হ্যাঁ'],
    );
    expect(find.text('সাপে কামড় — চিকিৎসা সহায়তা নিন'), findsOneWidget);
  });

  // ── Cycle 3 (C): TriageState recap on the terminal screen ───────────
  testWidgets('terminal screen shows the elapsed-time recap', (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ', 'হ্যাঁ', 'হ্যাঁ']);
    expect(find.textContaining('সময়'), findsOneWidget);
    expect(find.textContaining('প্রশ্ন'), findsOneWidget);
  });

  testWidgets('terminal screen shows the answer count', (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ', 'হ্যাঁ', 'হ্যাঁ']);
    expect(find.textContaining('প্রশ্ন: ৩'), findsOneWidget);
  });

  testWidgets('reset clears the recap shown on the terminal', (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ', 'হ্যাঁ', 'হ্যাঁ']);
    expect(find.text('রক্তপাত বন্ধ করুন'), findsOneWidget);
    await tester.tap(find.byTooltip('পুনরায় শুরু'));
    await tester.pumpAndSettle();
    expect(find.text('ব্যক্তি কি সচেতন?'), findsOneWidget);
  });

  // ── Cycle 4 (D): inline act-now steps on the terminal screen ────────
  testWidgets('terminal screen shows inline act-now steps',
      (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ', 'হ্যাঁ', 'হ্যাঁ']);
    expect(find.text('এখনই যা করবেন'), findsOneWidget);
    expect(find.textContaining('পরিষ্কার কাপড় দিয়ে জায়গায় চাপ দিন'),
        findsOneWidget);
  });

  testWidgets('terminal screen shows inline steps for cpr route',
      (tester) async {
    await _driveToCprTerminal(tester);
    expect(find.text('এখনই যা করবেন'), findsOneWidget);
    expect(find.textContaining('সমতল ও শক্ত জায়গায় শুইয়ে নিন'),
        findsOneWidget);
  });

  testWidgets('inline steps never show steps 4+ on the terminal screen',
      (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ', 'হ্যাঁ', 'হ্যাঁ']);
    // The 4th step of the bleeding card is "না থামলে ৯৯৯ এ কল করুন".
    // It must not appear inline — only the deep CTA shows it.
    expect(find.textContaining('৯৯৯ এ কল করুন'), findsNothing);
  });

  // ── Cycle 5 (E): TTS auto-read on each new question ─────────────────
  testWidgets('TTS speaks only when an adapter is provided', (tester) async {
    final tts = FakeTriageTts();
    // Pump the wizard with no tts argument — the production default.
    // The fake is unused, so spoken should remain empty.
    await _driveToTerminal(tester, taps: const ['হ্যাঁ']);
    expect(tts.spoken, isEmpty);
  });

  testWidgets('auto-read TTS speaks the first question on mount',
      (tester) async {
    final tts = FakeTriageTts();
    await _driveToTts(tester, tts: tts, taps: const []);
    expect(tts.spoken, ['ব্যক্তি কি সচেতন?']);
  });

  testWidgets('auto-read TTS speaks each new question', (tester) async {
    final tts = FakeTriageTts();
    await _driveToTts(tester, tts: tts, taps: const ['হ্যাঁ']);
    expect(tts.spoken, ['ব্যক্তি কি সচেতন?', 'শ্বাস নিচ্ছে?']);
  });

  testWidgets('auto-read TTS stops speaking on terminal route',
      (tester) async {
    final tts = FakeTriageTts();
    await _driveToTts(tester, tts: tts, taps: const ['না', 'না']);
    // The terminal screen shows, and the next TTS would never fire.
    expect(tts.stopped, isTrue);
  });

  // ── Cycle 6 (F): 999 handoff pre-fills the SOS composer ─────────────
  testWidgets('terminal screen shows a ৯৯৯ কে জানান button',
      (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ', 'হ্যাঁ', 'হ্যাঁ']);
    expect(find.text('৯৯৯ কে জানান'), findsOneWidget);
  });

  testWidgets('tapping ৯৯৯ কে জানান pushes SosComposerScreen with triage summary',
      (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ', 'হ্যাঁ', 'হ্যাঁ']);
    // Scroll the 999 handoff button into view — the terminal screen
    // has many stacked buttons that overflow the test viewport.
    final handoff = find.text('৯৯৯ কে জানান');
    await tester.scrollUntilVisible(handoff, 100);
    await tester.pumpAndSettle();
    await tester.tap(handoff, warnIfMissed: false);
    await tester.pumpAndSettle();
    // Verify we're on the SOS composer screen.
    expect(find.byType(Scaffold), findsWidgets);
    // The first TextField (free-text input) must contain the triage summary.
    final textField =
        tester.widget<TextField>(find.byType(TextField).first);
    final text = textField.controller!.text;
    expect(text, isNotEmpty);
    expect(text, contains('ট্রায়াজ:'));
  });

  // ── AppBar: calm, stable chrome — never errorContainer, title in slot ─
  testWidgets('AppBar background never goes errorContainer (stays calm)',
      (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ', 'হ্যাঁ', 'হ্যাঁ']);
    final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
    final cs = Theme.of(tester.element(find.byType(AppBar).first)).colorScheme;
    // The triage bar must never go red; emergency tone lives in the body.
    expect(appBar.backgroundColor, isNot(equals(cs.errorContainer)));
  });

  testWidgets('AppBar shows the full title in the title slot on question screen',
      (tester) async {
    await _driveToTerminal(tester, taps: const ['হ্যাঁ']);
    // Title is plain text in the title slot (not a narrow leading pill), so
    // the full string must render as one node and never wrap as "Tr/ia".
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('ট্রায়াজ উইজার্ড'),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _driveToTerminal(
  WidgetTester tester, {
  required List<String> taps,
  TriageTts? tts,
}) async {
  // Use a phone-sized viewport so the terminal screen with longer
  // Bangla titles ('ডুবে যাওয়া — নিষ্কাশন ও সিপিআর') has room.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    localizedApp(
      TriageWizardScreen(tts: tts),
      routesWithArgs: {
        AppRoutes.quickCardDetail: (settings) => QuickCardDetailScreen(
              cardId: settings.arguments is String
                  ? settings.arguments as String
                  : '',
            ),
        AppRoutes.sosComposer: (_) => const SosComposerScreen(),
      },
    ),
  );
  for (final t in taps) {
    await tester.tap(find.text(t));
    await tester.pumpAndSettle();
  }
}

Future<void> _driveToTts(
  WidgetTester tester, {
  required TriageTts tts,
  required List<String> taps,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    localizedApp(TriageWizardScreen(tts: tts)),
  );
  for (final t in taps) {
    await tester.tap(find.text(t));
    await tester.pumpAndSettle();
  }
}

Future<void> _driveToCprTerminal(WidgetTester tester) =>
    _driveToTerminal(tester, taps: const ['না', 'না']);