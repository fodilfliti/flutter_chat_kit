import 'package:flutter_chat_kit/flutter_chat_kit.dart';
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
