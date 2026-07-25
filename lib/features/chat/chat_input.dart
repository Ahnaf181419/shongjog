import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../core/haptics.dart';

/// Premium mic-first chat input.
///
/// Layout:
/// - 64dp floating mic FAB on the left, sitting on the row baseline
/// - Ambient breathing pulse (2.6s opacity 0.55↔1.0) when idle and STT
///   ready — the signature "I'm listening if you need me" affordance
/// - Active pulse (1.4s) when actively listening
/// - Heavy shadow → 1dp elevation at rest, 8dp during press
/// - Text input center, send button right
///
/// Always-visible send button — narrow conditional rebuilds can crash
/// Flutter Web's mouse_tracker (see prior implementation), so we don't
/// hide it. _submit() guards against empty text.
class ChatInput extends StatefulWidget {
  final void Function(String) onSubmit;
  final VoidCallback onMicPressed;
  final bool isListening;

  /// Bypass mode for tests / contexts where STT isn't available.
  final bool voiceInputEnabled;

  const ChatInput({
    super.key,
    required this.onSubmit,
    required this.onMicPressed,
    this.isListening = false,
    this.voiceInputEnabled = true,
  });

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();

  // One controller drives both the idle ambient pulse and the active mic pulse.
  late final AnimationController _pulse;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: widget.isListening
          ? const Duration(milliseconds: 1400)
          : const Duration(milliseconds: 2600),
    );
    _opacity = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    if (widget.voiceInputEnabled) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      _pulse.duration = Duration(
        milliseconds: widget.isListening ? 1400 : 2600,
      );
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  /// Public for chat screen — STT partials drop into the text field.
  void setText(String text) {
    _ctrl.text = text;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _ctrl.text.length),
    );
  }

  String get text => _ctrl.text;

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    HapticService.lightTap();
    widget.onSubmit(v);
    _ctrl.clear();
  }

  void _handleMic() {
    if (!widget.voiceInputEnabled) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatVoiceInputDisabled)),
      );
      return;
    }
    HapticService.lightTap();
    widget.onMicPressed();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    // Listening-state color must adapt: `alert` (red-600) reads OK on
    // light, but on dark scaffold a brighter tone (red-400) keeps the
    // FAB and its glow visible. Both guaranteed ≥AAA on the surrounding
    // white-on-color text/icons.
    final micColor = widget.isListening
        ? (isDark ? ShongjogTheme.alertBright : ShongjogTheme.alert)
        : cs.primary;
    final micLabel = widget.isListening
        ? l10n.chatListening
        : l10n.chatEmptyPrompt;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 64dp premium mic FAB with breathing pulse.
            SizedBox(
              width: 64,
              height: 64,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) {
                  return Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    elevation: widget.isListening ? 6 : 2,
                    child: InkWell(
                      onTap: _handleMic,
                      customBorder: const CircleBorder(),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: micColor,
                            boxShadow: widget.isListening
                                ? [
                                    BoxShadow(
                                      color: micColor.withValues(alpha: 0.55),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Opacity(
                              opacity: _opacity.value,
                              child: Icon(
                                widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                color: cs.onPrimary,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Semantics(
                  label: micLabel,
                  textField: true,
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(
                      fontSize: ShongjogTheme.bodyFloor,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.chatEmptyPrompt,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button — also 64dp to anchor the mic visually.
            SizedBox(
              height: 64,
              width: 80,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: ShongjogTheme.bodyFloor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(l10n.chatSend),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
