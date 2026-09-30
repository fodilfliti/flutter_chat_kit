import 'package:flutter_chat_kit/src/models/chat_event.dart';
import 'package:flutter_chat_kit/src/models/chat_page.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';

/// The backend contract. The app implements it for Firestore, Supabase,
/// REST, WebSockets, or anything else, and maps its DTOs to kit models.
///
/// Rules:
/// - Methods throw `AppFailure` (from `lemsa_core_kit`), never vendor
///   exceptions. `NetworkFailure` / `TimeoutFailure` make the outbox retry.
/// - Message pages are **newest first**. `before` and `after` are exclusive
///   keyset bounds ordered by `(createdAt, id)`.
/// - [send] must be idempotent on `Message.localId` (for example, use the
///   local id as the document id or primary key), so retries never duplicate.
/// - [events] must also emit the sender's own confirmed messages; the kit
///   deduplicates by `localId`, then `id`.
///
/// Mix in [ChatSourceDefaults] to get no-op typing and reactions and no
/// `fetchAround` support.
abstract interface class ChatSource {
  /// Rooms of the current user, most recently updated first.
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
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

  /// Realtime events. [roomId] null means inbox-level events (room changes,
  /// presence); otherwise events for one open room.
  Stream<ChatEvent> events({String? roomId});

  /// Stores [pending] (attachments already uploaded) and returns the
  /// confirmed message with the server `id` and `createdAt`.
  Future<Message> send(Message pending);

  Future<Message> edit(Message message);

  /// [messageId] may be the server id or the local id.
  Future<void> delete(String roomId, String messageId);

  /// Moves the current user's read pointer up to [upTo].
  Future<void> markRead(String roomId, MessageCursor upTo);

  Future<void> setTyping(String roomId, {required bool typing});

  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  });
}

/// Defaults for optional capabilities of [ChatSource].
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
}
