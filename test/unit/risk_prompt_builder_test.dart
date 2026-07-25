import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/planner/risk_prompt_builder.dart';

void main() {
  group('RiskPromptBuilder.buildPrompt', () {
    test('null for all-empty inputs', () {
      expect(RiskPromptBuilder.buildPrompt(RiskInputs.empty), isNull);
    });

    test('includes home material + flood history in the prompt', () {
      const r = RiskInputs(
        homeMaterial: HomeMaterial.tinShed,
        previousFloods: FloodHistory.major,
        elevation: Elevation.low,
        nearRiver: true,
        nearCoast: false,
        hasElderly: true,
        hasInfants: false,
      );
      final prompt = RiskPromptBuilder.buildPrompt(r);
      expect(prompt, isNotNull);
      expect(prompt!, contains('টিনের ঘর'));
      expect(prompt, contains('প্রধান'));
      expect(prompt, contains('নিচু'));
      expect(prompt, contains('নদী'));
      expect(prompt, contains('প্রবীণ'));
    });

    test('includes coast hint when near coast', () {
      const r = RiskInputs(
        homeMaterial: HomeMaterial.pucka,
        elevation: Elevation.mid,
        nearCoast: true,
      );
      final prompt = RiskPromptBuilder.buildPrompt(r);
      expect(prompt, isNotNull);
      expect(prompt!, contains('সমুদ্র'));
    });
  });

  group('RiskPromptBuilder.fallbackScore', () {
    test('high risk for tin-shed + low elevation + major floods + river',
        () {
      const r = RiskInputs(
        homeMaterial: HomeMaterial.tinShed,
        previousFloods: FloodHistory.major,
        elevation: Elevation.low,
        nearRiver: true,
      );
      final result = RiskPromptBuilder.fallbackScore(r);
      expect(result.score, greaterThanOrEqualTo(8));
      expect(result.summary, isNotEmpty);
    });

    test('low risk for pucka + high elevation + no flood history', () {
      const r = RiskInputs(
        homeMaterial: HomeMaterial.pucka,
        elevation: Elevation.high,
        previousFloods: FloodHistory.none,
        nearRiver: false,
        nearCoast: false,
      );
      final result = RiskPromptBuilder.fallbackScore(r);
      expect(result.score, lessThanOrEqualTo(3));
    });

    test('score is always between 1 and 10', () {
      for (final hm in HomeMaterial.values) {
        for (final elev in Elevation.values) {
          final r = RiskInputs(homeMaterial: hm, elevation: elev);
          final s = RiskPromptBuilder.fallbackScore(r).score;
          expect(s, inInclusiveRange(1, 10));
        }
      }
    });
  });
}