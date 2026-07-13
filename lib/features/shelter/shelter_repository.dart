import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'shelter_model.dart';

/// Loads cyclone shelters from the bundled GeoJSON asset.
///
/// Coordinates in GeoJSON are `[lon, lat]` per the spec; the loader maps
/// them to `Shelter(lat: coords[1], lon: coords[0])` (docs/architecture.md §7).
class ShelterRepository {
  Future<List<Shelter>> loadAll() async {
    final raw =
        await rootBundle.loadString('assets/shelter/cyclone_shelters.geojson');
    final gj = jsonDecode(raw) as Map<String, dynamic>;
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