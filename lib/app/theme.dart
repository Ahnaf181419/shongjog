import 'package:flutter/material.dart';

/// Shongjog design tokens. Source of truth: docs/design.md §5.
class ShongjogTheme {
  // Light tokens
  static const Color paperWhite = Color(0xFFFAF7F0);
  static const Color sand = Color(0xFFF4ECD8);
  static const Color inkBlack = Color(0xFF1A1A1A);
  static const Color calmTeal = Color(0xFF0E5E6F);
  static const Color softTeal = Color(0xFFE8F0F2);
  static const Color alertRed = Color(0xFFB23A48);

  // Dark tokens
  static const Color darkBody = Color(0xFF0A1922);
  static const Color elevated = Color(0xFF112733);
  static const Color warmOffWhite = Color(0xFFF0EAE0);
  static const Color calmTealPlus = Color(0xFF4FB3C8);
  static const Color softTealDark = Color(0xFF1A3540);
  static const Color alertRedPlus = Color(0xFFE57180);
  static const Color mutedText = Color(0xFFA8B5BC);

  // Bangla-first font family. Skeleton uses system Bengali so no asset
  // dependency; Phase 5 swaps to HindSiliguri (OFL, bundled in assets/fonts/).
  static const String fontFamily = 'HindSiliguri';

  // Body floor is 17sp (design.md §5.2). Material default 14sp is too small
  // for low-literacy / stressed users.
  static const double bodyFloor = 17.0;
  static const double bodyLargeFloor = 20.0;

  static ThemeData light() => _buildTheme(Brightness.light);
  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = isLight ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true);
    final textColor = isLight ? inkBlack : warmOffWhite;
    final scaffoldBg = isLight ? paperWhite : darkBody;
    final appBarBg = isLight ? calmTeal : darkBody;
    final appBarFg = isLight ? paperWhite : warmOffWhite;
    final primary = isLight ? calmTeal : calmTealPlus;
    final error = isLight ? alertRed : alertRedPlus;

    final textTheme = base.textTheme.apply(
      bodyColor: textColor,
      displayColor: textColor,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: isLight ? paperWhite : darkBody,
        secondary: primary,
        onSecondary: isLight ? paperWhite : darkBody,
        surface: scaffoldBg,
        onSurface: textColor,
        error: error,
        onError: isLight ? paperWhite : darkBody,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme.copyWith(
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: bodyLargeFloor),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: bodyFloor),
        bodySmall: textTheme.bodySmall?.copyWith(fontSize: 14),
        headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: appBarFg,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
    );
  }
}
