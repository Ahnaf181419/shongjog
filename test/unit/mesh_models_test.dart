import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/mesh_models.dart';

void main() {
  group('MessageType', () {
    test('has text and voice types', () {
      expect(MessageType.text.index, 0);
      expect(MessageType.voice.index, 1);
    });
  });

  group('PeerStatus', () {
    test('has connected, reconnecting, disconnected', () {
      expect(PeerStatus.values.length, 3);
    });
  });

  group('MeshMessage', () {
    test('text message stores fields', () {
      final msg = MeshMessage(
        senderId: 'peer-1',
        senderName: 'Shongjog-1234',
        text: 'হ্যালো',
        type: MessageType.text,
        timestamp: DateTime(2026),
      );
      expect(msg.senderId, 'peer-1');
      expect(msg.senderName, 'Shongjog-1234');
      expect(msg.text, 'হ্যালো');
      expect(msg.type, MessageType.text);
      expect(msg.isMe, isFalse);
    });

    test('voice message stores filePath', () {
      final msg = MeshMessage(
        senderId: 'me',
        senderName: 'Me',
        text: '',
        type: MessageType.voice,
        filePath: '/tmp/voice.m4a',
        timestamp: DateTime(2026),
      );
      expect(msg.type, MessageType.voice);
      expect(msg.filePath, '/tmp/voice.m4a');
      expect(msg.isMe, isTrue);
    });

    test('isMe returns true when senderId is "me"', () {
      final msg = MeshMessage(
        senderId: 'me',
        senderName: 'Me',
        text: 'test',
        type: MessageType.text,
        timestamp: null,
      );
      expect(msg.isMe, isTrue);
    });

    test('defaults timestamp to now when null', () {
      final before = DateTime.now();
      final msg = MeshMessage(
        senderId: 'me',
        senderName: 'Me',
        text: 'test',
        type: MessageType.text,
      );
      final after = DateTime.now();
      expect(msg.timestamp!.isAfter(before) || msg.timestamp!.isAtSameMomentAs(before), isTrue);
      expect(msg.timestamp!.isBefore(after) || msg.timestamp!.isAtSameMomentAs(after), isTrue);
    });
  });

  group('MeshPeer', () {
    test('initial state is connected', () {
      final peer = MeshPeer(
        endpointId: 'ep-1',
        name: 'Shongjog-5678',
      );
      expect(peer.status, PeerStatus.connected);
      expect(peer.lastSeen, isNotNull);
      expect(peer.reconnectAttempts, 0);
    });

    test('copyWith updates status', () {
      final peer = MeshPeer(
        endpointId: 'ep-1',
        name: 'Shongjog-5678',
      );
      final reconnecting = peer.copyWith(status: PeerStatus.reconnecting);
      expect(reconnecting.status, PeerStatus.reconnecting);
      expect(reconnecting.endpointId, 'ep-1');
      expect(reconnecting.name, 'Shongjog-5678');
    });

    test('copyWith updates reconnectAttempts', () {
      final peer = MeshPeer(
        endpointId: 'ep-1',
        name: 'Shongjog-5678',
      );
      final updated = peer.copyWith(reconnectAttempts: 3);
      expect(updated.reconnectAttempts, 3);
    });

    test('displayName strips Shongjog- prefix', () {
      final peer = MeshPeer(endpointId: 'ep-1', name: 'Shongjog-5678');
      expect(peer.displayName, '5678');
    });

    test('displayName keeps full name if no prefix', () {
      final peer = MeshPeer(endpointId: 'ep-1', name: 'SomeOther-1234');
      expect(peer.displayName, 'SomeOther-1234');
    });
  });
}
