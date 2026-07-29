import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/features/shelter/shelter_model.dart';
import 'package:shongjog/features/shelter/shelter_repository.dart';

void main() {
  group('ShelterRepository.parseGeoJson', () {
    test('parses a canonical GeoJSON FeatureCollection', () {
      // Mimics the real assets/shelter/cyclone_shelters.geojson layout:
      // features.geometry.coordinates are [lon, lat] per the spec.
      final raw = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [89.55, 22.85],
            },
            'properties': {
              'id': 'bd-shelter-khulna-001',
              'division': 'khulna',
              'district': 'খুলনা',
              'name': 'Khulna Shelter A',
              'name_bn': 'খুলনা শেল্টার এ',
              'capacity': 1200,
              'type': 'cyclone',
              'source': 'MoDMR',
            },
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [90.40, 22.70],
            },
            'properties': {
              'name': 'Barisal Cyclone Shelter',
              'name_bn': 'বরিশাল সাইক্লোন শেল্টার',
              'capacity': 800,
              'source': 'MoDMR',
            },
          },
        ],
      });

      final shelters = ShelterRepository.parseGeoJson(raw);

      expect(shelters, hasLength(2));
      expect(
          shelters[0],
          const Shelter(
            id: 'bd-shelter-khulna-001',
            division: 'khulna',
            district: 'খুলনা',
            name: 'Khulna Shelter A',
            nameBn: 'খুলনা শেল্টার এ',
            lat: 22.85,
            lon: 89.55,
            capacity: 1200,
            type: 'cyclone',
            source: 'MoDMR',
          ));
      expect(shelters[0].lat, 22.85, reason: 'coords[1] is lat');
      expect(shelters[0].lon, 89.55, reason: 'coords[0] is lon');
      expect(shelters[1].nameBn, 'বরিশাল সাইক্লোন শেল্টার');
      // Second record omits the new fields -> defaults apply.
      expect(shelters[1].id, isNull);
      expect(shelters[1].division, isNull);
      expect(shelters[1].district, isNull);
      expect(shelters[1].type, 'multi',
          reason: 'missing type defaults to multi');
    });

    test('defaults missing capacity to null', () {
      final raw = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [89.0, 23.0],
            },
            'properties': {
              'name': 'NoCapacity',
              'name_bn': '',
              'source': 'OSM',
            },
          },
        ],
      });

      final shelters = ShelterRepository.parseGeoJson(raw);
      expect(shelters, hasLength(1));
      expect(shelters.first.capacity, isNull);
    });

    test('defaults missing source to "OSM"', () {
      final raw = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [89.0, 23.0],
            },
            'properties': {
              'name': 'NoSource',
              'name_bn': '',
              'capacity': 100,
            },
          },
        ],
      });

      final shelters = ShelterRepository.parseGeoJson(raw);
      expect(shelters.first.source, 'OSM');
    });

    test('throws FormatException on malformed JSON', () {
      final raw = '{not valid json';
      expect(
        () => ShelterRepository.parseGeoJson(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('skips a single malformed feature, keeps the rest', () {
      // One good feature, one with a non-Point / missing coordinates.
      // The loader must log + skip the bad row and still return the good
      // one — the map's primary layer survives a bad row.
      final raw = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [90.0, 24.0],
            },
            'properties': {
              'name': 'Good',
              'name_bn': 'ভালো',
              'source': 'MoDMR',
            },
          },
          {
            'type': 'Feature',
            'geometry': {'type': 'Point', 'coordinates': []},
            'properties': {
              'name': 'Bad',
              'name_bn': '',
              'source': 'OSM',
            },
          },
        ],
      });

      final shelters = ShelterRepository.parseGeoJson(raw);
      expect(shelters, hasLength(1));
      expect(shelters.single.name, 'Good');
    });
  });

  test('Shelter ==, hashCode, toString', () {
    const a = Shelter(
      name: 'A',
      nameBn: 'এ',
      lat: 23.0,
      lon: 90.0,
      capacity: 100,
      source: 'OSM',
    );
    const b = Shelter(
      name: 'A',
      nameBn: 'এ',
      lat: 23.0,
      lon: 90.0,
      capacity: 100,
      source: 'OSM',
    );
    const c = Shelter(
      name: 'B',
      nameBn: 'বি',
      lat: 22.0,
      lon: 89.0,
      capacity: 50,
      source: 'MoDMR',
    );

    expect(a, equals(b));
    expect(b, isNot(equals(c)));
    expect(a.hashCode, equals(b.hashCode));
    // `a` and `b` are intentionally equal — verifying set dedupe.
    // ignore: equal_elements_in_set
    final setLiteral = <Shelter>{a, b, c};
    expect(setLiteral, hasLength(2));
    expect(a.toString(), contains('A'),
        reason: 'toString surfaces field names for debuggability');
    // toString surfaces the new fields too.
    expect(a.toString(), contains('type: multi'));
    expect(a.toString(), contains('division: null'));
  });
}
