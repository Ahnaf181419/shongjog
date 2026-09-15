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

  group('Control sizing', () {
    testWidgets('every button type is the same height', (tester) async {
      await tester.pumpWidget(wrap(Scaffold(
        body: Column(children: [
          FilledButton(onPressed: () {}, child: const Text('filled')),
          FilledButton.tonal(onPressed: () {}, child: const Text('tonal')),
          TextButton(onPressed: () {}, child: const Text('text')),
          OutlinedButton(onPressed: () {}, child: const Text('outlined')),
        ]),
      )));
      await tester.pumpAndSettle();

      // TextButton and OutlinedButton had no theme entry and kept Material's
      // 40dp default next to a 52dp FilledButton — a visible mismatch
      // wherever they were paired, and under the 48dp tap-target floor.
      for (final label in ['filled', 'tonal', 'text', 'outlined']) {
        final button = find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first;
        expect(tester.getSize(button).height, 52.0,
            reason: '$label button should match the 52dp control height');
      }
    });

    testWidgets('dialog actions sit on one row at equal height',
        (tester) async {
      await tester.pumpWidget(wrap(Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => confirmAdminAction(ctx,
                title: 'T', body: 'B', confirmLabel: 'go'),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // filledButtonTheme uses Size.fromHeight(52), whose minimum WIDTH is
      // infinity — OverflowBar cannot fit that beside anything, so it used to
      // stack a 40dp Cancel above a full-width 52dp confirm.
      Rect rectOf(String label) => tester.getRect(find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first);
      final cancel = rectOf('বাতিল');
      final confirm = rectOf('go');
      expect(cancel.top, confirm.top, reason: 'actions must share a row');
      expect(cancel.height, 52.0);
      expect(confirm.height, 52.0);
    });

    testWidgets('tonal buttons are not just filled buttons', (tester) async {
      await tester.pumpWidget(wrap(Scaffold(
        body: Column(children: [
          FilledButton(onPressed: () {}, child: const Text('filled')),
          FilledButton.tonal(onPressed: () {}, child: const Text('tonal')),
        ]),
      )));
      await tester.pumpAndSettle();

      Color? bgOf(String label) => tester
          .widget<Material>(find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first)
          .color;
      // secondaryContainer was unset and fell back to `secondary`, which this
      // scheme points at the brand hue — so tonal rendered identically to
      // filled and the middle emphasis level did not exist.
      expect(bgOf('tonal'), isNot(bgOf('filled')));
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
