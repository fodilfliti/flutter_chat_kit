import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

import '../cache/memory_cache.dart';
import '../source/fake_chat_source.dart';

final _t0 = DateTime.utc(2026, 9, 30, 12);

TextMessage _m(
  int i, {
  String room = 'r1',
  String author = 'u2',
  DateTime? at,
}) {
  final id = '$room-m${i.toString().padLeft(3, '0')}';
  return TextMessage(
    id: id,
    localId: id,
    roomId: room,
    authorId: author,
    createdAt: at ?? _t0.add(Duration(seconds: i)),
    text: id,
  );
}

List<TextMessage> _range(int from, int to, {String room = 'r1'}) => [
  for (var i = from; i < to; i++) _m(i, room: room),
];

String _id(int i, {String room = 'r1'}) => _m(i, room: room).id;

Future<void> _settle() => pumpEventQueue(times: 50);

class _Resolver implements ChatUserResolver {
  final List<Set<String>> calls = [];
  AppFailure? fail;

  @override
  Future<List<ChatUser>> resolve(Set<String> ids) async {
    calls.add(ids);
    final failure = fail;
    if (failure != null) throw failure;
    return [for (final id in ids) ChatUser(id: id, name: 'User $id')];
  }
}

void main() {
  late FakeChatSource source;
  late DriftChatCache cache;
  late ChatRepository repo;
  late _Resolver resolver;
  var now = _t0;

  ChatRepository build({
    int pageSize = 5,
    int maxGapPages = 5,
    Duration typingTimeout = const Duration(seconds: 5),
    int reconnectAttempts = 3,
  }) {
    return ChatRepository(
      currentUserId: 'me',
      source: source,
      cache: cache,
      users: resolver,
      config: ChatConfig(
        pageSize: pageSize,
        roomsPageSize: 2,
        typingTimeout: typingTimeout,
      ),
      clock: () => now,
      maxGapPages: maxGapPages,
      userBatchWindow: const Duration(milliseconds: 10),
      reconnectPolicy: RetryPolicy(
        maxAttempts: reconnectAttempts,
        base: const Duration(milliseconds: 5),
        max: const Duration(milliseconds: 5),
        jitter: 0,
      ),
    );
  }

  Future<void> waitFor(Future<bool> Function() test) async {
    for (var i = 0; i < 200 && !await test(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(await test(), isTrue);
  }

  Future<List<String>> shown(String roomId, RoomWindow window) async {
    final list = await repo.watchMessages(roomId, window).first;
    return [for (final m in list) m.id];
  }

  setUp(() async {
    now = _t0;
    source = FakeChatSource()..clock = () => now;
    cache = memoryCache(clock: () => now);
    await cache.open('me');
    resolver = _Resolver();
    repo = build();
  });

  tearDown(() async {
    await repo.dispose();
    await source.dispose();
    await cache.close();
  });

  group('sync', () {
    test('first open fetches the latest page and sets both cursors', () async {
      source.seedMessages('r1', _range(0, 12));
      final window = await repo.openRoom('r1');

      final state = await cache.syncState('r1');
      expect(state?.newest?.id, _id(11));
      expect(state?.oldest?.id, _id(7));
      expect(state?.hasMoreOlder, isTrue);
      expect(window.from?.id, _id(7));
      expect(await shown('r1', window), [for (var i = 11; i >= 7; i--) _id(i)]);
    });

    test('gap fill of one room leaves the other room untouched', () async {
      source
        ..seedMessages('r1', _range(0, 12))
        ..seedMessages('r2', _range(0, 3, room: 'r2'));
      await repo.openRoom('r1');
      await repo.openRoom('r2');
      await repo.closeRoom('r1');
      await repo.closeRoom('r2');
      final r2Before = await cache.syncState('r2');

      source
        ..seedMessages('r1', _range(12, 15))
        ..fetchCalls.clear();
      await repo.openRoom('r1');

      expect(source.fetchCalls.single.before, isNull);
      expect(source.fetchCalls.single.after, isNull);
      expect((await cache.syncState('r1'))?.newest?.id, _id(14));
      expect(await cache.syncState('r2'), r2Before);
      expect(r2Before?.hasMoreOlder, isFalse);
    });

    for (final (missed, requests) in [(0, 1), (10, 3), (100, 5), (1000, 5)]) {
      test(
        'reopening after $missed new messages costs $requests requests',
        () async {
          source.seedMessages('r1', _range(0, 10));
          await repo.openRoom('r1');
          await repo.closeRoom('r1');

          source
            ..seedMessages('r1', _range(10, 10 + missed))
            ..fetchCalls.clear();
          final window = await repo.openRoom('r1');

          final newest = 9 + missed;
          expect(source.fetchCalls, hasLength(requests));
          expect(source.fetchCalls.first.before, isNull);
          expect(source.fetchCalls.every((c) => c.after == null), isTrue);
          final state = await cache.syncState('r1');
          expect(state?.newest?.id, _id(newest));
          expect(await shown('r1', window), [
            for (var i = newest; i > newest - 5; i--) _id(i),
          ]);

          // Paging back never skips a message, whether the gap was closed or
          // left to paging.
          RoomWindow w = window;
          for (var i = 0; i < 4; i++) {
            w = await repo.loadOlder('r1', w);
          }
          expect(await shown('r1', w), [
            for (var i = newest; i > newest - 25 && i >= 0; i--) _id(i),
          ]);
        },
      );
    }

    test('a gap too large keeps the newest pages and pages the rest', () async {
      await repo.dispose();
      repo = build(maxGapPages: 2);
      source.seedMessages('r1', _range(0, 10));
      await repo.openRoom('r1');
      await repo.closeRoom('r1');

      source.seedMessages('r1', _range(10, 40));
      final window = await repo.openRoom('r1');

      final state = await cache.syncState('r1');
      expect(state?.oldest?.id, _id(30));
      expect(state?.newest?.id, _id(39));
      expect(state?.hasMoreOlder, isTrue);
      expect(await shown('r1', window), hasLength(5));

      final older = await repo.loadOlder('r1', window);
      expect(await shown('r1', older), [for (var i = 39; i >= 30; i--) _id(i)]);
      final oldest = await repo.loadOlder('r1', older);
      expect(await shown('r1', oldest), [
        for (var i = 39; i >= 25; i--) _id(i),
      ]);
    });

    test('resync fills what was missed while disconnected', () async {
      source.seedMessages('r1', _range(0, 10));
      await repo.openRoom('r1');

      repo.connectionLost();
      source
        ..seedMessages('r1', _range(10, 12))
        ..receive(_m(12));
      await _settle();
      expect((await cache.syncState('r1'))?.newest?.id, _id(9));

      await repo.resync();
      final state = await cache.syncState('r1');
      expect(state?.newest?.id, _id(12));
      final window = await repo.latestWindow('r1');
      final all = await cache.messages('r1', from: _m(5).cursor);
      expect(all, hasLength(8));
      expect(window.hasMoreOlder, isTrue);
    });

    test('a source failure leaves cache and cursors unchanged', () async {
      source
        ..seedMessages('r1', _range(0, 10))
        ..failNext = const NetworkFailure();
      await expectLater(repo.openRoom('r1'), throwsA(isA<NetworkFailure>()));
      await repo.closeRoom('r1');
      expect(await cache.syncState('r1'), isNull);
      expect(await cache.messages('r1'), isEmpty);

      await repo.openRoom('r1');
      await repo.closeRoom('r1');
      final before = await cache.syncState('r1');
      source
        ..seedMessages('r1', _range(10, 13))
        ..failNext = const TimeoutFailure();
      await expectLater(repo.openRoom('r1'), throwsA(isA<TimeoutFailure>()));
      await repo.closeRoom('r1');
      expect(await cache.syncState('r1'), before);

      await repo.openRoom('r1');
      expect((await cache.syncState('r1'))?.newest?.id, _id(12));
    });

    test('retention trims to maxCachedMessagesPerRoom after sync', () async {
      await repo.dispose();
      repo = ChatRepository(
        currentUserId: 'me',
        source: source,
        cache: cache,
        config: const ChatConfig(pageSize: 5, maxCachedMessagesPerRoom: 3),
      );
      source.seedMessages('r1', _range(0, 10));
      final window = await repo.openRoom('r1');
      expect(await shown('r1', window), [_id(9), _id(8), _id(7)]);
      expect((await cache.syncState('r1'))?.oldest?.id, _id(7));
    });
  });

  group('reconnect', () {
    test('a room stream that ends is resubscribed, the gap filled', () async {
      source.seedMessages('r1', _range(0, 3));
      await repo.openRoom('r1');
      final errors = <AppFailure>[];
      final sub = repo.errors.listen(errors.add);
      expect(source.eventListens, 1);

      source
        ..seedMessages('r1', _range(3, 5))
        ..dropStreams();
      await waitFor(
        () async => (await cache.syncState('r1'))?.newest?.id == _id(4),
      );
      expect(source.eventListens, 2);
      expect(errors, isEmpty);

      source.receive(_m(5));
      await waitFor(
        () async => (await cache.syncState('r1'))?.newest?.id == _id(5),
      );
      await sub.cancel();
    });

    test('a stream error is reported, then the stream comes back', () async {
      source.seedMessages('r1', _range(0, 3));
      await repo.openRoom('r1');
      repo.openInbox();
      final errors = <AppFailure>[];
      final sub = repo.errors.listen(errors.add);

      source.dropStreams(error: const NetworkFailure());
      await waitFor(() async => source.eventListens == 4);
      expect(errors, hasLength(2));
      expect(errors.first, isA<NetworkFailure>());
      expect(source.roomFetchCalls, isNotEmpty);

      source.dropStreams(error: StateError('socket'));
      await waitFor(() async => errors.length == 4);
      expect(errors.last, isA<UnknownFailure>());
      await sub.cancel();
      await repo.closeInbox();
    });

    test('gives up after maxAttempts until reconnect', () async {
      await repo.dispose();
      repo = build(reconnectAttempts: 1);
      source.seedMessages('r1', _range(0, 3));
      await repo.openRoom('r1');

      source.dropStreams();
      await waitFor(() async => source.eventListens == 2);
      source.dropStreams();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(source.eventListens, 2);

      repo.reconnect();
      expect(source.eventListens, 3);
      repo.reconnect();
      expect(source.eventListens, 3, reason: 'a live stream is left alone');
    });

    test('closing the room stops reconnecting', () async {
      source.seedMessages('r1', _range(0, 3));
      await repo.openRoom('r1');
      source.dropStreams();
      await repo.closeRoom('r1');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(source.eventListens, 1);
    });
  });

  group('paging', () {
    test('loadOlder serves from the cache before the source', () async {
      MessageCursor? fromOf(RoomWindow w) => (w as LatestWindow).from;

      source.seedMessages('r1', _range(0, 20));
      RoomWindow window = await repo.openRoom('r1');
      window = await repo.loadOlder('r1', window);
      window = await repo.loadOlder('r1', window);
      expect(fromOf(window)?.id, _id(5));
      await repo.closeRoom('r1');

      window = await repo.openRoom('r1');
      expect(fromOf(window)?.id, _id(15));
      source.fetchCalls.clear();

      window = await repo.loadOlder('r1', window);
      expect(source.fetchCalls, isEmpty);
      expect(fromOf(window)?.id, _id(10));
      expect(window.hasMoreOlder, isTrue);
    });

    test('equal timestamps page without gaps or duplicates', () async {
      final same = [
        for (var i = 0; i < 12; i++)
          TextMessage(
            id: 'a${i.toString().padLeft(2, '0')}',
            localId: 'a${i.toString().padLeft(2, '0')}',
            roomId: 'r1',
            authorId: 'u2',
            createdAt: _t0,
            text: '$i',
          ),
      ];
      source.seedMessages('r1', same);
      RoomWindow window = await repo.openRoom('r1');
      while (window.hasMoreOlder) {
        window = await repo.loadOlder('r1', window);
      }
      expect(await shown('r1', window), [
        for (var i = 11; i >= 0; i--) 'a${i.toString().padLeft(2, '0')}',
      ]);
    });

    test('loadOlder at the start of history reports no more', () async {
      source.seedMessages('r1', _range(0, 7));
      RoomWindow window = await repo.openRoom('r1');
      window = await repo.loadOlder('r1', window);
      expect(await shown('r1', window), hasLength(7));
      expect(window.hasMoreOlder, isFalse);
    });
  });

  group('realtime', () {
    test('the echo of an own message replaces the pending row', () async {
      source.seedMessages('r1', _range(0, 3));
      final window = await repo.openRoom('r1');
      now = _t0.add(const Duration(minutes: 1));
      final pending = TextMessage(
        id: 'l1',
        localId: 'l1',
        roomId: 'r1',
        authorId: 'me',
        createdAt: now,
        text: 'hi',
        status: MessageStatus.pending,
      );
      await cache.upsertMessages([pending]);

      final confirmed = await source.send(pending);
      await cache.upsertMessages([confirmed]);
      await _settle();

      final list = await repo.watchMessages('r1', window).first;
      expect(list.where((m) => m.localId == 'l1'), hasLength(1));
      expect(list.first.id, confirmed.id);
      expect(list.first.status, MessageStatus.sent);
      expect((await cache.syncState('r1'))?.newest?.id, confirmed.id);
    });

    test('updates, deletes and receipts reach the cache', () async {
      source.seedMessages('r1', _range(0, 3));
      await repo.openRoom('r1');
      final read = _t0.add(const Duration(minutes: 3));
      source
        ..emit(
          MessageChanged(
            roomId: 'r1',
            change: Updated(_m(1).copyWith(editedAt: read)),
          ),
        )
        ..emit(MessageChanged(roomId: 'r1', change: Deleted(_id(0))))
        ..emit(ReceiptChanged(roomId: 'r1', userId: 'u2', readAt: read));
      await _settle();

      expect((await cache.messageByAnyId(_id(1)))?.isEdited, isTrue);
      expect(await cache.messageByAnyId(_id(0)), isNull);
      final members = await cache.watchMembers('r1').first;
      expect(members.single.lastReadAt, read);
    });

    test('closed rooms stop receiving events', () async {
      source.seedMessages('r1', _range(0, 3));
      await repo.openRoom('r1');
      await repo.openRoom('r1');
      await repo.closeRoom('r1');
      expect(repo.isOpen('r1'), isTrue);
      await repo.closeRoom('r1');
      expect(repo.isOpen('r1'), isFalse);

      source.receive(_m(5));
      await _settle();
      expect(await cache.messageByAnyId(_id(5)), isNull);
    });

    test('typing ignores me, clears on a message and expires', () async {
      await repo.dispose();
      repo = build(typingTimeout: const Duration(milliseconds: 40));
      await repo.openRoom('r1');
      final states = <Set<String>>[];
      final sub = repo.watchTyping('r1').listen((t) => states.add(t.userIds));

      source
        ..emit(const TypingChanged(roomId: 'r1', userId: 'me', typing: true))
        ..emit(const TypingChanged(roomId: 'r1', userId: 'u2', typing: true))
        ..emit(const TypingChanged(roomId: 'r1', userId: 'u3', typing: true))
        ..receive(_m(1));
      await _settle();
      expect(repo.typing('r1').userIds, {'u3'});

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repo.typing('r1').isEmpty, isTrue);
      expect(states, [
        {'u2'},
        {'u2', 'u3'},
        {'u3'},
        <String>{},
      ]);
      await sub.cancel();
    });
  });

  group('jumpTo', () {
    test('a far message gives a detached window that reconnects', () async {
      source.seedMessages('r1', _range(0, 100));
      await repo.openRoom('r1');

      var window = await repo.jumpTo('r1', _id(20));
      expect(window, isA<DetachedWindow>());
      expect(await shown('r1', window!), contains(_id(20)));
      expect(await shown('r1', window), hasLength(5));

      var guard = 0;
      while (window is DetachedWindow && guard++ < 50) {
        window = await repo.loadNewer('r1', window);
      }
      expect(window, isA<LatestWindow>());
      final ids = await shown('r1', window!);
      expect(ids.first, _id(99));
      expect(ids.last, _id(18));
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, hasLength(82));
      expect((await cache.syncState('r1'))?.oldest?.id, _id(18));
    });

    test('a message already in the window keeps the window', () async {
      source.seedMessages('r1', _range(0, 20));
      final window = await repo.openRoom('r1');
      expect(await repo.jumpTo('r1', _id(17), current: window), window);
    });

    test('a cached contiguous message widens the latest window', () async {
      source.seedMessages('r1', _range(0, 20));
      RoomWindow window = await repo.openRoom('r1');
      window = await repo.loadOlder('r1', window);
      await repo.closeRoom('r1');
      window = await repo.openRoom('r1');

      final jumped = await repo.jumpTo('r1', _id(11), current: window);
      expect((jumped! as LatestWindow).from?.id, _id(10));
    });

    test('without fetchAround it pages back until found', () async {
      await repo.dispose();
      await source.dispose();
      source = FakeChatSource(supportsAround: false);
      repo = build();
      source.seedMessages('r1', _range(0, 30));
      await repo.openRoom('r1');

      final window = await repo.jumpTo('r1', _id(3));
      expect(window, isA<LatestWindow>());
      expect((window! as LatestWindow).from?.id, _id(1));
      expect(window.hasMoreOlder, isTrue);
      expect(await shown('r1', window), hasLength(29));

      expect(await repo.jumpTo('r1', 'missing'), isNull);
    });
  });

  group('inbox', () {
    ChatRoom room(String id, int minute) => ChatRoom(
      id: id,
      updatedAt: _t0.add(Duration(minutes: minute)),
      title: id,
    );

    test('rooms page with a cursor and follow room events', () async {
      for (var i = 0; i < 5; i++) {
        source.seedRoom(room('room$i', i));
      }
      final first = await repo.fetchRooms();
      expect(first.hasMore, isTrue);
      final second = await repo.fetchRooms(after: first.next);
      expect(second.hasMore, isTrue);
      final third = await repo.fetchRooms(after: second.next);
      expect(third.hasMore, isFalse);
      expect(await repo.watchRooms().first, hasLength(5));

      repo.openInbox();
      source
        ..emit(RoomChanged(Created(room('new', 10))))
        ..emit(const RoomChanged(Deleted('room0')));
      await _settle();
      final ids = [for (final r in await repo.watchRooms().first) r.id];
      expect(ids.first, 'new');
      expect(ids, isNot(contains('room0')));
      await repo.closeInbox();
    });

    test('presence events are kept in memory', () async {
      repo.openInbox();
      source.emit(
        const PresenceChanged(Presence(userId: 'u2', isOnline: true)),
      );
      await _settle();
      expect(repo.presence('u2')?.isOnline, isTrue);
      await repo.closeInbox();
    });
  });

  group('users', () {
    test('concurrent lookups share one resolver call', () async {
      final results = await Future.wait([
        repo.users({'a', 'b'}),
        repo.users({'b', 'c'}),
      ]);
      expect(resolver.calls, hasLength(1));
      expect(resolver.calls.single, {'a', 'b', 'c'});
      expect(results.last['c']?.name, 'User c');
    });

    test('fresh users come from the cache; stale ones refresh', () async {
      await repo.users({'a'});
      await repo.users({'a'});
      expect(resolver.calls, hasLength(1));

      now = now.add(const Duration(hours: 13));
      await repo.users({'a'});
      expect(resolver.calls, hasLength(2));
    });

    test(
      'users sent with pages are stored; the resolver is not asked',
      () async {
        source.people['u2'] = const ChatUser(id: 'u2', name: 'Sara');
        source.people['u3'] = const ChatUser(id: 'u3', name: 'Omar');
        source
          ..seedMessages('r1', _range(0, 3))
          ..seedRoom(
            ChatRoom(
              id: 'd1',
              updatedAt: _t0,
              members: const [
                RoomMember(userId: 'me'),
                RoomMember(userId: 'u3'),
              ],
            ),
          );

        await repo.openRoom('r1');
        await repo.fetchRooms();
        final users = await repo.users({'u2', 'u3'});
        expect(users['u2']?.name, 'Sara');
        expect(users['u3']?.name, 'Omar');
        expect(resolver.calls, isEmpty);
      },
    );

    test('changed users replace the stored ones and are announced', () async {
      final announced = <List<String>>[];
      final sub = repo.userChanges.listen(
        (users) => announced.add([for (final u in users) u.name]),
      );
      addTearDown(sub.cancel);

      const sara = ChatUser(id: 'u2', name: 'Sara', avatarUrl: 'a.png');
      await repo.putUsers([sara]);
      await repo.putUsers([sara]);
      await repo.putUsers([sara.copyWith(avatarUrl: 'b.png')]);
      await repo.putUsers([sara.copyWith(name: 'Sara B', avatarUrl: 'b.png')]);
      await _settle();

      expect(announced, [
        ['Sara'],
        ['Sara'],
        ['Sara B'],
      ]);
      expect((await repo.users({'u2'}))['u2']?.avatarUrl, 'b.png');
      expect(resolver.calls, isEmpty);
    });

    test('UsersChanged events update the stored users', () async {
      await repo.putUsers([const ChatUser(id: 'u2', name: 'Sara')]);
      repo.openInbox();
      source.emit(
        const UsersChanged([ChatUser(id: 'u2', name: 'Sara (shop)')]),
      );
      await _settle();
      expect((await repo.users({'u2'}))['u2']?.name, 'Sara (shop)');
      await repo.closeInbox();
    });

    test('resolver failures fall back to the cache', () async {
      await repo.users({'a'});
      now = now.add(const Duration(hours: 13));
      resolver.fail = const NetworkFailure();
      final users = await repo.users({'a', 'b'});
      expect(users.keys, ['a']);
    });
  });
}
