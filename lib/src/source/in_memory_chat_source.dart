import 'dart:async';
import 'dart:math';

import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/models/chat_event.dart';
import 'package:flutter_chat_kit/src/models/chat_page.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';
import 'package:flutter_chat_kit/src/models/presence.dart';
import 'package:flutter_chat_kit/src/models/room_filter.dart';
import 'package:flutter_chat_kit/src/models/room_member.dart';
import 'package:flutter_chat_kit/src/source/chat_source.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// A complete [ChatSource] kept in memory: paging, idempotent send, edit,
/// delete, receipts, reactions, pin, mute, typing and live events.
///
/// Use it to see the whole chat before writing any backend code, then
/// replace it with your own source. Nothing is saved: a restart starts
/// over (the kit's cache still keeps what it saw).
///
/// ```dart
/// final kit = ChatKit(
///   currentUserId: 'me',
///   source: InMemoryChatSource.sample(currentUserId: 'me'),
/// );
/// ```
///
/// Media needs a `ChatUploader`; without one the kit hides the attach and
/// mic buttons, and text chat works fully.
class InMemoryChatSource with ChatSourceDefaults {
  /// An in-memory backend seen by [currentUserId], starting with [rooms],
  /// [messages] (by room id, any order) and [users]. All start empty; use
  /// [InMemoryChatSource.sample] for ready-made content.
  ///
  /// [clock] gives server times (UTC now by default); [random] picks auto
  /// reply texts and authors.
  InMemoryChatSource({
    required this.currentUserId,
    Iterable<ChatRoom> rooms = const [],
    Map<String, List<Message>> messages = const {},
    Iterable<ChatUser> users = const [],
    this.autoReply = false,
    this.replyDelay = const Duration(milliseconds: 1500),
    this.latency = Duration.zero,
    DateTime Function()? clock,
    Random? random,
  }) : clock = clock ?? (() => DateTime.now().toUtc()),
       _random = random ?? Random() {
    for (final room in rooms) {
      _rooms[room.id] = room;
    }
    for (final MapEntry(:key, :value) in messages.entries) {
      _messages.putIfAbsent(key, () => []).addAll(value);
    }
    for (final user in users) {
      this.users[user.id] = user;
    }
  }

