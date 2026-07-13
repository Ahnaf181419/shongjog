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
}