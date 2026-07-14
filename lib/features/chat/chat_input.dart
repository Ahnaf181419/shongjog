import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Mic-first chat input. Mic button (left), text field (center), send
/// button (right, visible when text present). Mic wiring lands in Phase 4.
///
/// Per docs/design.md §7.1: mic is the primary affordance; typing is
/// secondary. The send button only appears once the field has content.
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
    setState(() {});
  }

  /// Currently displayed text.
  String get text => _ctrl.text;

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    widget.onSubmit(v);
    _ctrl.clear();
    setState(() {});
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
              tooltip: widget.isListening ? 'শুনছি, থামাতে আবার চাপুন' : 'প্রশ্ন বলুন',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'আপনার প্রশ্ন লিখুন...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            if (_ctrl.text.trim().isNotEmpty)
              FilledButton(onPressed: _submit, child: const Text('পাঠান')),
          ],
        ),
      ),
    );
  }
}