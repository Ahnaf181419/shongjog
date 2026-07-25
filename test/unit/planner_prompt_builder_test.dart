import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/planner/family_profile.dart';
import 'package:shongjog/features/planner/planner_prompt_builder.dart';

void main() {
  group('PlannerPromptBuilder.buildPlan', () {
    test('returns null for an empty profile', () {
      expect(PlannerPromptBuilder.buildPlan(FamilyProfile.empty), isNull);
    });

    test('includes family size + home type + vulnerable members', () {
      const profile = FamilyProfile(
        familySize: 5,
        childrenCount: 2,
        elderlyCount: 1,
        hasPets: true,
        homeType: HomeType.tinShed,
        nearbyRiver: true,
      );
      final prompt = PlannerPromptBuilder.buildPlan(profile);
      expect(prompt, isNotNull);
      // Bangla instruction.
      expect(prompt!, contains('বাংলা'));
      // Structured data is in the prompt.
      expect(prompt, contains('5'));
      expect(prompt, contains('টিনের ঘর'));
      expect(prompt, contains('নদী'));
    });

    test('mentions medical conditions when present', () {
      const profile = FamilyProfile(
        familySize: 3,
        medicalConditions: ['ডায়াবেটিস'],
      );
      final prompt = PlannerPromptBuilder.buildPlan(profile);
      expect(prompt, isNotNull);
      expect(prompt!, contains('ডায়াবেটিস'));
    });

    test('mentions coast when nearbyCoast is true', () {
      const profile = FamilyProfile(
        familySize: 2,
        nearbyCoast: true,
      );
      final prompt = PlannerPromptBuilder.buildPlan(profile);
      expect(prompt, isNotNull);
      expect(prompt!, contains('সমুদ্র'));
    });

    test('mentions floor number for apartments', () {
      const profile = FamilyProfile(
        familySize: 3,
        homeType: HomeType.apartment,
        floorNumber: 5,
      );
      final prompt = PlannerPromptBuilder.buildPlan(profile);
      expect(prompt, isNotNull);
      expect(prompt!, contains('5'));
      expect(prompt, contains('ফ্ল্যাট'));
    });
  });

  group('PlannerPromptBuilder.fallbackPlan', () {
    test('returns a useful generic plan for any profile', () {
      const profile = FamilyProfile(familySize: 4);
      final plan = PlannerPromptBuilder.fallbackPlan(profile);
      expect(plan, isNotEmpty);
      expect(plan, contains('শূন্যস্থান'));
      expect(plan, contains('৯৯৯'));
    });

    test('includes children-specific advice when children present', () {
      const profile = FamilyProfile(familySize: 3, childrenCount: 2);
      final plan = PlannerPromptBuilder.fallbackPlan(profile);
      expect(plan, contains('শিশু'));
    });

    test('includes elderly-specific advice when elderly present', () {
      const profile = FamilyProfile(familySize: 3, elderlyCount: 1);
      final plan = PlannerPromptBuilder.fallbackPlan(profile);
      expect(plan, contains('প্রবীণ'));
    });
  });
}
