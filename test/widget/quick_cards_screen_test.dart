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
      home: QuickCardsScreen(
        onRequestAiChat: (_) {},
      ),
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
      home: QuickCardsScreen(
        onRequestAiChat: (_) {},
      ),
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
      home: QuickCardsScreen(
        onRequestAiChat: (_) {},
      ),
    ));

    expect(find.text('জরুরি সহায়তা কার্ড'), findsOneWidget);
  });

  testWidgets('AI pill button appears in expanded card and triggers callback with title + first step',
      (tester) async {
    String? capturedPrompt;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('bn'),
      home: QuickCardsScreen(
        onRequestAiChat: (prompt) => capturedPrompt = prompt,
      ),
    ));

    // Expand the snakebite card.
    await tester.tap(find.text('সাপের কামড়'));
    await tester.pumpAndSettle();

    // AI pill button label is visible inside the expanded card.
    expect(find.text('এআই-তে জিজ্ঞাসা করুন'), findsOneWidget);

    final chip = find.byType(ActionChip).first;
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(capturedPrompt, isNotNull);
    expect(capturedPrompt!.startsWith('সাপের কামড়। '), isTrue,
        reason: 'prompt should be "<title>। <first step>"');
    expect(capturedPrompt!.contains('কাটবেন না'), isTrue,
        reason: 'prompt should include the snakebite card first step');
  });
}