  /// Three people, a direct chat with unread messages and a photo, a group
  /// and a quiet chat. [autoReply] is on: someone types and answers each
  /// message you send.
  factory InMemoryChatSource.sample({
    required String currentUserId,
    bool autoReply = true,
    Duration replyDelay = const Duration(milliseconds: 1500),
    DateTime Function()? clock,
  }) {
    final now = (clock ?? () => DateTime.now().toUtc())();
    DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
    const face = 'https://images.unsplash.com';
    const crop = '?w=150&h=150&fit=crop&crop=faces';
    const users = [
      ChatUser(
        id: 'amina',
        name: 'Amina Haddad',
        avatarUrl: '$face/photo-1494790108377-be9c29b29330$crop',
      ),
      ChatUser(
        id: 'karim',
        name: 'Karim Benali',
        avatarUrl: '$face/photo-1506794778202-cad84cf45f1d$crop',
      ),
      ChatUser(
        id: 'lina',
        name: 'Lina Mansouri',
        avatarUrl: '$face/photo-1534528741775-53994a69daeb$crop',
      ),
    ];
    var seq = 0;
    TextMessage text(String room, String author, int minutes, String body) {
      final id = 'sample-${++seq}';
      return TextMessage(
        id: id,
        localId: id,
        roomId: room,
        authorId: author,
        createdAt: ago(minutes),
        text: body,
      );
    }

    final me = currentUserId;
    final messages = <String, List<Message>>{
      'amina': [
        text('amina', me, 60, 'Hi Amina! Are we still on for Saturday?'),
        text('amina', 'amina', 58, 'Yes! 10am at the café 😊'),
        ImageMessage(
          id: 'sample-photo',
          localId: 'sample-photo',
          roomId: 'amina',
          authorId: 'amina',
          createdAt: ago(5),
          images: const [
            Attachment(
              mimeType: 'image/jpeg',
              remoteUrl: 'https://picsum.photos/seed/flutter-chat-kit/1200/800',
              width: 1200,
              height: 800,
            ),
          ],
          caption: 'The view from there',
        ),
        text('amina', 'amina', 4, 'Long-press a message to reply or react'),
      ],
      'weekend': [
        text('weekend', 'karim', 300, 'Who is bringing the snacks?'),
        text('weekend', 'lina', 290, 'I can! 🍪'),
        text('weekend', me, 280, 'I will bring drinks'),
        text('weekend', 'karim', 30, 'See you all at 9 then'),
      ],
      'karim': [
        text('karim', 'karim', 3000, 'Thanks for yesterday!'),
        text('karim', me, 2990, 'Anytime 🙏'),
      ],
    };
    RoomMember member(String id, {DateTime? read}) =>
        RoomMember(userId: id, lastReadAt: read, lastDeliveredAt: read);
    final rooms = [
      ChatRoom(
        id: 'amina',
        updatedAt: ago(4),
        members: [
          member(me, read: ago(58)),
          member('amina', read: ago(60)),
        ],
        lastMessage: messages['amina']!.last,
        unreadCount: 2,
      ),
      ChatRoom(
        id: 'weekend',
        type: RoomType.group,
        title: 'Weekend trip',
        updatedAt: ago(30),
        members: [
          member(me, read: ago(30)),
          member('karim', read: ago(30)),
          member('lina', read: ago(280)),
        ],
        lastMessage: messages['weekend']!.last,
      ),
      ChatRoom(
        id: 'karim',
        updatedAt: ago(2990),
        members: [
          member(me, read: ago(2990)),
          member('karim', read: ago(2990)),
        ],
        lastMessage: messages['karim']!.last,
      ),
    ];
    return InMemoryChatSource(
      currentUserId: currentUserId,
      rooms: rooms,
      messages: messages,
      users: users,
      autoReply: autoReply,
      replyDelay: replyDelay,
      clock: clock,
    );
  }

  /// The user this source acts for: [markRead], [react] and unread counts
  /// apply to them. Use the same id as `ChatKit.currentUserId`.
  final String currentUserId;

  /// After each message you send, another member reads it, types, and
  /// answers.
  bool autoReply;

  /// How long the auto reply takes, typing included.
  Duration replyDelay;

  /// Waits this long in every call, like a network.
  Duration latency;

  /// Server time, in UTC: `createdAt` of sent messages, `editedAt`,
  /// `deletedAt` and presence times.
  final DateTime Function() clock;
  final Random _random;

  /// Everyone the source knows, sent with each page.
  final Map<String, ChatUser> users = {};

  final Map<String, ChatRoom> _rooms = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, Message> _sentByLocalId = {};
  final _events = StreamController<ChatEvent>.broadcast();
  final _timers = <Timer>{};
  int _seq = 0;
  bool _disposed = false;

  /// The rooms, most recent first.
  List<ChatRoom> get rooms =>
      _rooms.values.toList()..sort((a, b) => b.cursor.compareTo(a.cursor));

  /// The messages of [roomId], newest first.
  List<Message> messagesOf(String roomId) =>
      [...?_messages[roomId]]..sort((a, b) => b.cursor.compareTo(a.cursor));

  /// Adds or replaces a room and tells open inboxes.
  void putRoom(ChatRoom room) {
    _rooms[room.id] = room;
    _emit(RoomChanged(Updated(room)));
  }

  /// Delivers [message] as if another member sent it: stores it, updates
  /// the room (last message, unread count) and emits it.
  void receive(Message message) {
    _store(message);
    final room = _rooms[message.roomId];
    if (room != null) {
      putRoom(
        room.copyWith(
          lastMessage: message,
          updatedAt: message.createdAt,
          unreadCount: message.authorId == currentUserId
              ? room.unreadCount
              : room.unreadCount + 1,
        ),
      );
    }
    _emit(MessageChanged(roomId: message.roomId, change: Created(message)));
  }

