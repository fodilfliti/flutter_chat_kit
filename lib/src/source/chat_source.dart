import 'package:flutter_chat_pro/src/models/chat_event.dart';
import 'package:flutter_chat_pro/src/models/chat_page.dart';
import 'package:flutter_chat_pro/src/models/chat_room.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_cursor.dart';
import 'package:flutter_chat_pro/src/models/room_filter.dart';

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
///
/// Writes (send, edit, delete, react) go through the kit's outbox: the UI
/// shows them at once, and the outbox calls these methods when online. Any
/// other exception is treated like a failure that is not retried. See
/// doc/adapters/your_api.md and the REST, Firestore and Supabase guides.
abstract interface class ChatDataSource {
  /// Rooms of the current user, most recently updated first.
  ///
  /// The kit calls it when an inbox opens, on pull to refresh, and when
  /// the list scrolls near its end, with [after] set to the last room it
  /// has. [after] is exclusive: return rooms strictly older than it.
  ///
  /// Apply as much of [filter] and [search] as the query itself supports
  /// (usually `types` and `labels`); the kit filters its cache again, so
  /// ignoring them is correct, only less efficient. `RoomFilter.toQuery`
  /// gives REST parameters.
  ///
  /// Return the page as the query read it: do not drop rooms from it
  /// afterwards. The next page starts after the last room returned, and an
  /// empty page ends paging.
  ///
  /// ```dart
  /// final res = await api.get('/rooms', query: {
  ///   'limit': '$limit',
  ///   if (after != null) 'before': after.updatedAt.toIso8601String(),
  ///   if (after != null) 'before_id': after.id,
  ///   ...filter.toQuery(),
  /// });
  /// final rooms = [
  ///   for (final r in res['items'] as List) ChatRoom.fromJson(r),
  /// ];
  /// return ChatPage(items: rooms, hasMore: rooms.length == limit);
  /// ```
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
  ///   of the newer ones), still ordered newest first. Only used to scroll
  ///   down from a message the user jumped to.
  ///
  /// Cursors are exclusive and ordered by `(createdAt, id)`; see
  /// [MessageCursor]. `hasMore` tells whether more messages exist further
  /// in that direction. The kit calls it when a room opens, when the user
  /// scrolls up, and after reconnecting. Catching up always starts from the
  /// latest page and walks back with [before] until it meets the cache, at
  /// most `maxGapPages` (5) requests however much was missed.
  ///
  /// ```dart
  /// final res = await api.get('/rooms/$roomId/messages', query: {
  ///   'limit': '$limit',
  ///   if (before != null) 'before': before.createdAt.toIso8601String(),
  ///   if (after != null) 'after': after.createdAt.toIso8601String(),
  /// });
  /// return ChatPage(
  ///   items: [for (final m in res['items'] as List)
  ///       Message.fromJson(m, roomId: roomId)],
  ///   hasMore: res['has_more'] == true,
  /// );
  /// ```
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  });

  /// A page centred on [messageId], newest first, used to jump to old
  /// messages (a tapped reply quote, a search result). `hasMore` tells
  /// whether older messages exist. Return null when unsupported; the kit
  /// then pages back with [fetchMessages] until it finds the message.
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  });

  /// Stores [pending] (attachments already uploaded) and returns the
  /// confirmed message with the server `id` and `createdAt`.
  ///
  /// Must be idempotent on `pending.localId`: the outbox retries after a
  /// timeout, so the same message may arrive twice. Store the local id and
  /// return it (JSON `local_id`), in this result and in the realtime echo,
  /// so the kit replaces the pending bubble instead of adding a second one.
  /// Throw `NetworkFailure` or `TimeoutFailure` to retry later; any other
  /// failure marks the message failed.
  ///
  /// ```dart
  /// @override
  /// Future<Message> send(Message pending) async {
  ///   final res = await api.post('/rooms/${pending.roomId}/messages',
  ///       body: pending.toJson()); // includes local_id
  ///   return Message.fromJson(res, roomId: pending.roomId);
  /// }
  /// ```
  Future<Message> send(Message pending);

  /// Saves the new content of [message] (same `id`, new text or caption)
  /// and returns the stored message, usually with `editedAt` set.
  ///
  /// Called after `ChatRoomController.edit`; the UI already shows the new
  /// text. A failure that is not retried restores the old text.
  Future<Message> edit(Message message);

  /// Deletes a message. Soft deletes (setting `deleted_at`) are
  /// recommended, so other devices and `PollingRealtime` see the change.
  ///
  /// [messageId] may be the server id or the local id. The UI already
  /// shows the message as deleted; a failure that is not retried restores
  /// it.
  Future<void> delete(String roomId, String messageId);

  /// Moves the current user's read pointer up to [upTo], and usually
  /// resets the room's unread count.
  ///
  /// Called when the newest messages are on screen
  /// (`ChatConfig.markReadWhenAtBottom`). The kit clears the badge locally
  /// first.
  Future<void> markRead(String roomId, MessageCursor upTo);

  /// Adds ([add] true) or removes the current user's [emoji] reaction on
  /// [messageId]. The UI already shows the change; a failure that is not
  /// retried reverts it.
  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  });

  /// Pins or unpins the room for the current user (`ChatRoom.pinned`).
  ///
  /// Called from `InboxController.setPinned`; the inbox already shows the
  /// change, and an `AppFailure` reverts it.
  Future<void> setPinned(String roomId, {required bool pinned});

  /// Mutes or unmutes the room's notifications for the current user
  /// (`ChatRoom.muted`).
  ///
  /// Called from `InboxController.setMuted`; the inbox already shows the
  /// change, and an `AppFailure` reverts it.
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
  /// Live changes, as a stream the kit listens to while a screen is open.
  ///
  /// With [roomId] null: inbox events (`RoomChanged`, `PresenceChanged`,
  /// `UsersChanged`), listened to while an inbox is open. With a room id:
  /// that room's `MessageChanged`, `TypingChanged`, `ReceiptChanged` and
  /// `UsersChanged`, listened to while the room is open. The kit cancels
  /// the subscription when the screen closes, so open the connection in
  /// `onListen` and close it in `onCancel`.
  ///
  /// When the stream errors or ends, the kit calls [events] again with
  /// backoff (`ChatRepository.reconnectPolicy`) and refetches what was
  /// missed, so a stream may simply close when its connection drops. It
  /// also catches up when the app returns to the foreground and on
  /// `ChatKit.setOnline(online: true)`.
  Stream<ChatEvent> events({String? roomId});

  /// Tells the other members that the current user started or stopped
  /// typing in [roomId].
  ///
  /// Called at most every `ChatConfig.typingThrottle` while typing, and
  /// with false after `ChatConfig.typingTimeout` of inactivity or on send.
  /// Failures are ignored.
  Future<void> setTyping(String roomId, {required bool typing});
}

/// The complete backend contract: [ChatDataSource] plus [ChatRealtime].
/// The app implements it for Firestore, Supabase, REST, WebSockets, or
/// anything else, and maps its DTOs to kit models; or composes it from two
/// parts with `ComposedChatSource`.
///
/// Mix in [ChatSourceDefaults] to get no-op typing, reactions, pin and mute
/// and no `fetchAround` support. Start from `InMemoryChatSource` to see the
/// chat working before writing one.
///
/// ```dart
/// class MyChatSource with ChatSourceDefaults {
///   @override
///   Future<ChatPage<ChatRoom>> fetchRooms({RoomCursor? after,
///       int limit = 20, String? search,
///       RoomFilter filter = RoomFilter.all}) { ... }
///   // fetchMessages, send, edit, delete, markRead, events
/// }
/// ```
abstract interface class ChatSource implements ChatDataSource, ChatRealtime {}

/// Defaults for optional capabilities of [ChatDataSource]: [fetchAround]
/// returns null, and [react], [setPinned] and [setMuted] do nothing, so
/// reactions, pin and mute stay local to the device. Override any of them
/// when the backend supports it.
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
/// [ChatDataSourceDefaults] plus no-op typing, so the typing indicator
/// never shows for others.
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
