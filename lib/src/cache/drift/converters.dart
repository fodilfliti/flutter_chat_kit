import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_chat_pro/src/cache/drift/chat_database.dart';
import 'package:flutter_chat_pro/src/models/chat_json_keys.dart';
import 'package:flutter_chat_pro/src/models/chat_room.dart';
import 'package:flutter_chat_pro/src/models/chat_user.dart';
import 'package:flutter_chat_pro/src/models/json_utils.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_cursor.dart';
import 'package:flutter_chat_pro/src/models/room_member.dart';
import 'package:flutter_chat_pro/src/sync/outbox_entry.dart';
import 'package:flutter_chat_pro/src/sync/room_sync_state.dart';

// The cache always uses the default keys, whatever the app's backend uses.
const _codec = MessageCodec();
const _keys = ChatJsonKeys();
final Set<String> _baseKeys = {
  _keys.type,
  _keys.id,
  _keys.localId,
  _keys.roomId,
  _keys.authorId,
  _keys.createdAt,
  _keys.editedAt,
  _keys.deletedAt,
  _keys.status,
  _keys.replyToId,
  _keys.reactions,
  _keys.metadata,
};

int toMicros(DateTime value) => value.toUtc().microsecondsSinceEpoch;

int? toMicrosOrNull(DateTime? value) => value == null ? null : toMicros(value);

DateTime fromMicros(int value) =>
    DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);

DateTime? fromMicrosOrNull(int? value) =>
    value == null ? null : fromMicros(value);

String encodeJson(Object? value) =>
    jsonEncode(value, toEncodable: _toEncodable);

Map<String, Object?> decodeJson(String? value) {
  if (value == null || value.isEmpty) return const {};
  return readMap(jsonDecode(value));
}

Object? _toEncodable(Object? value) {
  return switch (value) {
    final DateTime date => date.toUtc().toIso8601String(),
    final Set<Object?> set => set.toList(),
    _ => value.toString(),
  };
}

MessagesCompanion messageToRow(Message message) {
  final json = _codec.encode(message);
  final body = {
    for (final e in json.entries)
      if (!_baseKeys.contains(e.key)) e.key: e.value,
  };
  return MessagesCompanion.insert(
    localId: message.localId,
    id: message.id,
    roomId: message.roomId,
    authorId: message.authorId,
    type: message.type,
    createdAt: toMicros(message.createdAt),
    editedAt: Value(toMicrosOrNull(message.editedAt)),
    deletedAt: Value(toMicrosOrNull(message.deletedAt)),
    status: message.status.name,
    replyToId: Value(message.replyToId),
    bodyJson: encodeJson(body),
    reactionsJson: Value(encodeJson(writeReactions(message.reactions))),
    metadataJson: Value(encodeJson(message.metadata)),
  );
}

Message messageFromRow(MessageRow row) {
  return _codec.decode({
    ...decodeJson(row.bodyJson),
    _keys.type: row.type,
    _keys.id: row.id,
    _keys.localId: row.localId,
    _keys.roomId: row.roomId,
    _keys.authorId: row.authorId,
    _keys.createdAt: fromMicros(row.createdAt),
    _keys.editedAt: fromMicrosOrNull(row.editedAt),
    _keys.deletedAt: fromMicrosOrNull(row.deletedAt),
    _keys.status: row.status,
    _keys.replyToId: row.replyToId,
    _keys.reactions: decodeJson(row.reactionsJson),
    _keys.metadata: decodeJson(row.metadataJson),
  });
}

RoomsCompanion roomToRow(ChatRoom room) {
  final last = room.lastMessage;
  return RoomsCompanion.insert(
    id: room.id,
    type: room.type.name,
    title: Value(room.title),
    avatarUrl: Value(room.avatarUrl),
    lastMessageJson: Value(
      last == null ? null : encodeJson(_codec.encode(last)),
    ),
    unreadCount: Value(room.unreadCount),
    updatedAt: toMicros(room.updatedAt),
    pinned: Value(room.pinned),
    muted: Value(room.muted),
    metadataJson: Value(encodeJson(room.metadata)),
    labelsJson: Value(encodeJson(room.labels.toList()..sort())),
  );
}

