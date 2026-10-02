import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cache/memory_cache.dart';
import '../controllers/harness.dart';
import '../source/fake_chat_source.dart';
import '../widgets/widget_harness.dart';

const _personal = ChatProfile(id: 'ali', name: 'Ali');
const _shop = ChatProfile(
  id: 'shop',
  name: 'Lemsa Shop',
  kind: ChatProfileKind.business,
  agentId: 'ali',
  unreadCount: 3,
);
const _cafe = ChatProfile(
  id: 'cafe',
  name: 'Cafe',
  kind: ChatProfileKind.business,
  agentId: 'ali',
);

TextMessage _text(
  String id, {
  required String author,
  String? sentBy,
  int second = 0,
}) => TextMessage(
  id: id,
  localId: id,
  roomId: 'r1',
  authorId: author,
  sentBy: sentBy,
  createdAt: at(second),
  text: 'text $id',
);

/// Creates a kit per profile and records what happened to each.
class _Kits {
  final List<ChatKit> created = [];
  final List<String> cleared = [];
  final Set<String> failing = {};

  ChatKit create(ChatProfile profile) {
    final kit = _TestKit(this, profile);
    created.add(kit);
    return kit;
  }

  List<String> get ids => [for (final k in created) k.currentUserId];
}

class _TestKit extends ChatKit {
  _TestKit(this._kits, ChatProfile profile)
    : super(
        currentUserId: profile.id,
        agentId: profile.agentId,
        source: FakeChatSource(),
        cache: memoryCache(),
      );

  final _Kits _kits;

  @override
  Future<void> open() async {
    if (_kits.failing.contains(currentUserId)) {
      throw StateError('cannot open $currentUserId');
    }
    await super.open();
  }

