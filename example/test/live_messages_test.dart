import 'dart:math';

import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_chat_pro_example/fake/fake_chat_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// Messages that became a room's last message, from someone else than [me].
Stream<Message> _incoming(FakeChatSource source, String me) => source
    .events()
    .map(
      (event) => switch (event) {
        RoomChanged(change: Updated(item: final room)) => room.lastMessage,
        _ => null,
      },
    )
    .where((m) => m != null && m.authorId != me)
    .cast<Message>()
    .distinct((a, b) => a.id == b.id);

/// Awaiting straight in the test body would wait on microtasks that only
/// run during a frame.
Future<void> _dispose(WidgetTester tester, FakeChatSource source) async {
  source.dispose().ignore();
  await tester.pump();
}

void main() {
  // testWidgets for its fake clock: minutes pass in no time.
  testWidgets('live messages arrive from others until turned off', (
    tester,
  ) async {
    final source = FakeChatSource(random: Random(7));
    final incoming = <Message>[];
    final sub = _incoming(
      source,
      FakeChatSource.personalId,
    ).listen(incoming.add);

    await tester.pump(const Duration(seconds: 30));
    expect(incoming, isEmpty);

    source.liveMessages = true;
    await tester.pump(const Duration(minutes: 1));
    expect(incoming.length, greaterThanOrEqualTo(5));
    expect(incoming.map((m) => m.roomId), isNot(contains('history')));

    // Off and on again keeps a single stream of messages, not two.
    source
      ..liveMessages = false
      ..liveMessages = true;
    final before = incoming.length;
    await tester.pump(const Duration(minutes: 1));
    expect(incoming.length - before, inInclusiveRange(5, 20));

    source.liveMessages = false;
    await tester.pump(const Duration(seconds: 10));
    final stopped = incoming.length;
    await tester.pump(const Duration(minutes: 1));
    expect(incoming.length, stopped);

    sub.cancel().ignore();
    await _dispose(tester, source);
  });

  testWidgets('the shop hears from its customers', (tester) async {
    final source = FakeChatSource(random: Random(3), me: FakeChatSource.shopId)
      ..liveMessages = true;
    final rooms = <String>{};
    final sub = _incoming(
      source,
      FakeChatSource.shopId,
    ).listen((m) => rooms.add(m.roomId));

    await tester.pump(const Duration(minutes: 1));
    expect(rooms, isNotEmpty);
    expect(rooms, everyElement(isIn(['omar', 'nadia'])));

    sub.cancel().ignore();
    await _dispose(tester, source);
  });
}
