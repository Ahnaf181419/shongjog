/// A cyclone/flood/multi-hazard shelter from the bundled GeoJSON.
///
/// Source of truth: docs/architecture.md §7 (Shelter data model). The
/// `id`, `division`, `district`, and `type` fields are populated by the
/// expanded dataset (scripts/generate_shelters.py); legacy records and
/// tests that omit them compile unchanged thanks to the defaults below.
class Shelter {
  final String name;
  final String nameBn;
  final double lat;
  final double lon;
  final int? capacity;
  final String source;

  /// Stable identifier (e.g. `bd-shelter-khulna-001`). Null for records
  /// that predate the id-bearing dataset — used for dedup and future
  /// Firestore sync.
  final String? id;

  /// Lowercase division key (`khulna`, `barishal`, `chattogram`, `dhaka`,
  /// `rajshahi`, `rangpur`, `sylhet`, `mymensingh`). Null when unknown.
  final String? division;

  /// District name in Bangla. Null when unknown.
  final String? district;

  /// Hazard type the shelter is built for: `cyclone`, `flood`, `multi`,
  /// or `earthquake`. Defaults to `multi` for legacy records.
  final String type;

  const Shelter({
    required this.name,
    required this.nameBn,
    required this.lat,
    required this.lon,
    this.capacity,
    required this.source,
    this.id,
    this.division,
    this.district,
    this.type = 'multi',
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
          other.source == source &&
          other.id == id &&
          other.division == division &&
          other.district == district &&
          other.type == type;

  @override
  int get hashCode =>
      Object.hash(name, nameBn, lat, lon, capacity, source, id, division,
          district, type);

  @override
  String toString() =>
      'Shelter(name: $name, nameBn: $nameBn, lat: $lat, lon: $lon, '
      'capacity: $capacity, source: $source, id: $id, division: $division, '
      'district: $district, type: $type)';
}
