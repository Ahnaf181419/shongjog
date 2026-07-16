import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'mesh_models.dart';
import 'sos_payload.dart';
import 'sos_relay.dart';
import 'sos_relay_listener.dart';

/// Service ID isolates Shongjog peers from other Nearby Connections apps.
const _kServiceId = 'com.shongjog.mesh';

/// Reconnection constants.
const _kMaxReconnectAttempts = 5;
const _kReconnectBaseDelay = Duration(seconds: 2);

/// App-wide singleton Bluetooth-mesh messaging service using Google Nearby
/// Connections (P2P_CLUSTER strategy).
///
/// Lifecycle: started once after onboarding in `_StartupGate`, runs until app
/// termination. The radar screen and chat screen are pure UI layers that
/// connect to this service's streams.
class MeshService {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  final String userName;

  final _peersController = StreamController<List<MeshPeer>>.broadcast();
  final _messagesController = StreamController<MeshMessage>.broadcast();

  final Map<String, MeshPeer> _peers = {};
  final Map<String, Completer<void>> _reconnectTimers = {};

  /// Multi-hop SOS relay engine. Wired lazily — the listener is
  /// attached to the messages stream on first [start]().
  SosRelayEngine? _relayEngine;
  SosRelayListener? _relayListener;

  Stream<List<MeshPeer>> get peers => _peersController.stream;
  Stream<MeshMessage> get messages => _messagesController.stream;

  List<MeshPeer> get peerList => _peers.values.toList();
  int get peerCount => _peers.length;

  MeshService._({required this.userName});

  bool _running = false;
  bool get isRunning => _running;

  // ─── Permissions & Hardware Checks ───────────────────────────────

