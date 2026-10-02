import 'dart:async';

import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// In-memory [ChatSource] for tests: paging, realtime events, idempotent
/// send, and failures on demand.
class FakeChatSource with ChatSourceDefaults implements ChatSource {
  FakeChatSource({this.supportsAround = true});

  final bool supportsAround;
  final Map<String, ChatRoom> rooms = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, Message> _sentByLocalId = {};
  final _events = StreamController<ChatEvent>.broadcast();

  /// Thrown by the next call, then cleared.
  AppFailure? failNext;

  DateTime Function() clock = () => DateTime.now().toUtc();

  final List<(String, MessageCursor)> markReadCalls = [];
  final List<(String, bool)> typingCalls = [];
  final List<({String roomId, MessageCursor? before, MessageCursor? after})>
  fetchCalls = [];
  final List<(String, String)> aroundCalls = [];
  final List<({RoomCursor? after, String? search, RoomFilter filter})>
  roomFetchCalls = [];

  /// Returns every room regardless of the filter, like a backend that
  /// cannot filter.
  bool ignoreRoomFilter = false;
  int sendCalls = 0;
  int _serverSeq = 0;

  /// When set, `send` waits for it before answering.
  Completer<void>? sendGate;

  /// The next `send` of these local ids throws the failure.
  final Map<String, AppFailure> failSend = {};

  /// Messages received by successful `send` calls, in order.
  final List<Message> sent = [];
  final List<Message> edits = [];
  final List<(String, String)> deleteCalls = [];
  final List<(String, String, String, bool)> reactCalls = [];

  /// Sent with every page that mentions them (members, authors), like a
  /// backend that joins its profiles table.
  final Map<String, ChatUser> people = {};

  void seedRoom(ChatRoom room) => rooms[room.id] = room;

  List<ChatUser> _peopleIn(Iterable<String> ids) => [
    for (final id in ids.toSet()) ?people[id],
  ];

  List<ChatUser> _peopleOfRooms(List<ChatRoom> rooms) => _peopleIn([
    for (final room in rooms) ...[
      for (final member in room.members) member.userId,
      ?room.lastMessage?.authorId,
    ],
  ]);

  List<ChatUser> _peopleOfMessages(List<Message> messages) =>
      _peopleIn([for (final m in messages) m.authorId]);

  void seedMessages(String roomId, Iterable<Message> messages) {
    _messages.putIfAbsent(roomId, () => []).addAll(messages);
  }

  /// Stores [message] and emits it, as if another user sent it.
  void receive(Message message) {
    seedMessages(message.roomId, [message]);
    emit(MessageChanged(roomId: message.roomId, change: Created(message)));
  }

  void emit(ChatEvent event) => _events.add(event);

  List<Message> messagesOf(String roomId) {
    final list = [...?_messages[roomId]]
      ..sort((a, b) => b.cursor.compareTo(a.cursor));
    return list;
  }

  Future<void> dispose() => _events.close();

