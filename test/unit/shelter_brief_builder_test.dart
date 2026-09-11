import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/nearest_shelter.dart';
import 'package:shongjog/features/shelter/shelter_model.dart';
import 'package:shongjog/features/shelter/shelter_brief_builder.dart';
import 'package:shongjog/features/shelter/shelter_strings_loader.dart';
import 'package:shongjog/features/hazards/eonet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShelterStrings bnShelterStrings;
  setUpAll(() async {
    bnShelterStrings = await loadShelterStrings('bn');
  });
  final shelter = RankedShelter(
    const Shelter(
        name: 'Test',
        nameBn: 'টেস্ট শেল্টার',
        lat: 23.8,
        lon: 90.4,
        capacity: 1200,
        source: 't'),
    3.5,
  );

  group('ShelterBriefBuilder.buildPrompt', () {
    test('returns null when user position is missing', () {
      final p = ShelterBriefBuilder.buildPrompt(
        userLat: null,
        userLon: null,
        shelter: shelter,
        s: bnShelterStrings,
      );
      expect(p, isNull);
    });

    test('returns null when shelter is null', () {
      final p = ShelterBriefBuilder.buildPrompt(
        userLat: 23.0,
        userLon: 90.0,
        shelter: null,
        s: bnShelterStrings,
      );
      expect(p, isNull);
    });

    test('builds a prompt with shelter name + distance + capacity', () {
      final p = ShelterBriefBuilder.buildPrompt(
        userLat: 23.0,
        userLon: 90.0,
        shelter: shelter,
        s: bnShelterStrings,
      );
      expect(p, isNotNull);
      expect(p!, contains('টেস্ট শেল্টার'));
      // The prompt feeds the model — ASCII digits are fine here.
      // The model is instructed to output Bengali numerals.
      expect(p, contains('3.5'));
      expect(p, contains('1200'));
      expect(p, contains('Bangla'));
    });

    test('includes hazards when provided', () {
      final p = ShelterBriefBuilder.buildPrompt(
        userLat: 23.0,
        userLon: 90.0,
        shelter: shelter,
        hazards: [
          EonetEvent(
            id: 'x',
            title: 'Cyclone Mocha',
            category: EonetCategory.severeStorms,
            latitude: 22.0,
            longitude: 91.0,
          ),
        ],
        s: bnShelterStrings,
      );
      expect(p, isNotNull);
      expect(p!, contains('ঘূর্ণিঝড়'));
      expect(p, contains('Cyclone Mocha'));
    });
  });

  group('ShelterBriefBuilder.fallbackBrief', () {
    test('returns a useful sentence with name + distance', () {
      final brief = ShelterBriefBuilder.fallbackBrief(shelter: shelter, s: bnShelterStrings);
      expect(brief, contains('টেস্ট শেল্টার'));
      expect(brief, contains('৩.৫'));
      expect(brief, contains('কিমি'));
      expect(brief, contains('১২০০'));
    });

    test('omits capacity when null', () {
      final noCap = RankedShelter(
        const Shelter(name: 'X', nameBn: 'এক্স', lat: 0, lon: 0, capacity: null, source: 't'),
        5.0,
      );
      final brief = ShelterBriefBuilder.fallbackBrief(shelter: noCap, s: bnShelterStrings);
      expect(brief, contains('এক্স'));
      expect(brief, contains('৫.০'));
      expect(brief.contains('ধারণক্ষমতা'), isFalse);
    });

    test('returns a loading message when shelter is null', () {
      final brief = ShelterBriefBuilder.fallbackBrief(shelter: null, s: bnShelterStrings);
      expect(brief, isNotEmpty);
      expect(brief, contains('লোড'));
    });

    test('uses Bengali numerals', () {
      final brief = ShelterBriefBuilder.fallbackBrief(shelter: shelter, s: bnShelterStrings);
      // Distance 3.5 → Bengali ৩.৫, capacity 1200 → ১২০০.
      expect(brief, contains('৩.৫'));
      expect(brief, contains('১২০০'));
      // Must NOT contain ASCII digits.
      expect(brief.contains(RegExp(r'[0-9]')), isFalse);
    });
  });
}
