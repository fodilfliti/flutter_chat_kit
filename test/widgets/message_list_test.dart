import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../controllers/harness.dart';
import 'widget_harness.dart';

const _config = ChatConfig(
  highlightDuration: Duration(seconds: 30),
  typingTimeout: Duration(seconds: 30),
);

void main() {
  late Harness h;
  late ChatRoomController room;

  Future<void> open(WidgetTester tester, List<Message> messages) async {
    h = Harness(config: _config);
    h.source.seedMessages('r1', messages);
    await drive(tester, h.open());
    room = h.kit.room('r1');
    await drive(tester, room.ready);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatMessageList(controller: room)),
      ),
    );
    await settle(tester);
  }

  Future<void> openWith(WidgetTester tester, {int count = 100}) =>
      open(tester, [for (var i = 0; i < count; i++) msg(i)]);

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    room.dispose();
    await drive(tester, h.close());
    await tester.pump(const Duration(seconds: 3));
  }

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  void expectAtBottom(WidgetTester tester) {
    final p = position(tester);
    expect(p.pixels, moreOrLessEquals(p.minScrollExtent));
  }

  ChatMessageListState listState(WidgetTester tester) =>
      tester.state<ChatMessageListState>(find.byType(ChatMessageList));

  Offset topOf(WidgetTester tester, int i) =>
      tester.getTopLeft(find.text(msg(i).text));

  Future<void> scrollUp(WidgetTester tester, double by) async {
    await tester.drag(find.byType(Scrollable).first, Offset(0, by));
    await settle(tester);
  }

  testWidgets('starts at the newest message with the button hidden', (
    tester,
  ) async {
    await openWith(tester);
    expect(find.text(msg(99).text), findsOneWidget);
    expectAtBottom(tester);
    expect(listState(tester).showsScrollToBottom.value, isFalse);
    await close(tester);
  });

  testWidgets('loading older messages keeps the visible ones in place', (
    tester,
  ) async {
    await openWith(tester);
    await scrollUp(tester, 300);
    final visible = _visibleIndex(tester);
    final before = topOf(tester, visible);
    final count = room.messages.length;

    await drive(tester, room.loadOlder());
    await settle(tester);
    expect(room.messages.length, greaterThan(count));
    expect(topOf(tester, visible), before);
    await close(tester);
  });

  testWidgets('an incoming message while scrolled up keeps the list still '
      'and counts on the badge', (tester) async {
    await openWith(tester);
    await scrollUp(tester, 300);
    expect(room.isAtBottom, isFalse);
    final visible = _visibleIndex(tester);
    final before = topOf(tester, visible);

    h.source.receive(msg(100));
    await settle(tester, until: () => room.messages.first.id == msg(100).id);
    await settle(tester);
    expect(topOf(tester, visible), before);
    expect(room.newMessagesCount.value, 1);
    expect(find.text('1'), findsOneWidget);
    await close(tester);
  });

  testWidgets('an incoming message at the bottom scrolls into view', (
    tester,
  ) async {
    await openWith(tester);
    h.source.receive(msg(100));
    await settle(tester, until: () => room.messages.first.id == msg(100).id);
    await finishAnimations(tester);
    expectAtBottom(tester);
    expect(find.text(msg(100).text), findsOneWidget);
    expect(room.newMessagesCount.value, 0);
    await close(tester);
  });

  testWidgets('my own message scrolls to the bottom', (tester) async {
    await openWith(tester);
    await scrollUp(tester, 300);
    expect(room.isAtBottom, isFalse);

    await drive(tester, room.sendText('mine'));
    await settle(tester, until: () => room.messages.first.authorId == 'me');
    await finishAnimations(tester);
    expectAtBottom(tester);
    expect(find.text('mine'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the button returns to the bottom', (tester) async {
    await openWith(tester);
    await scrollUp(tester, 400);
    expect(listState(tester).showsScrollToBottom.value, isTrue);

    await tester.tap(find.byType(ScrollToBottomButton));
    await settle(tester);
    await finishAnimations(tester);
    expectAtBottom(tester);
    expect(listState(tester).showsScrollToBottom.value, isFalse);
    await close(tester);
  });

  testWidgets('jumping to an unloaded message fetches around it and '
      'highlights it', (tester) async {
    await openWith(tester, count: 300);
    final found = await drive(
      tester,
      listState(tester).jumpToMessage(msg(20).id),
    );
    await finishAnimations(tester);

    expect(found, isTrue);
    expect(h.source.aroundCalls, [('r1', msg(20).id)]);
    expect(room.isDetached, isTrue);
    expect(find.text(msg(20).text), findsOneWidget);
    final list = tester.getRect(find.byType(CustomScrollView));
    final target = tester.getCenter(find.text(msg(20).text));
    expect((target.dy - list.center.dy).abs(), lessThan(list.height / 4));
    expect(room.highlightedId.value, msg(20).localId);
    final row = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(msg(20).text),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(
      (row.decoration as BoxDecoration?)?.color,
      ChatTheme.of(tester.element(find.text(msg(20).text))).highlightColor,
    );
    await close(tester);
  });

  testWidgets('day separators and the start of history show', (tester) async {
    await open(tester, [msg(0), msg(1, second: 86400), msg(2, second: 86410)]);
    expect(find.byType(DateSeparator), findsNWidgets(2));
    expect(find.text(const ChatStrings().startOfConversation), findsOneWidget);
    await close(tester);
  });

  testWidgets('typing shows at the bottom; empty rooms show the empty text', (
    tester,
  ) async {
    await openWith(tester, count: 0);
    expect(find.text(const ChatStrings().noMessages), findsOneWidget);

    h.source.emit(
      const TypingChanged(roomId: 'r1', userId: 'u2', typing: true),
    );
    await settle(tester, until: () => room.users.containsKey('u2'));
    await settle(tester);
    expect(find.byType(TypingIndicator), findsOneWidget);
    expect(find.text('User u2 is typing'), findsOneWidget);
    await close(tester);
  });
}

/// A message index whose text is on screen, near the middle.
int _visibleIndex(WidgetTester tester) {
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (var i = 99; i >= 0; i--) {
    final finder = find.text(msg(i).text);
    if (finder.evaluate().isEmpty) continue;
    final y = tester.getTopLeft(finder).dy;
    if (y > height * 0.3 && y < height * 0.6) return i;
  }
  fail('no message near the middle of the screen');
}
