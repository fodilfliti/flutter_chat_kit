import 'dart:async';
import 'dart:math';

import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// An in-memory backend that behaves like a real one: latency, keyset
/// pages, realtime events, simulated replies with typing and read receipts,
/// an offline switch and random failures.
///
/// A real app implements `ChatSource` the same way over Firestore,
/// Supabase or REST (see `doc/adapters/`).
///
/// [me] is the profile the source acts as: the personal profile, or the
/// shop (a business profile answered by several staff members).
class FakeChatSource with ChatSourceDefaults implements ChatSource {
  FakeChatSource({Random? random, this.me = personalId})
    : _random = random ?? Random() {
    _seed();
  }

  /// The signed-in account's personal profile; also its staff id when it
  /// answers for the shop.
  static const personalId = 'me';
  static const shopId = 'shop';

  final String me;

  static const users = <String, ChatUser>{
    personalId: ChatUser(id: personalId, name: 'You'),
    shopId: ChatUser(
      id: shopId,
      name: 'Lemsa Shop',
      avatarUrl: 'https://picsum.photos/seed/lemsa-shop/150',
      metadata: {'business': true},
    ),
    'sara': ChatUser(id: 'sara', name: 'Sara (staff)'),
    'omar': ChatUser(
      id: 'omar',
      name: 'Omar Khelifi',
      avatarUrl: 'https://i.pravatar.cc/150?u=omar',
    ),
    'nadia': ChatUser(id: 'nadia', name: 'Nadia Saidi'),
    'amina': ChatUser(
      id: 'amina',
      name: 'Amina Haddad',
      avatarUrl: 'https://i.pravatar.cc/150?u=amina',
    ),
    'karim': ChatUser(
      id: 'karim',
      name: 'Karim Benali',
      avatarUrl: 'https://i.pravatar.cc/150?u=karim',
    ),
    'lina': ChatUser(
      id: 'lina',
      name: 'Lina Mansouri',
      avatarUrl: 'https://i.pravatar.cc/150?u=lina',
    ),
    'sam': ChatUser(id: 'sam', name: 'Sam Carter'),
  };

  static const historySize = 5000;

  final Random _random;
  final _rooms = <String, ChatRoom>{};

  /// Newest first.
  final _messages = <String, List<Message>>{};
  final _confirmed = <String, Message>{};
  final _presence = <String, Presence>{};
  final _events = StreamController<ChatEvent>.broadcast();
  final _timers = <Timer>{};
  int _seq = 0;

  /// When false every call throws `NetworkFailure`, like a lost connection.
  bool online = true;

  /// Makes about a third of the sends fail, to show retry.
  bool randomFailures = false;

  DateTime _now() => DateTime.now().toUtc();

  Future<void> dispose() async {
    for (final timer in _timers) {
      timer.cancel();
    }
    await _events.close();
  }

