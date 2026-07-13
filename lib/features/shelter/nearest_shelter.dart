import 'dart:math';

import 'shelter_model.dart';

/// A shelter ranked by haversine distance from a reference point.
class RankedShelter {
  final Shelter shelter;
  final double km;
  const RankedShelter(this.shelter, this.km);
}

const _earthRadiusKm = 6371.0;

double _radians(double deg) => deg * pi / 180.0;

/// Haversine great-circle distance in kilometers.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_radians(lat1)) * cos(_radians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * _earthRadiusKm * asin(sqrt(a));
}

/// Return the [k] nearest shelters to (lat, lon), sorted ascending by km.
/// Clamps k to the number of available shelters.
List<RankedShelter> nearestShelters({
  required double lat,
  required double lon,
  required List<Shelter> all,
  int k = 3,
}) {
  final ranked = all
      .map((s) => RankedShelter(s, haversineKm(lat, lon, s.lat, s.lon)))
      .toList()
    ..sort((a, b) => a.km.compareTo(b.km));
  return ranked.take(k).toList();
}