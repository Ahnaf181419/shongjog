import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/theme.dart';

/// Contrast guards for the design tokens.
///
/// These exist because a status badge shipped at 2.57:1 — less than half the
/// WCAG floor — and nothing caught it. The colour looked fine in isolation;
/// what broke it was painting the label on a ~15% tint of its own hue, which
/// lifts the background luminance and eats the contrast the flat value
/// appeared to have. So every check here composites the tint first, exactly
/// as [ShongjogTheme.toneChip] does.
///
/// Shongjog is read outdoors, at night, on cheap screens, by people in an
/// emergency. Treat a failure here as a real defect, not a lint.

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Composite [fg] at [alpha] over [bg] — what a tinted chip background is.
Color composite(Color fg, double alpha, Color bg) => Color.fromARGB(
      255,
      ((fg.r * alpha + bg.r * (1 - alpha)) * 255).round(),
      ((fg.g * alpha + bg.g * (1 - alpha)) * 255).round(),
      ((fg.b * alpha + bg.b * (1 - alpha)) * 255).round(),
    );

/// Pumps a widget so token helpers that need a [BuildContext] can be read
/// under a known brightness.
Future<T> underBrightness<T>(
  WidgetTester tester,
  Brightness b,
  T Function(BuildContext) read,
) async {
  late T out;
  await tester.pumpWidget(MaterialApp(
    theme: b == Brightness.light ? ShongjogTheme.light() : ShongjogTheme.dark(),
    home: Builder(builder: (c) {
      out = read(c);
      return const SizedBox();
    }),
  ));
  return out;
}

