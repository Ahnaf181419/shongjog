import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persisted chat message record.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'ts': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String,
        isUser: j['isUser'] as bool,
        timestamp: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Persists chat messages to a JSON file in the app documents directory.
///
/// Messages survive app restarts. The "Clear cache" action in Settings calls
/// [clear] to wipe all stored messages.
class ChatStore {
  static const _fileName = 'chat_history.json';

  @visibleForTesting
  Future<File> fileForTesting() async => _file();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Load all persisted messages (oldest first).
  Future<List<ChatMessage>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Append [messages] to the store. Pass the full list to persist atomically.
  Future<void> save(List<ChatMessage> messages) async {
    try {
      final f = await _file();
      final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
      await f.writeAsString(raw);
    } catch (e) { debugPrint("[Catch] chat_store: $e"); }
  }

  /// Delete all stored messages.
  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (e) { debugPrint("[Catch] chat_store: $e"); }
  }
}
