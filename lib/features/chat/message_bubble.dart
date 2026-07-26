import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/theme.dart';
import 'chat_repository.dart';
import 'typewriter_text.dart';

/// A single chat message bubble. User bubbles right-aligned (ocean blue),
/// assistant bubbles left-aligned (surface). Assistant bubbles carry a
/// "পড়ুন" read-aloud button when [onSpeak] is provided, a small
/// [path] chip indicating which generation path answered, and a typewriter
/// reveal effect for freshly generated responses.
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final VoidCallback? onSpeak;

  /// If true, the text animates in with a typewriter effect.
  /// Set to false for messages restored from persistence.
  final bool animate;

  /// Which generation path produced this answer. Rendered as a small chip
  /// on the assistant bubble (so the user knows whether cloud, on-device
  /// Gemma, raw corpus, or the canned 999 fallback answered).
  final GenerationPath? path;

  /// Called once when the typewriter animation finishes (or immediately
  /// if animate is false). Used by ChatScreen to mark the _Msg.animate
  /// flag as false so subsequent rebuilds don't re-trigger the animation.
  final VoidCallback? onAnimateComplete;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.onSpeak,
    this.animate = false,
    this.path,
    this.onAnimateComplete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
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
            if (!isUser && path != null) ...[
              _PathChip(path: path!),
              const SizedBox(height: 8),
            ],
            if (!isUser && animate)
              TypewriterText(
                text: text,
                style: TextStyle(
                  fontSize: ShongjogTheme.bodyFloor,
                  height: 1.5,
                  color: isDark ? ShongjogTheme.inkDark : ShongjogTheme.ink,
                ),
                onComplete: onAnimateComplete,
              )
            else
              Text(
                text,
                style: TextStyle(
                  fontSize: ShongjogTheme.bodyFloor,
                  height: 1.5,
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
                  label: Text(l10n.chatReadAloud),
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

class _PathChip extends StatelessWidget {
  final GenerationPath path;
  const _PathChip({required this.path});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    Color tint;
    switch (path) {
      case GenerationPath.cloud:
        tint = isLight ? ShongjogTheme.ocean : ShongjogTheme.oceanBright;
        break;
      case GenerationPath.device:
        tint = isLight ? ShongjogTheme.success : ShongjogTheme.successBright;
        break;
      case GenerationPath.corpus:
        tint = cs.onSurfaceVariant;
        break;
      case GenerationPath.canned:
        tint = isLight ? ShongjogTheme.alert : ShongjogTheme.alertBright;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isLight ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        path.label(context),
        style: TextStyle(
          fontFamily: ShongjogTheme.fontFamily,
          fontFamilyFallback: ShongjogTheme.fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tint,
          height: 1.1,
        ),
      ),
    );
  }
}
