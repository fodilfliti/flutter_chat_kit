import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';

import '../controllers/harness.dart';
import 'widget_harness.dart';

const _strings = ChatStrings();

MessageContext ctx(
  Message m, {
  bool mine = false,
  GroupPosition position = GroupPosition.single,
  Message? repliedTo,
}) {
  return MessageContext(
    message: m,
    currentUserId: 'me',
    isMine: mine,
    groupPosition: position,
    index: 0,
    uploadProgress: ValueNotifier<double?>(null),
    repliedTo: repliedTo,
  );
}

Future<void> show(WidgetTester tester, Widget child, {ThemeData? theme}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  );
}

CustomMessage offer({String type = 'offer'}) => CustomMessage(
  id: 'c1',
  localId: 'c1',
  roomId: 'r1',
  authorId: 'u2',
  createdAt: t0,
  customType: type,
  data: const {'price': 42},
);

void main() {
  group('MessageContent', () {
    testWidgets('a custom message renders through customBuilders', (
      tester,
    ) async {
      await show(
        tester,
        MessageContent(
          message: ctx(offer()),
          builders: ChatBuilders(
            customBuilders: {
              'offer': (context, m) =>
                  Text('Offer ${(m.message as CustomMessage).data['price']}'),
            },
          ),
        ),
      );
      expect(find.text('Offer 42'), findsOneWidget);
      expect(find.byType(UnsupportedMessageView), findsNothing);
    });

    testWidgets('a custom type without a builder renders unsupported', (
      tester,
    ) async {
      await show(tester, MessageContent(message: ctx(offer(type: 'poll'))));
      expect(find.byType(UnsupportedMessageView), findsOneWidget);
      expect(find.text(_strings.unsupportedMessage), findsOneWidget);
    });

    testWidgets('customBuilder resolves variants from the data', (
      tester,
    ) async {
      Widget? resolve(BuildContext context, MessageContext m) {
        final data = (m.message as CustomMessage).data;
        return data['price'] == 42 ? const Text('Priced offer') : null;
      }

      await show(
        tester,
        MessageContent(
          message: ctx(offer(type: 'anything')),
          builders: ChatBuilders(customBuilder: resolve),
        ),
      );
      expect(find.text('Priced offer'), findsOneWidget);
      expect(find.byType(MessageBubble), findsNothing);
    });

    testWidgets('customBuilders win over customBuilder; null falls back', (
      tester,
    ) async {
      final builders = ChatBuilders(
        customBuilders: {'offer': (context, m) => const Text('By type')},
        customBuilder: (context, m) => null,
      );
      await show(
        tester,
        MessageContent(message: ctx(offer()), builders: builders),
      );
      expect(find.text('By type'), findsOneWidget);

      await show(
        tester,
        MessageContent(
          message: ctx(offer(type: 'poll')),
          builders: builders,
        ),
      );
      expect(find.byType(UnsupportedMessageView), findsOneWidget);
    });

    testWidgets('bubbledCustomTypes render inside the default bubble', (
      tester,
    ) async {
      await show(
        tester,
        MessageContent(
          message: ctx(offer(), mine: true),
          builders: ChatBuilders(
            customBuilders: {'offer': (context, m) => const Text('Booking')},
            bubbledCustomTypes: const {'offer'},
          ),
        ),
      );
      final bubble = find.byType(MessageBubble);
      expect(bubble, findsOneWidget);
      expect(
        find.descendant(of: bubble, matching: find.text('Booking')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bubble, matching: find.byType(MessageMeta)),
        findsOneWidget,
      );
    });

    testWidgets('bubble style and scale come from the theme', (tester) async {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
      final chat = ChatTheme.fallback(scheme)
          .withMessageText(const TextStyle(fontSize: 14, color: Colors.grey))
          .mapBubbles(
            (b) => b.copyWith(
              radius: 10,
              tailRadius: 10,
              border: const BorderSide(color: Colors.red),
            ),
          )
          .scaled(2);
      await show(
        tester,
        MessageContent(message: ctx(msg(1))),
        theme: ThemeData(colorScheme: scheme, extensions: [chat]),
      );
      final style = tester
          .widget<TextMessageView>(find.byType(TextMessageView))
          .style;
      expect(style.fontSize, 28);
      expect(style.color, Colors.grey);

      final box = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(MessageBubble),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(
        box.borderRadius?.resolve(TextDirection.ltr),
        BorderRadius.circular(20),
      );
      expect(box.border, Border.all(color: Colors.red, width: 2));
    });

    testWidgets('bubble and per-type builders wrap the defaults', (
      tester,
    ) async {
      await show(
        tester,
        MessageContent(
          message: ctx(msg(1)),
          builders: ChatBuilders(
            bubbleBuilder: (context, m, child) =>
                KeyedSubtree(key: const Key('bubble'), child: child),
            textBuilder: (context, m, child) =>
                KeyedSubtree(key: const Key('text'), child: child),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('bubble')),
          matching: find.byType(MessageBubble),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('text')),
          matching: find.byType(TextMessageView),
        ),
        findsOneWidget,
      );
      expect(find.text(msg(1).text), findsOneWidget);
    });

    testWidgets('the reply preview shows the quoted message and taps', (
      tester,
    ) async {
      String? tapped;
      final reply = TextMessage(
        id: 'm9',
        localId: 'm9',
        roomId: 'r1',
        authorId: 'u2',
        createdAt: at(9),
        text: 'answer',
        replyToId: msg(1).id,
      );
      await show(
        tester,
        MessageContent(
          message: ctx(reply, repliedTo: msg(1).copyWith(authorId: 'me')),
          onReplyTap: (id) => tapped = id,
        ),
      );
      expect(find.text(_strings.you), findsOneWidget);
      await tester.tap(find.byType(ReplyPreview));
      expect(tapped, msg(1).id);
    });

    testWidgets('an unloaded quoted message shows the unavailable text', (
      tester,
    ) async {
      final reply = msg(2).copyWith(replyToId: 'gone');
      await show(tester, MessageContent(message: ctx(reply)));
      expect(find.text(_strings.replyUnavailable), findsOneWidget);
    });

    testWidgets('reaction chips highlight mine and toggle on tap', (
      tester,
    ) async {
      final toggled = <String>[];
      final m = msg(1).copyWith(
        reactions: {
          '👍': {'u2', 'u3'},
          '❤️': {'me'},
        },
      );
      await show(
        tester,
        MessageContent(message: ctx(m), onReactionTap: toggled.add),
      );
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel(_strings.reaction('❤️', 1))),
        matchesSemantics(
          label: _strings.reaction('❤️', 1),
          isSelected: true,
          hasSelectedState: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text('👍'));
      expect(toggled, ['👍']);
      handle.dispose();
    });

    testWidgets('a failed message of mine shows retry', (tester) async {
      var retried = 0;
      final m = msg(1, author: 'me').copyWith(status: MessageStatus.failed);
      await show(
        tester,
        MessageContent(message: ctx(m, mine: true), onRetry: () => retried++),
      );
      expect(find.text(_strings.failedToSend), findsOneWidget);
      await tester.tap(find.text(_strings.retry));
      expect(retried, 1);
    });

    testWidgets('deleted messages show the placeholder and no reactions', (
      tester,
    ) async {
      final m = msg(1).copyWith(
        deletedAt: at(5),
        reactions: {
          '👍': {'u2'},
        },
      );
      await show(tester, MessageContent(message: ctx(m)));
      expect(find.text(_strings.messageDeleted), findsOneWidget);
      expect(find.byType(ReactionsBar), findsNothing);
    });

    testWidgets('system messages render as a pill without a bubble', (
      tester,
    ) async {
      final m = SystemMessage(
        id: 's1',
        localId: 's1',
        roomId: 'r1',
        authorId: 'u2',
        createdAt: t0,
        code: 'joined',
        args: const {'text': 'Ana joined'},
      );
      await show(tester, MessageContent(message: ctx(m)));
      expect(find.text('Ana joined'), findsOneWidget);
      expect(find.byType(MessageBubble), findsNothing);
    });

    testWidgets('edited messages show the label', (tester) async {
      await show(
        tester,
        MessageContent(message: ctx(msg(1).copyWith(editedAt: at(3)))),
      );
      expect(find.text(_strings.edited), findsOneWidget);
    });

    testWidgets('file messages show the name and size', (tester) async {
      final m = FileMessage(
        id: 'f1',
        localId: 'f1',
        roomId: 'r1',
        authorId: 'u2',
        createdAt: t0,
        file: const Attachment(
          mimeType: 'application/pdf',
          name: 'report.pdf',
          size: 2048,
          remoteUrl: 'https://x/report.pdf',
        ),
      );
      Attachment? opened;
      await show(
        tester,
        MessageContent(
          message: ctx(m),
          onAttachmentTap: (message, file) => opened = file,
        ),
      );
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('2 KB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      await tester.tap(find.text('report.pdf'));
      expect(opened?.name, 'report.pdf');
    });
  });

  group('StatusTicks', () {
    testWidgets('each status has a semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (status, label) in [
        (MessageStatus.pending, _strings.statusPending),
        (MessageStatus.sent, _strings.statusSent),
        (MessageStatus.delivered, _strings.statusDelivered),
        (MessageStatus.seen, _strings.statusSeen),
        (MessageStatus.failed, _strings.failedToSend),
      ]) {
        await show(tester, StatusTicks(status: status));
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      handle.dispose();
    });
  });

  group('TextMessageView', () {
    test('detects emoji-only texts', () {
      expect(TextMessageView.isEmojiOnly('😀'), isTrue);
      expect(TextMessageView.isEmojiOnly('👍🏽 ❤️'), isTrue);
      expect(TextMessageView.isEmojiOnly('🇩🇿'), isTrue);
      expect(TextMessageView.isEmojiOnly('😀😀😀😀'), isFalse);
      expect(TextMessageView.isEmojiOnly('hi 😀'), isFalse);
      expect(TextMessageView.isEmojiOnly('123'), isFalse);
      expect(TextMessageView.isEmojiOnly(''), isFalse);
    });

    test('turns links, e-mails and phone numbers into URIs', () {
      Uri? first(String text) {
        final match = TextMessageView.linkPattern.firstMatch(text);
        return match == null ? null : TextMessageView.uriOf(match);
      }

      expect(
        first('see www.example.com/a?b=1.'),
        Uri.parse('https://www.example.com/a?b=1'),
      );
      expect(first('(https://x.io/p)'), Uri.parse('https://x.io/p'));
      expect(
        first('mail ana@example.org'),
        Uri.parse('mailto:ana@example.org'),
      );
      expect(first('call +213 555 12 34 56'), Uri.parse('tel:+213555123456'));
      expect(first('on 2026-09'), isNull);
    });

    testWidgets('tapping a link reports its URI', (tester) async {
      Uri? tapped;
      await show(
        tester,
        TextMessageView(
          text: 'open www.example.com now',
          style: const TextStyle(fontSize: 16),
          onLinkTap: (uri) => tapped = uri,
        ),
      );
      await tester.tapOnText(find.textRange.ofSubstring('www.example.com'));
      expect(tapped, Uri.parse('https://www.example.com'));
    });

    testWidgets('long texts collapse behind read more', (tester) async {
      final long = List.filled(50, 'word').join(' ');
      await show(
        tester,
        TextMessageView(
          text: long,
          style: const TextStyle(fontSize: 16),
          collapseAfter: 20,
        ),
      );
      expect(find.textContaining(_strings.readMore), findsOneWidget);
      await tester.tapOnText(find.textRange.ofSubstring(_strings.readMore));
      await tester.pump();
      expect(find.textContaining(_strings.readLess), findsOneWidget);
      expect(find.textContaining(long), findsOneWidget);
    });
  });

  group('MessageBubble', () {
    test('tail and group corners sit on the author side', () {
      final theme = ChatTheme.fallback(const ColorScheme.light());
      final big = Radius.circular(theme.outgoingBubble.radius);
      final small = Radius.circular(theme.outgoingBubble.tailRadius);
      final first = MessageBubble.radiusFor(
        GroupPosition.first,
        isMine: true,
        theme: theme,
      );
      expect(first.topEnd, big);
      expect(first.bottomEnd, small);
      expect(first.topStart, big);
      final middle = MessageBubble.radiusFor(
        GroupPosition.middle,
        isMine: false,
        theme: theme,
      );
      expect(middle.topStart, small);
      expect(middle.bottomStart, small);
      expect(middle.topEnd, big);
    });
  });

  group('MessageActionsSheet.defaults', () {
    List<String> ids(MessageContext m) => [
      for (final a in MessageActionsSheet.defaults(
        message: m,
        onReply: () {},
        onCopy: () {},
        onEdit: () {},
        onRetry: () {},
        onDelete: () {},
      ))
        a.id,
    ];

    test('filters by author and state', () {
      expect(ids(ctx(msg(1))), [MessageAction.replyId, MessageAction.copyId]);
      expect(ids(ctx(msg(1, author: 'me'), mine: true)), [
        MessageAction.replyId,
        MessageAction.copyId,
        MessageAction.editId,
        MessageAction.deleteId,
      ]);
      final failed = msg(
        1,
        author: 'me',
      ).copyWith(status: MessageStatus.failed);
      expect(ids(ctx(failed, mine: true)), [
        MessageAction.copyId,
        MessageAction.retryId,
        MessageAction.deleteId,
      ]);
      expect(ids(ctx(msg(1).copyWith(deletedAt: at(2)))), isEmpty);
    });
  });

  testWidgets('dragging past the threshold replies', (tester) async {
    var replies = 0;
    await show(
      tester,
      SwipeToReply(
        onReply: () => replies++,
        child: const SizedBox(height: 40, child: Text('row')),
      ),
    );
    await tester.drag(find.text('row'), const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(replies, 0);
    await tester.drag(find.text('row'), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(replies, 1);
  });

  group('in the message list', () {
    late Harness h;
    late ChatRoomController room;

    Future<void> open(
      WidgetTester tester,
      List<Message> messages, {
      ChatBuilders builders = const ChatBuilders(),
    }) async {
      h = Harness(
        config: const ChatConfig(highlightDuration: Duration(seconds: 30)),
      );
      h.source.seedMessages('r1', messages);
      await drive(tester, h.open());
      room = h.kit.room('r1');
      await drive(tester, room.ready);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageList(controller: room, builders: builders),
          ),
        ),
      );
      await settle(tester);
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      room.dispose();
      await drive(tester, h.close());
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('tapping a reply preview jumps to the quoted message', (
      tester,
    ) async {
      final reply = msg(5).copyWith(replyToId: msg(1).id);
      await open(tester, [for (var i = 0; i < 5; i++) msg(i), reply]);
      await settle(tester, until: () => room.users.containsKey('u2'));
      expect(
        find.descendant(
          of: find.byType(ReplyPreview),
          matching: find.text('User u2'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(ReplyPreview));
      await settle(
        tester,
        until: () => room.highlightedId.value == msg(1).localId,
      );
      await finishAnimations(tester);
      await close(tester);
    });

    testWidgets('long press opens the actions sheet with app actions', (
      tester,
    ) async {
      var reported = 0;
      await open(
        tester,
        [msg(0), msg(1)],
        builders: ChatBuilders(
          messageActions: (context, m, defaults) => [
            ...defaults,
            MessageAction(
              id: 'report',
              label: 'Report',
              icon: Icons.flag_outlined,
              onTap: () => reported++,
            ),
          ],
        ),
      );
      await tester.longPress(find.text(msg(1).text));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MessageActionsSheet), findsOneWidget);
      expect(find.text(_strings.copy), findsOneWidget);
      expect(find.text(_strings.delete), findsNothing);
      expect(find.text('👍'), findsOneWidget);

      await tester.tap(find.text('Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(reported, 1);
      expect(find.byType(MessageActionsSheet), findsNothing);
      await close(tester);
    });

    testWidgets('while selecting, taps toggle selection', (tester) async {
      await open(tester, [msg(0), msg(1)]);
      room.toggleSelect(msg(0).localId);
      await settle(tester);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.tap(find.text(msg(1).text));
      await settle(tester);
      expect(room.selectedIds, {msg(0).localId, msg(1).localId});
      await close(tester);
    });
  });
}
