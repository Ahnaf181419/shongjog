import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/mesh_models.dart';
import 'package:shongjog/features/mesh_comm/sos_payload.dart';
import 'package:shongjog/features/mesh_comm/sos_relay.dart';
import 'package:shongjog/features/mesh_comm/sos_relay_listener.dart';

void main() {
  String encodeSos({String id = 'a', int hops = 0, int hopCount = 0}) {
    final p = SosPayload(
      id: id,
      originName: 'A',
      originPhone: '',
      message: 'help',
      lat: 0,
      lon: 0,
      timestamp: DateTime.now(),
      hopCount: hopCount,
      hops: List.filled(hops, 'x'),
    );
    return p.encode();
  }

  group('SosRelayListener', () {
    test('on non-SOS payload, listener emits with no hopCount', () async {
      final sent = <String>[];
      final emitted = <MeshMessage>[];
      final listener = SosRelayListener(
        engine: SosRelayEngine(localDevice: 'me'),
        sendToAll: (Uint8List bytes) async => sent.add(utf8.decode(bytes)),
        emit: emitted.add,
      );
      await listener.onIncoming(
        MeshMessage(
          senderId: 'phone-b', senderName: 'B',
          text: 'hello world', type: MessageType.text,
        ),
        rawBytes: Uint8List.fromList(utf8.encode('hello world')),
      );
      expect(sent, isEmpty);
      expect(emitted, hasLength(1));
      expect(emitted.first.hopCount, isNull);
    });

    test('on first SOS, listener re-broadcasts the relayed payload', () async {
      final sent = <String>[];
      final emitted = <MeshMessage>[];
      final listener = SosRelayListener(
        engine: SosRelayEngine(localDevice: 'me'),
        sendToAll: (Uint8List bytes) async => sent.add(utf8.decode(bytes)),
        emit: emitted.add,
      );
      final encoded = encodeSos(id: 'first', hops: 0);
      await listener.onIncoming(
        MeshMessage(
          senderId: 'phone-b', senderName: 'B',
          text: encoded, type: MessageType.text,
        ),
        rawBytes: Uint8List.fromList(utf8.encode(encoded)),
      );
      expect(sent, hasLength(1));
      final re = SosPayload.decode(sent.first);
      expect(re.id, 'first');
      expect(re.hopCount, 1);
      expect(re.hops, ['me']);
    });

    test('on second SOS with the same id, listener does NOT re-broadcast',
        () async {
      final sent = <String>[];
      final emitted = <MeshMessage>[];
      final listener = SosRelayListener(
        engine: SosRelayEngine(localDevice: 'me'),
        sendToAll: (Uint8List bytes) async => sent.add(utf8.decode(bytes)),
        emit: emitted.add,
      );
      final encoded = encodeSos(id: 'dup', hops: 0);
      await listener.onIncoming(
        MeshMessage(
          senderId: 'phone-b', senderName: 'B',
          text: encoded, type: MessageType.text,
        ),
        rawBytes: Uint8List.fromList(utf8.encode(encoded)),
      );
      await listener.onIncoming(
        MeshMessage(
          senderId: 'phone-c', senderName: 'C',
          text: encoded, type: MessageType.text,
        ),
        rawBytes: Uint8List.fromList(utf8.encode(encoded)),
      );
      expect(sent, hasLength(1));
      // Duplicate arrival is de-duped — only one emission per SOS id.
      expect(emitted, hasLength(1));
      expect(emitted[0].hopCount, 0);
    });

    test('emitted message carries the original payload hopCount', () async {
      final sent = <String>[];
      final emitted = <MeshMessage>[];
      final listener = SosRelayListener(
        engine: SosRelayEngine(localDevice: 'me'),
        sendToAll: (Uint8List bytes) async => sent.add(utf8.decode(bytes)),
        emit: emitted.add,
      );
      final encoded = encodeSos(id: 'multi', hops: 2, hopCount: 2);
      await listener.onIncoming(
        MeshMessage(
          senderId: 'phone-b', senderName: 'B',
          text: encoded, type: MessageType.text,
        ),
        rawBytes: Uint8List.fromList(utf8.encode(encoded)),
      );
      expect(emitted, hasLength(1));
      expect(emitted.first.hopCount, 2);
      expect(emitted.first.text, 'help');
    });
  });
}