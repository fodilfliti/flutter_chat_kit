import 'package:flutter_chat_kit/src/models/chat_event.dart';
import 'package:flutter_chat_kit/src/models/chat_page.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/room_filter.dart';
import 'package:flutter_chat_kit/src/source/chat_source.dart';

/// A [ChatSource] built from two backends: [data] for reads and writes,
/// [realtime] for events and typing.
///
/// ```dart
/// final api = MyRestApi(); // implements ChatDataSource
/// final source = ComposedChatSource(
///   data: api,
///   realtime: MySupabaseRealtime(), // or Firestore, a WebSocket, ...
///   // realtime: PollingRealtime(api), // REST only, no realtime service
/// );
/// ```
///
/// A full `ChatSource` is also a `ChatDataSource` and a `ChatRealtime`, so
/// either side can reuse an existing adapter.
class ComposedChatSource implements ChatSource {
  const ComposedChatSource({required this.data, required this.realtime});

  final ChatDataSource data;
  final ChatRealtime realtime;

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) => data.fetchRooms(
    after: after,
    limit: limit,
    search: search,
    filter: filter,
  );

  @override
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) => data.fetchMessages(roomId, before: before, after: after, limit: limit);

  @override
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  }) => data.fetchAround(roomId, messageId, limit: limit);

  @override
  Future<Message> send(Message pending) => data.send(pending);

  @override
  Future<Message> edit(Message message) => data.edit(message);

  @override
  Future<void> delete(String roomId, String messageId) =>
      data.delete(roomId, messageId);

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) =>
      data.markRead(roomId, upTo);

  @override
  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  }) => data.react(roomId, messageId, emoji, add: add);

  @override
  Future<void> setPinned(String roomId, {required bool pinned}) =>
      data.setPinned(roomId, pinned: pinned);

  @override
  Future<void> setMuted(String roomId, {required bool muted}) =>
      data.setMuted(roomId, muted: muted);

  @override
  Stream<ChatEvent> events({String? roomId}) => realtime.events(roomId: roomId);

  @override
  Future<void> setTyping(String roomId, {required bool typing}) =>
      realtime.setTyping(roomId, typing: typing);
}
