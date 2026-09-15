import 'package:flutter/foundation.dart';

/// Sender id used for messages authored on this device.
const String kMeshSelfId = 'me';

/// Advertised-name prefix that scopes discovery to Shongjog peers.
const String kMeshPeerPrefix = 'Shongjog-';

enum MessageType { text, voice, image, video, file }

enum PeerStatus { connected, reconnecting, disconnected }

@immutable
class ConnectionRequestEvent {
  final String endpointId;
  final String endpointName;
  const ConnectionRequestEvent(this.endpointId, this.endpointName);
}

enum MessageDeliveryStatus { sending, sent, delivered, failed }

@immutable
class MeshMessage {
  final String senderId;
  final String senderName;
  final String text;
  final MessageType type;
  final String? filePath;
  final DateTime? timestamp;
  final int? hopCount;
  final int? payloadId;
  final MessageDeliveryStatus deliveryStatus;

  MeshMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    this.filePath,
    this.hopCount,
    this.payloadId,
    this.deliveryStatus = MessageDeliveryStatus.sent,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isMe => senderId == kMeshSelfId;

  /// Whether this message belongs in a 1-on-1 chat with [endpointId]:
  /// either sent by this device or received from that peer (excluding group broadcasts).
  bool belongsToChatWith(String endpointId) =>
      !text.startsWith('GRP_') && (isMe || senderId == endpointId);

  MeshMessage copyWith({
    String? senderId,
    String? senderName,
    String? text,
    MessageType? type,
    String? filePath,
    int? hopCount,
    int? payloadId,
    MessageDeliveryStatus? deliveryStatus,
    DateTime? timestamp,
  }) {
    return MeshMessage(
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      hopCount: hopCount ?? this.hopCount,
      payloadId: payloadId ?? this.payloadId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      timestamp: timestamp ?? this.timestamp,
    );
  }
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
    String? name,
    PeerStatus? status,
    int? reconnectAttempts,
    DateTime? lastSeen,
  }) {
    return MeshPeer(
      endpointId: endpointId,
      name: name ?? this.name,
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
