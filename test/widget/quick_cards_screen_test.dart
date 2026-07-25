import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/quick_cards/quick_cards_screen.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {
  testWidgets('renders all quick cards', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('bn'),
      home: const QuickCardsScreen(),
    ));

    expect(find.byType(ExpansionTile), findsWidgets);
    expect(find.text('ORS তৈরি'), findsOneWidget);
    expect(find.text('পানি শুদ্ধ করা'), findsOneWidget);
    expect(find.text('সাপের কামড়'), findsOneWidget);
  });

  testWidgets('expanding a card shows steps', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('bn'),
      home: const QuickCardsScreen(),
    ));

    await tester.tap(find.text('ORS তৈরি'));
    await tester.pumpAndSettle();

    expect(find.textContaining('পানি'), findsWidgets);
  });

  testWidgets('has app bar with bangla title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('bn'),
      home: const QuickCardsScreen(),
    ));

    expect(find.text('জরুরি সহায়তা কার্ড'), findsOneWidget);
  });
}
