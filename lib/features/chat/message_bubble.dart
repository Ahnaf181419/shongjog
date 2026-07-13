import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A single chat message bubble. User bubbles right-aligned (calmTeal),
/// assistant bubbles left-aligned (softTeal). Assistant bubbles carry a
/// "পড়ুন" (read aloud) button when [onSpeak] is provided.
///
/// Per docs/design.md §7.1: 16dp radius, 17sp body, 24dp between bubbles.
/// Confidence-as-opacity (§11.5) is layered on in Phase 5.
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final VoidCallback? onSpeak;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isUser
        ? ShongjogTheme.calmTeal
        : (isDark ? ShongjogTheme.softTealDark : ShongjogTheme.softTeal);
    final textColor =
        isUser ? ShongjogTheme.paperWhite : ShongjogTheme.inkBlack;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: ShongjogTheme.bodyFloor,
                color: textColor,
                height: 1.5,
              ),
            ),
            if (!isUser && onSpeak != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: const Text('পড়ুন'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}