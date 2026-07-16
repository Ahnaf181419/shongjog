import 'dart:convert';

/// SOS message format broadcast over the mesh.
///
/// `id` is a UUID generated on the origin device. Receivers
/// de-dupe by `id`. `hops` is the ordered list of device names
/// that have relayed this message; `hopCount == hops.length`.
class SosPayload {
  static const int maxHops = 5;

  final String id;
  final String originName;
  final String originPhone;
  final String message;
  final double lat;
  final double lon;
  final DateTime timestamp;
  final int hopCount;
  final List<String> hops;

  SosPayload({
    required this.id,
    required this.originName,
    required this.originPhone,
    required this.message,
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.hopCount,
    required this.hops,
  });

  @override
  bool operator ==(Object other) =>
      other is SosPayload &&
      other.id == id &&
      other.originName == originName &&
      other.originPhone == originPhone &&
      other.message == message &&
      other.lat == lat &&
      other.lon == lon &&
      other.timestamp == timestamp &&
      other.hopCount == hopCount &&
      _listEq(other.hops, hops);

  @override
  int get hashCode => Object.hash(
        id, originName, originPhone, message,
        lat, lon, timestamp, hopCount, Object.hashAll(hops),
      );

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool get canRelay => hopCount < maxHops;

  SosPayload relayFrom(String fromDevice) {
    if (!canRelay) {
      throw StateError('Cannot relay past max hops');
    }
    return SosPayload(
      id: id,
      originName: originName,
      originPhone: originPhone,
      message: message,
      lat: lat,
      lon: lon,
      timestamp: timestamp,
      hopCount: hopCount + 1,
      hops: [...hops, fromDevice],
    );
  }

  String encode() => jsonEncode({
        'id': id,
        'originName': originName,
        'originPhone': originPhone,
        'message': message,
        'lat': lat,
        'lon': lon,
        'timestamp': timestamp.toIso8601String(),
        'hopCount': hopCount,
        'hops': hops,
      });

  static SosPayload decode(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return SosPayload(
      id: m['id'] as String,
      originName: m['originName'] as String,
      originPhone: m['originPhone'] as String,
      message: m['message'] as String,
      lat: (m['lat'] as num).toDouble(),
      lon: (m['lon'] as num).toDouble(),
      timestamp: DateTime.parse(m['timestamp'] as String),
      hopCount: m['hopCount'] as int,
      hops: (m['hops'] as List).cast<String>(),
    );
  }
}
