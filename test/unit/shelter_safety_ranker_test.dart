import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/nearest_shelter.dart';
import 'package:shongjog/features/shelter/shelter_model.dart';
import 'package:shongjog/features/shelter/shelter_safety_ranker.dart';
import 'package:shongjog/features/hazards/eonet_service.dart';
import 'package:shongjog/features/hazards/gdacs_service.dart';

void main() {
  // Three shelters ranked by distance from (0, 0).
  final candidates = [
    RankedShelter(
      const Shelter(name: 'Near', nameBn: 'কাছের', lat: 0.01, lon: 0.01, capacity: 500, source: 't'),
      1.0,
    ),
    RankedShelter(
      const Shelter(name: 'Mid', nameBn: 'মাঝারি', lat: 0.1, lon: 0.1, capacity: 1000, source: 't'),
      10.0,
    ),
    RankedShelter(
      const Shelter(name: 'Far', nameBn: 'দূরের', lat: 0.5, lon: 0.5, capacity: 2000, source: 't'),
      50.0,
    ),
  ];

  group('ShelterSafetyRanker.buildPrompt', () {
    test('returns null when there are no hazards', () {
      final prompt = ShelterSafetyRanker.buildPrompt(
        userLat: 0,
        userLon: 0,
        candidates: candidates,
      );
      expect(prompt, isNull,
          reason: 'No hazards → distance ranking is correct, no model call needed.');
    });

    test('returns null when there is only one candidate', () {
      final prompt = ShelterSafetyRanker.buildPrompt(
        userLat: 0,
        userLon: 0,
        candidates: [candidates.first],
        hazards: [_makeEonet()],
      );
      expect(prompt, isNull);
    });

    test('builds a prompt with shelters + hazards when both are present', () {
      final prompt = ShelterSafetyRanker.buildPrompt(
        userLat: 0,
        userLon: 0,
        candidates: candidates,
        hazards: [_makeEonet()],
      );
      expect(prompt, isNotNull);
      expect(prompt!, contains('Shelters'));
      expect(prompt, contains('কাছের'));
      expect(prompt, contains('JSON array'));
    });

    test('includes GDACS alerts in the prompt when provided', () {
      final prompt = ShelterSafetyRanker.buildPrompt(
        userLat: 0,
        userLon: 0,
        candidates: candidates,
        alerts: [_makeGdacs()],
      );
      expect(prompt, isNotNull);
      expect(prompt!, contains('GDACS'));
    });
  });

  group('ShelterSafetyRanker.parseResponse', () {
    test('parses a clean JSON array re-ordering', () {
      // Reverse the order: Far, Mid, Near.
      final result = ShelterSafetyRanker.parseResponse('[2, 1, 0]', candidates);
      expect(result, isNotNull);
      expect(result!.first.shelter.name, 'Far');
      expect(result.last.shelter.name, 'Near');
    });

    test('parses a JSON array wrapped in markdown fences', () {
      final result = ShelterSafetyRanker.parseResponse(
          '```json\n[1, 0, 2]\n```', candidates);
      expect(result, isNotNull);
      expect(result!.first.shelter.name, 'Mid');
    });

    test('returns null for an incomplete permutation (missing index)', () {
      final result = ShelterSafetyRanker.parseResponse('[2, 0]', candidates);
      expect(result, isNull,
          reason: 'A partial re-order loses shelters; keep distance ranking.');
    });

    test('returns null for a duplicate index', () {
      final result = ShelterSafetyRanker.parseResponse('[0, 0, 1]', candidates);
      expect(result, isNull);
    });

    test('returns null for an out-of-range index', () {
      final result = ShelterSafetyRanker.parseResponse('[0, 1, 5]', candidates);
      expect(result, isNull);
    });

    test('returns null for non-JSON garbage', () {
      final result = ShelterSafetyRanker.parseResponse('I cannot help with that.', candidates);
      expect(result, isNull);
    });

    test('returns null for an empty response', () {
      final result = ShelterSafetyRanker.parseResponse('', candidates);
      expect(result, isNull);
    });
  });
}

EonetEvent _makeEonet() => EonetEvent(
      id: 'test',
      title: 'Test cyclone',
      category: EonetCategory.severeStorms,
      latitude: 0.5,
      longitude: 0.5,
    );

GdacsAlert _makeGdacs() => const GdacsAlert(
      title: 'Test flood alert',
      latitude: 0.5,
      longitude: 0.5,
      severity: GdacsSeverity.orange,
    );
