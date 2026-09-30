import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 9, 30, 12);

TextMessage _msg(String id, DateTime at) => TextMessage(
  id: id,
  localId: id,
  roomId: 'r1',
  authorId: 'u1',
  createdAt: at,
  text: id,
);

void main() {
  group('MessageCursor', () {
    test('orders by createdAt, then id', () {
      final a = MessageCursor(_t0, 'a');
      final b = MessageCursor(_t0, 'b');
      final later = MessageCursor(_t0.add(const Duration(seconds: 1)), 'a');

      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(later.isAfter(b), isTrue);
      expect([later, b, a]..sort(), [a, b, later]);
    });

    test('round-trips JSON', () {
      final c = MessageCursor(_t0, 'a');
      expect(MessageCursor.fromJson(c.toJson()), c);
      final r = RoomCursor(_t0, 'r');
      expect(RoomCursor.fromJson(r.toJson()), r);
    });
  });

  group('ChatRoom', () {
    final room = ChatRoom(
      id: 'r1',
      updatedAt: _t0,
      members: [
        RoomMember(userId: 'me', role: MemberRole.owner, lastReadAt: _t0),
        const RoomMember(userId: 'other'),
      ],
      lastMessage: _msg('m1', _t0),
      unreadCount: 3,
      pinned: true,
    );

    test('round-trips JSON with last message', () {
      expect(ChatRoom.fromJson(room.toJson()), room);
    });

    test('otherUserId for direct rooms only', () {
      expect(room.otherUserId('me'), 'other');
      expect(room.copyWith(type: RoomType.group).otherUserId('me'), isNull);
    });

    test('member lookup', () {
      expect(room.member('me')?.role, MemberRole.owner);
      expect(room.member('nobody'), isNull);
    });
  });

  group('RoomMember receipts', () {
    final member = RoomMember(
      userId: 'u2',
      lastReadAt: _t0,
      lastDeliveredAt: _t0.add(const Duration(minutes: 5)),
    );

    test('hasRead uses the read pointer inclusively', () {
      expect(member.hasRead(_msg('a', _t0)), isTrue);
      expect(
        member.hasRead(_msg('b', _t0.add(const Duration(seconds: 1)))),
        isFalse,
      );
    });

    test('hasReceived uses delivered or read pointer', () {
      expect(
        member.hasReceived(_msg('c', _t0.add(const Duration(minutes: 4)))),
        isTrue,
      );
      expect(
        member.hasReceived(_msg('d', _t0.add(const Duration(minutes: 6)))),
        isFalse,
      );
    });

    test('round-trips JSON', () {
      expect(RoomMember.fromJson(member.toJson()), member);
    });
  });

  group('TypingState', () {
    test('adds and removes users', () {
      const empty = TypingState(roomId: 'r1');
      final one = empty.withUser('u1', typing: true);
      expect(one.userIds, {'u1'});
      expect(one.withUser('u1', typing: false).isEmpty, isTrue);
    });
  });

  group('ChatPage', () {
    test('value equality', () {
      expect(
        const ChatPage(items: [1, 2], hasMore: true),
        const ChatPage(items: [1, 2], hasMore: true),
      );
      expect(const ChatPage<int>.empty().hasMore, isFalse);
    });
  });
}
