import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  AdminBroadcastService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  static const _fileName = 'admin_broadcasts.json';
  static const _collection = 'broadcasts';

  @visibleForTesting
  static String? debugFilesDirOverride;

  // Resolved lazily via [_firestore] below — see the same note in
  // CampaignRequestService for why this can't be an eager field.
  final FirebaseFirestore? _injectedFirestore;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;

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
    _subscribeFirestore();
  }

  /// Listen for broadcasts sent from any admin device. The local JSON
  /// cache (loaded above) paints instantly on cold start; this stream
  /// keeps it live. Best-effort — offline devices just stay on local data.
  void _subscribeFirestore() {
    try {
      _firestoreSub = _firestore
          .collection(_collection)
          .snapshots()
          .listen(_mergeFirestoreSnapshot, onError: (e) {
        debugPrint('AdminBroadcastService Firestore stream failed: $e');
      });
    } catch (e) {
      debugPrint('AdminBroadcastService Firestore subscribe failed: $e');
    }
  }

  void _mergeFirestoreSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final doc in snap.docs) {
      final incoming = AdminMessage.fromJson(doc.data());
      final index = _messages.indexWhere((m) => m.id == incoming.id);
      if (index == -1) {
        _messages.add(incoming);
      } else {
        // Preserve local read state — Firestore doesn't track per-device
        // read/unread, that's purely a local concern.
        incoming.isRead = _messages[index].isRead;
        _messages[index] = incoming;
      }
    }
    _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    unawaited(_save());
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
    try {
      await _firestore.collection(_collection).doc(msg.id).set(msg.toJson());
    } catch (e) {
      debugPrint('AdminBroadcastService: Firestore submit failed: $e');
    }
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
    } catch (e) { debugPrint("[Catch] admin_broadcast: $e"); }
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }
}

final AdminBroadcastService adminBroadcastService = AdminBroadcastService();
