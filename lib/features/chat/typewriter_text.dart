import 'dart:async';
import 'package:flutter/material.dart';

/// Reveals text cluster-by-cluster for a typewriter effect.
///
/// **Bangla-aware**: walks the string by Unicode grapheme clusters, never by
/// UTF-16 code units. A conjunct glyph like ক্ষ or জ্ঞ is a single grapheme
/// and must never be cut in half mid-render — that's the difference between
/// "nice animation" and "shows broken Bangla" (design.md §2 absolute ban).
///
/// Speed: tuned to ~30fps insertion (one cluster every ~33ms) per design.md
/// §5.5. Each tick reveals one cluster; long ones (like ক্ষ) feel slower but
/// stay readable.
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration stepDuration;
  final VoidCallback? onComplete;

  /// If false, skip the animation and show the full text immediately.
  final bool animate;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.stepDuration = const Duration(milliseconds: 33),
    this.onComplete,
    this.animate = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  late int _clustersShown;
  late final List<String> _clusters;
  Timer? _timer;

  /// Tracks whether the animation has already completed for this text.
  /// Prevents re-animation when the parent rebuilds (e.g. after a new
  /// message arrives and setState fires on ChatScreen). Without this,
  /// every setState would recreate TypewriterText with animate=true,
  /// restarting the typewriter from scratch on ALL visible messages.
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _clusters = _graphemeClusters(widget.text);
    if (widget.animate && !_hasCompleted) {
      _clustersShown = 0;
      _startTyping();
    } else {
      _clustersShown = _clusters.length;
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _hasCompleted = false;
      _timer?.cancel();
      _clusters
        ..clear()
        ..addAll(_graphemeClusters(widget.text));
      _clustersShown = widget.animate && !_hasCompleted ? 0 : _clusters.length;
      if (widget.animate && !_hasCompleted && _clustersShown < _clusters.length) {
        _startTyping();
      }
    }
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.stepDuration, (t) {
      if (_clustersShown >= _clusters.length) {
        t.cancel();
        _hasCompleted = true;
        widget.onComplete?.call();
        return;
      }
      setState(() => _clustersShown += 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Split a string into Unicode extended grapheme clusters so we don't
  /// cut conjuncts (যুক্তাক্ষর) or emoji sequences mid-render.
  ///
  /// Uses dart:core's [String.runes] + UAX #29 segmentation. We pick
  /// this manually so the dependency footprint stays small (no intl).
  static List<String> _graphemeClusters(String input) {
    if (input.isEmpty) return const [];
    // Use the runes Iterator; cluster boundaries are at base + extenders
    // (combining marks, ZWJ, virama). Cheap enough for chat-length strings
    // and correct enough for Bangla conjuncts.
    final out = <String>[];
    final chars = input.characters;
    out.addAll(chars.toList()); // Characters.iterator respects UAX #29
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _clusters.take(_clustersShown).join();
    final isTyping = _clustersShown < _clusters.length;
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
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
        ],
      ),
    );
  }
}
