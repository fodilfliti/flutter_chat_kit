import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/room_member.dart';
import 'package:flutter_chat_kit/src/sync/outbox_entry.dart';
import 'package:flutter_chat_kit/src/sync/room_sync_state.dart';

/// Unsent composer text for a room.
@immutable
class ChatDraft {
  const ChatDraft({required this.text, this.replyToId});

  final String text;
  final String? replyToId;

  @override
  bool operator ==(Object other) =>
      other is ChatDraft && other.text == text && other.replyToId == replyToId;

  @override
  int get hashCode => Object.hash(text, replyToId);
}

/// Local store the UI reads from. `DriftChatCache` is the default; the
/// interface exists for tests and alternative stores.
///
/// Message lists are newest first, ordered by `(createdAt, id)` descending.
/// Only `ChatKit` opens and closes a cache.
abstract interface class ChatCache {
  bool get isOpen;

  /// Opens the store of [userId], closing another user's store first.
  Future<void> open(String userId);
  Future<void> close();

  /// Deletes everything of the open user.
  Future<void> clear();

  /// Pinned first, then most recently updated. [search] matches the room
  /// title or a member's name.
  Stream<List<ChatRoom>> watchRooms({String? search});
  Stream<ChatRoom?> watchRoom(String roomId);

  /// Messages between [from] and [to] (both inclusive, either optional),
  /// newest first. [limit] keeps only the newest ones.
  Stream<List<Message>> watchMessages(
    String roomId, {
    MessageCursor? from,
    MessageCursor? to,
    int? limit,
  });

  /// One-shot version of [watchMessages].
  Future<List<Message>> messages(
    String roomId, {
    MessageCursor? from,
    MessageCursor? to,
    int? limit,
  });
  Stream<List<RoomMember>> watchMembers(String roomId);

  /// Up to [limit] messages strictly older than [cursor], newest first.
  Future<List<Message>> messagesBefore(
    String roomId,
    MessageCursor cursor,
    int limit,
  );

  /// Up to [limit] messages strictly newer than [cursor], newest first.
  Future<List<Message>> messagesAfter(
    String roomId,
    MessageCursor cursor,
    int limit,
  );
  Future<Message?> messageByAnyId(String idOrLocalId);

  /// Upserts rooms. A room with a non-empty `members` list replaces the
  /// stored member set; read pointers never move backwards.
  Future<void> upsertRooms(List<ChatRoom> rooms);

  /// Removes the room with its members, messages, sync state, draft and
  /// outbox entries.
  Future<void> deleteRoom(String roomId);

  /// Upserts in one transaction, matching on `localId`, else on `id`, so a
  /// confirmed message replaces its pending row.
  Future<void> upsertMessages(List<Message> messages);
  Future<void> deleteMessage(String idOrLocalId);

  /// Adds or updates members without removing others. Read and delivered
  /// pointers never move backwards.
  Future<void> upsertMembers(String roomId, List<RoomMember> members);

  /// Moves one member's read / delivered pointers forward, keeping the
  /// role. Adds the member when unknown.
  Future<void> updatePointers(
    String roomId,
    String userId, {
    DateTime? readAt,
    DateTime? deliveredAt,
  });
  Future<void> upsertUsers(List<ChatUser> users);
  Future<Map<String, ChatUser>> users(Set<String> ids);

  /// Ids from [ids] that are missing or were fetched before [olderThan].
  Future<Set<String>> staleUsers(
    Set<String> ids, {
    required DateTime olderThan,
  });

  Future<RoomSyncState?> syncState(String roomId);
  Future<void> saveSyncState(RoomSyncState state);

  /// Inserts or replaces the entry with the same key.
  Future<void> enqueue(OutboxEntry entry);

  /// Entries due at [now], oldest first.
  Future<List<OutboxEntry>> dueOutbox(DateTime now);

  /// Every entry, oldest first.
  Future<List<OutboxEntry>> outbox();
  Future<OutboxEntry?> outboxEntry(String key);
  Future<void> updateOutbox(OutboxEntry entry);
  Future<void> removeOutbox(String key);

  /// In one transaction: upserts [message] (like [upsertMessages]), then
  /// enqueues [enqueue] and removes the entries keyed [removeKeys]. Keeps
  /// a message and its pending writes consistent across crashes.
  Future<void> stage(
    Message message, {
    OutboxEntry? enqueue,
    List<String> removeKeys = const [],
  });

  Future<ChatDraft?> draft(String roomId);

  /// Saves the draft; an empty text without a reply clears it.
  Future<void> saveDraft(String roomId, String? text, {String? replyToId});

  /// Keeps the newest [keep] messages of the room (plus unsent ones) and
  /// moves the sync state's oldest cursor accordingly.
  Future<void> trim(String roomId, {required int keep});
}
