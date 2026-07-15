import 'package:flutter/services.dart';

/// Codified haptic vocabulary per `docs/design.md` §13.1.
///
/// Five signatures, map to Flutter platform APIs:
///   lightTap   = HapticFeedback.lightImpact        (mic press)
///   mediumTap  = HapticFeedback.selectionClick     (card open, selection)
///   success    = HapticFeedback.mediumImpact       (answer rendered)
///   warn       = HapticFeedback.heavyImpact        (low-confidence answer)
///   strong     = HapticFeedback.heavyImpact + vibrate (emergency confirmed)
///
/// Haptics respect MediaQuery.disableAnimations — if reduced motion is on, haptics
/// are also suppressed (some users have sensory sensitivities that span both).
class HapticService {
  static bool _enabled = true;

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static Future<void> lightTap() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> mediumTap() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> success() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> warn() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  static Future<void> strong() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await HapticFeedback.vibrate();
  }

  /// Tick at 50% and 90% of slide-to-confirm knob drag.
  static Future<void> tick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }
}

/// Bangla label registry for haptic events (debug overlay only).
/// Per `docs/design.md` §15.2 implementation handoff.
class HapticEventLabels {
  static const lightTap = 'lightTap';
  static const mediumTap = 'mediumTap';
  static const success = 'success';
  static const warn = 'warn';
  static const strong = 'strong';
  static const tick = 'tick';
}
