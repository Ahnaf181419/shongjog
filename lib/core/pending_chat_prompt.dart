import 'package:flutter/widgets.dart';

class PendingChatPrompt extends InheritedNotifier<ValueNotifier<String?>> {
  const PendingChatPrompt({
    super.key,
    required ValueNotifier<String?> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static PendingChatPrompt? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PendingChatPrompt>();
  }

  static String? consume(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<PendingChatPrompt>();
    final value = widget?.notifier?.value;
    widget?.notifier?.value = null;
    return value;
  }

  void requestPrompt(String prompt) {
    notifier?.value = prompt;
  }
}
