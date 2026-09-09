import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/main_shell.dart';
import 'package:shongjog/features/chat/chat_screen.dart';
import 'package:shongjog/features/quick_cards/quick_cards_screen.dart';
import 'package:shongjog/features/shelter/shelter_map_screen.dart';
import 'package:shongjog/features/tools/tools_screen.dart';
import 'package:shongjog/features/weather/weather_card.dart';
import 'package:shongjog/l10n/app_localizations.dart';

/// Widget tests for the floating-nav pill tap pipeline.
///
/// Audit F13 (2026-09-09): the pill tap callback had been moved onto
/// [Semantics.onTap] in audit F6, which is screen-reader-only — sighted
/// users tapping the pill got no response. These tests assert that
/// real touch now switches tabs and that the F6 accessibility labelling
/// is preserved.
///
/// Mounts `MainShell` directly in a localized `MaterialApp`. The mesh
/// service + call service use lazy `StreamController.broadcast()` so
/// their `initState` subscriptions never error in unit tests.
void main() {
  Widget wrapShell() {
    return MaterialApp(
      locale: const Locale('bn'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MainShell(),
    );
  }

  group('Floating nav bar', () {
    // HomeScreen's WeatherCard schedules a 7s GPS retry Timer. Without
    // this stub, the test framework fails the run with "A Timer is
    // still pending even after the widget tree was disposed" — same
    // pattern as `home_screen_test.dart`.
    setUp(() => WeatherCard.debugSkipGps = true);
    tearDown(() => WeatherCard.debugSkipGps = false);

    testWidgets(
      'tapping the AI pill switches to the chat tab (F13 regression)',
      (tester) async {
        await tester.pumpWidget(wrapShell());
        // Pump past the first frame without settling — the status dot
        // and breathing pulse on the home screen run forever by design,
        // matching the convention in `home_screen_test.dart`.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        // Home is the initial tab; ChatScreen should NOT be on screen.
        expect(find.byType(ChatScreen), findsNothing);

        // Tap the AI pill by its localized label (visible on the
        // currently-selected pill, and announced via Semantics on the
        // other four). Use the Semantics label finder so the test works
        // regardless of which pill is visually selected.
        await tester.tap(find.bySemanticsLabel('এআই'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        // ChatScreen is now mounted and visible (its empty-state text
        // proves the tree is built and the Offstage has flipped).
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(find.text('আপনার জরুরি প্রশ্ন বলুন বা লিখুন'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the Shelter pill switches to the shelter map tab',
      (tester) async {
        await tester.pumpWidget(wrapShell());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(ShelterMapScreen), findsNothing);

        await tester.tap(find.bySemanticsLabel('আশ্রয়'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(ShelterMapScreen), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the Tools and Cards pills switches to those tabs',
      (tester) async {
        await tester.pumpWidget(wrapShell());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        await tester.tap(find.bySemanticsLabel('টুলস'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(ToolsScreen), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('কার্ড'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(QuickCardsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'every pill exposes a localized Semantics label (F6 follow-up)',
      (tester) async {
        await tester.pumpWidget(wrapShell());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        // All five localized nav labels must be announced as
        // Semantics nodes — TalkBack otherwise reads "button" with no
        // name on the four unselected pills. This is the test the F6
        // commit message deferred ("left as a follow-up").
        for (final label in const ['হোম', 'এআই', 'টুলস', 'কার্ড', 'আশ্রয়']) {
          expect(
            find.bySemanticsLabel(label),
            findsOneWidget,
            reason: 'pill "$label" must be reachable via Semantics label',
          );
        }
      },
    );
  });
}
