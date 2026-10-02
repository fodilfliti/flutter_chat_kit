import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 9, 30, 12);

void main() {
  group('camelCase preset', () {
    test('reads a camelCase message with attachments', () {
      final m = Message.fromJson(const {
        'type': 'image',
        'id': 'm1',
        'localId': 'l1',
        'roomId': 'r1',
        'authorId': 'u1',
        'createdAt': '2026-09-30T12:00:00Z',
        'replyToId': 'm0',
        'attachments': [
          {
            'remoteUrl': 'https://cdn.test/a',
            'mimeType': 'image/png',
            'thumbnailUrl': 'https://cdn.test/t',
            'width': 10,
            'height': 5,
          },
        ],
      }, keys: ChatJsonKeys.camelCase);
      final image = (m as ImageMessage).images.single;
      expect(m.localId, 'l1');
      expect(m.replyToId, 'm0');
      expect(image.remoteUrl, 'https://cdn.test/a');
      expect(image.mimeType, 'image/png');
      expect(image.thumbnailUrl, 'https://cdn.test/t');
      expect(image.aspectRatio, 2);
    });

    test('message round trip, attachments written with camelCase keys', () {
      final audio = AudioMessage(
        id: 'm1',
        localId: 'l1',
        roomId: 'r1',
        authorId: 'u1',
        createdAt: _t0,
        audio: const Attachment(
          mimeType: 'audio/mp4',
          remoteUrl: 'https://cdn.test/v.m4a',
          duration: Duration(seconds: 3),
        ),
        duration: const Duration(seconds: 3),
      );
      const keys = ChatJsonKeys.camelCase;
      final json = audio.toJson(keys: keys);
      expect(json['roomId'], 'r1');
      expect(json['durationMs'], 3000);
      expect(json['attachment'], {
        'mimeType': 'audio/mp4',
        'remoteUrl': 'https://cdn.test/v.m4a',
        'durationMs': 3000,
      });
      expect(Message.fromJson(json, keys: keys), audio);
    });

    test('room, members, last message and users', () {
      const keys = ChatJsonKeys.camelCase;
      final json = <String, Object?>{
        'id': 'r1',
        'type': 'group',
        'title': 'Team',
        'avatarUrl': 'https://cdn.test/r.png',
        'updatedAt': '2026-09-30T12:00:00Z',
        'unreadCount': 2,
        'pinned': true,
        'members': [
          {
            'userId': 'u1',
            'role': 'admin',
            'lastReadAt': '2026-09-30T11:00:00Z',
          },
        ],
        'lastMessage': {
          'id': 'm1',
          'authorId': 'u1',
          'createdAt': '2026-09-30T12:00:00Z',
          'text': 'hi',
        },
      };
      final room = ChatRoom.fromJson(json, keys: keys);
      expect(room.avatarUrl, 'https://cdn.test/r.png');
      expect(room.unreadCount, 2);
      expect(room.pinned, isTrue);
      expect(room.members.single.role, MemberRole.admin);
      expect(room.members.single.lastReadAt, DateTime.utc(2026, 9, 30, 11));
      expect(room.lastMessage!.roomId, 'r1');
      expect(ChatRoom.fromJson(room.toJson(keys: keys), keys: keys), room);

      final user = ChatUser.fromJson(const {
        'id': 'u1',
        'name': 'Ana',
        'avatarUrl': 'https://cdn.test/u.png',
      }, keys: keys.userKeys);
      expect(user.avatarUrl, 'https://cdn.test/u.png');
      expect(user.toJson(keys: keys.userKeys)['avatarUrl'], user.avatarUrl);
    });
  });

  group('Custom keys', () {
    test('nested key sets override single fields', () {
      const keys = ChatJsonKeys(
        authorId: 'sender',
        attachmentKeys: AttachmentJsonKeys(remoteUrl: 'src', mimeType: 'kind'),
        roomKeys: RoomJsonKeys(
          id: 'conversation_id',
          updatedAt: 'last_activity',
          member: MemberJsonKeys(userId: 'uid'),
        ),
        userKeys: UserJsonKeys(name: 'display_name', avatarUrl: 'photo'),
      );
      final room = ChatRoom.fromJson(const {
        'conversation_id': 'c1',
        'last_activity': 1790000000000,
        'members': [
          {'uid': 'u1'},
        ],
      }, keys: keys);
      expect(room.id, 'c1');
      expect(room.members.single.userId, 'u1');

      final file = Message.fromJson(const {
        'type': 'file',
        'id': 'm1',
        'room_id': 'c1',
        'sender': 'u1',
        'created_at': 1790000000000,
        'attachment': {'src': 'https://cdn.test/x', 'kind': 'text/plain'},
      }, keys: keys);
      expect((file as FileMessage).file.remoteUrl, 'https://cdn.test/x');
      expect(file.file.mimeType, 'text/plain');

      final user = ChatUser.fromJson(const {
        'id': 'u1',
        'display_name': 'Ana',
        'photo': 'https://cdn.test/a.png',
      }, keys: keys.userKeys);
      expect(user.name, 'Ana');
      expect(user.avatarUrl, 'https://cdn.test/a.png');
    });

    test('a codec passed to ChatRoom.fromJson replaces keys', () {
      final room = ChatRoom.fromJson(const {
        'id': 'r1',
        'updatedAt': 1790000000000,
      }, codec: const MessageCodec(keys: ChatJsonKeys.camelCase));
      expect(room.updatedAt.year, 2026);
    });

    test('defaults are unchanged', () {
      final room = ChatRoom(
        id: 'r1',
        updatedAt: _t0,
        members: const [RoomMember(userId: 'u1')],
      );
      expect(room.toJson(), {
        'id': 'r1',
        'updated_at': '2026-09-30T12:00:00.000Z',
        'type': 'direct',
        'members': [
          {'user_id': 'u1', 'role': 'member'},
        ],
        'unread_count': 0,
        'pinned': false,
        'muted': false,
      });
    });
  });
}
