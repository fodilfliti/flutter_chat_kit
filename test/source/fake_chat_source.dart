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
  int sendCalls = 0;
  int _serverSeq = 0;

  void seedRoom(ChatRoom room) => rooms[room.id] = room;

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
  }) async {
    _check();
    final q = search?.toLowerCase();
    final sorted =
        rooms.values
            .where(
              (r) => q == null || (r.title ?? '').toLowerCase().contains(q),
            )
            .where((r) => after == null || r.cursor.compareTo(after) < 0)
            .toList()
          ..sort((a, b) => b.cursor.compareTo(a.cursor));
    return ChatPage(
      items: sorted.take(limit).toList(),
      hasMore: sorted.length > limit,
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
    if (!supportsAround) return null;
    _check();
    final all = messagesOf(roomId);
    final index = all.indexWhere((m) => m.matches(messageId));
    if (index < 0) throw NotFoundFailure('message:$messageId');
    final start = (index - limit ~/ 2).clamp(0, all.length);
    final end = (start + limit).clamp(0, all.length);
    return ChatPage(items: all.sublist(start, end), hasMore: end < all.length);
  }

  @override
  Stream<ChatEvent> events({String? roomId}) {
    if (roomId == null) {
      return _events.stream.where(
        (e) => e is RoomChanged || e is PresenceChanged,
      );
    }
    return _events.stream.where(
      (e) => switch (e) {
        MessageChanged(roomId: final id) => id == roomId,
        TypingChanged(roomId: final id) => id == roomId,
        ReceiptChanged(roomId: final id) => id == roomId,
        RoomChanged() || PresenceChanged() => false,
      },
    );
  }

  @override
  Future<Message> send(Message pending) async {
    _check();
    sendCalls++;
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
}
