import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/router.dart';
import 'package:shongjog/features/admin/admin_login_screen.dart';
import 'package:shongjog/features/admin/admin_pages.dart';
import 'package:shongjog/features/admin/admin_panel_screen.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapLogin({VoidCallback? onLogin}) {
    return MaterialApp(
      locale: const Locale('bn'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AdminLoginScreen(),
      routes: {
        AppRoutes.adminPanel: (_) => const AdminPanelScreen(),
        AppRoutes.adminDashboard: (_) => const AdminDashboardPage(),
        AppRoutes.adminUsers: (_) => const AdminUsersPage(),
        AppRoutes.adminCampaigns: (_) => const AdminCampaignsPage(),
        AppRoutes.adminBroadcast: (_) => const AdminBroadcastPage(),
      },
    );
  }

  Widget wrapPanel() {
    return MaterialApp(
      locale: const Locale('bn'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AdminPanelScreen(),
      routes: {
        AppRoutes.adminDashboard: (_) => const AdminDashboardPage(),
        AppRoutes.adminUsers: (_) => const AdminUsersPage(),
        AppRoutes.adminCampaigns: (_) => const AdminCampaignsPage(),
        AppRoutes.adminBroadcast: (_) => const AdminBroadcastPage(),
      },
    );
  }

  group('AdminLoginScreen', () {
    testWidgets('renders login form fields', (tester) async {
      await tester.pumpWidget(wrapLogin());
      await tester.pumpAndSettle();

      expect(find.text('অ্যাডমিন প্যানেল প্রবেশাধিকার'), findsOneWidget);
      expect(find.text('ব্যবহারকারীর নাম'), findsOneWidget);
      expect(find.text('পাসওয়ার্ড'), findsOneWidget);
      expect(find.text('প্রবেশ করুন'), findsOneWidget);
    });

    testWidgets('shows validation error on empty submit', (tester) async {
      await tester.pumpWidget(wrapLogin());
      await tester.pumpAndSettle();

      await tester.tap(find.text('প্রবেশ করুন'));
      await tester.pumpAndSettle();

      expect(find.text('ব্যবহারকারীর নাম লিখুন'), findsOneWidget);
      expect(find.text('পাসওয়ার্ড লিখুন'), findsOneWidget);
    });

    testWidgets('shows error on wrong credentials', (tester) async {
      await tester.pumpWidget(wrapLogin());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'ব্যবহারকারীর নাম'), 'wrong');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'পাসওয়ার্ড'), 'wrong');
      await tester.tap(find.text('প্রবেশ করুন'));
      await tester.pumpAndSettle();

      expect(find.text('ভুল ব্যবহারকারীর নাম অথবা পাসওয়ার্ড।'), findsOneWidget);
    });

    testWidgets('accepts valid credentials', (tester) async {
      await tester.pumpWidget(wrapLogin());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'ব্যবহারকারীর নাম'), 'admin');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'পাসওয়ার্ড'), 'admin123');
      await tester.tap(find.text('প্রবেশ করুন'));
      await tester.pumpAndSettle();

      // Should navigate away from login screen (error should not be present)
      expect(find.text('ভুল ব্যবহারকারীর নাম অথবা পাসওয়ার্ড।'), findsNothing);
    });
  });

  group('AdminPanelScreen (grid entry, no tabs)', () {
    testWidgets('renders hero + stat row + 4 quick-action tiles',
        (tester) async {
      // Use a tall viewport so the 2x2 grid is on-screen.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrapPanel());
      await tester.pumpAndSettle();

      // Hero: title and subtitle appear at least once.
      // (The title also labels the Dashboard tile, so it may appear 2x.)
      expect(find.text('সিস্টেম সারসংক্ষেপ'), findsAtLeastNWidgets(2));
      expect(
          find.text('মেশ পিয়ার এবং অভিযানের রিয়েল-টাইম অবস্থা'),
          findsOneWidget);

      // Stat row labels — each exactly once on the entry screen.
      expect(find.text('মোট ব্যবহারকারী'), findsOneWidget);
      expect(find.text('অফলাইন সেশন'), findsOneWidget);
      expect(find.text('মেশ পিয়ার'), findsOneWidget);

      // Quick Actions section header.
      expect(find.text('দ্রুত অ্যাকশন'), findsOneWidget);

      // 4 grid tiles — each label appears at least once.
      // The Dashboard tile uses adminDashboardTitle (সিস্টেম সারসংক্ষেপ),
      // so it appears 2x (hero + tile). The other 3 are unique.
      expect(find.text('সিস্টেম সারসংক্ষেপ'), findsAtLeastNWidgets(2));
      expect(find.text('ব্যবহারকারী'), findsAtLeastNWidgets(1));
      expect(find.text('অভিযান অনুরোধ'), findsAtLeastNWidgets(1));
      expect(find.text('বার্তা ব্রডকাস্ট'), findsAtLeastNWidgets(1));

      // No TabBar (regression guard for the old layout).
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('tapping the campaigns tile pushes AdminCampaignsPage',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrapPanel());
      await tester.pumpAndSettle();

      // Find the first matching tile (one per Card in the grid).
      final tiles = find.descendant(
        of: find.byType(Card),
        matching: find.text('অভিযান অনুরোধ'),
      );
      // The tile is the InkWell inside the Card; tap the first one.
      await tester.tap(tiles.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // AdminCampaignsPage renders the empty-state copy when there are
      // no campaigns in the test environment.
      expect(find.text('কোনো অভিযান অনুরোধ নেই'), findsOneWidget);
    });

    testWidgets('tapping the users tile pushes AdminUsersPage',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrapPanel());
      await tester.pumpAndSettle();

      final tiles = find.descendant(
        of: find.byType(Card),
        matching: find.text('ব্যবহারকারী'),
      );
      await tester.tap(tiles.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // AdminUsersPage renders the empty-state copy when there are
      // no mesh peers in the test environment.
      expect(find.text('কোনো সংযুক্ত ডিভাইস নেই'), findsOneWidget);
    });

    testWidgets('tapping the broadcast tile pushes AdminBroadcastPage',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrapPanel());
      await tester.pumpAndSettle();

      final tiles = find.descendant(
        of: find.byType(Card),
        matching: find.text('বার্তা ব্রডকাস্ট'),
      );
      await tester.tap(tiles.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // AdminBroadcastPage shows its section title + send button.
      expect(find.text('গ্লোবাল ব্রডকাস্ট'), findsOneWidget);
      // The send button uses the short i18n key (পাঠান).
      expect(find.text('পাঠান'), findsOneWidget);
    });
  });
}