  @override
  Future<void> clearUserData() async {
    _kits.cleared.add(currentUserId);
    await super.clearUserData();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Message.sentBy', () {
    final message = _text('m1', author: 'shop', sentBy: 'sara');

    test('round-trips through JSON and copyWith', () {
      const codec = MessageCodec();
      final json = codec.encode(message);
      expect(json['sent_by'], 'sara');
      expect(codec.decode(json), message);
      final plain = codec.encode(_text('m2', author: 'u2'));
      expect(plain.containsKey('sent_by'), isFalse);

      expect(message.copyWith(text: 'x').sentBy, 'sara');
      expect(message.copyWith(sentBy: 'omar').sentBy, 'omar');
      expect(message == message.copyWith(sentBy: 'omar'), isFalse);
    });

    test('is kept by the cache', () async {
      final cache = memoryCache();
      await cache.open('shop');
      await cache.upsertMessages([message]);
      final stored = await cache.messageByAnyId('m1');
      expect(stored?.sentBy, 'sara');
      await cache.close();
    });

    test('splits message groups', () {
      final a = _text('a', author: 'shop', sentBy: 'sara', second: 1);
      final b = _text('b', author: 'shop', sentBy: 'ali', second: 2);
      final c = _text('c', author: 'shop', sentBy: 'ali', second: 3);
      const window = Duration(minutes: 3);
      expect(
        GroupPosition.of(a, window: window, newer: b),
        GroupPosition.single,
      );
      expect(
        GroupPosition.of(b, window: window, older: a, newer: c),
        GroupPosition.first,
      );
    });
  });

  group('ChatKit.agentId', () {
    test('is stamped on sent messages', () async {
      final h = Harness(currentUserId: 'shop', agentId: 'ali');
      await h.open();
      final room = h.kit.room('r1');
      await room.ready;

      await room.sendText('hello');
      await until(() => room.messages.length == 1);
      expect(room.messages.single.sentBy, 'ali');
      await h.kit.outbox.flush();
      await until(() => h.source.sent.isNotEmpty);
      expect(h.source.sent.single.sentBy, 'ali');

      room.dispose();
      await h.close();
    });

    test('leaves sentBy empty on personal profiles', () async {
      final h = Harness();
      await h.open();
      final room = h.kit.room('r1');
      await room.ready;
      await room.sendText('hello');
      await h.kit.outbox.flush();
      await until(() => h.source.sent.isNotEmpty);
      expect(h.source.sent.single.sentBy, isNull);
      room.dispose();
      await h.close();
    });

    test('colleagues are resolved as users', () async {
      final h = Harness(currentUserId: 'shop', agentId: 'ali');
      h.source.seedMessages('r1', [
        _text('m1', author: 'shop', sentBy: 'sara'),
      ]);
      await h.open();
      final room = h.kit.room('r1');
      await room.ready;
      await until(() => room.users.containsKey('sara'));
      room.dispose();
      await h.close();
    });
  });

  group('MessageContext', () {
    MessageContext contextOf(Message m, {String? agentId}) => MessageContext(
      message: m,
      currentUserId: 'shop',
      agentId: agentId,
      isMine: m.authorId == 'shop',
      groupPosition: GroupPosition.single,
      index: 0,
      uploadProgress: ValueNotifier(null),
    );

    test('isSentByMe tells my messages from colleagues', () {
      final mine = contextOf(
        _text('a', author: 'shop', sentBy: 'ali'),
        agentId: 'ali',
      );
      final colleague = contextOf(
        _text('b', author: 'shop', sentBy: 'sara'),
        agentId: 'ali',
      );
      final plain = contextOf(_text('c', author: 'shop'));
      final customer = contextOf(_text('d', author: 'u2'), agentId: 'ali');

      expect(mine.isSentByMe, isTrue);
      expect(colleague.isSentByMe, isFalse);
      expect(colleague.isSentByColleague, isTrue);
      expect(plain.isSentByMe, isTrue);
      expect(customer.isSentByMe, isFalse);
      expect(customer.isSentByColleague, isFalse);
    });
  });

  group('RoomTile.previewOf', () {
    RoomContext contextOf(String? sentBy) => RoomContext(
      room: ChatRoom(
        id: 'r1',
        updatedAt: t0,
        lastMessage: _text('m1', author: 'shop', sentBy: sentBy),
      ),
      currentUserId: 'shop',
      agentId: 'ali',
      index: 0,
      lastMessageSender: sentBy == null
          ? null
          : ChatUser(id: sentBy, name: sentBy == 'sara' ? 'Sara' : 'Ali'),
    );

    test('names the colleague who answered', () {
      const strings = ChatStrings();
      expect(RoomTile.previewOf(contextOf('sara'), strings), 'Sara: text m1');
      expect(RoomTile.previewOf(contextOf('ali'), strings), 'You: text m1');
      expect(RoomTile.previewOf(contextOf(null), strings), 'You: text m1');
    });
  });

  group('ChatProfileSwitcher', () {
    late _Kits kits;
    late ChatProfileSwitcher switcher;

    setUp(() {
      kits = _Kits();
      switcher = ChatProfileSwitcher(
        profiles: const [_personal, _shop, _cafe],
        createKit: kits.create,
      );
    });

    tearDown(() async {
      await switcher.close();
      switcher.dispose();
    });

    test('rejects empty, duplicate or unknown profiles', () {
      expect(
        () => ChatProfileSwitcher(profiles: const [], createKit: kits.create),
        throwsArgumentError,
      );
      expect(
        () => ChatProfileSwitcher(
          profiles: const [_personal, _personal],
          createKit: kits.create,
        ),
        throwsArgumentError,
      );
      expect(
        () => ChatProfileSwitcher(
          profiles: const [_personal],
          createKit: kits.create,
          initialProfileId: 'nope',
        ),
        throwsArgumentError,
      );
    });

    test('opens only the active profile and swaps kits on switch', () async {
      expect(switcher.active, _personal);
      expect(switcher.kit, isNull);

      await switcher.open();
      final first = switcher.kit!;
      expect(first.currentUserId, 'ali');
      expect(first.agentId, isNull);
      expect(first.isOpen, isTrue);

      var notified = 0;
      switcher.addListener(() => notified++);
      await switcher.switchTo('shop');
      final second = switcher.kit!;
      expect(switcher.active, _shop);
      expect(second.currentUserId, 'shop');
      expect(second.agentId, 'ali');
      expect(second.isOpen, isTrue);
      expect(first.isOpen, isFalse);
      expect(notified, greaterThanOrEqualTo(2));

      await switcher.switchTo('shop');
      expect(switcher.kit, same(second));
      expect(kits.ids, ['ali', 'shop']);
    });

    test('switch requests run in order', () async {
      await switcher.open();
      final a = switcher.switchTo('shop');
      final b = switcher.switchTo('cafe');
      await Future.wait([a, b]);
      expect(switcher.active, _cafe);
      expect(kits.ids, ['ali', 'shop', 'cafe']);
      expect(kits.created.where((k) => k.isOpen), [switcher.kit]);
    });

    test('a failed switch keeps the previous profile', () async {
      await switcher.open();
      final first = switcher.kit;
      kits.failing.add('shop');
      await expectLater(switcher.switchTo('shop'), throwsStateError);
      expect(switcher.active, _personal);
      expect(switcher.kit, same(first));
      expect(switcher.isSwitching, isFalse);
      expect(() => switcher.switchTo('nope'), throwsArgumentError);
    });

    test('switching while closed only changes the active profile', () async {
      await switcher.switchTo('cafe');
      expect(switcher.active, _cafe);
      expect(kits.created, isEmpty);
      await switcher.open();
      expect(switcher.kit!.currentUserId, 'cafe');
    });

    test('setOnline reaches the active kit and the next ones', () async {
      await switcher.open();
      switcher.setOnline(online: false);
      expect(switcher.kit!.isOnline, isFalse);
      await switcher.switchTo('shop');
      expect(switcher.kit!.isOnline, isFalse);
      switcher.setOnline(online: true);
      expect(switcher.kit!.isOnline, isTrue);
    });

    test('setProfiles updates, falls back and clears removed data', () async {
      await switcher.open();
      await switcher.switchTo('shop');

      await switcher.setProfiles([_personal, _shop.copyWith(unreadCount: 9)]);
      expect(switcher.active.unreadCount, 9);
      expect(kits.cleared, ['cafe']);

      await switcher.setProfiles([_personal]);
      expect(switcher.active, _personal);
      expect(switcher.kit!.currentUserId, 'ali');
      expect(kits.cleared, ['cafe', 'shop']);

      await switcher.setProfiles([_personal, _cafe], clearRemoved: false);
      expect(switcher.profiles, [_personal, _cafe]);
      expect(kits.cleared, ['cafe', 'shop']);
    });

    test('clearAllUserData closes and wipes every profile', () async {
      await switcher.open();
      final kit = switcher.kit!;
      await kit.cache.upsertMessages([_text('m1', author: 'u2')]);

      await switcher.clearAllUserData();
      expect(switcher.kit, isNull);
      expect(kit.isOpen, isFalse);
      expect(kits.cleared, ['ali', 'shop', 'cafe']);
    });
  });

  group('widgets', () {
    testWidgets('ChatProfileScope rebuilds the chat tree on switch', (
      tester,
    ) async {
      final kits = _Kits();
      final switcher = ChatProfileSwitcher(
        profiles: const [_personal, _shop],
        createKit: kits.create,
      );
      final seen = <String>[];
      var inits = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ChatProfileScope(
            switcher: switcher,
            placeholder: const Text('closed'),
            child: _Probe(
              // Like the app's navigator: moved, not rebuilt, on re-keying.
              key: GlobalKey(),
              onInit: () => inits++,
              onBuild: (kit) => seen.add(kit.currentUserId),
            ),
          ),
        ),
      );
      expect(find.text('closed'), findsOneWidget);

      await drive(tester, switcher.open());
      await tester.pump();
      expect(seen.last, 'ali');
      expect(inits, 1);

      await drive(tester, switcher.switchTo('shop'));
      await tester.pump();
      expect(seen.last, 'shop');
      expect(inits, 2);
      expect(kits.created.first.isOpen, isFalse);

      await drive(tester, switcher.close());
      await tester.pump();
      expect(find.text('closed'), findsOneWidget);
      switcher.dispose();
    });

    testWidgets('ChatProfileMenuButton lists profiles and switches', (
      tester,
    ) async {
      final kits = _Kits();
      final switcher = ChatProfileSwitcher(
        profiles: const [_personal, _shop],
        createKit: kits.create,
      );
      await drive(tester, switcher.open());

      await tester.pumpWidget(
        MaterialApp(
          home: ChatProfileScope(
            switcher: switcher,
            child: Scaffold(
              appBar: AppBar(actions: const [ChatProfileMenuButton()]),
            ),
          ),
        ),
      );
      expect(find.byType(Badge), findsOneWidget);

      await tester.tap(find.byType(ChatProfileMenuButton));
      await tester.pumpAndSettle();
      expect(find.text('Lemsa Shop'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Lemsa Shop'));
      await settle(tester, until: () => switcher.active.id == 'shop');
      await settle(tester, until: () => !kits.created.first.isOpen);
      expect(switcher.kit!.currentUserId, 'shop');

      await drive(tester, switcher.close());
      switcher.dispose();
    });

    testWidgets('staff see who answered; customers do not', (tester) async {
      Future<void> check(
        Harness h, {
        required String waitFor,
        required Matcher sara,
      }) async {
        h.source.seedMessages('r1', [
          _text('m1', author: 'shop', sentBy: 'sara', second: 1),
          _text('m2', author: 'shop', sentBy: 'ali', second: 2),
          _text('m3', author: 'u2', second: 3),
        ]);
        await drive(tester, h.open());
        final room = h.kit.room('r1');
        await drive(tester, room.ready);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ChatMessageList(controller: room)),
          ),
        );
        await settle(tester, until: () => room.users.containsKey(waitFor));
        await settle(tester);
        expect(find.text('User sara'), sara);
        expect(find.text('User ali'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        room.dispose();
        await drive(tester, h.close());
      }

      await check(
        Harness(currentUserId: 'shop', agentId: 'ali'),
        waitFor: 'sara',
        sara: findsOneWidget,
      );
      await check(
        Harness(currentUserId: 'u2'),
        waitFor: 'shop',
        sara: findsNothing,
      );
      await tester.pump(const Duration(seconds: 3));
    });
  });
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onInit, required this.onBuild, super.key});

  final VoidCallback onInit;
  final void Function(ChatKit kit) onBuild;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild(context.chatKit);
    return const SizedBox();
  }
}
