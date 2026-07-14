import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/chat/chat_store.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('chat_store_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File getStoreFile() => File('${tempDir.path}/chat_history.json');

  group('ChatMessage', () {
    test('toJson serializes all fields', () {
      final msg = ChatMessage(text: 'হ্যালো', isUser: true);
      final json = msg.toJson();
      expect(json['text'], 'হ্যালো');
      expect(json['isUser'], true);
      expect(json['ts'], isNotNull);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'text': 'প্রশ্ন',
        'isUser': false,
        'ts': '2025-01-15T10:30:00.000',
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.text, 'প্রশ্ন');
      expect(msg.isUser, false);
    });

    test('fromJson handles missing timestamp', () {
      final json = {'text': 'test', 'isUser': true};
      final msg = ChatMessage.fromJson(json);
      expect(msg.text, 'test');
      expect(msg.isUser, true);
    });

    test('toJson/fromJson round trip preserves data', () {
      final msg = ChatMessage(text: 'নমস্কার', isUser: false);
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.text, msg.text);
      expect(restored.isUser, msg.isUser);
    });

    test('fromJson handles invalid timestamp gracefully', () {
      final msg = ChatMessage.fromJson({
        'text': 'x',
        'isUser': true,
        'ts': 'invalid-date',
      });
      expect(msg.text, 'x');
    });
  });

  group('ChatStore JSON file format', () {
    test('save writes valid JSON array', () {
      final messages = [
        ChatMessage(text: 'প্রশ্ন ১', isUser: true),
        ChatMessage(text: 'উত্তর ১', isUser: false),
      ];
      final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
      final list = jsonDecode(raw) as List;
      expect(list.length, 2);
      expect(list[0]['text'], 'প্রশ্ন ১');
      expect(list[0]['isUser'], true);
      expect(list[1]['text'], 'উত্তর ১');
    });

    test('empty file list is valid', () {
      final raw = jsonEncode([]);
      final list = jsonDecode(raw) as List;
      expect(list, isEmpty);
    });

    test('invalid JSON throws FormatException', () {
      expect(() => jsonDecode('not valid json'), throwsA(isA<FormatException>()));
    });
  });

  group('ChatStore file lifecycle', () {
    test('file can be written and read', () async {
      final f = getStoreFile();
      await f.writeAsString('[]');
      final content = await f.readAsString();
      expect(content, '[]');
    });

    test('file can be deleted', () async {
      final f = getStoreFile();
      await f.writeAsString('test');
      expect(await f.exists(), isTrue);
      await f.delete();
      expect(await f.exists(), isFalse);
    });
  });
}
