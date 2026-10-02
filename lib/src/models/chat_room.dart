import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/models/chat_json_keys.dart';
import 'package:flutter_chat_pro/src/models/json_utils.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_cursor.dart';
import 'package:flutter_chat_pro/src/models/room_member.dart';

/// The kind of conversation, which changes how the room is drawn.
enum RoomType {
  /// Two people. The app bar and inbox row show the other member's avatar,
  /// online state and, when the room has no title, name.
  direct,

  /// Several people. Bubbles show the author's name and avatar; the app bar
  /// shows the member count.
  group,

  /// Like [group], for broadcast-style rooms.
  channel;

  /// Reads `direct`, `group` or `channel`; anything else, or a missing
  /// value, reads as [direct].
  static RoomType parse(Object? value) {
    if (value is! String) return RoomType.direct;
    return RoomType.values.asNameMap()[value] ?? RoomType.direct;
  }
}

/// A conversation, as seen by the current user.
///
/// [unreadCount], [pinned] and [muted] are per-user values, like the
/// "one conversation row per member" model.
///
/// Read backend JSON with [ChatRoom.fromJson]; field names come from
/// `RoomJsonKeys`. Only `id` is required, plus `updated_at` or a
/// `last_message` to take the time from:
///
/// ```json
/// {"id": "r1", "type": "group", "title": "Weekend trip",
///  "updated_at": "2026-01-02T10:06:00Z", "unread_count": 2,
///  "members": [{"user_id": "u1", "last_read_at": "2026-01-02T10:00:00Z"},
///    "u2"],
///  "last_message": {"id": "m7", "author_id": "u2",
///    "created_at": "2026-01-02T10:06:00Z", "text": "Deal!"}}
/// ```
@immutable
class ChatRoom {
  /// A room; [id] and [updatedAt] are required.
  const ChatRoom({
    required this.id,
    required this.updatedAt,
    this.type = RoomType.direct,
    this.title,
    this.avatarUrl,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.pinned = false,
    this.muted = false,
    this.labels = const {},
    this.metadata = const {},
  });

  /// Reads a room from backend JSON.
  ///
  /// Field names come from [keys] (`keys.roomKeys`); [codec], when given,
  /// replaces [keys] for the room and its `last_message`.
  ///
  /// Without `updated_at`, the last message's `created_at` is used; with
  /// neither, or without `id`, it throws a [FormatException] that names the
  /// field. The last message may leave out its room id. Members can be
  /// objects or plain user ids. `pinned` and `muted` accept booleans, 0/1
  /// or `"true"`; `labels` accepts a list or one string. Check real
  /// responses with `ChatJsonCheck.room`.
  ///
  /// ```dart
  /// final rooms = [
  ///   for (final item in body['rooms'] as List)
  ///     ChatRoom.fromJson(item as Map<String, Object?>,
  ///         keys: ChatJsonKeys.camelCase),
  /// ];
  /// ```
  factory ChatRoom.fromJson(
    Map<String, Object?> json, {
    ChatJsonKeys keys = const ChatJsonKeys(),
    MessageCodec? codec,
  }) {
    final messages = codec ?? MessageCodec(keys: keys);
    final k = messages.keys.roomKeys;
    final id = readOptionalString(json[k.id]);
    if (id == null) {
      throw FormatException(
        'Room needs "${k.id}"; set RoomJsonKeys(id: ...) if your API names '
        'it differently. Got the fields ${json.keys.toList()}.',
      );
    }
    final last = json[k.lastMessage];
    final lastMessage = last is Map
        ? messages.decode(readMap(last), roomId: id)
        : null;
    final updatedAt =
        readDate(json[k.updatedAt]) ??
        lastMessage?.createdAt ??
        (throw FormatException(
          'Room "$id": missing "${k.updatedAt}" and no "${k.lastMessage}" '
          'to take the time from. Set RoomJsonKeys(updatedAt: ...) to your '
          'last activity field.',
        ));
    return ChatRoom(
      id: id,
      updatedAt: updatedAt,
      type: RoomType.parse(json[k.type]),
      title: readOptionalString(json[k.title]),
      avatarUrl: readOptionalString(json[k.avatarUrl]),
      members: [
        for (final m in readList(json[k.members]))
          if (m != null) RoomMember.fromJson(m, keys: k.member),
      ],
      lastMessage: lastMessage,
      unreadCount: readInt(json[k.unreadCount]) ?? 0,
      pinned: readBool(json[k.pinned]),
      muted: readBool(json[k.muted]),
      labels: readStringSet(json[k.labels]),
      metadata: readMap(json[k.metadata]),
    );
  }

  /// The room id (JSON `id`), a string or a number. Required.
  final String id;

  /// Last activity (JSON `updated_at`); the inbox sorts by this, newest
  /// first. Falls back to the last message's time when missing.
  final DateTime updatedAt;

