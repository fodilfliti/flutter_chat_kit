import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../controllers/harness.dart';
import 'widget_harness.dart';

ChatRoom groupRoom() => ChatRoom(
  id: 'r1',
  updatedAt: t0,
  type: RoomType.group,
  title: 'Team',
  members: const [
    RoomMember(userId: 'me'),
    RoomMember(userId: 'u2'),
    RoomMember(userId: 'u3'),
  ],
);

ChatRoom directRoom() => ChatRoom(
  id: 'r1',
  updatedAt: t0,
  members: const [
    RoomMember(userId: 'me'),
    RoomMember(userId: 'u2'),
  ],
);

ChatRoom inboxRoom(
  String id, {
  int updated = 0,
  int unread = 0,
  bool muted = false,
  bool pinned = false,
  Message? last,
}) => ChatRoom(
  id: id,
  updatedAt: at(updated),
  title: id,
  unreadCount: unread,
  muted: muted,
  pinned: pinned,
  lastMessage: last,
  members: [
    const RoomMember(userId: 'me'),
    RoomMember(userId: 'peer-$id'),
  ],
);

void main() {
  late Harness h;

  group('ChatRoomView', () {
    late ChatRoomController room;

    Future<void> open(
      WidgetTester tester,
      ChatRoom chatRoom, {
      List<Message> messages = const [],
      ChatAppBarOptions appBar = const ChatAppBarOptions(),
      Widget? header,
      ComposerController? composer,
    }) async {
      h = Harness();
      h.source
        ..seedRoom(chatRoom)
        ..seedMessages('r1', messages);
      await drive(tester, h.open());
      await drive(tester, h.kit.cache.upsertRooms([chatRoom]));
      room = h.kit.room('r1');
      await drive(tester, room.ready);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatRoomView(
            controller: room,
            composer: composer,
            appBar: appBar,
            header: header,
          ),
        ),
      );
      await settle(tester, until: () => room.room != null);
      await settle(tester);
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      room.dispose();
      await drive(tester, h.close());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('app bar shows the title, member count, actions and header', (
      tester,
    ) async {
      await open(
        tester,
        groupRoom(),
        appBar: const ChatAppBarOptions(
          actions: [Icon(Icons.call, key: Key('call'))],
        ),
        header: const Text('Pinned banner'),
      );
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('3 members'), findsOneWidget);
      expect(find.byKey(const Key('call')), findsOneWidget);
      expect(find.text('Pinned banner'), findsOneWidget);
      expect(find.byType(ChatComposer), findsOneWidget);
      await close(tester);
    });

    testWidgets('typing replaces the member count', (tester) async {
      await open(tester, groupRoom());
      h.source.emit(
        const TypingChanged(roomId: 'r1', userId: 'u2', typing: true),
      );
      await settle(tester, until: () => room.typingUserIds.isNotEmpty);
      await settle(tester, until: () => room.users.containsKey('u2'));
      await tester.pump();
      expect(find.text('User u2 is typing'), findsWidgets);
      expect(find.text('3 members'), findsNothing);
      await close(tester);
    });

    testWidgets('direct room shows the peer, online, then typing', (
      tester,
    ) async {
      await open(tester, directRoom());
      final inbox = h.kit.inbox();
      await settle(tester);
      expect(find.text('User u2'), findsOneWidget);

      h.source.emit(
        const PresenceChanged(Presence(userId: 'u2', isOnline: true)),
      );
      await settle(
        tester,
        until: () => find.text('online').evaluate().isNotEmpty,
      );

      h.source.emit(
        const TypingChanged(roomId: 'r1', userId: 'u2', typing: true),
      );
      await settle(tester, until: () => room.typingUserIds.isNotEmpty);
      await tester.pump();
      expect(find.text('online'), findsNothing);
      expect(find.text('User u2 is typing'), findsWidgets);
      inbox.dispose();
      await close(tester);
    });

    testWidgets('creates and disposes its own composer', (tester) async {
      await open(tester, groupRoom());
      final state = tester.state<ChatRoomViewState>(find.byType(ChatRoomView));
      final composer = state.composer;
      expect(identical(state.composer, composer), isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(
        () => ChangeNotifier.debugAssertNotDisposed(composer),
        throwsFlutterError,
      );
      room.dispose();
      await drive(tester, h.close());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('leaves a given composer alone', (tester) async {
      h = Harness();
      await drive(tester, h.open());
      final r = h.kit.room('r1');
      final composer = ComposerController(r);
      room = r;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatRoomView(controller: r, composer: composer),
        ),
      );
      await settle(tester);
      expect(
        tester.state<ChatRoomViewState>(find.byType(ChatRoomView)).composer,
        same(composer),
      );
      await tester.pumpWidget(const SizedBox());
      expect(ChangeNotifier.debugAssertNotDisposed(composer), isTrue);
      composer.dispose();
      room.dispose();
      await drive(tester, h.close());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('select from the actions sheet shows the selection bar', (
      tester,
    ) async {
      await open(tester, groupRoom(), messages: [msg(1, author: 'me')]);
      await settle(
        tester,
        until: () => find.text('r1-m001').evaluate().isNotEmpty,
      );
      await tester.longPress(find.text('r1-m001'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(room.selectedIds, {'r1-m001'});
      expect(find.byType(SelectionAppBar), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
      expect(find.byTooltip('Forward'), findsNothing);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(room.selectedIds, isEmpty);
      expect(find.byType(ChatAppBar), findsOneWidget);
      await close(tester);
    });

    testWidgets('delete in the selection bar deletes the selected message', (
      tester,
    ) async {
      await open(tester, groupRoom(), messages: [msg(1, author: 'me')]);
      await settle(tester, until: () => room.messages.isNotEmpty);
      room.toggleSelect('r1-m001');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete'));
      await settle(tester, until: () => h.source.deleteCalls.isNotEmpty);
      expect(h.source.deleteCalls.single, ('r1', 'r1-m001'));
      expect(room.selectedIds, isEmpty);
      await close(tester);
    });
  });

  group('InboxView', () {
    late InboxController inbox;
    late List<ChatRoom> tapped;

    Future<void> open(WidgetTester tester, List<ChatRoom> rooms) async {
      h = Harness();
      rooms.forEach(h.source.seedRoom);
      await drive(tester, h.open());
      inbox = h.kit.inbox();
      tapped = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InboxView(controller: inbox, onRoomTap: tapped.add),
          ),
        ),
      );
      await settle(tester, until: () => inbox.rooms.isNotEmpty);
      await settle(tester);
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      inbox.dispose();
      await drive(tester, h.close());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('tile shows the unread badge, muted and pinned icons', (
      tester,
    ) async {
      await open(tester, [
        inboxRoom('alpha', unread: 3, muted: true, pinned: true),
      ]);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      await close(tester);
    });

    testWidgets('preview is prefixed with You for my last message', (
      tester,
    ) async {
      await open(tester, [
        inboxRoom(
          'alpha',
          last: msg(1, room: 'alpha', author: 'me'),
        ),
      ]);
      expect(find.text('You: alpha-m001'), findsOneWidget);
      await close(tester);
    });

    testWidgets('tap calls onRoomTap', (tester) async {
      await open(tester, [inboxRoom('alpha')]);
      await tester.tap(find.text('alpha'));
      await tester.pump();
      expect([for (final r in tapped) r.id], ['alpha']);
      await close(tester);
    });

    testWidgets('search filters the rooms', (tester) async {
      await open(tester, [
        inboxRoom('alpha', updated: 2),
        inboxRoom('beta', updated: 1),
      ]);
      expect(find.text('beta'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'alp');
      await settle(tester, until: () => inbox.rooms.length == 1);
      await tester.pump();
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await settle(tester, until: () => inbox.rooms.length == 2);
      await close(tester);
    });

    testWidgets('empty search shows no results', (tester) async {
      await open(tester, [inboxRoom('alpha')]);
      await tester.enterText(find.byType(TextField), 'zzz');
      await settle(
        tester,
        until: () => inbox.rooms.isEmpty && !inbox.isLoading,
      );
      await tester.pump();
      expect(find.text('No results'), findsOneWidget);
      await close(tester);
    });

    testWidgets('loads the next page near the end', (tester) async {
      await open(tester, [
        for (var i = 0; i < 30; i++)
          inboxRoom('room${i.toString().padLeft(2, '0')}', updated: i),
      ]);
      // Page size is 2: the view keeps loading until the screen is full.
      await settle(tester, until: () => inbox.rooms.length >= 8);
      final filled = inbox.rooms.length;
      expect(filled, lessThan(30));

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -2000),
        3000,
      );
      await settle(tester, until: () => inbox.rooms.length > filled);
      await tester.pumpAndSettle();
      await close(tester);
    });

    testWidgets('swipe reveals pin and mute actions', (tester) async {
      await open(tester, [inboxRoom('alpha')]);
      await tester.drag(find.text('alpha'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mute'));
      await settle(tester, until: () => h.source.muteCalls.isNotEmpty);
      expect(h.source.muteCalls.single, ('alpha', true));
      await close(tester);
    });

    testWidgets('empty inbox shows the empty text', (tester) async {
      h = Harness();
      await drive(tester, h.open());
      inbox = h.kit.inbox();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InboxView(controller: inbox, onRoomTap: (_) {}),
          ),
        ),
      );
      await settle(
        tester,
        until: () => inbox.hasLoadedCache && !inbox.isLoading,
      );
      await tester.pump();
      expect(find.text('No conversations yet'), findsOneWidget);
      await close(tester);
    });
  });
}
