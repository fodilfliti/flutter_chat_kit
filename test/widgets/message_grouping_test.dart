import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../controllers/harness.dart';

void main() {
  const window = Duration(minutes: 3);
  const day = 86400;

  List<String> describe(List<ChatListItem> items) => [
    for (final item in items)
      switch (item) {
        MessageListItem(:final message, :final groupPosition) =>
          '${message.id.substring(3)}:${groupPosition.name}',
        DateSeparatorItem() => 'date',
        UnreadDividerItem() => 'unread',
      },
  ];

  test('runs by one author group; other authors and system messages split '
      'them', () {
    final messages = [
      msg(5, author: 'me'),
      msg(4),
      msg(3),
      msg(2),
      SystemMessage(
        id: 'r1-sys',
        localId: 'r1-sys',
        roomId: 'r1',
        authorId: 'u2',
        createdAt: at(1),
        code: 'joined',
      ),
      msg(0),
    ];
    final items = buildChatListItems(messages, groupingWindow: window);
    expect(describe(items), [
      'm005:single',
      'm004:last',
      'm003:middle',
      'm002:first',
      'sys:single',
      'm000:single',
      'date',
    ]);
  });

  test('messages further apart than the window do not group', () {
    final items = buildChatListItems([
      msg(2, second: 400),
      msg(1),
    ], groupingWindow: window);
    expect(describe(items), ['m002:single', 'm001:single', 'date']);
  });

  test('a separator sits above the first message of each day', () {
    final items = buildChatListItems([
      msg(3, second: day + 20),
      msg(2, second: day + 10),
      msg(1, second: 10),
    ], groupingWindow: window);
    expect(describe(items), [
      'm003:last',
      'm002:first',
      'date',
      'm001:single',
      'date',
    ]);
    final separators = items.whereType<DateSeparatorItem>().toList();
    expect(separators[0].day, localDay(at(day + 10)));
    expect(separators[0].key, isNot(separators[1].key));
  });

  test('the unread divider sits above its message, below the day', () {
    final items = buildChatListItems(
      [msg(2), msg(1)],
      groupingWindow: window,
      unreadDividerCursor: msg(1).cursor,
    );
    expect(describe(items), ['m002:last', 'm001:first', 'unread', 'date']);
  });

  test('no separator above the oldest loaded message before the start of '
      'history', () {
    final items = buildChatListItems(
      [msg(2), msg(1)],
      groupingWindow: window,
      isStartOfHistory: false,
    );
    expect(describe(items), ['m002:last', 'm001:first']);
  });
}
