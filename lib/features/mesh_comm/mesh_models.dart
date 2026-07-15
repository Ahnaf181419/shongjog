import 'package:flutter/foundation.dart';

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

  bool get isMe => senderId == 'me';
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

  MeshPeer copyWith({
    PeerStatus? status,
    int? reconnectAttempts,
  }) {
    return MeshPeer(
      endpointId: endpointId,
      name: name,
      status: status ?? this.status,
      lastSeen: DateTime.now(),
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }

  String get displayName {
    if (name.startsWith('Shongjog-')) {
      return name.substring('Shongjog-'.length);
    }
    return name;
  }
}
