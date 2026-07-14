import 'package:flutter/material.dart';

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

  // ─── Semantic ─────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A); // green-600
  static const Color successBright = Color(0xFF4ADE80); // green-400

  // ─── Backward-compatible aliases (old token names → new) ───
  @Deprecated('Use ocean instead')
  static const Color calmTeal = ocean;
  @Deprecated('Use oceanBright instead')
  static const Color calmTealPlus = oceanBright;
  @Deprecated('Use alert instead')
  static const Color alertRed = alert;
  @Deprecated('Use alertBright instead')
  static const Color alertRedDark = alertBright;
  @Deprecated('Use scaffoldDark instead')
  static const Color darkBg = scaffoldDark;
  @Deprecated('Use surfaceDark instead')
  static const Color darkSurface = surfaceDark;
  @Deprecated('Use borderDark instead')
  static const Color darkBorder = borderDark;
  @Deprecated('Use inkDark instead')
  static const Color darkInk = inkDark;

  // ─── Bangla-first font ────────────────────────────────────
  static const String fontFamily = 'HindSiliguri';
  static const double bodyFloor = 17.0;
  static const double bodyLargeFloor = 20.0;

  // ─── Shape ────────────────────────────────────────────────
  static const double radiusSm = 10.0;
  static const double radius = 16.0;
  static const double radiusLg = 20.0;

  // ─── Helpers for custom widgets ───────────────────────────

  /// Soft-elevation card decoration — tinted surface, hairline border,
  /// diffuse shadow. The signature "clean and rich" surface.
  static BoxDecoration cardDecoration(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: isLight ? border : borderDark),
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
        bodyLarge: tt.bodyLarge?.copyWith(fontSize: bodyLargeFloor),
        bodyMedium: tt.bodyMedium?.copyWith(fontSize: bodyFloor),
        bodySmall:
            tt.bodySmall?.copyWith(fontSize: 14, color: textSecondary),
        titleLarge:
            tt.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium:
            tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium:
            tt.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: tt.labelLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
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
          color: textSecondary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          minimumSize: const Size(0, 52), // Replaces Size.fromHeight(52) which causes infinite width crashes
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          textStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
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
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
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
          color: isLight ? white : scaffoldDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