  void _check() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) async {
    _check();
    roomFetchCalls.add((after: after, search: search, filter: filter));
    final q = search?.toLowerCase();
    final sorted =
        rooms.values
            .where(
              (r) => q == null || (r.title ?? '').toLowerCase().contains(q),
            )
            .where((r) => ignoreRoomFilter || filter.matches(r))
            .where((r) => after == null || r.cursor.compareTo(after) < 0)
            .toList()
          ..sort((a, b) => b.cursor.compareTo(a.cursor));
    final items = sorted.take(limit).toList();
    return ChatPage(
      items: items,
      hasMore: sorted.length > limit,
      users: _peopleOfRooms(items),
    );
  }

  @override
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) async {
    _check();
    fetchCalls.add((roomId: roomId, before: before, after: after));
    final all = messagesOf(roomId);
    if (after != null) {
      final newer = all.where((m) => m.cursor.isAfter(after)).toList();
      final oldestFirst = newer.reversed.take(limit).toList();
      return ChatPage(
        items: oldestFirst.reversed.toList(),
        hasMore: newer.length > limit,
        users: _peopleOfMessages(oldestFirst),
      );
    }
    final older = before == null
        ? all
        : all.where((m) => m.cursor.isBefore(before)).toList();
    final items = older.take(limit).toList();
    return ChatPage(
      items: items,
      hasMore: older.length > limit,
      users: _peopleOfMessages(items),
    );
  }

  @override
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  }) async {
    if (!supportsAround) return null;
    _check();
    aroundCalls.add((roomId, messageId));
    final all = messagesOf(roomId);
    final index = all.indexWhere((m) => m.matches(messageId));
    if (index < 0) throw NotFoundFailure('message:$messageId');
    final start = (index - limit ~/ 2).clamp(0, all.length);
    final end = (start + limit).clamp(0, all.length);
    return ChatPage(items: all.sublist(start, end), hasMore: end < all.length);
  }

  /// Calls of `listen` on streams returned by [events].
  int eventListens = 0;
  final List<StreamController<ChatEvent>> _live = [];

  /// Ends every open event stream, after [error] when given, like a
  /// dropped connection.
  void dropStreams({Object? error}) {
    for (final controller in [..._live]) {
      if (error != null) controller.addError(error);
      unawaited(controller.close());
    }
    _live.clear();
  }

  @override
  Stream<ChatEvent> events({String? roomId}) {
    bool matches(ChatEvent e) => roomId == null
        ? e is RoomChanged || e is PresenceChanged || e is UsersChanged
        : switch (e) {
            MessageChanged(roomId: final id) => id == roomId,
            TypingChanged(roomId: final id) => id == roomId,
            ReceiptChanged(roomId: final id) => id == roomId,
            RoomChanged() || PresenceChanged() || UsersChanged() => false,
          };
    late final StreamController<ChatEvent> controller;
    StreamSubscription<ChatEvent>? upstream;
    controller = StreamController<ChatEvent>(
      onListen: () {
        eventListens++;
        _live.add(controller);
        upstream = _events.stream.where(matches).listen(controller.add);
      },
      onCancel: () {
        _live.remove(controller);
        return upstream?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<Message> send(Message pending) async {
    await sendGate?.future;
    _check();
    final failure = failSend.remove(pending.localId);
    if (failure != null) throw failure;
    sendCalls++;
    sent.add(pending);
    final existing = _sentByLocalId[pending.localId];
    if (existing != null) return existing;
    final confirmed = pending.copyWith(
      id: 'srv-${++_serverSeq}',
      status: MessageStatus.sent,
      createdAt: clock(),
    );
    _sentByLocalId[pending.localId] = confirmed;
    receive(confirmed);
    return confirmed;
  }

  @override
  Future<Message> edit(Message message) async {
    _check();
    edits.add(message);
    final list = _messages[message.roomId] ?? [];
    final index = list.indexWhere((m) => m.matches(message.id));
    if (index < 0) throw NotFoundFailure('message:${message.id}');
    final edited = message.copyWith(editedAt: clock());
    list[index] = edited;
    emit(MessageChanged(roomId: message.roomId, change: Updated(edited)));
    return edited;
  }

  @override
  Future<void> delete(String roomId, String messageId) async {
    _check();
    deleteCalls.add((roomId, messageId));
    _messages[roomId]?.removeWhere((m) => m.matches(messageId));
    emit(MessageChanged(roomId: roomId, change: Deleted(messageId)));
  }

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) async {
    _check();
    markReadCalls.add((roomId, upTo));
  }

  @override
  Future<void> setTyping(String roomId, {required bool typing}) async {
    typingCalls.add((roomId, typing));
  }

  @override
  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  }) async {
    _check();
    reactCalls.add((roomId, messageId, emoji, add));
  }

  final List<(String, bool)> pinCalls = [];
  final List<(String, bool)> muteCalls = [];

  @override
  Future<void> setPinned(String roomId, {required bool pinned}) async {
    _check();
    pinCalls.add((roomId, pinned));
  }

  @override
  Future<void> setMuted(String roomId, {required bool muted}) async {
    _check();
    muteCalls.add((roomId, muted));
  }
}
