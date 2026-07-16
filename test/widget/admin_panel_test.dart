import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/router.dart';
import 'package:shongjog/features/admin/admin_login_screen.dart';
import 'package:shongjog/features/admin/admin_panel_screen.dart';

void main() {
  Widget wrapLogin({VoidCallback? onLogin}) {
    return MaterialApp(
      home: const AdminLoginScreen(),
      routes: {
        AppRoutes.adminPanel: (_) => const AdminPanelScreen(),
      },
    );
  }

  Widget wrapPanel() {
    return const MaterialApp(
      home: AdminPanelScreen(),
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

  group('AdminPanelScreen', () {
    testWidgets('renders tab bar with three tabs', (tester) async {
      await tester.pumpWidget(wrapPanel());
      await tester.pumpAndSettle();

      expect(find.text('ড্যাশবোর্ড'), findsOneWidget);
      expect(find.text('ব্যবহারকারী'), findsOneWidget);
      expect(find.text('বার্তা ব্রডকাস্ট'), findsOneWidget);
    });

    testWidgets('dashboard tab shows stat cards', (tester) async {
      await tester.pumpWidget(wrapPanel());
      await tester.pumpAndSettle();

      expect(find.text('মোট ব্যবহারকারী'), findsOneWidget);
      expect(find.text('অফলাইন সেশন'), findsOneWidget);
      expect(find.text('মেশ পিয়ার'), findsOneWidget);
    });

    testWidgets('broadcast tab shows message input', (tester) async {
      await tester.pumpWidget(wrapPanel());
      await tester.pumpAndSettle();

      // Tap on broadcast tab
      await tester.tap(find.text('বার্তা ব্রডকাস্ট'));
      await tester.pumpAndSettle();

      expect(find.text('গ্লোবাল ব্রডকাস্ট'), findsOneWidget);
      expect(find.text('বার্তা পাঠান'), findsWidgets);
    });
  });
}
