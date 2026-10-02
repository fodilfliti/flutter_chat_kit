import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

import '../cache/memory_cache.dart';
import '../controllers/harness.dart' show until;

final _t0 = DateTime.utc(2026, 9, 30, 12);

TextMessage _text(String id, int minute, {String author = 'ana'}) =>
    TextMessage(
      id: id,
      localId: id,
      roomId: 'r1',
      authorId: author,
      createdAt: _t0.add(Duration(minutes: minute)),
      text: id,
    );

InMemoryChatSource _source({bool autoReply = false}) {
  var now = _t0.add(const Duration(hours: 1));
  return InMemoryChatSource(
    currentUserId: 'me',
    autoReply: autoReply,
    replyDelay: const Duration(milliseconds: 30),
    clock: () => now = now.add(const Duration(seconds: 1)),
    rooms: [
      ChatRoom(
        id: 'r1',
        updatedAt: _t0,
        members: const [
          RoomMember(userId: 'me'),
          RoomMember(userId: 'ana'),
        ],
      ),
      ChatRoom(
        id: 'r2',
        type: RoomType.group,
        title: 'Team',
        updatedAt: _t0.subtract(const Duration(days: 1)),
      ),
    ],
    messages: {
      'r1': [for (var i = 0; i < 25; i++) _text('m$i', i)],
    },
    users: const [ChatUser(id: 'ana', name: 'Ana Lopez')],
  );
}

