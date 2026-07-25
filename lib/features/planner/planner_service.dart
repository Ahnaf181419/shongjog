import 'package:flutter/foundation.dart';

import '../../core/model_manager.dart';
import 'family_profile.dart';
import 'planner_prompt_builder.dart';

/// Generates a personalized disaster plan from a family profile.
///
/// Tries the on-device model first; falls back to a deterministic
/// plan on ANY failure (model not ready, generation error, empty
/// output). The UI never sees an empty result.
class PlannerService {
  const PlannerService();

  /// Generate a plan. Returns the model output on success, or the
  /// deterministic fallback on any failure.
  Future<String> generatePlan(FamilyProfile profile) async {
    final prompt = PlannerPromptBuilder.buildPlan(profile);
    if (prompt == null) {
      return PlannerPromptBuilder.fallbackPlan(profile);
    }

    try {
      final shouldTryDevice =
          modelManager.isReady || await modelManager.isAnyOnDisk();
      if (shouldTryDevice) {
        final raw = await modelManager.generate(prompt);
        final cleaned = _clean(raw);
        if (cleaned.isNotEmpty) return cleaned;
      }
    } catch (e) {
      debugPrint('[PlannerService] model failed, using fallback: $e');
    }

    return PlannerPromptBuilder.fallbackPlan(profile);
  }

  /// Strip control tokens + turn markers from the model output.
  String _clean(String raw) {
    var s = raw;
    // Remove thinking-channel leaks.
    s = s.replaceAll(
        RegExp(r'<\|channel\|>thinking.*?(?=<\|channel\|>final|$)',
            dotAll: true),
        '');
    // Remove any remaining channel tags.
    s = s.replaceAll(RegExp(r'<\|[^|]*\|>'), '');
    return s.trim();
  }
}
