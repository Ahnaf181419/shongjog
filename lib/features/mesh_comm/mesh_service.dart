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

const _kServiceId = 'com.shongjog.mesh';

class MeshService {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  final String userName;

  final _peersController = StreamController<List<MeshPeer>>.broadcast();
  final _messagesController = StreamController<MeshMessage>.broadcast();

  final Map<String, MeshPeer> _peers = {};

  // 🔴 FIX 1: Map to hold files that are currently downloading
  final Map<int, String> _incomingFiles = {};

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

  Future<bool> requestPermissions() async {
    // 🔴 FIX 3: Added nearbyWifiDevices for Android 13+ P2P_CLUSTER
    final statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    return statuses[Permission.bluetoothAdvertise]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.location]!.isGranted;
    // Note: nearbyWifiDevices might be null on older Androids, so we don't strictly require it in the return statement, but we MUST request it.
  }

  Future<bool> start() async {
    if (_running) return true;

    final granted = await requestPermissions();
    if (!granted) {
      debugPrint('MeshService: permissions denied');
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

    if (!advertisingOk && !discoveryOk) return false;

    _running = true;
    _peersController.add(peerList);
    return true;
  }

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
    } catch (_) {
      // Discovery start is best-effort; a failure here just means no peers
      // are found until the next start attempt.
    }
  }

  Future<void> stop() async {
    _running = false;
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _peers.clear();
    _incomingFiles.clear();
    _peersController.add(peerList);
  }

  void dispose() {
    _peersController.close();
    _messagesController.close();
  }

  void _onEndpointFound(String id, String name, String serviceId) {
    if (!name.startsWith(kMeshPeerPrefix)) return;

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
    // 🔴 FIX 2: Don't remove the peer, mark them as disconnected so UI can show grayed out state
    final peer = _peers[id];
    if (peer != null) {
      _peers[id] = peer.copyWith(status: PeerStatus.disconnected);
      _peersController.add(peerList);
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate, // 🔴 FIX 1
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      final existing = _peers[id];
      _peers[id] = MeshPeer(
        endpointId: id,
        name: existing?.name ?? id,
        status: PeerStatus.connected,
      );
      _peersController.add(peerList);
    } else {
      _peers.remove(id);
      _peersController.add(peerList);
    }
  }

  void _onDisconnected(String id) {
    // 🔴 FIX 2: Keep peer in list, but mark as disconnected.
    // Nearby automatically handles reconnecting if they come back into range via onEndpointFound.
    final peer = _peers[id];
    if (peer != null) {
      _peers[id] = peer.copyWith(status: PeerStatus.disconnected);
      _peersController.add(peerList);
    }
  }

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
      // 🔴 FIX 1: Store the file URI, but DO NOT send to UI yet.
      if (payload.uri != null) {
        _incomingFiles[payload.id] = payload.uri!;
      }
    }
  }

  // 🔴 FIX 1: Only pass the file to the UI when download completes
  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    if (update.status == PayloadStatus.SUCCESS) {
      final filePath = _incomingFiles.remove(update.id);
      if (filePath != null) {
        final peerName = _peers[endpointId]?.name ?? endpointId;
        _messagesController.add(MeshMessage(
          senderId: endpointId,
          senderName: peerName,
          text: '',
          type: MessageType.voice,
          filePath: filePath, // File is now 100% downloaded and safe to play
        ));
      }
    } else if (update.status == PayloadStatus.FAILURE || update.status == PayloadStatus.CANCELED) {
      _incomingFiles.remove(update.id);
    }
  }

  void sendMessage(String text, {String? targetEndpointId}) {
    if (_peers.isEmpty) return;
    final bytes = Uint8List.fromList(utf8.encode(text));
    for (final peer in _peers.values) {
      if (peer.status == PeerStatus.connected) {
        if (targetEndpointId == null || peer.endpointId == targetEndpointId) {
          try {
            Nearby().sendBytesPayload(peer.endpointId, bytes);
          } catch (e) { debugPrint("[Catch] mesh_service: $e"); }
        }
      }
    }
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

  /// Send a voice file to connected peers.
  ///
  /// When [targetEndpointId] is null the file is broadcast to every connected
  /// peer; when set, only that peer receives it (used by the per-peer chat).
  void sendVoiceMessage(String filePath, {String? targetEndpointId}) {
    if (_peers.isEmpty) return;
    for (final peer in _peers.values) {
      if (peer.status == PeerStatus.connected) {
        if (targetEndpointId == null || peer.endpointId == targetEndpointId) {
          try {
            Nearby().sendFilePayload(peer.endpointId, filePath);
          } catch (e) { debugPrint("[Catch] mesh_service: $e"); }
        }
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

final meshService = MeshService._(
  userName: '$kMeshPeerPrefix${Random.secure().nextInt(0x1000000).toRadixString(16).padLeft(6, '0')}',
);