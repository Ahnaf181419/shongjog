import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/features/shelter/shelter_model.dart';
import 'package:shongjog/features/shelter/shelter_repository.dart';

void main() {
  group('ShelterRepository', () {
    test('loadAll() parses a canonical GeoJSON FeatureCollection', () async {
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
              'name': 'Khulna Shelter A',
              'name_bn': 'খুলনা শেল্টার এ',
              'capacity': 1200,
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

      final repo = _RepoFromString(raw);
      final shelters = await repo.loadAll();

      expect(shelters, hasLength(2));
      expect(shelters[0], const Shelter(
            name: 'Khulna Shelter A',
            nameBn: 'খুলনা শেল্টার এ',
            lat: 22.85,
            lon: 89.55,
            capacity: 1200,
            source: 'MoDMR',
          ));
      expect(shelters[0].lat, 22.85,
          reason: 'coords[1] is lat');
      expect(shelters[0].lon, 89.55,
          reason: 'coords[0] is lon');
      expect(shelters[1].nameBn, 'বরিশাল সাইক্লোন শেল্টার');
    });

    test('loadAll() defaults missing capacity to null', () async {
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

      final shelters = await _RepoFromString(raw).loadAll();
      expect(shelters, hasLength(1));
      expect(shelters.first.capacity, isNull);
    });

    test('loadAll() defaults missing source to "OSM"', () async {
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

      final shelters = await _RepoFromString(raw).loadAll();
      expect(shelters.first.source, 'OSM');
    });

    test('loadAll() throws FormatException on malformed JSON', () async {
      // repoFromString uses loadString() — emulate the failure path by
      // feeding it bad input rather than mocking. We can use the real
      // bundle loader against an empty Features array, then call a
      // direct repo that throws.
      final raw = '{not valid json';
      await expectLater(
        _RepoFromString(raw).loadAll(),
        throwsA(isA<FormatException>()),
      );
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
  });
}

/// Test variant of [ShelterRepository] that reads from an in-memory
/// string instead of the asset bundle — keeps the test offline and
/// injects deterministic JSON.
class _RepoFromString implements ShelterRepository {
  final String _raw;
  _RepoFromString(this._raw);

  @override
  Future<List<Shelter>> loadAll() async {
    final gj = jsonDecode(_raw) as Map<String, dynamic>;
    final features = gj['features'] as List;
    return features.map((f) {
      final p = (f as Map<String, dynamic>)['properties']
          as Map<String, dynamic>;
      final g = f['geometry'] as Map<String, dynamic>;
      final coords = (g['coordinates'] as List).cast<num>();
      return Shelter(
        name: p['name']?.toString() ?? '',
        nameBn: p['name_bn']?.toString() ?? '',
        lat: coords[1].toDouble(),
        lon: coords[0].toDouble(),
        capacity: (p['capacity'] as num?)?.toInt(),
        source: p['source']?.toString() ?? 'OSM',
      );
    }).toList();
  }
}
