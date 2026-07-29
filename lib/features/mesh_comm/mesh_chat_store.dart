import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'mesh_models.dart';

/// Persisted mesh chat message record.
class MeshChatMessage {
  final String senderId;
  final String senderName;
  final String text;
  final MessageType type;
  final String? filePath;
  final int? hopCount;
  final DateTime timestamp;

  MeshChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    this.filePath,
    this.hopCount,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Whether this message was sent by the local device.
  bool get isMe => senderId == kMeshSelfId;

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'type': type.name,
        if (filePath != null) 'filePath': filePath,
        if (hopCount != null) 'hopCount': hopCount,
        'ts': timestamp.toIso8601String(),
      };

  factory MeshChatMessage.fromJson(Map<String, dynamic> j) =>
      MeshChatMessage(
        senderId: j['senderId'] as String,
        senderName: j['senderName'] as String,
        text: j['text'] as String,
        type: MessageType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => MessageType.text,
        ),
        filePath: j['filePath'] as String?,
        hopCount: j['hopCount'] as int?,
        timestamp:
            DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );

  /// Convert to a [MeshMessage] for display in the UI.
  MeshMessage toMeshMessage() => MeshMessage(
        senderId: senderId,
        senderName: senderName,
        text: text,
        type: type,
        filePath: filePath,
        hopCount: hopCount,
        timestamp: timestamp,
      );
}

/// Persists mesh chat messages per-peer to JSON files in the app documents
/// directory. Each peer conversation gets its own file keyed by a sanitized
/// version of the display name (not the endpoint ID, which changes on restart).
class MeshChatStore {
  static const _dirName = 'mesh_chat';

  /// Sanitize a string for use as a filename.
  String _sanitize(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<Directory> _dir() async {
    final dir = await getApplicationDocumentsDirectory();
    final meshDir = Directory('${dir.path}/$_dirName');
    if (!await meshDir.exists()) {
      await meshDir.create(recursive: true);
    }
    return meshDir;
  }

  Future<File> _fileForKey(String key) async {
    final dir = await _dir();
    return File('${dir.path}/${_sanitize(key)}.json');
  }

  /// Load all persisted messages for a peer by display name (oldest first).
  /// Handles migration from old endpoint-ID-keyed files transparently.
  Future<List<MeshChatMessage>> load(String displayName, {String? oldEndpointId}) async {
    // Try display-name key first.
    final f = await _fileForKey(displayName);
    if (await f.exists()) {
      try {
        final raw = await f.readAsString();
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => MeshChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }

    // Migration: check for old endpoint-ID-keyed file and rename it.
    if (oldEndpointId != null && oldEndpointId.isNotEmpty) {
      final oldFile = await _fileForKey(oldEndpointId);
      if (await oldFile.exists()) {
        try {
          await oldFile.rename(f.path);
          final raw = await f.readAsString();
          final list = jsonDecode(raw) as List;
          return list
              .map((e) => MeshChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {
          // Fall through to empty.
        }
      }
    }

    return [];
  }

  /// Persist the full message list for a peer by display name (atomic overwrite).
  Future<void> save(String displayName, List<MeshChatMessage> messages) async {
    try {
      final f = await _fileForKey(displayName);
      final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
      await f.writeAsString(raw);
    } catch (_) {}
  }

  /// Append a single message to the store for a peer by display name.
  Future<void> append(String displayName, MeshChatMessage message) async {
    final existing = await load(displayName);
    existing.add(message);
    await save(displayName, existing);
  }

  /// Delete all stored messages for a peer by display name.
  Future<void> clearPeer(String displayName) async {
    try {
      final f = await _fileForKey(displayName);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Delete all mesh chat history.
  Future<void> clearAll() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
