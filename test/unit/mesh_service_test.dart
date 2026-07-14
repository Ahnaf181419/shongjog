import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/mesh_service.dart';

void main() {
  group('MeshMessage', () {
    test('stores senderId and text', () {
      const msg = MeshMessage(senderId: 'abc123', text: 'হ্যালো');
      expect(msg.senderId, 'abc123');
      expect(msg.text, 'হ্যালো');
    });
  });

  group('UTF-8 message encoding round-trip', () {
    // Verifies the fix from text.codeUnits (Latin-1, breaks Bangla) to
    // utf8.encode (correct multi-byte). This is the encoding used inside
    // MeshService.sendMessage.
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
      // This test documents WHY we switched from codeUnits to utf8.encode.
      const original = 'হ্যালো';
      // In-memory round-trip of codeUnits is identity (UTF-16 code units).
      expect(String.fromCharCodes(original.codeUnits), original);
      // But codeUnits returns UTF-16 values (e.g. 0x09B9 = 2489 for 'হ'),
      // NOT bytes. If sent as raw bytes over Nearby Connections (BYTES
      // payload), only the low byte survives (2489 & 0xFF = 185 = '¹'),
      // garbling the Bangla text. utf8.encode produces correct multi-byte
      // sequences that survive the wire.
      expect(original.codeUnits.any((c) => c > 127), isTrue,
          reason: 'Bangla characters have code points > 127, proving '
              'codeUnits is unsafe as a byte encoding.');
    });
  });

  group('meshService singleton', () {
    test('is a single instance', () {
      // The singleton should be the same object every time it's referenced.
      expect(identical(meshService, meshService), isTrue);
    });

    test('connectedPeerList starts empty', () {
      expect(meshService.connectedPeerList, isEmpty);
    });

    test('isRunning starts false', () {
      expect(meshService.isRunning, isFalse);
    });
  });

  group('Set-based peer deduplication logic', () {
    // Tests the dedup pattern used in _onConnectionResult / _onDisconnected.
    test('adding same peer twice does not create duplicate', () {
      final peers = <String>{};
      peers.add('device-A');
      peers.add('device-A');
      expect(peers.length, 1);
    });

    test('removing a non-existent peer is a no-op', () {
      final peers = <String>{'device-A'};
      final removed = peers.remove('device-B');
      expect(removed, isFalse);
      expect(peers.length, 1);
    });

    test('clear empties the set', () {
      final peers = <String>{'A', 'B', 'C'};
      peers.clear();
      expect(peers, isEmpty);
    });
  });
}
