import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/nearest_shelter.dart';
import 'package:shongjog/features/shelter/shelter_model.dart';

void main() {
  group('nearestShelters', () {
    test('returns closest shelter by haversine distance', () {
      final s = [
        const Shelter(
            name: 'A', nameBn: 'A', lat: 23.8, lon: 90.4, source: 'x'),
        const Shelter(
            name: 'B', nameBn: 'B', lat: 22.7, lon: 89.5, source: 'x'),
      ];
      final near = nearestShelters(lat: 23.81, lon: 90.41, all: s, k: 1);
      expect(near.length, 1);
      expect(near.first.shelter.name, 'A');
      // ~1.1 km — sanity check the distance is plausible.
      expect(near.first.km, lessThan(20));
      expect(near.first.km, greaterThan(0));
    });

    test('returns sorted by distance ascending', () {
      final s = [
        const Shelter(
            name: 'far', nameBn: 'f', lat: 24.0, lon: 91.0, source: 'x'),
        const Shelter(
            name: 'near', nameBn: 'n', lat: 23.81, lon: 90.41, source: 'x'),
        const Shelter(
            name: 'mid', nameBn: 'm', lat: 23.9, lon: 90.7, source: 'x'),
      ];
      final ranked = nearestShelters(lat: 23.8, lon: 90.4, all: s, k: 3);
      expect(ranked.map((r) => r.shelter.name).toList(),
          ['near', 'mid', 'far']);
      // Distances must be non-decreasing.
      for (int i = 1; i < ranked.length; i++) {
        expect(ranked[i].km, greaterThanOrEqualTo(ranked[i - 1].km));
      }
    });

    test('k clamps to available shelters', () {
      final s = [
        const Shelter(
            name: 'A', nameBn: 'A', lat: 23.8, lon: 90.4, source: 'x'),
      ];
      final ranked = nearestShelters(lat: 23.8, lon: 90.4, all: s, k: 10);
      expect(ranked.length, 1);
      expect(ranked.first.km, closeTo(0, 0.01));
    });

    test('zero distance when at the exact shelter location', () {
      const s = Shelter(
          name: 'X', nameBn: 'X', lat: 23.8, lon: 90.4, source: 'x');
      final ranked =
          nearestShelters(lat: 23.8, lon: 90.4, all: const [s], k: 1);
      expect(ranked.first.km, closeTo(0, 0.001));
    });
  });
}