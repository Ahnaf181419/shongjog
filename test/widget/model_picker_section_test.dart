import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/theme.dart';
import 'package:shongjog/features/settings/model_picker_section.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {
  // These tests MUST use the real ShongjogTheme. Under a bare MaterialApp the
  // picker renders fine, which is exactly why the layout crash below shipped:
  // the app theme's filledButtonTheme sets minimumSize: Size.fromHeight(52)
  // (width == double.infinity), and a Row hands its non-flex children
  // unbounded width — so the download button threw "BoxConstraints forces an
  // infinite width" and the whole card silently vanished.
  Widget wrap({double width = 1280}) {
    return MaterialApp(
      locale: const Locale('bn'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ShongjogTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: ListView(children: const [ModelPickerSection()]),
        ),
      ),
    );
  }

  group('ModelPickerSection under the real app theme', () {
    testWidgets('renders a download button per available variant', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      // E2B + E4B are downloadable; 12B is unavailable and must stay hidden.
      expect(find.text('ডাউনলোড'), findsNWidgets(2));
      expect(find.textContaining('Gemma 4 E2B'), findsOneWidget);
      expect(find.textContaining('Gemma 4 12B'), findsNothing);
    });

    testWidgets('card lays out without throwing at narrow widths', (tester) async {
      await tester.pumpWidget(wrap(width: 360));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.text('ডাউনলোড'), findsNWidgets(2));
    });

    testWidgets('download button is finitely sized inside its row',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final size = tester.getSize(find.ancestor(
        of: find.text('ডাউনলোড').first,
        matching: find.byType(FilledButton).first,
      ));
      expect(size.width.isFinite, isTrue);
      expect(size.width, lessThan(400));
    });
  });
}
