import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

import 'harness.dart';

void main() {
  late Harness h;

  ChatRoom group({List<RoomMember>? members}) => ChatRoom(
    id: 'r1',
    updatedAt: t0,
    type: RoomType.group,
    title: 'Team',
    members:
        members ??
        const [
          RoomMember(userId: 'me'),
          RoomMember(userId: 'u2'),
          RoomMember(userId: 'u3'),
        ],
  );

  List<String> ids(ChatRoomController c) => [for (final m in c.messages) m.id];

  setUp(() async {
    h = Harness();
    await h.open();
  });

  tearDown(() => h.close());

  test('cached messages show even when the sync fails', () async {
    h.source.seedMessages('r1', [for (var i = 0; i < 10; i++) msg(i)]);
    final first = h.kit.room('r1');
    await first.ready;
    expect(first.messages, hasLength(10));
    first.dispose();

    h.source.failNext = const NetworkFailure();
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await room.ready;
    expect(room.messages, hasLength(10));
    expect(room.failure, isA<NetworkFailure>());
    expect(room.isSyncing, isFalse);
  });

  test('author names from the backend follow their changes', () async {
    h.source
      ..people['u2'] = const ChatUser(id: 'u2', name: 'Sara')
      ..seedRoom(group())
      ..seedMessages('r1', [msg(1)]);
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await room.ready;
    await until(() => room.users['u2']?.name == 'Sara');

    await h.kit.updateUsers([const ChatUser(id: 'u2', name: 'Sara B')]);
    await until(() => room.users['u2']?.name == 'Sara B');
  });

  test('loadOlder pages back through history', () async {
    h.source.seedMessages('r1', [for (var i = 0; i < 25; i++) msg(i)]);
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await room.ready;
    expect(ids(room).first, msg(24).id);
    expect(room.messages, hasLength(10));

    await room.loadOlder();
    await room.loadOlder();
    expect(room.messages, hasLength(25));
    expect(room.hasMoreOlder, isFalse);
    expect(ids(room).last, msg(0).id);
  });

  test('new messages count only while away from the bottom', () async {
    h.source.seedMessages('r1', [msg(1)]);
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await room.ready;

    h.source.receive(msg(2));
    await until(() => room.messages.length == 2);
    expect(room.newMessagesCount.value, 0);

    room.onViewportChanged(atBottom: false);
    h.source.receive(msg(3));
    await until(() => room.messages.length == 3);
    expect(room.newMessagesCount.value, 1);

    await room.sendText('mine');
    await until(() => room.messages.length == 4);
    expect(room.newMessagesCount.value, 1);

    room.onViewportChanged(atBottom: true);
    expect(room.newMessagesCount.value, 0);
  });

  test('markRead runs once per newer message at the bottom', () async {
    await h.kit.cache.upsertRooms([group()]);
    h.source.seedMessages('r1', [msg(1), msg(2)]);
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await room.ready;
    await until(() => h.source.markReadCalls.length == 1);
    expect(h.source.markReadCalls.single.$2, msg(2).cursor);

    room.onViewportChanged(atBottom: false);
    h.source.receive(msg(3));
    await until(() => room.messages.length == 3);
    await pumpEventQueue();
    expect(h.source.markReadCalls, hasLength(1));

    room.onViewportChanged(atBottom: true);
    await until(() => h.source.markReadCalls.length == 2);
    expect(h.source.markReadCalls.last.$2, msg(3).cursor);

    room
      ..onViewportChanged(atBottom: false)
      ..onViewportChanged(atBottom: true);
    await pumpEventQueue();
    expect(h.source.markReadCalls, hasLength(2));
    await until(() => room.room?.unreadCount == 0);
  });

  test('seenBy and effective status in a three-member group', () async {
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await h.kit.cache.upsertRooms([
      group(
        members: [
          const RoomMember(userId: 'me'),
          RoomMember(userId: 'u2', lastReadAt: at(5)),
          RoomMember(userId: 'u3', lastReadAt: at(1), lastDeliveredAt: at(9)),
        ],
      ),
    ]);
    await until(() => room.members.length == 3);
    final mine = msg(3, author: 'me');

    expect([for (final m in room.seenBy(mine)) m.userId], ['u2']);
    expect(room.effectiveStatus(mine), MessageStatus.delivered);
    expect(room.effectiveStatus(msg(20, author: 'me')), MessageStatus.sent);

    await h.kit.cache.updatePointers('r1', 'u3', readAt: at(4));
    await until(() => room.effectiveStatus(mine) == MessageStatus.seen);
    expect(room.effectiveStatus(msg(3)), MessageStatus.sent);
  });

  test('the unread divider sits above the first unread message', () async {
    await h.kit.cache.upsertRooms([
      group(
        members: [
          RoomMember(userId: 'me', lastReadAt: at(7)),
          const RoomMember(userId: 'u2'),
        ],
      ),
    ]);
    h.source.seedMessages('r1', [for (var i = 0; i < 10; i++) msg(i)]);
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await room.ready;
    expect(room.unreadDividerCursor, msg(8).cursor);
  });

  test('jumping far detaches, highlights, and returns', () async {
    h.source.seedMessages('r1', [for (var i = 0; i < 100; i++) msg(i)]);
    final room = h.kit.room('r1');
    await room.ready;

    final index = await room.jumpToMessage(msg(5).id);
    expect(index, isNotNull);
    expect(room.messages[index!].id, msg(5).id);
    expect(room.isDetached, isTrue);
    expect(room.highlightedId.value, msg(5).localId);
    await until(() => room.highlightedId.value == null);

    await room.loadNewer();
    expect(room.messages.first.cursor.isAfter(msg(5).cursor), isTrue);

    await room.returnToLatest();
    expect(room.isDetached, isFalse);
    expect(room.messages.first.id, msg(99).id);

    expect(await room.jumpToMessage('missing'), isNull);
    await room.jumpToMessage(msg(98).id);
    expect(room.hasPendingTimers, isTrue);
    room.dispose();
    expect(room.hasPendingTimers, isFalse);
  });

  test('send, react, edit and delete go through the outbox', () async {
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await room.ready;

    await room.sendText('  hello  ');
    await room.sendText('   ');
    await until(() => room.messages.length == 1);
    await h.kit.outbox.flush();
    await until(() => room.messages.single.id == 'srv-1');
    final sent = room.messages.single as TextMessage;
    expect(sent.text, 'hello');

    await room.react(sent.localId, '👍');
    await until(() => room.messages.single.reactions['👍'] != null);
    await room.react(sent.localId, '👍');
    await until(() => room.messages.single.reactions.isEmpty);

    await room.edit(sent.localId, 'hello!');
    await until(() => (room.messages.single as TextMessage).text == 'hello!');

    // The fake source confirms with a `Deleted` event, which drops the row.
    await room.delete(sent.localId);
    await h.kit.outbox.flush();
    await until(() => room.messages.isEmpty);
    expect(h.source.deleteCalls.single, ('r1', 'srv-1'));
  });

  test('media: images grouped, caption on them, size limit', () async {
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await room.ready;

    const image = Attachment(mimeType: 'image/png', remoteUrl: 'https://i/1');
    const file = Attachment(
      mimeType: 'application/pdf',
      remoteUrl: 'https://f/1',
      name: 'a.pdf',
    );
    await room.sendMedia([image, file, image], caption: 'look', replyToId: 'x');
    await until(() => room.messages.length == 2);
    final images = room.messages.whereType<ImageMessage>().single;
    expect(images.images, hasLength(2));
    expect(images.caption, 'look');
    expect(images.replyToId, 'x');
    expect(room.messages.whereType<FileMessage>().single.replyToId, isNull);

    final limited = Harness(config: const ChatConfig(maxAttachmentBytes: 10));
    await limited.open();
    addTearDown(limited.close);
    final small = limited.kit.room('r1');
    addTearDown(small.dispose);
    expect(
      () => small.sendMedia([
        const Attachment(mimeType: 'image/png', remoteUrl: 'u', size: 11),
      ]),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('typing members exclude me', () async {
    final room = h.kit.room('r1');
    addTearDown(room.dispose);
    await room.ready;
    h.source
      ..emit(const TypingChanged(roomId: 'r1', userId: 'u2', typing: true))
      ..emit(const TypingChanged(roomId: 'r1', userId: 'me', typing: true));
    await until(() => room.typingUserIds.isNotEmpty);
    expect(room.typingUserIds, ['u2']);
  });
}
