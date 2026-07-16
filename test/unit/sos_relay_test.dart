import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/sos_payload.dart';
import 'package:shongjog/features/mesh_comm/sos_relay.dart';

SosPayload _p(String id, {int hops = 0, DateTime? ts}) => SosPayload(
      id: id,
      originName: 'A',
      originPhone: '',
      message: '',
      lat: 0,
      lon: 0,
      timestamp: ts ?? DateTime.now(),
      hopCount: hops,
      hops: List.filled(hops, 'x'),
    );

void main() {
  group('SosRelayEngine', () {
    test('first time a payload is seen, it should be re-broadcast', () {
      final r = SosRelayEngine(localDevice: 'me');
      final verdict = r.onReceive(_p('a'), from: 'phone-b');
      expect(verdict.shouldRelay, isTrue);
      expect(verdict.relayed, isNotNull);
      expect(verdict.relayed!.hopCount, 1);
      expect(verdict.relayed!.hops.last, 'me');
    });

    test('second time the same payload is seen, no relay', () {
      final r = SosRelayEngine(localDevice: 'me');
      r.onReceive(_p('a'), from: 'phone-b');
      final verdict = r.onReceive(_p('a'), from: 'phone-c');
      expect(verdict.shouldRelay, isFalse);
      expect(verdict.relayed, isNull);
    });

    test('payload past max hops is never re-broadcast', () {
      final r = SosRelayEngine(localDevice: 'me');
      final verdict = r.onReceive(_p('a', hops: 5), from: 'phone-b');
      expect(verdict.shouldRelay, isFalse);
    });

    test('local-originated payload is not re-broadcast back to mesh', () {
      // We sent it; we don't need to re-broadcast our own message.
      final r = SosRelayEngine(localDevice: 'me');
      final verdict = r.onReceive(
        _p('a').relayFrom('me').relayFrom('phone-b'),
        from: 'phone-c',
      );
      // After two relays, "me" is already in hops. Don't loop.
      expect(verdict.shouldRelay, isFalse);
    });

    test('TTL expiry: payload older than 1h is dropped', () {
      final r = SosRelayEngine(localDevice: 'me', ttl: Duration(hours: 1));
      final old = _p('a', ts: DateTime.now().subtract(const Duration(hours: 2)));
      final verdict = r.onReceive(old, from: 'phone-b');
      expect(verdict.shouldRelay, isFalse);
      expect(verdict.expired, isTrue);
    });
  });
}
