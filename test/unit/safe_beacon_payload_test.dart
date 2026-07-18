import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/safe_beacon/safe_beacon_payload.dart';

void main() {
  group('SafeBeaconPayload', () {
    test('encodes to JSON with state=safe by default', () {
      final p = SafeBeaconPayload(
        id: 'beacon-1',
        originName: 'আমি',
        originPhone: '০১XXXXXXXXX',
        lat: 23.81,
        lon: 90.41,
        timestamp: DateTime.utc(2026, 7, 16, 10, 30),
        hopCount: 0,
        hops: const [],
      );
      final encoded = p.encode();
      expect(encoded, contains('"id":"beacon-1"'));
      expect(encoded, contains('"state":"safe"'));
      expect(encoded, contains('"lat":23.81'));
      expect(encoded, contains('"lon":90.41'));
    });

    test('round-trips through encode/decode', () {
      final original = SafeBeaconPayload(
        id: 'beacon-2',
        originName: 'ব্যক্তি-২',
        originPhone: '০১XXXXXXXXX',
        lat: 22.0,
        lon: 91.0,
        timestamp: DateTime.utc(2026, 7, 16, 12, 0),
        hopCount: 1,
        hops: const ['phone-b'],
      );
      final encoded = original.encode();
      final decoded = SafeBeaconPayload.decode(encoded);
      expect(decoded.id, original.id);
      expect(decoded.originName, original.originName);
      expect(decoded.lat, original.lat);
      expect(decoded.lon, original.lon);
      expect(decoded.hopCount, 1);
      expect(decoded.hops, ['phone-b']);
      expect(decoded.state, 'safe');
    });

    test('decodes default state as safe when missing', () {
      // Manually craft a JSON without state field.
      final encoded = '{"id":"b3","originName":"a","originPhone":"p",'
          '"lat":0.0,"lon":0.0,"timestamp":"2026-07-16T00:00:00.000Z",'
          '"hopCount":0,"hops":[]}';
      final p = SafeBeaconPayload.decode(encoded);
      expect(p.state, 'safe');
    });

    test('toSosPayload wraps with safe message', () {
      final p = SafeBeaconPayload(
        id: 'b4',
        originName: 'আমি',
        originPhone: 'p',
        lat: 23.0,
        lon: 90.0,
        timestamp: DateTime.utc(2026, 7, 16),
        hopCount: 0,
        hops: const [],
      );
      final sos = p.toSosPayload();
      expect(sos.message, 'নিরাপদ — আমি ভালো আছি');
      expect(sos.id, 'b4');
    });

    test('encode handles hop history', () {
      final p = SafeBeaconPayload(
        id: 'b5',
        originName: 'a',
        originPhone: 'p',
        lat: 0.0,
        lon: 0.0,
        timestamp: DateTime.utc(2026, 7, 16),
        hopCount: 3,
        hops: const ['a', 'b', 'c'],
      );
      final encoded = p.encode();
      expect(encoded, contains('"hopCount":3'));
      expect(encoded, contains('"a","b","c"'));
    });
  });
}