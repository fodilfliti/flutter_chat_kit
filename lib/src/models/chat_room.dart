import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/chat_json_keys.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/room_member.dart';

enum RoomType {
  direct,
  group,
  channel;

  static RoomType parse(Object? value) {
    if (value is! String) return RoomType.direct;
    return RoomType.values.asNameMap()[value] ?? RoomType.direct;
  }
}

/// A conversation, as seen by the current user.
///
/// [unreadCount], [pinned] and [muted] are per-user values, like the
/// "one conversation row per member" model.
@immutable
class ChatRoom {
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

  /// Field names come from [keys] (`keys.roomKeys`); [codec], when given,
  /// replaces [keys] for the room and its `last_message`.
  ///
  /// Without `updated_at`, the last message's time is used. The last
  /// message may leave out its room id. Members can be objects or plain
  /// user ids.
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

  final String id;

  /// Last activity; the inbox sorts by this.
  final DateTime updatedAt;
  final RoomType type;

  /// Null for direct rooms; the UI shows the other member's name.
  final String? title;
  final String? avatarUrl;
  final List<RoomMember> members;
  final Message? lastMessage;
  final int unreadCount;
  final bool pinned;
  final bool muted;

  /// App-defined categories of this room for the current user, such as
  /// `archived`, `selling` or `support`. `RoomFilter.labels` selects them.
  final Set<String> labels;
  final Map<String, Object?> metadata;

  bool get isDirect => type == RoomType.direct;

  bool hasLabel(String label) => labels.contains(label);

  RoomCursor get cursor => RoomCursor(updatedAt, id);

  RoomMember? member(String userId) {
    return members.firstWhereOrNull((m) => m.userId == userId);
  }

  /// The other participant of a direct room, or null.
  String? otherUserId(String currentUserId) {
    if (!isDirect) return null;
    return members.firstWhereOrNull((m) => m.userId != currentUserId)?.userId;
  }

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
