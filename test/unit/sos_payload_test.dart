import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/sos_payload.dart';

void main() {
  test('encode then decode round-trips all fields', () {
    final p = SosPayload(
      id: 'abc-123',
      originName: 'Ahnaf',
      originPhone: '+8801700000000',
      message: 'পানি উঠে গেছে, ছাদে আছি',
      lat: 22.33,
      lon: 91.81,
      timestamp: DateTime.utc(2026, 7, 16, 10, 0),
      hopCount: 0,
      hops: ['Ahnaf'],
    );
    final encoded = p.encode();
    final decoded = SosPayload.decode(encoded);
    expect(decoded, equals(p));
  });

  test('hop count is incremented on relay', () {
    final p = SosPayload(
      id: 'x',
      originName: 'A',
      originPhone: '',
      message: '',
      lat: 0,
      lon: 0,
      timestamp: DateTime.utc(2026, 7, 16),
      hopCount: 0,
      hops: ['A'],
    );
    final relayed = p.relayFrom('B');
    expect(relayed.hopCount, 1);
    expect(relayed.hops, ['A', 'B']);
  });

  test('rejects payload past max hops', () {
    final p = SosPayload(
      id: 'x',
      originName: 'A',
      originPhone: '',
      message: '',
      lat: 0,
      lon: 0,
      timestamp: DateTime.utc(2026, 7, 16),
      hopCount: 5,
      hops: List.filled(5, 'x'),
    );
    expect(p.canRelay, isFalse);
  });
}
