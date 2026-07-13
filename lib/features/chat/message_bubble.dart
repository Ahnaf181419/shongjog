import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A single chat message bubble. User bubbles right-aligned (calmTeal),
/// assistant bubbles left-aligned (surface). Assistant bubbles carry a
/// "পড়ুন" read-aloud button when [onSpeak] is provided.
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isUser
              ? ShongjogTheme.calmTeal
              : (isDark ? ShongjogTheme.darkSurface : ShongjogTheme.surface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isDark
                      ? ShongjogTheme.darkBorder
                      : ShongjogTheme.border,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: ShongjogTheme.bodyFloor,
                height: 1.5,
                color: isUser ? ShongjogTheme.white : null,
              ),
            ),
            if (!isUser && onSpeak != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: const Text('পড়ুন'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}