  /// Shows [userId] typing in [roomId] (or stopping).
  void typing(String roomId, String userId, {required bool typing}) =>
      _emit(TypingChanged(roomId: roomId, userId: userId, typing: typing));

  /// Sets [userId] online or offline.
  void presence(String userId, {required bool online}) => _emit(
    PresenceChanged(
      Presence(userId: userId, isOnline: online, lastSeenAt: clock()),
    ),
  );

  /// Cancels pending auto replies and closes the event streams. Call it
  /// after the `ChatKit` using this source is closed.
  Future<void> dispose() async {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    await _events.close();
  }

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) async {
    await _wait();
    final q = search?.trim().toLowerCase();
    final matching = [
      for (final room in rooms)
        if ((after == null || room.cursor.compareTo(after) < 0) &&
            filter.matches(room) &&
            (q == null || q.isEmpty || _title(room).contains(q)))
          room,
    ];
    final items = matching.take(limit).toList();
    return ChatPage(
      items: items,
      hasMore: matching.length > limit,
      users: _usersOf([
        for (final room in items) ...[
          for (final m in room.members) m.userId,
          ?room.lastMessage?.authorId,
        ],
      ]),
    );
  }

  @override
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) async {
    await _wait();
    final all = messagesOf(roomId);
    if (after != null) {
      final newer = all.where((m) => m.cursor.isAfter(after)).toList();
      final items = newer.reversed.take(limit).toList().reversed.toList();
      return ChatPage(
        items: items,
        hasMore: newer.length > limit,
        users: _usersOf([for (final m in items) m.authorId]),
      );
    }
    final older = before == null
        ? all
        : all.where((m) => m.cursor.isBefore(before)).toList();
    final items = older.take(limit).toList();
    return ChatPage(
      items: items,
      hasMore: older.length > limit,
      users: _usersOf([for (final m in items) m.authorId]),
    );
  }

  @override
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  }) async {
    await _wait();
    final all = messagesOf(roomId);
    final index = all.indexWhere((m) => m.matches(messageId));
    if (index < 0) throw NotFoundFailure('message:$messageId');
    final start = max(0, index - limit ~/ 2);
    final end = min(all.length, start + limit);
    return ChatPage(
      items: all.sublist(start, end),
      hasMore: end < all.length,
      users: _usersOf([for (final m in all.sublist(start, end)) m.authorId]),
    );
  }

  @override
  Stream<ChatEvent> events({String? roomId}) {
    if (roomId == null) {
      return _events.stream.where(
        (e) => e is RoomChanged || e is PresenceChanged || e is UsersChanged,
      );
    }
    return _events.stream.where(
      (e) => switch (e) {
        MessageChanged(roomId: final id) ||
        TypingChanged(roomId: final id) ||
        ReceiptChanged(roomId: final id) => id == roomId,
        UsersChanged() => true,
        RoomChanged() || PresenceChanged() => false,
      },
    );
  }

  @override
  Future<Message> send(Message pending) async {
    await _wait();
    final existing = _sentByLocalId[pending.localId];
    if (existing != null) return existing;
    final confirmed = pending.copyWith(
      id: 'mem-${++_seq}',
      status: MessageStatus.sent,
      createdAt: clock(),
    );
    _sentByLocalId[pending.localId] = confirmed;
    receive(confirmed);
    if (autoReply) _scheduleReply(confirmed);
    return confirmed;
  }

  @override
  Future<Message> edit(Message message) async {
    await _wait();
    return _update(message.roomId, message.id, (_) {
      return message.copyWith(editedAt: clock());
    });
  }

  @override
  Future<void> delete(String roomId, String messageId) async {
    await _wait();
    _update(roomId, messageId, (m) => m.copyWith(deletedAt: clock()));
  }

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) async {
    await _wait();
    final room = _rooms[roomId];
    if (room == null) return;
    putRoom(
      room.copyWith(
        unreadCount: 0,
        members: [
          for (final m in room.members)
            if (m.userId == currentUserId)
              m.copyWith(lastReadAt: upTo.createdAt)
            else
              m,
        ],
      ),
    );
    _emit(
      ReceiptChanged(
        roomId: roomId,
        userId: currentUserId,
        readAt: upTo.createdAt,
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
    await _wait();
    _update(roomId, messageId, (m) {
      final reactions = {
        for (final e in m.reactions.entries) e.key: {...e.value},
      };
      final who = reactions.putIfAbsent(emoji, () => {});
      add ? who.add(currentUserId) : who.remove(currentUserId);
      if (who.isEmpty) reactions.remove(emoji);
      return m.copyWith(reactions: reactions);
    });
  }

  @override
  Future<void> setPinned(String roomId, {required bool pinned}) async {
    await _wait();
    final room = _rooms[roomId];
    if (room != null) putRoom(room.copyWith(pinned: pinned));
  }

  @override
  Future<void> setMuted(String roomId, {required bool muted}) async {
    await _wait();
    final room = _rooms[roomId];
    if (room != null) putRoom(room.copyWith(muted: muted));
  }

  void _store(Message message) {
    final list = _messages.putIfAbsent(message.roomId, () => []);
    final index = list.indexWhere(
      (m) => m.localId == message.localId || m.id == message.id,
    );
    index < 0 ? list.add(message) : list[index] = message;
  }

  Message _update(
    String roomId,
    String messageId,
    Message Function(Message) change,
  ) {
    final list = _messages[roomId] ?? const <Message>[];
    final current = list.where((m) => m.matches(messageId)).firstOrNull;
    if (current == null) throw NotFoundFailure('message:$messageId');
    final updated = change(current);
    _store(updated);
    final room = _rooms[roomId];
    if (room != null && room.lastMessage?.matches(messageId) == true) {
      putRoom(room.copyWith(lastMessage: updated));
    }
    _emit(MessageChanged(roomId: roomId, change: Updated(updated)));
    return updated;
  }

  void _scheduleReply(Message to) {
    final room = _rooms[to.roomId];
    final others = [
      for (final m in room?.members ?? const <RoomMember>[])
        if (m.userId != currentUserId) m.userId,
    ];
    if (others.isEmpty) return;
    final replier = others[_random.nextInt(others.length)];
    final third = Duration(microseconds: replyDelay.inMicroseconds ~/ 3);
    _after(third, () {
      final readAt = clock();
      final current = _rooms[to.roomId];
      if (current != null) {
        _rooms[to.roomId] = current.copyWith(
          members: [
            for (final m in current.members)
              if (m.userId == replier)
                m.copyWith(lastReadAt: readAt, lastDeliveredAt: readAt)
              else
                m,
          ],
        );
      }
      _emit(
        ReceiptChanged(
          roomId: to.roomId,
          userId: replier,
          readAt: readAt,
          deliveredAt: readAt,
        ),
      );
      typing(to.roomId, replier, typing: true);
    });
    _after(replyDelay, () {
      typing(to.roomId, replier, typing: false);
      final id = 'mem-${++_seq}';
      receive(
        TextMessage(
          id: id,
          localId: id,
          roomId: to.roomId,
          authorId: replier,
          createdAt: clock(),
          text: _replies[_random.nextInt(_replies.length)],
          replyToId: _random.nextInt(4) == 0 ? to.id : null,
        ),
      );
    });
  }

  void _after(Duration delay, void Function() run) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (!_disposed) run();
    });
    _timers.add(timer);
  }

  static const _replies = [
    'Sounds good 👍',
    'Haha, true 😄',
    'Let me check and come back to you',
    'Perfect, thanks!',
    'On my way',
    'Can you send a photo?',
    'Great idea!',
  ];

  String _title(ChatRoom room) {
    final names = [
      room.title ?? '',
      for (final m in room.members) users[m.userId]?.name ?? '',
    ];
    return names.join(' ').toLowerCase();
  }

  List<ChatUser> _usersOf(Iterable<String> ids) => [
    for (final id in ids.toSet()) ?users[id],
  ];

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  void _emit(ChatEvent event) {
    if (!_disposed) _events.add(event);
  }
}
