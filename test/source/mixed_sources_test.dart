import 'dart:async';

import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

import '../cache/memory_cache.dart';
import '../controllers/harness.dart';
import 'fake_chat_source.dart';

class _RecordingRealtime implements ChatRealtime {
  final events$ = StreamController<ChatEvent>.broadcast();
  final List<String?> listened = [];
  final List<(String, bool)> typing = [];

  @override
  Stream<ChatEvent> events({String? roomId}) {
    listened.add(roomId);
    return events$.stream;
  }

  @override
  Future<void> setTyping(String roomId, {required bool typing}) async {
    this.typing.add((roomId, typing));
  }
}

const _tick = Duration(milliseconds: 20);

String _describe(ChatEvent event) => switch (event) {
  MessageChanged(change: Created(:final item)) => '+${item.id}',
  MessageChanged(change: Updated(:final item)) => '~${item.id}',
  MessageChanged(change: Deleted(:final id)) => '-$id',
  RoomChanged(change: Created(:final item)) => '+${item.id}',
  RoomChanged(change: Updated(:final item)) => '~${item.id}',
  RoomChanged(change: Deleted(:final id)) => '-$id',
  UsersChanged(:final users) => '@${[for (final u in users) u.name]}',
  _ => event.runtimeType.toString(),
};

void main() {
  late FakeChatSource data;

  setUp(() => data = FakeChatSource());
  tearDown(() => data.dispose());

  group('ComposedChatSource', () {
    test('reads data from one side and events from the other', () async {
      final realtime = _RecordingRealtime();
      addTearDown(realtime.events$.close);
      final source = ComposedChatSource(data: data, realtime: realtime);
      data
        ..seedRoom(ChatRoom(id: 'r1', updatedAt: t0, type: RoomType.group))
        ..seedMessages('r1', [msg(1), msg(2)]);

      final rooms = await source.fetchRooms(filter: RoomFilter.groups);
      expect(rooms.items.single.id, 'r1');
      expect(data.roomFetchCalls.single.filter, RoomFilter.groups);
      expect((await source.fetchMessages('r1')).items, hasLength(2));
      expect(await source.fetchAround('r1', msg(1).id), isNotNull);
      await source.markRead('r1', msg(2).cursor);
      await source.setPinned('r1', pinned: true);
      await source.setMuted('r1', muted: true);
      await source.react('r1', msg(1).id, 'x', add: true);
      expect(data.markReadCalls, hasLength(1));
      expect(data.pinCalls, [('r1', true)]);
      expect(data.muteCalls, [('r1', true)]);
      expect(data.reactCalls, hasLength(1));

      final seen = <ChatEvent>[];
      final sub = source.events(roomId: 'r1').listen(seen.add);
      realtime.events$.add(
        MessageChanged(roomId: 'r1', change: Created(msg(3))),
      );
      await until(() => seen.length == 1);
      await sub.cancel();
      expect(realtime.listened, ['r1']);

      await source.setTyping('r1', typing: true);
      expect(realtime.typing, [('r1', true)]);
      expect(data.typingCalls, isEmpty);
    });
  });

  group('PollingRealtime', () {
    test('an open room emits new and changed messages once', () async {
      data.seedMessages('r1', [msg(1), msg(2), msg(3)]);
      final polling = PollingRealtime(data, roomInterval: _tick, pageSize: 5);
      final seen = <String>[];
      final sub = polling
          .events(roomId: 'r1')
          .listen((e) => seen.add(_describe(e)));
      addTearDown(sub.cancel);

      await until(() => seen.length == 3);
      expect(seen, ['+r1-m001', '+r1-m002', '+r1-m003']);

      data.failNext = const NetworkFailure();
      await Future<void>.delayed(_tick * 2);
      data.seedMessages('r1', [msg(4)]);
      await until(() => seen.length == 4);
      expect(seen.last, '+r1-m004');

      await data.edit(msg(2).copyWith(text: 'edited'));
      await until(() => seen.length == 5);
      expect(seen.last, '~r1-m002');

      await Future<void>.delayed(_tick * 3);
      expect(seen, hasLength(5));
    });

    test('a burst larger than one page is read forward in order', () async {
      data.seedMessages('r1', [msg(1), msg(2)]);
      final polling = PollingRealtime(data, roomInterval: _tick, pageSize: 3);
      final seen = <String>[];
      final sub = polling
          .events(roomId: 'r1')
          .listen((e) => seen.add(_describe(e)));
      addTearDown(sub.cancel);
      await until(() => seen.length == 2);

      data.seedMessages('r1', [for (var i = 3; i <= 10; i++) msg(i)]);
      await until(() => seen.length == 10);
      expect(seen, [for (var i = 1; i <= 10; i++) '+${msg(i).id}']);
      expect(data.fetchCalls.any((c) => c.after == msg(2).cursor), isTrue);
    });

    test('the inbox emits rooms that changed', () async {
      data
        ..seedRoom(ChatRoom(id: 'a', updatedAt: at(1)))
        ..seedRoom(ChatRoom(id: 'b', updatedAt: at(2)));
      final polling = PollingRealtime(data, inboxInterval: _tick);
      final seen = <String>[];
      final sub = polling.events().listen((e) => seen.add(_describe(e)));
      addTearDown(sub.cancel);

      await until(() => seen.length == 2);
      expect(seen, ['~a', '~b']);

      data.seedRoom(ChatRoom(id: 'a', updatedAt: at(3), unreadCount: 1));
      await until(() => seen.length == 3);
      expect(seen.last, '~a');
      await Future<void>.delayed(_tick * 3);
      expect(seen, hasLength(3));
    });

    test('users sent with polled pages are emitted when they change', () async {
      data
        ..people['u2'] = const ChatUser(id: 'u2', name: 'Sara')
        ..seedMessages('r1', [msg(1)]);
      final polling = PollingRealtime(data, roomInterval: _tick);
      final seen = <String>[];
      final sub = polling
          .events(roomId: 'r1')
          .listen((e) => seen.add(_describe(e)));
      addTearDown(sub.cancel);

      await until(() => seen.length == 2);
      expect(seen, ['@[Sara]', '+r1-m001']);

      data.people['u2'] = const ChatUser(id: 'u2', name: 'Sara B');
      await until(() => seen.length == 3);
      expect(seen.last, '@[Sara B]');
      await Future<void>.delayed(_tick * 3);
      expect(seen, hasLength(3));
    });

    test('polling stops when the stream is cancelled', () async {
      final polling = PollingRealtime(data, roomInterval: _tick);
      final sub = polling.events(roomId: 'r1').listen((_) {});
      await until(() => data.fetchCalls.length >= 2);
      await sub.cancel();
      final calls = data.fetchCalls.length;
      await Future<void>.delayed(_tick * 4);
      expect(data.fetchCalls.length, calls);
    });

    test('a kit on REST plus polling shows messages from others', () async {
      data.seedMessages('r1', [msg(1), msg(2)]);
      final kit = ChatKit(
        currentUserId: 'me',
        source: ComposedChatSource(
          data: data,
          realtime: PollingRealtime(data, roomInterval: _tick),
        ),
        cache: memoryCache(),
      );
      await kit.open();
      addTearDown(kit.close);
      final room = kit.room('r1');
      addTearDown(room.dispose);

      await until(() => room.messages.length == 2);
      data.seedMessages('r1', [msg(3)]);
      await until(() => room.messages.length == 3);
      expect(room.messages.map((m) => m.id), contains(msg(3).id));
    });
  });
}
