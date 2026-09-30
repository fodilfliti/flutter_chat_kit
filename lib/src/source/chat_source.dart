import 'package:flutter_chat_kit/src/models/chat_event.dart';
import 'package:flutter_chat_kit/src/models/chat_page.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/room_filter.dart';

/// Reads and writes of the backend contract: pages of rooms and messages,
/// send, edit, delete, read pointers, reactions, pin and mute.
///
/// Implement it alone when realtime comes from somewhere else, and combine
/// the two with `ComposedChatSource` (for example a REST API for data and
/// Firebase, Supabase or a WebSocket for realtime, or `PollingRealtime`).
///
/// Rules:
/// - Methods throw `AppFailure` (from `lemsa_core_kit`), never vendor
///   exceptions. `NetworkFailure` / `TimeoutFailure` make the outbox retry.
/// - Message pages are **newest first**. `before` and `after` are exclusive
///   keyset bounds ordered by `(createdAt, id)`.
/// - [send] must be idempotent on `Message.localId` (for example, use the
///   local id as the document id or primary key), so retries never duplicate.
///
/// Mix in [ChatDataSourceDefaults] to get no-op reactions, pin and mute and
/// no `fetchAround` support.
abstract interface class ChatDataSource {
  /// Rooms of the current user, most recently updated first.
  ///
  /// Apply as much of [filter] and [search] as the query itself supports
  /// (usually `types` and `labels`); the kit filters its cache again, so
  /// ignoring them is correct, only less efficient. `RoomFilter.toQuery`
  /// gives REST parameters.
  ///
  /// Return the page as the query read it: do not drop rooms from it
  /// afterwards. The next page starts after the last room returned, and an
  /// empty page ends paging.
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
    RoomFilter filter = RoomFilter.all,
  });

  /// One page of a room's history, newest first.
  ///
  /// - No cursor: the latest [limit] messages.
  /// - [before]: the [limit] messages just older than the cursor.
  /// - [after]: the [limit] messages just newer than the cursor (the oldest
  ///   of the newer ones, used for gap filling), still ordered newest first.
  ///
  /// `hasMore` tells whether more messages exist further in that direction.
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  });

  /// A page centred on [messageId], newest first, used to jump to old
  /// messages. `hasMore` tells whether older messages exist. Return null
  /// when unsupported; the kit then pages back with [fetchMessages] until it
  /// finds the message.
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  });

  /// Stores [pending] (attachments already uploaded) and returns the
  /// confirmed message with the server `id` and `createdAt`.
  Future<Message> send(Message pending);

  Future<Message> edit(Message message);

  /// [messageId] may be the server id or the local id.
  Future<void> delete(String roomId, String messageId);

  /// Moves the current user's read pointer up to [upTo].
  Future<void> markRead(String roomId, MessageCursor upTo);

  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  });

  /// Pins or unpins the room for the current user.
  Future<void> setPinned(String roomId, {required bool pinned});

  /// Mutes or unmutes the room's notifications for the current user.
  Future<void> setMuted(String roomId, {required bool muted});
}

/// The realtime half of the backend contract: events and typing.
///
/// Rules:
/// - [events] with `roomId` null carries inbox-level events (`RoomChanged`,
///   `PresenceChanged`); with a room id, that room's `MessageChanged`,
///   `TypingChanged` and `ReceiptChanged`.
/// - It also emits the sender's own confirmed messages; the kit
///   deduplicates by `localId`, then `id`.
abstract interface class ChatRealtime {
  Stream<ChatEvent> events({String? roomId});

  Future<void> setTyping(String roomId, {required bool typing});
}

/// The complete backend contract: [ChatDataSource] plus [ChatRealtime].
/// The app implements it for Firestore, Supabase, REST, WebSockets, or
/// anything else, and maps its DTOs to kit models; or composes it from two
/// parts with `ComposedChatSource`.
///
/// Mix in [ChatSourceDefaults] to get no-op typing, reactions, pin and mute
/// and no `fetchAround` support.
abstract interface class ChatSource implements ChatDataSource, ChatRealtime {}

/// Defaults for optional capabilities of [ChatDataSource]. Pin and mute
/// stay local to the device.
mixin ChatDataSourceDefaults implements ChatDataSource {
  @override
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  }) async => null;

  @override
  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  }) async {}

  @override
  Future<void> setPinned(String roomId, {required bool pinned}) async {}

  @override
  Future<void> setMuted(String roomId, {required bool muted}) async {}
}

/// Defaults for optional capabilities of [ChatSource]: those of
/// [ChatDataSourceDefaults] plus no-op typing.
mixin ChatSourceDefaults implements ChatSource {
  @override
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  }) async => null;

  @override
  Future<void> setTyping(String roomId, {required bool typing}) async {}

  @override
  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  }) async {}

  @override
  Future<void> setPinned(String roomId, {required bool pinned}) async {}

  @override
  Future<void> setMuted(String roomId, {required bool muted}) async {}
}
