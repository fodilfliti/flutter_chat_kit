import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const window = Duration(minutes: 3);
  final t0 = DateTime(2026, 9, 30, 12);

  Message text(String id, String author, Duration offset) => TextMessage(
    id: id,
    localId: id,
    roomId: 'r',
    authorId: author,
    createdAt: t0.add(offset),
    text: id,
  );

  GroupPosition pos(Message m, {Message? older, Message? newer}) =>
      GroupPosition.of(m, window: window, older: older, newer: newer);

  test('run of one author: first, middle, last', () {
    final a = text('a', 'u1', Duration.zero);
    final b = text('b', 'u1', const Duration(minutes: 1));
    final c = text('c', 'u1', const Duration(minutes: 2));
    expect(pos(a, newer: b), GroupPosition.first);
    expect(pos(b, older: a, newer: c), GroupPosition.middle);
    expect(pos(c, older: b), GroupPosition.last);
  });

  test('author change, time gap and system messages break runs', () {
    final a = text('a', 'u1', Duration.zero);
    final other = text('b', 'u2', const Duration(minutes: 1));
    final late = text('c', 'u1', const Duration(minutes: 10));
    final sys = SystemMessage(
      id: 's',
      localId: 's',
      roomId: 'r',
      authorId: 'u1',
      createdAt: t0.add(const Duration(seconds: 30)),
      code: 'joined',
    );
    expect(pos(a, newer: other), GroupPosition.single);
    expect(pos(late, older: a), GroupPosition.single);
    expect(pos(a, newer: sys), GroupPosition.single);
  });

  test('day boundary breaks runs', () {
    final night = TextMessage(
      id: 'n',
      localId: 'n',
      roomId: 'r',
      authorId: 'u1',
      createdAt: DateTime(2026, 9, 29, 23, 59),
      text: 'n',
    );
    final morning = night.copyWith(
      id: 'm',
      localId: 'm',
      createdAt: DateTime(2026, 9, 30, 0, 1),
    );
    expect(pos(morning, older: night), GroupPosition.single);
  });

  test('isFirst and isLast helpers', () {
    expect(GroupPosition.single.isFirst && GroupPosition.single.isLast, true);
    expect(GroupPosition.middle.isFirst || GroupPosition.middle.isLast, false);
  });
}
