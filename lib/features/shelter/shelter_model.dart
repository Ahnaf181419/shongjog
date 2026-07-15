/// A cyclone shelter from the bundled GeoJSON.
///
/// Source of truth: docs/architecture.md §7 (Shelter data model).
class Shelter {
  final String name;
  final String nameBn;
  final double lat;
  final double lon;
  final int? capacity;
  final String source;

  const Shelter({
    required this.name,
    required this.nameBn,
    required this.lat,
    required this.lon,
    this.capacity,
    required this.source,
  });

  /// Two shelters are equal when all fields match. Trivially-derived
  /// hashCode via `Object.hash`. Adding this makes the value usable
  /// in `Set`, `Map`, and `lookup` contexts — and pinned by tests.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shelter &&
          other.name == name &&
          other.nameBn == nameBn &&
          other.lat == lat &&
          other.lon == lon &&
          other.capacity == capacity &&
          other.source == source;

  @override
  int get hashCode =>
      Object.hash(name, nameBn, lat, lon, capacity, source);

  @override
  String toString() =>
      'Shelter(name: $name, nameBn: $nameBn, lat: $lat, lon: $lon, '
      'capacity: $capacity, source: $source)';
}
