import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'typewriter_text.dart';

/// A single chat message bubble. User bubbles right-aligned (ocean blue),
/// assistant bubbles left-aligned (surface). Assistant bubbles carry a
/// "পড়ুন" read-aloud button when [onSpeak] is provided and use a
/// typewriter reveal effect for freshly generated responses.
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final VoidCallback? onSpeak;

  /// If true, the text animates in with a typewriter effect.
  /// Set to false for messages restored from persistence.
  final bool animate;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.onSpeak,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          // User bubble uses the adaptive primary — sky-700 (deep) in light,
          // sky-400 (bright) in dark. Hardcoded `ocean` blended into the dark
          // scaffold; this matches `cs.primary` so the bubble pops in both
          // modes while staying on-brand.
          color: isUser
              ? cs.primary
              : (isDark
                  ? cs.surfaceContainerHighest
                  : cs.surface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: ShongjogTheme.hairline(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && animate)
              TypewriterText(
                text: text,
                style: TextStyle(
                  fontSize: ShongjogTheme.bodyFloor,
                  height: 1.5,
                  color: isDark ? ShongjogTheme.inkDark : ShongjogTheme.ink,
                ),
              )
            else
              Text(
                text,
                style: TextStyle(
                  fontSize: ShongjogTheme.bodyFloor,
                  height: 1.5,
                  // User bubble: white text always (the surface is brand
                  // primary in both modes, both pass AAA with white).
                  // Assistant bubble: theme-adaptive body color so it
                  // reads on either light or dark surface.
                  color: isUser ? cs.onPrimary : cs.onSurface,
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
                    foregroundColor: cs.primary,
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
