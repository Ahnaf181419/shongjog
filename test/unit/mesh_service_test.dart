import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/mesh_chat_screen.dart';
import 'package:shongjog/features/mesh_comm/mesh_models.dart';
import 'package:shongjog/features/mesh_comm/mesh_service.dart';

void main() {
  group('MeshMessage', () {
    test('stores senderId and text', () {
      final msg = MeshMessage(
        senderId: 'abc123',
        senderName: 'Shongjog-1234',
        text: 'হ্যালো',
        type: MessageType.text,
      );
      expect(msg.senderId, 'abc123');
      expect(msg.text, 'হ্যালো');
      expect(msg.isMe, isFalse);
    });

    test('isMe returns true for senderId "me"', () {
      final msg = MeshMessage(
        senderId: 'me',
        senderName: 'Me',
        text: 'hello',
        type: MessageType.text,
      );
      expect(msg.isMe, isTrue);
    });
  });

  group('UTF-8 message encoding round-trip', () {
    test('Bangla text survives encode → decode', () {
      const original = 'অফলাইন মেসেজ — ব্লুটুথ দিয়ে যোগাযোগ';
      final bytes = Uint8List.fromList(utf8.encode(original));
      final decoded = utf8.decode(bytes);
      expect(decoded, original);
    });

    test('mixed Bangla + ASCII survives encode → decode', () {
      const original = 'ORS তৈরির নিয়ম — mix 123';
      final bytes = Uint8List.fromList(utf8.encode(original));
      final decoded = utf8.decode(bytes);
      expect(decoded, original);
    });

    test('codeUnits (old approach) is identity in-memory but NOT wire-safe', () {
      const original = 'হ্যালো';
      expect(String.fromCharCodes(original.codeUnits), original);
      expect(original.codeUnits.any((c) => c > 127), isTrue,
          reason: 'Bangla characters have code points > 127, proving '
              'codeUnits is unsafe as a byte encoding.');
    });
  });

  group('meshService singleton', () {
    test('is a single instance', () {
      expect(identical(meshService, meshService), isTrue);
    });

    test('peerList starts empty', () {
      expect(meshService.peerList, isEmpty);
    });

    test('isRunning starts false', () {
      expect(meshService.isRunning, isFalse);
    });

    test('peerCount starts at 0', () {
      expect(meshService.peerCount, 0);
    });
  });

  group('MeshPeer deduplication logic (Map-based)', () {
    test('adding same peer twice overwrites', () {
      final peers = <String, MeshPeer>{};
      final p1 = MeshPeer(endpointId: 'A', name: 'Shongjog-1');
      final p2 = MeshPeer(endpointId: 'A', name: 'Shongjog-1');
      peers[p1.endpointId] = p1;
      peers[p2.endpointId] = p2;
      expect(peers.length, 1);
    });

    test('removing a non-existent peer is a no-op', () {
      final peers = <String, MeshPeer>{
        'A': MeshPeer(endpointId: 'A', name: 'Shongjog-1'),
      };
      final removed = peers.remove('B');
      expect(removed, isNull);
      expect(peers.length, 1);
    });

    test('clear empties the map', () {
      final peers = <String, MeshPeer>{
        'A': MeshPeer(endpointId: 'A', name: 'Shongjog-1'),
        'B': MeshPeer(endpointId: 'B', name: 'Shongjog-2'),
      };
      peers.clear();
      expect(peers, isEmpty);
    });
  });

  group('MeshService initial state', () {
    test('isRunning is false initially', () {
      expect(meshService.isRunning, isFalse);
    });

    test('peerList starts empty', () {
      expect(meshService.peerList, isEmpty);
    });
  });

  group('isPlayableVoicePath (receive-path gate)', () {
    test('accepts absolute filesystem path', () {
      expect(isPlayableVoicePath('/data/user/0/x/files/voice.m4a'), isTrue);
    });

    test('rejects content:// URI from nearby_connections plugin', () {
      // This is the bug fix: pre-fix code passed content:// to audioplayers
      // and the bubble silently failed. Post-fix the gate rejects it.
      expect(isPlayableVoicePath('content://x/y/123'), isFalse);
    });

    test('rejects null path', () {
      expect(isPlayableVoicePath(null), isFalse);
    });

    test('rejects relative path', () {
      expect(isPlayableVoicePath('voice.m4a'), isFalse);
    });

    test('rejects empty string', () {
      expect(isPlayableVoicePath(''), isFalse);
    });
  });

  group('MeshStartResult', () {
    test('ok result exposes both advertising and discovery as true', () {
      const r = MeshStartResult.success;
      expect(r.ok, isTrue);
      expect(r.advertisingOk, isTrue);
      expect(r.discoveryOk, isTrue);
      expect(r.reason, isNull);
    });

    test('fail result is not ok and carries a reason', () {
      final r = MeshStartResult.fail('wifi_off', wifiOn: false);
      expect(r.ok, isFalse);
      expect(r.wifiOn, isFalse);
      expect(r.reason, 'wifi_off');
    });
  });
}
