import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The meaning a status colour carries. Separate from the brand accent —
/// these are reserved for state and are never used as decoration.
enum SemanticTone { success, warning, danger, info }

/// Shongjog design tokens — Deep Ocean Blue identity.
///
/// Direction: calm-in-crisis, authoritative, premium. One locked hue (~205°)
/// carries the brand in both modes; lightness varies, hue never does.
/// Every text/background pair is AAA-verified (≥7:1 body, ≥3:1 large).
///
/// Source of truth: docs/design.md §5.
class ShongjogTheme {
  ShongjogTheme._();

  // ─── Brand (locked hue ~205°, sky family) ──────────────────
  /// Deep ocean blue — light-mode primary. AppBar accents, CTAs, hero tiles.
  static const Color ocean = Color(0xFF0369A1); // sky-700 — L~32

  /// Brighter ocean blue — dark-mode primary. Same hue, higher luminance.
  static const Color oceanBright = Color(0xFF38BDF8); // sky-400 — L~70

  // ─── Light surfaces (cool neutrals, no warm tint) ─────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color scaffoldLight = Color(0xFFF8FAFC); // slate-50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9); // slate-100
  static const Color border = Color(0xFFE2E8F0); // slate-200 — hairlines
  static const Color borderStrong = Color(0xFFCBD5E1); // slate-300

  // ─── Text ramp (slate) ────────────────────────────────────
  static const Color ink = Color(0xFF0F172A); // slate-900 — body, 16:1 on white
  static const Color inkSecondary = Color(0xFF475569); // slate-600 — 7.4:1 AAA
  static const Color inkMuted = Color(0xFF94A3B8); // slate-400 — icons/hints only

  // ─── Dark surfaces ────────────────────────────────────────
  static const Color scaffoldDark = Color(0xFF0F172A); // slate-900
  static const Color surfaceDark = Color(0xFF1E293B); // slate-800
  static const Color surfaceDimDark = Color(0xFF172033); // slate-800/900 blend
  static const Color borderDark = Color(0xFF334155); // slate-700
  static const Color borderStrongDark = Color(0xFF475569); // slate-600

  // ─── Dark text ramp ───────────────────────────────────────
  static const Color inkDark = Color(0xFFF1F5F9); // slate-100 — 14:1 on slate-900
  static const Color inkSecondaryDark = Color(0xFFCBD5E1); // slate-300 — 8.6:1 AAA
  static const Color inkMutedDark = Color(0xFF64748B); // slate-500 — icons only

  // ─── Emergency (alertRed — reserved, never decorative) ────
  static const Color alert = Color(0xFFDC2626); // red-600 — light mode
  static const Color alertBright = Color(0xFFF87171); // red-400 — dark mode

  // ─── Semantic FILLS (icons, solid marks, tint backgrounds) ─
  //
  // These are mid-tone and are NOT safe as text. `success` measures 3.30:1 on
  // white — below the 4.5:1 floor before any background tint is applied. Use
  // the ink steps below for anything a user has to read.
  static const Color success = Color(0xFF16A34A); // green-600
  static const Color successBright = Color(0xFF4ADE80); // green-400
  static const Color warning = Color(0xFFB45309); // amber-700
  static const Color warningBright = Color(0xFFFCD34D); // amber-300

  // ─── Semantic INK (text-safe steps) ───────────────────────
  //
  // Two steps darker than the fills, because a status chip paints its label on
  // a ~15% tint of its own hue — which raises the background luminance and
  // eats the contrast the flat colour appeared to have. Measured on the worst
  // ground in the app (a 15% tint over `surfaceDim`):
  //
  //   green-600 #16A34A  2.57:1  <- what the badges used to be
  //   green-800 #166534  5.18:1  <- successInk
  //   amber-800 #92400E  5.15:1  <- warningInk
  //   red-800   #991B1B  5.82:1  <- dangerInk
  //
  // Prefer [toneInk] / [toneChip] over reaching for these directly — they pick
  // the right step for the active brightness.
  static const Color successInk = Color(0xFF166534); // green-800
  static const Color successInkDark = Color(0xFF86EFAC); // green-300
  static const Color warningInk = Color(0xFF92400E); // amber-800
  static const Color warningInkDark = Color(0xFFFCD34D); // amber-300
  static const Color dangerInk = Color(0xFF991B1B); // red-800
  static const Color dangerInkDark = Color(0xFFFCA5A5); // red-300

