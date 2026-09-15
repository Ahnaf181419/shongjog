import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/mesh_group.dart';
import 'package:shongjog/features/mesh_comm/mesh_models.dart';

void main() {
  group('MeshGroup model', () {
    test('round-trip JSON serialization', () {
      final group = MeshGroup(
        groupId: 'grp_test_123',
        name: 'ত্রাণ দল ১',
        creatorId: 'device_owner',
        createdAt: DateTime(2026, 9, 15, 12, 0, 0),
        members: [
          const GroupMember(
            deviceId: 'device_owner',
            displayName: 'আহনাফ',
            isAdmin: true,
          ),
          const GroupMember(
            deviceId: 'device_peer_2',
            displayName: 'রাকিব',
            isAdmin: false,
          ),
        ],
      );

      final encoded = group.encode();
      final decoded = MeshGroup.decode(encoded);

      expect(decoded.groupId, 'grp_test_123');
      expect(decoded.name, 'ত্রাণ দল ১');
      expect(decoded.creatorId, 'device_owner');
      expect(decoded.memberCount, 2);
      expect(decoded.hasMember('device_owner'), isTrue);
      expect(decoded.hasMember('device_peer_2'), isTrue);
      expect(decoded.hasMember('unknown_device'), isFalse);
    });

    test('addMember and removeMember', () {
      final original = MeshGroup(
        groupId: 'grp_001',
        name: 'রেসকিউ টিম',
        creatorId: 'dev_1',
        createdAt: DateTime.now(),
        members: [
          const GroupMember(deviceId: 'dev_1', displayName: 'ইউজার ১', isAdmin: true),
        ],
      );

      final withNewMember = original.addMember(
        const GroupMember(deviceId: 'dev_2', displayName: 'ইউজার ২'),
      );
      expect(withNewMember.memberCount, 2);
      expect(withNewMember.hasMember('dev_2'), isTrue);

      final removed = withNewMember.removeMember('dev_2');
      expect(removed.memberCount, 1);
      expect(removed.hasMember('dev_2'), isFalse);
    });
  });

  group('GroupMessage model', () {
    test('round-trip JSON serialization', () {
      final msg = GroupMessage(
        groupId: 'grp_test_123',
        senderId: 'dev_peer',
        senderName: 'সাদিয়া',
        text: 'জরুরি সাহায্য প্রয়োজন',
        type: 'text',
        timestamp: DateTime(2026, 9, 15, 12, 5, 0),
      );

      final encoded = msg.encode();
      final decoded = GroupMessage.decode(encoded);

      expect(decoded.groupId, 'grp_test_123');
      expect(decoded.senderId, 'dev_peer');
      expect(decoded.senderName, 'সাদিয়া');
      expect(decoded.text, 'জরুরি সাহায্য প্রয়োজন');
      expect(decoded.isMe, isFalse);
    });

    test('isMe returns true when senderId is me', () {
      final msg = GroupMessage(
        groupId: 'grp_test_123',
        senderId: 'me',
        senderName: 'আমি',
        text: 'আমি সাহায্য পাঠাচ্ছি',
        timestamp: DateTime.now(),
      );

      expect(msg.isMe, isTrue);
    });
  });

  group('1-on-1 chat filtering of group broadcasts', () {
    test('belongsToChatWith rejects GRP_ prefixed messages', () {
      final groupMsg = MeshMessage(
        senderId: 'peer_1',
        senderName: 'Peer',
        text: 'GRP_MSG:{"groupId":"g1","text":"Hi"}',
        type: MessageType.text,
      );

      expect(groupMsg.belongsToChatWith('peer_1'), isFalse);
    });

    test('belongsToChatWith accepts regular 1-on-1 messages from peer or me', () {
      final peerMsg = MeshMessage(
        senderId: 'peer_1',
        senderName: 'Peer',
        text: 'হ্যালো, কেমন আছেন?',
        type: MessageType.text,
      );
      expect(peerMsg.belongsToChatWith('peer_1'), isTrue);
      expect(peerMsg.belongsToChatWith('peer_2'), isFalse);

      final myMsg = MeshMessage(
        senderId: 'me',
        senderName: 'Me',
        text: 'ভালো আছি',
        type: MessageType.text,
      );
      expect(myMsg.belongsToChatWith('peer_1'), isTrue);
    });
  });
}