  /// Direct, group or channel (JSON `type`); defaults to
  /// [RoomType.direct].
  final RoomType type;

  /// The room name (JSON `title`). Usually null for direct rooms. Without
  /// it, a direct room shows the other member's name and a group lists its
  /// members' names.
  final String? title;

  /// The room picture (JSON `avatar_url`). Direct rooms prefer the other
  /// member's avatar and fall back to this; groups without it show two
  /// stacked member avatars.
  final String? avatarUrl;

  /// Who is in the room (JSON `members`), as objects or plain user ids.
  ///
  /// Their read pointers drive the ticks on my messages, and in direct
  /// rooms the other member gives the name, avatar and online state.
  /// Without members, ticks come only from `Message.status`.
  final List<RoomMember> members;

  /// The newest message (JSON `last_message`), shown as the inbox preview.
  final Message? lastMessage;

  /// Unread messages for the current user (JSON `unread_count`), shown as
  /// the inbox badge. Defaults to 0.
  final int unreadCount;

  /// Whether the current user pinned the room to the top of the inbox
  /// (JSON `pinned`).
  final bool pinned;

  /// Whether the current user muted the room (JSON `muted`); the inbox row
  /// shows a muted icon and a badge in `ChatBadgeStyle.mutedColor`.
  final bool muted;

  /// App-defined categories of this room for the current user, such as
  /// `archived`, `selling` or `support` (JSON `labels`). `RoomFilter.labels`
  /// selects them.
  final Set<String> labels;

  /// App extras (JSON `metadata`), kept untouched. The kit never reads it.
  final Map<String, Object?> metadata;

  /// Whether [type] is [RoomType.direct].
  bool get isDirect => type == RoomType.direct;

  /// Whether [labels] contains [label].
  bool hasLabel(String label) => labels.contains(label);

  /// This room's position in the inbox, for paging with
  /// `ChatSource.fetchRooms`.
  RoomCursor get cursor => RoomCursor(updatedAt, id);

  /// The member with [userId], or null.
  RoomMember? member(String userId) {
    return members.firstWhereOrNull((m) => m.userId == userId);
  }

  /// The other participant of a direct room, or null.
  String? otherUserId(String currentUserId) {
    if (!isDirect) return null;
    return members.firstWhereOrNull((m) => m.userId != currentUserId)?.userId;
  }

  /// A copy with the given fields replaced; null keeps the current value.
  ChatRoom copyWith({
    String? id,
    DateTime? updatedAt,
    RoomType? type,
    String? title,
    String? avatarUrl,
    List<RoomMember>? members,
    Message? lastMessage,
    int? unreadCount,
    bool? pinned,
    bool? muted,
    Set<String>? labels,
    Map<String, Object?>? metadata,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      pinned: pinned ?? this.pinned,
      muted: muted ?? this.muted,
      labels: labels ?? this.labels,
      metadata: metadata ?? this.metadata,
    );
  }

  /// This room as JSON with the names of [keys] (or [codec]); null and
  /// empty fields are left out.
  Map<String, Object?> toJson({
    ChatJsonKeys keys = const ChatJsonKeys(),
    MessageCodec? codec,
  }) {
    final messages = codec ?? MessageCodec(keys: keys);
    final k = messages.keys.roomKeys;
    final last = lastMessage;
    return withoutNulls({
      k.id: id,
      k.updatedAt: writeDate(updatedAt),
      k.type: type.name,
      k.title: title,
      k.avatarUrl: avatarUrl,
      k.members: [for (final m in members) m.toJson(keys: k.member)],
      k.lastMessage: last == null ? null : messages.encode(last),
      k.unreadCount: unreadCount,
      k.pinned: pinned,
      k.muted: muted,
      k.labels: labels.isEmpty ? null : (labels.toList()..sort()),
      k.metadata: metadata.isEmpty ? null : metadata,
    });
  }

  @override
  bool operator ==(Object other) {
    return other is ChatRoom &&
        other.id == id &&
        other.updatedAt == updatedAt &&
        other.type == type &&
        other.title == title &&
        other.avatarUrl == avatarUrl &&
        deepEquality.equals(other.members, members) &&
        other.lastMessage == lastMessage &&
        other.unreadCount == unreadCount &&
        other.pinned == pinned &&
        other.muted == muted &&
        deepEquality.equals(other.labels, labels) &&
        deepEquality.equals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    type,
    title,
    avatarUrl,
    deepEquality.hash(members),
    lastMessage,
    unreadCount,
    pinned,
    muted,
    deepEquality.hash(labels),
    deepEquality.hash(metadata),
  );

  @override
  String toString() => 'ChatRoom($id, ${type.name}, unread: $unreadCount)';
}
