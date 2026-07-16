import 'sos_payload.dart';

class RelayVerdict {
  final bool shouldRelay;
  final bool expired;
  final SosPayload? relayed;
  const RelayVerdict.relay(SosPayload next)
      : shouldRelay = true,
        expired = false,
        relayed = next;
  const RelayVerdict.duplicate()
      : shouldRelay = false,
        expired = false,
        relayed = null;
  const RelayVerdict.exhausted()
      : shouldRelay = false,
        expired = false,
        relayed = null;
  const RelayVerdict.stale()
      : shouldRelay = false,
        expired = true,
        relayed = null;
}

/// Pure-Dart decision engine for the multi-hop SOS mesh relay.
///
/// Tracks seen `id`s (LRU-bounded to 256) and respects hop count
/// and a per-payload TTL. Safe to construct once per app session.
class SosRelayEngine {
  final String localDevice;
  final Duration ttl;
  final Set<String> _seen = <String>{};
  static const int _maxSeen = 256;

  SosRelayEngine({
    required this.localDevice,
    this.ttl = const Duration(hours: 1),
  });

  RelayVerdict onReceive(SosPayload payload, {required String from}) {
    if (DateTime.now().difference(payload.timestamp) > ttl) {
      return RelayVerdict.stale();
    }
    if (_seen.contains(payload.id)) {
      return RelayVerdict.duplicate();
    }
    if (!payload.canRelay) {
      _remember(payload.id);
      return RelayVerdict.exhausted();
    }
    // Don't loop when the local device is already in the path.
    if (payload.hops.contains(localDevice)) {
      _remember(payload.id);
      return RelayVerdict.duplicate();
    }
    _remember(payload.id);
    return RelayVerdict.relay(payload.relayFrom(localDevice));
  }

  void _remember(String id) {
    _seen.add(id);
    if (_seen.length > _maxSeen) {
      _seen.clear();
      _seen.add(id);
    }
  }
}
