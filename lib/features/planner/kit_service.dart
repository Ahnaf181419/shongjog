import 'package:flutter/foundation.dart';

import '../../core/model_manager.dart';
import 'family_profile.dart';
import 'kit_prompt_builder.dart';

/// Generates a personalized emergency kit list from a family profile.
class KitService {
  const KitService();

  Future<String> generateKit(FamilyProfile profile) async {
    final prompt = KitPromptBuilder.buildPrompt(profile);
    if (prompt == null) {
      return KitPromptBuilder.fallbackKit(profile);
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
      debugPrint('[KitService] model failed, using fallback: $e');
    }

    return KitPromptBuilder.fallbackKit(profile);
  }

  String _clean(String raw) {
    var s = raw;
    s = s.replaceAll(
        RegExp(r'<\|channel\|>thinking.*?(?=<\|channel\|>final|$)',
            dotAll: true),
        '');
    s = s.replaceAll(RegExp(r'<\|[^|]*\|>'), '');
    return s.trim();
  }
}