ChatRoom roomFromRow(RoomRow row, List<RoomMember> members) {
  final last = row.lastMessageJson;
  return ChatRoom(
    id: row.id,
    updatedAt: fromMicros(row.updatedAt),
    type: RoomType.parse(row.type),
    title: row.title,
    avatarUrl: row.avatarUrl,
    members: members,
    lastMessage: last == null ? null : _codec.decode(decodeJson(last)),
    unreadCount: row.unreadCount,
    pinned: row.pinned,
    muted: row.muted,
    labels: readStringSet(jsonDecode(row.labelsJson)),
    metadata: decodeJson(row.metadataJson),
  );
}

MembersCompanion memberToRow(String roomId, RoomMember member) {
  return MembersCompanion.insert(
    roomId: roomId,
    userId: member.userId,
    role: member.role.name,
    lastReadAt: Value(toMicrosOrNull(member.lastReadAt)),
    lastDeliveredAt: Value(toMicrosOrNull(member.lastDeliveredAt)),
  );
}

RoomMember memberFromRow(MemberRow row) {
  return RoomMember(
    userId: row.userId,
    role: MemberRole.parse(row.role),
    lastReadAt: fromMicrosOrNull(row.lastReadAt),
    lastDeliveredAt: fromMicrosOrNull(row.lastDeliveredAt),
  );
}

UsersCompanion userToRow(ChatUser user, DateTime fetchedAt) {
  return UsersCompanion.insert(
    id: user.id,
    name: user.name,
    avatarUrl: Value(user.avatarUrl),
    metadataJson: Value(encodeJson(user.metadata)),
    fetchedAt: toMicros(fetchedAt),
  );
}

ChatUser userFromRow(UserRow row) {
  return ChatUser(
    id: row.id,
    name: row.name,
    avatarUrl: row.avatarUrl,
    metadata: decodeJson(row.metadataJson),
  );
}

RoomSyncStatesCompanion syncStateToRow(RoomSyncState state) {
  return RoomSyncStatesCompanion.insert(
    roomId: state.roomId,
    newestCreatedAt: Value(toMicrosOrNull(state.newest?.createdAt)),
    newestId: Value(state.newest?.id),
    oldestCreatedAt: Value(toMicrosOrNull(state.oldest?.createdAt)),
    oldestId: Value(state.oldest?.id),
    hasMoreOlder: Value(state.hasMoreOlder),
    syncedAt: Value(toMicrosOrNull(state.syncedAt)),
  );
}

RoomSyncState syncStateFromRow(SyncStateRow row) {
  MessageCursor? cursor(int? at, String? id) =>
      at == null || id == null ? null : MessageCursor(fromMicros(at), id);
  return RoomSyncState(
    roomId: row.roomId,
    newest: cursor(row.newestCreatedAt, row.newestId),
    oldest: cursor(row.oldestCreatedAt, row.oldestId),
    hasMoreOlder: row.hasMoreOlder,
    syncedAt: fromMicrosOrNull(row.syncedAt),
  );
}

OutboxCompanion outboxToRow(OutboxEntry entry) {
  return OutboxCompanion.insert(
    key: entry.key,
    localId: entry.localId,
    roomId: entry.roomId,
    op: entry.op.name,
    payloadJson: Value(encodeJson(entry.payload)),
    attempts: Value(entry.attempts),
    nextAttemptAt: Value(toMicrosOrNull(entry.nextAttemptAt)),
    lastError: Value(entry.lastError),
    createdAt: toMicros(entry.createdAt),
  );
}

OutboxEntry outboxFromRow(OutboxRow row) {
  return OutboxEntry(
    key: row.key,
    localId: row.localId,
    roomId: row.roomId,
    op: OutboxOp.parse(row.op),
    createdAt: fromMicros(row.createdAt),
    payload: decodeJson(row.payloadJson),
    attempts: row.attempts,
    nextAttemptAt: fromMicrosOrNull(row.nextAttemptAt),
    lastError: row.lastError,
  );
}
