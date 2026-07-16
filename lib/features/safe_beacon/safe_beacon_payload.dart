import 'dart:convert';

import '../mesh_comm/sos_payload.dart';

/// "I'm safe" beacon payload. Reuses the [SosPayload] wire format
/// so the relay engine handles it the same way, but distinguishes
/// safe beacons from SOS by the [state] field.
///
/// Receivers look at [state] to decide how to render the bubble
/// (safe = green check, SOS = red emergency).
class SafeBeaconPayload {
  static const String safeState = 'safe';

  final String id;
  final String originName;
  final String originPhone;
  final double lat;
  final double lon;
  final DateTime timestamp;
  final int hopCount;
  final List<String> hops;
  final String state;

  const SafeBeaconPayload({
    required this.id,
    required this.originName,
    required this.originPhone,
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.hopCount,
    required this.hops,
    this.state = safeState,
  });

  /// Convert to a [SosPayload] for wire compatibility. The SOS
  /// relay engine doesn't care about the message text — it
  /// de-dupes by [id].
  SosPayload toSosPayload({String message = 'নিরাপদ — আমি ভালো আছি'}) {
    return SosPayload(
      id: id,
      originName: originName,
      originPhone: originPhone,
      message: message,
      lat: lat,
      lon: lon,
      timestamp: timestamp,
      hopCount: hopCount,
      hops: hops,
    );
  }

  String encode() => jsonEncode({
        'id': id,
        'originName': originName,
        'originPhone': originPhone,
        'lat': lat,
        'lon': lon,
        'timestamp': timestamp.toIso8601String(),
        'hopCount': hopCount,
        'hops': hops,
        'state': state,
      });

  static SafeBeaconPayload decode(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return SafeBeaconPayload(
      id: m['id'] as String,
      originName: m['originName'] as String,
      originPhone: m['originPhone'] as String,
      lat: (m['lat'] as num).toDouble(),
      lon: (m['lon'] as num).toDouble(),
      timestamp: DateTime.parse(m['timestamp'] as String),
      hopCount: m['hopCount'] as int,
      hops: (m['hops'] as List).cast<String>(),
      state: (m['state'] as String?) ?? safeState,
    );
  }
}