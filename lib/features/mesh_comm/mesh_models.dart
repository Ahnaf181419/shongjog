import 'package:flutter/foundation.dart';

/// Sender id used for messages authored on this device.
const String kMeshSelfId = 'me';

/// Advertised-name prefix that scopes discovery to Shongjog peers.
const String kMeshPeerPrefix = 'Shongjog-';

enum MessageType { text, voice }

enum PeerStatus { connected, reconnecting, disconnected }

@immutable
class MeshMessage {
  final String senderId;
  final String senderName;
  final String text;
  final MessageType type;
  final String? filePath;
  final DateTime? timestamp;

  MeshMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    this.filePath,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isMe => senderId == kMeshSelfId;

  /// Whether this message belongs in a 1-on-1 chat with [endpointId]:
  /// either sent by this device or received from that peer.
  bool belongsToChatWith(String endpointId) =>
      isMe || senderId == endpointId;
}

@immutable
class MeshPeer {
  final String endpointId;
  final String name;
  final PeerStatus status;
  final DateTime lastSeen;
  final int reconnectAttempts;

  MeshPeer({
    required this.endpointId,
    required this.name,
    this.status = PeerStatus.connected,
    DateTime? lastSeen,
    this.reconnectAttempts = 0,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// [lastSeen] defaults to now — every observed state change counts as
  /// seeing the peer. Pass it explicitly to preserve the old timestamp.
  MeshPeer copyWith({
    PeerStatus? status,
    int? reconnectAttempts,
    DateTime? lastSeen,
  }) {
    return MeshPeer(
      endpointId: endpointId,
      name: name,
      status: status ?? this.status,
      lastSeen: lastSeen ?? DateTime.now(),
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }

  String get displayName {
    if (name.startsWith(kMeshPeerPrefix)) {
      return name.substring(kMeshPeerPrefix.length);
    }
    return name;
  }
}