void main() {
  test('rooms page newest first, with search, filter and users', () async {
    final source = _source();
    final page = await source.fetchRooms();
    expect(page.items.map((r) => r.id), ['r1', 'r2']);
    expect(page.users.single.name, 'Ana Lopez');

    final next = await source.fetchRooms(after: page.items.first.cursor);
    expect(next.items.single.id, 'r2');

    expect((await source.fetchRooms(search: 'ana')).items.single.id, 'r1');
    expect(
      (await source.fetchRooms(filter: RoomFilter.groups)).items.single.id,
      'r2',
    );
    await source.dispose();
  });

  test('messages page newest first in both directions', () async {
    final source = _source();
    final latest = await source.fetchMessages('r1', limit: 10);
    expect(latest.items.first.id, 'm24');
    expect(latest.items.last.id, 'm15');
    expect(latest.hasMore, isTrue);

    final older = await source.fetchMessages(
      'r1',
      before: latest.items.last.cursor,
      limit: 10,
    );
    expect(older.items.first.id, 'm14');

    final newer = await source.fetchMessages(
      'r1',
      after: older.items.first.cursor,
      limit: 3,
    );
    expect(newer.items.map((m) => m.id), ['m17', 'm16', 'm15']);
    expect(newer.hasMore, isTrue);

    final around = await source.fetchAround('r1', 'm5', limit: 6);
    expect(around!.items.map((m) => m.id), contains('m5'));
    await source.dispose();
  });

  test('send is idempotent and updates the room and both streams', () async {
    final source = _source();
    final roomEvents = <ChatEvent>[];
    final inboxEvents = <ChatEvent>[];
    final subs = [
      source.events(roomId: 'r1').listen(roomEvents.add),
      source.events().listen(inboxEvents.add),
    ];
    final pending = TextMessage(
      id: 'local-1',
      localId: 'local-1',
      roomId: 'r1',
      authorId: 'me',
      createdAt: _t0,
      text: 'hi',
      status: MessageStatus.pending,
    );
    final first = await source.send(pending);
    final again = await source.send(pending);
    await pumpEventQueue();

    expect(first.id, startsWith('mem-'));
    expect(first.status, MessageStatus.sent);
    expect(again, first);
    expect(source.messagesOf('r1').where((m) => m.localId == 'local-1'), [
      first,
    ]);
    expect(source.rooms.first.lastMessage, first);
    expect(source.rooms.first.unreadCount, 0);
    expect(roomEvents.whereType<MessageChanged>(), hasLength(1));
    expect(inboxEvents.whereType<RoomChanged>(), isNotEmpty);

    for (final s in subs) {
      await s.cancel();
    }
    await source.dispose();
  });

  test('receive counts unread; markRead clears it', () async {
    final source = _source()..receive(_text('new', 100));
    expect(source.rooms.first.unreadCount, 1);
    await source.markRead('r1', source.messagesOf('r1').first.cursor);
    final room = source.rooms.first;
    expect(room.unreadCount, 0);
    expect(
      room.member('me')!.lastReadAt,
      _t0.add(const Duration(hours: 1, minutes: 40)),
    );
    await source.dispose();
  });

  test('edit, react and soft delete emit updates', () async {
    final source = _source();
    final updates = <Message>[];
    final sub = source.events(roomId: 'r1').listen((e) {
      if (e case MessageChanged(change: Updated(:final item))) {
        updates.add(item);
      }
    });
    final m = source.messagesOf('r1').first as TextMessage;
    await source.edit(m.copyWith(text: 'changed'));
    await source.react('r1', m.id, '👍', add: true);
    await source.delete('r1', m.id);
    await pumpEventQueue();

    expect((updates[0] as TextMessage).text, 'changed');
    expect(updates[0].isEdited, isTrue);
    expect(updates[1].reactions, {
      '👍': {'me'},
    });
    expect(updates[2].isDeleted, isTrue);
    expect(() => source.delete('r1', 'nope'), throwsA(isA<NotFoundFailure>()));
    await sub.cancel();
    await source.dispose();
  });

  test('auto reply: read receipt, typing, then a message', () async {
    final source = _source(autoReply: true);
    final events = <ChatEvent>[];
    final sub = source.events(roomId: 'r1').listen(events.add);
    await source.send(
      TextMessage(
        id: 'l',
        localId: 'l',
        roomId: 'r1',
        authorId: 'me',
        createdAt: _t0,
        text: 'hello?',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(events.whereType<ReceiptChanged>().single.userId, 'ana');
    expect(events.whereType<TypingChanged>().map((e) => e.typing), [
      true,
      false,
    ]);
    final reply = events
        .whereType<MessageChanged>()
        .map((e) => e.change)
        .whereType<Created<Message>>()
        .last
        .item;
    expect(reply.authorId, 'ana');
    expect(source.rooms.first.unreadCount, 1);
    await sub.cancel();
    await source.dispose();
  });

  test('dispose cancels pending replies', () async {
    final source = _source(autoReply: true);
    await source.send(_text('x', 200, author: 'me'));
    await source.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(
      source.messagesOf('r1').where((m) => m.authorId == 'ana'),
      hasLength(25),
    );
  });

  test('sample works with a kit-shaped first page', () async {
    final source = InMemoryChatSource.sample(currentUserId: 'me');
    final rooms = await source.fetchRooms();
    expect(rooms.items, hasLength(3));
    expect(rooms.users.map((u) => u.id), containsAll(['amina', 'karim']));
    expect(rooms.items.first.unreadCount, 2);
    final messages = await source.fetchMessages(rooms.items.first.id);
    expect(messages.items.whereType<ImageMessage>(), hasLength(1));
    await source.dispose();
  });

  test('drives a real ChatKit: inbox, room, send and reply', () async {
    final source = InMemoryChatSource.sample(
      currentUserId: 'me',
      replyDelay: const Duration(milliseconds: 30),
    );
    final kit = ChatKit(
      currentUserId: 'me',
      source: source,
      cache: memoryCache(),
    );
    await kit.open();
    final inbox = kit.inbox();
    await until(() => inbox.rooms.length == 3);

    final room = kit.room(inbox.rooms.first.id);
    await room.ready;
    final before = room.messages.length;
    await room.sendText('hi');
    await until(() => room.messages.length == before + 2);
    expect(room.messages.first.authorId, isNot('me'));
    expect(room.messages[1].status, MessageStatus.sent);

    room.dispose();
    inbox.dispose();
    await kit.close();
    await source.dispose();
  });
}
