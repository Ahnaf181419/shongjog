import 'dart:async';

import 'package:flutter/foundation.dart';

import 'mesh_group.dart';
import 'mesh_group_store.dart';
import 'mesh_models.dart';
import 'mesh_service.dart';

class MeshGroupService {
  final MeshGroupStore _store = MeshGroupStore();
  final Map<String, MeshGroup> _groups = {};
  final Map<String, List<GroupMessage>> _messages = {};

  final _groupUpdateController = StreamController<List<MeshGroup>>.broadcast();
  final _messageUpdateController = StreamController<GroupMessage>.broadcast();

  Stream<List<MeshGroup>> get groupsStream => _groupUpdateController.stream;
  Stream<GroupMessage> get messageStream => _messageUpdateController.stream;

  List<MeshGroup> get groups => _groups.values.toList();

  Future<void> initialize() async {
    final loaded = await _store.loadGroups();
    for (final g in loaded) {
      _groups[g.groupId] = g;
      _messages[g.groupId] = await _store.loadMessages(g.groupId);
    }
    _notifyGroups();

    meshService.messages.listen(_onMeshMessage);
    debugPrint('MeshGroupService: initialized');
  }

  void _onMeshMessage(MeshMessage msg) {
    if (msg.isMe) return;

    if (msg.text.startsWith(kGroupMsgPrefix)) {
      final raw = msg.text.substring(kGroupMsgPrefix.length);
      try {
        final gMsg = GroupMessage.decode(raw);
        _handleIncomingGroupMessage(gMsg);
      } catch (e) {
        debugPrint('MeshGroupService: failed to decode group msg: $e');
      }
    } else if (msg.text.startsWith(kGroupInvitePrefix)) {
      final raw = msg.text.substring(kGroupInvitePrefix.length);
      try {
        final group = MeshGroup.decode(raw);
        _handleGroupInvite(group);
      } catch (e) {
        debugPrint('MeshGroupService: failed to decode group invite: $e');
      }
    }
  }

  void _handleIncomingGroupMessage(GroupMessage msg) {
    // Only process messages for groups we are a part of
    if (!_groups.containsKey(msg.groupId)) return;

    _messages.putIfAbsent(msg.groupId, () => []).add(msg);
    _store.saveMessages(msg.groupId, _messages[msg.groupId]!);
    _messageUpdateController.add(msg);
  }

  void _handleGroupInvite(MeshGroup group) {
    if (!_groups.containsKey(group.groupId)) {
      _groups[group.groupId] = group;
      _store.saveGroup(group);
      _notifyGroups();
    }
  }

  Future<void> createGroup(String name, List<MeshPeer> initialMembers) async {
    final groupId = 'grp_${DateTime.now().millisecondsSinceEpoch}';

    final selfName = meshService.userName.startsWith(kMeshPeerPrefix)
        ? meshService.userName.substring(kMeshPeerPrefix.length)
        : meshService.userName;

    final selfMember = GroupMember(
      deviceId: meshService.userName,
      displayName: selfName,
      isAdmin: true,
    );

    final members = [selfMember];
    for (final p in initialMembers) {
      members.add(GroupMember(
        deviceId: p.endpointId, 
        displayName: p.displayName,
      ));
    }

    final group = MeshGroup(
      groupId: groupId,
      name: name,
      creatorId: selfMember.deviceId,
      createdAt: DateTime.now(),
      members: members,
    );

    _groups[groupId] = group;
    await _store.saveGroup(group);
    _notifyGroups();

    // Broadcast invite to the selected peers
    final invitePayload = '$kGroupInvitePrefix${group.encode()}';
    for (final p in initialMembers) {
      meshService.sendMessage(
        invitePayload,
        targetEndpointId: p.endpointId,
        echoSelf: false,
      );
    }
  }

  Future<void> sendGroupMessage(String groupId, String text,
      {String type = 'text', String? filePath}) async {
    final group = _groups[groupId];
    if (group == null) return;

    final selfName = meshService.userName.startsWith(kMeshPeerPrefix)
        ? meshService.userName.substring(kMeshPeerPrefix.length)
        : meshService.userName;

    final gMsg = GroupMessage(
      groupId: groupId,
      senderId: kMeshSelfId,
      senderName: selfName,
      text: text,
      type: type,
      filePath: filePath,
      timestamp: DateTime.now(),
    );

    _messages.putIfAbsent(groupId, () => []).add(gMsg);
    await _store.saveMessages(groupId, _messages[groupId]!);
    _messageUpdateController.add(gMsg);

    final wirePayload = '$kGroupMsgPrefix${gMsg.encode()}';

    // In a true mesh, we broadcast to all peers, and only those in the group
    // will process it. We set targetEndpointId to null to send to everyone.
    meshService.sendMessage(wirePayload, echoSelf: false);
  }

  List<GroupMessage> getMessages(String groupId) => _messages[groupId] ?? [];

  void _notifyGroups() => _groupUpdateController.add(groups);
}

final meshGroupService = MeshGroupService();
