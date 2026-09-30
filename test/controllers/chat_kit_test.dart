import 'package:flutter/widgets.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

import '../cache/memory_cache.dart';
import '../source/fake_chat_source.dart';

final _t0 = DateTime.utc(2026, 9, 30, 12);

TextMessage _msg(String id, int second) => TextMessage(
  id: id,
  localId: id,
  roomId: 'r1',
  authorId: 'u2',
  createdAt: _t0.add(Duration(seconds: second)),
  text: id,
);

void main() {
  group('ChatKit', () {
    test('open, online state and media capability', () async {
      final opened = <String>[];
      final kit = ChatKit(
        currentUserId: 'me',
        source: FakeChatSource(),
        cache: memoryCache(opened: opened),
      );
      expect(kit.isOpen, isFalse);
      expect(kit.canSendMedia, isFalse);

      await kit.open();
      expect(kit.isOpen, isTrue);
      expect(kit.cache.isOpen, isTrue);
      expect(opened, ['me']);

      var notified = 0;
      kit
        ..addListener(() => notified++)
        ..setOnline(online: false)
        ..setOnline(online: false);
      expect(kit.isOnline, isFalse);
      expect(notified, 1);

      await kit.close();
      expect(kit.isOpen, isFalse);
      expect(kit.cache.isOpen, isFalse);
      kit.dispose();
    });

    test('clearUserData wipes the cache', () async {
      final kit = ChatKit(
        currentUserId: 'me',
        source: FakeChatSource(),
        cache: memoryCache(),
      );
      await kit.open();
      await kit.cache.upsertMessages([_msg('m1', 1)]);
      await kit.clearUserData();
      expect(await kit.cache.messageByAnyId('m1'), isNull);
      await kit.close();
      kit.dispose();
    });
  });

  group('ChatKitScope', () {
    testWidgets('of finds the kit; maybeOf is null outside', (tester) async {
      final kit = ChatKit(currentUserId: 'me', source: FakeChatSource());
      ChatKit? found;
      ChatKit? outside;

      await tester.pumpWidget(
        Builder(
          builder: (outer) {
            outside = ChatKitScope.maybeOf(outer);
            return ChatKitScope(
              kit: kit,
              child: Builder(
                builder: (inner) {
                  found = inner.chatKit;
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );

      expect(found, same(kit));
      expect(outside, isNull);
      kit.dispose();
    });
  });

  group('FakeChatSource contract', () {
    late FakeChatSource source;

    setUp(() {
      source = FakeChatSource()
        ..seedMessages('r1', [for (var i = 0; i < 10; i++) _msg('m$i', i)]);
    });

    tearDown(() => source.dispose());

    test('latest page is newest first', () async {
      final page = await source.fetchMessages('r1', limit: 3);
      expect(page.items.map((m) => m.id), ['m9', 'm8', 'm7']);
      expect(page.hasMore, isTrue);
    });

    test('before and after are exclusive keyset bounds', () async {
      final older = await source.fetchMessages(
        'r1',
        before: _msg('m5', 5).cursor,
        limit: 2,
      );
      expect(older.items.map((m) => m.id), ['m4', 'm3']);

      final newer = await source.fetchMessages(
        'r1',
        after: _msg('m5', 5).cursor,
        limit: 2,
      );
      expect(newer.items.map((m) => m.id), ['m7', 'm6']);
      expect(newer.hasMore, isTrue);
    });

    test('send is idempotent on localId and echoes an event', () async {
      final events = <ChatEvent>[];
      final sub = source.events(roomId: 'r1').listen(events.add);
      final pending = TextMessage(
        id: 'l1',
        localId: 'l1',
        roomId: 'r1',
        authorId: 'me',
        createdAt: _t0,
        text: 'hi',
        status: MessageStatus.pending,
      );

      final a = await source.send(pending);
      final b = await source.send(pending);
      await pumpEventQueue();

      expect(a, b);
      expect(a.status, MessageStatus.sent);
      expect(a.localId, 'l1');
      expect(events, hasLength(1));
      await sub.cancel();
    });

    test('failNext throws once', () async {
      source.failNext = const NetworkFailure();
      await expectLater(
        source.fetchMessages('r1'),
        throwsA(isA<NetworkFailure>()),
      );
      expect((await source.fetchMessages('r1')).items, isNotEmpty);
    });
  });
}
