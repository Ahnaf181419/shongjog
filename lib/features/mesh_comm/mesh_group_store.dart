import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'mesh_group.dart';

class MeshGroupStore {
  static const _dirName = 'mesh_groups';

  String _sanitize(String id) =>
      id.replaceAll(RegExp(r'[^\p{L}\p{N}_-]', unicode: true), '_');

  Future<Directory> _dir() async {
    final dir = await getApplicationDocumentsDirectory();
    final groupDir = Directory('${dir.path}/$_dirName');
    if (!await groupDir.exists()) {
      await groupDir.create(recursive: true);
    }
    return groupDir;
  }

  Future<List<MeshGroup>> loadGroups() async {
    try {
      final dir = await _dir();
      final groups = <MeshGroup>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('_meta.json')) {
          final jsonStr = await entity.readAsString();
          groups.add(MeshGroup.decode(jsonStr));
        }
      }
      return groups;
    } catch (e) {
      debugPrint('MeshGroupStore: failed to load groups: $e');
      return [];
    }
  }

  Future<void> saveGroup(MeshGroup group) async {
    try {
      final dir = await _dir();
      final safeId = _sanitize(group.groupId);
      final file = File('${dir.path}/${safeId}_meta.json');
      await file.writeAsString(group.encode());
    } catch (e) {
      debugPrint('MeshGroupStore: failed to save group: $e');
    }
  }

  Future<List<GroupMessage>> loadMessages(String groupId) async {
    try {
      final dir = await _dir();
      final safeId = _sanitize(groupId);
      final file = File('${dir.path}/${safeId}_chat.json');
      if (!await file.exists()) return [];

      final jsonStr = await file.readAsString();
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => GroupMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('MeshGroupStore: failed to load group messages: $e');
      return [];
    }
  }

  Future<void> saveMessages(String groupId, List<GroupMessage> messages) async {
    try {
      final dir = await _dir();
      final safeId = _sanitize(groupId);
      final file = File('${dir.path}/${safeId}_chat.json');
      final list = messages.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('MeshGroupStore: failed to save group messages: $e');
    }
  }
}