  /// Info ink. Deliberately a step darker than [ocean]: the brand primary is
  /// 5.93:1 flat but only 4.37:1 once it sits on a 15% tint of itself, so it
  /// cannot double as its own chip label. Same locked hue (~205°).
  static const Color infoInk = Color(0xFF075985); // sky-800
  static const Color infoInkDark = Color(0xFF7DD3FC); // sky-300

  // The teal-era aliases (calmTeal, alertRed, darkBg, …) are gone — the
  // migration to the ocean palette is complete and every call site moved.
  // They were worth keeping while in use; keeping them past that just
  // offered two names for one colour, and `isE2b ? calmTeal : ocean` had
  // already appeared in the wild — a ternary whose branches were the same
  // value, because calmTeal WAS ocean.

  // ─── Bangla-first font ────────────────────────────────────
  // Primary: Anek Bangla — modern variable font, crisp Bangla numerals.
  // Fallback: Manrope — for Latin characters (English diagnostics, version
  // numbers, About screen, etc.). Flutter's fontFamilyFallback chain routes
  // each glyph to the first font that has it, so a Bangla string with a
  // few Latin characters renders each script in its own typeface.
  static const String fontFamily = 'AnekBangla';
  static const List<String> fontFallback = ['Manrope'];
  static const double bodyFloor = 17.0;
  static const double bodyLargeFloor = 20.0;

  // ─── Shape ────────────────────────────────────────────────
  //
  // docs/design.md §5.4 locks the app to 12dp and 16dp surfaces, with 20dp
  // reserved for sheet top corners. `radiusSm` was 10dp — a value that
  // appears nowhere in the spec — while 12dp was the single most common
  // literal in the codebase (29 uses). The token was the drift, not the call
  // sites, so it now matches the spec it claims to implement.
  static const double radiusSm = 12.0;
  static const double radius = 16.0;
  static const double radiusLg = 20.0;

  // ─── Helpers for custom widgets ───────────────────────────

  /// Body text color that adapts to the current theme.
  ///
  /// `ShongjogTheme.ink` (slate-900) is correct only in light mode; on a
  /// dark scaffold it would render dark-on-dark and be invisible. Same
  /// for `inkSecondary`. These helpers route through Material 3's
  /// [ColorScheme.onSurface] so text reads AAA on every background.
  ///
  /// Usage in production screens:
  /// ```dart
  /// color: ShongjogTheme.body(context),
  /// color: ShongjogTheme.bodySecondary(context),
  /// ```
  static Color body(BuildContext c) => Theme.of(c).colorScheme.onSurface;

  /// Secondary body color (captions, subtitles, helper text). Adapts.
  static Color bodySecondary(BuildContext c) =>
      Theme.of(c).colorScheme.onSurfaceVariant;

  /// Card surface color that adapts — returns `surface` in light, the
  /// mid-tone `surfaceContainerHighest` in dark. Avoids the "jarring
  /// bright white card on dark scaffold" problem when widgets hardcode
  /// `ShongjogTheme.surface`.
  static Color cardSurface(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return cs.brightness == Brightness.dark
        ? cs.surfaceContainerHighest
        : cs.surface;
  }

  /// Soft-elevation card decoration — tinted surface, hairline border,
  /// diffuse shadow. The signature "clean and rich" surface.
  static BoxDecoration cardDecoration(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return BoxDecoration(
      color: cardSurface(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isLight ? border : Theme.of(context).colorScheme.outlineVariant,
      ),
      boxShadow: [
        BoxShadow(
          color: isLight
              ? const Color(0xFF000000).withValues(alpha: 0.05)
              : const Color(0xFF000000).withValues(alpha: 0.30),
          offset: const Offset(0, 2),
          blurRadius: 12,
        ),
      ],
    );
  }