void main() {
  // Small text needs 4.5:1. Every status badge in the app is small text.
  const smallTextFloor = 4.5;
  // Body copy is held to the stricter AAA bar the theme docstring claims.
  const bodyFloor = 7.0;

  group('body and secondary text hold AAA', () {
    test('light', () {
      expect(contrast(ShongjogTheme.ink, ShongjogTheme.surface),
          greaterThanOrEqualTo(bodyFloor));
      expect(contrast(ShongjogTheme.ink, ShongjogTheme.scaffoldLight),
          greaterThanOrEqualTo(bodyFloor));
      expect(contrast(ShongjogTheme.inkSecondary, ShongjogTheme.surface),
          greaterThanOrEqualTo(bodyFloor));
    });

    test('dark', () {
      expect(contrast(ShongjogTheme.inkDark, ShongjogTheme.scaffoldDark),
          greaterThanOrEqualTo(bodyFloor));
      expect(contrast(ShongjogTheme.inkDark, ShongjogTheme.surfaceDark),
          greaterThanOrEqualTo(bodyFloor));
      expect(
          contrast(ShongjogTheme.inkSecondaryDark, ShongjogTheme.surfaceDark),
          greaterThanOrEqualTo(bodyFloor));
    });
  });

  group('semantic ink survives its own chip tint', () {
    // The regression that motivated this file. `toneChip` tints at 0.15, and
    // the worst ground is the sunk surface a card sits on — so that pairing
    // is what gets asserted, not the flattering flat-on-white number.
    const tintAlpha = 0.15;

    for (final tone in SemanticTone.values) {
      testWidgets('$tone — light, on surface and surfaceDim', (tester) async {
        final ink = await underBrightness(
            tester, Brightness.light, (c) => ShongjogTheme.toneInk(c, tone));
        final fill = await underBrightness(
            tester, Brightness.light, (c) => ShongjogTheme.toneFill(c, tone));

        for (final ground in [ShongjogTheme.surface, ShongjogTheme.surfaceDim]) {
          final chipBg = composite(fill, tintAlpha, ground);
          expect(contrast(ink, chipBg), greaterThanOrEqualTo(smallTextFloor),
              reason: '$tone label on its own $tintAlpha tint over $ground '
                  'must clear $smallTextFloor:1 — this is the exact pairing '
                  'that shipped at 2.57:1.');
        }
      });

      testWidgets('$tone — dark, on surfaceDark and surfaceDimDark',
          (tester) async {
        final ink = await underBrightness(
            tester, Brightness.dark, (c) => ShongjogTheme.toneInk(c, tone));
        final fill = await underBrightness(
            tester, Brightness.dark, (c) => ShongjogTheme.toneFill(c, tone));

        for (final ground in [
          ShongjogTheme.surfaceDark,
          ShongjogTheme.surfaceDimDark,
        ]) {
          final chipBg = composite(fill, tintAlpha, ground);
          expect(contrast(ink, chipBg), greaterThanOrEqualTo(smallTextFloor),
              reason: '$tone label on its own $tintAlpha tint over $ground');
        }
      });
    }
  });

  group('solid tone buttons stay legible', () {
    // A filled emergency button is `toneFill` background + `onToneFill`
    // label. White is the intuitive foreground and is WRONG for several of
    // these: white on the light-mode success fill is 3.30:1, while ink on
    // the same fill is 5.42:1.
    for (final brightness in Brightness.values) {
      for (final tone in SemanticTone.values) {
        testWidgets('$tone on $brightness', (tester) async {
          final fill = await underBrightness(
              tester, brightness, (c) => ShongjogTheme.toneFill(c, tone));
          final fg = await underBrightness(
              tester, brightness, (c) => ShongjogTheme.onToneFill(c, tone));

          expect(contrast(fg, fill), greaterThanOrEqualTo(smallTextFloor),
              reason: 'The label on a solid $tone button must clear '
                  '$smallTextFloor:1 in $brightness.');
        });
      }
    }

    testWidgets('onToneFill genuinely picks ink where white would fail',
        (tester) async {
      // Pins the counter-intuitive case, so nobody "simplifies" this helper
      // back to a hardcoded Colors.white.
      final fg = await underBrightness(tester, Brightness.light,
          (c) => ShongjogTheme.onToneFill(c, SemanticTone.success));
      expect(fg, ShongjogTheme.ink,
          reason: 'White on the light success fill is only 3.30:1.');
    });
  });

  group('semantic fills are not mistaken for ink', () {
    test('the mid-tone fills genuinely fail as text — so the ink steps are '
        'not redundant ceremony', () {
      // If these ever start passing, the fills were re-tuned and toneInk
      // could be simplified. Until then this documents WHY the split exists.
      expect(contrast(ShongjogTheme.success, ShongjogTheme.surface),
          lessThan(smallTextFloor));
      expect(
          contrast(
              ShongjogTheme.success,
              composite(ShongjogTheme.success, 0.15, ShongjogTheme.surfaceDim)),
          lessThan(smallTextFloor));
    });
  });

  group('primary and error clear the small-text floor', () {
    test('light', () {
      expect(contrast(ShongjogTheme.ocean, ShongjogTheme.surface),
          greaterThanOrEqualTo(smallTextFloor));
      expect(contrast(ShongjogTheme.white, ShongjogTheme.ocean),
          greaterThanOrEqualTo(smallTextFloor));
      expect(contrast(ShongjogTheme.alert, ShongjogTheme.surface),
          greaterThanOrEqualTo(smallTextFloor));
    });

    test('dark', () {
      expect(contrast(ShongjogTheme.oceanBright, ShongjogTheme.scaffoldDark),
          greaterThanOrEqualTo(smallTextFloor));
      expect(contrast(ShongjogTheme.scaffoldDark, ShongjogTheme.oceanBright),
          greaterThanOrEqualTo(smallTextFloor));
      expect(contrast(ShongjogTheme.alertBright, ShongjogTheme.surfaceDark),
          greaterThanOrEqualTo(smallTextFloor));
    });
  });

  group('inkMuted is fenced to non-text use', () {
    // 2.56:1 — fine for a hairline (3:1 non-text), never for a label. The
    // docstring says "icons/hints only"; this pins that it stays that way.
    test('is below the text floor, so it must never be used as text', () {
      expect(contrast(ShongjogTheme.inkMuted, ShongjogTheme.surface),
          lessThan(smallTextFloor));
      expect(contrast(ShongjogTheme.inkMutedDark, ShongjogTheme.surfaceDark),
          lessThan(smallTextFloor));
    });
  });
}
