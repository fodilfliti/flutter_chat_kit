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

  factory ChatRoom.fromJson(
    Map<String, Object?> json, {
    MessageCodec codec = const MessageCodec(),
  }) {
    final last = json['last_message'];
    return ChatRoom(
      id: readString(json, 'id'),
      updatedAt: readRequiredDate(json, 'updated_at'),
      type: RoomType.parse(json['type']),
      title: readOptionalString(json['title']),
      avatarUrl: readOptionalString(json['avatar_url']),
      members: [
        for (final m in readMapList(json['members'])) RoomMember.fromJson(m),
      ],
      lastMessage: last is Map ? codec.decode(readMap(last)) : null,
      unreadCount: readInt(json['unread_count']) ?? 0,
      pinned: readBool(json['pinned']),
      muted: readBool(json['muted']),
      labels: readStringSet(json['labels']),
      metadata: readMap(json['metadata']),
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

  Map<String, Object?> toJson({MessageCodec codec = const MessageCodec()}) {
    final last = lastMessage;
    return withoutNulls({
      'id': id,
      'updated_at': writeDate(updatedAt),
      'type': type.name,
      'title': title,
      'avatar_url': avatarUrl,
      'members': [for (final m in members) m.toJson()],
      'last_message': last == null ? null : codec.encode(last),
      'unread_count': unreadCount,
      'pinned': pinned,
      'muted': muted,
      'labels': labels.isEmpty ? null : (labels.toList()..sort()),
      'metadata': metadata.isEmpty ? null : metadata,
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
