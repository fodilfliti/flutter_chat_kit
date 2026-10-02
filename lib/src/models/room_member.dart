import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/models/json_keys.dart';
import 'package:flutter_chat_pro/src/models/json_utils.dart';
import 'package:flutter_chat_pro/src/models/message.dart';

/// A member's role in a room. The kit stores it for the app; the built-in
/// UI does not change with it.
enum MemberRole {
  /// Created or owns the room.
  owner,

  /// Can manage the room.
  admin,

  /// A regular member; the default.
  member;

  /// Reads `owner`, `admin` or `member`; anything else, or a missing
  /// value, reads as [member].
  static MemberRole parse(Object? value) {
    if (value is! String) return MemberRole.member;
    return MemberRole.values.asNameMap()[value] ?? MemberRole.member;
  }
}

/// A user's membership in a room, including read pointers.
///
/// Receipts are derived from [lastReadAt] / [lastDeliveredAt]: a message is
/// seen by this member when its `createdAt` is not after [lastReadAt].
///
/// In JSON a member is an object, or just the user id (a string or a
/// number); field names come from [MemberJsonKeys]:
///
/// ```json
/// {"user_id": "u2", "role": "admin",
///  "last_read_at": "2026-01-02T10:00:00Z",
///  "last_delivered_at": "2026-01-02T10:05:00Z"}
/// ```
@immutable
class RoomMember {
  /// A member; only [userId] is required.
  const RoomMember({
    required this.userId,
    this.role = MemberRole.member,
    this.lastReadAt,
    this.lastDeliveredAt,
  });

  /// Reads a member object, or a plain user id.
  ///
  /// An object needs `user_id`, else it throws a [FormatException] that
  /// names the field. Dates may be ISO-8601, epoch milliseconds or epoch
  /// seconds.
  factory RoomMember.fromJson(
    Object? json, {
    MemberJsonKeys keys = const MemberJsonKeys(),
  }) {
    if (json is String || json is num) return RoomMember(userId: '$json');
    final map = readMap(json);
    final userId = readOptionalString(map[keys.userId]);
    if (userId == null) {
      throw FormatException(
        'Room member needs "${keys.userId}"; set MemberJsonKeys(userId: ...) '
        'if your API names it differently. Got the fields '
        '${map.keys.toList()}.',
      );
    }
    return RoomMember(
      userId: userId,
      role: MemberRole.parse(map[keys.role]),
      lastReadAt: readDate(map[keys.lastReadAt]),
      lastDeliveredAt: readDate(map[keys.lastDeliveredAt]),
    );
  }

  /// The member's user (or profile) id (JSON `user_id`). Names and avatars
  /// come from `ChatPage.users` or the `ChatUserResolver`.
  final String userId;

  /// Owner, admin or member (JSON `role`); defaults to
  /// [MemberRole.member].
  final MemberRole role;

  /// The time of the newest message this member has read (JSON
  /// `last_read_at`).
  ///
  /// My message shows the seen ticks once every other member's pointer
  /// reaches it. Without read pointers, only a `seen` `Message.status` from
  /// the server shows them.
  final DateTime? lastReadAt;

  /// The time of the newest message delivered to this member's device
  /// (JSON `last_delivered_at`). My message shows the delivered ticks once
  /// every other member received it.
  final DateTime? lastDeliveredAt;

  /// Whether this member has read [message], from [lastReadAt].
  bool hasRead(Message message) {
    final readAt = lastReadAt;
    return readAt != null && !message.createdAt.isAfter(readAt);
  }

  /// Whether [message] reached this member: read, or not after
  /// [lastDeliveredAt].
  bool hasReceived(Message message) {
    if (hasRead(message)) return true;
    final deliveredAt = lastDeliveredAt;
    return deliveredAt != null && !message.createdAt.isAfter(deliveredAt);
  }

  /// A copy with the given fields replaced; null keeps the current value.
  RoomMember copyWith({
    String? userId,
    MemberRole? role,
    DateTime? lastReadAt,
    DateTime? lastDeliveredAt,
  }) {
    return RoomMember(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastDeliveredAt: lastDeliveredAt ?? this.lastDeliveredAt,
    );
  }

  /// This member as JSON with the names of [keys]; null fields are left
  /// out.
  Map<String, Object?> toJson({MemberJsonKeys keys = const MemberJsonKeys()}) {
    return withoutNulls({
      keys.userId: userId,
      keys.role: role.name,
      keys.lastReadAt: writeDate(lastReadAt),
      keys.lastDeliveredAt: writeDate(lastDeliveredAt),
    });
  }

  @override
  bool operator ==(Object other) {
    return other is RoomMember &&
        other.userId == userId &&
        other.role == role &&
        other.lastReadAt == lastReadAt &&
        other.lastDeliveredAt == lastDeliveredAt;
  }

  @override
  int get hashCode => Object.hash(userId, role, lastReadAt, lastDeliveredAt);

  @override
  String toString() => 'RoomMember($userId, ${role.name})';
}