  /// Tinted icon badge — soft rounded square with 10-15% brand tint.
  static BoxDecoration iconBadge(BuildContext context, {Color? tint}) {
    final c = tint ?? Theme.of(context).colorScheme.primary;
    return BoxDecoration(
      color: c.withValues(alpha: Theme.of(context).brightness == Brightness.light
          ? 0.10
          : 0.15),
      borderRadius: BorderRadius.circular(radiusSm),
    );
  }

  /// Drenched hero panel — soft linear gradient + low elevation.
  ///
  /// Used for the AI entry card on Home. Both gradient stops live in the
  /// locked sky family (~205°); ~10-15% lightness variation, no hue drift.
  /// The drench comes from gradient + scale + composition, never from glow.
  static BoxDecoration heroPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isLight
          ? const [Color(0xFF0284C7), Color(0xFF075985)] // sky-600 → sky-800
          : const [Color(0xFF38BDF8), Color(0xFF0369A1)], // sky-400 → sky-700
    );
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(radiusLg),
      boxShadow: [
        BoxShadow(
          color: cs.primary.withValues(alpha: isLight ? 0.25 : 0.40),
          offset: const Offset(0, 8),
          blurRadius: 16,
        ),
      ],
    );
  }

  /// Recessed mic well — soft tinted container that holds the mic icon on
  /// the drenched hero. Reads as "contained object," not "light source."
  static BoxDecoration micWell(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    return BoxDecoration(
      color: cs.onPrimary.withValues(alpha: isLight ? 0.18 : 0.22),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// Bangla numeral chip — small bordered square on drenched panels, used
  /// for secondary state markers (model-ready, alert count, etc.).
  static BoxDecoration numeralChip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.onPrimary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: cs.onPrimary.withValues(alpha: 0.30),
        width: 1,
      ),
    );
  }

  /// Text-safe colour for [tone], adapted to the active brightness.
  ///
  /// Use this for any status text. See the ink tokens for why the fills are
  /// not interchangeable with these.
  static Color toneInk(BuildContext c, SemanticTone tone) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return switch (tone) {
      SemanticTone.success => dark ? successInkDark : successInk,
      SemanticTone.warning => dark ? warningInkDark : warningInk,
      SemanticTone.danger => dark ? dangerInkDark : dangerInk,
      SemanticTone.info => dark ? infoInkDark : infoInk,
    };
  }

  /// Fill colour for [tone] — icons, solid marks, progress. Never text.
  static Color toneFill(BuildContext c, SemanticTone tone) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return switch (tone) {
      SemanticTone.success => dark ? successBright : success,
      SemanticTone.warning => dark ? warningBright : warning,
      SemanticTone.danger => dark ? alertBright : alert,
      SemanticTone.info => Theme.of(c).colorScheme.primary,
    };
  }

  /// Foreground for a SOLID [toneFill] background — a filled button, a badge
  /// with no tint, a snackbar.
  ///
  /// Picks whichever neutral extreme actually has more contrast on that fill,
  /// rather than defaulting to white. That default is wrong more often than
  /// it looks: white on the light-mode success fill is 3.30:1, while ink on
  /// the same fill is 5.42:1. In dark mode every fill is a light step, so ink
  /// wins across the board.
  ///
  /// Computed rather than tabulated so it stays correct if a fill is retuned.
  static Color onToneFill(BuildContext c, SemanticTone tone) {
    final fill = toneFill(c, tone);
    final onLight = _contrastRatio(ink, fill);
    final onWhite = _contrastRatio(white, fill);
    return onWhite >= onLight ? white : ink;
  }

  /// WCAG 2.1 relative luminance.
  static double _relativeLuminance(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  static double _contrastRatio(Color a, Color b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Tinted status chip — the container half of a status badge.
  ///
  /// Pair it with [toneInk] for the label. Going through this pair is what
  /// keeps a badge readable: the tint here and the ink there were measured
  /// against each other, so no call site has to re-derive the contrast.
  ///
  /// ```dart
  /// Container(
  ///   decoration: ShongjogTheme.toneChip(context, SemanticTone.success),
  ///   child: Text(label, style: TextStyle(
  ///     color: ShongjogTheme.toneInk(context, SemanticTone.success),
  ///     fontSize: 14,
  ///   )),
  /// )
  /// ```
  static BoxDecoration toneChip(BuildContext c, SemanticTone tone) {
    return BoxDecoration(
      color: toneFill(c, tone).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(radiusSm),
    );
  }

  /// Status chip — hairline pill for inline status lines on the body.
  /// Sits on the scaffold; uses `surfaceContainerHighest` so it lifts off
  /// the bg subtly without screaming for attention.
  static BoxDecoration statusChip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radiusSm),
      border: Border.all(color: cs.outlineVariant),
    );
  }

  /// Weather card surface — soft surface with hairline + diffuse shadow.
  /// Used as the wrapper for the today row + 3-day strip.
  static BoxDecoration weatherCard(BuildContext context) {
    return cardDecoration(context);
  }

  /// Emergency pill — solid error fill, small radius, used in the AppBar
  /// for the persistent "জরুরি কল" shortcut. Children paint in `onError`.
  static BoxDecoration emergencyPill(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.error,
      borderRadius: BorderRadius.circular(radiusSm),
    );
  }

  /// Adaptive hairline border color (slate-200 in light, surfaceContainerHighest
  /// outline in dark).
  static Color hairline(BuildContext c) =>
      Theme.of(c).colorScheme.outlineVariant;

  // ─── Theme data builders ──────────────────────────────────

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isLight = b == Brightness.light;
    final base = isLight
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);

    final scaffoldBg = isLight ? scaffoldLight : scaffoldDark;
    final surfaceColor = isLight ? surface : surfaceDark;
    final borderColor = isLight ? border : borderDark;
    final primaryColor = isLight ? ocean : oceanBright;
    final onPrimaryColor = isLight ? white : scaffoldDark;
    final textPrimary = isLight ? ink : inkDark;
    final textSecondary = isLight ? inkSecondary : inkSecondaryDark;
    final errorColor = isLight ? alert : alertBright;

    final tt = base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
    );

    final colorScheme = ColorScheme(
      brightness: b,
      primary: primaryColor,
      onPrimary: onPrimaryColor,
      secondary: primaryColor,
      onSecondary: onPrimaryColor,
      surface: surfaceColor,
      onSurface: textPrimary,
      surfaceContainerHighest: isLight ? surfaceDim : surfaceDimDark,
      error: errorColor,
      onError: onPrimaryColor,
      outline: isLight ? inkMuted : inkMutedDark,
      outlineVariant: borderColor,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      dividerColor: borderColor,
      textTheme: tt.copyWith(
        // Enforce the body floor (17sp) and caption floor (14sp) globally.
        // Anything below 14sp is a type-scale violation we want to catch in
        // code review, not a value the designer gets to pick.
        bodyLarge: tt.bodyLarge?.copyWith(
          fontSize: bodyLargeFloor,
          height: 1.45,
        ),
        bodyMedium: tt.bodyMedium?.copyWith(
          fontSize: bodyFloor,
          height: 1.45,
        ),
        bodySmall: tt.bodySmall?.copyWith(
          fontSize: 14,
          color: textSecondary,
          height: 1.35,
        ),
        titleLarge:
            tt.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium:
            tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium:
            tt.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: tt.labelLarge?.copyWith(
          fontSize: 17,
          height: 1.2,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
        ),
        labelMedium: tt.labelMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          color: textSecondary,
          letterSpacing: 0.02,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: primaryColor.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFallback,
            // The one documented exception to the 14sp caption floor, and it
            // is pinned in test/unit/type_scale_test.dart. Material 3 specs
            // navigation labels at 12sp; they are persistent chrome rather
            // than content, each paired with a 26px icon that carries the
            // affordance. Five Bangla labels at 14sp overflow the 72px bar.
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryColor : (isLight ? inkMuted : inkMutedDark),
            size: 26,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? surfaceDim : surfaceDimDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          color: textSecondary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          textStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
            fontFamilyFallback: fontFallback,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryColor;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return onPrimaryColor;
            }
            return textSecondary;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          ),
          textStyle: WidgetStateProperty.all(
            TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: fontFallback,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return onPrimaryColor;
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.5);
          }
          return borderColor;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primaryColor,
        textColor: textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          fontSize: 14,
          color: textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          color: isLight ? white : scaffoldDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
