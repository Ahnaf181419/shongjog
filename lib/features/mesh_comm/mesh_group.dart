import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Unique prefix for group-related wire messages.
const String kGroupMsgPrefix = 'GRP_MSG:';
const String kGroupCreatePrefix = 'GRP_CREATE:';
const String kGroupInvitePrefix = 'GRP_INVITE:';
const String kGroupAcceptPrefix = 'GRP_ACCEPT:';
const String kGroupLeavePrefix = 'GRP_LEAVE:';

@immutable
class MeshGroup {
  final String groupId;
  final String name;
  final String creatorId;
  final DateTime createdAt;
  final List<GroupMember> members;

  const MeshGroup({
    required this.groupId,
    required this.name,
    required this.creatorId,
    required this.createdAt,
    required this.members,
  });

  int get memberCount => members.length;

  bool hasMember(String deviceId) =>
      members.any((m) => m.deviceId == deviceId);

  MeshGroup addMember(GroupMember member) => MeshGroup(
        groupId: groupId,
        name: name,
        creatorId: creatorId,
        createdAt: createdAt,
        members: [...members, member],
      );

  MeshGroup removeMember(String deviceId) => MeshGroup(
        groupId: groupId,
        name: name,
        creatorId: creatorId,
        createdAt: createdAt,
        members: members.where((m) => m.deviceId != deviceId).toList(),
      );

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'creatorId': creatorId,
        'createdAt': createdAt.toIso8601String(),
        'members': members.map((m) => m.toJson()).toList(),
      };

  factory MeshGroup.fromJson(Map<String, dynamic> j) => MeshGroup(
        groupId: j['groupId'] as String,
        name: j['name'] as String,
        creatorId: j['creatorId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        members: (j['members'] as List)
            .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String encode() => jsonEncode(toJson());
  static MeshGroup decode(String raw) =>
      MeshGroup.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

@immutable
class GroupMember {
  final String deviceId;
  final String displayName;
  final bool isAdmin;

  const GroupMember({
    required this.deviceId,
    required this.displayName,
    this.isAdmin = false,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'displayName': displayName,
        'isAdmin': isAdmin,
      };

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        deviceId: j['deviceId'] as String,
        displayName: j['displayName'] as String,
        isAdmin: j['isAdmin'] as bool? ?? false,
      );
}

@immutable
class GroupMessage {
  final String groupId;
  final String senderId;
  final String senderName;
  final String text;
  final String type; // 'text', 'voice', 'image', 'video'
  final String? filePath;
  final int? payloadId;
  final DateTime timestamp;

  const GroupMessage({
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.type = 'text',
    this.filePath,
    this.payloadId,
    required this.timestamp,
  });

  bool get isMe => senderId == 'me';

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'type': type,
        if (filePath != null) 'filePath': filePath,
        if (payloadId != null) 'payloadId': payloadId,
        'ts': timestamp.toIso8601String(),
      };

  factory GroupMessage.fromJson(Map<String, dynamic> j) => GroupMessage(
        groupId: j['groupId'] as String,
        senderId: j['senderId'] as String,
        senderName: j['senderName'] as String,
        text: j['text'] as String,
        type: j['type'] as String? ?? 'text',
        filePath: j['filePath'] as String?,
        payloadId: j['payloadId'] as int?,
        timestamp: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );

  String encode() => jsonEncode(toJson());
  static GroupMessage decode(String raw) =>
      GroupMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
