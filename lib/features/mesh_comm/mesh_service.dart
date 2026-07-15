import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

/// App-wide singleton Bluetooth-mesh messaging service using Google Nearby
/// Connections (P2P_CLUSTER strategy). Lets users exchange short text
/// messages with nearby devices when there is no internet — the core
/// "it works when the internet doesn't" thesis for the companion app.
///
/// Usage:
///   await meshService.start();           // begin advertising + discovery
///   meshService.peers.listen(...);       // stream of connected peer lists
///   meshService.messages.listen(...);    // stream of incoming messages
///   meshService.sendMessage('হ্যালো');   // broadcast to all peers
///   await meshService.stop();            // stop advertising + discovery
class MeshService {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  final String userName;

  final _peersController = StreamController<List<String>>.broadcast();
  final _messagesController = StreamController<MeshMessage>.broadcast();

  final Set<String> _connectedPeers = {};

  Stream<List<String>> get peers => _peersController.stream;
  Stream<MeshMessage> get messages => _messagesController.stream;

  List<String> get connectedPeerList => _connectedPeers.toList();

  MeshService._({required this.userName});

  /// Whether [start] has been called and [stop] has not.
  bool _running = false;
  bool get isRunning => _running;

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

  /// Begin advertising + discovery. Returns `false` (and does nothing) if
  /// permissions are denied.
  Future<bool> start() async {
    if (_running) return true;
    final granted = await requestPermissions();
    if (!granted) {
      debugPrint('MeshService: permissions denied — not starting');
      return false;
    }

    _running = true;

    // ── Advertising ──
    await Nearby().startAdvertising(
      userName,
      strategy,
      onConnectionInitiated: _acceptConnection,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );

    // ── Discovery ──
    await Nearby().startDiscovery(
      userName,
      strategy,
      onEndpointFound: (id, name, serviceId) {
        Nearby().requestConnection(
          userName,
          id,
          onConnectionInitiated: _acceptConnection,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
        );
      },
      onEndpointLost: (id) {
        if (id != null) _onDisconnected(id);
      },
    );

    return true;
  }

  /// Shared callback: accept the incoming connection and register a
  /// payload listener. Deduplicated from the three places that previously
  /// duplicated this logic (advertising + discovery + manual request).
  void _acceptConnection(String id, ConnectionInfo info) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endid, payload) {
        if (payload.type == PayloadType.BYTES) {
          final bytes = payload.bytes!;
          final text = utf8.decode(bytes, allowMalformed: true);
          _messagesController.add(MeshMessage(senderId: endid, text: text));
        }
      },
    );
  }

  /// Shared callback: add peer to the set on successful connection.
  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      final wasNew = _connectedPeers.add(id);
      if (wasNew) _peersController.add(connectedPeerList);
    }
  }

  /// Shared callback: remove peer on disconnect.
  void _onDisconnected(String id) {
    final removed = _connectedPeers.remove(id);
    if (removed) _peersController.add(connectedPeerList);
  }

  /// Stop all Nearby Connections activity and clear the peer set.
  Future<void> stop() async {
    _running = false;
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _connectedPeers.clear();
    _peersController.add(connectedPeerList);
  }

  /// Broadcast a UTF-8 text message to all connected peers.
  void sendMessage(String text) {
    if (_connectedPeers.isEmpty) return;
    final bytes = Uint8List.fromList(utf8.encode(text));
    for (final peer in _connectedPeers) {
      Nearby().sendBytesPayload(peer, bytes);
    }
  }

  /// Close the stream controllers. Only call when the service is being
  /// permanently destroyed (not on screen-pop — use [stop] for that).
  void dispose() {
    _peersController.close();
    _messagesController.close();
  }
}

class MeshMessage {
  final String senderId;
  final String text;
  const MeshMessage({required this.senderId, required this.text});
}

/// App-wide singleton. User name is a short stable identifier so peers
/// can recognise each other on the radar screen.
final meshService = MeshService._(
  userName: 'Shongjog-${DateTime.now().millisecondsSinceEpoch % 10000}',
);
