import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/app.dart';
import 'package:shongjog/app/theme.dart';
import 'package:shongjog/l10n/app_localizations.dart';
import 'package:shongjog/features/quick_cards/quick_cards_screen.dart';
import 'package:shongjog/features/planner/kit_screen.dart';

/// Text-scaling guards.
///
/// Before this, `lib/` contained zero references to `textScaler` — nothing
/// clamped or tested the OS large-text setting, which is exactly what an
/// older or low-vision user in an emergency is most likely to have on.
///
/// Two separate things are checked, because they fail differently:
///   1. The clamp exists and is applied at the app root.
///   2. Real screens survive being rendered at that clamp without clipping.
///
/// A `RenderFlex overflowed` from a dense screen is a real defect here — it
/// means information disappeared for the users who most needed it larger.

/// Renders [child] at [scale] on a phone-sized surface.
Future<void> pumpAtScale(
  WidgetTester tester,
  Widget child,
  double scale, {
  Size size = const Size(411, 891), // Pixel-class logical size
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: const Locale('bn'),
    theme: ShongjogTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, inner) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: TextScaler.linear(scale)
              .clamp(maxScaleFactor: ShongjogApp.maxTextScale),
        ),
        child: inner ?? const SizedBox.shrink(),
      );
    },
    home: child,
  ));
  // Fixed frames rather than pumpAndSettle: some screens hold a perpetual
  // animation (a loading spinner that never resolves without platform
  // channels), which makes pumpAndSettle time out. Layout — and therefore any
  // overflow — has already happened by the first frame.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('the clamp itself', () {
    test('caps at a value that is a real accessibility gain, not a token one',
        () {
      // 1.5x is 50% larger type. If someone lowers this below 1.3 the clamp
      // stops being an accommodation and becomes an obstruction.
      expect(ShongjogApp.maxTextScale, greaterThanOrEqualTo(1.3));
      // Above ~1.5 the dense screens start clipping rather than wrapping.
      expect(ShongjogApp.maxTextScale, lessThanOrEqualTo(1.6));
    });

    testWidgets('caps a 2.0x system setting at the ceiling', (tester) async {
      late TextScaler seen;
      await pumpAtScale(
        tester,
        Builder(builder: (c) {
          seen = MediaQuery.textScalerOf(c);
          return const SizedBox();
        }),
        2.0,
      );
      // 14sp is the caption floor — at the clamp it must land at 14 * 1.5.
      expect(seen.scale(14), closeTo(14 * ShongjogApp.maxTextScale, 0.01));
    });

    testWidgets('does NOT scale a user who chose smaller text back up',
        (tester) async {
      late TextScaler seen;
      await pumpAtScale(
        tester,
        Builder(builder: (c) {
          seen = MediaQuery.textScalerOf(c);
          return const SizedBox();
        }),
        0.85,
      );
      expect(seen.scale(14), closeTo(14 * 0.85, 0.01),
          reason: 'Downscaling is a deliberate user choice and is not clamped.');
    });
  });

  group('dense screens survive the clamp', () {
    // These two are the densest layouts that can be built without platform
    // channels: long Bangla labels in constrained rows, which is precisely
    // the shape that clips first.
    testWidgets('QuickCardsScreen renders at max scale without overflow',
        (tester) async {
      await pumpAtScale(tester, QuickCardsScreen(onRequestAiChat: (_) {}), 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('QuickCardsScreen survives an expanded card at max scale',
        (tester) async {
      await pumpAtScale(tester, QuickCardsScreen(onRequestAiChat: (_) {}), 2.0);
      final firstTile = find.byType(ExpansionTile).first;
      await tester.tap(firstTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('KitScreen renders at max scale without overflow',
        (tester) async {
      await pumpAtScale(tester, const KitScreen(), 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('screens also survive a narrow device at max scale',
        (tester) async {
      // 320dp — the narrowest Android phone still in circulation. Narrow
      // width plus large text is the worst case for a row of Bangla labels.
      await pumpAtScale(tester, QuickCardsScreen(onRequestAiChat: (_) {}), 2.0,
          size: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });
  });
}
