import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/app/theme.dart';
import 'package:shongjog/features/splash/splash_screen.dart';
import 'package:shongjog/l10n/app_localizations.dart';

/// The splash is the app's first impression and the one screen every user
/// sees on every launch, so its failures are expensive and silent — the
/// previous version drew the monogram straight from `icon_foreground.png`,
/// whose S is navy #041128. On this near-black ground that is 1.29:1, i.e.
/// an invisible logo, and nothing caught it.
Widget _splash({VoidCallback? onComplete, bool reducedMotion = false}) {
  return MaterialApp(
    locale: const Locale('bn'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: reducedMotion
        ? (context, child) => MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: child ?? const SizedBox.shrink(),
            )
        : null,
    home: SplashScreen(onComplete: onComplete ?? () {}),
  );
}

void main() {
  group('SplashScreen composition', () {
    testWidgets('shows the wordmark and tagline from the ARB, not literals',
        (tester) async {
      await tester.pumpWidget(_splash());
      await tester.pump(SplashScreen.duration);

      // Bangla-first: docs/design.md §2 bans English on the user surface,
      // and splashTitle already carries the correct mark.
      expect(find.text('সংযোগ'), findsOneWidget);
      expect(find.text('জরুরি সঙ্গী'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('draws the same monogram asset as the launcher icon',
        (tester) async {
      await tester.pumpWidget(_splash());
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName,
          'assets/icon_foreground.png',
          reason: 'Sharing the launcher foreground keeps icon and splash from '
              'drifting into two different marks.');

      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('tints the monogram so it is actually visible on the dark '
        'ground', (tester) async {
      await tester.pumpWidget(_splash());
      await tester.pump();

      // The regression that made the old splash look broken. The asset is
      // navy; without a tint it renders at 1.29:1 and reads as empty space.
      final tinted = tester.widget<ColorFiltered>(
        find.ancestor(
          of: find.byType(Image),
          matching: find.byType(ColorFiltered),
        ),
      );
      expect(
        tinted.colorFilter,
        const ColorFilter.mode(ShongjogTheme.oceanBright, BlendMode.srcIn),
        reason: 'oceanBright is 8.33:1 on scaffoldDark; the raw navy asset '
            'is 1.05:1.',
      );

      await tester.pump(const Duration(milliseconds: 2000));
    });
  });

  group('SplashScreen timing', () {
    testWidgets('fires onComplete at the end of the sequence', (tester) async {
      var completed = false;
      await tester.pumpWidget(_splash(onComplete: () => completed = true));

      await tester
          .pump(SplashScreen.duration + const Duration(milliseconds: 50));
      expect(completed, isTrue);
    });

    testWidgets('does not fire early', (tester) async {
      var completed = false;
      await tester.pumpWidget(_splash(onComplete: () => completed = true));

      await tester.pump(const Duration(milliseconds: 800));
      expect(completed, isFalse);

      await tester.pump(SplashScreen.duration);
    });

    test('stays short — this cost is paid on every launch, forever', () {
      // An emergency app has no business holding someone on a logo. If this
      // ever needs raising, it should be a deliberate, argued change.
      expect(SplashScreen.duration.inMilliseconds, lessThanOrEqualTo(1800));
    });

    testWidgets('reduced motion shows the finished composition and moves on',
        (tester) async {
      var completed = false;
      await tester.pumpWidget(
          _splash(onComplete: () => completed = true, reducedMotion: true));
      await tester.pump();

      // Everything must be at rest and legible immediately — not faded out
      // waiting for an animation that will never run.
      expect(find.text('সংযোগ'), findsOneWidget);
      final opacities =
          tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity);
      expect(opacities.every((o) => o == 1.0), isTrue,
          reason: 'With animations disabled every element is fully opaque.');

      await tester.pump(const Duration(milliseconds: 500));
      expect(completed, isTrue);
    });
  });

  group('SplashScreen layout', () {
    testWidgets('mark, wordmark and horizon share one optical axis',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_splash());
      await tester.pump(SplashScreen.duration);

      const screenCentreX = 180.0;
      for (final finder in [
        find.byType(Image),
        find.text('সংযোগ'),
        find.text('জরুরি সঙ্গী'),
      ]) {
        final centre = tester.getCenter(finder);
        expect(centre.dx, closeTo(screenCentreX, 1.0),
            reason: 'Everything sits on the same vertical axis; a drifting '
                'element reads as a mistake even when nothing else is wrong.');
      }

      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the mark sits above true centre so the wordmark balances it',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_splash());
      await tester.pump(SplashScreen.duration);

      final mark = tester.getCenter(find.byType(Image)).dy;
      final word = tester.getCenter(find.text('সংযোগ')).dy;

      expect(mark, lessThan(380),
          reason: 'Optical centring: a mark on the mathematical centre with '
              'text beneath it reads as sitting low.');
      expect(word, greaterThan(mark), reason: 'Wordmark sits below the mark.');

      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
