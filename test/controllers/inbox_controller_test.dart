import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

import 'harness.dart';

void main() {
  late Harness h;

  ChatRoom room(
    String id, {
    required int updated,
    String? title,
    int unread = 0,
    bool pinned = false,
    bool muted = false,
    RoomType type = RoomType.group,
  }) {
    return ChatRoom(
      id: id,
      updatedAt: at(updated),
      type: type,
      title: title ?? id,
      unreadCount: unread,
      pinned: pinned,
      muted: muted,
      members: [
        const RoomMember(userId: 'me'),
        RoomMember(userId: 'peer-$id'),
      ],
    );
  }

  setUp(() async {
    h = Harness();
    await h.open();
  });

  tearDown(() => h.close());

  test('pinned first, then recent; muted rooms not in the total', () async {
    h.source
      ..seedRoom(room('r1', updated: 1, unread: 2))
      ..seedRoom(room('r2', updated: 2, unread: 3, muted: true))
      ..seedRoom(room('r3', updated: 0, unread: 1, pinned: true));
    final inbox = h.kit.inbox();
    addTearDown(inbox.dispose);

    await until(() => !inbox.isLoading && inbox.rooms.length == 2);
    expect(inbox.hasMore, isTrue);
    await inbox.loadMore();
    await until(() => inbox.rooms.length == 3);
    expect(inbox.hasMore, isFalse);
    expect([for (final r in inbox.rooms) r.id], ['r3', 'r2', 'r1']);
    expect(inbox.totalUnread, 3);
  });

  test('search is debounced and filters by title', () async {
    h.source
      ..seedRoom(room('a', updated: 1, title: 'Alpha'))
      ..seedRoom(room('b', updated: 2, title: 'Beta'));
    final inbox = h.kit.inbox();
    await until(() => inbox.rooms.length == 2);

    inbox.search('al');
    expect(inbox.query, '');
    expect(inbox.hasPendingTimers, isTrue);
    await until(() => inbox.query == 'al');
    await until(() => inbox.rooms.length == 1);
    expect(inbox.rooms.single.title, 'Alpha');

    inbox
      ..search('be')
      ..dispose();
    expect(inbox.hasPendingTimers, isFalse);
  });

  test('pin is optimistic and reverted on rejection', () async {
    h.source
      ..seedRoom(room('r1', updated: 1))
      ..seedRoom(room('r2', updated: 2));
    final inbox = h.kit.inbox();
    addTearDown(inbox.dispose);
    await until(() => inbox.rooms.length == 2);

    await inbox.setPinned('r1', pinned: true);
    await until(() => inbox.rooms.first.id == 'r1');
    expect(h.source.pinCalls, [('r1', true)]);

    h.source.failNext = const PermissionFailure('room');
    await inbox.setMuted('r2', muted: true);
    expect(inbox.failure, isA<PermissionFailure>());
    await until(() => inbox.rooms.every((r) => !r.muted));
  });

  test('direct peers are resolved lazily', () async {
    h.source.seedRoom(room('d1', updated: 1, type: RoomType.direct));
    final inbox = h.kit.inbox();
    addTearDown(inbox.dispose);
    await until(() => inbox.rooms.isNotEmpty);
    await until(() => inbox.peerOf(inbox.rooms.single) != null);
    expect(inbox.peerOf(inbox.rooms.single)?.name, 'User peer-d1');
  });

  test('names from the backend show and follow their changes', () async {
    h.source
      ..people['peer-d1'] = const ChatUser(id: 'peer-d1', name: 'Sara')
      ..seedRoom(room('d1', updated: 1, type: RoomType.direct));
    final inbox = h.kit.inbox();
    addTearDown(inbox.dispose);
    await until(() => inbox.rooms.isNotEmpty);
    await until(() => inbox.peerOf(inbox.rooms.single)?.name == 'Sara');

    h.source.emit(
      const UsersChanged([
        ChatUser(id: 'peer-d1', name: 'Sara B', avatarUrl: 'new.png'),
      ]),
    );
    await until(() => inbox.peerOf(inbox.rooms.single)?.name == 'Sara B');
    expect(inbox.peerOf(inbox.rooms.single)?.avatarUrl, 'new.png');

    await h.kit.updateUsers([const ChatUser(id: 'peer-d1', name: 'Sara C')]);
    await until(() => inbox.peerOf(inbox.rooms.single)?.name == 'Sara C');
  });

  group('filters', () {
    void seedMixed() {
      h.source
        ..seedRoom(room('d1', updated: 1, type: RoomType.direct, unread: 1))
        ..seedRoom(room('d2', updated: 2, type: RoomType.direct))
        ..seedRoom(room('d3', updated: 3, type: RoomType.direct, unread: 4))
        ..seedRoom(room('g1', updated: 4, unread: 2))
        ..seedRoom(room('g2', updated: 5))
        ..seedRoom(room('c1', updated: 6, type: RoomType.channel));
    }

    List<String> ids(InboxController inbox) => [
      for (final r in inbox.rooms) r.id,
    ];

    test('two lists page, count and search independently', () async {
      seedMixed();
      final chats = h.kit.inbox(filter: RoomFilter.direct);
      final groups = h.kit.inbox(filter: RoomFilter.groups);
      addTearDown(chats.dispose);
      addTearDown(groups.dispose);

      await until(() => !chats.isLoading && !groups.isLoading);
      await until(() => chats.rooms.length == 2 && groups.rooms.length == 2);
      expect(ids(chats), ['d3', 'd2']);
      expect(ids(groups), ['c1', 'g2']);
      expect(h.source.roomFetchCalls.map((c) => c.filter).toSet(), {
        RoomFilter.direct,
        RoomFilter.groups,
      });

      await chats.loadMore();
      await until(() => chats.rooms.length == 3);
      expect(chats.hasMore, isFalse);
      expect(groups.hasMore, isTrue);
      expect(groups.rooms, hasLength(2));
      expect(chats.totalUnread, 5);

      await groups.loadMore();
      await until(() => groups.rooms.length == 3);
      expect(groups.totalUnread, 2);

      groups.search('g1');
      await until(() => groups.rooms.length == 1);
      expect(ids(chats), ['d3', 'd2', 'd1']);
    });

    test('setFilter switches the list and refetches', () async {
      seedMixed();
      final inbox = h.kit.inbox();
      addTearDown(inbox.dispose);
      await until(() => !inbox.isLoading && inbox.rooms.length == 2);

      inbox.setFilter(const RoomFilter(unreadOnly: true));
      expect(inbox.filter.unreadOnly, isTrue);
      await until(() => !inbox.isLoading);
      await inbox.loadMore();
      await until(() => inbox.rooms.length == 3);
      expect(ids(inbox), ['g1', 'd3', 'd1']);
      expect(h.source.roomFetchCalls.last.filter.unreadOnly, isTrue);
    });

    test('rooms are filtered locally when the backend ignores it', () async {
      seedMixed();
      h.source.ignoreRoomFilter = true;
      final chats = h.kit.inbox(filter: RoomFilter.direct);
      addTearDown(chats.dispose);
      await until(() => !chats.isLoading);
      // The first page held two groups only.
      expect(chats.rooms, isEmpty);
      expect(chats.hasMore, isTrue);
      while (chats.hasMore) {
        await chats.loadMore();
      }
      await until(() => chats.rooms.length == 3);
      expect(chats.rooms.every((r) => r.type == RoomType.direct), isTrue);
    });

    test('labels filter and room events land in the matching list', () async {
      h.source
        ..seedRoom(room('w1', updated: 1).copyWith(labels: {'work'}))
        ..seedRoom(room('p1', updated: 2).copyWith(labels: {'family'}));
      final work = h.kit.inbox(filter: const RoomFilter(labels: {'work'}));
      addTearDown(work.dispose);
      await until(() => !work.isLoading && work.rooms.length == 1);

      h.source.emit(
        RoomChanged(
          Created(room('w2', updated: 3).copyWith(labels: {'work', 'vip'})),
        ),
      );
      await until(() => work.rooms.length == 2);
      expect(ids(work), ['w2', 'w1']);
    });

    test('resync refreshes the first page of every open list', () async {
      seedMixed();
      final chats = h.kit.inbox(filter: RoomFilter.direct);
      final groups = h.kit.inbox(filter: RoomFilter.groups);
      addTearDown(chats.dispose);
      await until(() => !chats.isLoading && !groups.isLoading);
      await until(() => chats.rooms.isNotEmpty && groups.rooms.isNotEmpty);

      h.source.roomFetchCalls.clear();
      await h.kit.repository.resync();
      expect(h.source.roomFetchCalls.map((c) => (c.filter, c.after)).toSet(), {
        (RoomFilter.direct, null),
        (RoomFilter.groups, null),
      });

      groups.dispose();
      h.source.roomFetchCalls.clear();
      await h.kit.repository.resync();
      expect(h.source.roomFetchCalls.single.filter, RoomFilter.direct);
    });
  });

  test('a refresh failure is exposed and cleared by the next one', () async {
    h.source.failNext = const NetworkFailure();
    final inbox = h.kit.inbox();
    addTearDown(inbox.dispose);
    await until(() => !inbox.isLoading && inbox.failure != null);
    expect(inbox.failure, isA<NetworkFailure>());
    await inbox.refresh();
    expect(inbox.failure, isNull);
  });
}