  // ------------------------------------------------------------ ChatSource

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) async {
    await _call();
    final q = search?.trim().toLowerCase();
    final rooms =
        _rooms.values
            .where((room) => q == null || q.isEmpty || _matches(room, q))
            .where(filter.matches)
            .where((room) => after == null || room.cursor.compareTo(after) < 0)
            .toList()
          ..sort((a, b) => b.cursor.compareTo(a.cursor));
    return ChatPage(
      items: rooms.take(limit).toList(),
      hasMore: rooms.length > limit,
    );
  }

  @override
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) async {
    await _call();
    final all = _messages[roomId] ?? const [];
    if (after != null) {
      final newer = all.where((m) => m.cursor.isAfter(after)).toList();
      final oldestFirst = newer.reversed.take(limit).toList();
      return ChatPage(
        items: oldestFirst.reversed.toList(),
        hasMore: newer.length > limit,
      );
    }
    final older = before == null
        ? all
        : all.where((m) => m.cursor.isBefore(before)).toList();
    return ChatPage(
      items: older.take(limit).toList(),
      hasMore: older.length > limit,
    );
  }

  @override
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  }) async {
    await _call();
    final all = _messages[roomId] ?? const [];
    final index = all.indexWhere((m) => m.matches(messageId));
    if (index < 0) throw NotFoundFailure('message:$messageId');
    final start = max(0, index - limit ~/ 2);
    final end = min(all.length, start + limit);
    return ChatPage(items: all.sublist(start, end), hasMore: end < all.length);
  }

  @override
  Stream<ChatEvent> events({String? roomId}) {
    if (roomId == null) {
      return Stream.multi((controller) {
        for (final presence in _presence.values) {
          controller.add(PresenceChanged(presence));
        }
        final sub = _events.stream
            .where(
              (e) =>
                  e is RoomChanged || e is PresenceChanged || e is UsersChanged,
            )
            .listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    return _events.stream.where(
      (e) => switch (e) {
        MessageChanged(roomId: final id) => id == roomId,
        TypingChanged(roomId: final id) => id == roomId,
        ReceiptChanged(roomId: final id) => id == roomId,
        RoomChanged() || PresenceChanged() || UsersChanged() => false,
      },
    );
  }

  @override
  Future<Message> send(Message pending) async {
    await _call(mayFail: true);
    // Idempotent on localId: a retry after a lost response returns the
    // message stored the first time.
    final existing = _confirmed[pending.localId];
    if (existing != null) return existing;
    final confirmed = pending.copyWith(
      id: 'srv-${++_seq}',
      status: MessageStatus.sent,
      createdAt: _now(),
    );
    _confirmed[pending.localId] = confirmed;
    _insert(confirmed);
    _simulatePeer(confirmed);
    return confirmed;
  }

  @override
  Future<Message> edit(Message message) async {
    await _call();
    final edited = message.copyWith(editedAt: _now());
    _replace(edited);
    return edited;
  }

  @override
  Future<void> delete(String roomId, String messageId) async {
    await _call();
    final message = _find(roomId, messageId);
    if (message == null) throw NotFoundFailure('message:$messageId');
    _replace(message.copyWith(deletedAt: _now()));
  }

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) async {
    await _call();
    final room = _rooms[roomId];
    if (room == null) return;
    _updateRoom(
      room.copyWith(
        unreadCount: 0,
        members: [
          for (final m in room.members)
            if (m.userId == me) m.copyWith(lastReadAt: upTo.createdAt) else m,
        ],
      ),
    );
  }

  @override
  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  }) async {
    await _call();
    final message = _find(roomId, messageId);
    if (message == null) return;
    final reactions = {
      for (final e in message.reactions.entries) e.key: {...e.value},
    };
    final users = reactions.putIfAbsent(emoji, () => {});
    add ? users.add(me) : users.remove(me);
    if (users.isEmpty) reactions.remove(emoji);
    _replace(message.copyWith(reactions: reactions));
  }

  @override
  Future<void> setPinned(String roomId, {required bool pinned}) async {
    await _call();
    final room = _rooms[roomId];
    if (room != null) _updateRoom(room.copyWith(pinned: pinned));
  }

  @override
  Future<void> setMuted(String roomId, {required bool muted}) async {
    await _call();
    final room = _rooms[roomId];
    if (room != null) _updateRoom(room.copyWith(muted: muted));
  }

  // -------------------------------------------------------------- helpers

  Future<void> _call({bool mayFail = false}) async {
    await Future<void>.delayed(
      Duration(milliseconds: 120 + _random.nextInt(250)),
    );
    if (!online) throw const NetworkFailure();
    if (mayFail && randomFailures && _random.nextDouble() < 0.35) {
      throw const NetworkFailure();
    }
  }

  bool _matches(ChatRoom room, String q) {
    if ((room.title ?? '').toLowerCase().contains(q)) return true;
    return room.members.any(
      (m) =>
          m.userId != me &&
          (users[m.userId]?.name.toLowerCase().contains(q) ?? false),
    );
  }

  Message? _find(String roomId, String id) {
    for (final m in _messages[roomId] ?? const <Message>[]) {
      if (m.matches(id)) return m;
    }
    return null;
  }

  void _insert(Message message) {
    final list = _messages.putIfAbsent(message.roomId, () => []);
    list.insert(0, message);
    _events.add(
      MessageChanged(roomId: message.roomId, change: Created(message)),
    );
    final room = _rooms[message.roomId];
    if (room != null) {
      _updateRoom(
        room.copyWith(
          lastMessage: message,
          updatedAt: message.createdAt,
          unreadCount: message.authorId == me ? 0 : room.unreadCount + 1,
        ),
      );
    }
  }

  void _replace(Message message) {
    final list = _messages[message.roomId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.matches(message.id));
    if (index < 0) return;
    list[index] = message;
    _events.add(
      MessageChanged(roomId: message.roomId, change: Updated(message)),
    );
    final room = _rooms[message.roomId];
    if (room != null && room.lastMessage?.localId == message.localId) {
      _updateRoom(room.copyWith(lastMessage: message));
    }
  }

  void _updateRoom(ChatRoom room) {
    _rooms[room.id] = room;
    _events.add(RoomChanged(Updated(room)));
  }

  void _later(Duration delay, void Function() action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (!_events.isClosed) action();
    });
    _timers.add(timer);
  }

  /// Delivered, read, typing, then a reply from another member.
  void _simulatePeer(Message sent) {
    final room = _rooms[sent.roomId];
    if (room == null) return;
    final others = [
      for (final m in room.members)
        if (m.userId != me) m.userId,
    ];
    if (others.isEmpty) return;
    final peer = others[_random.nextInt(others.length)];
    final roomId = room.id;

    void receipt({DateTime? deliveredAt, DateTime? readAt}) {
      final current = _rooms[roomId];
      if (current == null) return;
      _events.add(
        ReceiptChanged(
          roomId: roomId,
          userId: peer,
          deliveredAt: deliveredAt,
          readAt: readAt,
        ),
      );
      _updateRoom(
        current.copyWith(
          members: [
            for (final m in current.members)
              if (m.userId == peer)
                m.copyWith(
                  lastDeliveredAt: deliveredAt ?? m.lastDeliveredAt,
                  lastReadAt: readAt ?? m.lastReadAt,
                )
              else
                m,
          ],
        ),
      );
    }

    _later(const Duration(milliseconds: 600), () {
      if (online) receipt(deliveredAt: _now());
    });
    _later(const Duration(milliseconds: 1500), () {
      if (online) receipt(deliveredAt: _now(), readAt: _now());
    });
    if (roomId == 'history') return;
    _later(const Duration(milliseconds: 1900), () {
      if (!online) return;
      _events.add(TypingChanged(roomId: roomId, userId: peer, typing: true));
    });
    _later(const Duration(milliseconds: 3800), () {
      _events.add(TypingChanged(roomId: roomId, userId: peer, typing: false));
      if (!online) return;
      final id = 'srv-${++_seq}';
      _insert(
        TextMessage(
          id: id,
          localId: id,
          roomId: roomId,
          authorId: peer,
          sentBy: peer == shopId ? 'sara' : null,
          createdAt: _now(),
          text: _replyTo(sent),
          replyToId: _random.nextInt(4) == 0 ? sent.id : null,
        ),
      );
    });
  }

  String _replyTo(Message message) {
    return switch (message) {
      ImageMessage() => 'Nice photo! 😍',
      VideoMessage() => 'Watching it now 🎬',
      AudioMessage() => 'Got your voice note, one sec',
      FileMessage() => 'Thanks, I will read it tonight',
      CustomMessage(customType: 'offer') => 'Can you do a bit less? 🙂',
      CustomMessage(customType: 'booking') => 'Works for me, see you then 👍',
      _ => _replies[_random.nextInt(_replies.length)],
    };
  }

  static const _replies = [
    'Sounds good 👍',
    'Haha, true',
    'Let me check and get back to you',
    'On my way!',
    'Can we talk later? In a meeting',
    'Perfect, see you then',
    '😂😂',
    'I was thinking the same thing',
  ];

  // ----------------------------------------------------------------- seed

  void _seed() {
    final now = _now();
    DateTime ago(Duration d) => now.subtract(d);

    var n = 0;
    Message text(
      String room,
      String author,
      Duration before,
      String body, {
      String? replyTo,
      String? sentBy,
    }) {
      final id = '$room-${++n}';
      return TextMessage(
        id: id,
        localId: id,
        roomId: room,
        authorId: author,
        sentBy: sentBy,
        createdAt: ago(before),
        text: body,
        replyToId: replyTo,
      );
    }

    ChatRoom room(
      String id,
      List<String> members, {
      RoomType type = RoomType.direct,
      String? title,
      int unread = 0,
      bool pinned = false,
      bool muted = false,
      Set<String> labels = const {},
    }) {
      final messages = _messages[id]!;
      return ChatRoom(
        id: id,
        type: type,
        title: title,
        labels: labels,
        updatedAt: messages.first.createdAt,
        lastMessage: messages.first,
        unreadCount: unread,
        pinned: pinned,
        muted: muted,
        members: [
          for (final m in [me, ...members])
            RoomMember(
              userId: m,
              lastReadAt: messages.first.createdAt,
              lastDeliveredAt: messages.first.createdAt,
            ),
        ],
      );
    }

    if (me == shopId) {
      // The shop's customers. Replies are signed by the staff member who
      // wrote them (`sentBy`): Sara, or you when you answer for the shop.
      _messages
        ..['omar'] = _newestFirst([
          text(
            'omar',
            'omar',
            const Duration(hours: 5),
            'Hi, is the blue jacket still available?',
          ),
          text(
            'omar',
            shopId,
            const Duration(hours: 4, minutes: 50),
            'Hello Omar! Yes, in M and L.',
            sentBy: 'sara',
          ),
          text(
            'omar',
            'omar',
            const Duration(hours: 4, minutes: 40),
            'Great, I will take an M',
          ),
          text(
            'omar',
            shopId,
            const Duration(hours: 1),
            'Reserved for you 👍',
            sentBy: personalId,
          ),
          text('omar', 'omar', const Duration(minutes: 5), 'Thanks! 🙏'),
        ])
        ..['nadia'] = _newestFirst([
          text(
            'nadia',
            'nadia',
            const Duration(minutes: 30),
            'What time do you open tomorrow?',
          ),
          text(
            'nadia',
            shopId,
            const Duration(minutes: 28),
            'From 9am to 7pm 🙂',
            sentBy: 'sara',
          ),
        ]);
      for (final r in [
        room('omar', ['omar'], unread: 1),
        room('nadia', ['nadia']),
      ]) {
        _rooms[r.id] = r;
      }
      return;
    }

    _presence['amina'] = const Presence(userId: 'amina', isOnline: true);
    _presence['karim'] = Presence(
      userId: 'karim',
      isOnline: false,
      lastSeenAt: ago(const Duration(minutes: 25)),
    );

    final amina = <Message>[
      text(
        'amina',
        'amina',
        const Duration(days: 1, hours: 2),
        'Hey! Are we still on for Saturday?',
      ),
      text(
        'amina',
        me,
        const Duration(days: 1, hours: 2, minutes: -3),
        'Yes! 10am at the usual place?',
      ),
      text(
        'amina',
        'amina',
        const Duration(days: 1, hours: 1),
        'Perfect. I will bring the map 🗺️',
      ),
      ImageMessage(
        id: 'amina-photo',
        localId: 'amina-photo',
        roomId: 'amina',
        authorId: 'amina',
        createdAt: ago(const Duration(hours: 3)),
        caption: 'The view from last time',
        images: const [
          Attachment(
            mimeType: 'image/jpeg',
            remoteUrl: 'https://picsum.photos/seed/lemsa-view/1200/800',
            width: 1200,
            height: 800,
          ),
        ],
      ),
      text(
        'amina',
        me,
        const Duration(hours: 2, minutes: 50),
        'Wow, that is beautiful',
      ),
      text(
        'amina',
        'amina',
        const Duration(minutes: 12),
        'Also, check the link: https://flutter.dev',
      ),
      text(
        'amina',
        'amina',
        const Duration(minutes: 11),
        'Swipe right on a message to reply 😉',
        replyTo: 'amina-1',
      ),
    ];

    final karim = <Message>[
      text('karim', me, const Duration(days: 3), 'Did you push the fix?'),
      text(
        'karim',
        'karim',
        const Duration(days: 3, minutes: -20),
        'Yes, it is on main now',
      ),
      text('karim', me, const Duration(days: 2), 'Thanks 🙏'),
    ];

    final trip = <Message>[
      SystemMessage(
        id: 'trip-created',
        localId: 'trip-created',
        roomId: 'trip',
        authorId: 'amina',
        createdAt: ago(const Duration(days: 5)),
        code: 'room_created',
        // The app translates `code` with `name` and `title`; `text` is
        // the fallback for codes it does not know.
        args: const {
          'name': 'Amina',
          'title': 'Weekend trip',
          'text': 'Amina created the group "Weekend trip"',
        },
      ),
      text('trip', 'amina', const Duration(days: 4), 'Who is driving?'),
      text(
        'trip',
        'karim',
        const Duration(days: 4, minutes: -5),
        'I can drive, 4 seats',
      ),
      text(
        'trip',
        'lina',
        const Duration(days: 4, minutes: -8),
        'Count me in!',
      ),
      CustomMessage(
        id: 'trip-offer',
        localId: 'trip-offer',
        roomId: 'trip',
        authorId: 'karim',
        createdAt: ago(const Duration(hours: 5)),
        customType: 'offer',
        data: const {
          'variant': 'product',
          'title': 'Camping tent (4 people)',
          'amount': 45,
          'currency': 'USD',
        },
      ),
      text(
        'trip',
        'lina',
        const Duration(hours: 1),
        'Long press a message for reactions and more',
      ),
    ];

    // You as a customer of a business: its replies come from the shop, and
    // the staff member who wrote them stays hidden.
    final shop = <Message>[
      text(
        shopId,
        me,
        const Duration(days: 2, hours: 1),
        'Hi! Do you deliver to Oran?',
      ),
      text(
        shopId,
        shopId,
        const Duration(days: 2),
        'Hello! Yes, delivery takes 2 to 3 days.',
        sentBy: 'sara',
      ),
      text(
        shopId,
        me,
        const Duration(days: 1, hours: 3),
        'Can you engrave a name on the wallet?',
      ),
      // Same `offer` type as the tent in "Weekend trip", another card.
      CustomMessage(
        id: 'shop-quote',
        localId: 'shop-quote',
        roomId: shopId,
        authorId: shopId,
        sentBy: 'sara',
        createdAt: ago(const Duration(days: 1, hours: 2)),
        customType: 'offer',
        data: const {
          'variant': 'quote',
          'title': 'Engraved wallet',
          'currency': 'USD',
          'validDays': 3,
          'items': [
            {'label': 'Leather wallet', 'amount': 40},
            {'label': 'Name engraving', 'amount': 8},
          ],
        },
      ),
      CustomMessage(
        id: 'shop-booking',
        localId: 'shop-booking',
        roomId: shopId,
        authorId: shopId,
        sentBy: 'sara',
        createdAt: ago(const Duration(days: 1, hours: 1)),
        customType: 'booking',
        data: {
          'title': 'Delivery slot',
          'at': DateTime.now()
              .add(const Duration(days: 2))
              .copyWith(hour: 14, minute: 30)
              .toIso8601String(),
          'place': 'Oran, your address',
        },
      ),
    ];

    _messages
      ..['amina'] = _newestFirst(amina)
      ..['karim'] = _newestFirst(karim)
      ..['trip'] = _newestFirst(trip)
      ..[shopId] = _newestFirst(shop)
      ..['history'] = _history(now);

    for (final r in [
      room('amina', ['amina'], unread: 2, labels: {'friends'}),
      room('karim', ['karim'], muted: true),
      room(shopId, [shopId]),
      room(
        'trip',
        ['amina', 'karim', 'lina'],
        type: RoomType.group,
        title: 'Weekend trip',
        pinned: true,
        unread: 1,
        labels: {'friends'},
      ),
      room(
        'history',
        ['amina', 'karim', 'sam'],
        type: RoomType.group,
        title: 'Big history (5 000 messages)',
      ),
    ]) {
      _rooms[r.id] = r;
    }
  }

  static const _longLine =
      'This is a slightly longer message to check how the list handles '
      'bubbles that wrap over several lines without jank.';

  static List<Message> _newestFirst(List<Message> messages) =>
      [...messages]..sort((a, b) => b.cursor.compareTo(a.cursor));

  /// 5 000 messages, one every few minutes, with replies to older ones so
  /// "jump to replied message" has something to fetch.
  List<Message> _history(DateTime now) {
    final authors = [me, 'amina', 'karim', 'sam'];
    const lines = [
      'Morning!',
      'Did anyone see the release notes?',
      'Pushing the build now',
      'Lunch?',
      _longLine,
      '👍',
      'Merged.',
      'Can someone review my PR?',
    ];
    final start = now.subtract(const Duration(minutes: historySize * 3));
    final messages = <Message>[];
    for (var i = 0; i < historySize; i++) {
      final id = 'history-${i.toString().padLeft(4, '0')}';
      messages.add(
        TextMessage(
          id: id,
          localId: id,
          roomId: 'history',
          authorId: authors[(i ~/ 3) % authors.length],
          createdAt: start.add(Duration(minutes: i * 3)),
          text: i % 250 == 0
              ? 'Message #$i'
              : '${lines[i % lines.length]} (#$i)',
          replyToId: i % 97 == 0 && i > 1000
              ? 'history-${(i - 900).toString().padLeft(4, '0')}'
              : null,
        ),
      );
    }
    return messages.reversed.toList();
  }
}

/// Profiles for [FakeChatSource.users], with a little latency.
class FakeUserResolver implements ChatUserResolver {
  @override
  Future<List<ChatUser>> resolve(Set<String> ids) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return [for (final id in ids) ?FakeChatSource.users[id]];
  }
}
