import 'dart:async';

import 'mesh_models.dart';

/// The active transport backend chosen at startup.
enum MeshTransportType {
  /// Google Nearby Connections — requires GMS. Best for devices with Play Services.
  nearbyConnections,

  /// Wi-Fi Direct via flutter_p2p_connection — GMS-free. Works on CN-market Xiaomi,
  /// AOSP builds, HyperOS without Play Services.
  wifiDirect,
}

/// Unified event emitted from either transport backend.
class TransportPeer {
  final String id;
  final String displayName;
  final bool isConnected;
  TransportPeer({required this.id, required this.displayName, required this.isConnected});
}

class TransportMessage {
  final String senderId;
  final String senderName;
  final String text;
  final String? filePath;
  TransportMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    this.filePath,
  });
}

/// Common interface both transport backends implement.
abstract class MeshTransport {
  MeshTransportType get type;

  Stream<List<TransportPeer>> get peers;
  Stream<TransportMessage> get messages;
  Stream<ConnectionRequestEvent> get connectionRequests;

  Future<bool> start(String userName);
  Future<void> stop();
  Future<void> restartDiscovery();

  bool sendText(String text);
  bool sendTextToPeer(String peerId, String text);
  bool sendFile(String filePath, {String? targetPeerId});

  void acceptConnection(String peerId);
  void rejectConnection(String peerId);

  bool get isRunning;
}
