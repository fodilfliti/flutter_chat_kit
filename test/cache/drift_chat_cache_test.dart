import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_cache.dart';

final _t0 = DateTime.utc(2026, 9, 30, 12);

TextMessage _msg(
  String id, {
  int second = 0,
  String? localId,
  String room = 'r1',
  MessageStatus status = MessageStatus.sent,
}) => TextMessage(
  id: id,
  localId: localId ?? id,
  roomId: room,
  authorId: 'u2',
  createdAt: _t0.add(Duration(seconds: second)),
  text: 'text $id',
  status: status,
);

List<String> _ids(List<Message> messages) => [for (final m in messages) m.id];

void main() {
  late DriftChatCache cache;
  var now = _t0;

  setUp(() async {
    now = _t0;
    cache = memoryCache(clock: () => now);
    await cache.open('me');
  });

  tearDown(() => cache.close());

  group('messages', () {
    test('every subtype round-trips exactly', () async {
      final base = _t0.add(const Duration(microseconds: 123));
      final messages = <Message>[
        TextMessage(
          id: 't',
          localId: 't',
          roomId: 'r1',
          authorId: 'u1',
          createdAt: base,
          editedAt: base.add(const Duration(minutes: 1)),
          text: 'hello',
          replyToId: 'x',
          reactions: const {
            '👍': {'u1', 'u2'},
          },
          metadata: const {'k': 1},
        ),
        ImageMessage(
          id: 'i',
          localId: 'i',
          roomId: 'r1',
          authorId: 'u1',
          createdAt: base,
          images: const [
            Attachment(mimeType: 'image/png', remoteUrl: 'u', width: 4),
          ],
          caption: 'cap',
        ),
        AudioMessage(
          id: 'a',
          localId: 'a',
          roomId: 'r1',
          authorId: 'u1',
          createdAt: base,
          audio: const Attachment(mimeType: 'audio/m4a', localPath: '/a'),
          duration: const Duration(seconds: 3),
          waveform: const [0.1, 0.5],
          status: MessageStatus.failed,
        ),
        SystemMessage(
          id: 's',
          localId: 's',
          roomId: 'r1',
          authorId: 'u1',
          createdAt: base,
          code: 'joined',
          args: const {'name': 'Ana'},
        ),
        CustomMessage(
          id: 'c',
          localId: 'c',
          roomId: 'r1',
          authorId: 'u1',
          createdAt: base,
          customType: 'offer',
          data: const {'price': 10},
          deletedAt: base,
        ),
      ];
      await cache.upsertMessages(messages);
      for (final m in messages) {
        expect(await cache.messageByAnyId(m.id), m);
      }
    });

    test('confirmed message replaces its pending row', () async {
      await cache.upsertMessages([_msg('l1', status: MessageStatus.pending)]);
      await cache.upsertMessages([_msg('srv-1', localId: 'l1')]);

      final all = await cache.watchMessages('r1', limit: 10).first;
      expect(all, hasLength(1));
      expect(all.single.id, 'srv-1');
      expect(all.single.localId, 'l1');
      expect(all.single.status, MessageStatus.sent);
      expect((await cache.messageByAnyId('l1'))?.id, 'srv-1');
    });

    test('merges a server-id duplicate into the pending row', () async {
      await cache.upsertMessages([
        _msg('l1', status: MessageStatus.sending),
        _msg('srv-1'),
      ]);
      await cache.upsertMessages([_msg('srv-1', localId: 'l1')]);

      final all = await cache.watchMessages('r1', limit: 10).first;
      expect(_ids(all), ['srv-1']);
      expect(all.single.localId, 'l1');
    });

    test('orders by createdAt then id, newest first', () async {
      await cache.upsertMessages([
        _msg('a', second: 1),
        _msg('c', second: 1),
        _msg('b', second: 1),
        _msg('z'),
        _msg('n', second: 2),
      ]);
      final list = await cache.watchMessages('r1', limit: 10).first;
      expect(_ids(list), ['n', 'c', 'b', 'a', 'z']);
      final latest = await cache.watchMessages('r1', limit: 2).first;
      expect(_ids(latest), ['n', 'c']);
    });

    test('keyset before/after are exclusive with equal timestamps', () async {
      await cache.upsertMessages([
        for (final id in ['a', 'b', 'c', 'd']) _msg(id, second: 1),
        _msg('old'),
        _msg('new', second: 2),
      ]);
      final cursor = _msg('b', second: 1).cursor;

      expect(_ids(await cache.messagesBefore('r1', cursor, 10)), ['a', 'old']);
      expect(_ids(await cache.messagesBefore('r1', cursor, 1)), ['a']);
      expect(_ids(await cache.messagesAfter('r1', cursor, 10)), [
        'new',
        'd',
        'c',
      ]);
      expect(_ids(await cache.messagesAfter('r1', cursor, 2)), ['d', 'c']);
    });

    test('watchMessages emits on insert and stays per room', () async {
      final stream = cache.watchMessages('r1', limit: 10);
      final emissions = <List<String>>[];
      final sub = stream.listen((list) => emissions.add(_ids(list)));
      await pumpEventQueue();

      await cache.upsertMessages([_msg('m1', second: 1)]);
      await pumpEventQueue();
      await cache.upsertMessages([_msg('other', room: 'r2')]);
      await pumpEventQueue();

      expect(emissions.first, isEmpty);
      expect(emissions.last, ['m1']);
      await sub.cancel();
    });

    test('range bounds are inclusive; limit keeps the newest', () async {
      await cache.upsertMessages([
        for (var i = 0; i < 10; i++) _msg('m$i', second: i),
      ]);
      final from = _msg('m2', second: 2).cursor;
      final to = _msg('m5', second: 5).cursor;
      expect(_ids(await cache.messages('r1', from: from, to: to)), [
        'm5',
        'm4',
        'm3',
        'm2',
      ]);
      expect(_ids(await cache.watchMessages('r1', from: from).first), [
        'm9',
        'm8',
        'm7',
        'm6',
        'm5',
        'm4',
        'm3',
        'm2',
      ]);
      expect(_ids(await cache.messages('r1', to: to, limit: 2)), ['m5', 'm4']);
    });

    test('updatePointers keeps the role and never moves back', () async {
      final read = _t0.add(const Duration(minutes: 5));
      await cache.upsertMembers('r1', [
        const RoomMember(userId: 'u2', role: MemberRole.admin),
      ]);
      await cache.updatePointers('r1', 'u2', readAt: read);
      await cache.updatePointers('r1', 'u2', readAt: _t0, deliveredAt: read);
      await cache.updatePointers('r1', 'u9', readAt: read);

      final members = await cache.watchMembers('r1').first;
      expect(members.first.role, MemberRole.admin);
      expect(members.first.lastReadAt, read);
      expect(members.first.lastDeliveredAt, read);
      expect(members.last.userId, 'u9');
    });

    test('deleteMessage by server id or local id', () async {
      await cache.upsertMessages([
        _msg('srv-1', localId: 'l1'),
        _msg('srv-2', localId: 'l2'),
      ]);
      await cache.deleteMessage('l1');
      await cache.deleteMessage('srv-2');
      expect(await cache.watchMessages('r1', limit: 10).first, isEmpty);
    });

    test('trim keeps the newest and unsent messages', () async {
      await cache.upsertMessages([
        for (var i = 0; i < 6; i++) _msg('m$i', second: i),
        _msg('pending', status: MessageStatus.pending),
      ]);
      await cache.saveSyncState(
        RoomSyncState(
          roomId: 'r1',
          newest: _msg('m5', second: 5).cursor,
          oldest: _msg('m0').cursor,
          hasMoreOlder: false,
        ),
      );

      await cache.trim('r1', keep: 2);

      final left = await cache.watchMessages('r1', limit: 10).first;
      expect(_ids(left), ['m5', 'm4', 'pending']);
      final state = await cache.syncState('r1');
      expect(state?.oldest, _msg('m4', second: 4).cursor);
      expect(state?.newest, _msg('m5', second: 5).cursor);
      expect(state?.hasMoreOlder, isTrue);
    });
  });

  group('rooms and members', () {
    ChatRoom room(
      String id, {
      int minute = 0,
      bool pinned = false,
      String? title,
      List<RoomMember> members = const [],
    }) => ChatRoom(
      id: id,
      updatedAt: _t0.add(Duration(minutes: minute)),
      type: members.length > 2 ? RoomType.group : RoomType.direct,
      title: title,
      pinned: pinned,
      members: members,
      lastMessage: _msg('last-$id', room: id),
      unreadCount: 2,
    );

    test('pinned first, then most recent', () async {
      await cache.upsertRooms([
        room('old'),
        room('new', minute: 5),
        room('pin', pinned: true),
      ]);
      final rooms = await cache.watchRooms().first;
      expect([for (final r in rooms) r.id], ['pin', 'new', 'old']);
      expect(rooms.first.lastMessage?.id, 'last-pin');
      expect(rooms.first.unreadCount, 2);
    });

    test(
      'members are replaced by a full list; pointers never go back',
      () async {
        final read = _t0.add(const Duration(minutes: 10));
        await cache.upsertRooms([
          room(
            'r1',
            members: [
              const RoomMember(userId: 'me'),
              RoomMember(userId: 'u2', lastReadAt: read),
            ],
          ),
        ]);
        await cache.upsertMembers('r1', [
          RoomMember(userId: 'u2', lastReadAt: _t0, lastDeliveredAt: read),
        ]);
        await cache.upsertRooms([
          room(
            'r1',
            members: [
              const RoomMember(userId: 'u2'),
              const RoomMember(userId: 'u3'),
            ],
          ),
        ]);

        final members = await cache.watchMembers('r1').first;
        expect([for (final m in members) m.userId], ['u2', 'u3']);
        expect(members.first.lastReadAt, read);
        expect(members.first.lastDeliveredAt, read);

        final loaded = await cache.watchRoom('r1').first;
        expect(loaded?.members, hasLength(2));
      },
    );

    test('a room without members keeps the stored ones', () async {
      await cache.upsertRooms([
        room('r1', members: [const RoomMember(userId: 'u2')]),
      ]);
      await cache.upsertRooms([room('r1', minute: 3)]);
      expect(await cache.watchMembers('r1').first, hasLength(1));
    });

    test('search matches title or member name', () async {
      await cache.upsertUsers([
        const ChatUser(id: 'u2', name: 'Ana Lopez'),
        const ChatUser(id: 'u3', name: 'Bo'),
      ]);
      await cache.upsertRooms([
        room('direct', members: [const RoomMember(userId: 'u2')]),
        room('team', title: 'Design team', minute: 1),
        room('other', members: [const RoomMember(userId: 'u3')], minute: 2),
      ]);

      Future<List<String>> search(String q) async => [
        for (final r in await cache.watchRooms(search: q).first) r.id,
      ];
      expect(await search('ana'), ['direct']);
      expect(await search('design'), ['team']);
      expect(await search('%'), isEmpty);
      expect(await search('  '), hasLength(3));
    });

    test('deleteRoom removes its messages and state', () async {
      await cache.upsertRooms([room('r1')]);
      await cache.upsertMessages([_msg('m1')]);
      await cache.saveDraft('r1', 'draft');
      await cache.deleteRoom('r1');
      expect(await cache.watchRoom('r1').first, isNull);
      expect(await cache.messageByAnyId('m1'), isNull);
      expect(await cache.draft('r1'), isNull);
    });
  });

  group('users, sync state, outbox, drafts', () {
    test('users and staleness', () async {
      await cache.upsertUsers([const ChatUser(id: 'u1', name: 'Ana')]);
      now = _t0.add(const Duration(hours: 1));
      await cache.upsertUsers([const ChatUser(id: 'u2', name: 'Bo')]);

      final users = await cache.users({'u1', 'u2', 'u3'});
      expect(users.keys, unorderedEquals(['u1', 'u2']));
      expect(
        await cache.staleUsers({
          'u1',
          'u2',
          'u3',
        }, olderThan: _t0.add(const Duration(minutes: 30))),
        {'u1', 'u3'},
      );
    });

    test('sync state round-trips', () async {
      final state = RoomSyncState(
        roomId: 'r1',
        newest: _msg('n', second: 9).cursor,
        oldest: _msg('o').cursor,
        hasMoreOlder: false,
        syncedAt: _t0,
      );
      await cache.saveSyncState(state);
      expect(await cache.syncState('r1'), state);
      expect(await cache.syncState('r2'), isNull);
    });

    test('outbox returns due entries oldest first', () async {
      OutboxEntry entry(String key, int second, {DateTime? next}) =>
          OutboxEntry(
            key: key,
            localId: key,
            roomId: 'r1',
            op: OutboxOp.send,
            createdAt: _t0.add(Duration(seconds: second)),
            payload: const {'a': 1},
            nextAttemptAt: next,
          );
      await cache.enqueue(entry('b', 2));
      await cache.enqueue(entry('a', 1));
      await cache.enqueue(
        entry('later', 0, next: _t0.add(const Duration(minutes: 5))),
      );

      final due = await cache.dueOutbox(_t0);
      expect([for (final e in due) e.key], ['a', 'b']);
      expect(due.first.payload, {'a': 1});

      await cache.updateOutbox(due.first.copyWith(attempts: 2));
      await cache.removeOutbox('b');
      final all = await cache.outbox();
      expect([for (final e in all) e.key], ['later', 'a']);
      expect(all.last.attempts, 2);
    });

    test('drafts save, update and clear', () async {
      await cache.saveDraft('r1', 'hel');
      await cache.saveDraft('r1', 'hello', replyToId: 'm1');
      expect(
        await cache.draft('r1'),
        const ChatDraft(text: 'hello', replyToId: 'm1'),
      );
      await cache.saveDraft('r1', '');
      expect(await cache.draft('r1'), isNull);
    });
  });

  group('lifecycle', () {
    test('clear wipes everything', () async {
      await cache.upsertMessages([_msg('m1')]);
      await cache.saveDraft('r1', 'x');
      await cache.clear();
      expect(await cache.messageByAnyId('m1'), isNull);
      expect(await cache.draft('r1'), isNull);
    });

    test('each user gets its own database', () async {
      final opened = <String>[];
      final multi = memoryCache(opened: opened);
      await multi.open('alice');
      await multi.upsertMessages([_msg('m1')]);
      await multi.open('alice');
      await multi.open('bob');
      expect(opened, ['alice', 'bob']);
      expect(await multi.messageByAnyId('m1'), isNull);
      await multi.close();
      expect(multi.isOpen, isFalse);
      expect(multi.watchRooms, throwsStateError);
    });

    test('database names are file-safe and distinct', () {
      expect(chatDatabaseName('abc_123'), 'chat_kit_abc_123');
      final a = chatDatabaseName('a/b');
      final b = chatDatabaseName('a_b');
      final c = chatDatabaseName('a:b');
      expect(a, startsWith('chat_kit_a_b_'));
      expect({a, b, c}, hasLength(3));
      expect(a, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });
  });
}
