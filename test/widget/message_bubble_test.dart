import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/theme.dart';
import 'package:shongjog/features/chat/chat_repository.dart';
import 'package:shongjog/features/chat/message_bubble.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
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
}
