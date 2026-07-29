import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'shelter_model.dart';

/// Loads shelters from the bundled GeoJSON asset.
///
/// Coordinates in GeoJSON are `[lon, lat]` per the spec; the loader maps
/// them to `Shelter(lat: coords[1], lon: coords[0])` (docs/architecture.md §7).
///
/// Each feature is parsed in isolation: a single malformed row (non-Point
/// geometry, missing coordinate, unexpected nesting) is logged and skipped
/// rather than poisoning the whole list — the map's primary layer must
/// survive a bad row.
class ShelterRepository {
  Future<List<Shelter>> loadAll() async {
    final raw =
        await rootBundle.loadString('assets/shelter/cyclone_shelters.geojson');
    return parseGeoJson(raw);
  }

  /// Pure parser shared with tests so they exercise the real parsing
  /// path instead of re-implementing it. Throws [FormatException] on
  /// malformed JSON; a bad feature row is logged and skipped.
  static List<Shelter> parseGeoJson(String raw) {
    final gj = jsonDecode(raw) as Map<String, dynamic>;
    final features = gj['features'] as List;
    final results = <Shelter>[];
    for (final f in features) {
      try {
        final p =
            (f as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
        final g = f['geometry'] as Map<String, dynamic>;
        final coords = (g['coordinates'] as List).cast<num>();
        if (coords.length < 2) {
          throw FormatException('Point has < 2 coordinates: $coords');
        }
        results.add(Shelter(
          id: p['id']?.toString(),
          division: p['division']?.toString(),
          district: p['district']?.toString(),
          name: p['name']?.toString() ?? '',
          nameBn: p['name_bn']?.toString() ?? '',
          lat: coords[1].toDouble(),
          lon: coords[0].toDouble(),
          capacity: (p['capacity'] as num?)?.toInt(),
          type: p['type']?.toString() ?? 'multi',
          source: p['source']?.toString() ?? 'OSM',
        ));
      } catch (e) {
        debugPrint('[ShelterRepository] skipped malformed feature: $e');
      }
    }
    return results;
  }
}