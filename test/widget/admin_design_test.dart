import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/theme.dart';
import 'package:shongjog/core/admin_broadcast_service.dart';
import 'package:shongjog/features/admin/admin_pages.dart';
import 'package:shongjog/features/admin/admin_widgets.dart';
import 'package:shongjog/l10n/app_localizations.dart';

/// Guards the outcomes of the admin design audit — the behaviours that are
/// easy to regress silently because nothing else in the suite looks at them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, {Locale locale = const Locale('bn')}) {
    return MaterialApp(
      locale: locale,
      theme: ShongjogTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  group('Broadcast confirmation', () {
    testWidgets('Send opens a confirmation instead of broadcasting',
        (tester) async {
      await tester.pumpWidget(wrap(const AdminBroadcastPage()));
      await tester.pumpAndSettle();

      final before = adminBroadcastService.messages.length;

      await tester.enterText(find.byType(TextField), 'পরীক্ষামূলক ঘোষণা');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'পাঠান'));
      await tester.pumpAndSettle();

      // The dialog is up, and nothing has gone out yet.
      expect(find.text('সবার কাছে পাঠাবেন?'), findsOneWidget);
      expect(adminBroadcastService.messages.length, before);
    });

    testWidgets('the confirmation previews the message as it will arrive',
        (tester) async {
      await tester.pumpWidget(wrap(const AdminBroadcastPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'পরীক্ষামূলক ঘোষণা');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'পাঠান'));
      await tester.pumpAndSettle();

      // The real tray title, so an admin sees the actual notification.
      expect(find.text(AdminBroadcastService.notificationTitle), findsOneWidget);
      expect(find.text('পরীক্ষামূলক ঘোষণা'), findsWidgets);
    });

    testWidgets('cancelling sends nothing and keeps the draft', (tester) async {
      await tester.pumpWidget(wrap(const AdminBroadcastPage()));
      await tester.pumpAndSettle();

      final before = adminBroadcastService.messages.length;

      await tester.enterText(find.byType(TextField), 'বাতিল হবে');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'পাঠান'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('বাতিল'));
      await tester.pumpAndSettle();

      expect(adminBroadcastService.messages.length, before);
      // Losing what they wrote would punish the admin for being careful.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'বাতিল হবে',
      );
    });

    testWidgets('Send is disabled while the field is empty', (tester) async {
      await tester.pumpWidget(wrap(const AdminBroadcastPage()));
      await tester.pumpAndSettle();

      final button =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'পাঠান'));
      expect(button.onPressed, isNull);
    });
  });

  group('Localisation', () {
    testWidgets('the danger list carries no hardcoded Bangla in English',
        (tester) async {
      await tester.pumpWidget(
        wrap(const AdminDangerListPage(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      // Empty state, but the point is that the page renders under `en`
      // without falling back to the Bangla literals it used to embed.
      expect(find.text('No one in danger'), findsOneWidget);
      expect(find.text('এইমাত্র'), findsNothing);
    });
  });

  group('Accessibility', () {
    testWidgets('quick-action chips meet the 48dp tap-target floor',
        (tester) async {
      await tester.pumpWidget(wrap(const AdminDashboardPage()));
      await tester.pumpAndSettle();

      final chips = find.descendant(
        of: find.byType(Wrap),
        matching: find.byType(InkWell),
      );
      expect(chips, findsWidgets);
      for (final element in chips.evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)).height,
          greaterThanOrEqualTo(48.0),
          reason: '§6 Accessibility: minimum tap target is 48x48dp',
        );
      }
    });

    testWidgets('stat cards read as one labelled node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const AdminDashboardPage()));
      await tester.pumpAndSettle();

      // "মোট ব্যবহারকারী ০" — label and value together, not an
      // unlabelled icon followed by two loose strings.
      expect(
        find.bySemanticsLabel(RegExp('মোট ব্যবহারকারী')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('Shared primitives', () {
    testWidgets('AdminEmptyState tones its icon by meaning', (tester) async {
      await tester.pumpWidget(wrap(const Scaffold(
        body: AdminEmptyState(
          icon: Icons.check_circle_rounded,
          message: 'all clear',
          tone: SemanticTone.success,
        ),
      )));
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
      expect(icon.color, ShongjogTheme.success);
    });
  });
}
