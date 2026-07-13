import 'package:flutter/material.dart';

/// Shongjog design tokens — clinical white + cool grey palette.
///
/// Direction: clean, modern, medical. Pure white surfaces (no beige),
/// deep teal identity, slate text. The calm-in-crisis feeling comes from
/// restraint and whitespace, not warm tones.
///
/// Source of truth: docs/design.md §5.1 (updated from warm-cream to clinical).
class ShongjogTheme {
  // ---- Brand / identity ----
  /// Deep teal — the brand accent. AppBar, primary CTAs, selected states.
  static const Color calmTeal = Color(0xFF0E5E6F);

  /// Brighter teal for dark mode and small accents.
  static const Color calmTealPlus = Color(0xFF14B8A6);

  // ---- Light surfaces (cool, not warm) ----
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8FAFC); // slate-50 — cards, inputs
  static const Color surfaceDim = Color(0xFFF1F5F9); // slate-100 — hover, pills
  static const Color border = Color(0xFFE2E8F0); // slate-200 — hairlines
  static const Color borderStrong = Color(0xFFCBD5E1); // slate-300

  // ---- Text (slate ramp, not pure black) ----
  static const Color ink = Color(0xFF0F172A); // slate-900 — primary text
  static const Color inkSecondary = Color(0xFF475569); // slate-600 — subtitles
  static const Color inkMuted = Color(0xFF94A3B8); // slate-400 — hints, captions

  // ---- Emergency-only ----
  static const Color alertRed = Color(0xFFDC2626); // red-600
  static const Color alertRedDark = Color(0xFFEF4444); // red-400 for dark

  // ---- Dark mode ----
  static const Color darkBg = Color(0xFF0F172A); // slate-900
  static const Color darkSurface = Color(0xFF1E293B); // slate-800
  static const Color darkBorder = Color(0xFF334155); // slate-700
  static const Color darkInk = Color(0xFFF1F5F9); // slate-100

  // ---- Semantic ----
  static const Color success = Color(0xFF16A34A); // green-600

  // ---- Bangla-first font ----
  static const String fontFamily = 'HindSiliguri';
  static const double bodyFloor = 17.0;
  static const double bodyLargeFloor = 20.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isLight = b == Brightness.light;
    final base = isLight
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);

    final scaffoldBg = isLight ? white : darkBg;
    final surface_ = isLight ? surface : darkSurface;
    final border_ = isLight ? border : darkBorder;
    final text = isLight ? ink : darkInk;
    final textSecondary = isLight ? inkSecondary : inkMuted;
    final primary = isLight ? calmTeal : calmTealPlus;
    final onPrimary = isLight ? white : darkBg;
    final error = isLight ? alertRed : alertRedDark;

    final tt = base.textTheme.apply(
      bodyColor: text,
      displayColor: text,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      colorScheme: ColorScheme(
        brightness: b,
        primary: primary,
        onPrimary: onPrimary,
        secondary: primary,
        onSecondary: onPrimary,
        surface: surface_,
        onSurface: text,
        error: error,
        onError: onPrimary,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      dividerColor: border_,
      textTheme: tt.copyWith(
        bodyLarge: tt.bodyLarge?.copyWith(fontSize: bodyLargeFloor),
        bodyMedium: tt.bodyMedium?.copyWith(fontSize: bodyFloor),
        bodySmall:
            tt.bodySmall?.copyWith(fontSize: 14, color: textSecondary),
        titleLarge:
            tt.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: text),
        headlineMedium:
            tt.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface_,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border_),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface_,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border_),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border_),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface_,
        side: BorderSide(color: border_),
        labelStyle: TextStyle(color: text, fontFamily: fontFamily),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}