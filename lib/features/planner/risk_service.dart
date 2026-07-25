import 'package:flutter/foundation.dart';

import '../../core/model_manager.dart';
import 'risk_prompt_builder.dart';

/// AI Risk Assessment service (Module C).
///
/// Generates a risk score (1-10) with Bangla explanation. Falls back
/// to the deterministic RiskPromptBuilder.fallbackScore on any
/// model failure. The UI never sees a blank result.
class RiskService {
  const RiskService();

  Future<RiskResult> assess(RiskInputs inputs) async {
    final prompt = RiskPromptBuilder.buildPrompt(inputs);
    if (prompt == null) return RiskPromptBuilder.fallbackScore(inputs);

    try {
      final shouldTryDevice =
          modelManager.isReady || await modelManager.isAnyOnDisk();
      if (shouldTryDevice) {
        final raw = await modelManager.generate(prompt);
        final cleaned = _clean(raw);
        if (cleaned.isNotEmpty) {
          return RiskResult(
            score: _extractScore(cleaned) ??
                RiskPromptBuilder.fallbackScore(inputs).score,
            summary: cleaned,
            improvements: RiskPromptBuilder.fallbackScore(inputs).improvements,
          );
        }
      }
    } catch (e) {
      debugPrint('[RiskService] model failed, using fallback: $e');
    }

    return RiskPromptBuilder.fallbackScore(inputs);
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

  /// Try to find an integer 1-10 in the model output. Returns null
  /// if no clear number is found.
  int? _extractScore(String s) {
    final m = RegExp(r'\b(\d)\b').firstMatch(s);
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!);
    if (n == null) return null;
    return n.clamp(1, 10);
  }
}