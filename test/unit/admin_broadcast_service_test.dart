import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/admin_broadcast_service.dart';

void main() {
  late Directory tempDir;
  late AdminBroadcastService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('admin_broadcast_test_');
    AdminBroadcastService.debugFilesDirOverride = tempDir.path;
    service = AdminBroadcastService();
  });

  tearDown(() async {
    AdminBroadcastService.debugFilesDirOverride = null;
    await service.clear();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('AdminMessage', () {
    test('toJson serializes all fields', () {
      final msg = AdminMessage(
        id: '123',
        text: 'বিজ্ঞপ্তি',
        timestamp: DateTime(2026, 7, 16, 12, 0),
        isRead: false,
      );
      final json = msg.toJson();
      expect(json['id'], '123');
      expect(json['text'], 'বিজ্ঞপ্তি');
      expect(json['ts'], '2026-07-16T12:00:00.000');
      expect(json['isRead'], false);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': '456',
        'text': 'সতর্কতা',
        'ts': '2026-07-16T10:30:00.000',
        'isRead': true,
      };
      final msg = AdminMessage.fromJson(json);
      expect(msg.id, '456');
      expect(msg.text, 'সতর্কতা');
      expect(msg.isRead, true);
    });

    test('fromJson handles missing fields gracefully', () {
      final json = <String, dynamic>{};
      final msg = AdminMessage.fromJson(json);
      expect(msg.id, '');
      expect(msg.text, '');
      expect(msg.isRead, false);
    });

    test('toJson/fromJson round trip preserves data', () {
      final msg = AdminMessage(
        id: '789',
        text: 'পরীক্ষা',
        timestamp: DateTime(2026, 7, 16, 14, 30),
        isRead: true,
      );
      final restored = AdminMessage.fromJson(msg.toJson());
      expect(restored.id, msg.id);
      expect(restored.text, msg.text);
      expect(restored.isRead, msg.isRead);
    });
  });

  group('AdminBroadcastService', () {
    test('starts with no messages', () {
      expect(service.messages, isEmpty);
      expect(service.unreadCount, 0);
    });

    test('addMessage stores message and increments count', () async {
      await service.addMessage('টেস্ট বার্তা');
      expect(service.messages.length, 1);
      expect(service.messages.first.text, 'টেস্ট বার্তা');
      expect(service.unreadCount, 1);
    });

    test('addMessage increments unread count', () async {
      await service.addMessage('বার্তা ১');
      await service.addMessage('বার্তা ২');
      expect(service.messages.length, 2);
      expect(service.unreadCount, 2);
    });

    test('messages are sorted newest-first', () async {
      await service.addMessage('প্রথম');
      await service.addMessage('দ্বিতীয়');
      expect(service.messages.first.text, 'দ্বিতীয়');
      expect(service.messages.last.text, 'প্রথম');
    });

    test('markAllAsRead clears unread count', () async {
      await service.addMessage('বার্তা ১');
      await service.addMessage('বার্তা ২');
      expect(service.unreadCount, 2);

      await service.markAllAsRead();
      expect(service.unreadCount, 0);
      expect(service.messages.every((m) => m.isRead), true);
    });

    test('markAllAsRead is idempotent', () async {
      await service.addMessage('টেস্ট');
      await service.markAllAsRead();
      await service.markAllAsRead();
      expect(service.unreadCount, 0);
    });

    test('clear empties messages and file', () async {
      await service.addMessage('বার্তা');
      expect(service.messages.length, 1);

      await service.clear();
      expect(service.messages, isEmpty);
      expect(service.unreadCount, 0);

      final f = File('${tempDir.path}/admin_broadcasts.json');
      expect(await f.exists(), false);
    });

    test('initialize loads persisted messages', () async {
      await service.addMessage('সংরক্ষিত বার্তা');
      expect(service.messages.length, 1);

      // Create a new service instance to test loading from disk
      final newService = AdminBroadcastService();
      AdminBroadcastService.debugFilesDirOverride = tempDir.path;
      await newService.initialize();
      expect(newService.messages.length, 1);
      expect(newService.messages.first.text, 'সংরক্ষিত বার্তা');
    });

    test('initialize handles corrupted file gracefully', () async {
      final f = File('${tempDir.path}/admin_broadcasts.json');
      await f.writeAsString('not valid json');

      final newService = AdminBroadcastService();
      AdminBroadcastService.debugFilesDirOverride = tempDir.path;
      await newService.initialize();
      expect(newService.messages, isEmpty);
    });

    test('notifyListeners fires on addMessage', () async {
      var notified = false;
      service.addListener(() => notified = true);
      await service.addMessage('টেস্ট');
      expect(notified, true);
    });

    test('notifyListeners fires on markAllAsRead', () async {
      await service.addMessage('টেস্ট');
      var notified = false;
      service.addListener(() => notified = true);
      await service.markAllAsRead();
      expect(notified, true);
    });

    test('notifyListeners does not fire when markAllAsRead has nothing to mark', () async {
      // Initialize first to avoid initialize() triggering notifyListeners
      await service.initialize();
      var notified = false;
      service.addListener(() => notified = true);
      await service.markAllAsRead();
      expect(notified, false);
    });
  });

  group('AdminBroadcastService Firestore sync', () {
    test('addMessage writes the message to Firestore', () async {
      final fakeFs = FakeFirebaseFirestore();
      final svc = AdminBroadcastService(firestore: fakeFs);
      AdminBroadcastService.debugFilesDirOverride = tempDir.path;

      await svc.addMessage('জরুরি বার্তা');

      final snap = await fakeFs.collection('broadcasts').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['text'], 'জরুরি বার্তা');
    });

    test('a broadcast written by another device merges into local messages',
        () async {
      final fakeFs = FakeFirebaseFirestore();
      // Simulate another device having already written a broadcast before
      // this device ever calls initialize().
      await fakeFs.collection('broadcasts').doc('remote-1').set({
        'id': 'remote-1',
        'text': 'অন্য ডিভাইস থেকে',
        'ts': DateTime(2026, 7, 20).toIso8601String(),
        'isRead': false,
      });

      final svc = AdminBroadcastService(firestore: fakeFs);
      AdminBroadcastService.debugFilesDirOverride = tempDir.path;
      await svc.initialize();
      // The fake Firestore stream delivers its first snapshot asynchronously.
      await Future<void>.delayed(Duration.zero);

      expect(svc.messages.any((m) => m.id == 'remote-1'), isTrue);
      expect(svc.messages.firstWhere((m) => m.id == 'remote-1').text,
          'অন্য ডিভাইস থেকে');
    });

    test('merging a remote broadcast preserves this device\'s local read state',
        () async {
      final fakeFs = FakeFirebaseFirestore();
      final svc = AdminBroadcastService(firestore: fakeFs);
      AdminBroadcastService.debugFilesDirOverride = tempDir.path;
      await svc.addMessage('বার্তা');
      final id = svc.messages.first.id;
      await svc.markAllAsRead();
      expect(svc.messages.first.isRead, isTrue);

      // Same doc arrives again via the stream (e.g. another field changed
      // remotely) — local isRead must not be clobbered back to false.
      await fakeFs.collection('broadcasts').doc(id).set({
        'id': id,
        'text': 'বার্তা',
        'ts': svc.messages.first.timestamp.toIso8601String(),
        'isRead': false,
      });
      await Future<void>.delayed(Duration.zero);

      expect(svc.messages.first.isRead, isTrue);
    });
  });
}
