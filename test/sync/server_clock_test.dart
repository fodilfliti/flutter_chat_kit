import 'dart:async';

import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit/src/sync/server_clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cache/memory_cache.dart';
import '../source/fake_chat_source.dart';

final _t0 = DateTime.utc(2026, 9, 30, 12);

void main() {
  group('ServerClock', () {
    test('the offset is the median of recent estimates', () {
      var now = _t0;
      final clock = ServerClock(clock: () => now);
      expect(clock.offset, Duration.zero);

      void send(Duration serverAhead, {Duration trip = Duration.zero}) {
        final sentAt = now;
        now = now.add(trip);
        clock.record(
          sentAt: sentAt,
          answeredAt: now,
          serverTime: sentAt.add(trip ~/ 2).add(serverAhead),
        );
      }

      send(const Duration(minutes: -10), trip: const Duration(seconds: 1));
      expect(clock.offset, const Duration(minutes: -10));
      send(const Duration(minutes: -10));
      send(const Duration(minutes: 5)); // one odd answer
      expect(clock.offset, const Duration(minutes: -10));
      expect(clock.now(), now.subtract(const Duration(minutes: 10)));
    });

    test('slow requests and echoed client times are ignored', () {
      final clock = ServerClock(clock: () => _t0);
      clock
        ..record(
          sentAt: _t0,
          answeredAt: _t0.add(const Duration(seconds: 30)),
          serverTime: _t0.add(const Duration(hours: 1)),
        )
        ..record(
          sentAt: _t0,
          answeredAt: _t0,
          serverTime: _t0.add(const Duration(hours: 1)),
          clientTime: _t0.add(const Duration(hours: 1)),
        );
      expect(clock.offset, Duration.zero);
    });
  });

  test('a phone 10 minutes ahead stamps new messages in server time', () async {
    var serverNow = _t0;
    const skew = Duration(minutes: 10);
    final source = FakeChatSource()
      ..clock = (() => serverNow)
      ..seedMessages('r1', [
        TextMessage(
          id: 'm0',
          localId: 'm0',
          roomId: 'r1',
          authorId: 'u2',
          createdAt: _t0.subtract(const Duration(seconds: 5)),
          text: 'hi',
        ),
      ]);
    final kit = ChatKit(
      currentUserId: 'me',
      source: source,
      cache: memoryCache(),
      clock: () => serverNow.add(skew),
    );
    await kit.open();
    final room = kit.room('r1');
    await room.ready;

    await room.sendText('first');
    await kit.outbox.flush();
    expect(kit.serverNow(), serverNow);

    // A reply lands, then the user answers: the answer goes below it.
    serverNow = serverNow.add(const Duration(seconds: 3));
    source.receive(
      TextMessage(
        id: 'm1',
        localId: 'm1',
        roomId: 'r1',
        authorId: 'u2',
        createdAt: serverNow,
        text: 'reply',
      ),
    );
    serverNow = serverNow.add(const Duration(seconds: 1));
    source.sendGate = Completer();
    await room.sendText('answer');
    final pending = (await kit.cache.messages(
      'r1',
    )).firstWhere((m) => m is TextMessage && m.text == 'answer');
    expect(pending.createdAt, serverNow);
    final newestFirst = await kit.cache.messages('r1');
    expect((newestFirst.first as TextMessage).text, 'answer');

    source.sendGate!.complete();
    room.dispose();
    await kit.close();
    kit.dispose();
  });
}
