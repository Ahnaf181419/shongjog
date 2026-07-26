import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/pending_chat_prompt.dart';

/// Contract test for the PendingChatPrompt wiring used by the
/// "Ask AI" pill button on QuickCardsScreen → ChatScreen.
///
/// The bug we're guarding against: the chat screen used to call
/// `PendingChatPrompt.consume(context)` only once during its
/// `initState()`, so any prompt requested AFTER the chat screen was
/// first built (the normal case — the tab is cached and never
/// re-initializes) was silently dropped. The fix: the chat screen
/// subscribes to the notifier in `initState()` and re-consumes on
/// every notification.
///
/// These tests pin down the contract that `_ChatScreenState` must
/// honor: once mounted, a widget that subscribes to the
/// `PendingChatPrompt`'s notifier must receive every prompt that
/// arrives via `requestPrompt(...)` for the lifetime of the widget.
void main() {
  testWidgets(
    'pending prompt arrives at a widget that subscribes after build',
    (tester) async {
      final received = <String>[];
      final notifier = ValueNotifier<String?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: PendingChatPrompt(
            notifier: notifier,
            child: _SubscribedChild(
              onPrompt: (p) => received.add(p),
            ),
          ),
        ),
      );

      // No prompt yet — nothing received.
      expect(received, isEmpty);

      // Simulate the cards-screen "Ask AI" callback landing.
      PendingChatPrompt.of(
        tester.element(find.byType(_SubscribedChild)),
      )!.requestPrompt('সাপের কামড়। কাটবেন না');
      await tester.pump();

      expect(received, ['সাপের কামড়। কাটবেন না']);
      // consume() must clear the slot so the same prompt doesn't
      // re-fire on a rebuild.
      expect(notifier.value, isNull);
    },
  );

  testWidgets(
    'subscribed widget receives a second prompt after the first',
    (tester) async {
      final received = <String>[];
      final notifier = ValueNotifier<String?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: PendingChatPrompt(
            notifier: notifier,
            child: _SubscribedChild(
              onPrompt: (p) => received.add(p),
            ),
          ),
        ),
      );

      PendingChatPrompt.of(
        tester.element(find.byType(_SubscribedChild)),
      )!.requestPrompt('প্রথম');
      await tester.pump();
      expect(received, ['প্রথম']);

      // The critical case: this is the bug reproduction. The chat
      // screen was already built, the user navigates back to cards,
      // taps Ask AI again. The prompt must arrive.
      PendingChatPrompt.of(
        tester.element(find.byType(_SubscribedChild)),
      )!.requestPrompt('দ্বিতীয়');
      await tester.pump();
      expect(received, ['প্রথম', 'দ্বিতীয়']);
    },
  );

  testWidgets(
    'subscribed widget receives a prompt set after the first build',
    (tester) async {
      final received = <String>[];
      final notifier = ValueNotifier<String?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: PendingChatPrompt(
            notifier: notifier,
            child: _SubscribedChild(
              onPrompt: (p) => received.add(p),
            ),
          ),
        ),
      );

      // Pop the loop a few times to simulate the user having been
      // on the screen for a while (no automatic notifications).
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(received, isEmpty);

      // Now the prompt arrives.
      notifier.value = 'পরে এসেছে';
      await tester.pump();
      expect(received, ['পরে এসেছে']);
    },
  );
}

/// Minimal widget that mirrors the chat screen's subscribe pattern:
/// on mount, find the PendingChatPrompt and add a listener that
/// consumes the prompt and dispatches it. On unmount, remove the
/// listener. Crucially, this keeps the subscription alive for the
/// entire lifetime of the widget, not just the first frame.
class _SubscribedChild extends StatefulWidget {
  final void Function(String prompt) onPrompt;
  const _SubscribedChild({required this.onPrompt});

  @override
  State<_SubscribedChild> createState() => _SubscribedChildState();
}

class _SubscribedChildState extends State<_SubscribedChild> {
  ValueNotifier<String?>? _notifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = PendingChatPrompt.of(context)?.notifier;
    if (notifier == _notifier) return; // already wired
    _notifier?.removeListener(_onChanged);
    _notifier = notifier;
    _notifier?.addListener(_onChanged);
    // Drain anything already in the slot (cold-start case).
    _onChanged();
  }

  @override
  void dispose() {
    _notifier?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final pending = PendingChatPrompt.consume(context);
    if (pending != null) widget.onPrompt(pending);
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: ValueKey('sub'));
}
