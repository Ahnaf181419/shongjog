import 'package:flutter/foundation.dart';

import '../../core/model_manager.dart';
import 'risk_prompt_builder.dart';

/// Bengali digit → ASCII digit map. The risk prompt explicitly instructs
/// the model to answer using Bangla numerals ("বাংলা সংখ্যা ব্যবহার
/// করো"), so score extraction must understand them — a plain `\d` regex
/// only matches ASCII 0-9 and silently matches nothing on a
/// prompt-compliant response.
const _bengaliToAscii = {
  '০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4',
  '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9',
};

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
            score: extractScore(cleaned) ??
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
  ///
  /// Two things the old `\b(\d)\b` regex got wrong: it only matched
  /// ASCII digits (the model answers in Bangla numerals per the
  /// prompt, so it never matched a real response — every score always
  /// fell back to the deterministic one even when the model's own text
  /// summary WAS used, producing a badge/summary that could disagree),
  /// and a single-digit-only match can never capture "10".
  @visibleForTesting
  int? extractScore(String s) {
    final normalized = _normalizeDigits(s);
    // Prefer an explicit "X/10" pattern — bare numbers elsewhere in the
    // summary (distances, people counts) can otherwise be picked up by
    // mistake, and "/10" itself would wrongly extract 10 instead of the
    // actual score before it.
    final ratio = RegExp(r'(\d{1,2})\s*/\s*10').firstMatch(normalized);
    final m = ratio ?? RegExp(r'\b(\d{1,2})\b').firstMatch(normalized);
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!);
    if (n == null) return null;
    return n.clamp(1, 10);
  }

  String _normalizeDigits(String s) =>
      s.split('').map((c) => _bengaliToAscii[c] ?? c).join();
}