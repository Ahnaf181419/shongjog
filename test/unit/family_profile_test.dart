import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/features/planner/family_profile.dart';

void main() {
  // SharedPreferences uses a mock in test mode automatically.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FamilyProfile', () {
    test('defaults are sensible for a fresh install', () {
      const p = FamilyProfile.empty;
      expect(p.familySize, 0);
      expect(p.childrenCount, 0);
      expect(p.elderlyCount, 0);
      expect(p.hasPets, isFalse);
      expect(p.homeType, HomeType.unknown);
      expect(p.medicalConditions, isEmpty);
      expect(p.nearbyRiver, isFalse);
      expect(p.nearbyCoast, isFalse);
    });

    test('toJson / fromJson round-trip preserves all fields', () {
      const original = FamilyProfile(
        familySize: 5,
        childrenCount: 2,
        elderlyCount: 1,
        hasPets: true,
        homeType: HomeType.tinShed,
        floorNumber: 2,
        medicalConditions: ['ডায়াবেটিস', 'হাঁপানি'],
        nearbyRiver: true,
        nearbyCoast: false,
      );
      final json = original.toJson();
      final restored = FamilyProfile.fromJson(json);
      expect(restored.familySize, 5);
      expect(restored.childrenCount, 2);
      expect(restored.elderlyCount, 1);
      expect(restored.hasPets, isTrue);
      expect(restored.homeType, HomeType.tinShed);
      expect(restored.floorNumber, 2);
      expect(restored.medicalConditions, ['ডায়াবেটিস', 'হাঁপানি']);
      expect(restored.nearbyRiver, isTrue);
      expect(restored.nearbyCoast, isFalse);
    });

    test('isEmpty is true for a fresh profile', () {
      expect(FamilyProfile.empty.isEmpty, isTrue);
    });

    test('isEmpty is false when familySize > 0', () {
      const p = FamilyProfile(familySize: 1);
      expect(p.isEmpty, isFalse);
    });

    test('save then load round-trips through SharedPreferences', () async {
      const original = FamilyProfile(
        familySize: 4,
        childrenCount: 1,
        elderlyCount: 0,
        hasPets: false,
        homeType: HomeType.pucka,
        floorNumber: 3,
        medicalConditions: ['উচ্চ রক্তচাপ'],
        nearbyRiver: false,
        nearbyCoast: true,
      );
      await FamilyProfile.save(original);
      final loaded = await FamilyProfile.load();
      expect(loaded.familySize, 4);
      expect(loaded.childrenCount, 1);
      expect(loaded.homeType, HomeType.pucka);
      expect(loaded.medicalConditions, ['উচ্চ রক্তচাপ']);
      expect(loaded.nearbyCoast, isTrue);
    });

    test('save with empty profile clears all keys', () async {
      const filled = FamilyProfile(familySize: 5);
      await FamilyProfile.save(filled);
      var loaded = await FamilyProfile.load();
      expect(loaded.familySize, 5);
      // Save empty — should clear.
      await FamilyProfile.save(FamilyProfile.empty);
      loaded = await FamilyProfile.load();
      expect(loaded.isEmpty, isTrue);
    });
  });

  group('HomeType', () {
    test('labelBn returns Bangla for each type', () {
      expect(HomeType.tinShed.labelBn, isNotEmpty);
      expect(HomeType.pucka.labelBn, isNotEmpty);
      expect(HomeType.apartment.labelBn, isNotEmpty);
    });

    test('fromString parses the Bangla label back', () {
      for (final t in HomeType.values) {
        if (t == HomeType.unknown) continue;
        expect(HomeType.fromString(t.labelBn), t);
      }
    });

    test('fromString returns unknown for garbage', () {
      expect(HomeType.fromString('xyz'), HomeType.unknown);
    });
  });
}
