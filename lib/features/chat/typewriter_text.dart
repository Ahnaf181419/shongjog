import 'dart:async';
import 'package:flutter/material.dart';

/// Reveals text character-by-character for a typewriter effect.
///
/// Used by [MessageBubble] for assistant responses to give a sense of
/// the AI "speaking" the answer. Skips the animation for user messages
/// and for messages restored from persistence.
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration stepDuration;
  final VoidCallback? onComplete;

  /// If true, skip the animation and show the full text immediately.
  final bool animate;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.stepDuration = const Duration(milliseconds: 15),
    this.onComplete,
    this.animate = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  late int _chars;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _chars = widget.animate ? 0 : widget.text.length;
    if (widget.animate) _startTyping();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      _chars = widget.animate ? 0 : widget.text.length;
      if (widget.animate) _startTyping();
    }
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.stepDuration, (t) {
      if (_chars >= widget.text.length) {
        t.cancel();
        widget.onComplete?.call();
        return;
      }
      setState(() => _chars += 2);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.text.substring(0, _chars.clamp(0, widget.text.length));
    final isTyping = _chars < widget.text.length;
    return RichText(
      text: TextSpan(
        text: shown,
        style: widget.style,
        children: [
          if (isTyping)
            TextSpan(
              text: '▌',
              style: widget.style?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ) ??
                  TextStyle(
                      color: Theme.of(context).colorScheme.primary),
            ),
        ],
      ),
    );
  }
}