  /// Request the Bluetooth + Location permissions required by Nearby
  /// Connections. Returns `true` only if **all** permissions are granted.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    return statuses[Permission.bluetoothAdvertise]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.location]!.isGranted;
  }

  // ─── Lifecycle ───────────────────────────────────────────────────

  /// Begin advertising + discovery. Returns `false` if permissions denied
  /// or both advertising and discovery fail.
  Future<bool> start() async {
    if (_running) return true;

    final granted = await requestPermissions();
    if (!granted) {
      debugPrint('MeshService: permissions denied — not starting');
      return false;
    }

    bool advertisingOk = false;
    bool discoveryOk = false;

    try {
      advertisingOk = await Nearby().startAdvertising(
        userName,
        strategy,
        serviceId: _kServiceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('MeshService: startAdvertising failed: $e');
    }

    try {
      discoveryOk = await Nearby().startDiscovery(
        userName,
        strategy,
        serviceId: _kServiceId,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
    } catch (e) {
      debugPrint('MeshService: startDiscovery failed: $e');
    }

    if (!advertisingOk && !discoveryOk) {
      debugPrint('MeshService: both advertising and discovery failed');
      return false;
    }

    _running = true;
    _peersController.add(peerList);
    return true;
  }

  /// Restart discovery (e.g., after app resumes from background).
  /// Advertising continues uninterrupted.
  Future<void> restartDiscovery() async {
    if (!_running) return;
    try {
      await Nearby().stopDiscovery();
      await Nearby().startDiscovery(
        userName,
        strategy,
        serviceId: _kServiceId,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
    } catch (e) {
      debugPrint('MeshService: restartDiscovery failed: $e');
    }
  }

  /// Stop all Nearby Connections activity. Only called on app termination.
  Future<void> stop() async {
    _running = false;
    for (final timer in _reconnectTimers.values) {
      timer.complete();
    }
    _reconnectTimers.clear();
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _peers.clear();
    _peersController.add(peerList);
  }

  void dispose() {
    _peersController.close();
    _messagesController.close();
  }

  // ─── Discovery Callbacks ─────────────────────────────────────────

  void _onEndpointFound(String id, String name, String serviceId) {
    // Filter: only connect to Shongjog peers.
    if (!name.startsWith(kMeshPeerPrefix)) {
      debugPrint('MeshService: ignoring non-Shongjog endpoint "$name"');
      return;
    }

    debugPrint('MeshService: found Shongjog peer "$name" ($id)');
    Nearby().requestConnection(
      userName,
      id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  void _onEndpointLost(String? id) {
    if (id == null) return;
    debugPrint('MeshService: endpoint lost: $id');
    // Don't immediately remove — start reconnection grace period.
    final peer = _peers[id];
    if (peer != null) {
      _peers[id] = peer.copyWith(
        status: PeerStatus.reconnecting,
        reconnectAttempts: 0,
      );
      _peersController.add(peerList);
      _startReconnect(id);
    }
  }

  // ─── Connection Callbacks ────────────────────────────────────────

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    debugPrint(
        'MeshService: connection initiated with "${info.endpointName}" ($id)');
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      debugPrint('MeshService: connected to $id');
      final existing = _peers[id];
      final peer = MeshPeer(
        endpointId: id,
        name: existing?.name ?? id,
        status: PeerStatus.connected,
      );
      _peers[id] = peer;
      _reconnectTimers.remove(id)?.complete();
      _peersController.add(peerList);
    } else {
      debugPrint('MeshService: connection to $id failed (${status.name})');
      _peers.remove(id);
      _peersController.add(peerList);
    }
  }

  void _onDisconnected(String id) {
    debugPrint('MeshService: disconnected from $id');
    final peer = _peers.remove(id);
    if (peer != null) {
      _peersController.add(peerList);
      // Start reconnection attempts instead of giving up.
      _startReconnect(id);
    }
  }

  // ─── Reconnection ────────────────────────────────────────────────

  void _startReconnect(String endpointId) {
    if (_reconnectTimers.containsKey(endpointId)) return;
    _reconnectAttempt(endpointId, 0);
  }

  void _reconnectAttempt(String endpointId, int attempt) {
    if (attempt >= _kMaxReconnectAttempts || !_running) {
      debugPrint(
          'MeshService: giving up reconnection for $endpointId after $_kMaxReconnectAttempts attempts');
      _reconnectTimers.remove(endpointId);
      _peers.remove(endpointId);
      _peersController.add(peerList);
      return;
    }

    final delay = _kReconnectBaseDelay * (1 << attempt); // exponential backoff
    final completer = Completer<void>();
    _reconnectTimers[endpointId] = completer;

    Future.delayed(delay, () async {
      if (completer.isCompleted || !_running) return;
      debugPrint(
          'MeshService: reconnect attempt ${attempt + 1} for $endpointId');
      // Nearby Connections doesn't expose a direct reconnect API.
      // Reconnection happens naturally through continued advertising + discovery.
      _reconnectAttempt(endpointId, attempt + 1);
    });
  }

  // ─── Payload Handling ────────────────────────────────────────────

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      final bytes = payload.bytes;
      if (bytes == null) return;
      final text = utf8.decode(bytes, allowMalformed: true);
      final peerName = _peers[endpointId]?.name ?? endpointId;
      final msg = MeshMessage(
        senderId: endpointId,
        senderName: peerName,
        text: text,
        type: MessageType.text,
      );
      // Run through the relay engine if wired. The listener handles
      // emission back to the controller so we don't double-emit.
      final listener = _relayListener;
      if (listener != null) {
        listener.onIncoming(msg, rawBytes: bytes);
      } else {
        _messagesController.add(msg);
      }
    } else if (payload.type == PayloadType.FILE) {
      final uri = payload.uri;
      if (uri == null) return;
      final peerName = _peers[endpointId]?.name ?? endpointId;
      _messagesController.add(MeshMessage(
        senderId: endpointId,
        senderName: peerName,
        text: '',
        type: MessageType.voice,
        filePath: uri,
      ));
    }
  }

  // ─── Sending ─────────────────────────────────────────────────────

  /// Broadcast a UTF-8 text message to all connected peers.
  void sendMessage(String text) {
    if (_peers.isEmpty) return;
    final bytes = Uint8List.fromList(utf8.encode(text));
    for (final peer in _peers.values) {
      try {
        Nearby().sendBytesPayload(peer.endpointId, bytes);
      } catch (e) {
        debugPrint('MeshService: failed to send text to ${peer.name}: $e');
      }
    }
    // Add to local message history.
    _messagesController.add(MeshMessage(
      senderId: kMeshSelfId,
      senderName: 'Me',
      text: text,
      type: MessageType.text,
    ));
  }

  /// Lazily wire the SOS relay engine. Idempotent — call from app
  /// startup. Returns the same listener on subsequent calls.
  SosRelayListener ensureRelayEngine() {
    final engine = _relayEngine ??= SosRelayEngine(localDevice: userName);
    return _relayListener ??= SosRelayListener(
      engine: engine,
      sendToAll: (Uint8List bytes) async => sendBytesToAll(bytes),
      emit: _messagesController.add,
    );
  }

  /// Send raw bytes to all connected peers. Used by the SOS relay
  /// listener to forward decoded payloads. Does NOT add to the
  /// local message history (the listener handles that for SOS).
  void sendBytesToAll(Uint8List bytes) {
    if (_peers.isEmpty) return;
    for (final peer in _peers.values) {
      try {
        Nearby().sendBytesPayload(peer.endpointId, bytes);
      } catch (e) {
        debugPrint('MeshService: failed to send bytes to ${peer.name}: $e');
      }
    }
  }

  /// Broadcast a SOS payload over the mesh and add a local copy
  /// to the chat history with hopCount: 0.
  void broadcastSos(SosPayload payload) {
    final encoded = utf8.encode(payload.encode());
    sendBytesToAll(Uint8List.fromList(encoded));
    _messagesController.add(MeshMessage(
      senderId: kMeshSelfId,
      senderName: 'Me',
      text: payload.message,
      type: MessageType.text,
      hopCount: 0,
    ));
  }

  /// Send a voice file to all connected peers.
  void sendVoiceMessage(String filePath) {
    if (_peers.isEmpty) return;
    for (final peer in _peers.values) {
      try {
        Nearby().sendFilePayload(peer.endpointId, filePath);
      } catch (e) {
        debugPrint('MeshService: failed to send voice to ${peer.name}: $e');
      }
    }
    _messagesController.add(MeshMessage(
      senderId: kMeshSelfId,
      senderName: 'Me',
      text: '',
      type: MessageType.voice,
      filePath: filePath,
    ));
  }
}

/// App-wide singleton. The 24-bit random suffix (~16.7M values) keeps the
/// collision chance negligible even in a dense shelter, unlike the previous
/// `millisecondsSinceEpoch % 10000` (birthday collision at ~118 peers).
final meshService = MeshService._(
  userName:
      '$kMeshPeerPrefix${Random.secure().nextInt(0x1000000).toRadixString(16).padLeft(6, '0')}',
);
