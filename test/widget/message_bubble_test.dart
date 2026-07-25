import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/theme.dart';
import 'package:shongjog/features/chat/chat_repository.dart';
import 'package:shongjog/features/chat/message_bubble.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ShongjogTheme.light(),
        home: Scaffold(body: child),
      );

  testWidgets('renders path chip for cloud answer', (tester) async {
    await tester.pumpWidget(wrap(MessageBubble(
      text: 'উত্তর',
      isUser: false,
      path: GenerationPath.cloud,
    )));
    expect(find.text('ক্লাউড'), findsOneWidget);
  });

  testWidgets('renders path chip for device answer', (tester) async {
    await tester.pumpWidget(wrap(MessageBubble(
      text: 'উত্তর',
      isUser: false,
      path: GenerationPath.device,
    )));
    expect(find.text('ডিভাইস'), findsOneWidget);
  });

  testWidgets('renders path chip for corpus fallback', (tester) async {
    await tester.pumpWidget(wrap(MessageBubble(
      text: 'উত্তর',
      isUser: false,
      path: GenerationPath.corpus,
    )));
    expect(find.text('কোরপাস'), findsOneWidget);
  });

  testWidgets('renders path chip for canned 999 fallback', (tester) async {
    await tester.pumpWidget(wrap(MessageBubble(
      text: 'উত্তর',
      isUser: false,
      path: GenerationPath.canned,
    )));
    expect(find.text('৯৯৯'), findsOneWidget);
  });

  testWidgets('omits chip when path is null', (tester) async {
    await tester.pumpWidget(wrap(const MessageBubble(
      text: 'উত্তর',
      isUser: false,
    )));
    expect(find.text('ক্লাউড'), findsNothing);
    expect(find.text('ডিভাইস'), findsNothing);
    expect(find.text('কোরপাস'), findsNothing);
    expect(find.text('৯৯৯'), findsNothing);
  });

  testWidgets('user bubbles never carry a chip', (tester) async {
    await tester.pumpWidget(wrap(MessageBubble(
      text: 'প্রশ্ন',
      isUser: true,
      path: GenerationPath.cloud,
    )));
    expect(find.text('ক্লাউড'), findsNothing);
  });

  testWidgets('calls onAnimateComplete when typewriter finishes', (tester) async {
    var completed = false;
    await tester.pumpWidget(wrap(MessageBubble(
      text: 'ABC',
      isUser: false,
      animate: true,
      onAnimateComplete: () => completed = true,
    )));
    // 3 clusters × 33ms default = 99ms; pump enough to let the timer fire
    await tester.pump(const Duration(milliseconds: 150));
    expect(completed, isTrue);
  });

  testWidgets('does not re-animate on parent rebuild', (tester) async {
    var animationCount = 0;

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('bn'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                MessageBubble(
                  text: 'Hello',
                  isUser: false,
                  animate: true,
                  onAnimateComplete: () => animationCount++,
                ),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Rebuild'),
                ),
              ],
            );
          },
        ),
      ),
    ));

    // Let initial animation complete (5 clusters × 33ms = 165ms)
    await tester.pump(const Duration(milliseconds: 200));
    expect(animationCount, 1);

    // Trigger parent rebuild — _hasCompleted should prevent re-animation
    await tester.tap(find.text('Rebuild'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(animationCount, 1);
  });
}
