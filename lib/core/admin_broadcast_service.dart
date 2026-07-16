import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AdminMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  bool isRead;

  AdminMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'ts': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory AdminMessage.fromJson(Map<String, dynamic> json) => AdminMessage(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        timestamp: DateTime.tryParse(json['ts'] as String? ?? '') ?? DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
      );
}

class AdminBroadcastService extends ChangeNotifier {
  static const _fileName = 'admin_broadcasts.json';

  @visibleForTesting
  static String? debugFilesDirOverride;

  List<AdminMessage> _messages = [];
  List<AdminMessage> get messages => _messages;

  int get unreadCount => _messages.where((m) => !m.isRead).length;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<File> _file() async {
    final dir = debugFilesDirOverride ??
        (await getApplicationDocumentsDirectory()).path;
    return File('$dir/$_fileName');
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final f = await _file();
      if (await f.exists()) {
        final raw = await f.readAsString();
        final list = jsonDecode(raw) as List;
        _messages = list
            .map((e) => AdminMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      debugPrint('AdminBroadcastService init failed: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> addMessage(String text) async {
    await initialize();
    final msg = AdminMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
    );
    _messages.insert(0, msg);
    await _save();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await initialize();
    var changed = false;
    for (final m in _messages) {
      if (!m.isRead) {
        m.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      await _save();
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      final raw = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await f.writeAsString(raw);
    } catch (e) {
      debugPrint('AdminBroadcastService save failed: $e');
    }
  }

  Future<void> clear() async {
    _messages.clear();
    try {
      final f = await _file();
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    notifyListeners();
  }
}

final AdminBroadcastService adminBroadcastService = AdminBroadcastService();
