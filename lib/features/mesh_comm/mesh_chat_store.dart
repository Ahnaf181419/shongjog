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
/// version of the endpoint ID.
class MeshChatStore {
  static const _dirName = 'mesh_chat';

  /// Sanitize an endpoint ID for use as a filename.
  String _sanitize(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<Directory> _dir() async {
    final dir = await getApplicationDocumentsDirectory();
    final meshDir = Directory('${dir.path}/$_dirName');
    if (!await meshDir.exists()) {
      await meshDir.create(recursive: true);
    }
    return meshDir;
  }

  Future<File> _fileFor(String peerId) async {
    final dir = await _dir();
    return File('${dir.path}/${_sanitize(peerId)}.json');
  }

  /// Load all persisted messages for a peer (oldest first).
  Future<List<MeshChatMessage>> load(String peerId) async {
    try {
      final f = await _fileFor(peerId);
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => MeshChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persist the full message list for a peer (atomic overwrite).
  Future<void> save(String peerId, List<MeshChatMessage> messages) async {
    try {
      final f = await _fileFor(peerId);
      final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
      await f.writeAsString(raw);
    } catch (_) {}
  }

  /// Append a single message to the store for a peer.
  Future<void> append(String peerId, MeshChatMessage message) async {
    final existing = await load(peerId);
    existing.add(message);
    await save(peerId, existing);
  }

  /// Delete all stored messages for a peer.
  Future<void> clearPeer(String peerId) async {
    try {
      final f = await _fileFor(peerId);
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
