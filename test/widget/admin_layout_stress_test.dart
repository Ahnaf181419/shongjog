import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/app/app.dart';
import 'package:shongjog/app/router.dart';
import 'package:shongjog/app/theme.dart';
import 'package:shongjog/features/admin/admin_login_screen.dart';
import 'package:shongjog/features/admin/admin_pages.dart';
import 'package:shongjog/features/admin/admin_panel_screen.dart';
import 'package:shongjog/l10n/app_localizations.dart';

/// Layout stress for the admin section.
///
/// The admin screens carry the app's densest fixed geometry — a
/// `GridView.count` with `childAspectRatio: 1.4`, fixed 40/44/48px icon
/// wells, stat rows of three `Expanded` cards — and all of it is labelled in
/// Bangla, which sets wider than the English these ratios were eyeballed
/// against.
///
/// A fixed aspect ratio does not stretch. When the text inside a tile grows —
/// a longer Bangla string, a narrow phone, or the user's OS text scale — the
/// tile keeps its height and the content overflows. That failure is invisible
/// in release builds: the yellow-and-black stripe only appears in debug, so a
/// judge on a 320dp phone just sees clipped labels.
///
/// These render each screen at the corners of the supported range and fail on
/// any layout exception.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget home) => MaterialApp(
        locale: const Locale('bn'),
        theme: ShongjogTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
        routes: {
          AppRoutes.adminPanel: (_) => const AdminPanelScreen(),
          AppRoutes.adminDashboard: (_) => const AdminDashboardPage(),
          AppRoutes.adminUsers: (_) => const AdminUsersPage(),
          AppRoutes.adminCampaigns: (_) => const AdminCampaignsPage(),
          AppRoutes.adminBroadcast: (_) => const AdminBroadcastPage(),
          AppRoutes.adminDangerList: (_) => const AdminDangerListPage(),
        },
      );

  /// Renders [home] at [size] with [scale] text and returns any layout
  /// exception raised while doing so.
  Future<Object?> renderAt(
    WidgetTester tester,
    Widget home, {
    required Size size,
    required double scale,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MediaQuery(
      // Clamped exactly as ShongjogApp clamps it, so this tests the range
      // users can actually reach rather than an unreachable extreme.
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(scale)
            .clamp(maxScaleFactor: ShongjogApp.maxTextScale),
      ),
      child: wrap(home),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return tester.takeException();
  }

  // 320dp is the narrowest Android phone still in circulation; 411 is a
  // Pixel-class default. 1.0 and 2.0 bracket the OS text-scale range, with
  // 2.0 landing on the app's 1.5x ceiling.
  const corners = <String, (Size, double)>{
    'narrow 320dp @ 1.0x': (Size(320, 640), 1.0),
    'narrow 320dp @ max scale': (Size(320, 640), 2.0),
    'phone 411dp @ max scale': (Size(411, 891), 2.0),
    'short 360x600 @ max scale': (Size(360, 600), 2.0),
  };

  final screens = <String, Widget Function()>{
    'AdminPanelScreen': () => const AdminPanelScreen(),
    'AdminDashboardPage': () => const AdminDashboardPage(),
    'AdminUsersPage': () => const AdminUsersPage(),
    'AdminCampaignsPage': () => const AdminCampaignsPage(),
    'AdminBroadcastPage': () => const AdminBroadcastPage(),
    'AdminDangerListPage': () => const AdminDangerListPage(),
    'AdminLoginScreen': () => const AdminLoginScreen(),
  };

  for (final screen in screens.entries) {
    group(screen.key, () {
      for (final corner in corners.entries) {
        final (size, scale) = corner.value;
        testWidgets('lays out at ${corner.key}', (tester) async {
          final error =
              await renderAt(tester, screen.value(), size: size, scale: scale);
          expect(error, isNull,
              reason: '${screen.key} overflows at ${corner.key}. Fixed '
                  'geometry (childAspectRatio, fixed heights) does not '
                  'stretch when Bangla labels wrap.');
        });
      }
    });
  }

  group('the admin tile grid', () {
    testWidgets('is built from content-sized rows, not a fixed aspect ratio',
        (tester) async {
      // GridView.count requires a childAspectRatio, which pins tile height to
      // tile width — the tiles could never grow to fit a wrapped Bangla title
      // and overflowed by up to 186px. If a GridView reappears here, that
      // failure mode is back.
      final error = await renderAt(tester, const AdminPanelScreen(),
          size: const Size(320, 640), scale: 2.0);
      expect(error, isNull);

      expect(find.byType(GridView), findsNothing,
          reason: 'Use IntrinsicHeight rows so tiles size to their content.');
      expect(find.byType(IntrinsicHeight), findsWidgets);
    });

    testWidgets('both tiles in a row stay the same height', (tester) async {
      // The reason for IntrinsicHeight rather than plain Rows: a short label
      // beside a wrapped one would otherwise leave a ragged pair.
      final error = await renderAt(tester, const AdminPanelScreen(),
          size: const Size(320, 640), scale: 2.0);
      expect(error, isNull);

      final rows = find.descendant(
        of: find.byType(IntrinsicHeight).first,
        matching: find.byType(Card),
      );
      if (rows.evaluate().length < 2) return;
      final a = tester.getSize(rows.at(0)).height;
      final b = tester.getSize(rows.at(1)).height;
      expect(a, closeTo(b, 0.5));
    });
  });
}
