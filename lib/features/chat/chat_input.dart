import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Mic-first chat input. Mic button (left), text field (center), send
/// button (right — always visible, guarded by _submit).
///
/// Per docs/design.md §7.1: mic is the primary affordance; typing is
/// secondary.
///
/// IMPORTANT: On Flutter Web, any rebuild triggered by TextEditingController
/// listeners fires during the pointer-event phase and crashes Flutter's
/// mouse_tracker. We therefore NEVER call setState, listen to the controller,
/// or use ValueListenableBuilder. The send button is always visible and
/// _submit() guards against empty input.
class ChatInput extends StatefulWidget {
  final void Function(String) onSubmit;
  final VoidCallback onMicPressed;
  final bool isListening;

  const ChatInput({
    super.key,
    required this.onSubmit,
    required this.onMicPressed,
    this.isListening = false,
  });

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Public so the chat screen can write STT partials into the field.
  void setText(String text) {
    _ctrl.text = text;
    _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length));
  }

  /// Currently displayed text.
  String get text => _ctrl.text;

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    widget.onSubmit(v);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton.filled(
              iconSize: 32,
              onPressed: widget.onMicPressed,
              style: IconButton.styleFrom(
                backgroundColor: widget.isListening
                    ? ShongjogTheme.alertRed
                    : ShongjogTheme.calmTeal,
              ),
              icon: Icon(widget.isListening ? Icons.stop : Icons.mic),
              tooltip: widget.isListening
                  ? 'শুনছি, থামাতে আবার চাপুন'
                  : 'প্রশ্ন বলুন',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'আপনার প্রশ্ন লিখুন...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            // Always-visible send button. _submit() guards against empty text.
            // Never conditionally show/hide — any rebuild from the controller
            // crashes Flutter Web's mouse_tracker.
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                // Override the global theme's Size.fromHeight(52) which has
                // double.infinity width and crashes the Row layout.
                minimumSize: const Size(80, 52),
              ),
              child: const Text('পাঠান'),
            ),
          ],
        ),
      ),
    );
  }
}