import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/mesh_models.dart';
import 'package:shongjog/features/mesh_comm/mesh_service.dart';

/// Mesh chat connected and then destabilized on a ~15-second cadence.
///
/// Cause: three separate code paths called `restartDiscovery()` /
/// `restartAdvertising()` unconditionally — a periodic timer, the app
/// lifecycle `resumed` handler, and radar-screen entry. On `P2P_CLUSTER`
/// those are not passive scans; the strategy negotiates a Wi-Fi Direct /
/// soft-AP group, so stopping and restarting them disturbs radio state that
/// an established link is sitting on.
///
/// [MeshService.hasLiveLink] is the single predicate all three now consult.
/// These tests pin its semantics, because every call site guards on it and a
/// wrong answer here silently restores the flapping.
void main() {
  // MeshService is a global singleton, so reset the seeded map between
  // tests — a leaked peer from one case would silently satisfy the next.
  tearDown(() => meshService.debugSeedPeers(const []));

  group('hasLiveLink', () {
    test('false with no peers at all — the refresh SHOULD run', () {
      final svc = meshService;
      expect(svc.hasLiveLink, isFalse);
    });

    test('true while a peer is connected — the refresh must stand down', () {
      final svc = meshService;
      svc.debugSeedPeers([
        MeshPeer(
          endpointId: 'a',
          name: 'peer-a',
          status: PeerStatus.connected,
        ),
      ]);
      expect(svc.hasLiveLink, isTrue);
    });

    test('true while a peer is RECONNECTING — the most important case', () {
      // A peer mid-reconnect is exactly when a radio bounce is most
      // destructive: it aborts the handshake and restarts the drop cycle.
      final svc = meshService;
      svc.debugSeedPeers([
        MeshPeer(
          endpointId: 'a',
          name: 'peer-a',
          status: PeerStatus.reconnecting,
        ),
      ]);
      expect(svc.hasLiveLink, isTrue);
    });

    test('false once every peer is fully disconnected — refresh resumes', () {
      final svc = meshService;
      svc.debugSeedPeers([
        MeshPeer(
          endpointId: 'a',
          name: 'peer-a',
          status: PeerStatus.disconnected,
        ),
        MeshPeer(
          endpointId: 'b',
          name: 'peer-b',
          status: PeerStatus.disconnected,
        ),
      ]);
      expect(svc.hasLiveLink, isFalse);
    });

    test('one live peer among disconnected ones still protects the radio', () {
      final svc = meshService;
      svc.debugSeedPeers([
        MeshPeer(
          endpointId: 'a',
          name: 'peer-a',
          status: PeerStatus.disconnected,
        ),
        MeshPeer(
          endpointId: 'b',
          name: 'peer-b',
          status: PeerStatus.connected,
        ),
      ]);
      expect(svc.hasLiveLink, isTrue);
    });
  });
}
