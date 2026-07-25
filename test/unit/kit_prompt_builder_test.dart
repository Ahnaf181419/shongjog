import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/planner/family_profile.dart';
import 'package:shongjog/features/planner/kit_prompt_builder.dart';

void main() {
  group('KitPromptBuilder.buildPrompt', () {
    test('returns null for empty profile', () {
      expect(KitPromptBuilder.buildPrompt(FamilyProfile.empty), isNull);
    });

    test('includes infant formula suggestion when children present', () {
      const p = FamilyProfile(familySize: 3, childrenCount: 2);
      final prompt = KitPromptBuilder.buildPrompt(p);
      expect(prompt, isNotNull);
      expect(prompt!, contains('শিশু'));
    });

    test('includes elderly medicine reminder when elderly present', () {
      const p = FamilyProfile(familySize: 3, elderlyCount: 1);
      final prompt = KitPromptBuilder.buildPrompt(p);
      expect(prompt, isNotNull);
      expect(prompt!, contains('প্রবীণ'));
    });

    test('includes pet supplies when hasPets', () {
      const p = FamilyProfile(familySize: 2, hasPets: true);
      final prompt = KitPromptBuilder.buildPrompt(p);
      expect(prompt, isNotNull);
      expect(prompt!, contains('পোষা'));
    });

    test('includes diabetes supply hint when medical condition', () {
      const p = FamilyProfile(
          familySize: 2, medicalConditions: ['ডায়াবেটিস']);
      final prompt = KitPromptBuilder.buildPrompt(p);
      expect(prompt, isNotNull);
      expect(prompt!, contains('ডায়াবেটিস'));
    });
  });

  group('KitPromptBuilder.fallbackKit', () {
    test('returns a useful generic kit for any profile', () {
      const p = FamilyProfile(familySize: 2);
      final kit = KitPromptBuilder.fallbackKit(p);
      expect(kit, contains('পানি'));
      expect(kit, contains('খাবার'));
      expect(kit, contains('ফ্ল্যাশলাইট'));
    });

    test('scales water quantity with family size', () {
      const p = FamilyProfile(familySize: 6);
      final kit = KitPromptBuilder.fallbackKit(p);
      // 6 × 3 = 18 litres/day.
      expect(kit, contains('১৮'));
    });

    test('adds pet food line when pets present', () {
      const p = FamilyProfile(familySize: 2, hasPets: true);
      final kit = KitPromptBuilder.fallbackKit(p);
      expect(kit, contains('পোষা'));
    });
  });
}